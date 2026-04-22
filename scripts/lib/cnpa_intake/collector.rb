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
    DEFAULT_LOOKBACK_DAYS = 28
    FUTURE_DATE_GRACE_SECONDS = 86_400
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

    def initialize(sources:, output_dir:, lookback_days: DEFAULT_LOOKBACK_DAYS, now: Time.now.utc)
      @sources = sources
      @output_dir = output_dir
      @fetcher = Fetcher.new
      @lookback_days = lookback_days
      @now = now.utc
      @cutoff_time = @now - (@lookback_days * 86_400)
    end

    def run
      articles = @sources.flat_map { |source| collect_source(source) }
      write_outputs(articles)
      articles
    end

    private

    def collect_source(source)
      articles =
        case source[:mode]
        when :rss
          collect_rss(source)
        when :page
          collect_page(source)
        else
          raise "Unsupported source mode: #{source[:mode]}"
        end

      filter_recent_articles(articles)
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

      build_rss_articles(source, feed.items, payload[:final_url] || source[:feed_url])
    end

    def build_rss_articles(source, items, source_url)
      Array(items).map do |item|
        title =
          if item.respond_to?(:title)
            item.title.to_s.strip
          else
            item.respond_to?(:name) ? item.name.to_s.strip : ''
          end

        link =
          if item.respond_to?(:link)
            value = item.link
            value = value.href if value.respond_to?(:href)
            value.to_s.strip
          else
            ''
          end

        description =
          if item.respond_to?(:description)
            item.description.to_s.strip
          elsif item.respond_to?(:summary)
            item.summary.to_s.strip
          else
            ''
          end

        {
          source_key: source[:key],
          publication: source[:publication],
          source_type: source[:source_type],
          source_url: source_url,
          article_url: link,
          title: title,
          author: extract_rss_author(item),
          published_date: parse_time(item.pubDate || item.dc_date),
          raw_excerpt: description,
          body_text: '',
          collected_at: Time.now.utc.iso8601,
          collector_mode: 'rss'
        }
      end
    end

    def collect_page(source)
      listing = fetch_listing_page(source)
      embedded_fallbacks = embedded_item_index(listing[:body], source)
      article_urls = candidate_article_urls(listing[:body], source).first(candidate_limit_for(source))
      articles = collect_article_pages(source, listing, article_urls, embedded_fallbacks)
      articles = filter_recent_articles(articles).first(source[:max_articles] || 5)

      min_articles = source[:min_articles] || [2, source[:max_articles].to_i].max
      if articles.length < min_articles
        feed_articles = filter_recent_articles(collect_page_feed_fallback(source, listing))
        return feed_articles.first(source[:max_articles]) if feed_articles.length >= min_articles
      end

      return articles unless articles.empty?

      raise "No article records extracted from #{listing[:final_url] || source[:list_url]}"
    end

    def collect_article_pages(source, listing, article_urls, embedded_fallbacks)
      articles = []

      article_urls.each do |article_url|
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
          published_date: pick_first(
            metadata[:published_date],
            embedded_fallbacks.dig(normalize_url(article_url), :published_date),
            infer_published_date_from_url(metadata[:canonical_url]),
            infer_published_date_from_url(article_url)
          ),
          raw_excerpt: pick_first(metadata[:excerpt], metadata[:summary], embedded_fallbacks.dig(normalize_url(article_url), :excerpt)),
          body_text: metadata[:body_text],
          collected_at: Time.now.utc.iso8601,
          collector_mode: 'page'
        }
      rescue StandardError
        next
      end

      articles
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
      json_ld_urls = HtmlUtils.listing_json_ld_article_urls(html, source[:list_url])
      seen = Set.new

      (embedded_urls + json_ld_urls + HtmlUtils.extract_links(html, source[:list_url])).filter_map do |url|
        next if same_listing_url?(url, source[:list_url])
        next if seen.include?(url)
        next unless allowed_host?(url, source[:allowed_hosts])
        next unless article_url?(url, source[:article_url_patterns])
        next if excluded_url?(url, source[:exclude_url_patterns])
        next unless allowed_context?(html, url, source)

        seen << url
        url
      end
    end

    def allowed_context?(html, url, source)
      required = Array(source[:required_context_patterns]).compact
      ignored = Array(source[:ignore_context_patterns]).compact
      return true if required.empty? && ignored.empty?

      snippets = url_context_snippets(html, url)
      return true if snippets.empty?

      valid_snippets = snippets.reject { |snippet| ignored.any? { |pattern| snippet.match?(pattern) } }
      return false if valid_snippets.empty?
      return true if required.empty?

      valid_snippets.any? { |snippet| required.any? { |pattern| snippet.match?(pattern) } }
    end

    def url_context_snippets(html, url)
      haystack = html.to_s
      snippets = []
      offset = 0

      while (index = haystack.index(url, offset))
        start = [index - 350, 0].max
        snippets << haystack[start, 900]
        offset = index + url.length
      end

      snippets
    end

    def candidate_limit_for(source)
      max_articles = source[:max_articles] || 5
      explicit_limit = source[:candidate_limit]
      return explicit_limit if explicit_limit

      [max_articles * 4, max_articles].max
    end

    def collect_page_feed_fallback(source, listing)
      return [] if source[:disable_feed_fallback]

      feed_urls = Array(source[:feed_urls]) + HtmlUtils.extract_feed_links(listing[:body], listing[:final_url] || source[:list_url])
      feed_urls.uniq.each do |feed_url|
        payload = @fetcher.fetch(
          feed_url,
          headers: source.fetch(:headers, {}),
          open_timeout: source.fetch(:open_timeout, 20),
          read_timeout: source.fetch(:read_timeout, 20),
          retries: source.fetch(:retries, 0)
        )
        feed = RSS::Parser.parse(payload[:body], false)
        articles = build_rss_articles(source, feed.items, payload[:final_url] || feed_url)
        return articles unless articles.empty?
      rescue StandardError
        next
      end

      []
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
      return item.itunes_author.to_s.strip if item.respond_to?(:itunes_author) && !item.itunes_author.to_s.strip.empty?
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

    def filter_recent_articles(articles)
      Array(articles).filter_map do |article|
        next article if collector_error_article?(article)

        published_at = article_published_time(article)
        if published_at.nil?
          article[:date_status] = 'unknown'
          next article
        end
        next if published_at < @cutoff_time
        next if published_at > (@now + FUTURE_DATE_GRACE_SECONDS)

        article.merge(
          published_date: published_at.utc.iso8601,
          date_status: 'verified'
        )
      end
    end

    def collector_error_article?(article)
      article[:raw_excerpt].to_s.match?(/\ACollector error:/i)
    end

    def article_published_time(article)
      value = article[:published_date].to_s.strip
      return nil if value.empty?

      Time.parse(value).utc
    rescue ArgumentError
      nil
    end

    def infer_published_date_from_url(url)
      value = url.to_s
      match = value.match(%r{/(20\d{2})/(0[1-9]|1[0-2])/([0-3]\d)/})
      return '' unless match

      Time.utc(match[1].to_i, match[2].to_i, match[3].to_i).iso8601
    rescue ArgumentError
      ''
    end

    def write_outputs(articles)
      FileUtils.mkdir_p(@output_dir)

      timestamp = Time.now.utc.strftime('%Y%m%dT%H%M%SZ')
      latest_json = File.join(@output_dir, 'latest_content_intake.json')
      latest_csv = File.join(@output_dir, 'latest_content_intake.csv')
      stamped_json = File.join(@output_dir, "content_intake_#{timestamp}.json")

      json_payload = {
        generated_at: Time.now.utc.iso8601,
        lookback_days: @lookback_days,
        cutoff_date: @cutoff_time.utc.iso8601,
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
