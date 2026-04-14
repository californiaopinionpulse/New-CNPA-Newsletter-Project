#!/usr/bin/env ruby
# frozen_string_literal: true
# encoding: UTF-8

require 'csv'

input_path = File.expand_path('CNPA prototype subset.csv', __dir__)
output_path = File.expand_path('CNPA prototype feed tracker.csv', __dir__)

rows = CSV.read(input_path, headers: true, encoding: 'bom|utf-8')

findings = {
  'Los Angeles Times' => {
    'Opinion Section URL' => 'https://www.latimes.com/opinion',
    'RSS Opinion feed Y/N' => 'Y',
    'RSS feed URL' => 'https://www.latimes.com/opinion/rss2.0.xml#nt=1col-7030col1',
    'Non-RSS Opinion Page Y/N' => 'Y',
    'Monitoring Method' => 'Use opinion RSS feed',
    'Source Notes' => 'Official LA Times feeds page lists an Opinion feed.'
  },
  'The Sacramento Bee' => {
    'Opinion Section URL' => 'https://www.sacbee.com/opinion/',
    'RSS Opinion feed Y/N' => 'N',
    'RSS feed URL' => '',
    'Non-RSS Opinion Page Y/N' => 'Y',
    'Monitoring Method' => 'Monitor opinion page for new items',
    'Source Notes' => 'Official opinion page confirmed; no dedicated opinion RSS found yet.'
  },
  'The Fresno Bee' => {
    'Opinion Section URL' => 'https://www.fresnobee.com/opinion/',
    'RSS Opinion feed Y/N' => 'N',
    'RSS feed URL' => '',
    'Non-RSS Opinion Page Y/N' => 'Y',
    'Monitoring Method' => 'Monitor opinion page and subpages',
    'Source Notes' => 'Official opinion page confirmed; editorials and op-ed subpages are also visible. Dedicated opinion RSS not confirmed yet.'
  },
  'The Modesto Bee' => {
    'Opinion Section URL' => 'https://www.modbee.com/opinion/opn-columns-blogs/',
    'RSS Opinion feed Y/N' => 'N',
    'RSS feed URL' => '',
    'Non-RSS Opinion Page Y/N' => 'Y',
    'Monitoring Method' => 'Monitor opinion columns/blogs page',
    'Source Notes' => 'Official opinion columns/blogs page confirmed; community columns and other opinion content are visible. Dedicated opinion RSS not confirmed yet.'
  },
  'San Francisco Chronicle' => {
    'Opinion Section URL' => 'https://www.sfchronicle.com/opinion',
    'RSS Opinion feed Y/N' => 'N',
    'RSS feed URL' => '',
    'Non-RSS Opinion Page Y/N' => 'Y',
    'Monitoring Method' => 'Monitor opinion page for new items',
    'Source Notes' => 'Official opinion landing page confirmed; dedicated opinion RSS not confirmed yet.'
  },
  'Voice of OC' => {
    'Opinion Section URL' => 'https://voiceofoc.org/category/involvement/community-opinion/',
    'RSS Opinion feed Y/N' => 'N',
    'RSS feed URL' => '',
    'Non-RSS Opinion Page Y/N' => 'Y',
    'Monitoring Method' => 'Monitor community opinion category page',
    'Source Notes' => 'Official civic engagement page points to Community Opinion; RSS not confirmed.'
  },
  '48 Hills' => {
    'Opinion Section URL' => 'https://48hills.org/category/news-politics/opinion/',
    'RSS Opinion feed Y/N' => 'N',
    'RSS feed URL' => '',
    'Non-RSS Opinion Page Y/N' => 'Y',
    'Monitoring Method' => 'Monitor opinion archive page',
    'Source Notes' => 'Opinion archive page confirmed on site; dedicated opinion RSS not confirmed yet.'
  },
  'The Press Democrat' => {
    'Opinion Section URL' => 'https://www.pressdemocrat.com/article/opinion/',
    'RSS Opinion feed Y/N' => 'N',
    'RSS feed URL' => '',
    'Non-RSS Opinion Page Y/N' => 'Y',
    'Monitoring Method' => 'Monitor opinion articles/category pages',
    'Source Notes' => 'Press Democrat published notice that RSS feeds were discontinued in June 2020.'
  },
  'The San Diego Union-Tribune' => {
    'Opinion Section URL' => '',
    'RSS Opinion feed Y/N' => '',
    'RSS feed URL' => '',
    'Non-RSS Opinion Page Y/N' => '',
    'Monitoring Method' => 'Manual review; likely opinion section exists',
    'Source Notes' => 'Direct opinion-section confirmation was blocked by robots in this pass, but this major metro daily is very likely to maintain opinion/editorial pages.'
  },
  'The Orange County Register' => {
    'Opinion Section URL' => '',
    'RSS Opinion feed Y/N' => '',
    'RSS feed URL' => '',
    'Non-RSS Opinion Page Y/N' => '',
    'Monitoring Method' => 'Manual review; likely opinion section exists',
    'Source Notes' => 'Direct opinion-section confirmation was blocked by robots in this pass, but this large regional daily likely maintains opinion/editorial pages.'
  },
  'The Bakersfield Californian' => {
    'Opinion Section URL' => '',
    'RSS Opinion feed Y/N' => '',
    'RSS feed URL' => '',
    'Non-RSS Opinion Page Y/N' => '',
    'Monitoring Method' => 'Manual review; likely opinion section exists',
    'Source Notes' => 'Direct opinion-section confirmation was not retrievable in this pass due site restrictions and search noise, but this metro daily likely maintains opinion/editorial content.'
  },
  'Monterey County Weekly' => {
    'Opinion Section URL' => '',
    'RSS Opinion feed Y/N' => 'N',
    'RSS feed URL' => '',
    'Non-RSS Opinion Page Y/N' => 'Y',
    'Monitoring Method' => 'Monitor letters/comments opinion pages in weekly archive',
    'Source Notes' => 'Flipbook archives consistently show a Letters • Comments • Opinion section with submission instructions to letters@mcweekly.com; no stable standalone opinion URL was confirmed.'
  },
  'The Union Democrat' => {
    'Opinion Section URL' => '',
    'RSS Opinion feed Y/N' => 'N',
    'RSS feed URL' => '',
    'Non-RSS Opinion Page Y/N' => 'Y',
    'Monitoring Method' => 'Monitor letters to the editor and editorials',
    'Source Notes' => 'Published contact information includes a dedicated letters@uniondemocrat.com address, indicating ongoing opinion/letters workflow; direct opinion page URL was not confirmed in this pass.'
  },
  'Santa Maria Times' => {
    'Opinion Section URL' => 'https://santamariatimes.com/opinion/guest/',
    'RSS Opinion feed Y/N' => 'N',
    'RSS feed URL' => '',
    'Non-RSS Opinion Page Y/N' => 'Y',
    'Monitoring Method' => 'Monitor guest commentary and opinion pages',
    'Source Notes' => 'Multiple externally cited Santa Maria Times guest commentary URLs confirm a working opinion/guest section; direct fetch of the site was blocked by robots.'
  },
  'A News Café' => {
    'Opinion Section URL' => 'https://anewscafe.com/category/opinion/',
    'RSS Opinion feed Y/N' => 'N',
    'RSS feed URL' => '',
    'Non-RSS Opinion Page Y/N' => 'Y',
    'Monitoring Method' => 'Monitor opinion category page',
    'Source Notes' => 'Opinion category page confirmed on site; dedicated opinion RSS not confirmed yet.'
  },
  'Black Voice News' => {
    'Opinion Section URL' => 'https://blackvoicenews.com/category/opinion/',
    'RSS Opinion feed Y/N' => 'N',
    'RSS feed URL' => '',
    'Non-RSS Opinion Page Y/N' => 'Y',
    'Monitoring Method' => 'Monitor opinion archive page',
    'Source Notes' => 'Dedicated opinion archive confirmed on site; dedicated opinion RSS not confirmed yet.'
  },
  'Capital & Main' => {
    'Opinion Section URL' => '',
    'RSS Opinion feed Y/N' => 'N',
    'RSS feed URL' => '',
    'Non-RSS Opinion Page Y/N' => 'N',
    'Monitoring Method' => 'Deprioritize for opinion prototype',
    'Source Notes' => 'Capital & Main explicitly describes itself as fact-based reporting, not opinion. It may be useful editorially, but it is not a clean fit for an opinion-feed prototype.'
  },
  'The Vallejo Sun' => {
    'Opinion Section URL' => '',
    'RSS Opinion feed Y/N' => 'N',
    'RSS feed URL' => '',
    'Non-RSS Opinion Page Y/N' => 'N',
    'Monitoring Method' => 'Manual review; no dedicated opinion section confirmed',
    'Source Notes' => 'Search results in this pass surfaced reported news and tagged author pages, but no dedicated opinion/commentary archive was confirmed.'
  },
  'ChicoSol News' => {
    'Opinion Section URL' => '',
    'RSS Opinion feed Y/N' => 'N',
    'RSS feed URL' => '',
    'Non-RSS Opinion Page Y/N' => 'Y',
    'Monitoring Method' => 'Monitor guest commentary and point-of-view stories',
    'Source Notes' => 'ChicoSol describes itself as fact-based reporting with guest commentaries, and multiple current stories are explicitly labeled Commentary or Point of View.'
  },
  'The Berkeley Scanner' => {
    'Opinion Section URL' => '',
    'RSS Opinion feed Y/N' => 'N',
    'RSS feed URL' => '',
    'Non-RSS Opinion Page Y/N' => 'N',
    'Monitoring Method' => 'Deprioritize; no opinion section identified',
    'Source Notes' => 'Current site presentation emphasizes independent daily crime and safety news. No dedicated opinion/commentary section was identified in this pass.'
  },
  'El Tecolote' => {
    'Opinion Section URL' => '',
    'RSS Opinion feed Y/N' => 'N',
    'RSS feed URL' => '',
    'Non-RSS Opinion Page Y/N' => '',
    'Monitoring Method' => 'Manual review; community-perspective outlet but opinion section unconfirmed',
    'Source Notes' => 'El Tecolote clearly offers community journalism from a Latinx perspective, but a dedicated opinion/op-ed archive was not confirmed in this pass.'
  },
  'Wind Newspaper' => {
    'Opinion Section URL' => 'https://www.windnewspaper.com/category/opinions',
    'RSS Opinion feed Y/N' => 'N',
    'RSS feed URL' => '',
    'Non-RSS Opinion Page Y/N' => 'Y',
    'Monitoring Method' => 'Monitor opinions and open forum page',
    'Source Notes' => 'Dedicated Opinions page confirmed on site; homepage also highlights Opinions & Open Forum content.'
  },
  'San Fernando Sun Newspaper' => {
    'Opinion Section URL' => 'https://sanfernandosun.com/category/opinion/',
    'RSS Opinion feed Y/N' => 'N',
    'RSS feed URL' => '',
    'Non-RSS Opinion Page Y/N' => 'Y',
    'Monitoring Method' => 'Monitor opinion archive page',
    'Source Notes' => 'Dedicated opinion archive confirmed on site; dedicated opinion RSS not confirmed yet.'
  },
  "Comstock's Magazine" => {
    'Opinion Section URL' => 'https://www.comstocksmag.com/opinion',
    'RSS Opinion feed Y/N' => 'N',
    'RSS feed URL' => '',
    'Non-RSS Opinion Page Y/N' => 'Y',
    'Monitoring Method' => 'Monitor opinion page',
    'Source Notes' => 'Dedicated opinion page and opinion submission guidance confirmed on site; dedicated opinion RSS not confirmed yet.'
  },
  'The Business Journal' => {
    'Opinion Section URL' => 'https://thebusinessjournal.com/opinion/',
    'RSS Opinion feed Y/N' => 'N',
    'RSS feed URL' => '',
    'Non-RSS Opinion Page Y/N' => 'Y',
    'Monitoring Method' => 'Monitor opinion archive page',
    'Source Notes' => 'Dedicated opinion archive confirmed on site; dedicated opinion RSS not confirmed yet.'
  },
  'Valley Voice' => {
    'Opinion Section URL' => '',
    'RSS Opinion feed Y/N' => 'N',
    'RSS feed URL' => '',
    'Non-RSS Opinion Page Y/N' => 'Y',
    'Monitoring Method' => 'Monitor site for opinion-labeled and letter posts',
    'Source Notes' => 'Multiple current Valley Voice articles are explicitly labeled OPINION, including letters; a dedicated opinion archive URL was not confirmed in this pass.'
  },
  'Ventura County Star' => {
    'Opinion Section URL' => '',
    'RSS Opinion feed Y/N' => '',
    'RSS feed URL' => '',
    'Non-RSS Opinion Page Y/N' => '',
    'Monitoring Method' => 'Manual review; likely opinion section exists',
    'Source Notes' => 'Archive pages show historic Ventura County Star /opinion/ URLs, but current direct section confirmation was blocked by robots.'
  },
  'The Desert Sun' => {
    'Opinion Section URL' => '',
    'RSS Opinion feed Y/N' => '',
    'RSS feed URL' => '',
    'Non-RSS Opinion Page Y/N' => '',
    'Monitoring Method' => 'Manual review; likely opinion section exists',
    'Source Notes' => 'Direct opinion-section confirmation was blocked in web retrieval during this pass.'
  },
  'Redding Record Searchlight' => {
    'Opinion Section URL' => '',
    'RSS Opinion feed Y/N' => '',
    'RSS feed URL' => '',
    'Non-RSS Opinion Page Y/N' => '',
    'Monitoring Method' => 'Manual review; likely opinion section exists',
    'Source Notes' => 'Redding.com is a Gannett property with letters-to-editor workflows and news section fronts visible, but current opinion section could not be directly confirmed in this pass.'
  },
  'The Mercury News' => {
    'Opinion Section URL' => '',
    'RSS Opinion feed Y/N' => '',
    'RSS feed URL' => '',
    'Non-RSS Opinion Page Y/N' => '',
    'Monitoring Method' => 'Manual review under BANG umbrella',
    'Source Notes' => 'Bay Area News Group official pages confirm The Mercury News is a BANG flagship property; opinion landing page not confirmed in this pass.'
  },
  'East Bay Times' => {
    'Opinion Section URL' => '',
    'RSS Opinion feed Y/N' => '',
    'RSS feed URL' => '',
    'Non-RSS Opinion Page Y/N' => '',
    'Monitoring Method' => 'Manual review under BANG umbrella',
    'Source Notes' => 'Bay Area News Group official pages confirm East Bay Times is a BANG property; opinion landing page not confirmed in this pass.'
  },
  'American Community Media' => {
    'Opinion Section URL' => 'https://americancommunitymedia.org/category/oped/',
    'RSS Opinion feed Y/N' => 'N',
    'RSS feed URL' => '',
    'Non-RSS Opinion Page Y/N' => 'Y',
    'Monitoring Method' => 'Monitor op-ed category page',
    'Source Notes' => 'ACoM has a dedicated Op-Ed category and describes its mission as distributing news, opinion and analysis through its community media syndicate.'
  }
}.freeze

headers = rows.headers + [
  'Opinion Section URL',
  'RSS Opinion feed Y/N',
  'RSS feed URL',
  'Non-RSS Opinion Page Y/N',
  'Monitoring Method',
  'Source Notes'
]

CSV.open(output_path, 'w', write_headers: true, headers: headers, force_quotes: true) do |csv|
  rows.each do |row|
    base = row.to_h
    data = findings[row['Prototype Publication Name']] || {}
    csv << headers.map { |h| data.key?(h) ? data[h] : base[h] }
  end
end

puts "Created #{output_path}"
puts "Confirmed entries: #{findings.length}"
