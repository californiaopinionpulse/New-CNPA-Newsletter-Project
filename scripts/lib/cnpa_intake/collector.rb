#!/usr/bin/env ruby
# frozen_string_literal: true

require 'csv'
require 'fileutils'
require 'json'
require 'rss'
require 'set'
require 'time'
require 'uri'

require_relative 'fetcher'
require_relative 'html_utils'

module CnpaIntake
  class Collector
    OUTPUT_HEADERS = %w[
      source_key
      publication
      source_type
      source_url
      article_url
      title
      author
      published_date
      raw_excerpt
      body_text
      collected_at
      collector_mode
    ].freeze

    def initialize(sources:, output_dir:)
      @sources = sources
      @output_dir = output_dir
      @fetcher = Fetcher.new
    end

    def run
      articles = @sources.flat_map { |source| collect_source(source) }
      write_outputs(articles)
      articles
    end

    private

    def collect_source(source)
      case source[:mode]
      when :rss
        collect_rss(source)
      when :page
        collect_page(source)
      else
        raise "Unsupported source mode: #{source[:mode]}"
      end
    rescue StandardError => e
      [{
        source_key: source[:key],
        publication: source[:publication],
        source_type: source[:source_type],
        source_url: source[:feed_url] || source[:list_url],
        article_url: '',
        title: '',
        author: '',
        published_date: '',
        raw_excerpt: "Collector error: #{e.message}",
        body_text: '',
        collected_at: Time.now.utc.iso8601,
        collector_mode: source[:mode].to_s
      }]
    end

    def collect_rss(source)
      payload = @fetcher.fetch(
        source[:feed_url],
        headers: source.fetch(:headers, {}),
        open_timeout: source.fetch(:open_timeout, 20),
        read_timeout: source.fetch(:read_timeout, 20),
        retries: source.fetch(:retries, 0)
      )
      feed = RSS::Parser.parse(payload[:body], false)

      feed.items.map do |item|
        {
          source_key: source[:key],
          publication: source[:publication],
          source_type: source[:source_type],
          source_url: source[:feed_url],
          article_url: item.link.to_s.strip,
          title: item.title.to_s.strip,
          author: extract_rss_author(item),
          published_date: parse_time(item.pubDate || item.dc_date),
          raw_excerpt: item.description.to_s.strip,
          body_text: '',
          collected_at: Time.now.utc.iso8601,
          collector_mode: 'rss'
        }
      end
    end

    def collect_page(source)
      listing = fetch_listing_page(source)
      embedded_fallbacks = embedded_item_index(listing[:body], source)
      article_urls = candidate_article_urls(listing[:body], source).first(source[:max_articles] || 5)
      articles = []

      article_urls.map do |article_url|
        article = @fetcher.fetch(
          article_url,
          headers: source.fetch(:headers, {}),
          open_timeout: source.fetch(:open_timeout, 20),
          read_timeout: source.fetch(:read_timeout, 20),
          retries: source.fetch(:retries, 0)
        )
        metadata = HtmlUtils.article_metadata(article[:body], url: article[:final_url] || article_url)

        articles << {
          source_key: source[:key],
          publication: source[:publication],
          source_type: source[:source_type],
          source_url: listing[:final_url] || source[:list_url],
          article_url: metadata[:canonical_url].to_s.empty? ? article_url : metadata[:canonical_url],
          title: pick_first(metadata[:title], HtmlUtils.title(article[:body]), embedded_fallbacks.dig(normalize_url(article_url), :title)),
          author: pick_first(metadata[:author], embedded_fallbacks.dig(normalize_url(article_url), :author)),
          published_date: pick_first(metadata[:published_date], embedded_fallbacks.dig(normalize_url(article_url), :published_date)),
          raw_excerpt: pick_first(metadata[:excerpt], metadata[:summary], embedded_fallbacks.dig(normalize_url(article_url), :excerpt)),
          body_text: metadata[:body_text],
          collected_at: Time.now.utc.iso8601,
          collector_mode: 'page'
        }
      rescue StandardError
        next
      end

      return articles unless articles.empty?

      raise "No article records extracted from #{listing[:final_url] || source[:list_url]}"
    end

    def fetch_listing_page(source)
      urls = Array(source[:list_urls] || source[:list_url])
      errors = []

      urls.each do |url|
        return @fetcher.fetch(
          url,
          headers: source.fetch(:headers, {}),
          open_timeout: source.fetch(:open_timeout, 20),
          read_timeout: source.fetch(:read_timeout, 20),
          retries: source.fetch(:retries, 0)
        )
      rescue StandardError => e
        errors << "#{url} => #{e.message}"
      end

      raise errors.join(' | ')
    end

    def candidate_article_urls(html, source)
      embedded_urls = embedded_article_urls(html, source)
      seen = Set.new

      (embedded_urls + HtmlUtils.extract_links(html, source[:list_url])).filter_map do |url|
        next if same_listing_url?(url, source[:list_url])
        next if seen.include?(url)
        next unless allowed_host?(url, source[:allowed_hosts])
        next unless article_url?(url, source[:article_url_patterns])
        next if excluded_url?(url, source[:exclude_url_patterns])

        seen << url
        url
      end
    end

    def embedded_article_urls(html, source)
      case source[:discovery]
      when :mcclatchy_state
        HtmlUtils.extract_mcclatchy_content_items(html).filter_map { |item| item['url'].to_s.strip unless item['url'].to_s.strip.empty? }
      else
        []
      end
    end

    def embedded_item_index(html, source)
      case source[:discovery]
      when :mcclatchy_state
        HtmlUtils.extract_mcclatchy_content_items(html).each_with_object({}) do |item, index|
          url = item['url'].to_s.strip
          next if url.empty?

          index[normalize_url(url)] = {
            title: item['meta_title'].to_s.strip.empty? ? item['title'].to_s : item['meta_title'].to_s,
            author: extract_mcclatchy_author(item),
            published_date: parse_time(item['published_date']),
            excerpt: item['story_teaser'].to_s.strip.empty? ? item['summary'].to_s : item['story_teaser'].to_s
          }
        end
      else
        {}
      end
    end

    def allowed_host?(url, hosts)
      uri = URI.parse(url)
      hosts.include?(uri.host)
    rescue URI::InvalidURIError
      false
    end

    def article_url?(url, patterns)
      patterns.any? { |pattern| url.match?(pattern) }
    end

    def excluded_url?(url, patterns)
      return false if patterns.nil? || patterns.empty?

      patterns.any? { |pattern| url.match?(pattern) }
    end

    def same_listing_url?(url, list_url)
      normalize_url(url) == normalize_url(list_url)
    end

    def normalize_url(url)
      uri = URI.parse(url)
      normalized_path = uri.path.to_s.sub(%r{/\z}, '')
      [uri.scheme, uri.host, normalized_path, uri.query].join('|')
    rescue URI::InvalidURIError
      url.to_s
    end

    def extract_rss_author(item)
      return item.author.to_s.strip unless item.author.to_s.strip.empty?
      return item.dc_creator.to_s.strip unless !item.respond_to?(:dc_creator) || item.dc_creator.to_s.strip.empty?

      ''
    end

    def parse_time(value)
      return '' if value.nil?
      return Time.at(value.to_i).utc.iso8601 if value.is_a?(Numeric) || value.to_s.match?(/\A\d{10}\z/)

      Time.parse(value.to_s).utc.iso8601
    rescue ArgumentError
      value.to_s
    end

    def pick_first(*values)
      values
        .map { |value| HtmlUtils.normalize_text(value) }
        .find { |value| !value.empty? }
        .to_s
    end

    def extract_mcclatchy_author(item)
      authors = Array(item['authors']).filter_map do |author|
        name = author['name'].to_s.strip
        name unless name.empty?
      end
      return authors.join(', ') unless authors.empty?

      HtmlUtils.strip_tags(item['byline']).sub(/\ABy\s+/i, '').strip
    end

    def write_outputs(articles)
      FileUtils.mkdir_p(@output_dir)

      timestamp = Time.now.utc.strftime('%Y%m%dT%H%M%SZ')
      latest_json = File.join(@output_dir, 'latest_content_intake.json')
      latest_csv = File.join(@output_dir, 'latest_content_intake.csv')
      stamped_json = File.join(@output_dir, "content_intake_#{timestamp}.json")

      json_payload = {
        generated_at: Time.now.utc.iso8601,
        article_count: articles.length,
        sources: @sources.map { |source| source[:key] },
        articles: articles
      }

      File.write(latest_json, JSON.pretty_generate(json_payload) + "\n")
      File.write(stamped_json, JSON.pretty_generate(json_payload) + "\n")

      CSV.open(latest_csv, 'w', write_headers: true, headers: OUTPUT_HEADERS, force_quotes: true, row_sep: "\n") do |csv|
        articles.each do |article|
          csv << OUTPUT_HEADERS.map { |header| article[header.to_sym].to_s }
        end
      end
    end
  end
end
