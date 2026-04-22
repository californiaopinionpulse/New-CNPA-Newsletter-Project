# COP Prototype

California Opinion Pulse is a prototype workspace for a weekly CNPA opinion newsletter.

## What Is Here

- `cnpa-newsletter-prototype.html`: the visual newsletter mockup
- `CNPA prototype rollout.md` and `CNPA weekly workflow plan.md`: editorial and automation planning
- `build_*.rb`: Ruby scripts that generate prototype CSV outputs
- `CNPA prototype *.csv` and `airtable_publications_prototype_import.csv`: generated planning outputs

## Current Status

This is a prototype and research workspace, not a production application yet.

The core pieces already in place are:

- the HTML issue prototype
- source-selection and ingestion-planning docs
- a CSV generation pipeline for prototype source tracking
- a cross-platform Ruby build path for Windows and macOS
- a scraping pipeline that produces a normalized article-intake file
- an Airtable-ready articles import CSV for editorial review

## Current Workflow

From the project root:

```powershell
.\run_pipeline.ps1
ruby .\scripts\scrape_cnpa_content.rb
ruby .\scripts\build_airtable_articles_import.rb
```

Key current outputs:

- `CNPA URLS and opinion feeds.csv`
- `CNPA prototype subset.csv`
- `CNPA prototype feed tracker.csv`
- `CNPA prototype ingestion list.csv`
- `CNPA prototype monitoring spec.csv`
- `airtable_publications_prototype_import.csv`
- `data/generated/content_intake/latest_content_intake.json`
- `data/generated/content_intake/airtable_articles_import.csv`

## Windows Notes

This PC is now usable for project work:

- `git` works in PowerShell
- `ruby` works in PowerShell
- the build and scraping scripts run locally

See [PROJECT_STATUS.md](./docs/PROJECT_STATUS.md), [PC_SETUP.md](./docs/PC_SETUP.md), and [SCRAPING_WORKFLOW.md](./docs/SCRAPING_WORKFLOW.md) for the current handoff state.
