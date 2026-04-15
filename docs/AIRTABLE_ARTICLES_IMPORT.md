# Airtable Articles Import

## Goal

Convert the normalized content intake output into the `Articles` CSV shape used by the Airtable prototype.

## Input

- `data/generated/content_intake/latest_content_intake.json`
- `airtable_publications_prototype_import.csv`
- `airtable_articles_template.csv`

## Output

- `data/generated/content_intake/airtable_articles_import.csv`

## Run

From the project root:

```powershell
ruby .\scripts\build_airtable_articles_import.rb
```

## What It Does

- skips records without an `article_url`
- deduplicates by `Article URL`
- maps `Opinion Source URL` and `Source Type` from the publications import when possible
- computes `Issue Week` from the article publish date
- marks successful records as `Ready for review`
- carries collection context into `Notes`

## Current Limits

- `Region`, `AI Summary`, and `Topic Tag` are still blank placeholders
- blocked sources such as `Black Voice News` will not become importable until collection succeeds
- this is a CSV-import layer, not a live Airtable API sync
