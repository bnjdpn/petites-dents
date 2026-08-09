#!/opt/homebrew/opt/ruby/bin/ruby
# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "optparse"
require "time"
require_relative "release_alignment_guard"

def parse_prepare_options(argv)
  options = { root: DEFAULT_ROOT }
  OptionParser.new do |opts|
    opts.banner = "Usage: scripts/prepare_android_release.rb --apk PATH --output-dir PATH"
    opts.on("--root PATH") { |value| options[:root] = File.expand_path(value) }
    opts.on("--apk PATH") { |value| options[:apk] = File.expand_path(value) }
    opts.on("--output-dir PATH") { |value| options[:output_dir] = File.expand_path(value) }
    opts.on("--source-commit SHA") { |value| options[:source_commit] = value }
  end.parse!(argv)
  raise "--apk is required" unless options[:apk]
  raise "--output-dir is required" unless options[:output_dir]
  options
end

def git_capture(root, *args)
  output, error, status = Open3.capture3("git", "-C", root, *args)
  raise "git #{args.join(' ')} failed: #{error.strip}" unless status.success?
  output.strip
end

def prepare_android_release(options)
  root = options.fetch(:root)
  state = local_release_state(root)
  failures = validate_local_state(state, expected_tag: "v#{state['ios_version']}")
  details = inspect_apk(
    options.fetch(:apk),
    aapt: ENV["ANDROID_AAPT"] || newest_android_tool("aapt"),
    apksigner: ENV["ANDROID_APKSIGNER"] || newest_android_tool("apksigner")
  )
  failures.concat(validate_apk_details(state, details))
  raise failures.join("\n") unless failures.empty?

  output_dir = options.fetch(:output_dir)
  FileUtils.mkdir_p(output_dir)
  target_name = "#{state['artifact_slug']}-v#{state['ios_version']}.apk"
  target = File.join(output_dir, target_name)
  FileUtils.cp(options.fetch(:apk), target)
  target_details = details.merge("file_name" => target_name, "sha256" => Digest::SHA256.file(target).hexdigest)
  checksum = "#{target_details['sha256']}  #{target_name}\n"
  checksum_path = "#{target}.sha256"
  File.write(checksum_path, checksum)

  diff = git_capture(root, "diff", "--binary", "--", ".", ":(exclude)ios/Builds")
  provenance = {
    "schema_version" => 1,
    "app" => state["artifact_slug"],
    "tag" => "v#{state['ios_version']}",
    "application_id" => state["application_id"],
    "version_name" => state["android_version"],
    "version_code" => state["android_version_code"],
    "apk" => target_name,
    "apk_sha256" => target_details["sha256"],
    "certificate_sha256" => target_details["signer_sha256"],
    "source_commit" => options[:source_commit] || git_capture(root, "rev-parse", "HEAD"),
    "source_tree" => git_capture(root, "rev-parse", "HEAD^{tree}"),
    "source_diff_sha256" => Digest::SHA256.hexdigest(diff),
    "source_diff_files" => git_capture(root, "diff", "--name-only").lines.map(&:strip).reject(&:empty?),
    "generated_at" => Time.now.utc.iso8601
  }
  provenance_path = "#{target}.provenance.json"
  File.write(provenance_path, JSON.pretty_generate(provenance) + "\n")

  artifact_failures = validate_checksum(checksum_path, target_details)
  artifact_failures.concat(validate_provenance(provenance_path, state, target_details, root: root))
  raise artifact_failures.join("\n") unless artifact_failures.empty?

  {
    "apk" => target,
    "checksum" => checksum_path,
    "provenance" => provenance_path,
    "sha256" => target_details["sha256"],
    "certificate_sha256" => target_details["signer_sha256"]
  }
end

begin
  puts JSON.pretty_generate(prepare_android_release(parse_prepare_options(ARGV)))
rescue RuntimeError, KeyError => e
  warn e.message
  exit 1
end
