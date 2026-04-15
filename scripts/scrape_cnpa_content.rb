#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'

require_relative 'lib/cnpa_intake/collector'
require_relative 'lib/cnpa_intake/source_registry'

options = {
  source_keys: []
}

OptionParser.new do |parser|
  parser.banner = 'Usage: ruby scripts/scrape_cnpa_content.rb [--source SOURCE_KEY]'

  parser.on('--source SOURCE_KEY', 'Limit collection to one source key; can be repeated') do |value|
    options[:source_keys] << value.to_s.strip.downcase
  end

  parser.on('--list-sources', 'Print available source keys and exit') do
    CnpaIntake::SourceRegistry.all.each do |source|
      puts "#{source[:key]} - #{source[:publication]} (#{source[:mode]})"
    end
    exit 0
  end
end.parse!

sources = CnpaIntake::SourceRegistry.fetch(options[:source_keys])
abort('No matching sources selected.') if sources.empty?

output_dir = File.expand_path('../data/generated/content_intake', __dir__)
collector = CnpaIntake::Collector.new(sources: sources, output_dir: output_dir)
articles = collector.run

puts "Collected #{articles.length} items from #{sources.length} sources."
puts "Output: #{File.join(output_dir, 'latest_content_intake.json')}"
