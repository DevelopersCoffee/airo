# v0.0.5 CE / Pro classification

Classification follows [ADR 0013](../adr/0013-airo-tv-open-core-boundary.md).
All entries below are public planning records, not shipped-feature claims.

## Community Edition

| Area | Issues |
| --- | --- |
| Rust/media framework | #874, #875, #899, #900, #901 |
| Local discovery, identity, data, performance | #877, #880, #883, #884, #885 |
| EPG and source-data foundation | #902, #949, #950, #952, #953, #955–#972 except #954 |
| Playback, accessibility, backup | #957, #978, #979, #981 |
| Open CV trackers | #816, #824, #828, #830–#833, #835, #836, #838, #889 |

The range above treats #959–#969 and #971–#972 as CE. It does not include
#951 or #954, which are Pro service/context work.

## Airo TV Pro

| Area | Issues |
| --- | --- |
| Sync and gateways | #876, #879 |
| Intelligence and knowledge | #881, #882, #904–#908 |
| Multi-feed and enriched context | #903, #951, #954, #973 |
| Mixed architecture epic | #898 |
| Deferred CV tracker | #829 |

#898 is classified Pro conservatively because its scope includes the paid Edge
SDK. Its reusable CE architecture children remain individually `non-pro`.

## Claim-state guard

- Open issue: `Planned`.
- Implemented without release/device evidence: `Under qualification`.
- Private implementation with approved disclosure only: `Private validation`
  or customer-facing `In testing`.
- Only a published artifact plus release evidence may be `Available`.
