#!/usr/bin/env ruby
# frozen_string_literal: true

module CnpaIntake
  module SourceRegistry
    module_function

    def all
      [
        {
          key: 'los_angeles_times',
          publication: 'Los Angeles Times',
          mode: :rss,
          source_type: 'rss',
          feed_url: 'https://www.latimes.com/opinion/rss2.0.xml#nt=1col-7030col1'
        },
        {
          key: 'sacramento_bee',
          publication: 'The Sacramento Bee',
          mode: :page,
          source_type: 'page_monitor',
          list_url: 'https://www.sacbee.com/opinion/',
          list_urls: [
            'https://www.sacbee.com/opinion/op-ed/',
            'https://www.sacbee.com/opinion/election-endorsements/',
            'https://www.sacbee.com/opinion/'
          ],
          allowed_hosts: ['www.sacbee.com', 'amp.sacbee.com'],
          article_url_patterns: [%r{/article\d+\.html}],
          discovery: :mcclatchy_state,
          max_articles: 6,
          open_timeout: 15,
          read_timeout: 45,
          retries: 1,
          headers: {
            'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36',
            'Upgrade-Insecure-Requests' => '1'
          }
        },
        {
          key: 'fresno_bee',
          publication: 'The Fresno Bee',
          mode: :page,
          source_type: 'page_monitor',
          list_url: 'https://www.fresnobee.com/opinion/',
          list_urls: [
            'https://www.fresnobee.com/opinion/readers-opinion/',
            'https://www.fresnobee.com/opinion/editorials/',
            'https://www.fresnobee.com/opinion/'
          ],
          allowed_hosts: ['www.fresnobee.com', 'amp.fresnobee.com'],
          article_url_patterns: [%r{/article\d+\.html}],
          discovery: :mcclatchy_state,
          max_articles: 6,
          open_timeout: 15,
          read_timeout: 45,
          retries: 1,
          headers: {
            'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36',
            'Upgrade-Insecure-Requests' => '1'
          }
        },
        {
          key: 'voice_of_oc',
          publication: 'Voice of OC',
          mode: :page,
          source_type: 'page_monitor',
          list_url: 'https://voiceofoc.org/category/involvement/community-opinion/',
          allowed_hosts: ['voiceofoc.org'],
          article_url_patterns: [%r{/\d{4}/\d{2}/}],
          max_articles: 6,
          retries: 1
        },
        {
          key: 'san_francisco_chronicle',
          publication: 'San Francisco Chronicle',
          mode: :page,
          source_type: 'page_monitor',
          list_url: 'https://www.sfchronicle.com/opinion',
          allowed_hosts: ['www.sfchronicle.com', 'sfchronicle.com'],
          article_url_patterns: [%r{/opinion/article/}, %r{/opinion/}],
          exclude_url_patterns: [
            %r{/opinion/editorials/?$},
            %r{/opinion/letterstotheeditor/?$},
            %r{/opinion/openforum/?$}
          ],
          max_articles: 6,
          retries: 1,
          headers: {
            'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36'
          }
        },
        {
          key: 'modesto_bee',
          publication: 'The Modesto Bee',
          mode: :page,
          source_type: 'page_monitor',
          list_url: 'https://www.modbee.com/opinion/opn-columns-blogs/',
          list_urls: [
            'https://www.modbee.com/opinion/editorials/',
            'https://www.modbee.com/opinion/opn-columns-blogs/community-columns/',
            'https://www.modbee.com/opinion/opn-columns-blogs/',
            'https://www.modbee.com/opinion/'
          ],
          allowed_hosts: ['www.modbee.com', 'amp.modbee.com'],
          article_url_patterns: [%r{/article\d+\.html}],
          discovery: :mcclatchy_state,
          ignore_context_patterns: [%r{sectionheadlines}i, %r{trending}i],
          required_context_patterns: [%r{/opinion/}i, %r{community-columns}i, %r{editorials}i, %r{opn-columns-blogs}i],
          disable_feed_fallback: true,
          max_articles: 6,
          candidate_limit: 32,
          open_timeout: 15,
          read_timeout: 45,
          retries: 1,
          headers: {
            'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36',
            'Upgrade-Insecure-Requests' => '1'
          }
        },
        {
          key: 'a_news_cafe',
          publication: 'A News Cafe',
          mode: :page,
          source_type: 'page_monitor',
          list_url: 'https://anewscafe.com/category/opinion/',
          allowed_hosts: ['anewscafe.com'],
          article_url_patterns: [%r{/\d{4}/\d{2}/}],
          max_articles: 6,
          retries: 1
        },
        {
          key: 'forty_eight_hills',
          publication: '48 Hills',
          mode: :page,
          source_type: 'page_monitor',
          list_url: 'https://48hills.org/category/news-politics/opinion/',
          allowed_hosts: ['48hills.org'],
          article_url_patterns: [%r{/\d{4}/\d{2}/}, %r{/news-politics/}],
          exclude_url_patterns: [
            %r{/category/news-politics/?$},
            %r{/category/news-politics/opinion/humor/?$}
          ],
          max_articles: 6,
          retries: 1
        },
        {
          key: 'black_voice_news',
          publication: 'Black Voice News',
          active: false,
          mode: :page,
          source_type: 'page_monitor',
          list_url: 'https://blackvoicenews.com/category/opinion/',
          allowed_hosts: ['blackvoicenews.com'],
          article_url_patterns: [%r{/\d{4}/\d{2}/}],
          max_articles: 6,
          open_timeout: 15,
          read_timeout: 30,
          retries: 0,
          headers: {
            'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36',
            'Referer' => 'https://blackvoicenews.com/'
          }
        },
        {
          key: 'press_democrat',
          publication: 'The Press Democrat',
          mode: :page,
          source_type: 'page_monitor',
          list_url: 'https://www.pressdemocrat.com/opinion/',
          allowed_hosts: ['www.pressdemocrat.com'],
          article_url_patterns: [%r{/\d{4}/\d{2}/\d{2}/}, %r{/opinion/}],
          exclude_url_patterns: [
            %r{/opinion/?$},
            %r{/opinion/editorials/?$},
            %r{/opinion/letters-to-the-editor/?$}
          ],
          ignore_context_patterns: [%r{widget-trending-stories}i, %r{trending-bar}i],
          required_context_patterns: [%r{category-opinion}i, %r{opinion-columnists}i, %r{type-of-work-opinion}i],
          feed_urls: ['https://www.pressdemocrat.com/opinion/feed/'],
          max_articles: 6,
          min_articles: 3,
          retries: 1,
          headers: {
            'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36'
          }
        },
        {
          key: 'san_fernando_sun',
          publication: 'San Fernando Sun Newspaper',
          mode: :page,
          source_type: 'page_monitor',
          list_url: 'https://sanfernandosun.com/category/opinion/',
          allowed_hosts: ['sanfernandosun.com'],
          article_url_patterns: [%r{/\d{4}/\d{2}/}, %r{/category/opinion/}],
          max_articles: 6,
          retries: 1
        },
        {
          key: 'american_community_media',
          publication: 'American Community Media',
          mode: :page,
          source_type: 'page_monitor',
          list_url: 'https://americancommunitymedia.org/category/oped/',
          allowed_hosts: ['americancommunitymedia.org'],
          article_url_patterns: [%r{/oped/}],
          exclude_url_patterns: [
            %r{^https?://americancommunitymedia\.org/?$},
            %r{/category/oped/?$},
            %r{/category/},
            %r{/tag/},
            %r{/initiatives/?$},
            %r{/most-popular/?$}
          ],
          max_articles: 6,
          retries: 1
        },
        {
          key: 'wind_newspaper',
          publication: 'Wind Newspaper',
          mode: :page,
          source_type: 'page_monitor',
          list_url: 'https://www.windnewspaper.com',
          list_urls: [
            'https://www.windnewspaper.com/category/opinions-and-open-forum',
            'https://www.windnewspaper.com/category/editorial',
            'https://www.windnewspaper.com'
          ],
          allowed_hosts: ['www.windnewspaper.com', 'windnewspaper.com'],
          article_url_patterns: [%r{/article/opinion}, %r{/article/open-forum}, %r{/article/editorial}],
          exclude_url_patterns: [
            %r{/category/editorial/?$},
            %r{/category/opinions/?$},
            %r{/category/opinion/?$},
            %r{/category/opinions-and-open-forum/?$}
          ],
          max_articles: 6,
          candidate_limit: 24,
          retries: 1
        },
        {
          key: 'business_journal',
          publication: 'The Business Journal',
          mode: :page,
          source_type: 'page_monitor',
          list_url: 'https://thebusinessjournal.com/opinion/',
          allowed_hosts: ['thebusinessjournal.com', 'www.thebusinessjournal.com'],
          article_url_patterns: [%r{/20\d{2}/}, %r{/[a-z0-9-]+/?$}],
          exclude_url_patterns: [
            %r{/opinion/?$},
            %r{/opinion/page/\d+/?$},
            %r{\.pdf$},
            %r{/contact-us/?$},
            %r{/advertise/?$},
            %r{/newsletter/?$}
          ],
          max_articles: 6,
          retries: 1
        },
        {
          key: 'san_diego_union_tribune',
          publication: 'The San Diego Union-Tribune',
          mode: :page,
          source_type: 'page_monitor',
          list_url: 'https://www.sandiegouniontribune.com/opinion/',
          allowed_hosts: ['www.sandiegouniontribune.com', 'sandiegouniontribune.com'],
          article_url_patterns: [%r{/\d{4}/\d{2}/\d{2}/}, %r{/opinion/}],
          exclude_url_patterns: [
            %r{/opinion/?$},
            %r{/opinion/commentary/?$},
            %r{/opinion/editorials/?$},
            %r{/opinion/letters-to-the-editor/?$},
            %r{/opinion/opinion-columnists/?$}
          ],
          ignore_context_patterns: [%r{widget-trending-stories}i, %r{trending-bar}i],
          required_context_patterns: [%r{category-opinion}i, %r{type-of-work-opinion}i, %r{category-commentary}i],
          feed_urls: ['https://www.sandiegouniontribune.com/opinion/feed/'],
          max_articles: 6,
          min_articles: 3,
          retries: 1,
          headers: {
            'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36'
          }
        },
        {
          key: 'orange_county_register',
          publication: 'The Orange County Register',
          mode: :page,
          source_type: 'page_monitor',
          list_url: 'https://www.ocregister.com/opinion/',
          allowed_hosts: ['www.ocregister.com', 'ocregister.com'],
          article_url_patterns: [%r{/\d{4}/\d{2}/\d{2}/}],
          exclude_url_patterns: [
            %r{/opinion/?$},
            %r{/opinion/editorials/?$},
            %r{/opinion/opinion-columnists/?$},
            %r{/opinion/commentary/?$},
            %r{/opinion/letters-to-the-editor/?$},
            %r{/opinion/endorsements/?$},
            %r{/editorial-board/?$}
          ],
          max_articles: 6,
          retries: 1,
          headers: {
            'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36'
          }
        },
        {
          key: 'ventura_county_star',
          publication: 'Ventura County Star',
          mode: :page,
          source_type: 'page_monitor',
          list_url: 'https://www.vcstar.com/opinion/',
          allowed_hosts: ['www.vcstar.com', 'vcstar.com'],
          article_url_patterns: [%r{/story/opinion/}],
          exclude_url_patterns: [
            %r{/opinion/?$},
            %r{/opinion/editorials/?$},
            %r{/opinion/letters/?$},
            %r{/opinion/columnists/?$}
          ],
          max_articles: 6,
          retries: 1,
          headers: {
            'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36'
          }
        },
        {
          key: 'desert_sun',
          publication: 'The Desert Sun',
          mode: :page,
          source_type: 'page_monitor',
          list_url: 'https://www.desertsun.com/opinion/',
          list_urls: [
            'https://www.desertsun.com/opinion/valley-voice/',
            'https://www.desertsun.com/opinion/letters/',
            'https://www.desertsun.com/opinion/'
          ],
          allowed_hosts: ['www.desertsun.com', 'desertsun.com', 'www.thedesertsun.com'],
          article_url_patterns: [%r{/story/opinion/}],
          exclude_url_patterns: [
            %r{/opinion/?$},
            %r{/opinion/editorials/?$},
            %r{/opinion/letters/?$},
            %r{/opinion/valley-voice/?$}
          ],
          max_articles: 6,
          candidate_limit: 30,
          retries: 1,
          headers: {
            'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36'
          }
        },
        {
          key: 'redding_record_searchlight',
          publication: 'Redding Record Searchlight',
          mode: :page,
          source_type: 'page_monitor',
          list_url: 'https://www.redding.com/opinion/',
          list_urls: [
            'https://www.redding.com/opinion/speak-your-piece/',
            'https://www.redding.com/opinion/',
            'https://www.redding.com/opinion/editorials/'
          ],
          allowed_hosts: ['www.redding.com', 'redding.com'],
          article_url_patterns: [%r{/story/opinion/}],
          exclude_url_patterns: [
            %r{/opinion/?$},
            %r{/opinion/speak-your-piece/?$},
            %r{/opinion/editorials/?$}
          ],
          candidate_limit: 30,
          max_articles: 6,
          retries: 1,
          headers: {
            'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36'
          }
        },
        {
          key: 'union_democrat',
          publication: 'The Union Democrat',
          mode: :page,
          source_type: 'page_monitor',
          list_url: 'https://www.uniondemocrat.com/',
          allowed_hosts: ['www.uniondemocrat.com', 'uniondemocrat.com'],
          article_url_patterns: [%r{/opinion/}],
          exclude_url_patterns: [
            %r{/users/},
            %r{/image_[a-f0-9-]+\.html$},
            %r{/sports/},
            %r{/lifestyle/}
          ],
          disable_feed_fallback: true,
          max_articles: 6,
          retries: 1,
          headers: {
            'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36'
          }
        }
      ]
    end

    def fetch(keys = [])
      return all.select { |source| source.fetch(:active, true) } if keys.nil? || keys.empty?

      wanted = keys.map(&:downcase)
      all.select { |source| wanted.include?(source[:key]) }
    end
  end
end
