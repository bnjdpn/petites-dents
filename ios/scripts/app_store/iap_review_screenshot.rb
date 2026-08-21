#!/usr/bin/env ruby
# frozen_string_literal: true

# Produces the App Store Connect review screenshot of the in-app purchase.
#
# App Review refuses a new in-app purchase that carries no review screenshot:
# the product stays in MISSING_METADATA and can never be attached to the
# version submission. Nothing else in this repository produced that file, so
# `release_config.json.iap_review_screenshot` pointed at a path that did not
# exist and `iap_sync` failed late, inside `File.binread`.
#
# The capture comes from `PetitesDentsUITests.testPaywallScreenshot`, which
# opens the paywall with `-paywall-screenshot`, loads the shipped
# `PetitesDents.storekit` through `SKTestSession` — so the price is a real
# `Product.displayPrice`, never a hardcoded string — pins the storefront to the
# base territory of `fastlane/pro_products.json`, scrolls the purchase card into
# frame and attaches the screen as "Paywall" plus the rendered price as
# "PaywallPrice". This script runs that one test on an exact, leased simulator,
# exports both attachments from the `.xcresult`, and writes them where
# `release_config.json` says they live.
#
# The destination is a versioned directory (`ios/review_assets/`), not the
# gitignored `Builds/` tree: a capture that disappears at the first clone is not
# evidence, and `scripts/pre_submission_gate.rb` refuses it. Next to the PNG it
# writes a sidecar JSON — the rendered price and the SHA-256 of the image — so
# `scripts/release_contract.rb` can check by machine that the pixels App Review
# will look at state the price the spec sells at.

require "digest"
require "fileutils"
require "json"
require "open3"
require "optparse"
require "time"

module PetitesDentsIapReviewScreenshot
  class Error < StandardError; end

  APP_ROOT = File.expand_path("../..", __dir__)
  REPO_ROOT = File.expand_path("..", APP_ROOT)
  UDID = /\A[0-9A-F]{8}(?:-[0-9A-F]{4}){3}-[0-9A-F]{12}\z/i
  TEST_IDENTIFIER = "PetitesDentsUITests/PetitesDentsUITests/testPaywallScreenshot"
  SCREENSHOT_ATTACHMENT = "Paywall"
  # The price string the paywall actually rendered. Attached by the same test,
  # from the same screen, in the same run as the PNG.
  PRICE_ATTACHMENT = "PaywallPrice"
  SPEC_PATH = File.expand_path("fastlane/pro_products.json", APP_ROOT)
  # xcresulttool decorates every attachment with its index and a UUID:
  # `Paywall` comes back as `Paywall_0_2C9A....png`. Matching on the prefix was
  # enough until a second attachment named `PaywallPrice` appeared — a prefix
  # match then finds both, and picks whichever came first. Strip the decoration
  # and compare for equality instead.
  DECORATED_NAME = /\A(?<name>.+?)_\d+_[0-9A-Fa-f-]{36}\.[A-Za-z0-9]+\z/
  # App Review reads the primary locale of the listing, so the capture is taken
  # in that language whatever the simulator was left in by the media matrix.
  LOCALE_LANGUAGE = {
    "en-US" => %w[en US],
    "en-GB" => %w[en GB],
    "fr-FR" => %w[fr FR]
  }.freeze

  class Generator
    def initialize(config_path:, device_udid:, execution_id:)
      @config = JSON.parse(File.read(config_path, encoding: "UTF-8"))
      unless device_udid.instance_of?(String) && device_udid.match?(UDID)
        raise Error, "--device-udid must be one exact leased simulator UDID, got #{device_udid.inspect}"
      end

      @device_udid = device_udid.upcase
      unless execution_id.instance_of?(String) && execution_id.match?(/\A[A-Za-z0-9][A-Za-z0-9_-]{0,63}\z/)
        raise Error, "invalid execution id: #{execution_id.inspect}"
      end

      @execution_id = execution_id
      @scratch_root = File.join(
        @config.fetch("temporary_state_root"),
        @execution_id,
        "iap-review-screenshot"
      )
    end

    def destination
      @destination ||= begin
        raw = ENV["IAP_REVIEW_SCREENSHOT"] || @config.fetch("iap_review_screenshot")
        path = File.expand_path(raw, APP_ROOT)
        raise Error, "IAP review screenshot escaped repository root" unless path.start_with?("#{REPO_ROOT}/")
        raise Error, "IAP review screenshot must be a .png" unless File.extname(path) == ".png"

        path
      end
    end

    def run!
      FileUtils.mkdir_p(@scratch_root)
      localize_device!
      result_path = run_test!
      attachment_root = export_attachments!(result_path)
      source = attachment!(attachment_root, SCREENSHOT_ATTACHMENT)
      price = File.read(attachment!(attachment_root, PRICE_ATTACHMENT), encoding: "UTF-8").strip
      raise Error, "#{TEST_IDENTIFIER} attached an empty price: the capture cannot be verified" if price.empty?

      size = publish!(source)
      sidecar = write_sidecar!(price, size)
      puts "Petites Dents IAP review screenshot: PASS (#{destination})"
      puts "Petites Dents IAP review sidecar:    #{sidecar} (price #{price.inspect})"
      destination
    end

    private

    def iphone_simulator
      @iphone_simulator ||= @config.fetch("simulators").find do |simulator|
        simulator.fetch("screenshot_type").start_with?("APP_IPHONE")
      end || raise(Error, "no iPhone simulator is configured")
    end

    def locale
      @config.fetch("primary_locale")
    end

    def localize_device!
      language, region = LOCALE_LANGUAGE.fetch(locale) do
        raise Error, "unsupported primary locale: #{locale}"
      end
      # `simctl spawn` needs a booted device: run standalone (not chained after
      # the screenshot matrix, which leaves the simulator up), the language
      # write used to die with "device is not booted" before anything was
      # captured. Booting first makes the lane usable on its own.
      sh("xcrun", "simctl", "boot", @device_udid, allow_failure: true)
      sh("xcrun", "simctl", "bootstatus", @device_udid, "-b")
      sh("xcrun", "simctl", "spawn", @device_udid,
         "defaults", "write", "NSGlobalDomain", "AppleLanguages", "-array", language)
      sh("xcrun", "simctl", "spawn", @device_udid,
         "defaults", "write", "NSGlobalDomain", "AppleLocale", "-string", "#{language}_#{region}")
      sh("xcrun", "simctl", "shutdown", @device_udid, allow_failure: true)
      sh("xcrun", "simctl", "boot", @device_udid)
      sh("xcrun", "simctl", "bootstatus", @device_udid, "-b")
      sh("xcrun", "simctl", "status_bar", @device_udid, "override",
         "--time", "09:41", "--batteryState", "charged", "--batteryLevel", "100", "--wifiBars", "3",
         allow_failure: true)
      [language, region]
    end

    def run_test!
      language, region = LOCALE_LANGUAGE.fetch(locale)
      result_path = File.join(@scratch_root, "paywall.xcresult")
      FileUtils.rm_rf(result_path)
      cache_root = File.join(@config.fetch("temporary_state_root"), "cache")
      sh(
        "xcodebuild", "test",
        "-project", File.join(REPO_ROOT, @config.fetch("project")),
        "-scheme", @config.fetch("scheme"),
        "-destination", "platform=iOS Simulator,id=#{@device_udid}",
        "-derivedDataPath", File.join(cache_root, "DerivedData"),
        "-clonedSourcePackagesDirPath", File.join(cache_root, "SourcePackages"),
        "-packageCachePath", File.join(cache_root, "PackageCache"),
        "-resultBundlePath", result_path,
        "-only-testing:#{TEST_IDENTIFIER}",
        "-testLanguage", language,
        "-testRegion", region,
        "-parallel-testing-enabled", "NO",
        chdir: APP_ROOT
      )
      result_path
    end

    def export_attachments!(result_path)
      attachment_root = File.join(@scratch_root, "attachments")
      FileUtils.rm_rf(attachment_root)
      FileUtils.mkdir_p(attachment_root)
      sh("xcrun", "xcresulttool", "export", "attachments",
         "--path", result_path, "--output-path", attachment_root)
      attachment_root
    end

    def manifest(attachment_root)
      manifest_path = File.join(attachment_root, "manifest.json")
      raise Error, "xcresult attachment manifest is missing" unless File.file?(manifest_path)

      JSON.parse(File.read(manifest_path, encoding: "UTF-8"))
          .flat_map { |test| test.fetch("attachments", []) }
    end

    # The one exported file whose attachment name is exactly `name`.
    def attachment!(attachment_root, name)
      entries = manifest(attachment_root)
      matches = entries.select do |candidate|
        raw = candidate.fetch("suggestedHumanReadableName", "").to_s
        (DECORATED_NAME.match(raw)&.[](:name) || File.basename(raw, ".*")) == name
      end
      unless matches.length == 1
        found = entries.map { |entry| entry["suggestedHumanReadableName"] }.compact.sort
        raise Error,
              "expected exactly one #{name.inspect} attachment from #{TEST_IDENTIFIER}, " \
              "got #{matches.length}; attachments were #{found.inspect}"
      end

      File.join(attachment_root, matches.first.fetch("exportedFileName"))
    end

    def publish!(source)
      width, height = image_dimensions(source)
      expected = iphone_simulator.fetch("screenshot_dimensions")
      unless [width, height] == expected
        raise Error,
              "IAP review screenshot dimensions mismatch: #{width}x#{height}, expected #{expected.join('x')}"
      end

      FileUtils.mkdir_p(File.dirname(destination))
      FileUtils.cp(source, destination)
      raise Error, "IAP review screenshot was not written: #{destination}" unless File.file?(destination)

      [width, height]
    end

    def sidecar_path
      destination.sub(/\.png\z/, ".json")
    end

    # A PNG states a price in pixels and nothing can read it back. The sidecar
    # carries the string the paywall rendered plus the digest of the image it
    # came from, which is what lets `scripts/release_contract.rb` refuse a
    # capture whose price diverges from `fastlane/pro_products.json` — and
    # refuse a sidecar hand-edited to agree with an image it does not describe.
    def write_sidecar!(price, size)
      spec = JSON.parse(File.read(SPEC_PATH, encoding: "UTF-8"))
      product = spec.fetch("products").first
      facts = {
        "screenshot" => File.basename(destination),
        "screenshot_sha256" => Digest::SHA256.hexdigest(File.binread(destination)),
        "screenshot_size" => size,
        "product_id" => product.fetch("product_id"),
        "displayed_price" => price,
        "storefront" => spec.fetch("base_territory"),
        "expected_base_price" => product.fetch("base_price"),
        "expected_base_currency" => spec.fetch("base_currency"),
        "price_source" => "PetitesDents.storekit via SKTestSession, storefront pinned to " \
                          "the base territory of fastlane/pro_products.json"
      }
      payload = { "captured_at" => capture_timestamp(facts) }.merge(facts)
      File.write(sidecar_path, "#{JSON.pretty_generate(payload)}\n", encoding: "UTF-8")
      sidecar_path
    end

    # La capture est reproductible au bit près : relancer la lane sur un paywall
    # inchangé produit le même PNG, donc le même digest. Réécrire un
    # `captured_at` neuf ferait pourtant muter un fichier versionné au milieu
    # d'une release, et le manifeste figé du pipeline refuserait la soumission
    # ("release candidate changed: review_assets/...json"). Ce garde-fou a
    # raison : le candidat ne doit pas bouger sous ses pieds. On ne redate donc
    # que si la capture décrit réellement autre chose qu'avant.
    def capture_timestamp(facts)
      now = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
      return now unless File.file?(sidecar_path) && !File.symlink?(sidecar_path)

      previous = JSON.parse(File.read(sidecar_path, encoding: "UTF-8"))
      return now unless previous.instance_of?(Hash)

      inherited = previous["captured_at"]
      return now unless inherited.instance_of?(String) &&
                        inherited.match?(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/)
      return now unless previous.reject { |key, _| key == "captured_at" } == facts

      inherited
    rescue JSON::ParserError
      now
    end

    def image_dimensions(path)
      output = sh("sips", "-g", "pixelWidth", "-g", "pixelHeight", path)
      width = output[/pixelWidth:\s+(\d+)/, 1]&.to_i
      height = output[/pixelHeight:\s+(\d+)/, 1]&.to_i
      raise Error, "could not read image dimensions: #{path}" unless width && height

      [width, height]
    end

    def sh(*command, chdir: nil, allow_failure: false)
      options = {}
      options[:chdir] = chdir if chdir
      stdout, stderr, status = Open3.capture3(*command, **options)
      unless status.success? || allow_failure
        detail = [stdout, stderr].reject(&:empty?).join("\n").strip
        raise Error, "command failed (#{status.exitstatus}): #{command.join(' ')}\n#{detail}"
      end
      stdout
    end
  end

  class CLI
    def self.run(argv)
      options = {
        config: File.join(APP_ROOT, "fastlane", "release_config.json"),
        execution_id: ENV["PETITES_DENTS_RELEASE_RUN_ID"] || ENV["RELEASE_RUN_ID"] ||
                      Time.now.utc.strftime("%Y%m%dT%H%M%SZ")
      }
      OptionParser.new do |parser|
        parser.on("--config PATH") { |value| options[:config] = value }
        parser.on("--device-udid UDID") { |value| options[:device_udid] = value }
        parser.on("--device-udids-json JSON") { |value| options[:device_udids_json] = value }
        parser.on("--execution-id ID") { |value| options[:execution_id] = value }
      end.parse!(argv)

      options[:device_udid] ||= begin
        raw = options[:device_udids_json] || ENV["APPS_FACTORY_DEVICE_UDIDS_JSON"]
        raw ? pick_iphone_udid(JSON.parse(raw), options.fetch(:config)) : nil
      end

      Generator.new(
        config_path: options.fetch(:config),
        device_udid: options[:device_udid].to_s,
        execution_id: options.fetch(:execution_id)
      ).run!
      0
    rescue Error, JSON::ParserError => error
      warn "Petites Dents IAP review screenshot: FAIL — #{error.message}"
      1
    end

    def self.pick_iphone_udid(mapping, config_path)
      config = JSON.parse(File.read(config_path, encoding: "UTF-8"))
      simulator = config.fetch("simulators").find do |candidate|
        candidate.fetch("screenshot_type").start_with?("APP_IPHONE")
      end
      raise Error, "no iPhone simulator is configured" unless simulator

      mapping[simulator.fetch("name_suffix")] ||
        raise(Error, "no leased UDID for #{simulator.fetch('name_suffix')}")
    end
  end
end

exit PetitesDentsIapReviewScreenshot::CLI.run(ARGV) if __FILE__ == $PROGRAM_NAME
