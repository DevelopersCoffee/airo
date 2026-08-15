# Airo Surface — market research findings

Research date: 2026-08-15. Findings only — no strategy, no requirements.
Sources: vendor pages, Reddit (via rdt-cli), Hacker News (Algolia), Exa web search,
press coverage. Every bullet carries a URL; dates given where the source publishes one.

Scope note: "what this means for Airo Surface" lines are read-outs of the evidence,
not recommendations.

---

## 1. Existing products in this space

### Subscription dashboard software on your own screen

- **DAKboard** — software-first: turns any TV/monitor/Pi into a calendar+photo+weather
  wall board. Free tier (2 calendars, 60-min calendar refresh, 2-min photo change);
  Essential $6/mo ($5/mo annual); Plus $10/mo ($8/mo annual). Extra screens billed
  separately at $4–6/mo each. Refresh rate, calendar count, content blocks (20 vs 50)
  and custom CSS are the paywall levers. https://dakboard.com/pricing
  → *For Airo Surface:* the incumbent proves people will pay a monthly fee for
  layout + refresh rate alone, and that refresh interval is a legible paywall axis.
- **DAKboard also sells hardware**: "DAKboard CPU v5" is a Raspberry Pi 5 in a box at
  $259, bundled with 30 days of Essential/Plus. In stock as of the page snapshot
  (2024-09-27). https://shop.dakboard.com/products/dakboard-cpu-v5
  → *For Airo Surface:* a $259 Pi-in-a-box with a subscription attached is a live,
  shipping business — the "bring your own screen" model has not been competed away.
- **Company is alive** — shop and pricing pages both current, v5 hardware shipping.
  https://shop.dakboard.com/
  → *For Airo Surface:* DAKboard is the direct software competitor if Airo Surface
  ever renders to a generic screen.

### Family calendar appliances (the money is here)

- **Skylight Calendar** — 10" $159.99, 15" $299.99 (Calendar 2 now listed $279.99),
  27" Calendar Max $599.99 / $569.99 depending on frame.
  https://myskylight.com/products/the-skylight-calendar-2-classic-white-with-plus-plan/ ,
  https://myskylight.com/products/skylight-calendar-max-shadow-box-natural-aluminum-with-plus-plan/ ,
  https://www.theverge.com/reviews/615523/skylight-calendar-max-sidekick-ai-assistant-review (2025-02-20)
  → *For Airo Surface:* the hardware price band for a family display is $160–600.
- **Skylight Plus subscription is $79/year, optional.** It gates AI "Magic Import"
  (email/PDF/photo → events), photo & video screensaver, meal planning, chore
  *rewards*, and Disney Mode. Base calendar sync, lists, chores and profiles are free.
  https://myskylight.com/products/calendar-skylight-plus/ ,
  https://skylight.zendesk.com/hc/en-us/articles/36009559376795-Does-Skylight-Calendar-require-a-subscription
  → *For Airo Surface:* the sellable subscription layer is ingestion + AI + media,
  not the calendar itself.
- **Skylight doubled Plus from $39 to $79/yr in early 2025**, grandfathering existing
  subscribers; The Verge's verdict was "at $79 a year… it's a tougher sell."
  https://www.theverge.com/reviews/615523/skylight-calendar-max-sidekick-ai-assistant-review (2025-02-20)
  → *For Airo Surface:* the market absorbed a 2× price rise without visible collapse,
  but reviewers flagged it immediately.
- **Scale: ~888,000 families own a Skylight** (co-founder Michael Segal to NYT), and
  the company claims 9.3M users across Frame + Calendar, 99% YoY revenue growth,
  bootstrapped, with a $50M debt facility raised April 2025.
  https://www.seattletimes.com/business/can-a-700-calendar-save-your-marriage/ (2025-06-01),
  https://www.prnewswire.com/news-releases/skylight-fuels-family-first-innovation-with-50-million-of-financing-from-sg-credit-partners-and-wingspire-capital-302419399.html (2025-04-03)
  → *For Airo Surface:* this is the single strongest proof the category is real and
  monetizable — and that it is already owned by a well-capitalised incumbent.
- **Hearth Display** — $699 list, discounted to $499–599 in sales. Membership $9/mo,
  $86.40/yr, up to $207.36/3yr. Critically, **membership is required to complete setup**
  (30-day trial), is non-refundable, and cancellable only after setup.
  https://hearthdisplay.com/pages/membership ,
  https://www.goodhousekeeping.com/electronics/a61843845/hearth-display-calendar-review/ (2024-08-28),
  https://lifehacker.com/tech/the-hearth-display-family-planner-changed-how-i-manage-my-family (2024-11-13)
  → *For Airo Surface:* the most aggressive subscription gate in the category, and
  the one that generates the most hostile user commentary (see §2).
- **Hearth is alive and shipping** in 1–2 business days with a 120-day trial — a
  major change from 2024 when backers waited 3–6 months.
  https://hearthdisplay.com/products/hearth-display
- **Cozyla** — Android-tablet-based family calendar, 15.6"/24"/32", $699.99–$899.99,
  explicitly marketed as "sync without subscription" with Google Play access.
  https://www.cozyla.com/products/digital-family-calendar-all-in-one-smart-touchscreen ,
  https://www.amazon.com/Digital-Calendar-Notepad-Electronic-Planner/dp/B0DHCJM694
  → *For Airo Surface:* the "no subscription" positioning is already taken by a
  hardware vendor, at a higher hardware price.

### Big-tech smart displays (declining or hostile)

- **Amazon Echo Show 15** — 15.6" FHD wall-mountable "family hub" with a widget
  gallery (calendar, weather, lists, sticky notes, smart home), $300 list, frequently
  $255. 2nd gen adds Fire TV, Wi-Fi 6E, Thread/Matter.
  https://kotaku.com/amazon-echo-show-15-with-built-in-fire-tv-drops-back-to-black-friday-pricing-a-smart-tv-alternative-in-one-hub-2000693084 (2026-05-06)
  → *For Airo Surface:* a $255 device already does the widget-wall job at half
  Skylight's price — the hardware is not the moat.
- **Echo Show is being actively degraded by full-screen ads.** "Sponsored" full-screen
  ads now appear between photos and content, cannot be disabled, and arrived after
  purchase with no packaging disclosure and no ad-supported discount. Amazon's own
  device chief conceded "the randomness" is not great.
  https://www.theverge.com/report/797672/amazon-echo-show-ads-alexa-plus (2025-10-09)
  → *For Airo Surface:* the largest installed base of ambient home displays is
  currently alienating its users — a real, dated opening.
- **Users are unplugging over it.** HN "People regret buying Amazon smart displays
  after being bombarded with ads" — 338 points, 187 comments (2025-10-11).
  https://news.ycombinator.com/item?id=45551081 . On Reddit: "This will cause me to
  unplug all show devices" (r/alexa, 125 comments, 2025-10-08) —
  https://reddit.com/r/alexa/comments/1o0y0rw/ads_this_will_cause_me_to_unplug_all_show_devices/
  with comments like "I only wish that I never got an echo with a screen" and
  "Me too! Wasted $$".
  → *For Airo Surface:* ad-free is a differentiator people are currently articulating
  in their own words, unprompted.
- **Amazon's device economics are bad.** WSJ: Echo devices are "a widely purchased
  product that is also a giant money loser"; the sell-cheap-monetize-later strategy
  "hasn't paid off."
  https://www.wsj.com/tech/amazon-alexa-devices-echo-losses-strategy-25f2581a (2024-07-23)
  → *For Airo Surface:* explains the ads. Hardware-subsidised ambient displays
  structurally trend toward monetising the screen.
- **Google Nest Hub is in visible decline.** No new smart display since 2021; the
  Pixel Tablet (the de-facto replacement) was discontinued; Assistant→Gemini
  migration has removed features and degraded basic commands to the point Google
  Home's CPO publicly apologised; Nest Hub Max is listed **Out of stock** at $229 on
  the Google Store.
  https://www.theverge.com/report/781221/the-end-of-nest-google-home-smart-home (2025-09-19),
  https://www.androidcentral.com/accessories/smart-home/the-switch-from-google-assistant-to-gemini-might-kill-nest-speakers-and-displays (2025-03-21),
  https://store.google.com/product/google_nest_hub_max
  → *For Airo Surface:* Google has vacated the ambient display category in practice
  even while saying it hasn't.
- **Google says it's still committed** — CPO Anish Kattukaran, Oct 2025: "We're
  definitely committed to smart displays… news to share there soon." No product as of
  research date. https://www.theverge.com/news/794298/new-nest-hub-smart-display-google-home-coming-soon (2025-10-07)
  → *For Airo Surface:* treat a Google re-entry as a live platform risk, not a
  settled absence.
- **Meta Portal is dead.** Wound down Nov 2022, unavailable for purchase since
  2022-12-31, explicitly "no next generation."
  https://www.reuters.com/technology/facebook-parent-meta-winding-down-some-non-core-hardware-projects-2022-11-11/ ,
  https://www.meta.com/help/portal/28980127478297747/
  → *For Airo Surface:* one of three big-tech entrants has fully exited.

### E-ink / low-power dashboards

- **TRMNL** — 7.5" e-paper dashboard, $139 base (TRMNL OG), TRMNL X 10.3" from $219;
  1800mAh battery quoted at 2–6 months; 850–1000+ plugins; "Unbrickable Pledge"; the
  server can be self-hosted. Company alive and shipping, with a colour BWRY model
  and a live review wall.
  https://usetrmnl.com/ , https://previewer.co/trmnl-e-ink-dashboard (2026-06-17)
- **TRMNL's paywalls draw the sharpest criticism in its own reviews.** The $35 "Clarity
  Kit" gates the bigger battery, charging cable, Discord access *and* the right to
  develop your own plugins; a $5/mo subscription gates refresh faster than 15 minutes;
  purchase is non-refundable. Reviewer: "it feels a little scummy"; "Why can't I use my
  open source device to develop open source plugins without paying an additional fee?"
  https://studiowallflowr.com/2026/02/18/trmnl-review/ (2026-02-18)
  → *For Airo Surface:* charging for developer access to an "open" product is the
  single most reputationally costly move observed in this research.
- **Second-order TRMNL risk named by reviewers: plugin rot.** "If support fades
  (especially among community projects) or API changes, plugins become unusable."
  https://notenoughtech.com/review/trmnl/ (2025-09-29)
- **TRMNL practical gripes:** 2.4GHz-only Wi-Fi chip struggles with modern mixed-band
  mesh routers; the e-ink clear flash every 15 min is distracting near a TV; no
  backlight so useless at night.
  https://e-inkreview.com/trmnl-e-ink-dashboard-review/ (2025-12-15)
- **SwitchBot E-Ink Home Dashboard** — new mainstream entrant, 7.5" e-ink, $109.99,
  5000mAh / claimed 1-year battery, front light, calendar sync for up to 5 members,
  Matter. Reviewed as good at the fixed screens and near-useless for custom content:
  "you'd really have to be a developer or scripting hobbyist"; glossy glare-prone
  cover glass.
  https://www.switch-bot.com/products/switchbot-e-ink-home-dashboard (2026-06-02),
  https://gizmodo.com/switchbot-home-dashboard-review-an-e-ink-smart-display-for-the-weather-obsessed-2000779585 (2026-07-18)
  → *For Airo Surface:* the e-ink dashboard price floor just moved to ~$110 from a
  volume smart-home OEM. The gap it leaves is customisation for non-developers.
- **Inkplate 10** (Soldered Electronics) — 9.7" grayscale ESP32 dev board, €189.95
  (€172.86 at 100+), 1200×825, 1.61s full refresh, 22µA deep sleep. Alive and sold
  as a component, not a product. https://soldered.com/products/inkplate-10
- **Visionect Joan** — B2B meeting-room e-ink displays; Joan 6 RE listed at $399;
  sells **only to incorporated legal entities**; Joan 6 / 6 Pro / 13 line still
  offered; a Visionect employee posts publicly on HN; earlier subscription plans were
  cancelled 2023-01-01.
  https://getjoan.com/terms-of-sale-returns-warranty-businesses-june-2025/ ,
  https://productscom.com/product/visionect-joan-6-re-6-full-hd-e-paper-conference-room-booking-display/ ,
  https://getjoan.com/plan-cancellation-notice/ (2022-06-23)
  → *For Airo Surface:* the only durable e-ink ambient business found is B2B room
  booking, at $399/unit, with no consumer motion.
- **Mudita** — mindful-tech e-ink brand; Mudita Pure is discontinued ("we're not
  making new ones"), Kompakt is current. Their own 2021 postmortem documents an
  EU-manufacturing tooling failure that forced an IP54→IP30/42 downgrade and months
  of delay. https://mudita.com/products/phones/ ,
  https://mudita.com/community/blog/new-production-schedule-and-unfortunately-further-delay/ (2021-03-11)
  → *For Airo Surface:* the canonical small-run hardware failure story, written by
  the maker.
- **Home Assistant e-ink dashboards are a thriving DIY genre, not a product.** Typical
  build: LOLIN S3 Pro + Waveshare 7.5" e-Paper, wakes every 20 min, ~1 month on
  2500mAh. https://github.com/pavlojs/esphome-epaper-dashboard . r/homeassistant is
  full of them — "E-ink dashboard" 611 pts, "This weekend's little project" 1176 pts,
  "Interactive e-ink dashboard with HA integration" 213 pts.
  → *For Airo Surface:* strong hobbyist supply, zero packaged-product supply.

### LED / novelty ambient displays

- **Tidbyt** — 64×32 LED matrix, acquihired by Modal 2024-11-07. Shipped ~100,000
  devices. Manufacturing paused ("we're taking a break from manufacturing… no new
  devices will be shipped"), cloud service kept running; the site still advertises a
  Gen 2 pre-order banner.
  https://tidbyt.com/blogs/tidbyt/tidbyt-is-joining-modal (2024-11-07),
  https://modal.com/blog/tidbyt-is-joining-modal (2024-11-07), https://tidbyt.com/
  → *For Airo Surface:* 100k units was not enough to sustain a 3-person hardware
  company. That is the honest ceiling signal for a novelty ambient display.
- **Tidbyt's community verdict was cloud-dependency, not the screen.** "I would have
  bought so many devices like this… if they had a hardware local control option with
  completely open docs. I refuse to spend time engineering a data pipeline that's
  dependent on someone else's cloud service." Founder's reply: open firmware "is not
  something the majority of our customers are asking for."
  https://news.ycombinator.com/item?id=31306135 (2022-05-08)
  → *For Airo Surface:* the loudest buyers want local control; the paying majority
  demonstrably does not ask for it. Both facts are in the same thread.
- **A dev's postmortem after the acquihire**: Tom MacWright, "Tidbyt without the
  company" — device still on the shelf, company gone, cloud promised.
  https://macwright.com/2025/04/12/tidbyt-second-life (2025-04-12)
- **LaMetric** — alive; LaMetric TIME smart clock $199.99, Sky LED wall panels
  ($172–$576 at pre-order). CNET's 2019 verdict still reads true: "Literally nobody
  should pay $200 for this thing." Its Home Assistant integration has broken for the
  Sky product. https://store.lametric.com/products/lametric ,
  https://www.cnet.com/reviews/lametric-time-review/ (2019-01-24),
  https://github.com/home-assistant/core/issues/110058
- **Vestaboard** — split-flap ambient display, $3,499 (Note: $899–1,299), plus
  Vestaboard+ at $95–99.99/yr for third-party integrations. Reviewers concede the
  price is not justified by function.
  https://www.techradar.com/home/smart-home/the-vestaboard-smart-display-costs-twice-as-much-as-my-tv-but-it-works-hard-to-justify-the-price (2025-06-26),
  https://www.popsci.com/gear/vestaboard-smart-display-review/ (2023-02-09)
  → *For Airo Surface:* at the top of the market the product is furniture, and even
  then the integrations are subscription-gated.

---

## 2. Willingness to pay

### The category does monetize — at family-appliance prices

- **~888,000 Skylight-owning families; 99% YoY revenue growth; bootstrapped; $50M
  debt facility.** People genuinely pay $160–600 for a household display.
  https://www.seattletimes.com/business/can-a-700-calendar-save-your-marriage/ (2025-06-01),
  https://www.prnewswire.com/news-releases/skylight-fuels-family-first-innovation-with-50-million-of-financing-from-sg-credit-partners-and-wingspire-capital-302419399.html (2025-04-03)
- **Retail distribution is mainstream**: Costco and Sam's Club carry Skylight,
  frequently bundled with a year of Plus.
  https://reddit.com/r/workingmoms/comments/1korcmg/does_anyone_use_one_of_those_fancy_calendars_like/ (2025-05-17)
- **It is heavily a gift purchase** — Christmas, Mother's Day, Black Friday recur in
  nearly every ownership anecdote. Same threads as above.
  → *For Airo Surface:* gift-driven demand decouples "bought" from "wanted", which
  is exactly the retention hazard in §4.
- **Willingness to pay is driven by mental-load framing, not calendaring.** Hearth
  co-founder: the goal is to "externalize the primary caregiver's brain… into a system
  that everyone could see." https://www.seattletimes.com/business/can-a-700-calendar-save-your-marriage/ (2025-06-01)

### Subscription-gated hardware is the loudest complaint in the category

- **Hard refusal at the shelf:** "We looked at getting a skylight at Costco last night
  and refused to pull the trigger when we saw the word 'subscription'… we hard pass now
  anytime we see that word."
  https://reddit.com/r/BuyItForLife/comments/1t5i5le/digital_wall_calendar_recommendations/ (2026-05-06)
  Also: "I won't buy a car with monthly subscriptions and I certainly won't buy a
  calendar." https://reddit.com/r/smarthome/comments/1bji8bw/real_review_of_hearth_display/ (2024-03-20)
- **Undisclosed subscription drives returns:** a Hearth buyer, "Sent it back today.
  No no and no" — specifically over the subscription not being surfaced pre-purchase.
  Same thread.
- **Cancellation friction is documented.** Skylight's parent, Glimpse LLC, has a BBB
  profile with 6 complaints, 4 unanswered, including "then 2 years later they start you
  on at $40 subscription and make it nearly impossible to cancel on your own."
  Skylight's ToS requires emailing support with the literal words "Cancel
  Subscription". Third-party how-to-cancel guides exist.
  https://www.bbb.org/us/ca/san-francisco/profile/picture-frame-dealers/glimpse-llc-1116-925704 ,
  https://ca.myskylight.com/tos/ ,
  https://legalclarity.org/how-to-cancel-a-skylight-subscription-and-avoid-charges/ (2026-06-03)
  → *For Airo Surface:* no FTC action found; volume is low. This is reputational, not
  regulatory, so far.
- **TRMNL's $5/mo faster-refresh tier reads as contradictory to its own pitch:**
  "I kind of figured a subscription model would have gone against the idea of the
  TRMNL." https://studiowallflowr.com/2026/02/18/trmnl-review/ (2026-02-18)
- **Vestaboard+ at $95–99.99/yr on a $3,499 device** drew: "At this price… the longer
  power cord and a subscription to Plus should be included in the box."
  https://www.techradar.com/home/smart-home/the-vestaboard-smart-display-costs-twice-as-much-as-my-tv-but-it-works-hard-to-justify-the-price (2025-06-26)
- **Counter-evidence — subscriptions are being paid.** Good Housekeeping recommends
  buying Hearth's $9/mo membership ("a small extra cost compared to the device
  itself"); Lifehacker says a Hearth without the sub is "limited to its basic calendar
  functionality" and recommends budgeting for it.
  https://www.goodhousekeeping.com/electronics/a61843845/hearth-display-calendar-review/ (2024-08-28),
  https://lifehacker.com/tech/the-hearth-display-family-planner-changed-how-i-manage-my-family (2024-11-13)
  → *For Airo Surface:* subscription resistance is loud but not universal; the
  breaking point is *undisclosed* or *setup-blocking* subscriptions, not paid
  software per se.

### Price anchors the market has already set

| Thing | Price | Source |
|---|---|---|
| Software-only dashboard | free / $5–10 per month | dakboard.com/pricing |
| Family calendar appliance | $160–$700 hardware | myskylight.com, hearthdisplay.com, cozyla.com |
| Family calendar subscription | $79/yr (Skylight) · $86–108/yr (Hearth) | vendor pages |
| Mainstream smart display | $229–300 (often $255) | Google Store, Kotaku 2026-05-06 |
| E-ink dashboard, packaged | $110 (SwitchBot) · $139–219 (TRMNL) | switch-bot.com, usetrmnl.com |
| E-ink dev board | €190 (Inkplate 10) | soldered.com |
| B2B e-ink room display | $399 | Joan 6 RE |
| Ambient art object | $899–3,499 + $95/yr | Vestaboard |

- **A free open-source competitor already exists and markets against Skylight
  explicitly:** DinkyDash — "No $300 frame. No subscription", MIT licence, runs on any
  old tablet/TV/Pi, BYO API key. https://dinkydash.co/
  → *For Airo Surface:* the "free, runs on a screen you own" position is occupied.

### India

- **No consumer market visible.** Skylight ships direct only to US, Canada, Australia,
  UK; Hearth is US-only.
  https://skylight.zendesk.com/hc/en-us/articles/20421533144219-Skylight-International-Orders-FAQ (2025-12-11)
- **Smart displays did launch in India and are cheap there:** Nest Hub ₹9,999, Echo
  Show 5 ₹8,999 (discounted to ~₹5,000 in sales), Echo Show 10 ₹22,999; Nest Hub Max
  was never officially sold in India.
  https://economictimes.indiatimes.com/magazines/panache/google-nest-hub-vs-amazon-echo-show-5-both-win-on-smart-displays-remain-at-par-with-home-product-compatibility/articleshow/70907156.cms
- **Analyst sizing exists but is low-confidence:** IMARC puts the India smart display
  market at $392.1M (2025) → $1,545.7M (2034), 15.97% CAGR. Vendor research report,
  methodology not public. https://www.imarcgroup.com/india-smart-display-market
- **Component pricing in India:** a bare Waveshare 7.5" e-paper module retails around
  ₹4,520 on IndiaMART. https://www.indiamart.com/proddetail/waveshare-7-5inch-e-paper-e-ink-display-module-2850031135633.html
  → *For Airo Surface:* a $280–700 device plus a $79–108/yr subscription is roughly
  ₹25,000–60,000 + ₹7,000–9,500/yr. No direct Indian consumer evidence either way was
  found — treat any India claim as unsupported.
- **Searches for India-specific discussion of family wall displays, fridge calendars,
  or chore charts returned nothing** on Reddit or via web search.
  → *For Airo Surface:* the strongest India finding is the absence of a conversation.

---

## 3. Widget-layer competition on phones

### Adoption ceiling: most people never use widgets

- **The only public widget-retention number from Google: Gratitude saw 25% higher
  retention for widget users vs non-widget users — but only 10% of total DAU adopted
  widgets at all.** The 10% is arguably the more important figure.
  https://android-developers.googleblog.com/2026/05/how-gratitude-widgets-boosted-user-retention-25-percent.html (2026-05)
  → *For Airo Surface:* widgets retain the minority who adopt; they do not create
  adoption. Plan the funnel around a ~10% adoption ceiling unless something changes it.
- **Secondary coverage flags the obvious caveat**: "It's one app in one category and
  shouldn't be read as a universal benchmark."
  https://android.gadgethacks.com/news/google-play-store-widgets-feature-what-the-new-badges-and-filters-mean-for-android-users/ (2026-08-06)
- **iOS side: roughly 50% of respondents never use widgets at all**; 25–50% use them
  slightly or heavily; on iPad, 46% don't use Home Screen widgets and 58–60% don't use
  Lock Screen or Today View widgets. Self-selected TidBITS reader poll — directional
  only. https://talk.tidbits.com/t/do-you-use-it-widgets-see-middling-adoption/26397 (2024-01-15),
  https://tidbits.com/2024/01/15/do-you-use-it-widgets-see-middling-adoption/
- **Google publicly admits discoverability is broken and dev ROI is unproven.** Play PM
  Yinka Taiwo-Peters: "Historically, one of the challenges with investing in widget
  development has been discoverability and user understanding" and "the effort required
  to build and maintain widgets needs to be justified by user adoption." Play responded
  with a widget search filter, detail-page badges, and an editorial page.
  https://android-developers.googleblog.com/2025/03/google-play-enhances-widget-discovery.html ,
  https://www.theverge.com/news/623289/google-play-apps-widgets-highlighting (both 2025-03-03)

### Monetization ceiling is low

- **KWGT (Android category leader): 16M downloads on the free app; Pro Key is $6.99
  one-time with 860K downloads** — roughly 5% lifetime free→paid conversion on a
  ten-year-old app, and current paid velocity is under 1% of free velocity.
  https://www.appbrain.com/app/kwgt-kustom-widget-maker/org.kustom.widget ,
  https://www.appbrain.com/app/kwgt-kustom-widget-pro-key/org.kustom.widget.pro
- **Widgetsmith: ~131M downloads (Sept 2025), up from 100M in March 2023** — ~31M in
  2.5 years, so growth flattened hard after the 2020 spike.
  https://www.david-smith.org/blog/2025/09/18/widgetsmith-at-five (2025-09-18),
  https://www.david-smith.org/blog/2023/03/08/new-post/ (2023-03-08)
- **Widgetsmith Premium is $1.99/mo or $19.99/yr** with a 7-day trial; weather and tide
  data are the premium gate. https://widgetsmith.app/widgetsmith-faq ,
  https://apps.apple.com/tt/app/widgetsmith/id1523682319
- **The Widgetsmith developer publicly identified retention — not signup rate — as the
  binding constraint on a 131M-download app**: revenue hits an asymptote from "the
  'weight' of your churning users growing over time," and "improving your retention rate
  appears to be much more important to long term income than sign-up rate."
  https://david-smith.org/blog/2023/01/12/churn (2023-01-12)
  → *For Airo Surface:* the best primary source on widget-app economics, written by
  the category's most successful indie, says churn is the whole game.
- **Chronus stays one-time (~$2.99) and markets shared background services as a
  battery advantage**: "Every Chronus widget shares the same lean background services…
  the ones you don't use stay dormant and consume no resources."
  https://play.google.com/store/apps/details?id=com.dvtonder.chronus , https://dvtonder.com/
- **Overdrop moved from one-time licence to subscription and now gates the widgets
  themselves** ("All the homescreen widgets available", "Enhanced data refresh rates");
  a Play review references buying "before everything became subscription-based."
  https://get.overdrop.app/faq.html , https://play.google.com/store/apps/details?id=widget.dd.com.overdrop.free
- **Indie widget packs operate at 50K-download scale** and still distribute via Reddit
  giveaways.
  https://www.reddit.com/r/androidapps/comments/1oovs0x/celebrating_50k_downloads_of_everything_widgets/ (2025-11-05)

### What abandons users — concrete, repeatable causes

- **Battery-drain attribution is the #1 recurring complaint in r/kustom, and users
  cannot distinguish a real bug from an attribution artifact.** "KWGT has used 33%
  battery Vs the next nearest at 9%."
  https://www.reddit.com/r/kustom/comments/1mpdisg/high_battery_drain/ (2025-08-13)
- **The community's actual fix is "restart your phone from time to time"** — a stuck
  background update loop is invisible and unfixable by the user. "battery was draining
  about 10% an hour. Restarted and now it's having no effect."
  https://www.reddit.com/r/kustom/comments/1hu90j7/i_need_to_reduce_kwgt_battery_usage/ (2025-01-05)
- **Even static widgets get blamed**: "I replaced one date and one time/date widget with
  3 static image widgets, and battery drain went from around 1% to 18."
  https://www.reddit.com/r/kustom/comments/1un6ebq/kwgt_draining_battery/ (2026-07-03)
- **The incumbent's own marketing leads with the battery objection** — Kustom's Play
  listing promises data "without draining your battery as many others tools do!"
  https://play.google.com/store/apps/details?id=org.kustom.widget.pro
  → *For Airo Surface:* perceived battery cost is the category's primary churn axis,
  independent of whether the cost is real.
- **Apple's WidgetKit refresh budget is a hard ceiling: 40–70 reloads per 24h for a
  frequently viewed widget (one every 15–60 min), with a ~5-minute floor between
  timeline entries**, budgeted per widget instance, explicitly for battery reasons.
  https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date
  → *For Airo Surface:* "live" is not available on iOS widgets. Any ambient design
  must be correct when stale.
- **On Android the equivalent frictions are exact-alarm permission and
  battery-optimization exemption** (r/androiddev, 2025-03-06, 29 comments) —
  https://www.reddit.com/r/androiddev/comments/1j4pm2e/
  *(title/date verified via search index; comments not read — rate limited)*
- **OEM background restriction breaks widgets, including first-party ones**: "[Xiaomi
  15] Widgets (Google Calendar, etc.) not updating on HyperOS. I've tried everything."
  https://www.reddit.com/r/Xiaomi_15/comments/1tvtjwl/ (2026-06-04); same class of
  report on Poco https://www.reddit.com/r/PocoPhones/comments/1nubyg3/ (2025-09-30)
- **Cross-OEM launcher inconsistency is a real build cost** — Google's own case study
  says "testing across various OEM launchers was also essential"; the indie report
  lists clocks 15 seconds late, fonts reverting to the OnePlus system font, and rounded
  corners becoming sharp once placed.
- **Notifications substitute for widgets and usually win.** Ask HN "What Happened to
  iOS Widgets?": a news-app developer saw no demand — "Our users seem to value push
  notifications more"; another, push notifications "are almost always better for UX
  than widgets (which take up space at all times)."
  https://news.ycombinator.com/item?id=34467116 (2023-01-21)
- **Home-screen real estate is priced by users**: "My Smart Stack knocks it down to 16
  [apps]. That widget better be really, really useful."
  https://talk.tidbits.com/t/do-you-use-it-widgets-see-middling-adoption/26397 (2024-01-16)

### Google At a Glance — the closest analogue to Airo Surface, and it is disliked

- **"At a Glance is useless"** — 157 upvotes, 130 comments: "the widget is so
  uninformative for me I never look on that if I want to see any information."
  https://www.reddit.com/r/GooglePixel/comments/15w6ysf/at_a_glance_is_useless/ (2023-08-20)
- **What retains is episodic, not daily.** The top reply in that thread (141 pts) is
  flight/travel info pulled from email and calendar; "It showed me baggage claim number
  after I landed" (64 pts). Dissent in the same thread: "that's actually useful for the
  small number of people that travels a lot. I never do."
  → *For Airo Surface:* the ambient value that people actually praise is rare
  high-stakes moments, which is structurally bad for daily-habit retention.
- **Wrong or stale ambient content destroys trust fast**: "The new upcoming flight
  At-A-Glance widget is next to useless" — barcode wouldn't scan, gate number never
  updated. 82 upvotes.
  https://www.reddit.com/r/GooglePixel/comments/u9czxb/the_new_upcoming_flight_ataglance_widget_is_next/ (2022-04-22)
- **Un-removable ambient surfaces breed resentment, not engagement**: "There is an
  option to deactivate the feature but the widget stays there, so whats the point."
  https://www.reddit.com/r/GooglePixel/comments/17680qt/no_way_to_remove_at_a_glance_widget/ (2023-10-12);
  earlier: "1/2 my main screen taken up by useless widgets I can't remove."
  https://www.reddit.com/r/GooglePixel/comments/jlw53b/ (2020-11-01)
- **Tap-target ambiguity is a repeated micro-abandonment cause**: "When I tap the
  weather it opens the calendar."
- **Legibility against arbitrary wallpapers is unsolved even at Google** — white text
  unreadable over AI-generated wallpapers, colour not overridable.
  https://www.reddit.com/r/GooglePixel/comments/17cbv5i/ (2023-10-20)

### Platform direction and platform risk

- **Jetpack Glance cut Gratitude's widget build time ~50%** vs XML RemoteViews, with
  dynamic colour and flexible resizing. Same Google case-study URL.
- **Home-screen placement is a fragile asset**: Gratitude's package refactor changed
  widget receiver paths and **deleted widgets off users' home screens**; recovery
  required re-prompting via `requestPinGlanceAppWidget`. Google's tip: never change the
  class name or package. Same URL.
- **In-app pinning, not the system widget picker, is Google's recommended acquisition
  path** — Google frames the picker itself as a discovery failure. Same URL.
- **iOS 26 pushes widgets toward decoration**: clear-glass/tinted presentations render
  content in accented mode (content tinted white, background removed); widgets extend
  to visionOS 26 and CarPlay; watchOS 26 adds relevance widgets that appear only when
  contextually relevant. https://developer.apple.com/videos/play/wwdc2025/278/ (2025-06-09)
- **iOS 18 already commoditised the aesthetic layer Widgetsmith originally sold** —
  free icon/widget placement, resizable home-screen widgets, tinted/dark/clear
  appearance.
  https://support.apple.com/guide/iphone/customize-apps-and-widgets-on-the-home-screen-iph385473442/ios ,
  https://www.macobserver.com/ios/customize-ios-18-home-screen-layout-icons-widgets/ (2024-09-17)
- **Store policy can amputate a widget engine's data sources overnight.** KWGT was
  forced to strip all Health Connect / fitness permissions in v3.82 because "Google's
  bots have decided that Kustom's 'core functionality' is not fitness-related." Dev:
  "I know this will break a ton of existing setups and hundreds of community presets."
  https://www.reddit.com/r/kustom/comments/1reaspl/health_connect_removal_in_382/ (2026-02-25)
  → *For Airo Surface:* a widget layer that aggregates data across domains is exposed
  to a policy class Google enforces by bot.
- **Zooper is the cautionary tale**: no updates after June 2014, dev disowned it in
  2016, pulled from Play Dec 2017.
  https://www.xda-developers.com/zooper-widget-removed-play-store/ (2017-12-22).
  Refugees bounce off the successors' complexity: "I didn't get it right with uccw and
  kwgt. confusing and laborious." https://xdaforums.com/t/any-replacement-for-zooper.4681393/ (2024-07-15)
- **The surviving Kustom community is a theming subculture, not a utility user base** —
  top r/kustom and r/androidthemes posts of the past year are preset showcases, not
  functional widgets. The retained cohort enjoys the *making*.
  https://www.reddit.com/r/kustom/ , https://www.reddit.com/r/androidthemes/

---

## 4. The family / household coordination use case

### Evidence people buy

- **~888,000 Skylight-owning families**, founder-stated to NYT — the largest hard
  number in the category. https://www.seattletimes.com/business/can-a-700-calendar-save-your-marriage/ (2025-06-01)
- **Hearth claims "Loved by 40,000+ families"** (marketing copy, unverified).
  https://hearthdisplay.com/
- **"Is it worth it" demand is constant** — recurring monthly in r/skylightcalendar
  (e.g. https://reddit.com/r/skylightcalendar/comments/1veoo30/another_is_it_worth_it_post/ ,
  2026-08-03) and a 2025-05 r/workingmoms thread at 86 upvotes / 111 comments.
  https://reddit.com/r/workingmoms/comments/1korcmg/does_anyone_use_one_of_those_fancy_calendars_like/
- **ADHD / neurodivergent households are a distinct motivated segment** — a dedicated
  r/adhdwomen thread (31 comments, 2026-06-05) and a Hearth marketing page aimed at
  neurodiversity.
  https://reddit.com/r/adhdwomen/comments/1u16bp7/give_it_to_me_straight_are_those_wall_digital/
- **Caregiving/accessibility is a real secondary use case** — 120-upvote Costco
  comment about a husband with a traumatic brain injury who couldn't keep a whiteboard
  current: "This has been such a benefit for us."
  https://reddit.com/r/Costco/comments/1m9clcw/does_anyone_have_the_skylight_calendar/ (2025-07-25)
- **DIY substitution proves latent demand below the price point** — an HA
  Skylight-clone calendar card hit 212 upvotes / 65 comments; top comment: "I wanted to
  gift my wife one but the max is $600 I was like surely HA can do this better."
  https://reddit.com/r/homeassistant/comments/1stju94/i_saw_my_brothers_skylight_calendar_and_tried_to/ (2026-04-23)
  → *For Airo Surface:* purchase intent is well-evidenced; the open question is
  everything after the purchase.

### Evidence people still use it after 6+ months (thin but real)

- **2 years, load-bearing:** "We have had one for 2 years… it is integral to our family
  schedule." 183 upvotes. https://reddit.com/r/Costco/comments/1m9clcw/does_anyone_have_the_skylight_calendar/ (2025-07-25)
- **2 years, skeptic converted:** "My wife was very skeptical at first… she now
  wouldn't live without it." https://reddit.com/r/skylightcalendar/comments/1qi3xj0/regret/ (2026-01-20)
- **Second-unit purchases** — the strongest retention signal available: "we have liked
  ours enough to get a second one"; "I love ours, and bought a second bigger one."
  Same thread.
- **Hearth at exactly 12 months:** "hearth display became load-bearing for our
  household within a few months, that's the only review metric that matters at twelve
  months. Still worth it for us. Would buy again."
  https://reddit.com/r/HerWellness/comments/1vgicck/hearth_review_one_year_in_what_we_actually_use/ (2026-08-05)
- **~6 months, positive, no subscription:** "We bought one about six months ago, and
  it's been working great for us, without the subscription." 137 upvotes.
  https://reddit.com/r/Costco/comments/1m9clcw/does_anyone_have_the_skylight_calendar/ (2025-07-25)
- **~16 months, still in use:** "I got it for Christmas 2024 so we've been using it
  awhile… I can update my Google calendar, and he can update his, and they both show up
  on the kitchen calendar."
  https://reddit.com/r/productivity/comments/1sidg5r/busy_parents_what_actually_works_for_keeping_the/ (2026-04-11)
  → *For Airo Surface:* retention concentrates in exactly three primitives — shared
  calendar, kid routines, shared lists.

### Evidence people abandon it

- **Feature decay inside a retained device.** The same 12-month Hearth review reports:
  meal planning ~50/50, weekly review weekly, feelings check-in **abandoned** (kids
  aged out), AI photo-to-calendar "I forget it exists honestly."
  https://reddit.com/r/HerWellness/comments/1vgicck/hearth_review_one_year_in_what_we_actually_use/ (2026-08-05)
- **The literal "became wallpaper" case, at 1 year:** "no one uses it. It just sits on
  our counter with a wallpaper on 99% of the time." Returned to Sam's Club.
  https://reddit.com/r/skylightcalendar/comments/1pddvwp/was_excited_for_skylight_but_one_feature_tanked/ (2025-12-03)
- **A "Regret" thread on the vendor's own subreddit** (46 upvotes, 54 comments):
  "it's too basic, not intuitive enough, not customizable enough… now it's just another
  tool that's sitting there. I wish I would've just mounted a basic old iPad."
  https://reddit.com/r/skylightcalendar/comments/1qi3xj0/regret/ (2026-01-20)
- **Kids abandon the chore system first:** "The chores system is too rigid and clunky
  to work well… they've stopped using it." Same thread. Age-band fragility is
  explicit: routines land preschool–elementary and die for tweens/teens — one owner
  returned it because "his kids are 12 and 14, the routine stuff didn't land at that
  age."
- **The screensaver actively destroys the ambient value.** Skylight has no motion or
  presence sensor, so the photo screensaver hides the calendar: "you have to tap it a
  couple times to get it to drop out of the photo screensaver"; "I wish when you walked
  by it, it would switch to the task screen"; and a blunt diagnosis of the wallpaper
  case: "Turn off the wallpaper. Not kidding. It defeats the point."
  https://reddit.com/r/skylightcalendar/comments/1pddvwp/was_excited_for_skylight_but_one_feature_tanked/ (2025-12-03),
  https://reddit.com/r/MamaMustHaves/comments/1qevbd0/skylight_digital_calendar_review_bought_6_mths_ago/ (2026-01-16)
  → *For Airo Surface:* the single most actionable failure detail found. A pretty
  idle state cannibalises the information state.
- **The device gets bypassed by the phone app:** "I've maybe touched it 2-3 times since
  setting it up"; "Husband and I use our Google Calendar apps on our phones more."
  https://reddit.com/r/skylightcalendar/comments/1uxa801/full_skylight_calendar_2_review_after_months_of/ (2026-04-13)
- **Hearth, 6+ months, structured negative review: "I do NOT recommend it."** Routines
  can't run simultaneously so it "does NOT help get 2+ kids ready for school"; monthly
  view unusable; everything easier on the phone than on the wall device. In the same
  thread an Android engineer returned his: "essentially a sideways Google Calendar with
  a to-do list tacked on."
  https://reddit.com/r/smarthome/comments/1bji8bw/real_review_of_hearth_display/ (2024-03-20)
- **Never activated:** "We have had one for a few years. We don't use it as much as we
  thought we would" (95 upvotes).
  https://reddit.com/r/Costco/comments/1m9clcw/does_anyone_have_the_skylight_calendar/ (2025-07-25)
- **The dominant consensus is that the display can't fix the underlying problem.** Top
  comment, 261 upvotes: "if your husband won't use a free shared calendar, why would he
  use the expensive shared calendar? This is a husband problem, not a product problem."
  Also: "calendars don't make people do things"; "If you ain't someone that already
  uses a calendar, this ain't gonna make you start using a calendar."
  https://reddit.com/r/workingmoms/comments/1korcmg/does_anyone_use_one_of_those_fancy_calendars_like/ (2025-05-17)
- **Experts on record saying the same.** Sociologist Allison Daminger (UW–Madison):
  "I often end up being a buzzkill, where I say, 'I'm not sure this is actually going to
  change the underlying dynamic.'" Eve Rodsky (*Fair Play*): "My biggest fear is the
  disappointment people are going to have when they think this amazing new shiny app
  will solve their gender-equity issues."
  https://www.seattletimes.com/business/can-a-700-calendar-save-your-marriage/ (2025-06-01)
- **Even the flagship power user is a single-updater.** NYT's featured Skylight
  ambassador "is the only person in the family consistently adding events." Same URL.
  → *For Airo Surface:* the display reliably solves *visibility* and reliably fails at
  *participation*. Every durable household in this evidence had buy-in before the
  purchase.
- **Operational churn:** Skylight is still 2.4GHz-only in 2026 and drops off networks
  — "One device dictating how Wifi needs to be set up is a HARD NO"; multiple returns
  over Wi-Fi instability. Same threads.
- **Cheap substitution pressure is constant**: mounted iPad + Google Calendar, Echo
  Show 21, Fire tablet + Mango Display ($2.99/mo), DAKboard free tier, HA + Pi +
  touchscreen, "I'm building my own with Claude Code, a raspberry pi, and a $50 touch
  screen." Frequent verdict: "it definitely is overpriced for a glorified android
  tablet."
  https://reddit.com/r/Homeorganization/comments/1ruuxvt/what_is_actually_the_best_digital_wall_calendar/ (2026-03-16)

---

## 5. Failure modes

### Dashboards decay into furniture — this is the best-documented pattern

- **"The Dashboard Nobody Checks"** — the failure is structural, not cosmetic: "By week
  three, nobody is looking at it… The dashboard fails not because it is broken but
  because it is passive. It waits to be visited." Prescribed fix is inversion: alerts,
  daily digests, embedded status where the person already looks.
  https://kody-w.github.io/2026/03/09/the-dashboard-nobody-checks/ (2026-03-09)
  → *For Airo Surface:* the strongest single statement of the core risk. An ambient
  surface is a passive dashboard by definition.
- **"Dashboard graveyards"** — working diagnostic: zero opens by a non-builder in 90
  days. Named root causes: built for available data rather than a specific decision;
  metric overload with no hierarchy; missing context; maintenance neglect producing
  stale, untrustworthy data.
  https://databox.com/dashboard-graveyard (2026-04-16)
- **Home Assistant's own community argues the dashboard is the wrong artifact.**
  "I never used dashboard" (66 comments): "if I'm using my dashboard, it's either
  because I'm doing something out of routine or there's a problem"; "My goal is
  literally the opposite of a dashboard"; "Nobody looks at it but me and then only if
  I need to see what's happening."
  https://reddit.com/r/homeassistant/comments/1uq8gbo/i_never_used_dashboard/
- **And a thread explicitly asking whether wall tablets are the wrong build.**
  "After watching my family use Home Assistant, I realized they almost never browse
  those pages. They just want answers to questions like: Is everything okay? Did the
  laundry finish?… That's a very different problem than 'show me every entity.'"
  A commenter adds the mechanism: "why do I see light switches during the day? Why does
  my EV charging show even though the car isn't plugged in?… I'm thinking of some
  mechanism that assigns each interface group with a relevancy score in real time."
  https://reddit.com/r/homeassistant/comments/1vdy207/are_we_building_the_wrong_thing_for_our_wall_tablets/
  → *For Airo Surface:* relevance-gated content, not more content, is what the
  power-user community has converged on.
- **The one HA build people report their families actually using is conditional
  visibility**: "only show at relevant times… The only things that show all the time
  are time, weather, and indoor temperature." Same thread.
- **"My biggest problem was justifying the tablets at all since we use phones for
  everything."** Same thread — the phone eats the wall display.

### Habituation is a measured effect, not a metaphor

- **Longitudinal fMRI + eye-tracking + 3-week field experiment on repeated warnings**:
  attention declines measurably over a workweek, adherence drops over three weeks, and
  **polymorphic (varying) presentation substantially reduces habituation**.
  https://misq.umn.edu/tuning-out-security-warnings-a-longitudinal-examination-of-habituation-through-fmri-eye-tracking-and-field-experiments/
  → *For Airo Surface:* the only intervention with hard evidence behind it is varying
  the presentation over time.
- **Peripheral-information research is explicit about the tradeoff**: the design
  challenge is "information displays that maximize information delivery while at the
  same time minimize intrusiveness or distraction."
  https://interruptions.net/literature/Maglio-CHI00-p241-maglio.pdf
- **CHI 2025 on ambient noticeability** — whether ambient content is even perceived
  depends on the viewer's engagement state; gaze + engagement predicts noticeability
  at AUC 0.81, gaze alone 0.76. https://dl.acm.org/doi/10.1145/3706598.3713511
  → *For Airo Surface:* "displayed" and "seen" are different variables, and the gap
  is measurable.
- **Information radiators only pay off through reception**: "without the reception
  there can be no use."
  https://link.springer.com/article/10.1007/s42979-021-00928-7 (2021-10-23)

### Product-level graveyard

- **Panic's Status Board** — the best-loved iPad ambient dashboard, discontinued
  2016-11-28: "sales weren't enough to sustain further development."
  https://blog.panic.com/the-future-of-status-board/ , https://help.panic.com/statusboard/future/
  → *For Airo Surface:* a beautifully executed ambient dashboard from a beloved dev
  shop still failed commercially.
- **The recurring HN observation**: "There seem to be so many people on HN and
  elsewhere who are interested in ambient data displays, but they never catch on with
  the masses." https://news.ycombinator.com/item?id=31306135 (2022-05-08)
- **Meta Portal** — exited entirely (2022). **Tidbyt** — 100k units, acquihired,
  manufacturing paused (2024). **Nest Hub** — no new hardware since 2021, Pixel Tablet
  discontinued, Assistant degraded (2025). **Status Board** — dead (2016). Sources as
  cited in §1.
- **Cloud dependency is the named death mechanism by users:** "It's an LED matrix which
  requires third party cloud servers to update the display. I own one. It's great." →
  reply: "…until the server goes down."
  https://news.ycombinator.com/item?id=31306135 (2022-05-08)
- **Ads are the named death mechanism by owners**: "You know something is ethically
  wrong with a product if you have to turn off all the ads they didn't tell you about.
  Then they change the design so you can't turn them off anymore."
  https://reddit.com/r/alexa/comments/1o0y0rw/ads_this_will_cause_me_to_unplug_all_show_devices/ (2025-10-08)
- **Bait-and-switch is the specific grievance, not ads in the abstract:** "Half the
  time they bait and switch you with a product which initially doesn't have ads… and
  then they turn them on… long after you made the purchase."
  https://news.ycombinator.com/item?id=45551081 (2025-10-11)

### The one counter-example that worked

- **A dashboard that absorbed notifications rather than adding a surface** — moving
  low-priority HA alerts off the phone onto an e-ink dashboard "cut my phone
  notifications in half" and made the remaining phone notifications matter again.
  https://www.howtogeek.com/e-ink-home-assistant-display-cut-phone-notifications-in-half/ (2026-08-05)
  → *For Airo Surface:* the one retention story with a mechanism behind it is
  *subtraction from another channel*, not addition of a new one.

---

## 6. The e-ink hardware path

### Panel supply and cost

- **E Ink Holdings holds an effective monopoly and it survived patent expiry.** The
  core MIT microencapsulation patent expired in 2018 and nothing changed; independent
  investor analysis puts E Ink's share "in the high 90s" across e-readers, ESL and
  signage, with a TAM of only ~US$1bn — which is exactly why no large entrant bothers.
  https://www.variispartners.co.uk/3q24 . A separate estimate puts the electrophoretic
  supply-chain share at 65.2% and flags "persistent high royalty costs for their patent
  estate… a friction point for smaller hardware integrators."
  https://www.verifiedmarketresearch.com/blog/top-e-paper-display-manufacturers/ (2026-02-25)
  E Ink itself reports ~2,770 patent applications / ~1,860 issued as of Dec 2025.
  https://jp.eink.com/investor/governance?bookmark=ip
- **The real moat is waveform data, not patents:** "e-Ink has complicated voltage
  waveform requirements… they are all proprietary. And there aren't multiple competing
  manufacturers, so even though some of the key patents have expired we have not seen a
  renaissance of display modules." https://news.ycombinator.com/item?id=34313685 (2023-01-09)
- **E Ink Holdings is capacity-constrained and explicitly unwilling to cut prices.**
  CEO Johnson Lee, Aug 2025: capacity "thoroughly eclipsed by customer demand"; full
  line utilisation "reducing pricing pressure"; long-term gross-margin target 50–55%;
  seven production lines today, an H6 line planned for 2026 with mass production early
  2027. https://www.digitimes.com/news/a20250814PD224/e-ink-demand-esl-production-earnings.html (2025-08-15)
  → *For Airo Surface:* the panel supplier is a single vendor with pricing power and
  no incentive to discount. Panel cost will not fall on your schedule.
- **Colour e-paper costs 8–10× an LCD of the same size**, and E Ink's own stated
  ambition is only to reach 1.5–2.5× LCD — not parity. Largest commercially available
  colour panels are far smaller than the 55–65" used in signage.
  https://invidis.com/sixteen-nine/2025/01/17/future-displays-e-ink-has-digital-signage-ambitions-but-costs-and-formats-are-adoption-barriers/ (2025-01-17)
- **Hobbyist panel prices (Waveshare, direct):** 7.5" mono e-Paper HAT $56.99 at 1–9
  units, $54.59 at 10–49, $53.39 at 50–99, **$52.91 at 100+** — a shallow volume curve.
  https://www.waveshare.com/product/displays/e-paper/epaper-1/7.5inch-e-paper-hat.htm
  → *For Airo Surface:* buying 100 panels saves ~7%. There is no small-run volume
  discount worth planning around.
- **Full Waveshare retail ladder (the de facto hobbyist price floor):** 4.2" mono
  $34.99; 7.5" mono HAT $56.99; 7.5" 4-colour $47.99–56.99; **10.3" 1872×1404 mono
  $202.99**; 13.3" 960×680 mono $144.99; 4" Spectra 6 $37.99–46.99; 7.3" Spectra 6
  $59.99–79.99; **13.3" 1600×1200 Spectra 6 $249.99–259.99**. The 7.3" ACeP 7-colour
  ($75.99) is now discontinued, displaced by Spectra 6. Universal ESP32 e-Paper driver
  board: **$14.99** — the MCU is a rounding error next to the panel.
  https://www.waveshare.com/product/displays/e-paper/4.2inch-e-paper-module.htm ,
  https://www.waveshare.com/10.3inch-e-paper-hat.htm ,
  https://www.waveshare.com/13.3inch-e-paper-hat-plus-e.htm ,
  https://www.waveshare.com/product/7.3inch-e-paper-hat-f.htm ,
  https://www.waveshare.com/product/displays/e-paper/e-paper-esp32-driver-board.htm
  → *For Airo Surface:* colour at a wall-usable size costs ~$250 for the panel alone.
- **E Ink's own shop is worse**: 13.3" Spectra 6 panel **$449**, plus ~$200 for the
  Scarlet driving board and power accessory to run it.
  https://shopkits.eink.com/en/product/detail/13.3''Spectra6ePaperDisplay
- **In India, a bare Waveshare 7.5" module retails around ₹4,520** (~$52) on IndiaMART —
  roughly import parity, no local cost advantage.
  https://www.indiamart.com/proddetail/waveshare-7-5inch-e-paper-e-ink-display-module-2850031135633.html
- **TRMNL publishes its own BOM and the conclusion that DIY loses:** battery $5, EPD
  screen $50, microcontroller $3–30, enclosure $3–20 — and "the investment required to
  build your own device could be greater than our retail price… Making a TRMNL from
  scratch is not an economically rational decision, but rather a labor of love."
  https://docs.usetrmnl.com/go/diy/byod
  → *For Airo Surface:* the panel is ~40% of a $139 retail device's BOM. There is
  very little room under the incumbent.

### Physical limits

- **E Ink Spectra 6 (the current colour platform): 12–15 second update time, 0–50°C
  operating range, up to 200 ppi, ~30:1 contrast.** E Ink's own materials concede the
  positioning: "Update times are longer than those of eReaders, but for an environment
  where updates only need to occur a few times per day, those longer times can be
  accommodated."
  https://www.eink.com/brand/detail/Spectra6 ,
  https://4336425.fs1.hubspotusercontent-na1.net/hubfs/4336425/E%20Ink%20Color%20Products%20Booklet.pdf ,
  https://www.taiwanexcellence.org/en/award/product/1130604
  → *For Airo Surface:* colour e-ink is a few-updates-per-day medium. Anything that
  needs to change on a human timescale must be mono, partial-refresh, or not e-ink.
- **Shipping Spectra 6 panels are ~2× E Ink's marketing figure: 19s at 13.3", 25s at
  7.3".** The 2025 "Ripple" waveform upgrade added primaries and smoothed the flash but
  explicitly did **not** reduce the 12s figure.
  https://www.waveshare.com/13.3inch-e-paper-hat-plus-e.htm ,
  https://www.waveshare.com/wiki/7.3inch_e-Paper_HAT_(E)_Manual ,
  https://invidis.com/news/2025/03/e-ink-upgrade-more-colors-and-less-flashing/ (2025-03-31)
- **Mono refresh figures, 7.5" 800×480: full 4s, fast 1.5s, partial 0.4s, 4-grey 2.1s;
  standby <0.01 µA; viewing angle >170°. The same size in red/black/white takes 26s** —
  one extra particle costs roughly 6× the refresh time.
  https://www.waveshare.com/product/7.5inch-e-paper.htm
- **Mono full refresh is ~1.6s** on a 9.7" panel (Inkplate 10, 1200×825), with partial
  update supported. https://soldered.com/products/inkplate-10
- **The faster colour options each carry a disqualifying catch.** Gallery 3 (ACeP CMYW)
  is far quicker — B&W 350ms, fast colour 500ms, best colour 1500ms, 300ppi — but only
  ~10,000 colour gamut and it needs a front light. Kaleido 3 (colour filter array) is
  500ms and −15 to +65 °C, but colour resolution drops to 75 ppi and it also requires a
  front light. https://www.eink.com/brand/detail/Gallery_3 ,
  https://4336425.fs1.hubspotusercontent-na1.net/hubfs/4336425/E%20Ink%20Color%20Products%20Booklet.pdf
- **Temperature rules out several deployments outright.** Standard mono and Spectra 6
  run 0–50 °C. The 7-colour ACeP panel operates only at **15–35 °C** and needs six hours
  at 25 °C before refreshing if it's been colder. Pervasive Displays states plainly that
  **"Spectra EPDs cannot be operated at sub-zero temperatures and do not support
  Fast/Partial refresh"**; wide-temp (−15 to +60 °C) and freezer (−25 to +30 °C) parts
  are black-and-white only.
  https://www.waveshare.com/wiki/7.5inch_e-Paper_HAT_(F)_Manual ,
  https://www.pervasivedisplays.com/product/epd-product-selection/ (2025-09-24)
- **Vendor care instructions are operational constraints, not advice:** minimum refresh
  interval **180 seconds**; the panel must be refreshed **at least once every 24 hours**
  or you get "screen burn that is difficult to repair"; full update after every 5
  partial updates; store showing white; refresh every 3 months if stored over 6.
  https://www.waveshare.com/wiki/7.3inch_e-Paper_HAT_(F)_Manual ,
  https://www.good-display.com/news/80.html
- **Measured ghosting trade-off** (2.9" panel, GxEPD2): standard full refresh 2.10s
  clears ghosting completely; fast full 1.70s may leave a trace; partial 370ms
  accumulates ghosting every time.
  https://docs.waveshare.com/ESP32-Peripheral-Tutorials/Display/E-Paper
- **Legibility has a measured floor: ~62 lux ambient illumination** before an e-paper
  display is comfortably legible. https://www.sciencedirect.com/science/article/abs/pii/S0141938210000739
  → *For Airo Surface:* a kitchen at night, a hallway, or a bedside is below this.
- **No backlight is a hard constraint people hit in practice:** "you can't read it in
  the dark… useless at night without a lamp. Great for an office, bad for a bedside
  clock." Full-refresh flashing every 15 minutes is described as distracting near a TV.
  https://e-inkreview.com/trmnl-e-ink-dashboard-review/ (2025-12-15)
- **Cover glass finish matters more than spec sheets suggest** — SwitchBot's glossy
  cover made its wall-mounted e-ink "hard to read from certain angles because all I
  could see were the reflections of my windows."
  https://gizmodo.com/switchbot-home-dashboard-review-an-e-ink-smart-display-for-the-weather-obsessed-2000779585 (2026-07-18)

### What ESP32 / Pi-class dashboards can and can't do

- **Realistic battery life, measured, not claimed:** LOLIN S3 Pro (ESP32-S3) +
  Waveshare 7.5", 90s awake per 20-minute cycle → **~1 month on 2500 mAh**. The wake
  cycle is dominated by Wi-Fi connect (20s timeout) + data fetch (30s timeout) + 5s
  waiting for the panel to physically finish rendering.
  https://github.com/pavlojs/esphome-epaper-dashboard
  → *For Airo Surface:* the "months of battery" claim requires refreshing a handful
  of times per hour at most; Wi-Fi wake, not the panel, is the power budget.
- **Vendor claims sit far above that**: TRMNL quotes 2–6 months on 1800 mAh depending
  on refresh; Inkplate 10 quotes 22 µA deep sleep and "months, even a year";
  SwitchBot quotes 1 year on 5000 mAh. All are refresh-rate-dependent.
  https://previewer.co/trmnl-e-ink-dashboard (2026-06-17), https://soldered.com/products/inkplate-10 ,
  https://www.switch-bot.com/products/switchbot-e-ink-home-dashboard (2026-06-02)
- **2.4GHz-only radios are a real support cost.** TRMNL: "It uses an older chip that
  only likes 2.4GHz networks. If you have a modern mesh router that mixes bands, it
  might struggle to connect at first. I had to fiddle with settings."
  https://e-inkreview.com/trmnl-e-ink-dashboard-review/ (2025-12-15). The same issue
  drives Skylight returns (§4).
- **Framebuffer size is the binding on-device constraint.** ESP32-C3 has 400 KB SRAM,
  classic ESP32 520 KB. 800×480 at 1 bpp is 48 KB and fine; 3-colour or 7-colour
  multiplies that and "standard ESP32-WROOM modules will crash" — you need PSRAM
  (WROVER/S3). ESPHome flags the 7.5" v2 and 7.5"-HD-B models as unusable on ESP8266
  "as it runs out of RAM", and supports partial refresh (`full_update_every`) on only a
  handful of models. https://documentation.espressif.com/esp32-c3_datasheet_en.pdf ,
  https://esphome.io/components/display/waveshare_epaper/ ,
  https://esp32s.com/blog/mastering-esp32-e-paper-displays-a-developers-guide-to-low-power-high-impact-iot-visuals/ (2026-07-11)
  The consequence is documented in an open ESPHome request: without partial refresh you
  get "ghosting and faded images after multiple partial updates… significant visual
  degradation over time." https://github.com/esphome/feature-requests/issues/3141 (2025-05-06)
- **Deep sleep and partial refresh are effectively mutually exclusive.**
  `display.hibernate()` gives the lowest power but invalidates the previous-frame data
  in the driver IC — you must reinitialise and do a *full* refresh before resuming
  partial. https://docs.waveshare.com/ESP32-Peripheral-Tutorials/Display/E-Paper
  → *For Airo Surface:* the single most consequential engineering fact in this
  section. Battery-powered means full refreshes means visible flashing.
- **Out-of-box sleep current is often wrong, and it eats the whole battery story.** A
  reTerminal E1003 drew ~4 mA in deep sleep (flat in 20–30 days) because SD-card and
  touch pins floated HIGH; holding them LOW dropped it below meter resolution →
  ~1%/day, 3+ months at a 4-hour refresh. Only diagnosable because Seeed publishes
  schematics. https://www.reddit.com/r/homeassistant/comments/1u1rhda/ (2026-06-06)
- **Commercial claim-vs-reality:** Seeed reTerminal E1002 advertises 3-month battery;
  a user running it live gets a full month at 60-minute updates, ~25 days at 45 minutes,
  both with an overnight sleep. Independent review: E1001 mono refreshes in 2–3s, E1002
  colour in ~17s, and the 3-month claim only holds for mono on a static screen.
  https://github.com/cromelex/e1002-esphome-dashboard ,
  https://www.cnx-software.com/2025/12/15/reterminal-e1001-e1002-review-bw-and-color-epaper-displays-tested-with-sensecraft-hmi-and-home-assistant/ (2025-12-15)
- **The 2.4GHz problem is architectural, not a bad chip choice** — ESP32 has no 5 GHz
  radio, so it cannot even see a 5 GHz SSID; band-steering routers with one shared SSID
  produce connect failures users read as device faults. Documented workarounds are
  "disable 5 GHz on the IoT SSID" or "buy a second router."
  https://github.com/Aircoookie/WLED/issues/4187 . TRMNL's fix for the X is telling:
  it ships an ESP32-S3 **plus a second ESP32-C5 purely as a 5 GHz modem**.
  https://trmnl.com/products/x/spec-sheet
- **Rendering is server-side in every shipping product.** TRMNL's device does
  `GET /api/display` with ID/token/refresh-rate/battery/RSSI headers and receives JSON
  containing an `image_url` pointing at a .bmp — it draws a bitmap and renders nothing.
  The firmware is open-sourceable precisely because the value is in the server.
  https://github.com/usetrmnl/trmnl-firmware , https://trmnl.com/blog/the-unbrickable-pledge (2025-02-18)
  The community converged independently on the same shape (compose in a browser →
  headless renderer → panel fetches over REST). https://github.com/dmellok/tesserae
- **The driver layer, not the app layer, is where these projects break.** ESPHome's
  `waveshare_epaper` tracker carries model-specific bugs open 3–5 years: wrong driver
  selection (#5455, open since 2024-01-31), 7.5v2 flicker (#5474), "WiFi stops working
  when display is enabled" (#5910, 2024-06-16), and repeated deep-sleep failures
  (#1458 open since 2020-09-09). LVGL is effectively unusable on e-paper. Upstream
  releases routinely break working dashboards — inverted images after 2025.2, online
  image broken in 2025.5.2, increased deep-sleep current after Inkplate library 11.0.0
  (2026-05-08). https://github.com/esphome/issues/issues
  → *For Airo Surface:* the maintenance surface is per-panel-model firmware, and it
  regresses on someone else's release cadence.
- **The DIY genre is healthy and produces working artifacts** — r/eink's top month
  includes a personal train timetable + weather board (1,083 pts), a bus-arrival
  display built for a relative's commute (816 pts), an ereader sleep-screen dashboard
  (290 pts), and a fully open-sourced 7.3" Spectra 6 frame with PCB/Gerbers/BOM/CAD
  (234 pts). r/homeassistant likewise: "E-ink dashboard" 611 pts, "This weekend's
  little project" 1,176 pts. https://www.reddit.com/r/eink/ , https://www.reddit.com/r/homeassistant/
  → *For Airo Surface:* enormous hobbyist supply, near-zero packaged-product supply.
  That gap is the opportunity and also the reason margins are thin.

### What indie makers say went wrong

- **TRMNL's own founder-stated business risk is server cost on a lifetime-access
  model.** "As more TRMNL devices opt into our lifetime-access hosted platform, how
  will we handle growing server costs?" The answer was the Unbrickable Pledge — a
  written commitment to open-source the core web app "if and when we ever become
  insolvent." https://trmnl.com/blog/the-unbrickable-pledge (2025-02-18)
  → *For Airo Surface:* selling hardware with lifetime hosted service is a known
  unfunded liability, publicly acknowledged by the market leader.
- **TRMNL's scale, for calibration:** Kickstarter Jun–Jul 2024 raised **$157,677 from
  1,325 backers** against a $5,000 goal. Current pricing: OG $139, X $229, BWRY $139,
  **BYOD licence $50 one-time perpetual** (not required if you self-host BYOS),
  Developer Edition $20. By end-2025: 1,500+ people running BYOD, plugins grew 60 →
  700+ (~90% community-built), team 25+.
  https://www.kickstarter.com/projects/usetrmnl/trmnl-the-e-ink-display-for-your-favorite-apps-and-news ,
  https://shop.trmnl.com/products.json , https://docs.trmnl.com/go/diy/byos ,
  https://usetrmnl.com/blog/2025-in-review (2025-12-17)
- **The founder's own 2025 retrospective is the best failure list in the category:**
  repeated stockouts, repeated server crashes, **hundreds of packages lost or damaged**,
  Model X shipping delayed, and **hundreds of functional devices bricked by firmware
  v1.6.0**. Named tail risks in their words: "550% tariff hikes and rare earth metal
  bans", magnet deliveries blocked by China's critical-mineral export controls, and an
  EU warehouse slowed by "customs issues and supplier theft."
  https://usetrmnl.com/blog/2025-in-review (2025-12-17)
- **The first outage was a self-inflicted DDoS**: latency caused devices to ignore
  exponential backoff and retry every 5 seconds.
  https://www.reddit.com/r/trmnl/comments/1l4hs9z/ (2025-06-04)
- **Firmware quality was bad enough to need an outside specialist.** Larry Bank was
  brought in Jul 2025 and within a month unlocked 4 greyscale levels on a panel the
  supplier's datasheet called 1-bit, and cut WiFi-on time for **+22% battery life**.
  They had been pre-selling a hardware screen upgrade to fix this and refunded everyone
  when OTA turned out to be enough. https://usetrmnl.com/blog/no-more-flicker (2025-08-04)
- **Model X slipped ~14 months** (announced 2025-07-30, promised end-2025, assembly
  began 2026-03-18). Compensation was $15,000 in charity donations plus 6 months free
  TRMNL+; **only 47 of ~3,900 pre-orders cancelled (1.2%)**.
  https://usetrmnl.com/blog/x-shipping-delay-survey (2025-11-28)
  → *For Airo Surface:* a 14-month slip with a public apology cost 1.2% of the order
  book. Hardware buyers in this niche are unusually forgiving of schedule, and
  unforgiving of paywalls.
- **The recurring buyer objection is licence drift**, not price: "My worry is about my
  lifetime license eventually turning into a subscription requirement."
  https://news.ycombinator.com/item?id=43781465 (2025-04-24)
- **TRMNL's paywalls are the most-criticised thing about it** — $35 Clarity Kit gating
  battery/cable/Discord/developer access, $5/mo for sub-15-minute refresh,
  non-refundable purchase. "It feels a little scummy."
  https://studiowallflowr.com/2026/02/18/trmnl-review/ (2026-02-18)
- **Plugin rot is the named long-term risk:** "If support fades (especially among
  community projects) or API changes, plugins become unusable."
  https://notenoughtech.com/review/trmnl/ (2025-09-29)
- **Mudita's own postmortem is the canonical small-run tooling failure**: EU molding
  partner couldn't hit the design, forcing an IP54→IP30/IP42 downgrade and months of
  delay; lesson recorded as "manufacturing certain highly specialized electronic
  equipment in the EU may be very difficult."
  https://mudita.com/community/blog/new-production-schedule-and-unfortunately-further-delay/ (2021-03-11)
- **The brutal-economics postmortem, with numbers.** Chris Greening's ESP32 Rainbow:
  £12,839 raised from 118 backers, COGS £30.60/unit across 280 sellable units,
  Crowd Supply fees $18.76/unit, distributor margins 40–60% forcing a $99 retail on a
  hoped-for $49.99, 435 hours over 13 months, and a **£1,049 loss once labour is
  imputed at minimum wage**. Also: CE/UKCA is mandatory even when using pre-certified
  ESP32 modules; 25% US tariff risk was avoided only by arguing "sufficient
  transformation"; advice is "assume 2.5× COGS" and "allocate 20% for tariffs,
  shipping snafus, and certification surprises."
  https://news.lavx.hu/article/the-brutal-economics-of-hardware-crowdfunding-why-your-99-dev-board-barely-breaks-even (2025-07-22)
  → *For Airo Surface:* a successful campaign at ~236 units still lost money. The
  break-even unit count for indie e-ink hardware is well above what a first campaign
  produces.
- **The India-based e-ink dashboard attempt failed at crowdfunding.** paperd.ink
  needed 300 units to avoid a loss, fell short, and survived only via a FOSS United
  grant funded by Zerodha's CTO. Their own reasoning for avoiding touch e-paper:
  refresh latency makes touch feel broken, and those panels are expensive.
  https://linuxblog.io/why-we-built-paperd-ink-even-after-crowdfunding-failed/ (2022-06-06)
  → *For Airo Surface:* the only India-origin datapoint in this entire research is a
  failed e-ink dashboard crowdfund.
- **Tidbyt: 100,000 units shipped was not enough** to sustain a three-person hardware
  company; acquihired, manufacturing paused.
  https://modal.com/blog/tidbyt-is-joining-modal (2024-11-07)
- **Inkplate/Soldered survived by selling components, not products** — Inkplate 10 is
  a €189.95 dev board with a 9% discount at 100+ units.
  https://soldered.com/products/inkplate-10
- **Inkplate's crowdfunding curve shows the novelty premium decaying:** Inkplate 6
  $131,240 (Feb 2020) → Inkplate 10 $196,535 (Feb 2021) → 6PLUS $69,008 (Jul 2021) →
  **Inkplate 5 only $14,645 against a $10,000 goal (Jul 2023)** → 6MOTION $45,532
  (Jul 2024). https://www.crowdsupply.com/soldered/inkplate-10 and sibling pages
- **Their structural risk is recycled Kindle panels, and they say so:** "recycled
  e-paper displays are hard to come by… some of the salvaged panels cannot be reused
  and must be thrown away. The flex cables often get damaged and must be replaced."
  Inkplate 6 lost 40–50 days purely to panel supply (Spring Festival + COVID + Croatian
  customs), slipping Apr 1 → May 20 → Jul 2.
  https://www.crowdsupply.com/soldered/inkplate-6color/updates/the-challenges-of-obtaining-e-ink-displays-during-a-global-chip-shortage ,
  https://www.crowdsupply.com/e-radionica/inkplate-6/updates/covid-19-delays
  → *No evidence of an Inkplate fulfilment scandal or refund wave was found* — their
  documented pain is sourcing and driver quality, not delivery.
- **Visionect survived by going B2B-only and then de-coupling from its own hardware** —
  sells exclusively to incorporated legal entities, cancelled its earlier
  device-subscription plans in Jan 2023, and Joan now runs on "any other display —
  tablet, LCD TV, or another brand." Joan 6 RE is £299 hardware plus SaaS from €49/month
  (€9.99/mo per extra device); panel is 1024×758, 212 ppi, **750 ms full / 100 ms
  partial** with a front light. Founded 2007, ~80 employees, still independent as of
  2026-08. https://getjoan.com/about-joan/ , https://getjoan.com/shop/joan-6-re/ ,
  https://getjoan.com/pricing/ , https://getjoan.com/plan-cancellation-notice/
- **Visionect's 2016 white paper is the best public "what goes wrong with e-paper
  hardware" document, and a vendor wrote it.** E-paper signage project failure rates
  estimated **as high as 95%**; a functional product takes 1–2 years; inexperience can
  extend development **tenfold**. Named failure modes: moisture buildup inside
  enclosures kills panels; unbonded panels create a greenhouse effect under sun; update
  time and waveform behaviour shift with ambient temperature (20 °C ≠ 25 °C), requiring
  a temperature sensor in the controller. Their conclusion maps exactly onto TRMNL's
  outage: "should the display management infrastructure fail, the signage deployment
  will fail, no matter the quality of the panel hardware."
  https://www.visionect.com/blog/promise-of-electronic-paper/ (2016-04-15)
- **The canonical price objection, from Visionect's founder in 2020, still holds:**
  "we have not found a customer application that could survive the low-volume incurred
  high price of an E Ink solution… when customers get the option of going for a 75"
  color LCD for the price of a 32" E Ink, it's a really tough sell."
  https://news.ycombinator.com/item?id=23022940 (2020-04-30)
- **Mudita, with numbers:** Pure raised $262,506 from 1,042 backers, retail $369, and
  took **~2.5 years to fulfil** — including a QC crisis where **only 34% of a week's
  production passed**. Pure's fatal flaw was RF (undelivered SMS, calls that dial but
  never ring), not e-ink; owners report no replacement batteries after warranty.
  **Kompakt shipped on time** (€353,751 from 1,078 backers, goal hit in 3.5 hours,
  first units 2025-04-24) — and the thing that bought the schedule was scope reduction:
  Kompakt is Android-based with a touchscreen where Pure was a bespoke OS.
  https://www.kickstarter.com/projects/mudita/mudita-pure-your-minimalist-phone ,
  https://mudita.com/community/blog/mudita-pure-shipping-update-more-devices-are-on-the-way/ ,
  https://forum.mudita.com/t/looking-for-honest-feedback-how-reliable-is-mudita-pure-for-daily-use/10368 (2025-07-22),
  https://mudita.com/community/blog/mudita-kompakts-kickstarter-journey-to-success/
- **Boox as a dashboard is disqualified on latency and governance.** Measured typing
  latency at Boox's fastest refresh is **150–275 ms**; colour Boox has no partial
  refresh, producing "a ~20–30 second flashing-hell every time you want to draw
  anything different." Onyx has a decade-old unresolved GPL non-compliance record
  (open since 2016, including allegations of deliberately stripping assembly), and
  Mozilla's *Privacy Not Included* found **no device privacy policy at all**.
  https://tylercipriani.com/blog/2025/03/05/boox-go-10-3-review/ (2025-03-05),
  https://news.ycombinator.com/item?id=48996236 (2026-07-21),
  https://www.mobileread.com/forums/showthread.php?t=277431 ,
  https://www.mozillafoundation.org/en/privacynotincluded/onyx-boox/ (2021-11-08)
- **The Kindle-jailbreak route dies to vendor patching, not engineering.** A user with
  jailbroken Paperwhite + KOReader polling the HA API ("lasted days on a charge") quit
  because "Amazon keeps patching jailbreaks so I can't really buy more of these for
  other rooms." The same thread names the demand driver for e-ink: an iPad HA dashboard
  "constantly emitted light that got annoying at night or during movies" and had to
  stay tethered. https://www.reddit.com/r/homeassistant/comments/1rpoviz/ (2026-03-07)
- **Enclosures are the chronically under-estimated blocker:** "the big problem with
  this sort of thing is that cases are always a disaster."
  https://news.ycombinator.com/item?id=23022940 (2020-04-29)
- **Market-size reality check:** TRMNL's EU competitor Invisible Computers ran a
  Kickstarter with **77 backers**. TRMNL's $157k was the outlier, not the norm.
  https://news.ycombinator.com/item?id=42137513 (2024-11-14)
- **DIY builds take a year of evenings.** A developer's Inkplate 10 calendar project
  ran July 2023 → June 2024 before he called it "done": "GopherCal made me realise how
  long they take, the patience you need to 'finish' one."
  https://www.gouthamve.dev/gophercal-experiments-with-eink/ (2024-06-23)

### r/eink sentiment

- **Price is the #1 complaint, above every technical one.** Top comment on a 611-pt
  Home Assistant e-ink dashboard post: "I love e-ink dashboards. I just expected the
  displays to be a lot cheaper by now" → "for real, it's the only reason I haven't added
  one to my house"; "Same reason for me."
  https://reddit.com/r/homeassistant/comments/1projw9/ (2025-12-20). Also: "I can buy
  three or four Amazon Fire tablets for that price… **Bring the price down to $30–35 and
  we can have a conversation**"; "€260 for a Bluetooth screen is a bit too much."
  https://reddit.com/r/homeassistant/comments/1r605ig/ (2026-02-16)
- **The single most actionable line found in this research**, from a wall-size e-ink
  thread: "**Just give me an affordable, programmable eink panel. I don't need your app
  store. Sell me just the eink module for cheap. I will buy 100s.**" Same thread carries
  the crowdfunding trust damage: "I cannot trust anymore electronics to it. I've been
  burned too many times." https://reddit.com/r/eink/comments/1t8dc2s/ (2026-05-05)
- **Colour is consistently judged not-there-yet.** On Kaleido 3: colours "so far off
  that they're hard to recognize"; dithering "makes everything look like it came off a
  cheap printer that was running out of ink." The fair consensus reply: "I don't think
  anyone thinks color eInk is great. But it's definitely better than not having color."
  Community estimate for acceptable colour: "2 to 5 more years and another generation."
  https://reddit.com/r/eink/comments/1gwwcb1/ (2024-11-21). Independent review confirms:
  muted colours, darker screen with a green tint, front light needed in most
  environments, visible CFA grid texture.
  https://myereader.substack.com/p/kobo-libra-colour-review-e-ink-colour (2024-07-11)
- **Spectra 6 flicker is a household-acceptance problem, not an aesthetic one:** "it is
  ridiculously slow. Something like 12 second refresh time per update, with full screen
  flickering"; "it takes about 15s and blinks quite a lot… **Kind of not wife approved
  yet**"; "my kids ask why it flickers so much, is it broke?"
  https://reddit.com/r/homeassistant/comments/1oqjuk1/ (2025-11-07)
- **Spectra 6 also needs custom tone-mapping to look acceptable** — a maker built an
  open-source library because "dynamic range is quite limited", reporting a blue tint on
  greys and off-whites turning "noisy or yellowish."
  https://reddit.com/r/eink/comments/1txiupw/ (2026-06)
- **Panel refresh-count wear is an unresolved worry among builders**, not a settled
  question: "the eink panels cost a lot and have a finite number of refreshes" — the
  author's answer was essentially "I am interested to see how the display will hold up
  over the years." That same 3,423-pt build lasts only **1–2 weeks at 2-minute
  updates**; a Pi Zero + Waveshare 7.5" user reports "around 40 secs" per update and
  "given how slow it is I gave up."
  https://reddit.com/r/homeassistant/comments/1gtcuqd/ (2024-11-17)
- **Dark-room failure kills use cases outright:** "I love e-ink, especially color, I
  just don't use them as they don't work in dark environments" — and front-lighting a
  wall panel "kind of defeats the purpose of an info panel."
  https://reddit.com/r/homeassistant/comments/1oqjuk1/ (2025-11)
- **Design rule experienced builders repeat:** "always be careful with contrast as
  e-ink displays don't have great contrast already. Black on white is the best…
  **never use white text on black.**" Same thread.
- **Monopoly resentment suppresses projects:** "The fact that they force device
  manufacturers to pay them in order to build new devices is the problem. There are lots
  of project ideas I've had over the years that I think would be great for eink, but
  they are not mainstream enough that I am comfortable buying one." And on why the 2018
  patent expiry changed nothing: "Reinkstone has been quiet for nearly a year, and
  Topjoy for nearly two." https://reddit.com/r/eink/comments/1ll3wxw/ (2025-06-26),
  https://reddit.com/r/eink/comments/1e3icaz/ (2024-07-15)
- **The subreddit's centre of gravity is ereaders, tablets and one-off makes, not
  dashboards.** Top-of-year posts are book collections, tablet AMAs, keychains,
  watches, foldable notebooks — dashboards appear but are a minority genre.
  https://www.reddit.com/r/eink/
- **The clearest abandonment thread is about e-ink notebooks, and the reason is
  problem-fit, not hardware:** "after using it for some time, through Remarkable,
  Supernote and ViWoods, I realised these items didn't solve any real problem for me."
  61 pts, 88 comments.
  https://www.reddit.com/r/eink/comments/1jrwf7l/why_i_eventually_stopped_using_eink/
- **The "distraction-free" pitch is openly rejected inside the community:** "The
  distraction free idea is pure marketing bullshit. On any tablet you can decide to
  make it perfectly distraction free." Same thread.
  → *For Airo Surface:* "calm technology" framing does not survive contact with the
  e-ink audience most likely to buy first.

### Small-run production realities

- **MOQ makes custom hardware unreachable below ~10,000 units.** Good Display's own
  FAQ: standard catalogue panels — "You can purchase one unit." Custom — "you must have
  **100,000 unit** and even more volume." For sizes under 3.5" the "**molding fee is
  about 100,000 US dollars, the MOQ is 500K**." Custom large-size FPC open mould:
  minimum 10K units. Their marketing describes the historical bar as "prohibitively
  high tooling costs (starting from $150,000) and substantial MOQ (1KK pcs)."
  https://www.good-display.com/faq/1.html , https://www.good-display.com/news/234.html (2025-10-11)
  → *For Airo Surface:* below ~10,000 units you buy a standard catalogue panel at
  near-retail. There is no custom industrial design of the panel itself.
- **Bare-panel volume pricing is quote-only.** Good Display and E Ink publish full
  datasheets but no public prices; the Waveshare retail ladder is the only hard price
  data available, and it is retail, not BOM. *(evidence gap)*
- **Certification cost bands for a WiFi device (2026):** pre-certified module →
  **$2,500–5,500, 3–6 weeks**; custom single-band RF → $8,000–20,000, 6–12 weeks;
  chip-down WiFi+BT → $15,000–30,000, 8–16 weeks. Using a pre-cert module "cuts
  certification cost by 60–80% and halves the timeline"; below 50,000 units modules win
  on total cost. FCC's own fees are trivial (~$40 grantee code, $0 SDoC) — the money is
  lab time and TCB. https://markready.io/learn/fcc-certification-cost (2026-04-18)
  *(commercial compliance vendor — treat as industry-consensus range, not an
  independent receipt)*
- **First-pass EMC failure is the budget killer:** "roughly half of consumer
  electronics fail formal EMC testing on the first attempt… That adds $5,000 to $30,000
  and 4 to 12 weeks." Pre-compliance testing at $500–2,000/day drops failure below 10%.
  Same URL.
- **CE/RED lead time** is 4–6 weeks clean on a pre-cert module, 8–12 weeks typical,
  3–6 months with custom RF — plus 2–4 weeks of lab booking queue; labs want 3–5 sample
  units. https://www.aestechno.com/en/ce-red-certification-iot/ (2026-01-04)
- **UKCA is a non-issue**: GB indefinitely recognises CE marking for radio equipment,
  and UKCA may sit on a label rather than the device until 31 Dec 2027.
  https://www.gov.uk/government/publications/radio-equipment-regulations-2017/radio-equipment-regulations-2017-great-britain (updated 2025-12-16)
- **A real e-ink example of certification schedule risk:** Modos was delayed partly
  because "the recent U.S. government shutdown slowed down parts of the certification
  process, including the timeline for our FCC certification."
  https://www.crowdsupply.com/modos-tech/modos-paper-monitor/updates/highlights-certifications-and-production-progress (2025-12-08)
- **Popslate 2 is the case where RF certification killed the company** — raised >$1.1M
  on Indiegogo, prototypes failed Apple's testing because the case material "diminished
  the phone's ability to send and receive RF transmissions," requiring re-tooling it
  couldn't fund. Dissolved, **no refunds**.
  https://www.theverge.com/2017/3/18/14966858/ (2017-03-18)
- **De minimis is gone globally.** The $800 exemption was suspended "regardless of
  value, country of origin, mode of transportation, or method of entry," effective
  29 August 2025, and officials called it permanent.
  https://www.whitehouse.gov/presidential-actions/2025/07/suspending-duty-free-de-minimis-treatment-for-all-countries/ (2025-07-30)
  → *For Airo Surface:* direct-to-consumer hardware shipping into the US no longer has
  a small-parcel escape hatch.
- **The tariff problem is volatility, not level.** The 2025 reciprocal rate on China ran
  10% (Apr 5) → 84% (Apr 9) → 125% (Apr 10–May 13) → 10% (May 14). Anyone who placed a
  PO in that window could not price their product. Current China baseline as of Nov 2025
  is ~20% before Section 301 and any Section 232.
  https://www.cbp.gov/trade/programs-administration/trade-remedies/IEEPA-FAQ ,
  https://www.cbp.gov/sites/default/files/2026-02/U.S.%20Tariff%20Overview%20February%202026_0.pdf (Feb 2026)
- **Tariff paralysis, documented live by an e-ink project:** Zerowriter Ink postponed
  fulfilment writing "nobody really has any answers… everything seems to change
  week-by-week. Or even day-by-day."
  https://www.crowdsupply.com/zerowriter/zerowriter-ink/updates/ (2025-04-23)
- **The structural maker complaint** (bunnie huang): Section 301 taxed "basic
  components, tools and sub-assemblies, while giving fully assembled goods a free pass,"
  which "pushes business owners to send these 'last screw' operation overseas."
  https://www.bunniestudios.com/blog/2018/new-us-tariffs-are-anti-maker-and-will-encourage-offshoring/ (2018-06-18)
  → *For Airo Surface:* the tariff code penalises assembling in the destination market.
- **The brutal-economics postmortem, with numbers.** Chris Greening's ESP32 Rainbow:
  £12,839 raised from 118 backers, COGS £30.60/unit across 280 sellable units,
  Crowd Supply fees $18.76/unit, distributor margins 40–60% forcing a $99 retail on a
  hoped-for $49.99, 435 hours over 13 months, and a **£1,049 loss once labour is imputed
  at minimum wage**. CE/UKCA was mandatory even with pre-certified ESP32 modules; 25% US
  tariff risk was avoided only by arguing "sufficient transformation." Advice: "assume
  2.5× COGS" and "allocate 20% for tariffs, shipping snafus, and certification
  surprises."
  https://news.lavx.hu/article/the-brutal-economics-of-hardware-crowdfunding-why-your-99-dev-board-barely-breaks-even (2025-07-22)
- **Fulfilment slips are the norm, not the exception.** Modos Paper Monitor: $197,588
  raised, campaign closed Sept 2025, first shipment Feb 2026, new orders quoting
  **28 Jul 2026** — and "around half of the 6" panels we received didn't meet our quality
  standards."
  https://www.crowdsupply.com/modos-tech/modos-paper-monitor/updates/progress-on-shipping-cases-and-firmware (2026-04-01).
  Zerowriter's enclosure bottleneck forced batch fulfilment at ~150 units/month.
  https://www.crowdsupply.com/zerowriter/zerowriter-ink/updates/new-timelines-new-features
- **The worst case: CST-01 e-ink watch** raised >$1M on Kickstarter (2013), told backers
  in 2015 it couldn't ship, and went bankrupt with **$30,000 in assets against $891,563
  in liabilities**. https://www.theverge.com/2016/5/5/11595666/ (2016-05-05)
- **The India-origin datapoint is a failure.** paperd.ink needed 300 units to avoid a
  loss, fell short at crowdfunding, and survived only on a FOSS United grant funded by
  Zerodha's CTO. Their reason for avoiding touch e-paper: refresh latency makes touch
  feel broken, and those panels are expensive.
  https://linuxblog.io/why-we-built-paperd-ink-even-after-crowdfunding-failed/ (2022-06-06)

---

## Strongest signals

1. **The category monetizes, at appliance prices, and is already owned.** ~888,000
   Skylight-owning families, 9.3M users, 99% YoY revenue growth, bootstrapped, $50M debt
   facility, Costco/Sam's distribution. This is not an unproven market — it is a market
   with a well-capitalised incumbent.
   https://www.seattletimes.com/business/can-a-700-calendar-save-your-marriage/ (2025-06-01)
2. **Ambient displays reliably solve visibility and reliably fail at participation.**
   Every long-term happy household in this evidence had buy-in *before* the purchase;
   every abandonment traces to expecting the device to create it. Top comment, 261
   upvotes: "if your husband won't use a free shared calendar, why would he use the
   expensive shared calendar? This is a husband problem, not a product problem."
   https://reddit.com/r/workingmoms/comments/1korcmg/does_anyone_use_one_of_those_fancy_calendars_like/ (2025-05-17)
3. **Only three features survive 12 months: shared calendar, kid routines, shared
   lists.** Meal planning, feelings check-ins, AI import and chore/reward economies all
   decay — chore systems die when kids pass ~11 or when logging is harder than doing.
   https://reddit.com/r/HerWellness/comments/1vgicck/hearth_review_one_year_in_what_we_actually_use/ (2026-08-05)
4. **The widget layer has a hard ~10% adoption ceiling and a low monetization ceiling.**
   Google's only public number: 25% retention lift for widget users, but only 10% of DAU
   adopt. KWGT converts ~5% lifetime at $6.99 one-time. Widgetsmith's own developer says
   churn, not signup, is the binding constraint on 131M downloads.
   https://android-developers.googleblog.com/2026/05/how-gratitude-widgets-boosted-user-retention-25-percent.html ,
   https://david-smith.org/blog/2023/01/12/churn (2023-01-12)
5. **Big tech has vacated or is actively degrading the ambient home display.** Meta
   Portal dead (2022), Nest Hub with no hardware since 2021 and Assistant degrading,
   Nest Hub Max out of stock, and Echo Show now carrying undisableable full-screen ads
   that owners are unplugging over. That is a real, dated, quotable opening.
   https://www.theverge.com/report/797672/amazon-echo-show-ads-alexa-plus (2025-10-09)
6. **Subscription resistance is loud, and it has a specific trigger.** People do pay
   $79–108/yr. What they refuse is *undisclosed*, *setup-blocking*, or
   *hard-to-cancel*: "we refused to pull the trigger when we saw the word
   'subscription'"; Hearth requires membership to complete setup; TRMNL's fee for
   developer access to its own "open source" device is called "scummy" in reviews.
   https://reddit.com/r/BuyItForLife/comments/1t5i5le/digital_wall_calendar_recommendations/ (2026-05-06),
   https://studiowallflowr.com/2026/02/18/trmnl-review/ (2026-02-18)
7. **The most actionable design failure found is the idle state.** Skylight has no
   presence sensor, so its photo screensaver hides the calendar and the device becomes
   literal wallpaper. "Turn off the wallpaper. Not kidding. It defeats the point."
   The corresponding fix the HA community converged on is relevance-gated content:
   "only show at relevant times… the only things that show all the time are time,
   weather, and indoor temperature."
   https://reddit.com/r/skylightcalendar/comments/1pddvwp/was_excited_for_skylight_but_one_feature_tanked/ (2025-12-03),
   https://reddit.com/r/homeassistant/comments/1vdy207/are_we_building_the_wrong_thing_for_our_wall_tablets/
8. **E-ink hardware economics are bounded by two facts that will not move soon.** A
   13.3" colour panel costs ~$250 at retail and takes 19–25s to redraw with visible
   flicker; and deep sleep invalidates the driver's frame buffer, so battery-powered
   designs are forced into full refreshes. E Ink is capacity-constrained and states it
   is "reluctant to lower prices." Meanwhile Tidbyt shipped 100,000 units and still had
   to be acquihired, and a "successful" £12,839 indie campaign lost money once labour
   was counted.
   https://www.digitimes.com/news/a20250814PD224/e-ink-demand-esl-production-earnings.html (2025-08-15),
   https://modal.com/blog/tidbyt-is-joining-modal (2024-11-07),
   https://news.lavx.hu/article/the-brutal-economics-of-hardware-crowdfunding-why-your-99-dev-board-barely-breaks-even (2025-07-22)

---

## Where the evidence is weak or missing

**Retention data does not exist anywhere.**
- No vendor publishes churn, cohort retention, or 12-month active rate for any product
  in this category. All longitudinal evidence is a few dozen self-selected Reddit
  anecdotes, and the ones inside r/skylightcalendar are structurally biased toward
  retained users — people who quit leave the subreddit.
- The 6–12 month evidence bucket holds roughly a dozen genuinely dated accounts, against
  dozens of pre-purchase "is it worth it" posts. That ratio is suggestive, not
  conclusive.
- The 888,000 figure is founder-stated to a journalist, unaudited, and counts *owners*,
  not active users. Hearth's "40,000+ families" is unverified marketing copy.

**Reddit in this category is contaminated by marketing.** Several "comparison" and
"review" posts drew accusations of being ads. Vendor-subreddit dissent and hostile-sub
threads (r/smarthome, r/Costco, r/workingmoms) were weighted higher for this reason. The
2026-08 Hearth one-year review sits in a low-traffic sub with 2 upvotes.

**India is effectively unresearched, and probably unresearchable right now.** No
Indian-language or India-context discussion of family wall displays, fridge calendars or
chore charts was found on Reddit or the web. Skylight and Hearth do not ship there. The
IMARC market-size figure is a commercial research report with no public methodology. The
only India-origin datapoint in the whole study is paperd.ink, a failed crowdfund. Any
India claim in this report is inference, not evidence.

**Apple publishes nothing on widget engagement.** No adoption number, no DAU, no
retention claim — only the WidgetKit refresh-budget doc. This is a genuine gap, not a
search failure. The iOS-side qualitative evidence leans on a self-selected TidBITS
reader poll and HN threads.

**Samsung is a blind spot.** No usage data for Modes & Routines; Daily Board appears
effectively dead (the only substantive result is a 2024 crash thread on an app users
can no longer uninstall). Samsung's current ambient bet reads as the Now Bar, not a
dashboard.

**No widget-app retention/DAU data exists publicly** for Widgetsmith, KWGT, Chronus or
Overdrop. The KWGT ~5% conversion figure is inferred from bucketed Play install counts
plus AppBrain velocity estimates. The Chronus revenue estimate is an unverified ML
guess. No direct user complaint about Widgetsmith's $19.99/yr was found — absence of
evidence, not evidence of absence.

**Two widget-platform sources are title-verified only.** The r/androiddev exact-alarm
thread and an r/swift WidgetKit-workaround thread were hit by Reddit rate-limiting
before their comments could be read; titles, scores and dates come from the search
index, the comment content does not.

**No post-mortem thread on abandoned e-ink dashboards exists.** Searches across r/eink,
r/homeassistant, r/esp32 and r/raspberry_pi for "stopped using", "gathering dust",
"regret", "abandoned" returned only build showcases. The abandonment signal for DIY
e-ink is indirect — a steady stream of "yet another e-ink dashboard" posts with
near-zero follow-up, plus isolated "I gave up" comments. Suggestive, not proof.

**Hardware economics are partly opaque.** No public unit economics or margin for TRMNL —
any COGS claim is inference from $139 retail against their own $58–105 BOM estimate. No
public volume pricing from Good Display or E Ink; the Waveshare retail ladder is the
only hard price data and it is retail, not BOM. Visionect has no public financials;
"still alive" rests on their own about page. Certification cost bands come from a
commercial compliance vendor. Tariff percentages are volatile and should be re-checked
against CBP before use.

**Panel refresh-count lifetime has no manufacturer-published cycle rating.** Builders
worry about it openly; no vendor answers it. This determines service life and is
genuinely unknown.

**No documented Inkplate fulfilment failure or refund wave.** Their documented pain is
component sourcing and driver quality. Treat "Inkplate delivery scandal" as unsupported.

**No FTC action or class action** was found against Skylight or Hearth. BBB complaint
volume against Skylight's parent is 6. The cancellation-friction complaints are real but
not a regulatory-scale pattern.
