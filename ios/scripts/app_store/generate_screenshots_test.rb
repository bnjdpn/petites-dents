#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "securerandom"
require_relative "generate_screenshots"

class PetitesDentsScreenshotScheduleTest < Minitest::Test
  ROOT = File.expand_path("../../..", __dir__)
  CONFIG = JSON.parse(File.binread(File.join(ROOT, "ios", "fastlane", "release_config.json")))
  DEVICE_UDIDS = {
    "iPhone-17-Pro-Max" => "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA",
    "iPad-Pro-13-M5" => "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB"
  }.freeze

  class RecordingRunner
    attr_reader :commands

    def initialize
      @commands = []
    end

    def run!(*command, **_options)
      @commands << command
      ""
    end
  end

  class ProbeGenerator < PetitesDentsScreenshots::Generator
    attr_reader :build_count, :cells

    private

    def build_for_testing_once!
      @build_count = (@build_count || 0) + 1
    end

    def capture_cell(locale, simulator, udid)
      @cells ||= []
      @cells << [locale, simulator.fetch("name_suffix"), udid]
    end

    def write_manifest!
      true
    end
  end

  def test_each_exact_udid_handles_every_locale_without_device_churn
    schedule = PetitesDentsScreenshots::DeviceSchedule.new(
      locales: CONFIG.fetch("media_locales"),
      simulators: CONFIG.fetch("simulators"),
      device_udids: DEVICE_UDIDS
    )

    assert_equal 2, schedule.groups.length
    assert_equal DEVICE_UDIDS.values.sort, schedule.groups.map { |group| group.fetch("udid") }.sort
    schedule.groups.each do |group|
      assert_equal CONFIG.fetch("media_locales"), group.fetch("locales")
    end
    assert_equal 6, schedule.groups.sum { |group| group.fetch("locales").length }
  end

  def test_schedule_refuses_missing_or_duplicate_udids
    assert_raises(PetitesDentsScreenshots::Error) do
      PetitesDentsScreenshots::DeviceSchedule.new(
        locales: CONFIG.fetch("media_locales"),
        simulators: CONFIG.fetch("simulators"),
        device_udids: { "iPhone-17-Pro-Max" => DEVICE_UDIDS.fetch("iPhone-17-Pro-Max") }
      )
    end
    assert_raises(PetitesDentsScreenshots::Error) do
      PetitesDentsScreenshots::DeviceSchedule.new(
        locales: CONFIG.fetch("media_locales"),
        simulators: CONFIG.fetch("simulators"),
        device_udids: DEVICE_UDIDS.transform_values { DEVICE_UDIDS.values.first }
      )
    end
  end

  def test_pilot_enables_gradle_caches_and_declares_media_inputs
    properties = File.binread(File.join(ROOT, "gradle.properties"))
    assert_includes properties, "org.gradle.caching=true"
    assert_includes properties, "org.gradle.configuration-cache=true"

    media = JSON.parse(File.binread(File.join(ROOT, "ios", "fastlane", "media_inputs.json")))
    assert_equal CONFIG.fetch("media_locales").sort, media.fetch("localizations").keys.sort
    %w[ui assets fixtures framing].each { |group| refute_empty media.fetch(group) }
  end

  def test_ui_test_leaves_locale_control_to_xcodebuild
    source = File.binread(File.join(ROOT, "ios", "PetitesDentsUITests", "PetitesDentsUITests.swift"))
    screenshot_flow = source[/func testStoreScreenshots\(\) throws \{.*?\n    \}/m]

    refute_includes screenshot_flow, "-AppleLanguages"
    refute_includes screenshot_flow, "-AppleLocale"
  end

  def test_localization_guard_rejects_french_images_identical_to_english
    entries = %w[en-US en-GB fr-FR].map do |locale|
      {
        "locale" => locale,
        "display_type" => "APP_IPHONE_67",
        "scene" => "01_Mouth",
        "sha256" => "a" * 64
      }
    end

    assert_raises(PetitesDentsScreenshots::Error) do
      PetitesDentsScreenshots::LocalizationGuard.validate!(entries)
    end
  end

  def test_generator_reuses_two_leased_devices_for_all_six_cells
    run_id = "schedule-test-#{SecureRandom.hex(4)}"
    runner = RecordingRunner.new
    generator = ProbeGenerator.new(
      app_root: ROOT,
      run_id: run_id,
      candidate_id: "c" * 64,
      device_udids: DEVICE_UDIDS,
      runner: runner
    )

    generator.run!

    assert_equal 1, generator.build_count
    assert_equal 6, generator.cells.length
    shutdowns = runner.commands.select { |command| command[0..2] == ["xcrun", "simctl", "shutdown"] }
    erases = runner.commands.select { |command| command[0..2] == ["xcrun", "simctl", "erase"] }
    boots = runner.commands.select { |command| command[0..2] == ["xcrun", "simctl", "boot"] }
    bootstatuses = runner.commands.select { |command| command[0..2] == ["xcrun", "simctl", "bootstatus"] }
    creates = runner.commands.select { |command| command[0..2] == ["xcrun", "simctl", "create"] }
    deletes = runner.commands.select { |command| command[0..2] == ["xcrun", "simctl", "delete"] }
    assert_equal DEVICE_UDIDS.values.sort, erases.map { |command| command.fetch(3) }.sort
    DEVICE_UDIDS.values.each do |udid|
      shutdown_index = runner.commands.index { |command| command[0..3] == ["xcrun", "simctl", "shutdown", udid] }
      erase_index = runner.commands.index { |command| command[0..3] == ["xcrun", "simctl", "erase", udid] }
      boot_index = runner.commands.index { |command| command[0..3] == ["xcrun", "simctl", "boot", udid] }
      refute_nil shutdown_index
      assert_operator shutdown_index, :<, erase_index
      assert_operator erase_index, :<, boot_index
    end
    locale_defaults = runner.commands.select { |command| command[0..2] == ["xcrun", "simctl", "spawn"] }
    assert_equal 6, shutdowns.length
    assert_equal 6, boots.length
    assert_equal 6, bootstatuses.length
    assert_equal 8, locale_defaults.length
    assert_empty creates
    assert_empty deletes
  ensure
    FileUtils.rm_rf(File.join(ROOT, "Builds", "AppStore", "PetitesDents", run_id)) if run_id
    FileUtils.rm_rf(File.join("/private/tmp/apps-factory/PetitesDents", run_id)) if run_id
  end
end
