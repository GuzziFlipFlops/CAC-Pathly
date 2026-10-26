# Contributing to the Pathly Open Catalog

Thanks for helping students find real opportunities. The one rule that matters most:

> **Never invent a fact.** Every deadline, eligibility rule, cost, location, or date must come from an official source. If you can't verify something, leave it `null`.

## Two ways to help

### 1. Report a problem (no coding)

[Open an issue](https://github.com/{{OWNER}}/{{REPO}}/issues/new/choose) and choose:

- **Fix a record**: something is wrong or out of date. Include the record ID (like `opp_000094`) and the official link that shows the correct information.
- **Add an opportunity**: something students should know about is missing. Include its official page.

### 2. Edit the data (pull request)

1. Fork this repository.
2. Edit the file in `v1/`:
   - `opportunities.json`: competitions, programs, scholarships, and other things students can apply to or attend
   - `places.json`: libraries, makerspaces, museums, and other physical resources
   - `organizations.json`: the organizers and owners referenced by the records above
   - `opportunity_locations.json`: links between an opportunity and the places where it happens
3. For a new record, copy the matching file from `templates/` and use the next unused ID (see below).
4. Update `last_verified` to today's date (`YYYY-MM-DD`) on every record you checked, and set `source_url` to the page you used.
5. Open a pull request. The **Validate catalog** check runs automatically and must pass.

### Run the check yourself (macOS)

```bash
xcrun swiftc -o /tmp/validate validator/*.swift && /tmp/validate v1
```

It decodes every record with the same models the Pathly app uses and checks IDs, links between records, value ranges, URLs, dates, state codes, and coordinates.

## Rules for records

- **IDs** are `opp_`, `place_`, or `org_` followed by six digits. Use the next number after the highest existing ID. Never reuse or renumber an ID. IDs ending in `000000` are template placeholders.
- **Don't delete records.** If an opportunity ends, set `status` to `Closed` or `Expired`. If a place closes, set its `status` to `Closed`.
- **Don't duplicate.** One opportunity held at several places is one opportunity record with several `opportunity_locations` links.
- **Use the allowed values** for categories, formats, statuses, and other controlled fields. They're listed in [SCHEMA.md](SCHEMA.md).
- **States** are two-letter USPS codes, or `["ALL"]` for nationwide. Countries are ISO codes like `US`.
- **Dates** are `YYYY-MM-DD`. If only the month is known, leave the date `null` and put the detail in `eligibility_notes` or `description_full`.
- **Descriptions** should be short, factual, and in your own words. Don't paste marketing text.
- **Coordinates** must be for the actual building, from an authoritative source.
- Don't add personal information about students, teachers, or staff.

## Review

A maintainer checks the source link for every change. Pull requests that pass validation and cite an official source are usually merged quickly. Changes are published to the API within a few minutes of merging.
