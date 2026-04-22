#!/usr/bin/env ruby
# frozen_string_literal: true

require 'csv'
require 'json'
require 'set'
require 'time'
require 'cgi'

def load_json(path)
  JSON.parse(File.read(path))
end

def load_publication_metadata(path)
  CSV.read(path, headers: true).each_with_object({}) do |row, index|
    publication = row['Publication Name'].to_s.strip
    next if publication.empty?

    index[publication] = {
      opinion_source_url: row['Opinion Source URL'].to_s.strip,
      source_type: row['Source Type'].to_s.strip,
      notes: row['Notes'].to_s.strip
    }
  end
end

def clean_text(value)
  value.to_s
       .encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
       .gsub(/\s+/, ' ')
       .strip
end

def strip_html(value)
  CGI.unescapeHTML(
    value.to_s
         .gsub(/<script.*?<\/script>/mi, ' ')
         .gsub(/<style.*?<\/style>/mi, ' ')
         .gsub(/<[^>]+>/, ' ')
         .gsub(/\s+/, ' ')
         .strip
  )
end

def normalize_text(value)
  clean_text(strip_html(value))
end

def region_for(publication)
  {
    'Los Angeles Times' => 'Southern California',
    'The Sacramento Bee' => 'Sacramento / Capital',
    'The Fresno Bee' => 'Central Valley',
    'Voice of OC' => 'Southern California',
    'A News Cafe' => 'Northern California',
    'A News Cafe?' => 'Northern California',
    'A News Café' => 'Northern California',
    'Black Voice News' => 'Inland Empire'
  }.fetch(publication, 'Statewide')
end

TOPIC_RULES = [
  ['Housing', %w[housing homelessness homeless rent renter landlord zoning development shelter real-estate realestate]],
  ['Education', %w[school schools student students college colleges university universities classroom classrooms teacher teachers education]],
  ['Environment', %w[climate wildfire water drought pollution solar clean-energy clean transportation diesel air-quality environment landfill]],
  ['Health', %w[health healthcare hospital hospitals medical medicine addiction mental-health public-health medicaid medi-cal vaccine vaccines]],
  ['Politics', %w[trump congress election elections governor legislator legislators legislature lawmakers politics political impeachment democrat republican]],
  ['Criminal Justice', %w[prison prisons police policing jail crime criminal sentencing incarceration juvenile court courts]],
  ['Economy', %w[economy economic jobs labor worker workers wages inflation prices cost affordable affordability business businesses market trade]],
  ['Transportation', %w[transit transportation train trains rail railyards traffic roads highway highways vehicle vehicles]],
  ['Technology', %w[technology tech social-media platform platforms internet ai artificial-intelligence data privacy]],
  ['International', %w[iran europe war wars foreign foreign-policy international global hungary orban]]
].freeze

def topic_tag_for(title, excerpt)
  normalized = "#{title} #{excerpt}".downcase.gsub(/[^a-z0-9]+/, ' ').strip
  tokens = normalized.split.to_set

  TOPIC_RULES.each do |label, keywords|
    return label if keywords.any? do |keyword|
      normalized_keyword = keyword.downcase.gsub(/[^a-z0-9]+/, ' ').strip
      next false if normalized_keyword.empty?

      if normalized_keyword.include?(' ')
        normalized.include?(normalized_keyword)
      else
        tokens.include?(normalized_keyword)
      end
    end
  end

  'Civic Affairs'
end

def summary_for(title, excerpt)
  clean_excerpt = normalize_text(excerpt)
  clean_title = normalize_text(title)

  return clean_excerpt if clean_excerpt.length.between?(40, 220)
  return "#{clean_title}." if clean_excerpt.empty?

  "#{clean_title}. #{clean_excerpt}".gsub(/\s+/, ' ').strip.slice(0, 240).to_s.sub(/\s+\z/, '')
end

def iso_issue_week(published_date, fallback_time)
  date =
    begin
      published_date.to_s.strip.empty? ? fallback_time.utc.to_date : Time.parse(published_date).utc.to_date
    rescue ArgumentError
      fallback_time.utc.to_date
    end

  year = date.cwyear
  week = date.cweek
  format('%<year>d-W%<week>02d', year: year, week: week)
end

def parsed_published_time(value)
  return nil if value.to_s.strip.empty?

  Time.parse(value.to_s).utc
rescue ArgumentError
  nil
end

input_path = File.expand_path('../data/generated/content_intake/latest_content_intake.json', __dir__)
publication_path = File.expand_path('../airtable_publications_prototype_import.csv', __dir__)
output_path = File.expand_path('../data/generated/content_intake/airtable_articles_import.csv', __dir__)
template_path = File.expand_path('../airtable_articles_template.csv', __dir__)

payload = load_json(input_path)
publication_metadata = load_publication_metadata(publication_path)
headers = CSV.read(template_path, headers: true).headers
generated_at = Time.parse(payload['generated_at'].to_s)
lookback_days = payload['lookback_days'].to_i
lookback_days = 28 if lookback_days <= 0
cutoff_time = generated_at - (lookback_days * 86_400)
seen_urls = Set.new

rows = payload.fetch('articles', []).filter_map do |article|
  article_url = clean_text(article['article_url'])
  next if article_url.empty?
  next if seen_urls.include?(article_url)

  seen_urls << article_url
  published_at = parsed_published_time(article['published_date'])
  date_status = clean_text(article['date_status'])

  if published_at
    next if published_at < cutoff_time
    next if published_at > (generated_at + 86_400)
  end

  publication = clean_text(article['publication'])
  metadata = publication_metadata.fetch(publication, {})
  raw_excerpt = normalize_text(article['raw_excerpt']).gsub(/\ACollector error:\s*/i, '')
  title = normalize_text(article['title'])
  topic_tag = topic_tag_for(title, raw_excerpt)
  region = region_for(publication)
  ai_summary = summary_for(title, raw_excerpt)

  status =
    if raw_excerpt.match?(/forbidden|timeout|collector error/i)
      'Needs source review'
    elsif published_at.nil? || date_status == 'unknown'
      'Unknown publish date'
    else
      'Ready for review'
    end

  notes = [
    metadata[:notes],
    "source_key=#{clean_text(article['source_key'])}",
    "collector_mode=#{clean_text(article['collector_mode'])}",
    "collected_at=#{clean_text(article['collected_at'])}",
    ("publish_date=missing_or_unparseable" if published_at.nil? || date_status == 'unknown')
  ].compact.map { |value| clean_text(value) }.reject(&:empty?).join(' | ')

  {
    'Article Title' => title,
    'Publication' => publication,
    'Article URL' => article_url,
    'Author' => clean_text(article['author']),
    'Published Date' => published_at ? published_at.strftime('%Y-%m-%d') : '',
    'Source URL' => clean_text(metadata[:opinion_source_url]).empty? ? clean_text(article['source_url']) : clean_text(metadata[:opinion_source_url]),
    'Source Type' => clean_text(metadata[:source_type]).empty? ? clean_text(article['source_type']) : clean_text(metadata[:source_type]),
    'Region' => region,
    'Raw Excerpt' => raw_excerpt,
    'AI Summary' => ai_summary,
    'Topic Tag' => topic_tag,
    'Candidate' => status == 'Ready for review' ? 'Yes' : 'No',
    'Issue Week' => published_at ? iso_issue_week(article['published_date'], generated_at) : '',
    'Status' => status,
    'Notes' => notes
  }
end

CSV.open(output_path, 'w', write_headers: true, headers: headers, force_quotes: true, row_sep: "\n") do |csv|
  rows.each do |row|
    csv << headers.map { |header| row.fetch(header, '') }
  end
end

puts "Created #{output_path}"
puts "Rows: #{rows.length}"
