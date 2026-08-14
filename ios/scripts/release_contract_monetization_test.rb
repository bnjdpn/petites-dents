# frozen_string_literal: true

require "json"
require "minitest/autorun"
require_relative "release_contract"

class PetitesDentsReleaseContractMonetizationTest < Minitest::Test
  CONFIG_PATH = File.expand_path("../fastlane/release_config.json", __dir__)

  def test_current_release_configuration_is_coherent
    assert_empty PetitesDentsReleaseContract.monetization_errors(current_config)
  end

  def test_future_app_specific_paid_plan_is_supported
    config = current_config
    config["price"] = "3.99"
    config["pricing"] = { "target_price" => "3.99", "territory" => "FRA" }
    config["iap"] = [
      { "product_id" => "com.bnjdpn.petitesdents.lifetime", "type" => "NON_CONSUMABLE" }
    ]
    config["iap_products"] = ["com.bnjdpn.petitesdents.lifetime"]

    assert_empty PetitesDentsReleaseContract.monetization_errors(config)
  end

  def test_incoherent_price_and_duplicate_products_fail_closed
    config = current_config
    config["price"] = "1.99"
    duplicate = { "product_id" => "duplicate", "type" => "CONSUMABLE" }
    config["iap"] = [duplicate, duplicate.dup]
    config["iap_products"] = ["different"]

    errors = PetitesDentsReleaseContract.monetization_errors(config)

    assert_includes errors, "top-level price must match configured target price"
    assert_includes errors, "IAP product IDs must be unique"
    assert_includes errors, "iap_products must match the configured IAP order"
  end

  private

  def current_config
    JSON.parse(File.binread(CONFIG_PATH))
  end
end
