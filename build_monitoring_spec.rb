#!/usr/bin/env ruby
# frozen_string_literal: true
# encoding: UTF-8

require 'csv'

def read_csv(path)
  CSV.read(path, headers: true, encoding: 'bom|utf-8', row_sep: :auto, liberal_parsing: true)
rescue CSV::MalformedCSVError
  normalized = File.read(path, mode: 'r:bom|utf-8').gsub("\r\n", "\n")
  CSV.parse(normalized, headers: true, liberal_parsing: true)
end

input_path = File.expand_path('CNPA prototype ingestion list.csv', __dir__)
output_path = File.expand_path('CNPA prototype monitoring spec.csv', __dir__)

rows = read_csv(input_path)

headers = [
  'Prototype Publication Name',
  'Ingestion Tier',
  'Recommended System',
  'Primary Source URL',
  'Platform / Pattern Family',
  'List-Page Monitoring Rule',
  'Candidate Article Link Pattern',
  'Article Detail Fetch Needed',
  'Title Extraction',
  'Author Extraction',
  'Date Extraction',
  'Summary Extraction',
  'Dedup Key',
  'Operational Notes'
]

def spec_for(row)
  name = row['Prototype Publication Name']
  homepage = row['Homepage URL']
  opinion_url = row['Opinion Section URL'].to_s
  source_url = opinion_url.empty? ? homepage : opinion_url

  default = {
    'Platform / Pattern Family' => 'General web page',
    'List-Page Monitoring Rule' => 'Detect newly listed article URLs on the source page',
    'Candidate Article Link Pattern' => 'Links under the opinion/category page that resolve to article pages',
    'Article Detail Fetch Needed' => 'Yes',
    'Title Extraction' => 'From article page <title> / main headline',
    'Author Extraction' => 'From byline on article page',
    'Date Extraction' => 'From published/updated timestamp on article page',
    'Summary Extraction' => 'Use list excerpt when available; otherwise generate summary from article body',
    'Dedup Key' => 'Canonical article URL',
    'Operational Notes' => row['Implementation Notes']
  }

  overrides = case name
  when 'Los Angeles Times'
    {
      'Platform / Pattern Family' => 'Tribune Publishing / RSS',
      'List-Page Monitoring Rule' => 'Ingest every new item from the opinion RSS feed',
      'Candidate Article Link Pattern' => 'Use URLs emitted by RSS feed',
      'Article Detail Fetch Needed' => 'Optional',
      'Title Extraction' => 'RSS item title',
      'Author Extraction' => 'RSS item author if present; otherwise article page byline',
      'Date Extraction' => 'RSS pubDate',
      'Summary Extraction' => 'RSS description or generated article summary',
      'Operational Notes' => 'Best direct Feedly source in the prototype. Minimal engineering needed.'
    }
  when 'The Sacramento Bee', 'The Fresno Bee'
    {
      'Platform / Pattern Family' => 'McClatchy opinion index',
      'List-Page Monitoring Rule' => 'Check the main opinion landing page for new headline links and section sub-links such as Editorials, Viewpoints, Letters',
      'Candidate Article Link Pattern' => 'Links under the opinion module, usually article URLs on the same domain',
      'Article Detail Fetch Needed' => 'Yes',
      'Title Extraction' => 'List page headline as fallback; confirm on article page',
      'Author Extraction' => 'Article page byline',
      'Date Extraction' => 'Article page published/updated timestamp',
      'Summary Extraction' => 'List page deck when present; otherwise generate from article body',
      'Operational Notes' => 'McClatchy layout is structured enough for a lightweight page monitor; treat category labels as useful metadata.'
    }
  when 'The Modesto Bee'
    {
      'Platform / Pattern Family' => 'McClatchy opinion columns/blogs index',
      'List-Page Monitoring Rule' => 'Check opinion columns/blogs landing page for newly listed headlines',
      'Candidate Article Link Pattern' => 'Links under opinion columns/blogs section on modbee.com',
      'Article Detail Fetch Needed' => 'Yes',
      'Title Extraction' => 'List headline fallback, confirm on article page',
      'Author Extraction' => 'Article page byline',
      'Date Extraction' => 'Article page published/updated timestamp',
      'Summary Extraction' => 'List deck when present; otherwise generate from article body'
    }
  when 'San Francisco Chronicle'
    {
      'Platform / Pattern Family' => 'Hearst opinion landing page',
      'List-Page Monitoring Rule' => 'Check Chronicle opinion landing page for newly listed commentary/editorial links',
      'Candidate Article Link Pattern' => 'Links under /opinion/ on sfchronicle.com',
      'Article Detail Fetch Needed' => 'Yes',
      'Title Extraction' => 'List headline fallback, confirm on article page',
      'Author Extraction' => 'Article byline',
      'Date Extraction' => 'Article timestamp',
      'Summary Extraction' => 'Use list deck when present; otherwise generate from article body'
    }
  when 'The Press Democrat'
    {
      'Platform / Pattern Family' => 'Custom CMS opinion articles',
      'List-Page Monitoring Rule' => 'Check opinion article landing page for newly listed article URLs',
      'Candidate Article Link Pattern' => 'PressDemocrat article links under opinion/article pages',
      'Article Detail Fetch Needed' => 'Yes',
      'Operational Notes' => 'RSS is discontinued; page monitoring is the right long-term path.'
    }
  when 'Voice of OC'
    {
      'Platform / Pattern Family' => 'WordPress category page',
      'List-Page Monitoring Rule' => 'Monitor Community Opinion category page pagination for new post URLs',
      'Candidate Article Link Pattern' => 'voiceofoc.org/category/involvement/community-opinion/... article links',
      'Article Detail Fetch Needed' => 'Yes',
      'Title Extraction' => 'Category page headline fallback, confirm on article page',
      'Author Extraction' => 'Article byline',
      'Date Extraction' => 'Article page date',
      'Summary Extraction' => 'Use category page excerpt when present; otherwise generate from article body'
    }
  when 'A News Café'
    {
      'Platform / Pattern Family' => 'WordPress category page',
      'List-Page Monitoring Rule' => 'Monitor Opinion category page and newer pagination for newly published post URLs',
      'Candidate Article Link Pattern' => 'anewscafe.com post links listed under Opinion',
      'Article Detail Fetch Needed' => 'Yes'
    }
  when '48 Hills'
    {
      'Platform / Pattern Family' => 'WordPress category archive',
      'List-Page Monitoring Rule' => 'Monitor Opinion archive for new post URLs',
      'Candidate Article Link Pattern' => '48hills article links under /category/news-politics/opinion/',
      'Article Detail Fetch Needed' => 'Yes'
    }
  when 'Black Voice News', 'San Fernando Sun Newspaper', 'Wind Newspaper', 'American Community Media'
    {
      'Platform / Pattern Family' => 'Category/archive page',
      'List-Page Monitoring Rule' => 'Monitor category or op-ed archive for newly listed article URLs',
      'Candidate Article Link Pattern' => 'Links under the confirmed opinion/category archive on the same domain',
      'Article Detail Fetch Needed' => 'Yes'
    }
  when "Comstock's Magazine", 'The Business Journal'
    {
      'Platform / Pattern Family' => 'Magazine/business opinion archive',
      'List-Page Monitoring Rule' => 'Monitor opinion archive for new article URLs',
      'Candidate Article Link Pattern' => 'Links listed on opinion page within same domain',
      'Article Detail Fetch Needed' => 'Yes'
    }
  when 'Monterey County Weekly'
    {
      'Platform / Pattern Family' => 'Weekly issue archive / flipbook',
      'List-Page Monitoring Rule' => 'Check each new weekly issue for a Letters • Comments • Opinion section',
      'Candidate Article Link Pattern' => 'Opinion items embedded in weekly issue archive rather than a stable category page',
      'Article Detail Fetch Needed' => 'Maybe',
      'Title Extraction' => 'From issue archive headlines or linked article titles',
      'Author Extraction' => 'From issue text or linked article page',
      'Date Extraction' => 'Use issue date or linked article date',
      'Summary Extraction' => 'Generate from issue text or linked article body',
      'Operational Notes' => 'This is a good candidate for manual-assisted weekly extraction rather than a fully generic scraper.'
    }
  when 'The Union Democrat'
    {
      'Platform / Pattern Family' => 'Letters/editorials workflow',
      'List-Page Monitoring Rule' => 'Check site for newly posted letters, editorials, or opinion items; use letters workflow as evidence opinion content exists',
      'Candidate Article Link Pattern' => 'Opinion/editorial article URLs if found during site crawl',
      'Article Detail Fetch Needed' => 'Yes',
      'Operational Notes' => 'Treat as a page-monitor candidate, but expect a small amount of manual QA until a stable opinion page is identified.'
    }
  when 'Santa Maria Times'
    {
      'Platform / Pattern Family' => 'Lee Enterprises opinion guest page',
      'List-Page Monitoring Rule' => 'Monitor /opinion/guest/ plus nearby opinion pages for new commentary URLs',
      'Candidate Article Link Pattern' => 'santamariatimes.com/opinion/guest/... article URLs',
      'Article Detail Fetch Needed' => 'Yes'
    }
  when 'ChicoSol News'
    {
      'Platform / Pattern Family' => 'Nonprofit newsroom with guest commentary',
      'List-Page Monitoring Rule' => 'Monitor for commentary / point-of-view / guest-commentary stories',
      'Candidate Article Link Pattern' => 'chicosol.org article URLs flagged as commentary or point of view',
      'Article Detail Fetch Needed' => 'Yes',
      'Operational Notes' => 'Good candidate for keyword-based filtering on list pages if a dedicated archive is absent.'
    }
  when 'Valley Voice'
    {
      'Platform / Pattern Family' => 'General article stream with opinion-labeled posts',
      'List-Page Monitoring Rule' => 'Monitor homepage/category streams for posts labeled OPINION or letters',
      'Candidate Article Link Pattern' => 'ourvalleyvoice.com article URLs with OPINION labeling',
      'Article Detail Fetch Needed' => 'Yes',
      'Operational Notes' => 'Use content labeling rather than relying on a dedicated archive URL.'
    }
  when 'Capital & Main'
    {
      'Platform / Pattern Family' => 'Digital outlet not opinion-led',
      'List-Page Monitoring Rule' => 'Skip for first prototype',
      'Candidate Article Link Pattern' => '',
      'Article Detail Fetch Needed' => 'No',
      'Title Extraction' => '',
      'Author Extraction' => '',
      'Date Extraction' => '',
      'Summary Extraction' => '',
      'Operational Notes' => 'Not a clean opinion-source fit.'
    }
  when 'The Berkeley Scanner'
    {
      'Platform / Pattern Family' => 'News-only outlet',
      'List-Page Monitoring Rule' => 'Skip for first prototype',
      'Candidate Article Link Pattern' => '',
      'Article Detail Fetch Needed' => 'No',
      'Title Extraction' => '',
      'Author Extraction' => '',
      'Date Extraction' => '',
      'Summary Extraction' => '',
      'Operational Notes' => 'No opinion section identified.'
    }
  else
    {
      'Operational Notes' => row['Implementation Notes']
    }
  end

  [
    name,
    row['Ingestion Tier'],
    row['Recommended System'],
    source_url,
    default['Platform / Pattern Family'].then { |v| overrides['Platform / Pattern Family'] || v },
    default['List-Page Monitoring Rule'].then { |v| overrides['List-Page Monitoring Rule'] || v },
    default['Candidate Article Link Pattern'].then { |v| overrides['Candidate Article Link Pattern'] || v },
    default['Article Detail Fetch Needed'].then { |v| overrides['Article Detail Fetch Needed'] || v },
    default['Title Extraction'].then { |v| overrides['Title Extraction'] || v },
    default['Author Extraction'].then { |v| overrides['Author Extraction'] || v },
    default['Date Extraction'].then { |v| overrides['Date Extraction'] || v },
    default['Summary Extraction'].then { |v| overrides['Summary Extraction'] || v },
    default['Dedup Key'],
    overrides['Operational Notes'] || default['Operational Notes']
  ]
end

CSV.open(output_path, 'w', write_headers: true, headers: headers, force_quotes: true, row_sep: "\n") do |csv|
  rows.each do |row|
    csv << spec_for(row)
  end
end

puts "Created #{output_path}"
