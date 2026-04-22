# PC Setup

## Goal

Keep this Windows clone usable as a primary COP prototype workstation and ready for MacBook handoff via GitHub.

## Required Tools

1. Git
2. Ruby

## Current State

This PC is already configured for active work:

- `git` works in PowerShell
- `ruby` works in PowerShell
- `.\run_pipeline.ps1` works
- the scraper and Airtable export scripts run locally

## Run Order

From the project root:

```powershell
.\run_pipeline.ps1
ruby .\scripts\scrape_cnpa_content.rb
ruby .\scripts\build_airtable_articles_import.rb
```

## Expected Outputs

- `CNPA URLS and opinion feeds.csv`
- `CNPA prototype subset.csv`
- `CNPA prototype feed tracker.csv`
- `CNPA prototype ingestion list.csv`
- `CNPA prototype monitoring spec.csv`
- `airtable_publications_prototype_import.csv`
- `data/generated/content_intake/latest_content_intake.json`
- `data/generated/content_intake/latest_content_intake.csv`
- `data/generated/content_intake/airtable_articles_import.csv`

## Notes

- The repo contains both source code/config and generated editorial-review outputs.
- Timestamped scrape snapshots under `data/generated/content_intake/content_intake_*.json` are local run artifacts and are ignored by Git.
- Temporary Office lockfiles such as `~$CNPA URLS and opinion feeds.xlsx` are ignored by Git.
- The next interoperability step is to keep the PC and MacBook synced through GitHub and regenerate outputs locally on each machine.
