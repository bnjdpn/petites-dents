#!/opt/homebrew/opt/ruby/bin/ruby
# frozen_string_literal: true

require "digest"
require "json"
require "open3"
require "optparse"
require "time"

DEFAULT_ROOT = File.expand_path("..", __dir__)
VERSION_PATTERN = /\A\d+\.\d+\.\d+\z/
ASC_RELEASE_STATES = %w[
  WAITING_FOR_REVIEW IN_REVIEW PENDING_DEVELOPER_RELEASE PROCESSING_FOR_APP_STORE
  READY_FOR_SALE
].freeze

def parse_options(argv)
  options = { root: DEFAULT_ROOT, final: false }
  OptionParser.new do |opts|
    opts.banner = "Usage: scripts/release_alignment_guard.rb [options]"
    opts.on("--root PATH") { |value| options[:root] = File.expand_path(value) }
    opts.on("--expected-tag TAG") { |value| options[:expected_tag] = value }
    opts.on("--apk PATH") { |value| options[:apk] = File.expand_path(value) }
    opts.on("--checksum PATH") { |value| options[:checksum] = File.expand_path(value) }
    opts.on("--provenance PATH") { |value| options[:provenance] = File.expand_path(value) }
    opts.on("--asc-json PATH") { |value| options[:asc_json] = File.expand_path(value) }
    opts.on("--release-json PATH") { |value| options[:release_json] = File.expand_path(value) }
    opts.on("--aapt PATH") { |value| options[:aapt] = File.expand_path(value) }
    opts.on("--apksigner PATH") { |value| options[:apksigner] = File.expand_path(value) }
    opts.on("--final") { options[:final] = true }
  end.parse!(argv)
  options
end

def capture(path, pattern)
  match = File.read(path).match(pattern)
  match && match[1].strip
end

def local_release_state(root)
  android = File.join(root, "app", "build.gradle.kts")
  ios = File.join(root, "ios", "project.yml")
  config = JSON.parse(File.read(File.join(root, "ios", "fastlane", "release_config.json")))
  signing = JSON.parse(File.read(File.join(root, "release", "android_release.json")))
  {
    "android_version" => capture(android, /versionName\s*=\s*"([^"]+)"/),
    "android_version_code" => capture(android, /versionCode\s*=\s*(\d+)/)&.to_i,
    "application_id" => capture(android, /applicationId\s*=\s*"([^"]+)"/),
    "ios_version" => capture(ios, /MARKETING_VERSION:\s*"?([^"\n]+)"?/),
    "ios_build" => capture(ios, /CURRENT_PROJECT_VERSION:\s*"?([^"\n]+)"?/),
    "config_version" => config["version"].to_s.strip,
    "artifact_slug" => signing.fetch("artifact_slug"),
    "expected_application_id" => signing.fetch("application_id"),
    "expected_signer_sha256" => signing.fetch("signer_sha256").downcase,
    "required_asset_suffixes" => signing.fetch("required_asset_suffixes")
  }
end

def validate_local_state(state, expected_tag: nil)
  failures = []
  versions = {
    "Android versionName" => state["android_version"],
    "iOS MARKETING_VERSION" => state["ios_version"],
    "App Store release config version" => state["config_version"]
  }
  versions.each do |label, version|
    failures << "#{label} is missing or not X.Y.Z" unless version&.match?(VERSION_PATTERN)
  end
  present = versions.values.compact.uniq
  failures << "Marketing versions must match: #{versions.map { |key, value| "#{key}=#{value || '(missing)'}" }.join(', ')}" if present.length > 1
  failures << "Android versionCode must be a positive integer" unless state["android_version_code"].to_i.positive?
  if state["application_id"] != state["expected_application_id"]
    failures << "Android applicationId #{state['application_id'] || '(missing)'} must be #{state['expected_application_id']}"
  end
  expected = "v#{state['ios_version']}"
  failures << "GitHub Release tag #{expected_tag} must be #{expected}" if expected_tag && expected_tag != expected
  failures
end

def newest_android_tool(name)
  candidates = Dir[File.expand_path("~/Library/Android/sdk/build-tools/*/#{name}")]
  candidates.select { |path| File.file?(path) && File.executable?(path) }.max_by do |path|
    path.split(File::SEPARATOR)[-2].split(".").map(&:to_i)
  end
end

def inspect_apk(apk, aapt:, apksigner:)
  raise "APK missing or empty at #{apk}" unless File.file?(apk) && File.size(apk).positive?
  raise "aapt executable not found" unless aapt && File.executable?(aapt)
  raise "apksigner executable not found" unless apksigner && File.executable?(apksigner)

  badging, badging_error, badging_status = Open3.capture3(aapt, "dump", "badging", apk)
  raise "aapt failed: #{badging_error.strip}" unless badging_status.success?
  package_line = badging.lines.find { |line| line.start_with?("package:") }.to_s
  signature, signature_error, signature_status = Open3.capture3(apksigner, "verify", "--print-certs", apk)
  raise "APK signature verification failed: #{signature_error.strip}" unless signature_status.success?
  {
    "application_id" => package_line[/name='([^']+)'/, 1],
    "version_code" => package_line[/versionCode='([^']+)'/, 1]&.to_i,
    "version_name" => package_line[/versionName='([^']+)'/, 1],
    "signer_sha256" => signature[/certificate SHA-256 digest:\s*([a-fA-F0-9]+)/, 1]&.downcase,
    "sha256" => Digest::SHA256.file(apk).hexdigest,
    "file_name" => File.basename(apk)
  }
end

def validate_apk_details(state, details)
  failures = []
  failures << "APK applicationId #{details['application_id']} must be #{state['application_id']}" unless details["application_id"] == state["application_id"]
  failures << "APK versionName #{details['version_name']} must be #{state['android_version']}" unless details["version_name"] == state["android_version"]
  failures << "APK versionCode #{details['version_code']} must be #{state['android_version_code']}" unless details["version_code"] == state["android_version_code"]
  failures << "APK signer #{details['signer_sha256'] || '(missing)'} must be #{state['expected_signer_sha256']}" unless details["signer_sha256"] == state["expected_signer_sha256"]
  failures
end

def validate_checksum(path, details)
  return ["Checksum missing at #{path}"] unless path && File.file?(path)
  line = File.read(path).strip
  expected = "#{details['sha256']}  #{details['file_name']}"
  line == expected ? [] : ["Checksum must be exactly #{expected.inspect}"]
end

def guard_git_capture(root, *args)
  output, error, status = Open3.capture3("git", "-C", root, *args)
  raise "git #{args.join(' ')} failed: #{error.strip}" unless status.success?
  output.strip
end

def validate_provenance(path, state, details, root: nil)
  return ["Provenance missing at #{path}"] unless path && File.file?(path)
  payload = JSON.parse(File.read(path))
  expected = {
    "schema_version" => 1,
    "app" => state["artifact_slug"],
    "tag" => "v#{state['ios_version']}",
    "application_id" => state["application_id"],
    "version_name" => state["android_version"],
    "version_code" => state["android_version_code"],
    "apk" => details["file_name"],
    "apk_sha256" => details["sha256"],
    "certificate_sha256" => details["signer_sha256"]
  }
  expected.each_with_object([]) do |(key, value), failures|
    failures << "Provenance #{key}=#{payload[key].inspect} must be #{value.inspect}" unless payload[key] == value
  end.tap do |failures|
    source_commit = payload["source_commit"]
    source_tree = payload["source_tree"]
    source_diff = payload["source_diff_sha256"]
    failures << "Provenance source_commit must be a full Git commit SHA" unless source_commit&.match?(/\A[0-9a-f]{40}\z/i)
    failures << "Provenance source_tree must be a full Git tree SHA" unless source_tree&.match?(/\A[0-9a-f]{40}\z/i)
    failures << "Provenance source_diff_sha256 must be a SHA-256 digest" unless source_diff&.match?(/\A[0-9a-f]{64}\z/i)
    failures << "Provenance source_diff_files must be an array" unless payload["source_diff_files"].is_a?(Array)
    begin
      Time.iso8601(payload.fetch("generated_at"))
    rescue KeyError, ArgumentError, TypeError
      failures << "Provenance generated_at must be an ISO-8601 timestamp"
    end

    git_metadata = File.exist?(File.join(root.to_s, ".git"))
    if git_metadata && source_commit&.match?(/\A[0-9a-f]{40}\z/i) && source_tree&.match?(/\A[0-9a-f]{40}\z/i)
      head = guard_git_capture(root, "rev-parse", "HEAD")
      tree = guard_git_capture(root, "rev-parse", "#{source_commit}^{tree}")
      diff = guard_git_capture(root, "diff", "--binary", "--", ".", ":(exclude)ios/Builds")
      files = guard_git_capture(root, "diff", "--name-only").lines.map(&:strip).reject(&:empty?)
      failures << "Provenance source_commit #{source_commit} must match checkout HEAD #{head}" unless source_commit == head
      failures << "Provenance source_tree #{source_tree} must match #{tree}" unless source_tree == tree
      failures << "Provenance source_diff_sha256 does not match the checkout diff" unless source_diff == Digest::SHA256.hexdigest(diff)
      failures << "Provenance source_diff_files do not match the checkout diff" unless payload["source_diff_files"] == files
    end
  end
rescue JSON::ParserError => e
  ["Invalid provenance JSON: #{e.message}"]
end

def validate_asc_json(path, state)
  return ["ASC readback JSON is required"] unless path && File.file?(path)
  payload = JSON.parse(File.read(path))
  version = payload["version"]
  build = payload["selected_build"]
  failures = []
  failures << "ASC version is missing" unless version
  if version
    failures << "ASC version #{version['version']} must be #{state['ios_version']}" unless version["version"] == state["ios_version"]
    failures << "ASC version state #{version['state']} is not a submitted/released state" unless ASC_RELEASE_STATES.include?(version["state"])
  end
  failures << "ASC selected build is missing" unless build
  failures << "ASC selected build state #{build['state']} must be VALID" if build && build["state"] != "VALID"
  if build && build["build"].to_s != state["ios_build"].to_s
    failures << "ASC selected build #{build['build'] || '(missing)'} must be #{state['ios_build']}"
  end
  failures
rescue JSON::ParserError => e
  ["Invalid ASC JSON: #{e.message}"]
end

def validate_release_json(path, state, details)
  return ["GitHub Release readback JSON is required"] unless path && File.file?(path)
  payload = JSON.parse(File.read(path))
  tag = payload["tag_name"] || payload["tagName"]
  assets = payload["assets"]
  assets = [] unless assets.is_a?(Array)
  names = assets.map { |asset| asset["name"] }.compact
  expected_tag = "v#{state['ios_version']}"
  failures = []
  failures << "GitHub Release tag #{tag || '(missing)'} must be #{expected_tag}" unless tag == expected_tag
  draft = payload.key?("draft") ? payload["draft"] : payload["isDraft"]
  prerelease = payload.key?("prerelease") ? payload["prerelease"] : payload["isPrerelease"]
  failures << "GitHub Release #{expected_tag} must explicitly be non-draft" unless draft == false
  failures << "GitHub Release #{expected_tag} must explicitly be non-prerelease" unless prerelease == false
  failures << "GitHub Release #{expected_tag} assets must be an array" unless payload["assets"].is_a?(Array)
  state["required_asset_suffixes"].each do |suffix|
    failures << "GitHub Release #{expected_tag} is missing an asset ending in #{suffix}" unless names.any? { |name| name.end_with?(suffix) }
  end
  apk_asset = assets.find { |asset| asset["name"] == details["file_name"] }
  failures << "GitHub Release #{expected_tag} is missing exact APK #{details['file_name']}" unless apk_asset
  ["#{details['file_name']}.sha256", "#{details['file_name']}.provenance.json"].each do |name|
    failures << "GitHub Release #{expected_tag} is missing exact asset #{name}" unless names.include?(name)
  end
  digest = apk_asset && apk_asset["digest"]
  failures << "GitHub APK digest is missing" unless digest
  if digest && digest != "sha256:#{details['sha256']}"
    failures << "GitHub APK digest #{digest} must be sha256:#{details['sha256']}"
  end
  failures
rescue JSON::ParserError => e
  ["Invalid GitHub Release JSON: #{e.message}"]
end

def validate_release_alignment(root = DEFAULT_ROOT, options = {}, apk_details: nil, **legacy_options)
  options = options.merge(legacy_options)
  options.delete(:root)
  state = local_release_state(root)
  failures = validate_local_state(state, expected_tag: options[:expected_tag])
  required = %i[apk checksum provenance asc_json release_json]
  required.each do |key|
    failures << "--final requires --#{key.to_s.tr('_', '-')}" if options[:final] && !options[key]
  end
  details = apk_details
  if options[:apk]
    details ||= inspect_apk(
      options[:apk],
      aapt: options[:aapt] || ENV["ANDROID_AAPT"] || newest_android_tool("aapt"),
      apksigner: options[:apksigner] || ENV["ANDROID_APKSIGNER"] || newest_android_tool("apksigner")
    )
    failures.concat(validate_apk_details(state, details))
    failures.concat(validate_checksum(options[:checksum], details)) if options[:checksum]
    failures.concat(validate_provenance(options[:provenance], state, details, root: root)) if options[:provenance]
  end
  if options[:final] && details
    failures.concat(validate_checksum(options[:checksum], details)) unless options[:checksum].nil?
    failures.concat(validate_provenance(options[:provenance], state, details, root: root)) unless options[:provenance].nil?
    failures.concat(validate_asc_json(options[:asc_json], state))
    failures.concat(validate_release_json(options[:release_json], state, details))
  end
  failures.uniq
rescue Errno::ENOENT, KeyError, JSON::ParserError, RuntimeError => e
  [e.message]
end

def run(argv)
  options = parse_options(argv)
  failures = validate_release_alignment(options.fetch(:root), options)
  if failures.empty?
    puts "Release alignment guard passed."
    0
  else
    warn failures.join("\n")
    1
  end
end

exit run(ARGV) if $PROGRAM_NAME == __FILE__
