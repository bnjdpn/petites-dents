#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "optparse"
require "pathname"
require "time"

module PetitesDentsScreenshots
  class Error < StandardError; end

  class LocalizationGuard
    REQUIRED_LOCALES = %w[en-US en-GB fr-FR].freeze

    def self.validate!(entries)
      entries.group_by { |entry| [entry.fetch("display_type"), entry.fetch("scene")] }.each do |key, group|
        by_locale = group.to_h { |entry| [entry.fetch("locale"), entry] }
        missing = REQUIRED_LOCALES - by_locale.keys
        raise Error, "localized screenshot matrix is incomplete for #{key.join('/')}" unless missing.empty?

        if by_locale.fetch("en-US").fetch("sha256") == by_locale.fetch("fr-FR").fetch("sha256")
          raise Error, "French screenshot is identical to English for #{key.join('/')}"
        end
      end
      true
    end
  end

  class DeviceSchedule
    UDID = /\A[0-9A-F]{8}(?:-[0-9A-F]{4}){3}-[0-9A-F]{12}\z/i

    attr_reader :groups

    def initialize(locales:, simulators:, device_udids:)
      expected = simulators.map { |simulator| simulator.fetch("name_suffix") }
      unless device_udids.instance_of?(Hash) && device_udids.keys.sort == expected.sort &&
             device_udids.values.uniq.length == expected.length &&
             device_udids.values.all? { |udid| udid.instance_of?(String) && udid.match?(UDID) }
        raise Error, "device_udids must map every configured simulator to a distinct exact UDID"
      end

      @groups = simulators.map do |simulator|
        {
          "simulator" => simulator,
          "udid" => device_udids.fetch(simulator.fetch("name_suffix")).upcase,
          "locales" => locales.dup.freeze
        }.freeze
      end.freeze
      freeze
    end
  end

  class Runner
    def initialize(log_root:)
      @log_root = log_root
      FileUtils.mkdir_p(@log_root)
      @sequence = 0
      @sequence_mutex = Mutex.new
    end

    def run!(*command, environment: {}, chdir: nil, allow_failure: false)
      sequence = @sequence_mutex.synchronize { @sequence += 1 }
      process_options = {}
      process_options[:chdir] = chdir if chdir
      stdout, stderr, status = Open3.capture3(environment, *command, **process_options)
      label = format("%03d-%s.log", sequence, File.basename(command.first))
      File.write(
        File.join(@log_root, label),
        "$ #{command.join(' ')}\n\nSTDOUT\n#{stdout}\nSTDERR\n#{stderr}\n"
      )
      unless status.success? || allow_failure
        detail = [stdout, stderr].reject(&:empty?).join("\n").strip
        raise Error, "command failed (#{status.exitstatus}): #{command.join(' ')}\n#{detail}"
      end
      stdout
    end
  end

  class Generator
    TEST_LOCALE = {
      "en-US" => ["en", "US"],
      "en-GB" => ["en", "GB"],
      "fr-FR" => ["fr", "FR"]
    }.freeze

    def initialize(app_root:, run_id:, candidate_id:, device_udids:, runner: nil)
      @app_root = File.realpath(app_root)
      @run_id = run_id
      validate_run_id!
      unless candidate_id.instance_of?(String) && candidate_id.match?(/\A[a-f0-9]{64}\z/)
        raise Error, "candidate_id must be a lowercase SHA-256"
      end
      @candidate_id = candidate_id.freeze
      @config = JSON.parse(
        File.read(File.join(@app_root, "ios", "fastlane", "release_config.json"))
      )
      @schedule = DeviceSchedule.new(
        locales: @config.fetch("media_locales"),
        simulators: @config.fetch("simulators"),
        device_udids: device_udids
      )
      @run_root = bounded_path(@config.fetch("artifact_root"), @run_id)
      @temporary_root = File.join(
        @config.fetch("temporary_state_root"),
        @run_id,
        "screenshots"
      )
      @runner = runner || Runner.new(log_root: File.join(@run_root, "logs", "commands"))
      @entries = []
      @entries_mutex = Mutex.new
      @simulator_receipts = []
    end

    def run!
      validate_source!
      prepare_paths!
      startup = [Thread.new { build_for_testing_once! }]
      startup.concat(@schedule.groups.map { |group| Thread.new { prepare_leased_device!(group) } })
      startup.each(&:value)
      workers = @schedule.groups.map do |group|
        Thread.new do
          group.fetch("locales").each do |locale|
            localize_device_when_needed!(group.fetch("udid"), locale)
            capture_cell(locale, group.fetch("simulator"), group.fetch("udid"))
          end
        end
      end
      workers.each(&:value)
      write_manifest!
      puts "Petites Dents screenshots: PASS (#{@entries.length} files)"
    end

    private

    def validate_run_id!
      return if @run_id.match?(/\A[A-Za-z0-9][A-Za-z0-9_-]{0,63}\z/)

      raise Error, "invalid run id: #{@run_id.inspect}"
    end

    def bounded_path(*components)
      candidate = File.expand_path(File.join(@app_root, *components))
      prefix = "#{@app_root}#{File::SEPARATOR}"
      raise Error, "path escaped app root: #{candidate}" unless candidate.start_with?(prefix)

      current = @app_root
      Pathname.new(candidate).relative_path_from(Pathname.new(@app_root)).each_filename do |component|
        current = File.join(current, component)
        raise Error, "symbolic link is forbidden: #{current}" if File.symlink?(current)
      end
      candidate
    end

    def validate_source!
      branch = git("branch", "--show-current").strip
      raise Error, "screenshot source branch must be main, got #{branch.inspect}" unless branch == "main"

      @source_git_sha = git("rev-parse", "HEAD").strip
      @source_git_tree_sha = git("rev-parse", "HEAD^{tree}").strip
    end

    def git(*arguments)
      stdout, stderr, status = Open3.capture3("git", "-C", @app_root, *arguments)
      raise Error, "git #{arguments.join(' ')} failed: #{stderr}" unless status.success?

      stdout
    end

    def prepare_paths!
      screenshots = File.join(@run_root, "screenshots")
      existing = Dir.glob(File.join(screenshots, "**", "*.png"))
      raise Error, "run already contains screenshots: #{@run_root}" unless existing.empty?

      %w[screenshots app_previews logs].each do |directory|
        FileUtils.mkdir_p(File.join(@run_root, directory))
      end
      FileUtils.mkdir_p(@temporary_root)
      %w[DerivedData SourcePackages PackageCache].each do |directory|
        FileUtils.mkdir_p(File.join(cache_root, directory))
      end
    end

    def cache_root
      File.join(@config.fetch("temporary_state_root"), "cache")
    end

    def build_for_testing_once!
      result_path = File.join(@temporary_root, "build.xcresult")
      @runner.run!(
        "xcodebuild", "build-for-testing",
        "-project", File.join(@app_root, @config.fetch("project")),
        "-scheme", @config.fetch("scheme"),
        "-destination", "generic/platform=iOS Simulator",
        "-derivedDataPath", File.join(cache_root, "DerivedData"),
        "-clonedSourcePackagesDirPath", File.join(cache_root, "SourcePackages"),
        "-packageCachePath", File.join(cache_root, "PackageCache"),
        "-resultBundlePath", result_path,
        "-parallel-testing-enabled", "NO",
        "-maximum-parallel-testing-workers", "1",
        "-maximum-concurrent-test-simulator-destinations", "1",
        chdir: File.join(@app_root, "ios")
      )
      candidates = Dir.glob(File.join(cache_root, "DerivedData", "**", "*.xctestrun"))
      raise Error, "build must produce exactly one xctestrun, found #{candidates.length}" unless candidates.length == 1

      @built_xctestrun = candidates.fetch(0)
    end

    def prepare_leased_device!(group)
      simulator = group.fetch("simulator")
      udid = group.fetch("udid")
      receipt = write_simulator_receipt(
        udid: udid,
        name: "AppsFactory-#{simulator.fetch('name_suffix')}",
        locale: nil,
        simulator: simulator,
        state: "leased"
      )
      @runner.run!("xcrun", "simctl", "shutdown", udid, allow_failure: true)
      @runner.run!("xcrun", "simctl", "erase", udid)
      @runner.run!("xcrun", "simctl", "boot", udid)
      @runner.run!("xcrun", "simctl", "bootstatus", udid, "-b")
      @runner.run!(
        "xcrun", "simctl", "status_bar", udid, "override",
        "--time", "09:41", "--batteryState", "charged", "--batteryLevel", "100", "--wifiBars", "3",
        allow_failure: true
      )
      update_receipt(receipt, "ready")
    rescue StandardError => error
      update_receipt(receipt, "failed", error.message) if receipt
      raise
    end

    def localize_device_when_needed!(udid, locale)
      language, region = TEST_LOCALE.fetch(locale)
      return if locale == "en-GB"

      @runner.run!(
        "xcrun", "simctl", "spawn", udid,
        "defaults", "write", "NSGlobalDomain", "AppleLanguages", "-array", language
      )
      @runner.run!(
        "xcrun", "simctl", "spawn", udid,
        "defaults", "write", "NSGlobalDomain", "AppleLocale", "-string", "#{language}_#{region}"
      )
      @runner.run!("xcrun", "simctl", "shutdown", udid)
      @runner.run!("xcrun", "simctl", "boot", udid)
      @runner.run!("xcrun", "simctl", "bootstatus", udid, "-b")
      @runner.run!(
        "xcrun", "simctl", "status_bar", udid, "override",
        "--time", "09:41", "--batteryState", "charged", "--batteryLevel", "100", "--wifiBars", "3",
        allow_failure: true
      )
    end

    def capture_cell(locale, simulator, udid)
      language, region = TEST_LOCALE.fetch(locale)
      cell_id = "#{locale.gsub(/[^A-Za-z0-9]/, "_")}-#{simulator.fetch("name_suffix")}"
      cell_root = File.join(@temporary_root, cell_id)
      FileUtils.mkdir_p(cell_root)
      result_path = File.join(cell_root, "result.xcresult")
      @runner.run!(
        "xcodebuild", "test-without-building",
        "-xctestrun", @built_xctestrun,
        "-destination", "platform=iOS Simulator,id=#{udid}",
        "-derivedDataPath", File.join(cell_root, "DerivedData"),
        "-clonedSourcePackagesDirPath", File.join(cache_root, "SourcePackages"),
        "-packageCachePath", File.join(cache_root, "PackageCache"),
        "-resultBundlePath", result_path,
        "-only-testing:PetitesDentsUITests/PetitesDentsUITests/testStoreScreenshots",
        "-testLanguage", language,
        "-testRegion", region,
        "-parallel-testing-enabled", "NO",
        "-maximum-parallel-testing-workers", "1",
        "-maximum-concurrent-test-simulator-destinations", "1",
        chdir: File.join(@app_root, "ios")
      )

      attachment_root = File.join(cell_root, "attachments")
      FileUtils.mkdir_p(attachment_root)
      @runner.run!(
        "xcrun", "xcresulttool", "export", "attachments",
        "--path", result_path,
        "--output-path", attachment_root
      )
      collect_attachments(attachment_root: attachment_root, locale: locale, simulator: simulator, udid: udid)
    end

    def write_simulator_receipt(udid:, name:, locale:, simulator:, state:)
      receipt_root = File.join(@temporary_root, "simulator-receipts")
      FileUtils.mkdir_p(receipt_root)
      path = File.join(receipt_root, "#{udid}.json")
      payload = {
        "owner" => "petites-dents/#{@run_id}",
        "udid" => udid,
        "name" => name,
        "locale" => locale,
        "device_type" => simulator.fetch("device_type"),
        "runtime" => @config.fetch("simulator_runtime"),
        "state" => state,
        "created_at" => Time.now.utc.iso8601
      }
      File.write(path, JSON.pretty_generate(payload))
      @simulator_receipts << path
      path
    end

    def update_receipt(path, state, error = nil)
      return unless path && File.file?(path)

      payload = JSON.parse(File.read(path))
      payload["state"] = state
      payload["updated_at"] = Time.now.utc.iso8601
      payload["error"] = error if error
      File.write(path, JSON.pretty_generate(payload))
    end

    def collect_attachments(attachment_root:, locale:, simulator:, udid:)
      manifest_path = File.join(attachment_root, "manifest.json")
      raise Error, "xcresult attachment manifest is missing" unless File.file?(manifest_path)

      attachments = JSON.parse(File.read(manifest_path)).flat_map { |test| test.fetch("attachments", []) }
      @config.fetch("screenshot_scenes").each do |scene|
        attachment = attachments.find do |candidate|
          candidate.fetch("suggestedHumanReadableName", "").start_with?("#{scene}_")
        end
        raise Error, "missing screenshot attachment #{locale}/#{simulator.fetch('screenshot_type')}/#{scene}" unless attachment

        source = File.join(attachment_root, attachment.fetch("exportedFileName"))
        filename = "PetitesDents_#{simulator.fetch('screenshot_type')}_#{scene}.png"
        destination_root = File.join(@run_root, "screenshots", locale)
        FileUtils.mkdir_p(destination_root)
        destination = File.join(destination_root, filename)
        raise Error, "duplicate screenshot destination: #{destination}" if File.exist?(destination)

        FileUtils.cp(source, destination)
        width, height = image_dimensions(destination)
        expected = simulator.fetch("screenshot_dimensions")
        unless [width, height] == expected
          raise Error, "screenshot dimensions mismatch for #{destination}: #{width}x#{height}, expected #{expected.join('x')}"
        end
        entry = {
          "locale" => locale,
          "display_type" => simulator.fetch("screenshot_type"),
          "scene" => scene,
          "relative_path" => Pathname.new(destination).relative_path_from(Pathname.new(@run_root)).to_s,
          "width" => width,
          "height" => height,
          "sha256" => Digest::SHA256.file(destination).hexdigest,
          "simulator_udid" => udid,
          "device_type" => simulator.fetch("device_type")
        }
        @entries_mutex.synchronize { @entries << entry }
      end
    end

    def image_dimensions(path)
      output = @runner.run!("sips", "-g", "pixelWidth", "-g", "pixelHeight", path)
      width = output[/pixelWidth:\s+(\d+)/, 1]&.to_i
      height = output[/pixelHeight:\s+(\d+)/, 1]&.to_i
      raise Error, "could not read image dimensions: #{path}" unless width && height

      [width, height]
    end

    def write_manifest!
      expected_count = @config.fetch("media_locales").length *
                       @config.fetch("simulators").length *
                       @config.fetch("screenshot_scenes").length
      raise Error, "screenshot matrix is incomplete: #{@entries.length}/#{expected_count}" unless @entries.length == expected_count
      LocalizationGuard.validate!(@entries)

      payload = {
        "schema_version" => 1,
        "app" => "Petites Dents",
        "version" => @config.fetch("version"),
        "run_id" => @run_id,
        "generated_at" => Time.now.utc.iso8601,
        "source_git_sha" => @source_git_sha,
        "source_git_tree_sha" => @source_git_tree_sha,
        "source_candidate_id" => @candidate_id,
        "app_preview_policy" => @config.fetch("app_preview_policy"),
        "screenshots" => @entries.sort_by { |entry| [entry["locale"], entry["display_type"], entry["scene"]] },
        "simulator_receipts" => @simulator_receipts
      }
      File.write(
        File.join(@run_root, "logs", "media-manifest.json"),
        JSON.pretty_generate(payload)
      )
    end
  end

  class CLI
    def self.run(argv)
      options = {}
      parser = OptionParser.new do |flags|
        flags.on("--app-root PATH") { |value| options[:app_root] = value }
        flags.on("--run-id ID") { |value| options[:run_id] = value }
        flags.on("--candidate-id SHA256") { |value| options[:candidate_id] = value }
        flags.on("--device-udids-json JSON") { |value| options[:device_udids] = JSON.parse(value) }
      end
      parser.parse!(argv)
      raise Error, "unknown arguments: #{argv.join(' ')}" unless argv.empty?
      raise Error, "--app-root is required" if options[:app_root].to_s.empty?
      raise Error, "--run-id is required" if options[:run_id].to_s.empty?
      raise Error, "--candidate-id is required" if options[:candidate_id].to_s.empty?
      raise Error, "--device-udids-json is required" unless options[:device_udids]

      Generator.new(**options).run!
      0
    rescue OptionParser::ParseError, JSON::ParserError, Error => error
      warn error.message
      1
    end
  end
end

exit PetitesDentsScreenshots::CLI.run(ARGV) if $PROGRAM_NAME == __FILE__
