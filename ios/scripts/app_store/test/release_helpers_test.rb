# frozen_string_literal: true

require_relative "../review_submission"
require_relative "../status"

class RecordingAscClient
  attr_reader :calls

  def initialize(game_center_app_version: nil)
    @calls = []
    @game_center_app_version = game_center_app_version
  end

  def get_all(path, params = {})
    @calls << [:get_all, path, params]
    case path
    when "/v1/apps/app-1/appStoreVersions"
      {
        "data" => [
          {
            "type" => "appStoreVersions",
            "id" => "version-1",
            "attributes" => { "versionString" => "1.0.6" },
            "relationships" => { "build" => { "data" => nil } }
          }
        ],
        "included" => []
      }
    when "/v1/builds"
      {
        "data" => [
          {
            "type" => "builds",
            "id" => "build-1",
            "attributes" => {
              "version" => "7",
              "processingState" => "VALID",
              "expired" => false,
              "usesNonExemptEncryption" => false
            }
          }
        ]
      }
    else
      raise "Unexpected get_all call: #{path}"
    end
  end

  def get(path, params = {}, optional: false)
    @calls << [:get, path, params, optional]
    if path == "/v1/appStoreVersions/version-1/gameCenterAppVersion"
      return { "data" => @game_center_app_version }
    end

    raise "Unexpected get call: #{path}"
  end

  def patch(path, payload)
    @calls << [:patch, path, payload]
    { "data" => {} }
  end

  def post(path, payload)
    @calls << [:post, path, payload]
    raise "Unexpected post call: #{path}"
  end
end

class ReleaseHelpersTest
  def test_empty_leaderboard_list_skips_all_game_center_requests
    client = RecordingAscClient.new

    assert_equal [], review_leaderboard_version_ids(client, "app-1", [])
    assert_empty client.calls
  end

  def test_select_build_without_leaderboards_does_not_touch_game_center
    client = RecordingAscClient.new
    coordinator = ReviewSubmissionCoordinator.new(
      client: client,
      app_id: "app-1",
      version: "1.0.6",
      expected_build: "7"
    )

    result = coordinator.select_build(wait_timeout: 0, poll_interval: 0)

    assert_equal "selected", result.fetch("status")
    refute client.calls.any? { |_method, path, *| path.include?("gameCenter") }
  end

  def test_select_build_with_leaderboards_keeps_game_center_enabled
    game_center_app_version = {
      "type" => "gameCenterAppVersions",
      "id" => "game-center-version-1",
      "attributes" => { "enabled" => false }
    }
    client = RecordingAscClient.new(game_center_app_version: game_center_app_version)
    coordinator = ReviewSubmissionCoordinator.new(
      client: client,
      app_id: "app-1",
      version: "1.0.6",
      expected_build: "7",
      leaderboard_version_ids: ["leaderboard-version-1"]
    )

    coordinator.select_build(wait_timeout: 0, poll_interval: 0)

    assert(client.calls.any? { |method, path, *| method == :get && path.include?("gameCenterAppVersion") })
    assert(client.calls.any? do |method, path, payload|
      method == :patch &&
        path == "/v1/gameCenterAppVersions/game-center-version-1" &&
        payload.dig(:data, :attributes, :enabled) == true
    end)
  end

  def test_strict_status_accepts_an_app_without_game_center
    errors = strict_errors(base_payload, base_options)

    assert_empty errors
  end

  def test_strict_status_still_rejects_unexpected_leaderboards
    payload = base_payload
    payload["game_center"]["unexpected_ids"] = ["unexpected.board"]

    errors = strict_errors(payload, base_options)

    assert_includes errors, "unexpected Game Center leaderboards: unexpected.board"
  end

  def test_strict_status_requires_game_center_when_configured
    options = base_options.merge(expected_leaderboards: ["expected.board"])

    errors = strict_errors(base_payload, options)

    assert_includes errors, "Game Center detail is not configured"
    assert_includes errors, "Game Center is not enabled for marketing version 1.0.6"
  end

  def test_review_submission_without_leaderboards_only_requires_app_version
    options = base_options.merge(require_review_submission: true)
    payload = base_payload
    payload["review_submissions"] = [
      {
        "state" => "WAITING_FOR_REVIEW",
        "items" => [
          { "resource_type" => "appStoreVersions", "version" => "1.0.6" }
        ]
      }
    ]

    errors = strict_errors(payload, options)

    assert_empty errors
  end

  private

  def assert(condition, message = "assertion failed")
    raise message unless condition
  end

  def refute(condition, message = "refutation failed")
    raise message if condition
  end

  def assert_equal(expected, actual)
    assert(expected == actual, "Expected #{expected.inspect}, got #{actual.inspect}")
  end

  def assert_empty(actual)
    assert(actual.empty?, "Expected #{actual.inspect} to be empty")
  end

  def assert_includes(collection, item)
    assert(collection.include?(item), "Expected #{collection.inspect} to include #{item.inspect}")
  end

  def base_options
    {
      version: "1.0.6",
      expected_build: nil,
      require_selected_build: false,
      expected_leaderboards: [],
      leaderboard_definitions: [],
      required_locales: [],
      required_screenshot_display_types: [],
      app_preview_applicable: false,
      required_preview_types: [],
      require_review_submission: false
    }
  end

  def base_payload
    {
      "version" => { "version" => "1.0.6" },
      "recent_builds" => [],
      "selected_build" => nil,
      "pricing" => { "expected_price" => "0.00", "matches_expected" => true },
      "iap" => { "missing_product_ids" => [], "unexpected_product_ids" => [] },
      "age_rating" => { "configured" => true, "matches_expected" => true, "mismatches" => [] },
      "app_privacy" => {
        "declared_locally" => true,
        "data_collected" => false,
        "tracking" => false,
        "public_api_supported" => false,
        "verified_live" => false,
        "blocker" => "ASC has no public App Privacy API."
      },
      "game_center" => {
        "configured" => false,
        "missing_ids" => [],
        "unexpected_ids" => [],
        "items" => []
      },
      "game_center_app_version" => { "configured" => false, "enabled" => false },
      "assets" => { "locales" => [] },
      "review_submissions" => []
    }
  end
end

tests = ReleaseHelpersTest.public_instance_methods(false).grep(/^test_/).sort
tests.each do |test|
  ReleaseHelpersTest.new.public_send(test)
  print "."
rescue StandardError => error
  warn "\n#{test} failed: #{error.message}"
  warn error.backtrace.join("\n")
  exit 1
end
puts "\n#{tests.length} release helper tests passed"
