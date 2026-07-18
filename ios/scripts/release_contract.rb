#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"
require "optparse"
require "pathname"
require "rexml/document"
require "rexml/xpath"

module PetitesDentsReleaseContract
  APP_NAME = "Petites Dents"
  BUNDLE_ID = "com.bnjdpn.petitesdents"
  TEAM_ID = "767SX34A7Z"
  VERSION = "1.0.0"
  SUPPORT_URL = "https://bnjdpn.github.io/petites-dents/#contact"
  PRIVACY_URL = "https://bnjdpn.github.io/petites-dents/privacy.html"
  FORMSPREE_ENDPOINT = "https://formspree.io/f/mykqbyyw"
  LOCALES = %w[en-US en-GB fr-FR].freeze
  SCENES = %w[01_Mouth 02_ToothDetail 03_History 04_ExportAndSupport].freeze
  DISPLAY_TYPES = %w[APP_IPHONE_67 APP_IPAD_PRO_3GEN_129].freeze
  TIPS = %w[
    com.bnjdpn.petitesdents.tip.cafe
    com.bnjdpn.petitesdents.tip.merci
    com.bnjdpn.petitesdents.tip.soutien
  ].freeze
  REQUIRED_LANES = %w[
    setup_asc release_contract asc_status metadata screenshots
    upload_screenshots upload_previews build_release upload_release
    submit_review release_quick pricing iap_status iap_sync
  ].freeze
  METADATA_LIMITS = {
    "name.txt" => 30,
    "subtitle.txt" => 30,
    "keywords.txt" => 100,
    "promotional_text.txt" => 170,
    "description.txt" => 4_000,
    "release_notes.txt" => 4_000
  }.freeze

  class Verifier
    attr_reader :errors

    def initialize(root)
      @root = File.realpath(root)
      @errors = []
    end

    def verify
      validate_git
      validate_projects
      config = validate_config
      validate_fastlane
      validate_metadata
      validate_rating
      validate_privacy
      validate_support
      validate_product_contract
      validate_ci
      validate_credentials
      validate_config_products(config) if config
      errors.empty?
    end

    private

    def validate_git
      branch = git("branch", "--show-current").strip
      pull_request_for_main = ENV["CI"] == "true" && ENV["GITHUB_BASE_REF"] == "main" && branch.empty?
      add("release branch must be main") unless branch == "main" || pull_request_for_main
      remote = git("remote", "get-url", "origin", allow_failure: true).strip
      if !remote.empty? && !remote.match?(%r{github\.com[:/]bnjdpn/petites-dents(?:\.git)?\z}i)
        add("origin must be bnjdpn/petites-dents")
      end
    end

    def validate_projects
      project = read("ios/project.yml")
      return unless project

      {
        "PRODUCT_BUNDLE_IDENTIFIER: #{BUNDLE_ID}" => "iOS bundle identifier mismatch",
        "DEVELOPMENT_TEAM: #{TEAM_ID}" => "iOS team mismatch",
        'TARGETED_DEVICE_FAMILY: "1,2"' => "iOS must target iPhone and iPad",
        "MARKETING_VERSION: #{VERSION}" => "iOS marketing version mismatch",
        "ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon" => "iOS AppIcon is not configured"
      }.each do |fragment, message|
        add(message) unless project.include?(fragment)
      end

      android = read("app/build.gradle.kts")
      if android
        add("Android application id mismatch") unless android.include?('applicationId = "com.bnjdpn.petitesdents"')
        add("Android version mismatch") unless android.include?('versionName = "1.0.0"')
        add("Android target SDK must be 36") unless android.include?("targetSdk = 36")
      end

      manifest = read("app/src/main/AndroidManifest.xml")
      add("Android INTERNET permission is forbidden") if manifest&.include?("android.permission.INTERNET")
      add("Android notification permission is forbidden") if manifest&.include?("POST_NOTIFICATIONS")
    end

    def validate_config
      contents = read("ios/fastlane/release_config.json")
      return nil unless contents

      config = JSON.parse(contents)
      {
        "app_name" => APP_NAME,
        "app_slug" => "PetitesDents",
        "bundle_id" => BUNDLE_ID,
        "version" => VERSION,
        "team_id" => TEAM_ID,
        "project" => "ios/PetitesDents.xcodeproj",
        "scheme" => "PetitesDents",
        "artifact_root" => "Builds/AppStore/PetitesDents",
        "price" => "0.00"
      }.each do |key, expected|
        add("release config mismatch: #{key}") unless config[key] == expected
      end
      add("media locales mismatch") unless config["media_locales"] == LOCALES
      add("screenshot scenes mismatch") unless config["screenshot_scenes"] == SCENES
      add("screenshot display types mismatch") unless config["required_screenshot_display_types"].sort == DISPLAY_TYPES.sort
      add("screenshot runtime mismatch") unless config["simulator_runtime"] == "com.apple.CoreSimulator.SimRuntime.iOS-26-2"

      policy = config["app_preview_policy"]
      unless policy.is_a?(Hash) &&
             policy["applicable"] == false &&
             policy["review_each_release"] == true &&
             !policy["reason"].to_s.strip.empty? &&
             config["app_preview_applicable"] == false
        add("App Preview non-applicable policy is incomplete")
      end
      config
    rescue JSON::ParserError => error
      add("invalid release config: #{error.message}")
      nil
    end

    def validate_fastlane
      fastfile = read("ios/fastlane/Fastfile")
      return unless fastfile

      REQUIRED_LANES.each do |lane|
        add("missing Fastlane lane: #{lane}") unless fastfile.match?(/\blane\s+:#{Regexp.escape(lane)}\b/)
      end
      {
        "upload_to_testflight" => /upload_to_testflight/i,
        "pilot" => /\bpilot\s*\(?/i,
        "latest_testflight_build_number" => /latest_testflight_build_number/i,
        "beta lane" => /\blane\s+:beta\b/i
      }.each do |label, pattern|
        add("forbidden TestFlight token: #{label}") if fastfile.match?(pattern)
      end
      add("build number must come from live App Store builds") unless fastfile.include?("app_store_build_number")
      add("release must select the exact uploaded build") unless fastfile.include?("select-build") && fastfile.include?("--expected-build")
      add("release must reread strict ASC state") unless fastfile.include?("--strict") && fastfile.include?("--require-selected-build")
      add("metadata must upload age rating") unless fastfile.include?("app_rating_config_path")
      add("screenshots must use the app-local generator") unless fastfile.include?("generate_screenshots.rb")
      add("review contact must stay in private environment values") unless %w[
        ASC_REVIEW_FIRST_NAME ASC_REVIEW_LAST_NAME ASC_REVIEW_PHONE_NUMBER ASC_REVIEW_EMAIL_ADDRESS
      ].all? { |key| fastfile.include?(key) }
    end

    def validate_metadata
      LOCALES.each do |locale|
        METADATA_LIMITS.each do |filename, limit|
          value = read("ios/fastlane/metadata/#{locale}/#{filename}")
          next unless value
          add("empty metadata: #{locale}/#{filename}") if value.strip.empty?
          add("#{locale}/#{filename} exceeds #{limit} characters") if value.strip.length > limit
        end
        support = read("ios/fastlane/metadata/#{locale}/support_url.txt")
        privacy = read("ios/fastlane/metadata/#{locale}/privacy_url.txt")
        add("support URL mismatch: #{locale}") if support && support.strip != SUPPORT_URL
        add("privacy URL mismatch: #{locale}") if privacy && privacy.strip != PRIVACY_URL
      end

      %w[en.lproj en-GB.lproj fr.lproj].each do |localization|
        read("ios/PetitesDents/Resources/#{localization}/Localizable.strings")
      end
      read("app/src/main/res/values/strings.xml")
      read("app/src/main/res/values-fr/strings.xml")
    end

    def validate_rating
      contents = read("ios/fastlane/metadata/app_rating_config.json")
      return unless contents
      rating = JSON.parse(contents)
      add("health and wellness age-rating answer must be true") unless rating["healthOrWellnessTopics"] == true
      add("medical information rating must be INFREQUENT") unless rating["medicalOrTreatmentInformation"] == "INFREQUENT"
      add("Kids category must remain unset") unless rating["kidsAgeBand"].nil?
      add("unrestricted web access must be false") unless rating["unrestrictedWebAccess"] == false
    rescue JSON::ParserError => error
      add("invalid age rating: #{error.message}")
    end

    def validate_privacy
      declaration = read("ios/fastlane/app_privacy_declaration.json")
      if declaration
        parsed = JSON.parse(declaration)
        add("App Privacy must declare no data collection") unless parsed["data_collected"] == false
        add("App Privacy must declare no tracking") unless parsed["tracking"] == false
        add("App Privacy API blocker must remain explicit") if parsed["blocker"].to_s.strip.empty?
      end

      manifest = read("ios/PetitesDents/Resources/PrivacyInfo.xcprivacy")
      if manifest
        document = REXML::Document.new(manifest)
        root = REXML::XPath.first(document, "/plist/dict")
        add("privacy manifest root is missing") unless root
        if root
          tracking = plist_value(root, "NSPrivacyTracking")
          collected = plist_value(root, "NSPrivacyCollectedDataTypes")
          add("privacy manifest must disable tracking") unless tracking&.name == "false"
          add("privacy manifest must declare no collected data") unless collected&.name == "array" && collected.elements.empty?
        end
      end
    rescue JSON::ParserError, REXML::ParseException => error
      add("invalid privacy declaration: #{error.message}")
    end

    def plist_value(dictionary, key_name)
      key = dictionary.get_elements("key").find { |entry| entry.text == key_name }
      key&.next_element
    end

    def validate_support
      html = read("docs/index.html")
      privacy = read("docs/privacy.html")
      return unless html && privacy

      add("support Formspree endpoint mismatch") unless html.include?("action=\"#{FORMSPREE_ENDPOINT}\"")
      %w[app _subject _gotcha category email app_version os_version message].each do |field|
        add("support form field missing: #{field}") unless html.match?(/name=["']#{Regexp.escape(field)}["']/)
      end
      add("support contact anchor is missing") unless html.match?(/id=["']contact["']/)

      public_contents = [
        read("README.md"),
        html,
        privacy,
        *LOCALES.map { |locale| read("ios/fastlane/metadata/#{locale}/description.txt") }
      ].compact.join("\n")
      add("public mailto link is forbidden") if public_contents.match?(/mailto\s*:/i)
      add("public developer address is forbidden") if public_contents.match?(/[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}/i)
    end

    def validate_product_contract
      ios_catalog = read("ios/PetitesDents/Models/ToothCatalog.swift")
      android_catalog = read("app/src/main/kotlin/com/bnjdpn/petitesdents/data/TeethData.kt")
      add("iOS tooth catalog must contain 20 definitions") unless ios_catalog&.scan(/tooth\(\d{2},/)&.length == 20
      add("Android tooth catalog must contain 20 definitions") unless android_catalog&.scan(/tooth\(\d{2},/)&.length == 20

      app_icon = absolute("ios/PetitesDents/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")
      add("missing 1024px ImageGen AppIcon") unless File.file?(app_icon)
      android_icon = absolute("app/src/main/ic_launcher-playstore.png")
      add("missing Android Play icon") unless File.file?(android_icon)
    end

    def validate_ci
      %w[
        .github/workflows/android-ci.yml
        .github/workflows/android-release-apk.yml
        .github/workflows/ios-ci.yml
      ].each { |path| read(path) }
    end

    def validate_credentials
      forbidden_extensions = %w[.p8 .p12 .cer .mobileprovision .keystore]
      paths = if Dir.exist?(absolute(".git"))
                git("ls-files").lines.map(&:strip)
              else
                Dir.glob(File.join(@root, "**", "*"), File::FNM_DOTMATCH)
                   .select { |path| File.file?(path) }
                   .map { |path| Pathname.new(path).relative_path_from(Pathname.new(@root)).to_s }
              end
      paths.each do |relative|
        basename = File.basename(relative)
        forbidden = basename == "asc_api_key.json" ||
                    basename == ".env" ||
                    basename.start_with?(".env.") ||
                    forbidden_extensions.include?(File.extname(basename).downcase)
        add("forbidden credential file: #{relative}") if forbidden
      end
    end

    def validate_config_products(config)
      products = config["iap_products"]
      definitions = config["iap"]
      ids = definitions.is_a?(Array) ? definitions.map { |item| item["product_id"] } : []
      add("IAP products must be exactly the three optional tips") unless products == TIPS && ids == TIPS
      add("Game Center must not be configured") unless config["leaderboard_ids"] == [] && config["leaderboards"] == []
      add("free pricing territory mismatch") unless config.dig("pricing", "target_price") == "0.00"
    end

    def read(relative)
      path = absolute(relative)
      unless File.file?(path)
        add("missing required release file: #{relative}")
        return nil
      end
      File.read(path)
    end

    def absolute(relative)
      File.join(@root, relative)
    end

    def git(*arguments, allow_failure: false)
      output, error, status = Open3.capture3("git", "-C", @root, *arguments)
      add("git #{arguments.join(' ')} failed: #{error.strip}") unless status.success? || allow_failure
      output
    end

    def add(message)
      @errors << message unless @errors.include?(message)
    end
  end

  class CLI
    def self.run(argv)
      OptionParser.new do |flags|
        flags.on("--check") {}
      end.parse!(argv)
      raise ArgumentError, "unknown arguments: #{argv.join(' ')}" unless argv.empty?

      root = File.realpath(File.join(__dir__, "..", ".."))
      verifier = Verifier.new(root)
      if verifier.verify
        puts "Petites Dents release contract: PASS"
        0
      else
        warn verifier.errors.join("\n")
        1
      end
    rescue OptionParser::ParseError, ArgumentError => error
      warn error.message
      1
    end
  end
end

exit PetitesDentsReleaseContract::CLI.run(ARGV) if $PROGRAM_NAME == __FILE__
