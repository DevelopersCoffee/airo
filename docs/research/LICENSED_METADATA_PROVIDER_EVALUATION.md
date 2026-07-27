# Licensed metadata and sports provider evaluation

- Date checked: 2026-07-27
- Issue: #973
- Decision: none approved for production activation
- Review owners: Product, Open Source, Security

This is an engineering evaluation, not legal advice. A provider may be enabled
only after the named owners record a written commercial-use decision against
the then-current terms.

## Programme metadata

| Provider | Current evidence | Coverage/API fit | Decision |
|---|---|---|---|
| TMDB | The [official FAQ](https://developer.themoviedb.org/docs/faq) limits the free developer API to non-commercial use and requires its approved logo plus a non-endorsement notice. The [API terms](https://www.themoviedb.org/api-terms-of-use) require a written agreement for commercial use, limit caching, and prohibit use with an ML/AI-based application. | Strong general TV search, synopsis, poster, and external-ID APIs; no evidence that text-title matching is a licensed linear-EPG join for Airo. | Not approved. Seek a written commercial/AI-use agreement before any prototype uses live data. |
| TheTVDB | [API licensing](https://thetvdb.com/api-information) supports commercial projects, publishes revenue-based tiers, and normally requires linked attribution. Its [terms](https://thetvdb.com/tos) say the API license does not itself authorize display of associated images/trailers/programming. | Strong TV metadata and API; project key/license and separate image-rights analysis required. | Candidate for text metadata only after a project-specific license and image decision. |
| TVmaze | The [public API](https://www.tvmaze.com/api) is CC BY-SA with attribution and ShareAlike. [Paid plans](https://www.tvmaze.com/api/plans) offer CC BY or custom licenses at published/commercial tiers. | Clean TV/show/episode API. Indian linear-channel/EPG match coverage is unproven. | Free tier not approved because downstream ShareAlike scope is unresolved. Paid/custom tier remains a candidate. |
| TiVo / Gracenote | TiVo’s official [package summary](https://business.tivo.com/content/dam/tivo/business/global/pdfs/2024/TiVo-Video-Metadata-Package-Details_March%202023.pdf) describes licensed linear schedules, sports listings, imagery, and deeper metadata. Gracenote’s [GVD guide](https://documentation.gracenote.com/gvd/html/Content/gvd-schema-docs/gvd-dev-guide.pdf) documents India schedule coverage. | Best linear-TV and India fit of the evaluated providers; commercial sales integration and cost are not public. | Preferred enterprise discovery candidate; no activation before quote, permitted-field list, retention, attribution, and redistribution terms are signed. |

## Sports fixtures/results

| Provider | Current evidence | Decision |
|---|---|---|
| TheSportsDB | Official [terms](https://www.thesportsdb.com/docs_terms_of_use.php) require a paid subscriber for app-store publication, attribution for paid API data, and separate permission for third-party content. [Documentation](https://www.thesportsdb.com/documentation) publishes endpoint/rate-limit differences. | Candidate for an internal fixtures-only evaluation after confirming the paid tier covers Airo distribution, leagues/territories, cache duration, logos, and results. No live key in CE. |
| API-Football / API-Sports | Official [terms](https://api-sports.io/terms) state that the service does not grant a publication license and that league/federation/event rights may require separate authorization. | Rejected for the prototype until Airo obtains the relevant publication rights in writing. |
| TiVo / Gracenote | The same commercial metadata package advertises sports listings within a rights-managed linear-TV catalog. | Preferred combined enterprise candidate; quote and rights matrix required. |

## Recommendation and approval checklist

No external provider is enabled in v0.0.5. The prototype uses injected fake
adapters only.

## Engineering Council decision record

This records the repository-policy review for the bounded #973 spike. It is
not a provider contract, counsel opinion, procurement approval, or permission
to activate production data.

| Council role | Bounded spike decision | Production activation |
|---|---|---|
| Product | Accept the provider-neutral detail and sports-fixture prototype as internal evaluation evidence. Do not advertise it as a v0.0.5 feature. | Blocked until a provider, territories, expected volume, user value, and disclosure copy are approved. |
| Open Source | Accept public contracts and fake adapters in CE; require real adapters, credentials, and provider-specific code to remain additive in the private overlay. | Blocked until project-specific commercial, artwork, attribution, redistribution, and retention rights are recorded. |
| Security | Accept the fail-closed entitlement + consent + dated-license gate and the no-network CE default. | Blocked until endpoint, secret storage, request minimization, logging, rate-limit, cache-deletion, and incident-disable controls are reviewed. |
| Flutter / Accessibility | Accept provider-named, off-by-default controls and attributed result widgets as a prototype contract. | Blocked until the selected provider disclosure and focus/screen-reader behavior are qualified on supported devices. |
| Chief Architect | Accept `platform_epg` as owner of reusable contracts and `feature_iptv` as owner of the internal composition surface. | Any adapter remains an additive `airo-pro` implementation; CE application flows may depend only on the public contract. |

Result: the spike is accepted with **no production provider approved**. A
future activation is a separate release decision and must not infer approval
from this document.

Before a provider changes from `pending` to `approved`:

1. Product records target surfaces, territories, expected requests, and value.
2. Open Source/legal records commercial/app-store rights, attribution,
   ShareAlike/redistribution effects, permitted fields, image/logo rights,
   cache/retention/deletion rules, and an effective review date.
3. Security approves endpoints, credential storage, request minimization,
   redacted logging, certificate/TLS policy, rate limits, and incident disable.
4. The private overlay supplies the adapter and secret; CE receives neither.
5. UX ships an off-by-default toggle naming the provider and displaying the
   required attribution before the first request.
6. Release qualification verifies attribution and provider disable/revocation.
