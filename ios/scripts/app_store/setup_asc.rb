#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "optparse"
require "rubygems/version"
require "time"
require_relative "client"

def app_root
  File.expand_path("../..", __dir__)
end

def parse_options(argv)
  options = {
    platform: "IOS",
    version: "1.0.0",
    primary_locale: "en-US",
    config: File.join(app_root, "fastlane", "release_config.json"),
    key_path: ENV["ASC_API_KEY_PATH"] || File.join(app_root, "fastlane", "asc_api_key.json")
  }
  OptionParser.new do |opts|
    opts.on("--config PATH") { |value| options[:config] = value }
    opts.on("--key-path PATH") { |value| options[:key_path] = value }
    opts.on("--bundle-id ID") { |value| options[:bundle_id] = value }
    opts.on("--name NAME") { |value| options[:name] = value }
    opts.on("--sku SKU") { |value| options[:sku] = value }
    opts.on("--version VERSION") { |value| options[:version] = value }
    opts.on("--primary-locale LOCALE") { |value| options[:primary_locale] = value }
  end.parse!(argv)

  config = File.file?(options[:config]) ? JSON.parse(File.read(options[:config])) : {}
  options[:config_data] = config
  options[:bundle_id] ||= config["bundle_id"]
  options[:name] ||= config["app_store_name"] || config["name"]
  options[:sku] ||= config["sku"] || options[:bundle_id]
  options[:version] ||= config["version"]
  options[:primary_locale] ||= config["primary_locale"]
  options[:age_rating_path] = File.join(File.dirname(options[:config]), "metadata", "app_rating_config.json")

  abort "--bundle-id is required" if options[:bundle_id].to_s.empty?
  abort "--name is required" if options[:name].to_s.empty?
  abort "Provide ASC_API_KEY_PATH or APP_STORE_CONNECT_API_KEY_* environment credentials" unless AutonomousAscCredentials.available?(key_path: options[:key_path])
  options
end

class BundleIdProvisioner
  def initialize(client:)
    @client = client
  end

  def ensure(identifier:, name:, capabilities:)
    bundle = find_bundle(identifier)
    created = bundle.nil?
    bundle ||= create_bundle(identifier: identifier, name: name)

    existing_capabilities = @client
      .get_all("/v1/bundleIds/#{bundle.fetch('id')}/bundleIdCapabilities")
      .fetch("data", [])
      .filter_map { |item| item.dig("attributes", "capabilityType") }
    capabilities_added = capabilities.uniq.reject do |capability|
      existing_capabilities.include?(capability)
    end
    capabilities_added.each do |capability|
      create_capability(bundle.fetch("id"), capability)
    end

    {
      bundle: bundle,
      created: created,
      capabilities_added: capabilities_added
    }
  end

  private

  def find_bundle(identifier)
    @client.get_all(
      "/v1/bundleIds",
      { "filter[identifier]" => identifier, "limit" => "200" }
    ).fetch("data", []).find do |item|
      item.dig("attributes", "identifier") == identifier
    end
  end

  def create_bundle(identifier:, name:)
    @client.post(
      "/v1/bundleIds",
      {
        data: {
          type: "bundleIds",
          attributes: {
            identifier: identifier,
            name: name,
            platform: "IOS"
          }
        }
      }
    ).fetch("data")
  end

  def create_capability(bundle_id, capability)
    @client.post(
      "/v1/bundleIdCapabilities",
      {
        data: {
          type: "bundleIdCapabilities",
          attributes: { capabilityType: capability },
          relationships: {
            bundleId: {
              data: { type: "bundleIds", id: bundle_id }
            }
          }
        }
      }
    )
  end
end

EDITABLE_APP_STORE_VERSION_STATES = %w[
  PREPARE_FOR_SUBMISSION
  DEVELOPER_REJECTED
  REJECTED
  METADATA_REJECTED
].freeze

def app_store_versions(client, app_id, platform)
  client.get_all("/v1/apps/#{app_id}/appStoreVersions", {
    "filter[platform]" => platform,
    "fields[appStoreVersions]" => "versionString,appStoreState,platform",
    "limit" => "200"
  }).fetch("data")
end

def find_app_store_version(client, app_id, version_string, platform)
  app_store_versions(client, app_id, platform).find do |version|
    version.dig("attributes", "versionString") == version_string
  end
end

def ensure_app_store_version(client, app_id, version_string, platform)
  versions = app_store_versions(client, app_id, platform)
  existing = versions.find do |version|
    version.dig("attributes", "versionString") == version_string
  end
  return existing if existing

  # Chrome creates the first editable version as `1.0`. Treat it as the same
  # semantic version as the release contract's `1.0.0` and align it in place;
  # ASC refuses a second version while that initial draft exists.
  equivalent = versions.find do |version|
    EDITABLE_APP_STORE_VERSION_STATES.include?(version.dig("attributes", "appStoreState")) &&
      Gem::Version.new(version.dig("attributes", "versionString")) == Gem::Version.new(version_string)
  rescue ArgumentError
    false
  end
  if equivalent
    return client.patch("/v1/appStoreVersions/#{equivalent.fetch('id')}", {
      data: {
        type: "appStoreVersions",
        id: equivalent.fetch("id"),
        attributes: { versionString: version_string }
      }
    }).fetch("data")
  end

  client.post("/v1/appStoreVersions", {
    data: {
      type: "appStoreVersions",
      attributes: {
        platform: platform,
        versionString: version_string
      },
      relationships: {
        app: {
          data: { type: "apps", id: app_id }
        }
      }
    }
  }).fetch("data")
rescue AutonomousAscError => error
  raise unless error.status.to_s == "409"

  find_app_store_version(client, app_id, version_string, platform) || raise
end

def ensure_game_center_detail(client, app_id)
  response = client.get("/v1/apps/#{app_id}/gameCenterDetail", {}, optional: true)
  return response.fetch("data") if response && response["data"]

  created = client.post("/v1/gameCenterDetails", {
    data: {
      type: "gameCenterDetails",
      relationships: {
        app: { data: { type: "apps", id: app_id } }
      }
    }
  })
  created.fetch("data")
end

def leaderboard_create_body(definition, detail_id, local_index)
  version_id = "${version-#{local_index}}"
  {
    data: {
      type: "gameCenterLeaderboards",
      attributes: leaderboard_attributes(definition),
      relationships: {
        gameCenterDetail: {
          data: { type: "gameCenterDetails", id: detail_id }
        },
        versions: {
          data: [{ type: "gameCenterLeaderboardVersions", id: version_id }]
        }
      }
    },
    included: [{ type: "gameCenterLeaderboardVersions", id: version_id }]
  }
end

def leaderboard_attributes(definition)
  attributes = {
    referenceName: definition.fetch("reference_name"),
    vendorIdentifier: definition.fetch("id"),
    defaultFormatter: definition.fetch("default_formatter"),
    submissionType: definition.fetch("submission_type"),
    scoreSortType: definition.fetch("score_sort_type"),
    # App Store Connect v2 models leaderboard score bounds as JSON strings,
    # even when the local release contract uses numeric values.
    scoreRangeStart: definition.fetch("score_range_start").to_s,
    scoreRangeEnd: definition.fetch("score_range_end").to_s,
    visibility: "SHOW_FOR_ALL"
  }
  return attributes unless definition.key?("recurrence_start_date") ||
                           definition.key?("recurrence_duration") ||
                           definition.key?("recurrence_rule")

  attributes.merge(
    recurrenceStartDate: definition.fetch("recurrence_start_date"),
    recurrenceDuration: definition.fetch("recurrence_duration"),
    recurrenceRule: definition.fetch("recurrence_rule")
  )
end

def leaderboard_fields
  %w[
    referenceName vendorIdentifier defaultFormatter submissionType scoreSortType
    scoreRangeStart scoreRangeEnd recurrenceStartDate recurrenceDuration
    recurrenceRule visibility archived versions
  ].join(",")
end

def leaderboard_attribute_matches?(key, desired, actual)
  return Time.iso8601(actual).utc == Time.iso8601(desired).utc if key == :recurrenceStartDate

  actual.to_s == desired.to_s
rescue ArgumentError, TypeError
  false
end

def reconcile_leaderboard(client, leaderboard, definition)
  desired = leaderboard_attributes(definition)
  actual = leaderboard.fetch("attributes", {})
  return leaderboard if desired.all? do |key, value|
    leaderboard_attribute_matches?(key, value, actual[key.to_s])
  end

  client.patch("/v2/gameCenterLeaderboards/#{leaderboard.fetch('id')}", {
    data: {
      type: "gameCenterLeaderboards",
      id: leaderboard.fetch("id"),
      attributes: desired
    }
  }).fetch("data")
end

def versions_for_leaderboard(client, leaderboard_id)
  client.get_all("/v2/gameCenterLeaderboards/#{leaderboard_id}/versions", {
    "include" => "localizations",
    "fields[gameCenterLeaderboardVersions]" => "version,state,localizations",
    "fields[gameCenterLeaderboardLocalizations]" => "locale,name,formatterSuffix,formatterSuffixSingular,description",
    "limit" => "200",
    "limit[localizations]" => "50"
  })
end

def ensure_version(client, leaderboard_id)
  payload = versions_for_leaderboard(client, leaderboard_id)
  version = payload.fetch("data").max_by { |item| item.dig("attributes", "version").to_i }
  return [version, payload] if version

  created = client.post("/v2/gameCenterLeaderboardVersions", {
    data: {
      type: "gameCenterLeaderboardVersions",
      relationships: {
        leaderboard: {
          data: { type: "gameCenterLeaderboards", id: leaderboard_id }
        }
      }
    }
  }).fetch("data")
  [created, versions_for_leaderboard(client, leaderboard_id)]
end

def localization_attributes(locale, localization)
  {
    locale: locale,
    name: localization.fetch("name"),
    formatterSuffix: localization["suffix"],
    formatterSuffixSingular: localization["singular_suffix"],
    description: localization["description"]
  }.reject { |_key, value| value.nil? }
end

def ensure_localizations(client, version, payload, definition)
  localization_ids = version.dig("relationships", "localizations", "data") || []
  included = payload.fetch("included", [])
  actual_by_locale = localization_ids.each_with_object({}) do |linkage, result|
    resource = included.find do |item|
      item["type"] == linkage["type"] && item["id"] == linkage["id"]
    end
    locale = resource&.dig("attributes", "locale")
    result[locale] = resource if locale
  end

  definition.fetch("localizations").each do |locale, localization|
    desired = localization_attributes(locale, localization)
    existing = actual_by_locale[locale]
    if existing
      actual = existing.fetch("attributes", {})
      next if desired.all? { |key, value| actual[key.to_s] == value }

      client.patch("/v2/gameCenterLeaderboardLocalizations/#{existing.fetch('id')}", {
        data: {
          type: "gameCenterLeaderboardLocalizations",
          id: existing.fetch("id"),
          attributes: desired.reject { |key, _value| key == :locale }
        }
      })
      puts "Updated Game Center localization #{definition.fetch("id")} / #{locale}"
      next
    end

    client.post("/v2/gameCenterLeaderboardLocalizations", {
      data: {
        type: "gameCenterLeaderboardLocalizations",
        attributes: desired,
        relationships: {
          version: {
            data: { type: "gameCenterLeaderboardVersions", id: version.fetch("id") }
          }
        }
      }
    })
    puts "Created Game Center localization #{definition.fetch("id")} / #{locale}"
  end
end

def ensure_age_rating(client, app_id, expected)
  app_infos = client.get_all("/v1/apps/#{app_id}/appInfos", {
    "fields[appInfos]" => "state,appStoreAgeRating,ageRatingDeclaration",
    "limit" => "200"
  }).fetch("data")
  app_info = app_infos.find { |item| item.dig("attributes", "state") == "PREPARE_FOR_SUBMISSION" } || app_infos.first
  raise "No App Info exists for age-rating configuration" unless app_info

  response = client.get("/v1/appInfos/#{app_info.fetch('id')}/ageRatingDeclaration", {
    "fields[ageRatingDeclarations]" => expected.keys.join(",")
  })
  declaration = response.fetch("data")
  actual = declaration.fetch("attributes", {})
  return declaration if expected.all? { |key, value| actual[key] == value }

  updated = client.patch("/v1/ageRatingDeclarations/#{declaration.fetch('id')}", {
    data: {
      type: "ageRatingDeclarations",
      id: declaration.fetch("id"),
      attributes: expected.transform_keys(&:to_sym)
    }
  }).fetch("data")
  puts "Updated age rating declaration #{declaration.fetch('id')}"
  updated
end

if __FILE__ == $PROGRAM_NAME
begin
  options = parse_options(ARGV)
  token = AutonomousAscCredentials.token(key_path: options[:key_path])
  Spaceship::ConnectAPI.token = token
  client = AutonomousAscClient.new(key_path: options[:key_path])
  definitions = options.fetch(:config_data).fetch("leaderboards", [])

  bundle_result = BundleIdProvisioner.new(client: client).ensure(
    identifier: options[:bundle_id],
    name: options[:name],
    capabilities: definitions.empty? ? [] : ["GAME_CENTER"]
  )
  bundle = bundle_result.fetch(:bundle)
  puts "Created bundle id #{options[:bundle_id]}" if bundle_result.fetch(:created)
  added = bundle_result.fetch(:capabilities_added)
  unless definitions.empty?
    puts "Game Center entitlement #{added.include?('GAME_CENTER') ? 'enabled' : 'already enabled'} for #{options[:bundle_id]}"
  end

  app = Spaceship::ConnectAPI::App.all(filter: { bundleId: options[:bundle_id] }).find do |candidate|
    candidate.bundle_id == options[:bundle_id]
  end
  unless app
    app = Spaceship::ConnectAPI::App.create(
      name: options[:name],
      version_string: options[:version],
      sku: options[:sku],
      primary_locale: options[:primary_locale],
      bundle_id: bundle.fetch("id"),
      platforms: [options[:platform]]
    )
    puts "Created App Store Connect app #{app.name}"
  end
  puts "ASC app record exists: #{app.name} / #{app.bundle_id} / #{app.id}"
  app_store_version = ensure_app_store_version(
    client,
    app.id,
    options.fetch(:version),
    options.fetch(:platform)
  )
  puts "App Store version ready: #{app_store_version.dig('attributes', 'versionString')} / #{app_store_version.fetch('id')}"

  unless File.file?(options[:age_rating_path])
    abort "Missing age rating declaration: #{options[:age_rating_path]}"
  end
  ensure_age_rating(client, app.id, JSON.parse(File.read(options[:age_rating_path])))
  unless definitions.empty?
    detail = ensure_game_center_detail(client, app.id)
    puts "Game Center detail exists: #{detail.fetch("id")}"
    response = client.get_all("/v1/gameCenterDetails/#{detail.fetch("id")}/gameCenterLeaderboardsV2", {
      "fields[gameCenterLeaderboards]" => leaderboard_fields,
      "limit" => "200"
    })
    existing = response.fetch("data").each_with_object({}) do |leaderboard, index|
      index[leaderboard.dig("attributes", "vendorIdentifier")] = leaderboard
    end

    definitions.each_with_index do |definition, index|
      leaderboard = existing[definition.fetch("id")]
      unless leaderboard
        leaderboard = client.post(
          "/v2/gameCenterLeaderboards",
          leaderboard_create_body(definition, detail.fetch("id"), index)
        ).fetch("data")
        puts "Created Game Center leaderboard #{definition.fetch("id")}"
      else
        leaderboard = reconcile_leaderboard(client, leaderboard, definition)
        puts "Reconciled Game Center leaderboard #{definition.fetch("id")}"
      end
      version, payload = ensure_version(client, leaderboard.fetch("id"))
      ensure_localizations(client, version, payload, definition)
      puts "Game Center leaderboard ready: #{definition.fetch("id")} version=#{version.dig("attributes", "version")} state=#{version.dig("attributes", "state")}"
    end
  end
rescue AutonomousAscError => error
  warn error.message
  exit 1
end
end
