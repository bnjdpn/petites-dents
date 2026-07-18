#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "digest/md5"
require "net/http"
require "spaceship"
require "uri"

module AutonomousAscCredentials
  ENV_KEYS = %w[
    APP_STORE_CONNECT_API_KEY_KEY_ID
    APP_STORE_CONNECT_API_KEY_ISSUER_ID
    APP_STORE_CONNECT_API_KEY_KEY
  ].freeze

  def self.available?(key_path: nil)
    (key_path && File.file?(key_path)) || ENV_KEYS.all? { |key| !ENV[key].to_s.empty? }
  end

  def self.token(key_path: nil)
    return Spaceship::ConnectAPI::Token.from(filepath: key_path) if key_path && File.file?(key_path)

    missing = ENV_KEYS.select { |key| ENV[key].to_s.empty? }
    raise ArgumentError, "Missing App Store Connect credentials: #{missing.join(', ')}" unless missing.empty?

    Spaceship::ConnectAPI::Token.create(
      key_id: ENV.fetch("APP_STORE_CONNECT_API_KEY_KEY_ID"),
      issuer_id: ENV.fetch("APP_STORE_CONNECT_API_KEY_ISSUER_ID"),
      key: ENV.fetch("APP_STORE_CONNECT_API_KEY_KEY"),
      is_key_content_base64: ENV["APP_STORE_CONNECT_API_KEY_IS_BASE64"] == "1",
      in_house: false
    )
  end
end

class AutonomousAscError < StandardError
  attr_reader :method, :path, :status, :body

  def initialize(method:, path:, status:, body:)
    @method = method
    @path = path
    @status = status
    @body = body
    super("#{method} #{path} -> #{status}: #{body}")
  end
end

class AutonomousAscClient
  BASE_URL = "https://api.appstoreconnect.apple.com"

  def initialize(key_path: nil)
    @token = AutonomousAscCredentials.token(key_path: key_path)
  end

  def get(path, params = {}, optional: false)
    request(Net::HTTP::Get, uri_for(path, params), optional: optional)
  end

  def get_optional(path, params = {})
    get(path, params, optional: true)
  end

  def get_all(path, params = {})
    data = []
    included = []
    current = uri_for(path, params)
    loop do
      payload = request(Net::HTTP::Get, current)
      items = payload.fetch("data", [])
      data.concat(items.is_a?(Array) ? items : [items].compact)
      included.concat(payload.fetch("included", []))
      next_link = payload.dig("links", "next")
      break unless next_link
      current = URI(next_link)
    end
    { "data" => data, "included" => included }
  end

  def post(path, body)
    request(Net::HTTP::Post, uri_for(path), body: body)
  end

  def patch(path, body)
    request(Net::HTTP::Patch, uri_for(path), body: body)
  end

  def delete(path)
    request(Net::HTTP::Delete, uri_for(path))
  end

  def upload(upload_operations, bytes)
    upload_operations.each do |operation|
      uri = URI(operation.fetch("url"))
      request_class = Object.const_get(
        "Net::HTTP::#{operation.fetch("method").capitalize}"
      )
      request = request_class.new(uri)
      operation.fetch("requestHeaders").each do |header|
        request[header.fetch("name")] = header.fetch("value")
      end
      request.body = bytes[
        operation.fetch("offset"),
        operation.fetch("length")
      ]
      response = Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: true,
        open_timeout: 30,
        read_timeout: 120
      ) { |http| http.request(request) }
      next if response.is_a?(Net::HTTPSuccess)

      raise AutonomousAscError.new(
        method: operation.fetch("method"),
        path: uri.request_uri,
        status: response.code,
        body: response.body
      )
    end
  end

  private

  def uri_for(path, params = {})
    return path if path.is_a?(URI)
    query = URI.encode_www_form(params)
    URI("#{BASE_URL}#{path}#{query.empty? ? "" : "?#{query}"}")
  end

  def request(request_class, uri, body: nil, optional: false)
    request = request_class.new(uri)
    request["Authorization"] = "Bearer #{@token.text}"
    request["Accept"] = "application/json"
    request["Content-Type"] = "application/json"
    request.body = JSON.generate(body) if body

    response = nil
    3.times do |attempt|
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 30, read_timeout: 120) { |http| http.request(request) }
      break unless response.is_a?(Net::HTTPServerError)
      sleep(5 * (attempt + 1))
    end
    return {} if response.is_a?(Net::HTTPNoContent)
    return JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)
    return nil if optional && response.code == "404"
    raise AutonomousAscError.new(method: request.method, path: uri.request_uri, status: response.code, body: response.body)
  end
end
