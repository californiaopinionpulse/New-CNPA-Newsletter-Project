**Prototype Assets**

- Newsletter mockup: [cnpa-newsletter-prototype.html](./cnpa-newsletter-prototype.html)
- Source matching sheet: [CNPA URLS and opinion feeds.xlsx](./CNPA%20URLS%20and%20opinion%20feeds.xlsx)
- Feed tracker: [CNPA prototype feed tracker.csv](./CNPA%20prototype%20feed%20tracker.csv)
- Ingestion plan: [CNPA prototype ingestion list.csv](./CNPA%20prototype%20ingestion%20list.csv)
- Monitoring spec: [CNPA prototype monitoring spec.csv](./CNPA%20prototype%20monitoring%20spec.csv)

**Suggested Subject Line**

What California communities are saying this week

Backup options:
- Capitol Opinion Watch: Voices from around California
- This week in California opinion
- What local editorial pages are telling Sacramento

**Newsletter Name Ideas**

1. Capitol Opinion Watch
2. California Voices
3. The Statehouse Pulse
4. Voices from Main Street
5. Opinion Across California
6. The California Editorial Brief
7. Golden State Voices
8. The Community Opinion Report
9. The Sacramento Listening Post
10. What Californians Are Saying

**Recommended Prototype Workflow**

1. Use Feedly for `Tier 1` RSS sources.
2. Use a page monitor, scraper, or custom checker for `Tier 2` sources.
3. Keep `Tier 3` sources in a short editorial review queue until their opinion paths are confirmed.
4. Exclude `Tier 4` sources from the first automated build.

**Simple Tech Stack**

- Feedly:
  Use for direct RSS ingestion.
- Zapier or Make:
  Trigger when a new RSS item or new page item appears.
- Airtable or Google Sheets:
  Store raw article metadata before formatting.
- OpenAI:
  Generate the issue intro, article summaries, tags, and subject line.
- Mailchimp, Beehiiv, or a custom HTML email:
  Render and distribute the final issue.

**Suggested Data Fields**

- `title`
- `author`
- `publication`
- `publication_date`
- `article_url`
- `source_type`
- `topic_tag`
- `summary`
- `issue_date`
- `region`

**Best First Automation Scope**

Start with:
- `Los Angeles Times`
- `The Sacramento Bee`
- `San Francisco Chronicle`
- `The Fresno Bee`
- `The Modesto Bee`
- `The Press Democrat`
- `Voice of OC`
- `A News Café`
- `Black Voice News`
- `Wind Newspaper`
- `Comstock's Magazine`
- `The Business Journal`

This set is broad enough to feel statewide, but small enough to prototype quickly.

**Recommended Next Step**

Create a single prototype issue using sample content from 8-12 of the strongest sources first. Once the newsletter layout and tone feel right, wire in the automation for the `Tier 1` and `Tier 2` sources.
