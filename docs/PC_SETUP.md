# PC Setup

## Goal

Make this Windows clone usable for continued COP prototype work.

## Required Tools

1. Git
2. Ruby

## Run Order

After Ruby is installed, run these from the project root:

```powershell
ruby .\build_cnpa_urls.rb
ruby .\build_prototype_subset.rb
ruby .\build_prototype_feed_tracker.rb
ruby .\build_prototype_ingestion_list.rb
ruby .\build_monitoring_spec.rb
ruby .\build_airtable_publications_import.rb
```

## Expected Outputs

- `CNPA URLS and opinion feeds.csv`
- `CNPA prototype subset.csv`
- `CNPA prototype feed tracker.csv`
- `CNPA prototype ingestion list.csv`
- `CNPA prototype monitoring spec.csv`
- `airtable_publications_prototype_import.csv`

## Notes

- A deeper folder reorganization was attempted, but Windows/OneDrive denied the file moves.
- Temporary Office lockfiles such as `~$CNPA URLS and opinion feeds.xlsx` are now ignored by Git.
