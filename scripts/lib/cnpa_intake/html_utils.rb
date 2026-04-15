#!/usr/bin/env ruby
# frozen_string_literal: true

require 'cgi'
require 'json'
require 'time'
require 'uri'

module CnpaIntake
  module HtmlUtils
    module_function

    def decode_html(text)
      CGI.unescapeHTML(text.to_s)
    end

    def normalize_text(text)
      decode_html(text.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '').strip)
    rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
      decode_html(text.to_s.force_encoding('UTF-8').encode('UTF-8', invalid: :replace, undef: :replace, replace: '').strip)
    end

    def strip_tags(text)
      decode_html(
        text
          .to_s
          .gsub(/<script.*?<\/script>/mi, ' ')
          .gsub(/<style.*?<\/style>/mi, ' ')
          .gsub(/<[^>]+>/, ' ')
          .gsub(/\s+/, ' ')
          .strip
      )
    end

    def extract_links(html, base_url)
      quoted_links = html.to_s.scan(/<a\b[^>]*href=(["'])(.*?)\1/mi).map do |_quote, href|
        resolve_url(base_url, href)
      end

      unquoted_links = html.to_s.scan(/<a\b[^>]*href=([^"'\s>]+)[^>]*>/mi).map do |href|
        resolve_url(base_url, href[0])
      end

      bare_urls = html.to_s.scan(%r{https?://[^\s"'<>]+}i).map do |url|
        resolve_url(base_url, url[0])
      end

      (quoted_links + unquoted_links + bare_urls).compact.uniq
    end

    def resolve_url(base_url, href)
      cleaned = href.to_s.strip
      return nil if cleaned.empty?
      return nil if cleaned.start_with?('#', 'mailto:', 'tel:', 'javascript:')

      URI.join(base_url, cleaned).to_s
    rescue URI::InvalidURIError
      nil
    end

    def meta_content(html, *keys)
      keys.each do |key|
        patterns = [
          /<meta\b[^>]*property=["']#{Regexp.escape(key)}["'][^>]*content=["'](.*?)["'][^>]*>/mi,
          /<meta\b[^>]*content=["'](.*?)["'][^>]*property=["']#{Regexp.escape(key)}["'][^>]*>/mi,
          /<meta\b[^>]*name=["']#{Regexp.escape(key)}["'][^>]*content=["'](.*?)["'][^>]*>/mi,
          /<meta\b[^>]*content=["'](.*?)["'][^>]*name=["']#{Regexp.escape(key)}["'][^>]*>/mi
        ]

        patterns.each do |pattern|
          match = html.to_s.match(pattern)
          return normalize_text(match[1]) if match
        end
      end

      nil
    end

    def title(html)
      match = html.to_s.match(/<title[^>]*>(.*?)<\/title>/mi)
      match ? normalize_text(strip_tags(match[1])) : nil
    end

    def extract_json_ld_objects(html)
      html.to_s.scan(/<script\b[^>]*type=["']application\/ld\+json["'][^>]*>(.*?)<\/script>/mi).flat_map do |match|
        parse_json_ld(match[0])
      end
    end

    def extract_mcclatchy_content_items(html)
      payload = html.to_s[/window\.__INITIAL_STATE__=(\{.*?\})<\/script>/m, 1]
      return [] unless payload

      object = JSON.parse(payload)
      Array(object.dig('content', 'contentitems'))
    rescue JSON::ParserError
      []
    end

    def parse_json_ld(payload)
      normalized = payload.to_s.strip
      return [] if normalized.empty?

      object = JSON.parse(normalized)
      flatten_json_ld(object)
    rescue JSON::ParserError
      []
    end

    def flatten_json_ld(object)
      case object
      when Array
        object.flat_map { |item| flatten_json_ld(item) }
      when Hash
        graph_items = object['@graph'].is_a?(Array) ? object['@graph'] : []
        [object] + graph_items.flat_map { |item| flatten_json_ld(item) }
      else
        []
      end
    end

    def article_json_ld(html)
      extract_json_ld_objects(html).find do |obj|
        type = obj['@type']
        [type].flatten.compact.any? do |item|
          %w[Article NewsArticle ReportageNewsArticle BlogPosting AnalysisNewsArticle].include?(item)
        end
      end
    end

    def parse_time(value)
      return nil if value.to_s.strip.empty?

      Time.parse(value.to_s).utc.iso8601
    rescue ArgumentError
      value.to_s
    end

    def article_metadata(html, url:)
      json_ld = article_json_ld(html) || {}
      author =
        case json_ld['author']
        when Array
          json_ld['author']
            .map { |item| item.is_a?(Hash) ? item['name'] : item }
            .compact
            .map { |item| item.to_s.strip }
            .reject(&:empty?)
            .join(', ')
        when Hash
          json_ld['author']['name'].to_s
        else
          json_ld['author'].to_s
        end

      {
        title: normalize_text(json_ld['headline']),
        author: normalize_text(author),
        published_date: parse_time(json_ld['datePublished']),
        summary: normalize_text(json_ld['description']),
        canonical_url: normalize_text(meta_content(html, 'og:url', 'twitter:url') || url),
        body_text: normalize_text(strip_tags(json_ld['articleBody'])),
        excerpt: meta_content(html, 'description', 'og:description', 'twitter:description')
      }.transform_values { |value| normalize_text(value) }
    end
  end
end
