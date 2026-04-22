#!/usr/bin/env ruby
# frozen_string_literal: true

require 'net/http'
require 'stringio'
require 'uri'
require 'zlib'

module CnpaIntake
  class Fetcher
    DEFAULT_HEADERS = {
      'User-Agent' => 'CNPA Prototype Intake/0.1 (+local research workflow)',
      'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Encoding' => 'gzip,deflate',
      'Accept-Language' => 'en-US,en;q=0.9',
      'Connection' => 'close'
    }.freeze

    def fetch(url, limit: 5, headers: {}, open_timeout: 20, read_timeout: 20, retries: 0)
      raise ArgumentError, 'HTTP redirect too deep' if limit <= 0

      uri = URI.parse(url)
      attempts = 0

      begin
        response = perform_request(uri, headers: headers, open_timeout: open_timeout, read_timeout: read_timeout)
      rescue Net::OpenTimeout, Net::ReadTimeout, EOFError, IOError, Errno::ECONNRESET, Errno::ETIMEDOUT => e
        attempts += 1
        raise e if attempts > retries

        sleep(1.0 * attempts)
        retry
      end

      case response
      when Net::HTTPSuccess
        {
          url: url,
          final_url: url,
          status: response.code.to_i,
          headers: response.to_hash,
          body: decode_body(response)
        }
      when Net::HTTPRedirection
        location = response['location']
        raise "Redirect without location for #{url}" if location.to_s.strip.empty?

        redirected = URI.join(url, location).to_s
        fetch(
          redirected,
          limit: limit - 1,
          headers: headers,
          open_timeout: open_timeout,
          read_timeout: read_timeout,
          retries: retries
        )
      else
        raise "Request failed for #{url}: #{response.code} #{response.message}"
      end
    end

    private

    def perform_request(uri, headers:, open_timeout:, read_timeout:)
      http = Net::HTTP.new(uri.host, uri.port, nil, nil)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = open_timeout
      http.read_timeout = read_timeout

      request = Net::HTTP::Get.new(uri)
      DEFAULT_HEADERS.merge(headers).each { |key, value| request[key] = value }
      http.request(request)
    end

    def decode_body(response)
      body = response.body.to_s
      encoding = response['content-encoding'].to_s.downcase

      decoded = case encoding
      when 'gzip'
        Zlib::GzipReader.new(StringIO.new(body)).read
      when 'deflate'
        Zlib::Inflate.inflate(body)
      else
        body
      end

      normalize_text(decoded, response['content-type'])
    rescue Zlib::Error
      normalize_text(body, response['content-type'])
    end

    def normalize_text(body, content_type)
      charset = content_type.to_s[/charset=([^\s;]+)/i, 1]
      text = body.to_s
      return text.force_encoding('UTF-8').encode('UTF-8', invalid: :replace, undef: :replace, replace: '') if charset.to_s.strip.empty?

      text.force_encoding(charset).encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
    rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError, ArgumentError
      text.to_s.force_encoding('UTF-8').encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
    end
  end
end
