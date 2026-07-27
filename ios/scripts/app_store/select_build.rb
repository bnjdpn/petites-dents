#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
require "time"
require_relative "client"

options = {}
OptionParser.new do |parser|
  parser.on("--bundle-id ID") { |value| options[:bundle_id] = value }
  parser.on("--version VERSION") { |value| options[:version] = value }
  parser.on("--build BUILD") { |value| options[:build] = value }
  parser.on("--key-path PATH") { |value| options[:key_path] = value }
end.parse!(ARGV)
%i[bundle_id version build key_path].each do |key|
  abort "--#{key.to_s.tr('_', '-')} is required" if options[key].to_s.empty?
end
abort "Missing ASC API key at #{options[:key_path]}" unless File.file?(options[:key_path])

client = AutonomousAscClient.new(key_path: options.fetch(:key_path))
app = client.get("/v1/apps", {
  "filter[bundleId]" => options.fetch(:bundle_id),
  "fields[apps]" => "name,bundleId"
}).fetch("data").find { |item| item.dig("attributes", "bundleId") == options.fetch(:bundle_id) }
abort "App not found for #{options.fetch(:bundle_id)}" unless app

version = client.get_all("/v1/apps/#{app.fetch('id')}/appStoreVersions", {
  "filter[platform]" => "IOS",
  "filter[versionString]" => options.fetch(:version),
  "fields[appStoreVersions]" => "versionString,appStoreState,platform"
}).fetch("data").find { |item| item.dig("attributes", "versionString") == options.fetch(:version) }
abort "Version #{options.fetch(:version)} not found" unless version

build = client.get_all("/v1/builds", {
  "filter[app]" => app.fetch("id"),
  "fields[builds]" => "version,processingState,uploadedDate,expired,usesNonExemptEncryption",
  "limit" => "200"
}).fetch("data").select do |item|
  item.dig("attributes", "version").to_s == options.fetch(:build).to_s
end.sort_by do |item|
  Time.parse(item.dig("attributes", "uploadedDate").to_s)
rescue ArgumentError
  Time.at(0)
end.last
abort "Build #{options.fetch(:build)} not found" unless build
abort "Build is not VALID" unless build.dig("attributes", "processingState") == "VALID"

client.patch("/v1/appStoreVersions/#{version.fetch('id')}/relationships/build", {
  data: { type: "builds", id: build.fetch("id") }
})
puts "Selected build #{options.fetch(:build)}"
