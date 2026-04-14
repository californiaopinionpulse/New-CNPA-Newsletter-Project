#!/usr/bin/env ruby
# frozen_string_literal: true
# encoding: UTF-8

require 'csv'

source_path = File.expand_path('CNPA URLS and opinion feeds.csv', __dir__)
output_path = File.expand_path('CNPA prototype subset.csv', __dir__)

rows = CSV.read(source_path, headers: true, encoding: 'bom|utf-8')
by_name = rows.map { |r| [r['Member Publication Name'], r] }.to_h

targets = [
  ['Los Angeles Times', 'Major metro influence', 'Likely RSS candidate', 'Large metro with visible section architecture; strong early target for opinion-feed discovery.'],
  ['The Sacramento Bee', 'Major metro influence', 'Likely RSS candidate', 'High-value Capitol publication; likely structured opinion/category output.'],
  ['The San Diego Union-Tribune', 'Major metro influence', 'Likely RSS candidate', 'Major daily and good proof point for Southern California coverage.'],
  ['San Francisco Chronicle', 'Major metro influence', 'Likely RSS candidate', 'Major statewide-recognition outlet with frequent opinion content.'],
  ['The Orange County Register', 'Major metro influence', 'Likely RSS candidate', 'Large regional paper with recurring commentary/editorial content.'],
  ['The Fresno Bee', 'Major metro influence', 'Likely RSS candidate', 'Strong Central Valley anchor and likely good structured feed source.'],
  ['The Bakersfield Californian', 'Major metro influence', 'Likely RSS candidate', 'Important Inland/Central Valley signal for statewide balance.'],
  ['The Modesto Bee', 'Major metro influence', 'Likely RSS candidate', 'Another strong Central Valley source with likely opinion section structure.'],
  ['Ventura County Star', 'Regional daily', 'Likely RSS candidate', 'Gannett property; likely standardized site/feed patterns.'],
  ['The Desert Sun', 'Regional daily', 'Likely RSS candidate', 'Gannett property and useful Inland Empire/Coachella voice.'],
  ['The Press Democrat', 'Regional daily', 'Likely RSS candidate', 'Strong North Bay regional daily with likely recurring columns/opinion.'],
  ['Monterey County Weekly', 'Regional daily', 'Likely non-RSS opinion page', 'Stronger Central Coast choice for the prototype and likely rich in commentary/community voice content.'],
  ['Redding Record Searchlight', 'Regional daily', 'Likely RSS candidate', 'Stronger far-Northern California anchor and likely standardized Gannett feed patterns.'],
  ['The Union Democrat', 'Regional daily', 'Likely non-RSS opinion page', 'Regional daily likely to have editorials/letters even if dedicated RSS is weaker.'],
  ['Santa Maria Times', 'Regional daily', 'Likely non-RSS opinion page', 'Good Central Coast representation; opinion section may be page-first rather than feed-first.'],
  ['48 Hills', 'Independent digital', 'Likely non-RSS opinion page', 'Opinion-rich independent outlet; likely easy to classify even if not via clean RSS.'],
  ['Voice of OC', 'Independent digital', 'Likely RSS candidate', 'Digital-first site with strong issue commentary and likely structured feeds.'],
  ['Capital & Main', 'Independent digital', 'Likely RSS candidate', 'Digital publication likely to expose category or site-wide feeds.'],
  ['The Vallejo Sun', 'Independent digital', 'Likely non-RSS opinion page', 'Promising local digital source; may require page monitoring instead of opinion RSS.'],
  ['The Mercury News', 'Bay Area metro influence', 'Manual review candidate', 'Add explicit Bay Area News Group flagship coverage for Silicon Valley and broader Bay Area opinion tracking.'],
  ['East Bay Times', 'Bay Area metro influence', 'Manual review candidate', 'Add East Bay News Group coverage to strengthen Bay Area representation in the prototype.'],
  ['ChicoSol News', 'Independent digital', 'Likely non-RSS opinion page', 'Smaller digital outlet; likely better handled through page checks.'],
  ['The Berkeley Scanner', 'Independent digital', 'Manual review candidate', 'Strong outlet, but opinion cadence may be limited or absent compared with news.'],
  ['A News Café', 'Independent digital', 'Likely non-RSS opinion page', 'Community-driven site and likely to include commentary/community voices.'],
  ['El Tecolote', 'Community and ethnic media', 'Likely non-RSS opinion page', 'Important community voice publication; likely better page/category monitoring than clean opinion RSS.'],
  ['Black Voice News', 'Community and ethnic media', 'Likely non-RSS opinion page', 'High-value civic/community perspective source; likely strong commentary mix.'],
  ['San Fernando Sun Newspaper', 'Community and ethnic media', 'Likely non-RSS opinion page', 'Use this as the practical substitute for the broader organization entry in the prototype.'],
  ['American Community Media', 'Community and ethnic media', 'Manual review candidate', 'May be more organization/network than a straightforward publication feed source.'],
  ['Wind Newspaper', 'Community and ethnic media', 'Likely non-RSS opinion page', 'Useful ethnic/community perspective; likely requires manual opinion-page check.'],
  ['Valley Voice', 'Community and ethnic media', 'Likely non-RSS opinion page', 'Local voice publication likely to have columns/opinion but not necessarily a dedicated RSS feed.'],
  ["Comstock's Magazine", 'Business and civic', 'Likely non-RSS opinion page', 'Useful policy/business lens for Sacramento audience; likely commentary-rich.'],
  ['The Business Journal', 'Business and civic', 'Likely non-RSS opinion page', 'Another strong business/civic perspective source for prototype breadth.']
]

output_headers = [
  'Prototype Publication Name',
  'Matched Publication Name',
  'Bucket',
  'Prototype Priority',
  'Homepage URL',
  'Parent Org',
  'Match Confidence',
  'Notes',
  'Why Included'
]

output_rows = [output_headers]

bang_row = by_name['Bay Area News Group (BANG Newspapers)']

targets.each do |prototype_name, bucket, priority, why|
  row =
    case prototype_name
    when 'The Mercury News', 'East Bay Times'
      bang_row
    else
      by_name[prototype_name]
    end
  unless row
    output_rows << [
      prototype_name,
      '',
      bucket,
      'Out of current matched set',
      '',
      '',
      '',
      'Not present in CNPA matched sheet; include only if you want non-member/out-of-scope prototype sources.',
      why
    ]
    next
  end

  output_rows << [
    prototype_name,
    (prototype_name == 'The Mercury News' || prototype_name == 'East Bay Times') ? prototype_name : row['Matched Publication Name'],
    bucket,
    priority,
    row['Homepage URL'],
    row['Parent Org'],
    row['Match Confidence'],
    if prototype_name == 'The Mercury News'
      'Tracked via Bay Area News Group umbrella record; locate Mercury News opinion source from BANG-managed properties.'
    elsif prototype_name == 'East Bay Times'
      'Tracked via Bay Area News Group umbrella record; locate East Bay Times opinion source from BANG-managed properties.'
    else
      row['Notes']
    end,
    why
  ]
end

CSV.open(output_path, 'w', write_headers: false, force_quotes: true) do |csv|
  output_rows.each { |r| csv << r }
end

puts "Created #{output_path}"
puts "Rows: #{output_rows.length - 1}"
