#!/usr/bin/env ruby
# frozen_string_literal: true
# encoding: UTF-8

require 'csv'

input_path = File.expand_path('CNPA prototype feed tracker.csv', __dir__)
output_path = File.expand_path('CNPA prototype ingestion list.csv', __dir__)

rows = CSV.read(input_path, headers: true, encoding: 'bom|utf-8')

headers = [
  'Prototype Publication Name',
  'Bucket',
  'Homepage URL',
  'Opinion Section URL',
  'RSS Opinion feed Y/N',
  'RSS feed URL',
  'Non-RSS Opinion Page Y/N',
  'Ingestion Tier',
  'Recommended System',
  'Recommended Setup',
  'Monitoring Method',
  'Implementation Notes',
  'Source Notes'
]

def ingestion_plan(row)
  if row['RSS Opinion feed Y/N'] == 'Y' && !row['RSS feed URL'].to_s.empty?
    [
      'Tier 1',
      'Feedly',
      'Add RSS feed directly to Feedly prototype folder',
      row['Monitoring Method'].to_s.empty? ? 'Use opinion RSS feed' : row['Monitoring Method'],
      'Best prototype candidate. Connect Feedly to Zapier or Make for automatic article capture.'
    ]
  elsif row['Non-RSS Opinion Page Y/N'] == 'Y'
    [
      'Tier 2',
      'Page monitor',
      'Monitor opinion/category page for newly published article links',
      row['Monitoring Method'],
      'Use a page-change monitor, scraper, or custom checker to extract title, author, date, summary, and URL from newly listed opinion items.'
    ]
  elsif row['Monitoring Method'].to_s.downcase.include?('deprioritize')
    [
      'Tier 4',
      'Skip for prototype',
      'Do not include in initial automated prototype',
      row['Monitoring Method'],
      'Keep out of the first automated newsletter build unless editorial priorities change.'
    ]
  else
    [
      'Tier 3',
      'Manual review',
      'Editorial/manual verification before automation',
      row['Monitoring Method'],
      'Needs a human check to confirm whether a stable opinion landing page or feed exists before adding to automation.'
    ]
  end
end

CSV.open(output_path, 'w', write_headers: true, headers: headers, force_quotes: true) do |csv|
  rows.each do |row|
    tier, system, setup, method, notes = ingestion_plan(row)
    csv << [
      row['Prototype Publication Name'],
      row['Bucket'],
      row['Homepage URL'],
      row['Opinion Section URL'],
      row['RSS Opinion feed Y/N'],
      row['RSS feed URL'],
      row['Non-RSS Opinion Page Y/N'],
      tier,
      system,
      setup,
      method,
      notes,
      row['Source Notes']
    ]
  end
end

summary = rows.group_by do |row|
  ingestion_plan(row).first
end.transform_values(&:count)

puts "Created #{output_path}"
puts summary.sort_by { |k, _| k }.map { |k, v| "#{k}=#{v}" }.join(', ')
