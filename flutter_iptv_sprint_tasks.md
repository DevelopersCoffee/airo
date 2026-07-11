# Flutter IPTV - Sprint Task Breakdown

**Quick Reference for Team Coordination**

---

## Sprint 0: Technical Spikes (Week 1)

### Media Engine Engineer

**Spike 1.1: media_kit Playback Proof-of-Concept**
- [ ] Create bare-bones Flutter app
- [ ] Initialize `MediaKit.ensureInitialized()`
- [ ] Compile on iOS simulator + Android device
- [ ] Test playback:
  - [ ] `.m3u8` (HLS) stream
  - [ ] `.ts` (Transport Stream)
  - [ ] Audio-only radio stream
- [ ] Custom User-Agent header support
- [ ] Logs/metrics: Playback quality, codec detection

**Success Metric:** All three stream types play smoothly without stuttering

---

### Backend & Systems Engineer

**Spike 1.2: Isolate-Based Parsing Pipeline**
- [ ] Create Dart Isolate for background work
- [ ] Generate 100MB dummy XMLTV file
- [ ] Implement streaming XML parser using `xml_events`
- [ ] Parse and insert into `drift` SQLite DB
- [ ] Monitor main thread frame rate (should stay 60fps)
- [ ] Measure: Parse time, memory peak, UI responsiveness

**Success Metric:** 100MB XMLTV parses while UI spins CircularProgressIndicator at 60fps

---

### UI/UX Engineer

**Spike 1.3: Mobile Search & Navigation Prototype**
- [ ] Create Figma wireframe: Bottom-sheet search
- [ ] Map user flow:
  - User taps search → opens bottom sheet
  - Type channel name (live filtering)
  - Tap result → player launches
  - Close player → search state preserved
  - Back button → search text still visible
- [ ] One-handed navigation emphasis
- [ ] Present to PM for feedback

**Success Metric:** Clickable Figma prototype approved; identifies UX risks early

---

## Sprint 1: Core Foundation (Weeks 2-5)

### Backend & Systems Engineer

#### Epic 1.1: Database Schema & Drift Setup
- [ ] **Task 1.1.1:** Create Drift AppDatabase with tables:
  - `Playlists`
  - `Channels`
  - `EpgPrograms`
  - `UserPreferences`
- [ ] **Task 1.1.2:** Configure WAL mode + synchronous=NORMAL
- [ ] **Task 1.1.3:** Implement basic CRUD repositories:
  - `PlaylistRepository`
  - `ChannelRepository`
  - `UserPreferencesRepository`
- [ ] **Task 1.1.4:** Write unit tests for DB operations
- **Deadline:** End of Week 2
- **Dependencies:** None (standalone task)
- **Output Artifact:** `lib/infrastructure/database/` folder

---

#### Epic 1.2: M3U Parser & Isolate Integration
- [ ] **Task 1.2.1:** Port TypeScript M3U parser to Dart
  - Extract `#EXTINF` tags
  - Parse proprietary fields: `tvg-id`, `tvg-logo`, `group-title`
  - Handle malformed lines gracefully
  - Unit tests for parser correctness
- [ ] **Task 1.2.2:** Implement `PlaylistIngestionService`:
  - Spawn Dart Isolate for parsing
  - Batch insert into DB (500 channels per transaction)
  - Report progress via Stream
  - Support cancellation
- [ ] **Task 1.2.3:** Integration test: Parse 50k-line M3U in <2 seconds
- **Deadline:** End of Week 3
- **Dependencies:** Epic 1.1 (DB schema)
- **Output Artifact:** `lib/domain/services/playlist_ingestion_service.dart`

---

### Media Engine Engineer

#### Epic 1.3: media_kit Integration & Basic Playback
- [ ] **Task 1.3.1:** Initialize media_kit in `main.dart`
  - `MediaKit.ensureInitialized()` before `runApp()`
  - Platform-specific setup (iOS/Android/Web)
- [ ] **Task 1.3.2:** Implement `MediaService` abstraction:
  - `openStream(Channel)`
  - `play()`, `pause()`, `seek()`
  - Stream: `position`, `duration`, `isPlaying`
- [ ] **Task 1.3.3:** Test on real devices:
  - iOS: iPhone 12+, iOS 14+
  - Android: Pixel 4+, Android 10+
  - Codec support verification
- [ ] **Task 1.3.4:** User-Agent header support (critical for IPTV providers)
- **Deadline:** End of Week 4
- **Dependencies:** None
- **Output Artifact:** `lib/domain/services/media_service.dart`

---

### UI/UX Engineer

#### Epic 1.4: State Management Foundation (Riverpod)
- [ ] **Task 1.4.1:** Setup Riverpod providers:
  - `activePlaylistProvider`
  - `activePlaylistChannelsProvider`
  - `searchQueryProvider`
  - `currentChannelProvider`
  - `playerStateProvider`
- [ ] **Task 1.4.2:** Dependency injection for repositories + services
  - `playlistRepositoryProvider`
  - `channelRepositoryProvider`
  - `mediaServiceProvider`
- [ ] **Task 1.4.3:** Unit tests for state transitions
- [ ] **Task 1.4.4:** Document provider hierarchy (diagram)
- **Deadline:** End of Week 2
- **Dependencies:** Epic 1.1 (repositories)
- **Output Artifact:** `lib/presentation/providers/`

---

#### Epic 1.5: Dashboard & Channel List Screens
- [ ] **Task 1.5.1:** Implement Dashboard Screen:
  - Persistent search bar at top
  - "Continue Watching" section
  - "Favorites" grid
  - Category carousel
  - Acceptance: Search state preserved on navigation
- [ ] **Task 1.5.2:** Implement Channel List Screen:
  - Stream-built list (no blocking)
  - Fuzzy search <50ms
  - Long-press actions: Favorite, Hide category
  - Pull-to-refresh (prep for Xtream)
- [ ] **Task 1.5.3:** Navigation setup (go_router)
  - Route hierarchy
  - State preservation
- [ ] **Task 1.5.4:** Widget tests for layout responsiveness
- **Deadline:** End of Week 5
- **Dependencies:** Epic 1.4 (Riverpod), Epic 1.3 (media_service)
- **Output Artifact:** `lib/presentation/screens/`

---

### All Team Members

#### Integration Checkpoint (End of Week 5)
- **Deliverable:** Internal build on TestFlight (iOS) + Staging (Android)
- **User Flow:** Add M3U URL → Search channel → Tap → Player plays stream
- **Acceptance:**
  - [ ] App compiles without errors
  - [ ] M3U URL ingestion works (no crashes)
  - [ ] Search functional
  - [ ] Player launches and plays stream
  - [ ] No major UI glitches
  - [ ] Frame rate stays 60fps during channel load

---

## Sprint 2: Feature Expansion (Weeks 6-9)

### Backend & Systems Engineer

#### Epic 2.1: Xtream Codes API Client
- [ ] **Task 2.1.1:** Implement `XtreamService` with endpoints:
  - `getLiveCategories()`
  - `getLiveStreams(categoryId)`
  - `getVodCategories()`
  - `getVodStreams(categoryId)`
  - `getSeriesCategories()`
  - `getSeriesInfo(seriesId)`
- [ ] **Task 2.1.2:** Lazy-loading strategy:
  - Fetch categories only, not all streams upfront
  - Cache category metadata (24-hour TTL)
  - Fetch streams on-demand when user taps category
- [ ] **Task 2.1.3:** Error handling + retry logic:
  - 401: Auth failure message
  - 429: Rate limiting (exponential backoff)
  - Network errors: Offline message
- [ ] **Task 2.1.4:** Unit tests with mock Xtream responses
- **Deadline:** End of Week 6
- **Dependencies:** Epic 1.1 (DB)
- **Output Artifact:** `lib/domain/services/xtream_service.dart`

---

#### Epic 2.2: XMLTV EPG Parser & Background Sync
- [ ] **Task 2.2.1:** Implement streaming XMLTV parser (`xml_events`):
  - Consume event tokens, not DOM
  - Extract program info: title, start/end, description
  - Handle missing/malformed entries gracefully
- [ ] **Task 2.2.2:** `EpgRepository` for CRUD:
  - `upsertPrograms(List<EpgProgram>)`
  - `getProgramsForChannel(tvgId, date)`
  - `watchProgramsForChannel()` for reactive UI
- [ ] **Task 2.2.3:** Workmanager background task:
  - Schedule EPG sync every 12 hours (Android)
  - iOS: Manual sync on app open (if sync >12h old)
  - Show progress notification
  - Retry on failure (next scheduled time)
- [ ] **Task 2.2.4:** Integration test: Parse 100MB XMLTV without OOM
- **Deadline:** End of Week 7
- **Dependencies:** Epic 1.1 (DB), Epic 1.2 (Isolates)
- **Output Artifact:** `lib/domain/services/epg_parser.dart`, `lib/infrastructure/background_tasks/`

---

### Media Engine Engineer

#### Epic 2.3: Catch-Up & Timeshift (VOD Playback)
- [ ] **Task 2.3.1:** Implement `CatchupService`:
  - Generate catch-up URL with UTC timestamps
  - Format: `{streamUrl}?utc=START&lutc=END`
  - Support different provider formats
- [ ] **Task 2.3.2:** Integration with EPG:
  - When user taps past program, generate catch-up URL
  - Pass to media_kit for playback
  - Show "Program expired" if >7 days old
- [ ] **Task 2.3.3:** Test on real Xtream portal if available
- **Deadline:** End of Week 6
- **Dependencies:** Epic 2.2 (EPG), Epic 1.3 (media_service)
- **Output Artifact:** `lib/domain/services/catchup_service.dart`

---

#### Epic 2.4: Casting Integration (mDNS + Chromecast)
- [ ] **Task 2.4.1:** Implement `CastingService`:
  - Discover Chromecast devices via mDNS (`mdns_sd`)
  - Store device list in provider stream
  - Handle device disconnection
- [ ] **Task 2.4.2:** Casting flow:
  - User taps cast icon in player
  - Show bottom sheet with discovered devices
  - Tap device → initiate cast
  - Show "Casting to Device X" indicator
- [ ] **Task 2.4.3:** V1 Scope (defer to V2):
  - Single-device casting only
  - Public IPTV streams only
  - No multi-device orchestration
  - No local file casting
- [ ] **Task 2.4.4:** Test on Sony Bravia TV + Chromecast dongle
- **Deadline:** End of Week 8
- **Dependencies:** Epic 2.3 (media_service)
- **Output Artifact:** `lib/domain/services/casting_service.dart`

---

### UI/UX Engineer

#### Epic 2.5: EPG Grid Screen
- [ ] **Task 2.5.1:** Implement EPG Grid layout:
  - Horizontal time header (30-min slots, 2-week span)
  - Vertical channel list (scrollable)
  - EPG program cells (tap to play catch-up)
- [ ] **Task 2.5.2:** Interactions:
  - Horizontal scroll: Change time
  - Vertical scroll: Change channel
  - Tap program: Trigger catch-up playback
  - Date navigator: Switch between today, tomorrow, +7 days
- [ ] **Task 2.5.3:** Performance optimization:
  - Lazy-build grid (only visible cells)
  - Cache program images
  - Prefetch adjacent weeks
- [ ] **Task 2.5.4:** Acceptance:
  - 100+ channels, 2-week EPG loads <500ms
  - Scrolling smooth (60fps)
  - No jank on low-end device (Pixel 3)
- **Deadline:** End of Week 8
- **Dependencies:** Epic 2.2 (EPG), Epic 1.4 (Riverpod)
- **Output Artifact:** `lib/presentation/screens/epg_screen.dart`

---

#### Epic 2.6: VOD/Series Screens (Pagination & Detail Sheet)
- [ ] **Task 2.6.1:** VOD Grid with pagination:
  - Use `PagingController` (infinite_scroll_pagination)
  - Load 50 movies at a time
  - Lazy image caching (`cached_network_image`)
  - Memory limit: 100MB max image cache
- [ ] **Task 2.6.2:** VOD Detail Sheet:
  - Tap poster → bottom sheet (not full screen)
  - Show: Title, synopsis, cast, rating, poster
  - Play button → launch player
- [ ] **Task 2.6.3:** Series Detail Sheet:
  - Season dropdown
  - Episode list (scrollable)
  - Tap episode → player
- [ ] **Task 2.6.4:** Testing:
  - Load 1000+ VOD items without crash
  - Verify image cache limits on low-end device
  - No OOM on pagination
- **Deadline:** End of Week 9
- **Dependencies:** Epic 2.1 (Xtream), Epic 1.3 (media_service)
- **Output Artifact:** `lib/presentation/screens/vod_screen.dart`

---

#### Epic 2.7: Player Gesture Overlay
- [ ] **Task 2.7.1:** Immersive Mode UI:
  - Single tap video → toggle all overlays
  - When hidden: Just video + system UI hidden
  - When visible: Play/pause, seek bar, title, cast button
- [ ] **Task 2.7.2:** Gesture Handlers:
  - Left swipe (left 1/3): Brightness ±
  - Right swipe (right 1/3): Volume ±
  - Horizontal swipe (center): Seek VOD (disabled for live)
  - Double tap: Play/pause
  - Long press: Show EPG for channel
- [ ] **Task 2.7.3:** Visual Feedback:
  - Show brightness/volume %age during swipe
  - Animated seek indicator
  - Haptic feedback on swipes (optional)
- [ ] **Task 2.7.4:** Acceptance:
  - All gestures responsive (<200ms latency)
  - Overlay toggle instant
  - Brightness/volume swipes intuitive (tested with 3+ users)
- **Deadline:** End of Week 9
- **Dependencies:** Epic 1.5 (player screen)
- **Output Artifact:** `lib/presentation/widgets/player_overlay.dart`

---

### All Team Members

#### Integration Checkpoint (End of Week 9)
- **Deliverable:** Beta build with feature parity to desktop v0.21
- **User Flow:** Add Xtream → Browse live + VOD → View EPG → Cast to TV
- **Acceptance:**
  - [ ] Xtream credentials validated
  - [ ] Categories load without blocking
  - [ ] EPG shows 2-week grid
  - [ ] VOD pagination works smoothly
  - [ ] Casting discovers + casts successfully
  - [ ] No crashes on 50k+ channel load
  - [ ] 100MB XMLTV sync without OOM
  - [ ] Performance: Gesture latency <200ms, search <50ms

---

## Sprint 3: Polish & Testing (Weeks 10-12)

### All Roles

#### Epic 3.1: Testing & Stability
- [ ] **Task 3.1.1:** Performance testing suite:
  - 50k-channel playlist load + search
  - 100MB XMLTV parse + EPG display
  - VOD pagination (1000+ items)
  - Measure: Frame rate, memory peak, CPU usage
  - Devices: iPhone 12, Pixel 4, Pixel 3 (low-end baseline)
- [ ] **Task 3.1.2:** E2E testing:
  - Add M3U → Search → Play → Close → Search preserved
  - Add Xtream → Browse categories → Tap stream → Cast
  - Sync EPG in background → Open app → EPG ready
  - Play VOD → Seek → Close → Resume playback
- [ ] **Task 3.1.3:** Regression testing:
  - Xtream issues from desktop v0.21 (Issue #1048)
  - M3U parsing edge cases (malformed entries)
  - Navigation state loss (v0.20 bug)
- **Deadline:** End of Week 10
- **Dependencies:** All previous epics

---

#### Epic 3.2: Gesture & UX Refinement
- [ ] **Task 3.2.1:** Gesture tuning:
  - Test brightness/volume swipes on 5+ users
  - Adjust sensitivity if needed
  - Gather feedback: Intuitive? Responsive?
- [ ] **Task 3.2.2:** One-handed usability:
  - Verify all critical buttons within thumb reach
  - Test on various phone sizes
  - Document safe zones
- [ ] **Task 3.2.3:** Accessibility:
  - VoiceOver support (iOS)
  - TalkBack support (Android)
  - Minimum text size: 14pt
  - Color contrast: WCAG AA
- **Deadline:** End of Week 11
- **Dependencies:** Sprint 2 UI epics

---

#### Epic 3.3: In-App Purchases (Premium Paywall)
- [ ] **Task 3.3.1:** IAP Configuration:
  - Free tier: 1 playlist, basic features
  - Premium tier: Unlimited playlists, EPG, casting
  - App Store Connect setup
  - Google Play Console setup
- [ ] **Task 3.3.2:** IAP UI:
  - Paywall screen showing features/tiers
  - Purchase flow
  - Restore purchases
  - Show "Premium" badge in UI
- [ ] **Task 3.3.3:** Compliance:
  - Apple policies (clear cancellation)
  - Google policies (refund info)
  - GDPR/Privacy considerations
- **Deadline:** End of Week 11
- **Dependencies:** None (independent)

---

#### Epic 3.4: App Store Readiness
- [ ] **Task 3.4.1:** App Store metadata:
  - 5 screenshots per platform (both orientations)
  - App description (200 chars)
  - Changelog (V1.0 release notes)
  - Keywords (IPTV, streaming, TV guide, etc.)
  - Privacy policy (link to web version)
- [ ] **Task 3.4.2:** Google Play metadata:
  - Same screenshots + 1-2 preview videos (30s)
  - Full description (4000 chars)
  - Category (Entertainment/Video Players)
  - Content rating questionnaire
  - Privacy policy link
- [ ] **Task 3.4.3:** App Icons:
  - 1024x1024 base
  - Platform-specific adaptations
  - Accessibility color contrast
- [ ] **Task 3.4.4:** Privacy Policy:
  - Data collection (playlist URLs, watch history)
  - Third-party services (analytics, crash reporting)
  - GDPR/CCPA compliance
- **Deadline:** End of Week 12
- **Dependencies:** None (can be parallel)

---

#### Epic 3.5: Bug Fixes & Stability
- [ ] **Task 3.5.1:** Known issues from beta:
  - Triage bug reports
  - Assign to engineers
  - Fix critical issues (crash/data loss)
  - Defer minor UX issues to V1.1
- [ ] **Task 3.5.2:** Edge case handling:
  - No internet: Show cached channels
  - Invalid credentials: Clear error message
  - Large playlists (100k+ channels): Performance
  - Low memory device: Image cache limits
- [ ] **Task 3.5.3:** Logging & crash reporting:
  - Firebase Crashlytics setup
  - Error messages sent to backend (with consent)
  - Analytics: Feature usage, performance metrics
- **Deadline:** End of Week 12
- **Dependencies:** All previous epics

---

### All Team Members

#### Final Checkpoint (End of Week 12)
- **Deliverable:** TestFlight (iOS) + Google Play Console Internal Track (Android)
- **Acceptance:**
  - [ ] Zero crash rate over 24-hour beta
  - [ ] All features from requirements working
  - [ ] Performance meets targets (60fps, <2s load, <50ms search)
  - [ ] App Store metadata complete
  - [ ] Legal/privacy compliance verified
  - [ ] IAP working on both platforms
  - [ ] 5+ internal testers signed off

---

## Sprint 4: Public Launch (Week 13)

### Product Manager + Engineering Lead

#### Epic 4.1: App Store Submission
- [ ] **Task 4.1.1:** Apple App Store:
  - Submit build to TestFlight reviewers
  - Review process (typically 24-48 hours)
  - Respond to reviewer questions if any
  - Approve for production release
- [ ] **Task 4.1.2:** Google Play Store:
  - Submit build for review
  - Set rollout strategy (5% → 50% → 100%)
  - Monitor crash rate in Play Console
  - Auto-escalate to 100% after 48 hours (if stable)
- [ ] **Task 4.1.3:** Release notes:
  - "V1.0: Initial release"
  - Feature summary (M3U, Xtream, Stalker, EPG, casting)
  - Known limitations (V1 scope)
- **Deadline:** Week 13 (Mon-Tue)

---

#### Epic 4.2: Go-Live Monitoring
- [ ] **Task 4.2.1:** First 48 hours:
  - Monitor Crashlytics daily
  - Track user acquisition/retention
  - Check 1-star reviews for critical issues
  - Have rollback plan if crash rate >2%
- [ ] **Task 4.2.2:** Communication:
  - Twitter/Reddit post: "V1.0 live"
  - Developer blog post: Technical deep dive
  - Newsletter: Announce to users (DevelopersCoffee list)
- [ ] **Task 4.2.3:** Post-launch roadmap:
  - V1.1: Bug fixes + minor UX improvements
  - V2: Multi-device orchestration, local file casting, advanced search
  - V3: AI-powered recommendations, cross-device sync
- **Deadline:** Week 13 (Wed onwards)

---

## Cross-Sprint Risks & Mitigation

| Risk | Mitigation | Owner |
|------|-----------|-------|
| EPG OOM on old phones | Strict image cache limits (100MB), stream parse XMLTV | Backend Eng |
| Xtream parsing regressions | Regression test suite against known bad portals | Backend Eng |
| Search state loss during nav | Riverpod StateProvider, don't clear on navigate | Frontend Eng |
| Casting discovery slow | 2-second timeout, "No devices" fallback UI | Media Eng |
| Media codec gaps on Android | Use media_kit (libmpv), test on API 21+ | Media Eng |
| iOS background sync fails | Manual sync fallback on app open | Backend Eng |

---

## Dependency Graph

```
Sprint 0 (Spikes):
  ├─ Media Engine Spike (async, independent)
  ├─ Data Pipeline Spike (async, independent)
  └─ Wireframing Spike (async, independent)

Sprint 1:
  ├─ Epic 1.1 (DB Schema) ← foundation
  │   ├─ Epic 1.2 (M3U Parser) ← depends on 1.1
  │   └─ Epic 1.4 (Riverpod) ← depends on 1.1
  ├─ Epic 1.3 (media_kit) ← independent
  └─ Epic 1.5 (UI Screens) ← depends on 1.3, 1.4

Sprint 2:
  ├─ Epic 2.1 (Xtream) ← depends on 1.1
  ├─ Epic 2.2 (EPG) ← depends on 1.1, 1.2
  ├─ Epic 2.3 (Catchup) ← depends on 2.2, 1.3
  ├─ Epic 2.4 (Casting) ← depends on 1.3
  ├─ Epic 2.5 (EPG Grid) ← depends on 2.2, 1.4
  └─ Epic 2.6 (VOD) ← depends on 2.1

Sprint 3:
  └─ All epics ← depends on Sprint 2 completion

Sprint 4:
  └─ Launch ← depends on Sprint 3 QA sign-off
```

---

## Team Size & Allocation

**Ideal team:** 3 full-time engineers
- **Backend & Systems Engineer:** 1 FTE
- **Media Engine Engineer:** 1 FTE
- **UI/UX & Frontend Engineer:** 1 FTE
- **Product Manager:** 0.5 FTE (oversight, coordination)
- **QA/Testing:** 0.5 FTE (parallel to dev, ramp up in Sprint 3)

**Total Sprint Duration:** 13 weeks (3.25 months)

---

## Success Metrics

**Product Launch (V1.0):**
- ✅ Supports M3U, Xtream, Stalker playlists
- ✅ EPG (TV Guide) with catch-up capability
- ✅ Casting to Chromecast + AirPlay
- ✅ VOD/Series browsing with pagination
- ✅ Zero crashes (QA sign-off)
- ✅ 60fps playback + <50ms search

**Business Launch:**
- ✅ App Store + Google Play live
- ✅ 1000+ installs in first week
- ✅ <2% crash rate (first 48h)
- ✅ >4.0 avg rating (50+ reviews)
- ✅ Premium tier adoption >10%

---

**End of Sprint Task Breakdown**
