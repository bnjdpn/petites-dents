#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "json"
require "open3"
require "optparse"
require "pathname"

module PetitesDentsMediaContract
  class Error < StandardError; end

  class Contract
    def initialize(run_root:)
      @run_root = File.realpath(run_root)
      @repo_root = File.realpath(File.join(@run_root, "..", "..", "..", ".."))
      @config = JSON.parse(
        File.read(File.join(@repo_root, "ios", "fastlane", "release_config.json"))
      )
      @manifest_path = File.join(@run_root, "logs", "media-manifest.json")
    end

    def validate!
      validate_bounded_root!
      manifest = read_manifest!
      validate_source!(manifest)
      validate_policy!(manifest)
      validate_screenshot_matrix!(manifest)
      validate_no_preview_files!
      puts "Petites Dents media contract: PASS (#{manifest.fetch('screenshots').length} screenshots)"
    end

    private

    def validate_bounded_root!
      artifact_root = File.realpath(File.join(@repo_root, @config.fetch("artifact_root")))
      prefix = "#{artifact_root}#{File::SEPARATOR}"
      raise Error, "run root escaped app-local artifact root" unless @run_root.start_with?(prefix)

      current = artifact_root
      Pathname.new(@run_root).relative_path_from(Pathname.new(artifact_root)).each_filename do |component|
        current = File.join(current, component)
        raise Error, "media path traverses a symbolic link: #{current}" if File.symlink?(current)
      end
    end

    def read_manifest!
      raise Error, "missing media manifest: #{@manifest_path}" unless File.file?(@manifest_path)

      JSON.parse(File.read(@manifest_path))
    rescue JSON::ParserError => error
      raise Error, "invalid media manifest: #{error.message}"
    end

    def validate_source!(manifest)
      branch = git("branch", "--show-current").strip
      raise Error, "media source branch must be main" unless branch == "main"

      dirty = git("status", "--porcelain", "--untracked-files=no").strip
      raise Error, "tracked source changed after media capture\n#{dirty}" unless dirty.empty?

      sha = git("rev-parse", "HEAD").strip
      tree = git("rev-parse", "HEAD^{tree}").strip
      raise Error, "media commit does not match current HEAD" unless manifest["source_git_sha"] == sha
      raise Error, "media source tree does not match current tree" unless manifest["source_git_tree_sha"] == tree
      raise Error, "media version mismatch" unless manifest["version"] == @config.fetch("version")
    end

    def validate_policy!(manifest)
      configured = @config.fetch("app_preview_policy")
      captured = manifest.fetch("app_preview_policy")
      raise Error, "App Preview policy changed after capture" unless captured == configured
      raise Error, "App Preview applicability must be false" unless configured["applicable"] == false
      raise Error, "App Preview policy must be reviewed for each release" unless configured["review_each_release"] == true
      raise Error, "App Preview reason is missing" if configured["reason"].to_s.strip.empty?
    end

    def validate_screenshot_matrix!(manifest)
      entries = manifest.fetch("screenshots")
      expected = []
      @config.fetch("media_locales").each do |locale|
        @config.fetch("simulators").each do |simulator|
          @config.fetch("screenshot_scenes").each do |scene|
            expected << [locale, simulator.fetch("screenshot_type"), scene]
          end
        end
      end
      actual = entries.map { |entry| [entry["locale"], entry["display_type"], entry["scene"]] }
      raise Error, "screenshot cells are missing, duplicated, or foreign" unless actual.sort == expected.sort

      expected_paths = []
      entries.each do |entry|
        relative = entry.fetch("relative_path")
        path = File.expand_path(relative, @run_root)
        prefix = "#{@run_root}#{File::SEPARATOR}"
        raise Error, "screenshot escaped run root: #{relative}" unless path.start_with?(prefix)
        raise Error, "missing screenshot: #{relative}" unless File.file?(path)
        raise Error, "screenshot may not be a symbolic link: #{relative}" if File.symlink?(path)
        expected_paths << path

        digest = Digest::SHA256.file(path).hexdigest
        raise Error, "checksum mismatch: #{relative}" unless digest == entry.fetch("sha256")
        width, height = image_dimensions(path)
        raise Error, "dimension manifest mismatch: #{relative}" unless [width, height] == [entry["width"], entry["height"]]
        simulator = @config.fetch("simulators").find do |item|
          item.fetch("screenshot_type") == entry.fetch("display_type")
        end
        raise Error, "unknown display type: #{entry['display_type']}" unless simulator
        raise Error, "wrong screenshot dimensions: #{relative}" unless [width, height] == simulator.fetch("screenshot_dimensions")
      end

      found_paths = Dir.glob(File.join(@run_root, "screenshots", "**", "*.png"))
      raise Error, "screenshot directory contains stale or foreign files" unless found_paths.sort == expected_paths.sort
    end

    def validate_no_preview_files!
      previews = Dir.glob(File.join(@run_root, "app_previews", "**", "*.{mov,mp4}"))
      raise Error, "App Preview files exist despite non-applicable policy" unless previews.empty?
    end

    def image_dimensions(path)
      output, error, status = Open3.capture3("sips", "-g", "pixelWidth", "-g", "pixelHeight", path)
      raise Error, "sips failed for #{path}: #{error}" unless status.success?

      width = output[/pixelWidth:\s+(\d+)/, 1]&.to_i
      height = output[/pixelHeight:\s+(\d+)/, 1]&.to_i
      raise Error, "could not read dimensions: #{path}" unless width && height
      [width, height]
    end

    def git(*arguments)
      output, error, status = Open3.capture3("git", "-C", @repo_root, *arguments)
      raise Error, "git #{arguments.join(' ')} failed: #{error}" unless status.success?
      output
    end
  end

  class CLI
    def self.run(argv)
      options = {}
      OptionParser.new do |flags|
        flags.on("--run-root PATH") { |value| options[:run_root] = value }
      end.parse!(argv)
      raise Error, "unknown arguments: #{argv.join(' ')}" unless argv.empty?
      raise Error, "--run-root is required" if options[:run_root].to_s.empty?

      Contract.new(**options).validate!
      0
    rescue OptionParser::ParseError, Error => error
      warn error.message
      1
    end
  end
end

exit PetitesDentsMediaContract::CLI.run(ARGV) if $PROGRAM_NAME == __FILE__
