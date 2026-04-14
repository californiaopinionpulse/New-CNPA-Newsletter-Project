#!/usr/bin/env ruby
# frozen_string_literal: true
# encoding: UTF-8

require 'csv'

input_path = File.expand_path('CNPA prototype ingestion list.csv', __dir__)
output_path = File.expand_path('airtable_publications_prototype_import.csv', __dir__)

rows = CSV.read(input_path, headers: true, encoding: 'bom|utf-8')

headers = [
  'Publication Name',
  'Homepage URL',
  'Opinion Source URL',
  'Source Type',
  'Ingestion Tier',
  'Monitoring Method',
  'Active',
  'Notes'
]

CSV.open(output_path, 'w', write_headers: true, headers: headers, force_quotes: true) do |csv|
  rows.each do |row|
    source_type =
      if row['RSS Opinion feed Y/N'] == 'Y'
        'RSS opinion feed'
      elsif row['Non-RSS Opinion Page Y/N'] == 'Y'
        'Opinion page'
      else
        'Manual review'
      end

    opinion_source_url = row['Opinion Section URL'].to_s.empty? ? row['Homepage URL'] : row['Opinion Section URL']

    csv << [
      row['Prototype Publication Name'],
      row['Homepage URL'],
      opinion_source_url,
      source_type,
      row['Ingestion Tier'],
      row['Monitoring Method'],
      'Yes',
      row['Source Notes']
    ]
  end
end

puts "Created #{output_path}"
