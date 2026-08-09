# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "tmpdir"
require_relative "release_alignment_guard"

class ReleaseAlignmentGuardTest < Minitest::Test
  SIGNER = "a" * 64

  def test_accepts_matching_local_versions
    with_root do |root|
      assert_empty validate_release_alignment(root)
    end
  end

  def test_rejects_android_ios_mismatch
    with_root(android_version: "1.0.7") do |root|
      failures = validate_release_alignment(root)
      assert failures.any? { |failure| failure.include?("Marketing versions must match") }
    end
  end

  def test_rejects_wrong_expected_tag
    with_root do |root|
      failures = validate_release_alignment(root, { expected_tag: "v1.0.7" })
      assert_includes failures, "GitHub Release tag v1.0.7 must be v1.0.8"
    end
  end

  def test_final_gate_requires_every_readback_and_artifact
    with_root do |root|
      failures = validate_release_alignment(root, { final: true })
      %w[apk checksum provenance asc-json release-json].each do |name|
        assert_includes failures, "--final requires --#{name}"
      end
    end
  end

  def test_rejects_wrong_apk_signer
    with_root do |root|
      details = apk_details.merge("signer_sha256" => "b" * 64)
      failures = validate_release_alignment(root, { apk: "/tmp/fake.apk" }, apk_details: details)
      assert failures.any? { |failure| failure.include?("APK signer") }
    end
  end

  def test_validates_complete_final_gate
    with_root do |root|
      Dir.mktmpdir("release-evidence") do |evidence|
        apk = File.join(evidence, "petites-dents-v1.0.8.apk")
        File.write(apk, "apk")
        details = apk_details.merge("sha256" => Digest::SHA256.file(apk).hexdigest, "file_name" => File.basename(apk))
        checksum = "#{apk}.sha256"
        File.write(checksum, "#{details['sha256']}  #{details['file_name']}\n")
        provenance = "#{apk}.provenance.json"
        File.write(provenance, JSON.pretty_generate(
          "schema_version" => 1,
          "app" => "petites-dents",
          "tag" => "v1.0.8",
          "application_id" => "com.bnjdpn.petitesdents",
          "version_name" => "1.0.8",
          "version_code" => 9,
          "apk" => details["file_name"],
          "apk_sha256" => details["sha256"],
          "certificate_sha256" => SIGNER,
          "source_commit" => "d" * 40,
          "source_tree" => "e" * 40,
          "source_diff_sha256" => "f" * 64,
          "source_diff_files" => [],
          "generated_at" => "2026-08-09T20:00:00Z"
        ))
        asc = File.join(evidence, "asc.json")
        File.write(asc, JSON.pretty_generate(
          "version" => { "version" => "1.0.8", "state" => "READY_FOR_SALE" },
          "selected_build" => { "build" => "1", "state" => "VALID" }
        ))
        release = File.join(evidence, "release.json")
        File.write(release, JSON.pretty_generate(
          "tag_name" => "v1.0.8",
          "draft" => false,
          "prerelease" => false,
          "assets" => [
            { "name" => details["file_name"], "digest" => "sha256:#{details['sha256']}" },
            { "name" => "#{details['file_name']}.sha256" },
            { "name" => "#{details['file_name']}.provenance.json" }
          ]
        ))
        options = { final: true, apk: apk, checksum: checksum, provenance: provenance, asc_json: asc, release_json: release }
        assert_empty validate_release_alignment(root, options, apk_details: details)
      end
    end
  end

  def test_readbacks_require_exact_build_flags_assets_and_digest
    with_root do |root|
      state = local_release_state(root)
      details = apk_details
      Dir.mktmpdir("release-readbacks") do |evidence|
        asc = File.join(evidence, "asc.json")
        File.write(asc, JSON.generate(
          "version" => { "version" => state["ios_version"], "state" => "READY_FOR_SALE" },
          "selected_build" => { "build" => "999", "state" => "VALID" }
        ))
        asc_failures = validate_asc_json(asc, state)
        assert asc_failures.any? { |failure| failure.include?("ASC selected build 999") }

        release = File.join(evidence, "release.json")
        File.write(release, JSON.generate(
          "tag_name" => "v#{state['ios_version']}",
          "assets" => [
            { "name" => details["file_name"] },
            { "name" => "#{details['file_name']}.sha256" },
            { "name" => "#{details['file_name']}.provenance.json" }
          ]
        ))
        release_failures = validate_release_json(release, state, details)
        assert_includes release_failures, "GitHub APK digest is missing"
        assert release_failures.any? { |failure| failure.include?("explicitly be non-draft") }
        assert release_failures.any? { |failure| failure.include?("explicitly be non-prerelease") }
      end
    end
  end

  private

  def apk_details
    {
      "application_id" => "com.bnjdpn.petitesdents",
      "version_code" => 9,
      "version_name" => "1.0.8",
      "signer_sha256" => SIGNER,
      "sha256" => "c" * 64,
      "file_name" => "petites-dents-v1.0.8.apk"
    }
  end

  def with_root(android_version: "1.0.8")
    Dir.mktmpdir("release-alignment") do |root|
      FileUtils.mkdir_p(File.join(root, "app"))
      File.write(File.join(root, "app", "build.gradle.kts"), <<~KOTLIN)
        android { defaultConfig {
          applicationId = "com.bnjdpn.petitesdents"
          versionCode = 9
          versionName = "#{android_version}"
        } }
      KOTLIN
      FileUtils.mkdir_p(File.join(root, "ios", "fastlane"))
      File.write(File.join(root, "ios", "project.yml"), "MARKETING_VERSION: \"1.0.8\"\nCURRENT_PROJECT_VERSION: 1\n")
      File.write(File.join(root, "ios", "fastlane", "release_config.json"), JSON.generate("version" => "1.0.8"))
      FileUtils.mkdir_p(File.join(root, "release"))
      File.write(File.join(root, "release", "android_release.json"), JSON.generate(
        "artifact_slug" => "petites-dents",
        "application_id" => "com.bnjdpn.petitesdents",
        "signer_sha256" => SIGNER,
        "required_asset_suffixes" => [".apk", ".apk.sha256", ".apk.provenance.json"]
      ))
      yield root
    end
  end
end
