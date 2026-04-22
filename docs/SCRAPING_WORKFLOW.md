# Scraping Workflow

## Goal

Collect opinion/article candidates from a small pilot source set into a normalized local intake file before wiring those records into Airtable.

## Current Configured Sources

- `los_angeles_times` - RSS
- `sacramento_bee` - page monitor
- `fresno_bee` - page monitor
- `modesto_bee` - page monitor
- `san_francisco_chronicle` - page monitor
- `voice_of_oc` - page monitor
- `a_news_cafe` - page monitor
- `forty_eight_hills` - page monitor
- `press_democrat` - page monitor
- `san_fernando_sun` - page monitor
- `american_community_media` - page monitor
- `wind_newspaper` - page monitor
- `business_journal` - page monitor
- `san_diego_union_tribune` - page monitor
- `orange_county_register` - page monitor
- `ventura_county_star` - page monitor
- `desert_sun` - page monitor
- `redding_record_searchlight` - page monitor
- `union_democrat` - page monitor

## Paused Sources

- `black_voice_news` - currently excluded from default runs pending later review

## Normalized Output Fields

- `source_key`
- `publication`
- `source_type`
- `source_url`
- `article_url`
- `title`
- `author`
- `published_date`
- `raw_excerpt`
- `body_text`
- `collected_at`
- `collector_mode`

## Run

From the project root:

```powershell
ruby .\scripts\scrape_cnpa_content.rb
```

Limit to one source:

```powershell
ruby .\scripts\scrape_cnpa_content.rb --source los_angeles_times
```

List the configured pilot sources:

```powershell
ruby .\scripts\scrape_cnpa_content.rb --list-sources
```

## Output Files

The collector writes to `data/generated/content_intake/`:

- `latest_content_intake.json`
- `latest_content_intake.csv`
- timestamped JSON snapshots

## Current Shape

This is a scaffold, not the finished ingestion system yet.

It currently:

- supports one RSS path and an expanding set of page-monitor paths
- uses only Ruby standard-library dependencies
- extracts article metadata primarily from RSS fields, JSON-LD, and HTML meta tags
- keeps only current content from the previous 4 weeks by default
- flags or excludes weak-source output according to current prototype rules
- gives us a clean staging layer before Airtable writes

## Next Steps

1. Formalize pause criteria for weak sources during the prototype phase.
2. Decide whether low-yield sources should stay active or be paused temporarily.
3. Keep the active source set synced across PC and MacBook through GitHub.
4. Move upstream into editorial review workflow and issue assembly once the active scrape set is stable.
