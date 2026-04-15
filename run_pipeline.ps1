param()

$ErrorActionPreference = "Stop"

$scripts = @(
  "build_cnpa_urls.rb",
  "build_prototype_subset.rb",
  "build_prototype_feed_tracker.rb",
  "build_prototype_ingestion_list.rb",
  "build_monitoring_spec.rb",
  "build_airtable_publications_import.rb"
)

foreach ($script in $scripts) {
  Write-Host "Running $script..."
  ruby ".\$script"
}

Write-Host "Pipeline complete."
