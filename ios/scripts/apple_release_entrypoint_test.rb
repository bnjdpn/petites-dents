# frozen_string_literal: true

class AppleReleaseEntrypointTest
  REPO_ROOT = File.expand_path("../..", __dir__)
  WORKFLOW = File.join(REPO_ROOT, ".github", "workflows", "app-store-cd.yml")
  FASTFILE = File.join(__dir__, "..", "fastlane", "Fastfile")
  SURFACE = "petites-dents"
  LANES = %w[release_contract asc_status release_quick submit_review].freeze

  def workflow
    @workflow ||= File.read(WORKFLOW)
  end

  def workflow_steps
    workflow.scan(/^      - .*?(?=^      - |\z)/m)
  end

  def test_live_doctor_fails_closed_before_fastlane
    step = workflow_steps.find { |candidate| candidate.include?("doctor --live --json") }
    refute_nil step
    assert_includes workflow, "APPLE_RELEASE_BIN: /Users/benjamin/Documents/Apps/bin/apple-release"
    assert_includes step, "set -euo pipefail"
    assert_includes step, 'test -x "$APPLE_RELEASE_BIN"'
    assert_includes step, '"$APPLE_RELEASE_BIN" doctor --live --json'
  end

  def test_every_fastlane_action_uses_the_shared_surface
    LANES.each do |lane|
      step = workflow_steps.find { |candidate| candidate.include?("bundle exec fastlane #{lane}") }
      refute_nil step, "missing workflow step for #{lane}"
      assert_includes step, '"$APPLE_RELEASE_BIN" run petites-dents -- /bin/zsh -lc'
      assert_includes step, 'cd "$GITHUB_WORKSPACE/ios"'
    end
    assert_equal LANES.sort, workflow.scan(/bundle exec fastlane ([a-z_]+)/).flatten.sort
  end

  def test_legacy_asc_secret_bridge_is_absent
    %w[APP_STORE_CONNECT_API_KEY_KEY_ID APP_STORE_CONNECT_API_KEY_ISSUER_ID APP_STORE_CONNECT_API_KEY_KEY ASC_API_KEY_PATH].each do |name|
      refute_includes workflow, name
    end
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
