#!/usr/bin/env ruby
# frozen_string_literal: true

require "bigdecimal"
require "json"
require "optparse"
require "time"

def app_root
  File.expand_path("../..", __dir__)
end

def default_config_path
  File.join(app_root, "fastlane", "release_config.json")
end

def default_key_path
  File.join(app_root, "fastlane", "asc_api_key.json")
end

def load_config(path)
  return {} unless path && File.file?(path)

  JSON.parse(File.read(path))
end

def parse_options(argv)
  options = {
    config: default_config_path,
    key_path: ENV["ASC_API_KEY_PATH"] || default_key_path
  }

  OptionParser.new do |opts|
    opts.on("--bundle-id ID") { |value| options[:bundle_id] = value }
    opts.on("--config PATH") { |value| options[:config] = value }
    opts.on("--key-path PATH") { |value| options[:key_path] = value }
    opts.on("--version VERSION") { |value| options[:version] = value }
    opts.on("--expected-build NUMBER") { |value| options[:expected_build] = value }
    opts.on("--strict") { options[:strict] = true }
    opts.on("--require-selected-build") { options[:require_selected_build] = true }
    opts.on("--require-review-submission") { options[:require_review_submission] = true }
    opts.on("--json") { options[:json] = true }
  end.parse!(argv)

  config = load_config(options[:config])
  options[:bundle_id] ||= config["bundle_id"]
  options[:version] ||= config["version"]
  options[:expected_iap] = config.fetch("iap", [])
  options[:expected_leaderboards] = config.fetch("leaderboard_ids", [])
  options[:leaderboard_definitions] = config.fetch("leaderboards", [])
  options[:expected_price] = config["price"]
  options[:app_preview_applicable] = config["app_preview_applicable"] == true
  options[:required_locales] = config.fetch("required_locales", %w[en-US fr-FR])
  options[:required_screenshot_display_types] = config.fetch("required_screenshot_display_types", [])
  options[:required_preview_types] = config.fetch("required_preview_types", [])
  fastlane_root = File.dirname(options[:config])
  options[:expected_age_rating] = load_config(File.join(fastlane_root, "metadata", "app_rating_config.json"))
  options[:app_privacy_declaration] = load_config(File.join(fastlane_root, "app_privacy_declaration.json"))

  abort "--bundle-id is required" if options[:bundle_id].to_s.empty?
  abort "Provide ASC_API_KEY_PATH or APP_STORE_CONNECT_API_KEY_* environment credentials" unless AutonomousAscCredentials.available?(key_path: options[:key_path])

  options
end

def included_index(included)
  included.each_with_object({}) do |item, index|
    index[[item.fetch("type"), item.fetch("id")]] = item
  end
end

def normalize_recurrence_start_date(value)
  return nil if value.nil?

  Time.iso8601(value.to_s).utc.iso8601
rescue ArgumentError
  value
end

def game_center_attribute_matches?(key, expected, actual)
  if key == "recurrence_start_date"
    normalize_recurrence_start_date(actual) == normalize_recurrence_start_date(expected)
  elsif %w[recurrence_duration recurrence_rule].include?(key)
    actual == expected
  else
    actual.to_s == expected.to_s
  end
end

def find_app(client, bundle_id)
  app = client.get("/v1/apps", {
    "filter[bundleId]" => bundle_id,
    "fields[apps]" => "name,bundleId,sku,primaryLocale"
  }).fetch("data").first
  abort "App not found for bundle id #{bundle_id}" unless app

  app
end

def versions_for_app(client, app_id)
  response = client.get_all("/v1/apps/#{app_id}/appStoreVersions", {
    "filter[platform]" => "IOS",
    "include" => "build",
    "fields[appStoreVersions]" => "versionString,appStoreState,platform,createdDate,build",
    "fields[builds]" => "version,processingState,uploadedDate,expired",
    "limit" => "200"
  })
  [response.fetch("data"), included_index(response.fetch("included", []))]
end

def select_version(versions, requested_version)
  return versions.find { |item| item.dig("attributes", "versionString") == requested_version } if requested_version

  versions.first
end

def build_payload(build)
  return nil unless build

  {
    "id" => build.fetch("id"),
    "build" => build.dig("attributes", "version"),
    "state" => build.dig("attributes", "processingState"),
    "uploaded" => build.dig("attributes", "uploadedDate"),
    "expired" => build.dig("attributes", "expired")
  }
end

def selected_build(client, version, included)
  return nil unless version

  build_id = version.dig("relationships", "build", "data", "id")
  return build_payload(included[["builds", build_id]]) if build_id && included[["builds", build_id]]

  response = client.get("/v1/appStoreVersions/#{version.fetch("id")}/build", {
    "fields[builds]" => "version,processingState,uploadedDate,expired"
  })
  build_payload(response["data"])
end

def recent_builds(client, app_id, marketing_version = nil)
  filters = {
    "filter[app]" => app_id,
    "filter[preReleaseVersion.platform]" => "IOS",
    "sort" => "-uploadedDate",
    "fields[builds]" => "version,processingState,uploadedDate,expired",
    "limit" => "10"
  }
  filters["filter[preReleaseVersion.version]"] = marketing_version if marketing_version
  client.get_all("/v1/builds", filters).fetch("data").map { |build| build_payload(build) }
end

def review_submissions(client, app_id)
  client.get_all("/v1/apps/#{app_id}/reviewSubmissions", {
    "fields[reviewSubmissions]" => "state,submittedDate,platform",
    "limit" => "10"
  }).fetch("data").map do |submission|
    items = client.get_all("/v1/reviewSubmissions/#{submission.fetch("id")}/items", {
      "include" => "appStoreVersion,gameCenterLeaderboardVersion",
      "fields[reviewSubmissionItems]" => "state,appStoreVersion,gameCenterLeaderboardVersion",
      "fields[appStoreVersions]" => "versionString,appStoreState,platform",
      "fields[gameCenterLeaderboardVersions]" => "version,state",
      "limit" => "200"
    })
    included = included_index(items.fetch("included", []))
    {
      "id" => submission.fetch("id"),
      "state" => submission.dig("attributes", "state"),
      "submitted" => submission.dig("attributes", "submittedDate"),
      "items" => items.fetch("data").map do |item|
        app_version = item.dig("relationships", "appStoreVersion", "data")
        leaderboard_version = item.dig("relationships", "gameCenterLeaderboardVersion", "data")
        resource = app_version || leaderboard_version
        version = app_version && included[[app_version.fetch("type"), app_version.fetch("id")]]
        {
          "id" => item.fetch("id"),
          "state" => item.dig("attributes", "state"),
          "resource_type" => resource && resource.fetch("type"),
          "resource_id" => resource && resource.fetch("id"),
          "version" => version&.dig("attributes", "versionString"),
          "version_state" => version&.dig("attributes", "appStoreState")
        }
      end
    }
  end
end

def game_center_app_version_status(client, version)
  return { "configured" => false, "enabled" => false } unless version

  response = client.get(
    "/v1/appStoreVersions/#{version.fetch('id')}/gameCenterAppVersion",
    { "fields[gameCenterAppVersions]" => "enabled" },
    optional: true
  )
  app_version = response && response["data"]
  return { "configured" => false, "enabled" => false } unless app_version

  {
    "configured" => true,
    "id" => app_version.fetch("id"),
    "enabled" => app_version.dig("attributes", "enabled") == true
  }
end

def age_rating_status(client, app_id, expected)
  app_infos = client.get_all("/v1/apps/#{app_id}/appInfos", {
    "fields[appInfos]" => "state,appStoreAgeRating,ageRatingDeclaration",
    "limit" => "200"
  }).fetch("data")
  app_info = app_infos.find { |item| item.dig("attributes", "state") == "PREPARE_FOR_SUBMISSION" } || app_infos.first
  return {
    "configured" => false,
    "matches_expected" => false,
    "mismatches" => ["no app info exists"]
  } unless app_info

  response = client.get("/v1/appInfos/#{app_info.fetch('id')}/ageRatingDeclaration", {
    "fields[ageRatingDeclarations]" => expected.keys.join(",")
  })
  declaration = response.fetch("data")
  actual = declaration.fetch("attributes", {})
  mismatches = expected.each_with_object([]) do |(key, value), result|
    result << "#{key} expected=#{value.inspect} actual=#{actual[key].inspect}" unless actual[key] == value
  end
  {
    "configured" => true,
    "app_info_id" => app_info.fetch("id"),
    "declaration_id" => declaration.fetch("id"),
    "app_info_state" => app_info.dig("attributes", "state"),
    "derived_rating" => app_info.dig("attributes", "appStoreAgeRating"),
    "expected" => expected,
    "actual" => actual.slice(*expected.keys),
    "mismatches" => mismatches,
    "matches_expected" => mismatches.empty?
  }
end

def app_privacy_status(declaration)
  {
    "declared_locally" => declaration["data_collected"] == false,
    "data_collected" => declaration["data_collected"],
    "tracking" => declaration["tracking"],
    "public_api_supported" => declaration["public_api_supported"] == true,
    "verified_live" => declaration["live_verified"] == true,
    "blocker" => declaration["blocker"]
  }
end

def media_set_status(client, path, fields:, state_key:, type_key:, type_value:)
  resources = client.get_all(path, {
    fields => "fileName,#{state_key}",
    "limit" => "200"
  }).fetch("data").map do |resource|
    state_payload = resource.dig("attributes", state_key) || {}
    {
      "id" => resource.fetch("id"),
      "file_name" => resource.dig("attributes", "fileName"),
      "state" => state_payload["state"],
      "errors" => state_payload.fetch("errors", []),
      "warnings" => state_payload.fetch("warnings", [])
    }
  end
  complete = resources.count { |resource| resource["state"] == "COMPLETE" }
  {
    type_key => type_value,
    "count" => resources.length,
    "complete_count" => complete,
    "incomplete_states" => resources.reject { |resource| resource["state"] == "COMPLETE" }
                                    .map { |resource| resource["state"] || "UNKNOWN" }.uniq.sort,
    "items" => resources
  }
end

def asset_count(client, path, fields)
  client.get_all(path, fields.merge("limit" => "200")).fetch("data").length
end

def app_store_assets(client, version)
  return { "locales" => [], "screenshot_count" => 0, "preview_count" => 0 } unless version

  localizations = client.get_all("/v1/appStoreVersions/#{version.fetch("id")}/appStoreVersionLocalizations", {
    "fields[appStoreVersionLocalizations]" => "locale",
    "limit" => "200"
  }).fetch("data")

  locales = localizations.map do |localization|
    screenshot_sets = client.get_all("/v1/appStoreVersionLocalizations/#{localization.fetch("id")}/appScreenshotSets", {
      "fields[appScreenshotSets]" => "screenshotDisplayType",
      "limit" => "200"
    }).fetch("data")
    preview_sets = client.get_all("/v1/appStoreVersionLocalizations/#{localization.fetch("id")}/appPreviewSets", {
      "fields[appPreviewSets]" => "previewType",
      "limit" => "200"
    }).fetch("data")

    screenshots = screenshot_sets.map do |set|
      media_set_status(
        client,
        "/v1/appScreenshotSets/#{set.fetch('id')}/appScreenshots",
        fields: "fields[appScreenshots]",
        state_key: "assetDeliveryState",
        type_key: "display_type",
        type_value: set.dig("attributes", "screenshotDisplayType")
      )
    end
    previews = preview_sets.map do |set|
      media_set_status(
        client,
        "/v1/appPreviewSets/#{set.fetch('id')}/appPreviews",
        fields: "fields[appPreviews]",
        state_key: "videoDeliveryState",
        type_key: "preview_type",
        type_value: set.dig("attributes", "previewType")
      )
    end

    {
      "locale" => localization.dig("attributes", "locale"),
      "screenshots" => screenshots,
      "previews" => previews,
      "screenshot_count" => screenshots.sum { |item| item.fetch("complete_count") },
      "preview_count" => previews.sum { |item| item.fetch("complete_count") }
    }
  end

  {
    "locales" => locales,
    "screenshot_count" => locales.sum { |item| item.fetch("screenshot_count") },
    "preview_count" => locales.sum { |item| item.fetch("preview_count") }
  }
end

def pricing_status(client, app_id, expected_price)
  schedule = client.get("/v1/apps/#{app_id}/appPriceSchedule", {
    "fields[appPriceSchedules]" => "baseTerritory,manualPrices,automaticPrices"
  }).fetch("data")
  base = client.get("/v1/appPriceSchedules/#{schedule.fetch("id")}/baseTerritory", {
    "fields[territories]" => "currency"
  }).fetch("data")

  prices = %w[manualPrices automaticPrices].flat_map do |relationship|
    response = client.get_all("/v1/appPriceSchedules/#{schedule.fetch("id")}/#{relationship}", {
      "include" => "appPricePoint,territory",
      "fields[appPrices]" => "manual,startDate,endDate,appPricePoint,territory",
      "fields[appPricePoints]" => "customerPrice,proceeds,territory",
      "fields[territories]" => "currency",
      "limit" => "200"
    })
    included = included_index(response.fetch("included", []))
    response.fetch("data").map do |price|
      point_id = price.dig("relationships", "appPricePoint", "data", "id")
      territory_id = price.dig("relationships", "territory", "data", "id")
      point = included[["appPricePoints", point_id]]
      territory = included[["territories", territory_id]]
      {
        "relationship" => relationship,
        "territory" => territory_id,
        "currency" => territory&.dig("attributes", "currency"),
        "customer_price" => point&.dig("attributes", "customerPrice"),
        "start_date" => price.dig("attributes", "startDate"),
        "end_date" => price.dig("attributes", "endDate")
      }
    end
  end

  current_prices = prices.select { |price| price["end_date"].nil? }
  observed_prices = current_prices.map { |price| price["customer_price"] }.compact.uniq
  matches_expected = begin
    expected = BigDecimal(expected_price.to_s)
    !observed_prices.empty? && observed_prices.all? { |price| BigDecimal(price.to_s) == expected }
  rescue ArgumentError
    false
  end
  {
    "schedule_id" => schedule.fetch("id"),
    "base_territory" => base&.fetch("id"),
    "base_currency" => base&.dig("attributes", "currency"),
    "manual_price_count" => asset_count(client, "/v1/appPriceSchedules/#{schedule.fetch("id")}/manualPrices", {
      "fields[appPrices]" => "manual,startDate,endDate"
    }),
    "automatic_price_count" => asset_count(client, "/v1/appPriceSchedules/#{schedule.fetch("id")}/automaticPrices", {
      "fields[appPrices]" => "manual,startDate,endDate"
    }),
    "current_prices" => current_prices,
    "expected_price" => expected_price,
    "matches_expected" => matches_expected
  }
end

def game_center_status(client, app_id, expected_ids)
  response = client.get("/v1/apps/#{app_id}/gameCenterDetail", {}, optional: true)
  detail = response && response["data"]
  return {
    "configured" => false,
    "expected_ids" => expected_ids,
    "actual_ids" => [],
    "missing_ids" => expected_ids,
    "unexpected_ids" => [],
    "items" => []
  } unless detail

  leaderboards = client.get_all("/v1/gameCenterDetails/#{detail.fetch("id")}/gameCenterLeaderboardsV2", {
    "fields[gameCenterLeaderboards]" => "referenceName,vendorIdentifier,defaultFormatter,submissionType,scoreSortType,scoreRangeStart,scoreRangeEnd,recurrenceStartDate,recurrenceDuration,recurrenceRule,visibility,archived,versions",
    "limit" => "200"
  }).fetch("data")
  items = leaderboards.map do |leaderboard|
    versions = client.get_all("/v2/gameCenterLeaderboards/#{leaderboard.fetch("id")}/versions", {
      "include" => "localizations",
      "fields[gameCenterLeaderboardVersions]" => "version,state,localizations",
      "fields[gameCenterLeaderboardLocalizations]" => "locale,name,formatterSuffix,formatterSuffixSingular,description",
      "limit" => "200",
      "limit[localizations]" => "50"
    })
    latest = versions.fetch("data").max_by { |version| version.dig("attributes", "version").to_i }
    included = included_index(versions.fetch("included", []))
    localization_links = latest&.dig("relationships", "localizations", "data") || []
    localizations = localization_links.filter_map do |linkage|
      resource = included[[linkage.fetch("type"), linkage.fetch("id")]]
      next unless resource

      {
        "locale" => resource.dig("attributes", "locale"),
        "name" => resource.dig("attributes", "name"),
        "suffix" => resource.dig("attributes", "formatterSuffix"),
        "singular_suffix" => resource.dig("attributes", "formatterSuffixSingular"),
        "description" => resource.dig("attributes", "description")
      }
    end
    {
      "id" => leaderboard.fetch("id"),
      "vendor_id" => leaderboard.dig("attributes", "vendorIdentifier"),
      "reference_name" => leaderboard.dig("attributes", "referenceName"),
      "default_formatter" => leaderboard.dig("attributes", "defaultFormatter"),
      "submission_type" => leaderboard.dig("attributes", "submissionType"),
      "score_sort_type" => leaderboard.dig("attributes", "scoreSortType"),
      "score_range_start" => leaderboard.dig("attributes", "scoreRangeStart"),
      "score_range_end" => leaderboard.dig("attributes", "scoreRangeEnd"),
      "recurrence_start_date" => normalize_recurrence_start_date(
        leaderboard.dig("attributes", "recurrenceStartDate")
      ),
      "recurrence_duration" => leaderboard.dig("attributes", "recurrenceDuration"),
      "recurrence_rule" => leaderboard.dig("attributes", "recurrenceRule"),
      "visibility" => leaderboard.dig("attributes", "visibility"),
      "archived" => leaderboard.dig("attributes", "archived"),
      "version_id" => latest&.fetch("id"),
      "version" => latest&.dig("attributes", "version"),
      "state" => latest&.dig("attributes", "state"),
      "locales" => localizations.map { |localization| localization["locale"] }.compact.sort,
      "localizations" => localizations.sort_by { |localization| localization["locale"].to_s }
    }
  end
  actual_ids = items.map { |item| item["vendor_id"] }.compact
  {
    "configured" => true,
    "detail_id" => detail.fetch("id"),
    "expected_ids" => expected_ids,
    "actual_ids" => actual_ids,
    "missing_ids" => expected_ids - actual_ids,
    "unexpected_ids" => actual_ids - expected_ids,
    "items" => items
  }
end

def iap_status(client, app_id, expected_iap)
  actual = client.get_all("/v1/apps/#{app_id}/inAppPurchasesV2", {
    "fields[inAppPurchases]" => "name,productId,inAppPurchaseType,state,reviewNote",
    "limit" => "200"
  }).fetch("data").map do |item|
    {
      "id" => item.fetch("id"),
      "product_id" => item.dig("attributes", "productId"),
      "name" => item.dig("attributes", "name"),
      "type" => item.dig("attributes", "inAppPurchaseType"),
      "state" => item.dig("attributes", "state")
    }
  end
  expected_ids = expected_iap.map { |item| item["product_id"] || item["productId"] || item["id"] }.compact
  actual_ids = actual.map { |item| item["product_id"] }.compact

  {
    "expected_count" => expected_iap.length,
    "actual_count" => actual.length,
    "missing_product_ids" => expected_ids - actual_ids,
    "unexpected_product_ids" => actual_ids - expected_ids,
    "items" => actual
  }
end

def strict_errors(payload, options)
  errors = []
  version = payload["version"]
  if version.nil?
    errors << "marketing version #{options[:version]} does not exist"
  elsif version["version"] != options[:version]
    errors << "marketing version mismatch: expected #{options[:version]}, got #{version["version"]}"
  end

  expected_build = if options[:expected_build]
                     payload.fetch("recent_builds").find do |candidate|
                       candidate["build"].to_s == options[:expected_build].to_s
                     end
                   end
  if options[:expected_build]
    if expected_build.nil?
      errors << "expected build #{options[:expected_build]} is not uploaded"
    else
      unless expected_build["state"] == "VALID"
        errors << "expected build #{options[:expected_build]} is not VALID: #{expected_build["state"]}"
      end
      errors << "expected build #{options[:expected_build]} is expired" if expected_build["expired"] == true
    end
  end

  build = payload["selected_build"]
  if build
    errors << "selected build #{build["build"]} is expired" if build["expired"] == true
    if options[:require_selected_build] && options[:expected_build] && build["build"].to_s != options[:expected_build].to_s
      errors << "selected build mismatch: expected #{options[:expected_build]}, got #{build["build"]}"
    end
  elsif options[:require_selected_build]
    errors << "no build is selected for #{options[:version]}"
  end

  pricing = payload.fetch("pricing")
  errors << "price does not match free target #{pricing["expected_price"]}" unless pricing["matches_expected"]

  iap = payload.fetch("iap")
  unless iap["missing_product_ids"].empty? && iap["unexpected_product_ids"].empty?
    errors << "IAP configuration drift: missing=#{iap["missing_product_ids"].join(',')} unexpected=#{iap["unexpected_product_ids"].join(',')}"
  end


  age_rating = payload.fetch("age_rating")
  unless age_rating["configured"] != false && age_rating["matches_expected"]
    errors << "age rating declaration mismatch: #{age_rating.fetch('mismatches', []).join('; ')}"
  end

  app_privacy = payload.fetch("app_privacy")
  explicit_public_api_boundary =
    app_privacy["declared_locally"] == true &&
    app_privacy["data_collected"] == false &&
    app_privacy["tracking"] == false &&
    app_privacy["public_api_supported"] == false &&
    !app_privacy["blocker"].to_s.empty?
  unless app_privacy["verified_live"] == true || explicit_public_api_boundary
    errors << "App Privacy declaration is neither live-verified nor covered by an explicit public API boundary"
  end

  game_center = payload.fetch("game_center")
  game_center_required =
    options.fetch(:expected_leaderboards).any? || options.fetch(:leaderboard_definitions).any?
  errors << "Game Center detail is not configured" if game_center_required && !game_center["configured"]
  errors << "missing Game Center leaderboards: #{game_center["missing_ids"].join(',')}" unless game_center["missing_ids"].empty?
  errors << "unexpected Game Center leaderboards: #{game_center["unexpected_ids"].join(',')}" unless game_center["unexpected_ids"].empty?
  options.fetch(:leaderboard_definitions).each do |definition|
    item = game_center.fetch("items", []).find { |candidate| candidate["vendor_id"] == definition["id"] }
    next unless item

    errors << "Game Center leaderboard is archived: #{definition["id"]}" if item["archived"] == true
    errors << "Game Center leaderboard has no version: #{definition["id"]}" if item["version_id"].to_s.empty?
    expected_attributes = {
      "reference_name" => definition["reference_name"],
      "default_formatter" => definition["default_formatter"],
      "submission_type" => definition["submission_type"],
      "score_sort_type" => definition["score_sort_type"],
      "score_range_start" => definition["score_range_start"],
      "score_range_end" => definition["score_range_end"],
      "recurrence_start_date" => definition["recurrence_start_date"],
      "recurrence_duration" => definition["recurrence_duration"],
      "recurrence_rule" => definition["recurrence_rule"],
      "visibility" => "SHOW_FOR_ALL"
    }
    unless expected_attributes.all? do |key, value|
      game_center_attribute_matches?(key, value, item[key])
    end
      errors << "Game Center leaderboard configuration mismatch: #{definition['id']}"
    end
    if options[:require_review_submission]
      submitted_states = %w[WAITING_FOR_REVIEW IN_REVIEW ACCEPTED PENDING_RELEASE LIVE]
      unless submitted_states.include?(item["state"])
        errors << "Game Center leaderboard version is not submitted or live: #{definition["id"]} state=#{item["state"]}"
      end
    end
    required = definition.fetch("localizations", {}).keys
    missing_locales = required - item.fetch("locales", [])
    errors << "Game Center leaderboard #{definition["id"]} missing locales: #{missing_locales.join(',')}" unless missing_locales.empty?
    definition.fetch("localizations", {}).each do |locale, expected|
      actual = item.fetch("localizations", []).find { |localization| localization["locale"] == locale }
      next unless actual

      expected_localization = {
        "name" => expected["name"],
        "suffix" => expected["suffix"],
        "singular_suffix" => expected["singular_suffix"]
      }
      unless expected_localization.all? { |key, value| actual[key] == value }
        errors << "Game Center leaderboard localization mismatch: #{definition['id']} / #{locale}"
      end
    end
  end

  game_center_app_version = payload.fetch("game_center_app_version")
  if game_center_required && !(game_center_app_version["configured"] && game_center_app_version["enabled"])
    errors << "Game Center is not enabled for marketing version #{options[:version]}"
  end

  assets = payload.fetch("assets")
  locale_assets = assets.fetch("locales").each_with_object({}) do |locale, index|
    index[locale["locale"]] = locale
  end
  options.fetch(:required_locales).each do |locale|
    entry = locale_assets[locale]
    options.fetch(:required_screenshot_display_types, []).each do |display_type|
      media_set = entry&.fetch("screenshots", [])&.find { |set| set["display_type"] == display_type }
      if media_set.nil? || media_set["count"].to_i.zero?
        errors << "App Store screenshots missing for #{locale} / #{display_type}"
      elsif media_set["complete_count"].to_i != media_set["count"].to_i
        errors << "App Store screenshots not COMPLETE for #{locale} / #{display_type}: #{media_set.fetch('incomplete_states', []).join(',')}"
      end
    end
    next unless options[:app_preview_applicable]

    options.fetch(:required_preview_types, []).each do |preview_type|
      media_set = entry&.fetch("previews", [])&.find { |set| set["preview_type"] == preview_type }
      if media_set.nil? || media_set["count"].to_i.zero?
        errors << "App Preview missing for #{locale} / #{preview_type}"
      elsif media_set["complete_count"].to_i != media_set["count"].to_i
        errors << "App Preview not COMPLETE for #{locale} / #{preview_type}: #{media_set.fetch('incomplete_states', []).join(',')}"
      end
    end
  end

  if options[:require_review_submission]
    required_leaderboard_version_ids = game_center.fetch("items", []).map do |item|
      item["version_id"]
    end.compact
    submitted_states = %w[WAITING_FOR_REVIEW IN_REVIEW]
    submitted = payload.fetch("review_submissions").any? do |submission|
      items = submission.fetch("items")
      has_version = items.any? do |item|
        item["resource_type"] == "appStoreVersions" && item["version"] == options[:version]
      end
      leaderboard_ids = items.select do |item|
        item["resource_type"] == "gameCenterLeaderboardVersions"
      end.map { |item| item["resource_id"] }
      submitted_states.include?(submission["state"]) &&
        has_version &&
        (required_leaderboard_version_ids - leaderboard_ids).empty?
    end
    unless submitted
      errors << "no submitted review submission contains #{options[:version]} and all Game Center versions"
    end
  end
  errors
end

def print_human(payload)
  puts "App: #{payload.dig("app", "name")} (#{payload.dig("app", "bundle_id")}) id=#{payload.dig("app", "id")}"
  if payload["version"]
    puts "Version: #{payload.dig("version", "version")} state=#{payload.dig("version", "state")} id=#{payload.dig("version", "id")}"
  else
    puts "Version: none"
  end
  selected = payload["selected_build"]
  puts selected ? "Selected build: #{selected["build"]} state=#{selected["state"]} uploaded=#{selected["uploaded"]}" : "Selected build: none"
  puts "Recent builds:"
  payload.fetch("recent_builds").each { |build| puts "  build=#{build["build"]} state=#{build["state"]} uploaded=#{build["uploaded"]}" }
  assets = payload.fetch("assets")
  puts "Assets: screenshots=#{assets.fetch("screenshot_count")} previews=#{assets.fetch("preview_count")}"
  assets.fetch("locales").each do |locale|
    puts "  #{locale["locale"]}: screenshots=#{locale["screenshot_count"]} previews=#{locale["preview_count"]}"
    locale.fetch("screenshots", []).each do |set|
      puts "    screenshots #{set["display_type"]}: complete=#{set["complete_count"]}/#{set["count"]} incomplete=#{set["incomplete_states"].join(',')}"
    end
    locale.fetch("previews", []).each do |set|
      puts "    previews #{set["preview_type"]}: complete=#{set["complete_count"]}/#{set["count"]} incomplete=#{set["incomplete_states"].join(',')}"
    end
  end
  rating = payload.fetch("age_rating")
  puts "Age rating: configured=#{rating["configured"]} derived=#{rating["derived_rating"]} matches=#{rating["matches_expected"]}"
  rating.fetch("mismatches", []).each { |mismatch| puts "  #{mismatch}" }
  privacy = payload.fetch("app_privacy")
  puts "App Privacy: local_no_data=#{privacy["declared_locally"]} live_verified=#{privacy["verified_live"]} public_api_supported=#{privacy["public_api_supported"]}"
  puts "  blocker=#{privacy["blocker"]}" unless privacy["verified_live"]
  pricing = payload.fetch("pricing")
  prices = pricing.fetch("current_prices")
  price_summary = prices.map { |price| "#{price["territory"]}=#{price["customer_price"]} #{price["currency"]}" }.join(",")
  puts "Pricing: schedule=#{pricing["schedule_id"]} base=#{pricing["base_territory"]} currency=#{pricing["base_currency"]} manual=#{pricing["manual_price_count"]} automatic=#{pricing["automatic_price_count"]} current=#{price_summary} expected=#{pricing["expected_price"]} matches=#{pricing["matches_expected"]}"
  iap = payload.fetch("iap")
  puts "IAP: expected=#{iap["expected_count"]} actual=#{iap["actual_count"]} missing=#{iap["missing_product_ids"].join(",")} unexpected=#{iap["unexpected_product_ids"].join(",")}"
  game_center = payload.fetch("game_center")
  puts "Game Center: configured=#{game_center["configured"]} missing=#{game_center["missing_ids"].join(",")} unexpected=#{game_center.fetch("unexpected_ids", []).join(",")}"
  game_center.fetch("items", []).each do |item|
    puts "  #{item["vendor_id"]}: version=#{item["version"]} state=#{item["state"]} archived=#{item["archived"]} locales=#{item["locales"].join(',')}"
  end
  app_version = payload.fetch("game_center_app_version")
  puts "Game Center app version: configured=#{app_version["configured"]} enabled=#{app_version["enabled"]} id=#{app_version["id"]}"
  puts "Review submissions:"
  if payload.fetch("review_submissions").empty?
    puts "  none"
  else
    payload.fetch("review_submissions").each do |submission|
      versions = submission.fetch("items").map { |item| item["version"] }.compact.uniq.join(",")
      puts "  id=#{submission["id"]} state=#{submission["state"]} submitted=#{submission["submitted"]} versions=#{versions}"
    end
  end
  checks = payload.fetch("checks")
  puts "Strict readback: #{checks["passed"] ? 'PASS' : 'FAIL'}"
  checks.fetch("errors").each { |error| puts "  - #{error}" }
end

if __FILE__ == $PROGRAM_NAME
  require_relative "client"

begin
  options = parse_options(ARGV)
  client = AutonomousAscClient.new(key_path: options.fetch(:key_path))
  app = find_app(client, options.fetch(:bundle_id))
  versions, included = versions_for_app(client, app.fetch("id"))
  version = select_version(versions, options[:version])

  payload = {
    "app" => {
      "id" => app.fetch("id"),
      "name" => app.dig("attributes", "name"),
      "bundle_id" => app.dig("attributes", "bundleId"),
      "sku" => app.dig("attributes", "sku"),
      "primary_locale" => app.dig("attributes", "primaryLocale")
    },
    "version" => version && {
      "id" => version.fetch("id"),
      "version" => version.dig("attributes", "versionString"),
      "state" => version.dig("attributes", "appStoreState"),
      "created" => version.dig("attributes", "createdDate")
    },
    "selected_build" => selected_build(client, version, included),
    "recent_builds" => recent_builds(client, app.fetch("id"), options[:version]),
    "review_submissions" => review_submissions(client, app.fetch("id")),
    "assets" => app_store_assets(client, version),
    "pricing" => pricing_status(client, app.fetch("id"), options.fetch(:expected_price)),
    "iap" => iap_status(client, app.fetch("id"), options.fetch(:expected_iap)),
    "age_rating" => age_rating_status(client, app.fetch("id"), options.fetch(:expected_age_rating)),
    "app_privacy" => app_privacy_status(options.fetch(:app_privacy_declaration)),
    "game_center" => game_center_status(client, app.fetch("id"), options.fetch(:expected_leaderboards)),
    "game_center_app_version" => game_center_app_version_status(client, version)
  }
  errors = strict_errors(payload, options)
  payload["checks"] = {
    "strict" => options[:strict] == true,
    "passed" => errors.empty?,
    "errors" => errors
  }

  if options[:json]
    puts JSON.pretty_generate(payload)
  else
    print_human(payload)
  end
  exit 1 if options[:strict] && !errors.empty?
rescue AutonomousAscError => e
  warn e.message
  exit 1
end
end
