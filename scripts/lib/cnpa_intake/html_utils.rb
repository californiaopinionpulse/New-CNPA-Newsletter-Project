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

    def extract_feed_links(html, base_url)
      html.to_s.scan(/<link\b[^>]*rel=["'][^"']*alternate[^"']*["'][^>]*>/mi).filter_map do |tag|
        type = tag[/type=(["'])(.*?)\1/mi, 2].to_s.downcase
        next unless type.include?('rss') || type.include?('atom') || type.include?('xml')

        href = tag[/href=(["'])(.*?)\1/mi, 2] || tag[/href=([^"'\s>]+)/mi, 1]
        resolve_url(base_url, href)
      end.uniq
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

    def page_json_ld(html, url: nil)
      candidates = extract_json_ld_objects(html).select do |obj|
        type = [obj['@type']].flatten.compact.map(&:to_s)
        type.include?('WebPage')
      end

      return candidates.first if url.to_s.strip.empty?

      normalized_url = normalize_text(url)
      candidates.find do |obj|
        normalize_text(obj['url']) == normalized_url || normalize_text(obj['@id']).sub(/#.*\z/, '') == normalized_url
      end || candidates.first
    end

    def listing_json_ld_article_urls(html, base_url)
      extract_json_ld_objects(html).flat_map do |obj|
        extract_urls_from_json_ld_object(obj, base_url)
      end.compact.uniq
    end

    def parse_time(value)
      return nil if value.to_s.strip.empty?

      Time.parse(value.to_s).utc.iso8601
    rescue ArgumentError
      value.to_s
    end

    def article_metadata(html, url:)
      json_ld = article_json_ld(html) || {}
      page_ld = page_json_ld(html, url: url) || {}
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

      fallback_title = meta_content(html, 'og:title', 'twitter:title')
      fallback_author = meta_content(html, 'author', 'article:author')
      fallback_published = meta_content(html, 'article:published_time', 'og:published_time', 'pubdate')
      fallback_excerpt = first_paragraph(html)

      {
        title: pick_present(
          normalize_text(json_ld['headline']),
          normalize_text(page_ld['name']),
          fallback_title,
          first_h1(html),
          title(html)
        ),
        author: pick_present(
          normalize_text(author),
          fallback_author,
          author_near_heading(html)
        ),
        published_date: pick_present(
          parse_time(json_ld['datePublished']),
          parse_time(page_ld['datePublished']),
          parse_time(fallback_published),
          parse_time(date_near_heading(html))
        ),
        summary: pick_present(
          normalize_text(json_ld['description']),
          normalize_text(page_ld['description'])
        ),
        canonical_url: normalize_text(meta_content(html, 'og:url', 'twitter:url') || url),
        body_text: pick_present(
          normalize_text(strip_tags(json_ld['articleBody'])),
          article_body_text(html)
        ),
        excerpt: pick_present(
          meta_content(html, 'description', 'og:description', 'twitter:description'),
          fallback_excerpt
        )
      }.transform_values { |value| normalize_text(value) }
    end

    def pick_present(*values)
      values
        .map { |value| normalize_text(value) }
        .find { |value| !value.empty? }
        .to_s
    end

    def first_h1(html)
      match = html.to_s.match(/<h1\b[^>]*>(.*?)<\/h1>/mi)
      return '' unless match

      normalize_text(strip_tags(match[1]))
    end

    def first_paragraph(html)
      match = html.to_s.match(/<p\b[^>]*>(.*?)<\/p>/mi)
      return '' unless match

      normalize_text(strip_tags(match[1]))
    end

    def article_body_text(html)
      article = html.to_s[/<article\b[^>]*>(.*?)<\/article>/mi, 1] || html.to_s[/<main\b[^>]*>(.*?)<\/main>/mi, 1]
      return '' unless article

      paragraphs = article.scan(/<p\b[^>]*>(.*?)<\/p>/mi).flatten.map { |paragraph| normalize_text(strip_tags(paragraph)) }
      paragraphs.reject(&:empty?).join("\n\n")
    end

    def author_near_heading(html)
      heading_match = html.to_s.match(/<h1\b[^>]*>.*?<\/h1>(.{0,1500})/mi)
      return '' unless heading_match

      fragment = heading_match[1]
      labeled = fragment.match(/(?:By|by)\s+([^<\n\r]{2,120})/m)
      return normalize_text(strip_tags(labeled[1])) if labeled

      class_match = fragment.match(/<div\b[^>]*class=["'][^"']*(?:author|byline|text-text)[^"']*["'][^>]*>(.*?)<\/div>/mi)
      return normalize_text(strip_tags(class_match[1])) if class_match

      ''
    end

    def date_near_heading(html)
      heading_match = html.to_s.match(/<h1\b[^>]*>.*?<\/h1>(.{0,2000})/mi)
      return '' unless heading_match

      fragment = strip_tags(heading_match[1])
      month_name = '(?:January|February|March|April|May|June|July|August|September|October|November|December)'
      date_match = fragment.match(/#{month_name}\s+\d{1,2},\s+\d{4}(?:\s+\d{1,2}:\d{2}\s*(?:a\.m\.|p\.m\.|AM|PM))?/i)
      date_match ? date_match[0] : ''
    end

    def extract_urls_from_json_ld_object(object, base_url)
      return [] unless object.is_a?(Hash)

      urls = []
      type_names = [object['@type']].flatten.compact.map(&:to_s)

      if type_names.any? { |type| %w[Article NewsArticle ReportageNewsArticle BlogPosting AnalysisNewsArticle].include?(type) }
        urls << extract_json_ld_url(object, base_url)
      end

      if type_names.include?('ItemList')
        urls.concat(Array(object['itemListElement']).flat_map { |item| extract_urls_from_item_list_element(item, base_url) })
      end

      if object['mainEntity'].is_a?(Hash)
        urls.concat(extract_urls_from_json_ld_object(object['mainEntity'], base_url))
      elsif object['mainEntityOfPage'].is_a?(Hash)
        urls.concat(extract_urls_from_json_ld_object(object['mainEntityOfPage'], base_url))
      end

      urls.compact.uniq
    end

    def extract_urls_from_item_list_element(item, base_url)
      case item
      when Hash
        candidate_urls = []
        candidate_urls << extract_json_ld_url(item, base_url)
        candidate_urls << extract_json_ld_url(item['item'], base_url) if item['item'].is_a?(Hash)
        candidate_urls.compact
      else
        []
      end
    end

    def extract_json_ld_url(object, base_url)
      return nil unless object.is_a?(Hash)

      raw_url = object['url']
      raw_url = object.dig('mainEntityOfPage', '@id') if raw_url.to_s.strip.empty? && object['mainEntityOfPage'].is_a?(Hash)
      raw_url = object.dig('item', '@id') if raw_url.to_s.strip.empty? && object['item'].is_a?(Hash)
      resolve_url(base_url, raw_url)
    end
  end
end
