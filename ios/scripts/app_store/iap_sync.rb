#!/usr/bin/env ruby
# frozen_string_literal: true

require "bigdecimal"
require "digest/md5"
require "json"
require "optparse"
require_relative "client"

APP_ROOT = File.expand_path("../..", __dir__)
REPO_ROOT = File.expand_path("..", APP_ROOT)
REVIEW_NOTE = "Optional consumable tip visible in the Petites Dents More tab. It unlocks no content, feature, account, service, or entitlement. The complete app remains free.".freeze

def load_config(path)
  JSON.parse(File.read(path))
end

def parse_options(argv)
  options = {
    apply: false,
    config: File.join(APP_ROOT, "fastlane", "release_config.json"),
    key_path: ENV["ASC_API_KEY_PATH"] || File.join(APP_ROOT, "fastlane", "asc_api_key.json")
  }
  OptionParser.new do |parser|
    parser.on("--apply") { options[:apply] = true }
    parser.on("--bundle-id ID") { |value| options[:bundle_id] = value }
    parser.on("--config PATH") { |value| options[:config] = value }
    parser.on("--json") { options[:json] = true }
    parser.on("--key-path PATH") { |value| options[:key_path] = value }
  end.parse!(argv)

  config = load_config(options.fetch(:config))
  options[:bundle_id] ||= config["bundle_id"]
  options[:products] = config.fetch("iap")
  screenshot_input = ENV["IAP_REVIEW_SCREENSHOT"] || config.fetch("iap_review_screenshot")
  screenshot = File.expand_path(screenshot_input, APP_ROOT)
  abort "IAP review screenshot escaped repository root" unless screenshot.start_with?("#{REPO_ROOT}/")
  options[:review_screenshot] = screenshot

  abort "--bundle-id is required" if options[:bundle_id].to_s.empty?
  abort "Exactly three optional tip products are required" unless options[:products].length == 3
  unless AutonomousAscCredentials.available?(key_path: options[:key_path])
    abort "Provide ASC_API_KEY_PATH or APP_STORE_CONNECT_API_KEY_* environment credentials"
  end
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

def all_iaps(client, app_id)
  client.get_all("/v1/apps/#{app_id}/inAppPurchasesV2", {
    "fields[inAppPurchases]" => "name,productId,inAppPurchaseType,state,reviewNote",
    "limit" => "200"
  }).fetch("data")
end

def create_iap(client, app_id, product)
  client.post("/v2/inAppPurchases", {
    data: {
      type: "inAppPurchases",
      attributes: {
        name: product.fetch("reference_name"),
        productId: product.fetch("product_id"),
        inAppPurchaseType: product.fetch("type"),
        reviewNote: REVIEW_NOTE
      },
      relationships: {
        app: { data: { type: "apps", id: app_id } }
      }
    }
  }).fetch("data")
end

def update_iap_metadata(client, iap, product)
  attributes = iap.fetch("attributes")
  return iap if attributes["name"] == product.fetch("reference_name") &&
                attributes["reviewNote"] == REVIEW_NOTE

  client.patch("/v2/inAppPurchases/#{iap.fetch('id')}", {
    data: {
      type: "inAppPurchases",
      id: iap.fetch("id"),
      attributes: {
        name: product.fetch("reference_name"),
        reviewNote: REVIEW_NOTE
      }
    }
  }).fetch("data")
end

def iap_localizations(client, iap_id)
  client.get_all("/v2/inAppPurchases/#{iap_id}/inAppPurchaseLocalizations", {
    "fields[inAppPurchaseLocalizations]" => "locale,name,description",
    "limit" => "50"
  }).fetch("data")
end

def ensure_localizations(client, iap_id, product)
  current = iap_localizations(client, iap_id)
  product.fetch("localizations").each do |locale, copy|
    existing = current.find { |item| item.dig("attributes", "locale") == locale }
    if existing
      attributes = existing.fetch("attributes")
      next if attributes["name"] == copy.fetch("name") &&
              attributes["description"] == copy.fetch("description")

      client.patch("/v1/inAppPurchaseLocalizations/#{existing.fetch('id')}", {
        data: {
          type: "inAppPurchaseLocalizations",
          id: existing.fetch("id"),
          attributes: {
            name: copy.fetch("name"),
            description: copy.fetch("description")
          }
        }
      })
    else
      client.post("/v1/inAppPurchaseLocalizations", {
        data: {
          type: "inAppPurchaseLocalizations",
          attributes: {
            locale: locale,
            name: copy.fetch("name"),
            description: copy.fetch("description")
          },
          relationships: {
            inAppPurchaseV2: {
              data: { type: "inAppPurchases", id: iap_id }
            }
          }
        }
      })
    end
  end
end

def ensure_availability(client, iap_id)
  existing = client.get_optional(
    "/v2/inAppPurchases/#{iap_id}/inAppPurchaseAvailability"
  )
  return existing.fetch("data") if existing

  territories = client.get_all("/v1/territories", {
    "limit" => "200"
  }).fetch("data")
  client.post("/v1/inAppPurchaseAvailabilities", {
    data: {
      type: "inAppPurchaseAvailabilities",
      attributes: { availableInNewTerritories: true },
      relationships: {
        availableTerritories: {
          data: territories.map do |territory|
            { type: "territories", id: territory.fetch("id") }
          end
        },
        inAppPurchase: {
          data: { type: "inAppPurchases", id: iap_id }
        }
      }
    }
  }).fetch("data")
end

def index_included(items)
  items.each_with_object({}) do |item, index|
    index[[item.fetch("type"), item.fetch("id")]] = item
  end
end

def current_price(client, iap_id, territory = "FRA")
  schedule = client.get_optional("/v2/inAppPurchases/#{iap_id}/iapPriceSchedule", {
    "fields[inAppPurchasePriceSchedules]" => "baseTerritory,manualPrices,automaticPrices"
  })&.fetch("data")
  return nil unless schedule

  %w[manualPrices automaticPrices].each do |relationship|
    response = client.get_all(
      "/v1/inAppPurchasePriceSchedules/#{schedule.fetch('id')}/#{relationship}",
      {
        "filter[territory]" => territory,
        "include" => "inAppPurchasePricePoint",
        "fields[inAppPurchasePrices]" => "startDate,endDate,inAppPurchasePricePoint,territory",
        "fields[inAppPurchasePricePoints]" => "customerPrice,territory",
        "limit" => "200"
      }
    )
    included = index_included(response.fetch("included", []))
    price = response.fetch("data").find do |item|
      item.dig("attributes", "endDate").nil?
    end || response.fetch("data").first
    next unless price

    point_id = price.dig(
      "relationships", "inAppPurchasePricePoint", "data", "id"
    )
    return included[["inAppPurchasePricePoints", point_id]]&.dig(
      "attributes", "customerPrice"
    )
  end
  nil
end

def ensure_price(client, iap_id, target, territory = "FRA")
  current = current_price(client, iap_id, territory)
  return current if current && BigDecimal(current.to_s) == BigDecimal(target)

  points = client.get_all("/v2/inAppPurchases/#{iap_id}/pricePoints", {
    "filter[territory]" => territory,
    "fields[inAppPurchasePricePoints]" => "customerPrice,territory",
    "limit" => "200"
  }).fetch("data")
  point = points.find do |candidate|
    BigDecimal(candidate.dig("attributes", "customerPrice").to_s) ==
      BigDecimal(target)
  end
  abort "Missing IAP price point #{target} for #{iap_id} in #{territory}" unless point

  client.post("/v1/inAppPurchasePriceSchedules", {
    data: {
      type: "inAppPurchasePriceSchedules",
      relationships: {
        baseTerritory: { data: { type: "territories", id: territory } },
        inAppPurchase: {
          data: { type: "inAppPurchases", id: iap_id }
        },
        manualPrices: {
          data: [{ type: "inAppPurchasePrices", id: "${price-1}" }]
        }
      }
    },
    included: [{
      type: "inAppPurchasePrices",
      id: "${price-1}",
      attributes: { startDate: nil },
      relationships: {
        inAppPurchasePricePoint: {
          data: {
            type: "inAppPurchasePricePoints",
            id: point.fetch("id")
          }
        }
      }
    }]
  })
  target
end

def review_screenshot(client, iap_id)
  client.get_optional(
    "/v2/inAppPurchases/#{iap_id}/appStoreReviewScreenshot"
  )&.fetch("data")
end

def wait_for_screenshot(client, screenshot_id, iap_id)
  deadline = Time.now + 90
  loop do
    screenshot = client.get(
      "/v1/inAppPurchaseAppStoreReviewScreenshots/#{screenshot_id}"
    ).fetch("data")
    state = screenshot.dig("attributes", "assetDeliveryState", "state")
    return screenshot if state == "COMPLETE"
    if state == "FAILED"
      abort "IAP review screenshot failed for #{iap_id}: #{screenshot.dig('attributes', 'assetDeliveryState', 'errors').inspect}"
    end
    abort "IAP review screenshot timed out for #{iap_id}: #{state}" if Time.now > deadline
    sleep 3
  end
end

def upload_review_screenshot(client, iap_id, path)
  bytes = File.binread(path)
  placeholder = client.post(
    "/v1/inAppPurchaseAppStoreReviewScreenshots",
    {
      data: {
        type: "inAppPurchaseAppStoreReviewScreenshots",
        attributes: {
          fileName: File.basename(path),
          fileSize: bytes.bytesize
        },
        relationships: {
          inAppPurchaseV2: {
            data: { type: "inAppPurchases", id: iap_id }
          }
        }
      }
    }
  ).fetch("data")
  client.upload(
    placeholder.dig("attributes", "uploadOperations"),
    bytes
  )
  client.patch(
    "/v1/inAppPurchaseAppStoreReviewScreenshots/#{placeholder.fetch('id')}",
    {
      data: {
        type: "inAppPurchaseAppStoreReviewScreenshots",
        id: placeholder.fetch("id"),
        attributes: {
          uploaded: true,
          sourceFileChecksum: Digest::MD5.hexdigest(bytes)
        }
      }
    }
  )
  wait_for_screenshot(client, placeholder.fetch("id"), iap_id)
end

def ensure_review_screenshot(client, iap_id, path)
  existing = review_screenshot(client, iap_id)
  state = existing&.dig("attributes", "assetDeliveryState", "state")
  return existing if state == "COMPLETE"
  return wait_for_screenshot(client, existing.fetch("id"), iap_id) if existing && state != "FAILED"

  if existing
    client.delete(
      "/v1/inAppPurchaseAppStoreReviewScreenshots/#{existing.fetch('id')}"
    )
  end
  upload_review_screenshot(client, iap_id, path)
end

def product_status(client, product, iap)
  return { "product_id" => product.fetch("product_id"), "status" => "missing" } unless iap

  locales = iap_localizations(client, iap.fetch("id"))
  screenshot = review_screenshot(client, iap.fetch("id"))
  availability = client.get_optional(
    "/v2/inAppPurchases/#{iap.fetch('id')}/inAppPurchaseAvailability"
  )
  {
    "product_id" => product.fetch("product_id"),
    "asc_id" => iap.fetch("id"),
    "status" => "present",
    "type" => iap.dig("attributes", "inAppPurchaseType"),
    "state" => iap.dig("attributes", "state"),
    "price_fra" => current_price(client, iap.fetch("id")),
    "locales" => locales.map { |item| item.dig("attributes", "locale") }.sort,
    "review_screenshot_state" => screenshot&.dig(
      "attributes", "assetDeliveryState", "state"
    ),
    "available_for_sale" => !availability.nil?
  }
end

def blockers_for(products, statuses, unexpected_ids)
  blockers = []
  blockers << "unexpected_iap:#{unexpected_ids.join(',')}" unless unexpected_ids.empty?
  products.each do |product|
    status = statuses.find { |item| item["product_id"] == product.fetch("product_id") }
    blockers << "missing_iap:#{product.fetch('product_id')}" if status["status"] == "missing"
    next if status["status"] == "missing"
    blockers << "wrong_type:#{product.fetch('product_id')}" unless status["type"] == "CONSUMABLE"
    blockers << "missing_availability:#{product.fetch('product_id')}" unless status["available_for_sale"]
    expected_locales = product.fetch("localizations").keys.sort
    blockers << "missing_localizations:#{product.fetch('product_id')}" unless status["locales"] == expected_locales
    price = status["price_fra"]
    unless price && BigDecimal(price.to_s) == BigDecimal(product.fetch("price_fra"))
      blockers << "wrong_price:#{product.fetch('product_id')}"
    end
    unless status["review_screenshot_state"] == "COMPLETE"
      blockers << "missing_review_screenshot:#{product.fetch('product_id')}"
    end
    blockers << "missing_metadata:#{product.fetch('product_id')}" if status["state"] == "MISSING_METADATA"
  end
  blockers
end

def run(options)
  screenshot = options.fetch(:review_screenshot)
  if options[:apply] && !File.file?(screenshot)
    abort "Missing app-local IAP review screenshot: #{screenshot}"
  end

  client = AutonomousAscClient.new(key_path: options.fetch(:key_path))
  app = find_app(client, options.fetch(:bundle_id))
  products = options.fetch(:products)
  expected_ids = products.map { |product| product.fetch("product_id") }
  iaps = all_iaps(client, app.fetch("id"))
  unexpected_ids = iaps.map { |iap| iap.dig("attributes", "productId") }.compact - expected_ids

  if options[:apply]
    abort "Unexpected IAPs configured: #{unexpected_ids.join(',')}" unless unexpected_ids.empty?
    products.each do |product|
      iap = iaps.find do |candidate|
        candidate.dig("attributes", "productId") == product.fetch("product_id")
      end
      iap ||= create_iap(client, app.fetch("id"), product)
      iap = update_iap_metadata(client, iap, product)
      ensure_availability(client, iap.fetch("id"))
      ensure_localizations(client, iap.fetch("id"), product)
      ensure_price(client, iap.fetch("id"), product.fetch("price_fra"))
      ensure_review_screenshot(client, iap.fetch("id"), screenshot)
    end
    iaps = all_iaps(client, app.fetch("id"))
  end

  statuses = products.map do |product|
    iap = iaps.find do |candidate|
      candidate.dig("attributes", "productId") == product.fetch("product_id")
    end
    product_status(client, product, iap)
  end
  blockers = blockers_for(products, statuses, unexpected_ids)
  {
    "status" => blockers.empty? ? "tip_jar_ready" : "tip_jar_blocked",
    "apply" => options[:apply],
    "app" => {
      "id" => app.fetch("id"),
      "name" => app.dig("attributes", "name"),
      "bundle_id" => app.dig("attributes", "bundleId")
    },
    "review_screenshot" => screenshot,
    "products" => statuses,
    "blockers" => blockers
  }
end

def print_human(payload)
  puts "IAP sync: #{payload.fetch('status')} apply=#{payload.fetch('apply')}"
  payload.fetch("products").each do |product|
    puts "Tip: #{product.fetch('product_id')} state=#{product['state'] || product['status']} price_fra=#{product['price_fra'] || 'missing'} locales=#{product.fetch('locales', []).join(',')} screenshot=#{product['review_screenshot_state'] || 'missing'}"
  end
  puts "Blockers: #{payload.fetch('blockers').empty? ? 'none' : payload.fetch('blockers').join(', ')}"
end

def main(argv)
  options = parse_options(argv)
  payload = run(options)
  options[:json] ? puts(JSON.pretty_generate(payload)) : print_human(payload)
  payload.fetch("blockers").empty? ? 0 : 1
rescue AutonomousAscError => error
  warn error.message
  1
end

exit main(ARGV) if $PROGRAM_NAME == __FILE__
