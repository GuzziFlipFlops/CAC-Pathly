# Asset and Location Needs

Updated August 24, 2026 from the current bundled datasets.

## Location work

- **441 places still need valid coordinates.** The complete list is available as `missing_location_requests.json` and the spreadsheet-friendly `missing_location_requests.csv`.
- 421 returned no Apple MapKit search result.
- 21 returned a result in the wrong state and were rejected.
- Of the 331 places with coordinates, 235 came from the earlier MapKit lookup and remain in `coordinate_review.json`; 96 new library coordinates come from the official IMLS FY2024 outlet dataset.

Each missing-location entry includes the stable place ID, name, category, submitted address/city/state/ZIP, official website, previous query, and any rejected match. Update `places.json` only after choosing the intended physical site.

## Organization and event artwork

- **50 of 131 opportunity-facing organizations now have prototype logos/icons.** They provide a visual fallback for 93 opportunities.
- **81 opportunity-facing organizations still need a logo.** The current status, official websites, coverage counts, and stable asset names are in `missing_organization_logos.json` and `missing_organization_logos.csv`.
- **386 opportunities currently have no event-specific artwork.** The exact list is in `visual_asset_requests.json` and `missing_event_artwork.csv`.
- Of those opportunities, **108 have no organization relationship**, so they cannot inherit an organization logo and need individual event artwork first.
- After the 50-logo pass, **293 opportunities still have neither event artwork nor an organization-logo fallback**. The other 93 can use a relevant organization logo initially. The 58 Scholarship America imports can share one official Scholarship America logo when an approved asset is supplied.

`organization_artwork_sources.json` and `.csv` record the source page, direct image URL, collection method, and review status for each of the 50 prototype organization assets. Thirty-seven came directly from organization-owned site metadata or page images. Thirteen are favicon-mirror fallbacks and must be replaced or explicitly approved before release.

The user-supplied `artwork_manifest.csv` contains source research for 26 event images, but the referenced `artwork/...` files were not included. Treat those rows as download/review leads, not bundled artwork.

Use official organization logos and official event artwork when possible. Do not generate imitations of real logos. Suggested asset names are stable: `org_######_logo` and `opp_######_visual`.

## Place category artwork

Place cards do not request organization logos. They first use an optional place-specific `image_asset_name`, then one of these generated category illustrations:

| Current place category | Asset |
| --- | --- |
| Library | `PlaceLibrary` |
| Makerspace | `PlaceMakerspace` |
| Fab Lab | `PlaceFabLab` |
| Hackerspace | `PlaceHackerspace` |
| Innovation Lab | `PlaceInnovationLab` |
| Museum | `PlaceMuseum` |
| Robotics Club | `PlaceRoboticsClub` |
| Science Center | `PlaceScienceCenter` |
| University | `PlaceUniversity` |
| Youth Center | `PlaceYouthCenter` |

The currently unused Observatory type shares `PlaceScienceCenter`, and Community Center shares `PlaceYouthCenter` until either category enters the dataset and needs its own artwork.

## Image generation prompt set

The original detailed 3D place scenes were replaced on August 22 because they were too busy at card size. The current images were created with OpenAI ImageGen in **generation** mode using this shared prompt direction:

> Create a square minimalist flat editorial illustration for a 70-point Pathly iOS place-category thumbnail. Use one large, instantly recognizable category subject with bold simple geometry and generous negative space. Use a warm off-white or pale blue-gray background, deep navy main shape, white secondary shape, and only one small cyan path-and-star accent. Avoid people, text, brands, detailed interiors, photorealism, glossy 3D rendering, neon glow, mostly-blue imagery, busy backgrounds, gradients, and tiny objects.

The category-specific subjects are: an open book and shelf; workbench, wrench, and cube; fabrication machine and panel; terminal and circuit trace; lightbulb and prototype cube; museum columns; robot head and gear; atom and flask; university arch; and a welcoming youth-center doorway.
