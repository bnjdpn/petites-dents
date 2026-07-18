#!/usr/bin/env ruby
# frozen_string_literal: true

require "bigdecimal"
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

def parse_price(value)
  value.to_s.empty? ? nil : BigDecimal(value.to_s)
end

def parse_options(argv)
  options = {
    apply: false,
    config: File.join(app_root, "fastlane", "release_config.json"),
    key_path: ENV["ASC_API_KEY_PATH"] || File.join(app_root, "fastlane", "asc_api_key.json"),
    territory: "FRA"
  }
  command = argv.first && !argv.first.start_with?("-") ? argv.shift : "check"

  OptionParser.new do |opts|
    opts.on("--apply") { options[:apply] = true }
    opts.on("--bundle-id ID") { |value| options[:bundle_id] = value }
    opts.on("--config PATH") { |value| options[:config] = value }
    opts.on("--json") { options[:json] = true }
    opts.on("--key-path PATH") { |value| options[:key_path] = value }
    opts.on("--target-price PRICE") { |value| options[:target_price] = parse_price(value) }
    opts.on("--territory ID") { |value| options[:territory] = value.upcase }
  end.parse!(argv)

  config = load_config(options[:config])
  pricing = config.fetch("pricing", {})
  options[:bundle_id] ||= config["bundle_id"]
  options[:territory] = (pricing["territory"] || options[:territory]).upcase
  options[:target_price] ||= parse_price(pricing["target_price"] || pricing["price"])

  abort "Unknown pricing command: #{command}" unless %w[check set].include?(command)
  abort "--bundle-id is required" if options[:bundle_id].to_s.empty?
  abort "Provide ASC_API_KEY_PATH or APP_STORE_CONNECT_API_KEY_* environment credentials" unless AutonomousAscCredentials.available?(key_path: options[:key_path])

  [command, options]
end

def find_app(client, bundle_id)
  app = client.get("/v1/apps", {
    "filter[bundleId]" => bundle_id,
    "fields[apps]" => "name,bundleId,sku,primaryLocale"
  }).fetch("data").first
  abort "App not found for bundle id #{bundle_id}" unless app

  app
end

def included_index(response)
  response.fetch("included", []).each_with_object({}) do |item, index|
    index[[item.fetch("type"), item.fetch("id")]] = item
  end
end

def price_schedule(client, app_id)
  client.get("/v1/apps/#{app_id}/appPriceSchedule", {
    "fields[appPriceSchedules]" => "baseTerritory,manualPrices,automaticPrices"
  }).fetch("data")
end

def base_territory(client, schedule_id)
  client.get("/v1/appPriceSchedules/#{schedule_id}/baseTerritory", {
    "fields[territories]" => "currency"
  }).fetch("data")
end

def relationship_prices(client, schedule_id, relationship, territory)
  response = client.get_all("/v1/appPriceSchedules/#{schedule_id}/#{relationship}", {
    "filter[territory]" => territory,
    "include" => "appPricePoint,territory",
    "fields[appPrices]" => "manual,startDate,endDate,appPricePoint,territory",
    "fields[appPricePoints]" => "customerPrice,proceeds,territory",
    "fields[territories]" => "currency",
    "limit" => "200"
  })
  included = included_index(response)
  response.fetch("data").map do |price|
    price_point_id = price.dig("relationships", "appPricePoint", "data", "id")
    territory_id = price.dig("relationships", "territory", "data", "id")
    price_point = included[["appPricePoints", price_point_id]]
    territory_info = included[["territories", territory_id]]
    {
      "relationship" => relationship,
      "manual" => price.dig("attributes", "manual"),
      "start_date" => price.dig("attributes", "startDate"),
      "end_date" => price.dig("attributes", "endDate"),
      "territory" => territory_id,
      "currency" => territory_info&.dig("attributes", "currency"),
      "customer_price" => price_point&.dig("attributes", "customerPrice"),
      "proceeds" => price_point&.dig("attributes", "proceeds"),
      "price_point_id" => price_point_id
    }
  end
rescue AutonomousAscError => error
  # A brand-new ASC app exposes a placeholder price-schedule relationship
  # before its first schedule is created. Its price collections return 404;
  # treat that state as an empty schedule so `pricing set --apply` can create it.
  return [] if error.status.to_s == "404"

  raise
end

def current_price(client, schedule_id, territory)
  prices = []
  prices.concat(relationship_prices(client, schedule_id, "manualPrices", territory))
  prices.concat(relationship_prices(client, schedule_id, "automaticPrices", territory))
  prices.find { |price| price["end_date"].nil? } || prices.first
end

def find_price_point(client, app_id, territory, target_price)
  response = client.get_all("/v1/apps/#{app_id}/appPricePoints", {
    "filter[territory]" => territory,
    "include" => "territory",
    "fields[appPricePoints]" => "customerPrice,proceeds,territory",
    "fields[territories]" => "currency",
    "limit" => "200"
  })
  included = included_index(response)

  response.fetch("data").each do |price_point|
    next unless price_point.dig("attributes", "customerPrice")
    next unless BigDecimal(price_point.dig("attributes", "customerPrice")) == target_price

    territory_id = price_point.dig("relationships", "territory", "data", "id")
    territory_info = included[["territories", territory_id]]
    return {
      "id" => price_point.fetch("id"),
      "territory" => territory_id,
      "currency" => territory_info&.dig("attributes", "currency"),
      "customer_price" => price_point.dig("attributes", "customerPrice"),
      "proceeds" => price_point.dig("attributes", "proceeds")
    }
  end

  nil
end

def price_schedule_body(app_id:, territory:, price_point_id:)
  {
    data: {
      type: "appPriceSchedules",
      relationships: {
        app: {
          data: {
            type: "apps",
            id: app_id
          }
        },
        baseTerritory: {
          data: {
            type: "territories",
            id: territory
          }
        },
        manualPrices: {
          data: [
            {
              type: "appPrices",
              id: "${price-0}"
            }
          ]
        }
      }
    },
    included: [
      {
        type: "appPrices",
        id: "${price-0}",
        attributes: {
          startDate: nil,
          endDate: nil
        },
        relationships: {
          appPricePoint: {
            data: {
              type: "appPricePoints",
              id: price_point_id
            }
          },
          territory: {
            data: {
              type: "territories",
              id: territory
            }
          }
        }
      }
    ]
  }
end

def print_human(payload)
  puts "App: #{payload.dig("app", "name")} (#{payload.dig("app", "bundle_id")}) id=#{payload.dig("app", "id")}"
  puts "Pricing: schedule=#{payload.dig("pricing", "schedule_id")} base=#{payload.dig("pricing", "base_territory")} currency=#{payload.dig("pricing", "base_currency")}"
  current = payload.dig("pricing", "current_price")
  if current
    puts "Current #{current["territory"]} price: #{current["customer_price"]} #{current["currency"]} via #{current["relationship"]} point=#{current["price_point_id"]}"
  else
    puts "Current price: none for #{payload.dig("pricing", "territory")}"
  end
  target = payload.dig("pricing", "target_price_point")
  return unless target

  puts "Target price point: #{target["customer_price"]} #{target["currency"]} id=#{target["id"]} proceeds=#{target["proceeds"]}"
end

if $PROGRAM_NAME == __FILE__
begin
  command, options = parse_options(ARGV)
  client = AutonomousAscClient.new(key_path: options.fetch(:key_path))
  app = find_app(client, options.fetch(:bundle_id))
  schedule = price_schedule(client, app.fetch("id"))
  base = base_territory(client, schedule.fetch("id"))
  current = current_price(client, schedule.fetch("id"), options.fetch(:territory))
  target_point = options[:target_price] && find_price_point(client, app.fetch("id"), options.fetch(:territory), options.fetch(:target_price))

  payload = {
    "command" => command,
    "app" => {
      "id" => app.fetch("id"),
      "name" => app.dig("attributes", "name"),
      "bundle_id" => app.dig("attributes", "bundleId")
    },
    "pricing" => {
      "schedule_id" => schedule.fetch("id"),
      "base_territory" => base&.fetch("id"),
      "base_currency" => base&.dig("attributes", "currency"),
      "territory" => options.fetch(:territory),
      "current_price" => current,
      "target_price" => options[:target_price]&.to_s("F"),
      "target_price_point" => target_point
    }
  }

  if command == "set"
    abort "pricing set requires --target-price or fastlane/release_config.json pricing.price" unless options[:target_price]
    abort "No ASC price point for #{options.fetch(:territory)} #{options[:target_price].to_s("F")}" unless target_point
    if current && current["customer_price"] && BigDecimal(current["customer_price"]) == options[:target_price]
      payload["status"] = "already_current"
    elsif options[:apply]
      response = client.post("/v1/appPriceSchedules", price_schedule_body(
        app_id: app.fetch("id"),
        territory: options.fetch(:territory),
        price_point_id: target_point.fetch("id")
      ))
      payload["status"] = "updated"
      payload["created_schedule_id"] = response.fetch("data").fetch("id")
    else
      payload["status"] = "dry_run"
      payload["dry_run_request"] = "POST /v1/appPriceSchedules"
    end
  else
    payload["status"] = "ok"
  end

  if options[:json]
    puts JSON.pretty_generate(payload)
  else
    print_human(payload)
    puts "Status: #{payload["status"]}"
  end
rescue AutonomousAscError => e
  warn e.message
  exit 1
end
end
