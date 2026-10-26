# Pathly Data Guide

This directory defines the canonical first version of Pathly's opportunity and place database. The bundled records are JSON because Pathly data contains arrays, optional values, controlled vocabularies, and many-to-many relationships that do not fit cleanly in a primary CSV file.

> **Imported-data warning:** The current snapshot began with the user-provided `pathly_merged_sources_compiled.json` on August 22, 2026, then received a conservative source-verified gap-fill import, a nationwide IMLS library import, an official MLH-season hackathon import, 58 official Scholarship America program listings, and 44 upcoming teen workshops from official San Francisco Public Library event pages. It contains 386 opportunities, 772 places, 267 organizations, and one opportunity-location link. Earlier imported facts and the original search-derived coordinates still require ongoing review.

Never invent deadlines, eligibility rules, costs, locations, recognition levels, or other missing facts. Use an authoritative source and prefer `null`, an empty array where appropriate, or a documented `Unknown` enum value when a fact cannot be verified.

## Directory contents

| File | Purpose |
| --- | --- |
| `opportunities.json` | User-independent competitions, programs, internships, and other discoverable opportunities |
| `places.json` | Physical educational resources intended primarily for the map |
| `organizations.json` | Normalized organizers and owners referenced by opportunities and places |
| `opportunity_locations.json` | Junction records connecting one opportunity to any number of physical places |
| `coordinate_review.json` | Audit trail for coordinates populated from the first Apple MapKit search result; not loaded by the app |
| `missing_location_requests.json` | Exact 441-place worklist for records that still lack usable coordinates |
| `missing_location_requests.csv` | Spreadsheet-friendly export of the missing-location worklist |
| `visual_asset_requests.json` | Every opportunity still missing artwork, with a stable suggested asset name |
| `missing_event_artwork.csv` | Spreadsheet-friendly export of all event-art needs and their priority |
| `missing_organization_logos.json` | Logo status for all 131 organizations attached to opportunities |
| `missing_organization_logos.csv` | Spreadsheet-friendly export of organization-logo status |
| `organization_artwork_sources.json` | Source URL, method, and review status for the 50 collected organization visuals |
| `organization_artwork_sources.csv` | Spreadsheet-friendly export of collected organization visual provenance |
| `artwork_manifest.csv` | User-supplied research for event artwork; referenced local files were not attached |
| `ASSET_AND_LOCATION_NEEDS.md` | Human-readable counts, priorities, place-art mapping, and ImageGen prompt direction |
| `templates/opportunity_template.json` | Copy-ready object containing every opportunity field |
| `templates/place_template.json` | Copy-ready object containing every place field |
| `templates/organization_template.json` | Copy-ready object containing every organization field |

All four dataset files contain JSON arrays. Template files contain one JSON object so it can be copied into a dataset array. IDs ending in `000000` are placeholders and must never be committed as real record IDs.

## Relationships

```text
Organization
    │
    ├──────────────────┐
    ↓                  ↓
Opportunity          Place
    │                  ↑
    └── OpportunityLocation
```

An organization can own many opportunities and many places. An opportunity can connect to multiple places through `OpportunityLocation`; a place can likewise host multiple opportunities. Do not duplicate an opportunity merely because it has several locations.

## Opportunity schema

Swift model: `Models/Opportunity.swift`

| Field | JSON type | Required? | Meaning | Example |
| --- | --- | --- | --- | --- |
| `id` | String | Required | Stable internal ID matching `opp_######` | `opp_000123` |
| `name` | String | Required | Official opportunity name | `Swift Student Challenge` |
| `organization_id` | String or null | Optional | Existing organizer ID when normalized | `org_000042` |
| `image_asset_name` | String or null | Optional | Event artwork name in `Assets.xcassets`; falls back to the organization's logo | `opp_000123_visual` |
| `category` | Enum string | Required | Broad primary category | `Competition` |
| `subcategory` | String or null | Optional | More specific discipline/type | `App Development` |
| `description_short` | String | Required | Concise factual card/list summary | `Create an app playground...` |
| `description_full` | String or null | Optional | Longer factual description | `Participants submit...` |
| `interest_tags` | String array | Required | Controlled interests used for discovery | `["Programming", "Design"]` |
| `required_skills` | String array | Required | Skills explicitly required to participate | `["Swift"]` |
| `recommended_skills` | String array | Required | Helpful but non-mandatory skills | `["UI Design"]` |
| `min_grade` | Integer or null | Optional | Lowest eligible US grade | `6` |
| `max_grade` | Integer or null | Optional | Highest eligible US grade | `12` |
| `min_age` | Integer or null | Optional | Minimum age, when officially stated | `13` |
| `max_age` | Integer or null | Optional | Maximum age, when officially stated | `18` |
| `eligibility_notes` | String or null | Optional | Eligibility facts not captured structurally | `Must reside in...` |
| `team_type` | Enum string or null | Optional | Whether entry is individual, team, or either | `Individual or Team` |
| `min_team_size` | Integer or null | Optional | Smallest allowed team | `1` |
| `max_team_size` | Integer or null | Optional | Largest allowed team | `4` |
| `format` | Enum string | Required | Delivery/attendance format | `Hybrid` |
| `geographic_scope` | Enum string | Required | Geographic reach of the opportunity | `National` |
| `eligible_states` | String array | Required | USPS codes or the single value `ALL` | `["DE", "MD", "PA"]` |
| `eligible_countries` | String array | Required | Uppercase ISO two-letter country codes | `["US"]` |
| `online_available` | Boolean | Required | Whether participation is available online | `true` |
| `travel_required` | Boolean | Required | Whether participation requires travel | `false` |
| `cost_usd` | Number or null | Optional | Verified participant cost in US dollars | `0` |
| `financial_aid` | Boolean or null | Optional | Whether financial aid is confirmed available | `true` |
| `prize_value` | String or null | Optional | Factual award description, including ranges or non-cash awards | `Up to $5,000` |
| `application_open` | Date string or null | Optional | Date applications open | `2026-08-01` |
| `deadline` | Date string or null | Optional | Application/submission deadline | `2026-09-15` |
| `event_start` | Date string or null | Optional | Event/program start date | `2026-10-10` |
| `event_end` | Date string or null | Optional | Event/program end date | `2026-10-12` |
| `recurring` | Enum string | Required | Recurrence pattern | `Annual` |
| `recognition_level` | Enum string or null | Optional | Objective external-recognition tier | `High` |
| `selectivity_level` | Enum string | Required | How selective admission/advancement is | `Competitive` |
| `difficulty_level` | Enum string | Required | Expected participant challenge | `Intermediate` |
| `official_url` | URL string | Required | Official opportunity information page | `https://example.org/program` |
| `application_url` | URL string or null | Optional | Direct official application page | `https://example.org/apply` |
| `source_url` | URL string | Required | Authoritative page used for verification | `https://example.org/rules` |
| `last_verified` | Date string | Required | Most recent date facts were checked | `2026-08-21` |
| `status` | Enum string | Required | Current lifecycle status | `Open` |

Grades are numeric US K–12 grade levels. Do not invent a number for college-only eligibility; leave grade bounds `null` and explain the verified education-level requirement in `eligibility_notes` until a dedicated education-level field is added.

`cost_usd` remains numeric for filtering. `prize_value` is descriptive because real programs may offer ranges, multiple award tiers, travel, equipment, or other value that cannot be represented accurately by one number.

### Dates and deadlines

All dates use strict `YYYY-MM-DD` values. Do not use one generic date field, localized strings such as `10/12/26`, or a time value in these fields.

```json
{
  "application_open": "2026-08-01",
  "deadline": "2026-09-15",
  "event_start": "2026-10-10",
  "event_end": "2026-10-12"
}
```

Dates may be `null` when the official source has not announced them. Never copy a prior year's deadline into a current record unless the official source explicitly confirms it.

## Place schema

Swift model: `Models/Place.swift`

| Field | JSON type | Required? | Meaning | Example |
| --- | --- | --- | --- | --- |
| `id` | String | Required | Stable internal ID matching `place_######` | `place_000245` |
| `name` | String | Required | Official place/resource name | `Central Library` |
| `organization_id` | String or null | Optional | Existing owner/operator ID | `org_000031` |
| `image_asset_name` | String or null | Optional | Place-specific photo/artwork name in `Assets.xcassets`; otherwise the UI uses place-category artwork | `place_000245_visual` |
| `place_type` | Enum string | Required | Controlled physical resource type | `Makerspace` |
| `description` | String or null | Optional | Concise factual description | `Public fabrication lab...` |
| `address` | String or null | Optional | Street address | `123 Main Street` |
| `city` | String or null | Optional | City/locality | `Wilmington` |
| `state` | String or null | Conditional | USPS code for US places; region code where applicable | `DE` |
| `zip` | String or null | Optional | Postal code stored as text | `19801` |
| `country` | String | Required | Uppercase ISO two-letter country code | `US` |
| `latitude` | Number or null | Optional | WGS84 latitude from -90 through 90 | `39.7447` |
| `longitude` | Number or null | Optional | WGS84 longitude from -180 through 180 | `-75.5484` |
| `website` | URL string or null | Optional | Official place page | `https://example.org` |
| `phone` | String or null | Optional | Official public contact number | `+1-302-555-0100` |
| `free_access` | Boolean or null | Optional | Whether access is confirmed free | `true` |
| `membership_required` | Boolean or null | Optional | Whether membership is required | `false` |
| `resource_tags` | String array | Required | Physical services/equipment | `["3D Printers", "Laser Cutter"]` |
| `interest_tags` | String array | Required | Controlled interest taxonomy values | `["Engineering", "Design"]` |
| `verified` | Boolean | Required | Whether the record has been checked against an official source | `true` |
| `last_verified` | Date string | Required | Most recent verification date | `2026-08-21` |
| `status` | Enum string | Required | Current operating status | `Active` |

US places should use a USPS state code. Coordinates, when present, must be numeric JSON values and never quoted strings.

### Coordinate review

The August 22 import originally contained no coordinates. Pathly searched each place using its name, address, city, and state, then wrote 235 first-result Apple MapKit coordinates. It rejected 21 obvious state mismatches and retained 421 no-result records without coordinates. On August 23, Pathly added 96 public-library outlets with coordinates from the official IMLS FY2024 Public Libraries Survey. The app now has 331 pins; the original 235 MapKit results remain separate from the IMLS-sourced coordinates in the audit trail.

`coordinate_review.json` records the exact query, expected state, returned name/address, coordinates, match confidence, and `Needs Review`, `No Result`, or `Rejected: State Mismatch` status for every place. Review that file before treating any pin as authoritative. The place-level `verified` flag came from the supplied dataset and does not imply that its newly searched coordinate was verified.

`missing_location_requests.json` is the actionable subset: 441 places still lack coordinates, comprising 420 searches with no result and 21 rejected state mismatches. It preserves the submitted location and search evidence needed for manual research.

### Nationwide library coverage

Pathly now contains 100 library records—at least two in every U.S. state. Ninety-six were selected from the Institute of Museum and Library Services FY2024 Public Libraries Survey public-use outlet file. The official dataset supplies outlet identity, address, phone, and coordinates. Pathly intentionally leaves website, free-access, membership, age-restriction, and interest fields unknown when the survey does not provide them.

The reproducible import is `Scripts/import_imls_libraries.py`; `Research/LibraryExpansion/selected_libraries.json` preserves each Pathly ID, IMLS `FSCSKEY`, outlet ID, and source URL.

### Hackathon coverage

Pathly now contains 53 Hackathon records. Fifty upcoming events were imported from Major League Hacking's official 2027-season listing on August 23, 2026. Their names, dates, formats, locations, official event URLs, and MLH-supplied artwork URLs are preserved in `Research/HackathonExpansion/mlh_import_manifest.json`.

The season listing does not consistently state age eligibility, price, registration deadline, team size, or eligible geography. Those fields remain unknown; the records explicitly direct students to confirm organizer-specific rules. The HTTP audit reached 49 of 50 official event sites; UofTHacks returned HTTP 403 to automated access but remains linked by the official MLH listing.

### Scholarship America import

Pathly now contains 60 Scholarship records. Fifty-five high-school-relevant programs were imported on August 24, 2026 from Scholarship America's official public program API and listing pages. `Scripts/import_scholarshipamerica_scholarships.py` is idempotent and preserves the official program title, eligibility text, award amount, application window, application state, and official URL where published.

`Research/ScholarshipExpansion/scholarshipamerica_import_manifest.json` maps every new stable Pathly ID to its Scholarship America post ID and official page. `source_snapshot.json` records source counts and the import-quality policy. The imported snapshot contains six officially Open records, three records with published future opening dates, and 46 Closed cycles. Closed cycles keep their actual 2026 dates and must be reverified before their status changes; the importer does not assume an annual recurrence or shift old dates forward.

Some Scholarship America programs are restricted to employees' dependents, specific schools, counties, fields, or other sponsor-defined populations. Those are valid catalog records only because the full official eligibility text is retained. Recommendation eligibility may remain potential when Pathly's schema cannot deterministically represent every restriction, and students must confirm the official page before applying.

## Organization schema

Swift model: `Models/Organization.swift`

| Field | JSON type | Required? | Meaning | Example |
| --- | --- | --- | --- | --- |
| `id` | String | Required | Stable internal ID matching `org_######` | `org_000042` |
| `name` | String | Required | Official organization name | `Apple` |
| `organization_type` | Enum string | Required | Controlled organization classification | `Company` |
| `logo_asset_name` | String or null | Optional | Reusable organization logo name in `Assets.xcassets` | `org_000042_logo` |
| `website` | URL string or null | Optional | Official organization website | `https://www.apple.com` |
| `country` | String | Required | Headquarters/home uppercase ISO country code | `US` |
| `description` | String or null | Optional | Concise factual organization description | `Technology company...` |
| `verified` | Boolean | Required | Whether identity/details were checked | `true` |

Store organization facts once and reference them by ID. For example, an opportunity named Swift Student Challenge should reference Apple's organization record rather than repeating Apple details inside the opportunity.

## Visual assets

Explore resolves opportunity artwork in this order:

1. Opportunity `image_asset_name`
2. Referenced organization `logo_asset_name`
3. A category SF Symbol placeholder

Place artwork resolves separately:

1. Place-specific `image_asset_name`
2. A reusable generated illustration for its controlled `place_type`
3. A place-type SF Symbol fallback

All 386 imported opportunities currently have `image_asset_name = null`. `visual_asset_requests.json` is the complete machine-readable checklist and suggests stable event names such as `opp_000001_visual` plus organization-logo names such as `org_000056_logo`. Add the image to `Assets.xcassets` using that name, then copy the same value into the opportunity's `image_asset_name` or organization's `logo_asset_name`. An official event graphic is preferred; when none exists, add one reusable organization logo instead of duplicating it.

Fifty organization visuals are now installed and cover 93 linked opportunities. Eighty-one opportunity-facing organizations remain without logos, while 293 opportunities still have no event image or organization-logo fallback. `missing_organization_logos.json` tracks all 131 opportunity-facing organization statuses. Place-only library organizations remain excluded because place cards use the ten generated category illustrations documented in `ASSET_AND_LOCATION_NEEDS.md`.

Prototype organization artwork must remain auditable. `organization_artwork_sources.json` records the source for every collected visual. Assets marked `review_required = true` came from a favicon mirror or cached fallback and should be replaced with an official brand asset before distribution. Never invent or use ImageGen to imitate a real organization's logo.

## Opportunity-location schema

Swift model: `Models/OpportunityLocation.swift`

| Field | JSON type | Required? | Meaning | Example |
| --- | --- | --- | --- | --- |
| `opportunity_id` | String | Required | Existing opportunity ID | `opp_000123` |
| `place_id` | String | Required | Existing place ID | `place_000245` |

The pair must be unique. Add one relationship object per location; never clone the opportunity record.

## Controlled vocabularies

The canonical Swift definitions live in `Models/PathlyEnums.swift`. JSON values are case- and punctuation-sensitive. An unrecognized value intentionally causes decoding to fail so errors are found before inconsistent data reaches the app.

| Vocabulary | Allowed values |
| --- | --- |
| Opportunity category | Competition; Hackathon; Research; Internship; Scholarship; Program; Camp; Workshop; Event; Volunteering; Leadership; Club; Fellowship; Grant |
| Place type | Library; Makerspace; Fab Lab; Museum; Science Center; University; Robotics Club; Community Center; Hackerspace; Observatory; Innovation Lab; Youth Center |
| Interest | Computer Science; Programming; Artificial Intelligence; Cybersecurity; Robotics; Engineering; Electronics; Science; Biology; Chemistry; Physics; Medicine; Mathematics; Space; Environment; Business; Entrepreneurship; Finance; Economics; Writing; Journalism; Art; Design; Music; Film; Game Development; Public Policy; Debate; Community Service |
| Format | Online; In-Person; Hybrid |
| Geographic scope | Local; County; Congressional District; State; Regional; National; International; Anywhere |
| Opportunity status | Open; Upcoming; Closed; Expired; Unknown |
| Place status | Active; Temporarily Closed; Closed; Unknown |
| Recognition | Local; Regional; State; Strong; High; Exceptional |
| Selectivity | Open; Competitive; Selective; Highly Selective; Unknown |
| Difficulty | Beginner; Intermediate; Advanced; Expert; Unknown |
| Team type | Individual; Team; Individual or Team |
| Recurrence | One-Time; Annual; Seasonal; Monthly; Recurring; Unknown |
| Organization type | Company; Nonprofit; Government; University; School; Library; Foundation; Community Organization; Professional Organization; Other |

Primary categories remain broad. A robotics contest is `category = Competition` and `subcategory = Robotics`, not a new `Robotics Competition` category. Extend a vocabulary by updating both `PathlyEnums.swift` and this table in the same change.

### Recognition is not an admissions score

`recognition_level` is not “good for Harvard,” a college-admissions score, a quality judgment, or a promise of student outcomes. It may eventually summarize objective signals such as geographic scope, organizer, judged submission, selectivity, participant count, advancement structure, award level, and external validation. There is no recognition algorithm yet. Leave the field `null` rather than guessing.

### User-specific matching does not belong in records

Never add fields such as `match`, `skill_match`, or `excellent_match` to an opportunity. Pathly will calculate those later by comparing a user profile with stable opportunity facts: interests, skills, grade, age, eligibility, location, travel distance, cost preference, format preference, and category preference. The same opportunity may be an excellent skill match for one student and a stretch opportunity for another.

## State and online handling

All states remain in the same national dataset. Do not create separate files or databases per state.

Use a single `ALL` value for nationwide US eligibility:

```json
"eligible_states": ["ALL"]
```

Use uppercase two-letter USPS abbreviations for limited eligibility:

```json
"eligible_states": ["DE", "MD", "PA"]
```

Do not combine `ALL` with individual state codes. Online describes delivery format, not eligibility. This is valid:

```json
{
  "format": "Online",
  "eligible_states": ["DE"],
  "eligible_countries": ["US"]
}
```

An online listing does not automatically become national or international.

## Stable ID convention

- Opportunities: `opp_000001`, `opp_000002`, ...
- Places: `place_000001`, `place_000002`, ...
- Organizations: `org_000001`, `org_000002`, ...

IDs are permanent database identities, not display names. Never derive them from a human-readable name, change them when a name changes, recycle an ID from a deleted record, or renumber existing records to close gaps.

## Adding an opportunity

1. Find the official organization, government, university, library, or program source.
2. Search `opportunities.json` for the name, URL, organizer, and likely aliases to prevent duplicates.
3. Assign the next unused stable `opp_######` ID.
4. Find the organizer in `organizations.json`; add and verify it first if it exists. Use `null` temporarily when the supplied source does not identify a normalized organizer—never invent one.
5. Copy `templates/opportunity_template.json` into the dataset array and replace the placeholder ID.
6. Fill every required field and use only controlled category/enum values.
7. Record only eligibility, grade, age, team, cost, and travel rules stated by an authoritative source.
8. Add controlled interest tags and factual free-text skill tags; distinguish required from merely recommended skills.
9. Add the four dates independently using `YYYY-MM-DD`; keep unannounced dates `null`.
10. Add the official, application, and authoritative source URLs.
11. Set `last_verified` to the date the source was actually checked and assign the evidence-supported status.
12. Add `opportunity_locations.json` links for each physical venue without duplicating the opportunity.
13. Add official artwork using `image_asset_name`, or connect a reusable organization logo.
14. Validate JSON syntax, build the app, and resolve every DataStore error before submitting the record.

## Adding a place

1. Find the official place or owner page and check that the place is not already present.
2. Assign the next unused stable `place_######` ID.
3. Find or create the owner/operator organization when it is known.
4. Copy `templates/place_template.json` and replace every placeholder value.
5. Choose the canonical `place_type` and interest tags.
6. Verify the public address, numeric coordinates, access/membership rules, age restrictions, website, and phone.
7. Use a USPS state abbreviation for US places and an uppercase ISO country code.
8. Set `verified`, `last_verified`, and `status` from current evidence.
9. Link opportunities through `opportunity_locations.json`; never embed or duplicate full opportunity data in a place.
10. Validate JSON syntax, build the app, and resolve every DataStore error.

## Data-quality rules

- Never invent missing information. Prefer `null`, an empty array where semantically appropriate, or `Unknown` when that enum supports it.
- Prefer official and authoritative sources. Aggregator pages can help discovery but should not override official facts.
- Never guess deadlines or eligibility requirements.
- Do not duplicate organizations, opportunities, places, or opportunity-place pairs.
- Keep spelling, capitalization, punctuation, and enum values consistent.
- Keep every date in strict `YYYY-MM-DD` format.
- Update `last_verified` every time an opportunity or place is genuinely checked.
- Do not mark `verified` true merely because a record contains plausible information.
- Do not store user-specific match ratings in the dataset.
- Do not create state-specific dataset files.
- Do not use empty strings for unknown optional values; use `null`.
- Keep skills factual and consistently named. Skills remain strings so the vocabulary can evolve before a dedicated skill taxonomy is finalized.

## Loading and validation

`Services/DataStore.swift` defines a `PathlyDataSource` boundary, a `BundledJSONDataSource`, and the observable `DataStore`. At app launch the store:

1. Finds all four JSON resources in the application bundle.
2. Decodes them with strict `YYYY-MM-DD` date handling.
3. Publishes the four typed arrays for future views/repositories.
4. Runs lightweight relationship and record validation.
5. Publishes `validationIssues` or `loadErrorDescription` and prints detailed development diagnostics in Debug builds.

The validator checks duplicate and malformed IDs, missing relationships, missing names, grade/age/team ranges, HTTP(S) URLs, application/event date order, state/country codes, latitude/longitude, and duplicate junction pairs. Codable enum decoding catches unrecognized controlled values, while strict date decoding catches malformed dates.

Views should consume models through `DataStore` or a future repository, never open JSON files directly. A future Firebase, Supabase, CloudKit, REST, remote-JSON, or other backend can implement `PathlyDataSource` and replace the bundled source without changing the model consumers.

## Scale and migration notes

The current source decodes each dataset into memory, which is intentionally simple and suitable for the initial bundled catalog. The normalized IDs and data-source boundary are designed for eventual migration to 10,000+ opportunities, 10,000+ places, and thousands of organizations. Before that scale causes launch-time or bundle-size pressure, move loading behind an asynchronous indexed repository/backend while retaining stable IDs and the canonical field meanings defined here.
