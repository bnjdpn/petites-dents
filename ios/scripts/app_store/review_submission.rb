#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "optparse"

class ReviewSubmissionError < StandardError; end

class ReviewSubmissionCoordinator
  TERMINAL_STATES = %w[CANCELED COMPLETE].freeze
  SUBMITTED_STATES = %w[WAITING_FOR_REVIEW IN_REVIEW].freeze
  CANCELLABLE_STATES = %w[READY_FOR_REVIEW WAITING_FOR_REVIEW].freeze
  UNSAFE_STATES = %w[IN_REVIEW UNRESOLVED_ISSUES COMPLETING].freeze

  def initialize(
    client:,
    app_id:,
    version:,
    expected_build:,
    leaderboard_version_ids: [],
    iap_ids: []
  )
    @client = client
    @app_id = app_id
    @version = version
    @expected_build = expected_build.to_s
    @leaderboard_version_ids = leaderboard_version_ids
    @iap_ids = iap_ids
    @selected_version = nil
    @selected_build = nil
  end

  def select_build(wait_timeout: 1_800, poll_interval: 30)
    version, = target_version_and_build
    build = wait_for_expected_build(wait_timeout: wait_timeout, poll_interval: poll_interval)
    build_id = build.fetch("id")

    @client.patch("/v1/appStoreVersions/#{version.fetch('id')}/relationships/build", {
      data: { type: "builds", id: build_id }
    })
    unless build.dig("attributes", "usesNonExemptEncryption") == false
      @client.patch("/v1/builds/#{build_id}", {
        data: {
          type: "builds",
          id: build_id,
          attributes: { usesNonExemptEncryption: false }
        }
      })
    end
    @client.patch("/v1/appStoreVersions/#{version.fetch('id')}", {
      data: {
        type: "appStoreVersions",
        id: version.fetch("id"),
        attributes: { releaseType: "AFTER_APPROVAL" }
      }
    })
    @client.patch("/v1/apps/#{@app_id}", {
      data: {
        type: "apps",
        id: @app_id,
        attributes: { contentRightsDeclaration: "DOES_NOT_USE_THIRD_PARTY_CONTENT" }
      }
    })
    ensure_game_center_app_version(version.fetch("id"))

    @selected_version = version
    @selected_build = build
    base_result(version, @expected_build).merge(
      "status" => "selected",
      "build_id" => build_id,
      "processing_state" => build.dig("attributes", "processingState")
    )
  end

  def submit(wait_timeout: 300, poll_interval: 10)
    select_build(wait_timeout: wait_timeout, poll_interval: poll_interval) unless @selected_version && @selected_build
    version_id = @selected_version.fetch("id")
    required = required_resources(version_id)
    submissions = review_submissions(include_terminal: true)

    exact = submissions.find do |submission|
      SUBMITTED_STATES.include?(submission.fetch("state")) &&
        (required - submission.fetch("resources")).empty?
    end
    if exact
      return base_result(@selected_version, @expected_build).merge(
        "status" => "already_submitted",
        "submission_id" => exact.fetch("id"),
        "submission_state" => exact.fetch("state")
      )
    end

    active = submissions.reject { |submission| TERMINAL_STATES.include?(submission.fetch("state")) }
    unsafe = active.select { |submission| UNSAFE_STATES.include?(submission.fetch("state")) }
    unless unsafe.empty?
      detail = unsafe.map { |submission| "#{submission.fetch('id')}:#{submission.fetch('state')}" }.join(", ")
      raise ReviewSubmissionError, "wrong active review submission cannot safely cancel: #{detail}"
    end

    reusable = active.find do |submission|
      submission.fetch("state") == "READY_FOR_REVIEW" &&
        (submission.fetch("resources") - required).empty?
    end
    blocking = active.reject { |submission| reusable && submission.fetch("id") == reusable.fetch("id") }
    blocking.each do |submission|
      next if submission.fetch("state") == "CANCELING"
      unless CANCELLABLE_STATES.include?(submission.fetch("state"))
        raise ReviewSubmissionError,
              "wrong active review submission cannot safely cancel: #{submission.fetch('id')}:#{submission.fetch('state')}"
      end
      cancel(submission.fetch("id"))
    end
    wait_for_cancellation(
      blocking.map { |submission| submission.fetch("id") },
      wait_timeout: wait_timeout,
      poll_interval: poll_interval
    ) unless blocking.empty?

    submission = reusable || create_submission
    existing = submission.fetch("resources", [])
    (required - existing).each do |type, resource_id|
      if type == "inAppPurchases"
        add_iap_submission(resource_id)
      else
        add_review_item(submission.fetch("id"), type, resource_id)
      end
    end
    mark_submitted(submission.fetch("id"))
    final = wait_for_submission(
      submission.fetch("id"),
      wait_timeout: wait_timeout,
      poll_interval: poll_interval
    )
    game_center_states = wait_for_game_center_submission(
      wait_timeout: wait_timeout,
      poll_interval: poll_interval
    )
    base_result(@selected_version, @expected_build).merge(
      "status" => "submitted",
      "submission_id" => submission.fetch("id"),
      "submission_state" => final.fetch("state"),
      "leaderboard_version_ids" => @leaderboard_version_ids,
      "iap_ids" => @iap_ids,
      "leaderboard_version_states" => game_center_states
    )
  end

  def prepare(apply: false)
    version, build = target_version_and_build
    selected_build = build&.dig("attributes", "version").to_s

    active = review_submissions
    correct = if selected_build == @expected_build
                active.find do |submission|
                  SUBMITTED_STATES.include?(submission.fetch("state")) &&
                    submission.fetch("resources").include?(["appStoreVersions", version.fetch("id")])
                end
              end
    if correct
      return base_result(version, selected_build).merge(
        "status" => "already_submitted",
        "submission_id" => correct.fetch("id"),
        "submission_state" => correct.fetch("state")
      )
    end

    return base_result(version, selected_build).merge("status" => "ready") if active.empty?

    unsafe = active.reject { |submission| CANCELLABLE_STATES.include?(submission.fetch("state")) }
    unless unsafe.empty?
      detail = unsafe.map { |submission| "#{submission.fetch('id')}:#{submission.fetch('state')}" }.join(", ")
      raise ReviewSubmissionError, "wrong active review submission cannot safely cancel: #{detail}"
    end

    blocking_ids = active.map { |submission| submission.fetch("id") }
    unless apply
      return base_result(version, selected_build).merge(
        "status" => "needs_cancellation",
        "blocking_submission_ids" => blocking_ids
      )
    end

    active.each { |submission| cancel(submission.fetch("id")) }
    base_result(version, selected_build).merge(
      "status" => "ready",
      "canceled_submission_ids" => blocking_ids
    )
  end

  private

  def wait_for_expected_build(wait_timeout:, poll_interval:)
    deadline = monotonic_time + wait_timeout.to_f
    last_state = "missing"
    loop do
      builds = @client.get_all("/v1/builds", {
        "filter[app]" => @app_id,
        "filter[version]" => @expected_build,
        "filter[preReleaseVersion.version]" => @version,
        "filter[preReleaseVersion.platform]" => "IOS",
        "fields[builds]" => "version,processingState,uploadedDate,expired,usesNonExemptEncryption",
        "limit" => "20"
      }).fetch("data")
      build = builds.find { |candidate| candidate.dig("attributes", "version").to_s == @expected_build }
      if build
        last_state = build.dig("attributes", "processingState").to_s
        if build.dig("attributes", "expired") == true
          raise ReviewSubmissionError, "build #{@expected_build} is expired"
        end
        return build if last_state == "VALID"
        if %w[FAILED INVALID].include?(last_state)
          raise ReviewSubmissionError, "build #{@expected_build} processing failed with state #{last_state}"
        end
      end
      break if monotonic_time >= deadline
      sleep(poll_interval) if poll_interval.to_f.positive?
    end
    raise ReviewSubmissionError,
          "build #{@expected_build} did not become VALID within #{wait_timeout}s (last state: #{last_state})"
  end

  def ensure_game_center_app_version(version_id)
    response = @client.get(
      "/v1/appStoreVersions/#{version_id}/gameCenterAppVersion",
      { "fields[gameCenterAppVersions]" => "enabled" },
      optional: true
    )
    app_version = response && response["data"]
    unless app_version
      app_version = @client.post("/v1/gameCenterAppVersions", {
        data: {
          type: "gameCenterAppVersions",
          relationships: {
            appStoreVersion: {
              data: { type: "appStoreVersions", id: version_id }
            }
          }
        }
      }).fetch("data")
    end
    return if app_version.dig("attributes", "enabled") == true

    @client.patch("/v1/gameCenterAppVersions/#{app_version.fetch('id')}", {
      data: {
        type: "gameCenterAppVersions",
        id: app_version.fetch("id"),
        attributes: { enabled: true }
      }
    })
  end

  def target_version_and_build
    response = @client.get_all("/v1/apps/#{@app_id}/appStoreVersions", {
      "filter[platform]" => "IOS",
      "filter[versionString]" => @version,
      "include" => "build",
      "fields[appStoreVersions]" => "versionString,appStoreState,platform,build",
      "fields[builds]" => "version,processingState,expired",
      "limit" => "10"
    })
    version = response.fetch("data").find do |candidate|
      candidate.dig("attributes", "versionString") == @version
    end
    raise ReviewSubmissionError, "marketing version #{@version} does not exist" unless version

    build_id = version.dig("relationships", "build", "data", "id")
    build = response.fetch("included", []).find do |candidate|
      candidate["type"] == "builds" && candidate["id"] == build_id
    end
    if build_id && build.nil?
      build = @client.get("/v1/appStoreVersions/#{version.fetch('id')}/build", {
        "fields[builds]" => "version,processingState,expired"
      })["data"]
    end
    [version, build]
  end

  def review_submissions(include_terminal: false)
    response = @client.get_all("/v1/apps/#{@app_id}/reviewSubmissions", {
      "fields[reviewSubmissions]" => "state,submittedDate,platform,items",
      "limit" => "50"
    })
    response.fetch("data").map do |submission|
      state = submission.dig("attributes", "state").to_s
      next if !include_terminal && TERMINAL_STATES.include?(state)

      items = @client.get_all("/v1/reviewSubmissions/#{submission.fetch('id')}/items", {
        "include" => "appStoreVersion,gameCenterLeaderboardVersion",
        "fields[reviewSubmissionItems]" => "state,appStoreVersion,gameCenterLeaderboardVersion",
        "fields[appStoreVersions]" => "versionString,appStoreState,platform",
        "fields[gameCenterLeaderboardVersions]" => "version,state",
        "limit" => "200"
      })
      resources = items.fetch("data").flat_map { |item| item_resources(item) }
      {
        "id" => submission.fetch("id"),
        "state" => state,
        "resources" => resources
      }
    end.compact
  end

  def item_resources(item)
    %w[appStoreVersion gameCenterLeaderboardVersion].map do |relationship|
      resource = item.dig("relationships", relationship, "data")
      resource && [resource.fetch("type"), resource.fetch("id")]
    end.compact
  end

  def required_resources(version_id)
    resources = [["appStoreVersions", version_id]]
    resources.concat(@leaderboard_version_ids.map do |id|
      ["gameCenterLeaderboardVersions", id]
    end)
    resources.concat(@iap_ids.map { |id| ["inAppPurchases", id] })
    resources
  end

  def create_submission
    created = @client.post("/v1/reviewSubmissions", {
      data: {
        type: "reviewSubmissions",
        relationships: {
          app: { data: { type: "apps", id: @app_id } }
        }
      }
    }).fetch("data")
    {
      "id" => created.fetch("id"),
      "state" => created.dig("attributes", "state").to_s,
      "resources" => []
    }
  end

  def add_review_item(submission_id, type, resource_id)
    relationship = case type
                   when "appStoreVersions" then :appStoreVersion
                   when "gameCenterLeaderboardVersions" then :gameCenterLeaderboardVersion
                   else
                     raise ReviewSubmissionError, "unsupported review resource type: #{type}"
                   end
    @client.post("/v1/reviewSubmissionItems", {
      data: {
        type: "reviewSubmissionItems",
        relationships: {
          reviewSubmission: {
            data: { type: "reviewSubmissions", id: submission_id }
          },
          relationship => {
            data: { type: type, id: resource_id }
          }
        }
      }
    })
  end

  def add_iap_submission(iap_id)
    @client.post("/v1/inAppPurchaseSubmissions", {
      data: {
        type: "inAppPurchaseSubmissions",
        relationships: {
          inAppPurchaseV2: {
            data: { type: "inAppPurchases", id: iap_id }
          }
        }
      }
    })
  end

  def mark_submitted(submission_id)
    @client.patch("/v1/reviewSubmissions/#{submission_id}", {
      data: {
        type: "reviewSubmissions",
        id: submission_id,
        attributes: { submitted: true }
      }
    })
  end

  def wait_for_cancellation(submission_ids, wait_timeout:, poll_interval:)
    deadline = monotonic_time + wait_timeout.to_f
    loop do
      current = review_submissions(include_terminal: true)
      pending = current.select do |submission|
        submission_ids.include?(submission.fetch("id")) &&
          !TERMINAL_STATES.include?(submission.fetch("state"))
      end
      return if pending.empty?
      break if monotonic_time >= deadline
      sleep(poll_interval) if poll_interval.to_f.positive?
    end
    raise ReviewSubmissionError,
          "review submission cancellation did not complete within #{wait_timeout}s: #{submission_ids.join(',')}"
  end

  def wait_for_submission(submission_id, wait_timeout:, poll_interval:)
    deadline = monotonic_time + wait_timeout.to_f
    loop do
      submission = review_submissions(include_terminal: true).find do |candidate|
        candidate.fetch("id") == submission_id
      end
      return submission if submission && SUBMITTED_STATES.include?(submission.fetch("state"))
      break if monotonic_time >= deadline
      sleep(poll_interval) if poll_interval.to_f.positive?
    end
    raise ReviewSubmissionError,
          "review submission #{submission_id} did not leave READY_FOR_REVIEW within #{wait_timeout}s"
  end

  def wait_for_game_center_submission(wait_timeout:, poll_interval:)
    return {} if @leaderboard_version_ids.empty?

    submitted_states = %w[WAITING_FOR_REVIEW IN_REVIEW ACCEPTED PENDING_RELEASE LIVE]
    deadline = monotonic_time + wait_timeout.to_f
    states = {}
    loop do
      states = @leaderboard_version_ids.each_with_object({}) do |version_id, output|
        response = @client.get("/v2/gameCenterLeaderboardVersions/#{version_id}", {
          "fields[gameCenterLeaderboardVersions]" => "version,state"
        })
        output[version_id] = response.dig("data", "attributes", "state")
      end
      return states if states.values.all? { |state| submitted_states.include?(state) }
      break if monotonic_time >= deadline
      sleep(poll_interval) if poll_interval.to_f.positive?
    end
    detail = states.map { |id, state| "#{id}:#{state}" }.join(",")
    raise ReviewSubmissionError,
          "Game Center versions did not enter review within #{wait_timeout}s: #{detail}"
  end

  def cancel(submission_id)
    @client.patch("/v1/reviewSubmissions/#{submission_id}", {
      data: {
        type: "reviewSubmissions",
        id: submission_id,
        attributes: { canceled: true }
      }
    })
  end

  def base_result(version, selected_build)
    {
      "version" => @version,
      "version_id" => version.fetch("id"),
      "selected_build" => selected_build
    }
  end

  def monotonic_time
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end

def review_leaderboard_version_ids(client, app_id, expected_vendor_ids)
  detail_response = client.get("/v1/apps/#{app_id}/gameCenterDetail", {}, optional: true)
  detail = detail_response && detail_response["data"]
  raise ReviewSubmissionError, "Game Center detail is not configured" unless detail

  leaderboards = client.get_all(
    "/v1/gameCenterDetails/#{detail.fetch('id')}/gameCenterLeaderboardsV2",
    {
      "fields[gameCenterLeaderboards]" => "vendorIdentifier,versions,archived",
      "limit" => "200"
    }
  ).fetch("data")
  versions = expected_vendor_ids.map do |vendor_id|
    leaderboard = leaderboards.find do |candidate|
      candidate.dig("attributes", "vendorIdentifier") == vendor_id
    end
    raise ReviewSubmissionError, "Game Center leaderboard is missing: #{vendor_id}" unless leaderboard
    raise ReviewSubmissionError, "Game Center leaderboard is archived: #{vendor_id}" if leaderboard.dig("attributes", "archived") == true

    response = client.get_all("/v2/gameCenterLeaderboards/#{leaderboard.fetch('id')}/versions", {
      "fields[gameCenterLeaderboardVersions]" => "version,state",
      "limit" => "200"
    })
    version = response.fetch("data").max_by do |candidate|
      candidate.dig("attributes", "version").to_i
    end
    raise ReviewSubmissionError, "Game Center leaderboard has no version: #{vendor_id}" unless version

    version.fetch("id")
  end
  versions
end

def review_iap_ids(client, app_id, expected_products)
  expected_ids = expected_products.map do |product|
    product.is_a?(Hash) ? product["product_id"] : product
  end.compact
  return [] if expected_ids.empty?

  iaps = client.get_all("/v1/apps/#{app_id}/inAppPurchasesV2", {
    "fields[inAppPurchases]" => "name,productId,inAppPurchaseType,state",
    "limit" => "200"
  }).fetch("data")
  expected_ids.map do |product_id|
    iap = iaps.find do |candidate|
      candidate.dig("attributes", "productId") == product_id
    end
    raise ReviewSubmissionError, "tip IAP is missing: #{product_id}" unless iap
    unless iap.dig("attributes", "inAppPurchaseType") == "CONSUMABLE"
      raise ReviewSubmissionError, "tip IAP must be consumable: #{product_id}"
    end
    state = iap.dig("attributes", "state")
    unless %w[READY_TO_SUBMIT WAITING_FOR_REVIEW IN_REVIEW APPROVED].include?(state)
      raise ReviewSubmissionError, "tip IAP is not ready for review: #{product_id}:#{state}"
    end
    iap.fetch("id")
  end
end

if __FILE__ == $PROGRAM_NAME
  require_relative "client"

  app_root = File.expand_path("../..", __dir__)
  options = {
    config: File.join(app_root, "fastlane", "release_config.json"),
    key_path: ENV["ASC_API_KEY_PATH"] || File.join(app_root, "fastlane", "asc_api_key.json"),
    wait_timeout: 1_800,
    poll_interval: 30
  }
  options[:command] = ARGV.shift if ARGV.first && !ARGV.first.start_with?("-")
  OptionParser.new do |parser|
    parser.on("--config PATH") { |value| options[:config] = value }
    parser.on("--key-path PATH") { |value| options[:key_path] = value }
    parser.on("--bundle-id ID") { |value| options[:bundle_id] = value }
    parser.on("--version VERSION") { |value| options[:version] = value }
    parser.on("--expected-build NUMBER") { |value| options[:expected_build] = value }
    parser.on("--wait-timeout SECONDS", Integer) { |value| options[:wait_timeout] = value }
    parser.on("--poll-interval SECONDS", Integer) { |value| options[:poll_interval] = value }
    parser.on("--apply") { options[:apply] = true }
    parser.on("--json") { options[:json] = true }
  end.parse!(ARGV)

  config = File.file?(options[:config]) ? JSON.parse(File.read(options[:config])) : {}
  options[:bundle_id] ||= config["bundle_id"]
  options[:version] ||= config["version"]
  supported_commands = %w[prepare select-build submit]
  abort "Supported commands: #{supported_commands.join(', ')}" unless supported_commands.include?(options[:command])
  abort "--bundle-id is required" if options[:bundle_id].to_s.empty?
  abort "--version is required" if options[:version].to_s.empty?
  abort "--expected-build is required" if options[:expected_build].to_s.empty?
  if %w[select-build submit].include?(options[:command]) && options[:apply] != true
    abort "#{options[:command]} mutates ASC and requires --apply"
  end
  unless AutonomousAscCredentials.available?(key_path: options[:key_path])
    abort "Provide ASC_API_KEY_PATH or APP_STORE_CONNECT_API_KEY_* environment credentials"
  end

  begin
    client = AutonomousAscClient.new(key_path: options[:key_path])
    app = client.get("/v1/apps", {
      "filter[bundleId]" => options[:bundle_id],
      "fields[apps]" => "name,bundleId,sku,primaryLocale"
    }).fetch("data").first
    raise ReviewSubmissionError, "App not found for bundle id #{options[:bundle_id]}" unless app

    leaderboard_version_ids = if options[:command] == "submit"
                                review_leaderboard_version_ids(
                                  client,
                                  app.fetch("id"),
                                  config.fetch("leaderboard_ids")
                                )
                              else
                                []
                              end
    iap_ids = if options[:command] == "submit"
                review_iap_ids(
                  client,
                  app.fetch("id"),
                  config.fetch("iap", [])
                )
              else
                []
              end
    coordinator = ReviewSubmissionCoordinator.new(
      client: client,
      app_id: app.fetch("id"),
      version: options[:version],
      expected_build: options[:expected_build],
      leaderboard_version_ids: leaderboard_version_ids,
      iap_ids: iap_ids
    )
    result = case options[:command]
             when "prepare"
               coordinator.prepare(apply: options[:apply] == true)
             when "select-build"
               coordinator.select_build(
                 wait_timeout: options[:wait_timeout],
                 poll_interval: options[:poll_interval]
               )
             when "submit"
               coordinator.select_build(
                 wait_timeout: options[:wait_timeout],
                 poll_interval: options[:poll_interval]
               )
               coordinator.submit(
                 wait_timeout: options[:wait_timeout],
                 poll_interval: options[:poll_interval]
               )
             end
    if options[:json]
      puts JSON.generate(result)
    else
      puts "Review submission workflow: #{result.fetch('status')} build=#{result.fetch('selected_build')}"
      canceled = result.fetch("canceled_submission_ids", [])
      puts "Canceled wrong submissions: #{canceled.join(',')}" unless canceled.empty?
    end
  rescue ReviewSubmissionError, AutonomousAscError => error
    warn error.message
    exit 1
  end
end
