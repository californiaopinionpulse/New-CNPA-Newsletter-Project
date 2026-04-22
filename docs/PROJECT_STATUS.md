# Project Status

## What This Project Is

`COP Prototype` is a planning-and-prototype workspace for a CNPA weekly opinion newsletter.

It already includes:

- a polished HTML email mockup
- a curated California publication/source list
- prototype ingestion tiers and monitoring specs
- Airtable-oriented CSV outputs
- a working scraping/intake layer for current opinion content
- an Airtable-ready article import export

## What Appears Done

- visual direction for the newsletter prototype
- initial weekly workflow design
- first-pass source mapping and output generation
- Windows Ruby/Git setup
- cross-platform Ruby build compatibility
- current-content scraping and Airtable import generation

## What Is Not Yet Built

- automated issue generation
- production sending workflow
- full source coverage for every targeted publication
- finalized pause/review policy for weak sources

## Current Working State

Current baseline:

- `git` works in PowerShell
- `ruby` works in PowerShell
- the build pipeline runs locally
- the scraper runs locally
- the Airtable article import builds locally
- the active source set is cross-platform oriented

Recent scraper baseline:

- 19 active sources
- current-content intake constrained to the previous 4 weeks
- unknown publish dates reduced to 0 in the current Airtable import
- paused/blocked candidates can be excluded from default runs while remaining in source config for later review

## Next Step

Clean up and commit the current Windows-side interoperability changes, then mirror this repo state onto the MacBook via GitHub.
