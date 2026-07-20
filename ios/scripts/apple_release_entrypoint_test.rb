# frozen_string_literal: true

class AppleReleaseEntrypointTest
  REPO_ROOT = File.expand_path("../..", __dir__)
  FASTFILE = File.join(__dir__, "..", "fastlane", "Fastfile")

  def test_github_actions_workflows_are_absent
    workflows = Dir.glob(File.join(REPO_ROOT, ".github", "workflows", "*.{yml,yaml}"))

    assert(workflows.empty?, "GitHub Actions is disabled; found #{workflows.join(', ')}")
  end

  def test_signing_consumes_only_wrapper_injected_identity
    source = File.read(FASTFILE)
    refute_match(/\bget_certificates\s*\(/, source)
    refute_match(/\bimport_certificate\s*\(/, source)
    refute_match(/\bmatch\s+nuke\b/, source)
    refute_includes source, "-allowProvisioningUpdates"
    assert_includes source, 'ENV["APPLE_RELEASE_CERTIFICATE_MUTATIONS"] == "forbidden"'
    assert_includes source, 'ENV.fetch("APPLE_RELEASE_IDENTITY_SHA1"'
    assert_includes source, 'ENV.fetch("APPLE_RELEASE_CERTIFICATE_ID"'
    assert_includes source, 'ENV.fetch("APPLE_RELEASE_XCCONFIG_FILE"'
    assert_includes source, "readonly: true"
    assert_includes source, "cert_id: certificate_id"
    assert_includes source, '"-xcconfig #{@petites_dents_release_xcconfig.shellescape}"'
  end

  private

  def assert(condition, message = "assertion failed")
    raise message unless condition
  end

  def refute(condition, message = "refutation failed")
    raise message if condition
  end

  def refute_nil(value, message = "expected a value")
    assert(!value.nil?, message)
  end

  def assert_equal(expected, actual)
    assert(expected == actual, "Expected #{expected.inspect}, got #{actual.inspect}")
  end

  def assert_includes(collection, item)
    assert(collection.include?(item), "Expected content to include #{item.inspect}")
  end

  def refute_includes(collection, item)
    refute(collection.include?(item), "Expected content not to include #{item.inspect}")
  end

  def refute_match(pattern, value)
    refute(pattern.match?(value), "Expected content not to match #{pattern.inspect}")
  end
end

tests = AppleReleaseEntrypointTest.public_instance_methods(false).grep(/^test_/).sort
tests.each do |test|
  AppleReleaseEntrypointTest.new.public_send(test)
  print "."
rescue StandardError => error
  warn "\n#{test} failed: #{error.message}"
  warn error.backtrace.join("\n")
  exit 1
end
puts "\n#{tests.length} apple-release entrypoint tests passed"
