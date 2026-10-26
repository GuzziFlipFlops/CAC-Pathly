# Pathly Open Catalog

A free, open database of opportunities for middle- and high-school students: competitions, science fairs, hackathons, scholarships, research programs, workshops, and the libraries, makerspaces, and labs where students can do the work.

It's the data behind the Pathly iOS app, published so anyone can use it and anyone can help keep it accurate.

| | |
|---|---|
| Opportunities | {{OPPORTUNITIES}} |
| Places | {{PLACES}} |
| Organizations | {{ORGANIZATIONS}} |
| Version | `{{VERSION}}` |

## Use the API

The catalog is a static JSON API served by GitHub Pages. No key, no sign-up, no rate limit beyond GitHub's.

```text
https://{{OWNER}}.github.io/{{REPO}}/v1/index.json
https://{{OWNER}}.github.io/{{REPO}}/v1/opportunities.json
https://{{OWNER}}.github.io/{{REPO}}/v1/places.json
https://{{OWNER}}.github.io/{{REPO}}/v1/organizations.json
https://{{OWNER}}.github.io/{{REPO}}/v1/opportunity_locations.json
```

The same files are also mirrored for free by the jsDelivr CDN:

```text
https://cdn.jsdelivr.net/gh/{{OWNER}}/{{REPO}}@main/v1/opportunities.json
```

Fetch every competition open to Delaware students:

```bash
curl -s https://{{OWNER}}.github.io/{{REPO}}/v1/opportunities.json \
  | jq '[.[] | select(.category == "Competition" and (.eligible_states | index("DE") or index("ALL")))] | length'
```

From JavaScript:

```js
const res = await fetch("https://{{OWNER}}.github.io/{{REPO}}/v1/opportunities.json");
const opportunities = await res.json();
```

`v1/index.json` lists the record counts, the version, and the date of the last update. Field definitions, allowed values, and ID rules are in [SCHEMA.md](SCHEMA.md).

### What `v1` promises

- Field names and meanings in `v1` won't change. New optional fields may be added.
- Record IDs (`opp_000094`, `place_000051`, …) are permanent. A record that ends is marked `Closed` or `Expired`, not deleted.
- Unknown facts are `null`, never guessed.

## Help fix it

Deadlines move and programs change every year. If something is wrong or missing:

- **Report it:** [open an issue](https://github.com/{{OWNER}}/{{REPO}}/issues/new/choose). Pick "Fix a record" or "Add an opportunity" and include an official source link.
- **Fix it yourself:** edit the JSON in `v1/` and open a pull request. Every pull request is checked automatically by the same validator the app uses. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Good to know

- Records are facts copied from official sources, with a `source_url` and a `last_verified` date. Always confirm deadlines and eligibility on the official page before relying on them.
- `image_asset_name` and `logo_asset_name` refer to artwork inside the Pathly app. The artwork itself isn't part of this catalog.
- Eligibility fields describe the opportunity, not any one student. Matching students to opportunities happens in apps that use the data.

## License

The catalog is licensed under [CC BY 4.0](LICENSE). You can use it in your own projects, including commercial ones, as long as you credit "Pathly Open Catalog" with a link to this repository. Names, logos, and trademarks of the listed organizations belong to those organizations.
