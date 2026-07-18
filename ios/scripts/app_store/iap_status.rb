#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "optparse"
require_relative "client"

def app_root
  File.expand_path("../..", __dir__)
end

def load_config(path)
  return {} unless path && File.file?(path)

  JSON.parse(File.read(path))
end

def parse_options(argv)
  options = {
    config: File.join(app_root, "fastlane", "release_config.json"),
    key_path: ENV["ASC_API_KEY_PATH"] || File.join(app_root, "fastlane", "asc_api_key.json")
  }
  OptionParser.new do |opts|
    opts.on("--bundle-id ID") { |value| options[:bundle_id] = value }
    opts.on("--config PATH") { |value| options[:config] = value }
    opts.on("--json") { options[:json] = true }
    opts.on("--key-path PATH") { |value| options[:key_path] = value }
  end.parse!(argv)

  config = load_config(options[:config])
  options[:bundle_id] ||= config["bundle_id"]
  options[:expected_iap] = config.fetch("iap", [])

  abort "--bundle-id is required" if options[:bundle_id].to_s.empty?
  abort "Provide ASC_API_KEY_PATH or APP_STORE_CONNECT_API_KEY_* environment credentials" unless AutonomousAscCredentials.available?(key_path: options[:key_path])

  options
end

def find_app(client, bundle_id)
  app = client.get("/v1/apps", {
    "filter[bundleId]" => bundle_id,
    "fields[apps]" => "name,bundleId,sku,primaryLocale"
  }).fetch("data").first
  abort "App not found for bundle id #{bundle_id}" unless app

  app
end

def asc_iap_items(client, app_id)
  client.get_all("/v1/apps/#{app_id}/inAppPurchasesV2", {
    "fields[inAppPurchases]" => "name,productId,inAppPurchaseType,state,reviewNote",
    "limit" => "200"
  }).fetch("data").map do |item|
    {
      "id" => item.fetch("id"),
      "product_id" => item.dig("attributes", "productId"),
      "name" => item.dig("attributes", "name"),
      "type" => item.dig("attributes", "inAppPurchaseType"),
      "state" => item.dig("attributes", "state")
    }
  end
end

def expected_product_ids(expected_iap)
  expected_iap.map { |item| item["product_id"] || item["productId"] || item["id"] }.compact
end

def status_payload(app, actual_items, expected_iap)
  expected_ids = expected_product_ids(expected_iap)
  actual_ids = actual_items.map { |item| item["product_id"] }.compact
  missing = expected_ids - actual_ids
  unexpected = actual_ids - expected_ids
  state = missing.empty? && unexpected.empty? ? "ok" : "drift"

  {
    "status" => state,
    "app" => {
      "id" => app.fetch("id"),
      "name" => app.dig("attributes", "name"),
      "bundle_id" => app.dig("attributes", "bundleId")
    },
    "iap" => {
      "expected_count" => expected_iap.length,
      "actual_count" => actual_items.length,
      "missing_product_ids" => missing,
      "unexpected_product_ids" => unexpected,
      "items" => actual_items
    }
  }
end

def print_human(payload)
  puts "App: #{payload.dig("app", "name")} (#{payload.dig("app", "bundle_id")}) id=#{payload.dig("app", "id")}"
  iap = payload.fetch("iap")
  puts "IAP: expected=#{iap["expected_count"]} actual=#{iap["actual_count"]} missing=#{iap["missing_product_ids"].join(",")} unexpected=#{iap["unexpected_product_ids"].join(",")}"
  iap.fetch("items").each do |item|
    puts "  #{item["product_id"]}: state=#{item["state"]} type=#{item["type"]} name=#{item["name"]}"
  end
  puts "Status: #{payload["status"]}"
end

begin
  options = parse_options(ARGV)
  client = AutonomousAscClient.new(key_path: options.fetch(:key_path))
  app = find_app(client, options.fetch(:bundle_id))
  payload = status_payload(app, asc_iap_items(client, app.fetch("id")), options.fetch(:expected_iap))

  if options[:json]
    puts JSON.pretty_generate(payload)
  else
    print_human(payload)
  end

  exit(payload["status"] == "ok" ? 0 : 1)
rescue AutonomousAscError => e
  warn e.message
  exit 1
end
