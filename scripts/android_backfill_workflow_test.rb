# frozen_string_literal: true

require "minitest/autorun"

class AndroidBackfillWorkflowTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  WORKFLOW_PATH = File.join(ROOT, ".github", "workflows", "android-v1.0.7-signed-backfill.yml")
  WORKFLOW = File.read(WORKFLOW_PATH)
  BASE_COMMIT = "c4df7b3fa37adfd9f6de2e7420069c0fed6b7107"
  SOURCE_COMMIT = "3f869bb87754d9a8e5ca8497dc69fa12e84a6901"
  SOURCE_TREE = "4930fb59293ab131e52815bbfe19c082a412ca18"
  SIGNER = "f126e90193736e65f8145d6cb6562487bce86cd609cc4a125ab754aaf7a6128f"
  SECRETS = %w[
    ANDROID_RELEASE_KEYSTORE_BASE64
    ANDROID_RELEASE_STORE_PASSWORD
    ANDROID_RELEASE_KEY_ALIAS
    ANDROID_RELEASE_KEY_PASSWORD
  ].freeze

  def test_is_manual_build_only_and_read_only
    assert_match(/^on:\n  workflow_dispatch:\n/, WORKFLOW)
    assert_match(/^permissions:\n  contents: read\n/, WORKFLOW)
    refute_match(/^\s{2}(?:push|pull_request|release|schedule):/m, WORKFLOW)
    refute_match(/contents:\s*write/, WORKFLOW)
  end

  def test_candidate_and_signer_are_locked
    assert_operator WORKFLOW.scan(SOURCE_COMMIT).length, :>=, 3
    assert_operator WORKFLOW.scan(BASE_COMMIT).length, :>=, 1
    assert_operator WORKFLOW.scan(SOURCE_TREE).length, :>=, 2
    assert_operator WORKFLOW.scan(SIGNER).length, :>=, 2
    assert_match(/EXPECTED_VERSION_NAME: "1\.0\.7"/, WORKFLOW)
    assert_match(/EXPECTED_VERSION_CODE: "8"/, WORKFLOW)
    assert_match(/REQUESTED_SOURCE_COMMIT.*EXPECTED_SOURCE_COMMIT/, WORKFLOW)
  end

  def test_all_signing_secrets_are_required_but_not_materialized_in_source
    SECRETS.each do |name|
      assert_match(/secrets\.#{name}/, WORKFLOW)
      assert_match(/test -n "\$\{!name\}"/, WORKFLOW)
    end
    assert_match(/umask 077/, WORKFLOW)
    assert_match(/trap cleanup_keystore EXIT/, WORKFLOW)
  end

  def test_reconstructed_source_is_built_without_runtime_patch
    assert_match(/EXPECTED_SOURCE_REF: release\/reconstruct-petites-dents-1\.0\.7-android-source/, WORKFLOW)
    assert_match(/Reconstructed source worktree is not clean/, WORKFLOW)
    assert_match(/Reconstructed source worktree changed during the build/, WORKFLOW)
    assert_match(/"source_diff_sha256" => "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"/, WORKFLOW)
    assert_match(/"source_diff_files" => \[\]/, WORKFLOW)
    refute_match(/replacements =/, WORKFLOW)
    refute_match(/File\.binwrite/, WORKFLOW)
    refute_match(/install -m 0644 release\/android_release\.json/, WORKFLOW)
    refute_match(/git -C "\$worktree" add -N/, WORKFLOW)
  end

  def test_build_executes_tests_and_release_assembly_before_validation
    assert_match(%r{\./gradlew --no-daemon --stacktrace test assembleRelease}, WORKFLOW)
    assert_match(/NO-SOURCE is forbidden/, WORKFLOW)
    assert_match(/prepare_android_release\.rb/, WORKFLOW)
    assert_match(/release_alignment_guard\.rb/, WORKFLOW)
  end

  def test_android_build_tools_are_resolved_from_runner_and_fail_closed
    assert_match(/build_tools_root="\$\{ANDROID_HOME:\?ANDROID_HOME is required\}\/build-tools"/, WORKFLOW)
    assert_match(/find "\$build_tools_root" .* LC_ALL=C sort -V/, WORKFLOW)
    assert_match(/No Android build-tools version found/, WORKFLOW)
    assert_match(/aapt is missing or not executable/, WORKFLOW)
    assert_match(/apksigner is missing or not executable/, WORKFLOW)
    assert_match(/export ANDROID_AAPT ANDROID_APKSIGNER/, WORKFLOW)
    refute_match(%r{Library/Android/sdk}, WORKFLOW)
  end

  def test_only_short_lived_actions_artifact_is_uploaded
    assert_match(%r{actions/upload-artifact@[0-9a-f]{40}}, WORKFLOW)
    assert_match(/retention-days: 1/, WORKFLOW)
    assert_match(/if-no-files-found: error/, WORKFLOW)
    refute_match(/\bgh\s+release\b/, WORKFLOW)
    refute_match(/\bgit\s+tag\b/, WORKFLOW)
    refute_match(/--clobber\b/, WORKFLOW)
    refute_match(/create[-_ ]release/i, WORKFLOW)
  end
end
