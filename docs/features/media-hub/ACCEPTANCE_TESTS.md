# Media Hub Acceptance Test Cases

## Overview

Platform-specific acceptance test cases for the unified Music + TV Streaming surface, aligned with PRD requirements.

---

## Test Categories

1. **[CP]** Cross-Platform (must pass on all platforms)
2. **[WEB]** Web-specific
3. **[AND]** Android-specific
4. **[IOS]** iOS-specific

---

## 1. Hero Player Area Tests

### [CP-HP-001] Player Default Height
**Given:** User navigates to Media Hub  
**When:** Page loads with no content playing  
**Then:** Player area occupies ~65-70% of typical full height (200px mobile, 280px tablet)

### [CP-HP-002] Player Collapse on Scroll
**Given:** Content is playing in hero player  
**When:** User scrolls down the discovery content  
**Then:** Player smoothly collapses to minimum height  
**And:** Animation duration is ~300ms with easeOutCubic curve

### [CP-HP-003] Player Expand to Fullscreen
**Given:** Player is in collapsed state  
**When:** User taps fullscreen button  
**Then:** Player expands to fullscreen mode  
**And:** System UI is hidden (platform-specific)

### [CP-HP-004] Overlay Controls Visibility
**Given:** Content is playing  
**When:** User taps on player area  
**Then:** Overlay controls appear with fade animation  
**And:** Controls auto-hide after 4 seconds of inactivity

### [CP-HP-005] Play/Pause Toggle
**Given:** Content is playing  
**When:** User taps Play/Pause button  
**Then:** Playback toggles correctly  
**And:** Button icon updates immediately

### [CP-HP-006] Favorite Toggle
**Given:** Any content is playing  
**When:** User taps Favorite button  
**Then:** Favorite state toggles  
**And:** Content appears in/disappears from Favorites section

### [CP-HP-007] Settings Panel Opens
**Given:** Content is playing with controls visible  
**When:** User taps Settings button  
**Then:** Settings bottom sheet opens  
**And:** Shows Quality, Audio Language (if available), Playback Speed (Music only)

### [WEB-HP-008] Hover Shows Controls
**Given:** Content is playing with controls hidden  
**When:** User hovers mouse over player  
**Then:** Controls appear immediately  
**And:** Hide timer restarts

### [WEB-HP-009] Keyboard Shortcuts
**Given:** Focus is on player or page  
**When:** User presses Space/F/M keys  
**Then:** Space toggles play/pause, F toggles fullscreen, M toggles mute

### [AND-HP-010] Notification Media Controls
**Given:** Audio/video is playing in background  
**When:** User pulls down notification shade  
**Then:** Media notification shows with play/pause, skip controls

### [IOS-HP-011] Control Center Integration
**Given:** Audio is playing  
**When:** User opens Control Center  
**Then:** Now Playing widget shows current track  
**And:** Controls work correctly

---

## 2. Mode Switching Tests

### [CP-MS-001] Mode Switch UI
**Given:** User is on Media Hub  
**When:** Page loads  
**Then:** Segmented control shows Music (🎵) and TV (📺) options  
**And:** Active mode has clear visual indicator

### [CP-MS-002] Mode Switch Changes Categories
**Given:** User is in Music mode  
**When:** User taps TV segment  
**Then:** Category chips update to TV categories (Live, Movies, Kids, Music, Regional, News)  
**And:** Content grid shows TV content

### [CP-MS-003] Mode Switch Preserves Playback
**Given:** Music is playing  
**When:** User switches to TV mode  
**Then:** Music continues playing  
**And:** Mini player shows current music track

### [CP-MS-004] Mode Switch Stops Incompatible Playback
**Given:** TV video is playing in hero player  
**When:** User switches to Music mode AND starts a music track  
**Then:** TV playback stops  
**And:** Music starts in hero player

---

## 3. Category Chips Tests

### [CP-CC-001] Category Chips Display
**Given:** User is on Media Hub in Music mode  
**When:** Page loads  
**Then:** Horizontal scrollable chips show: Trending, Regional, Indie, Devotional, Chill, Focus

### [CP-CC-002] Category Selection Filters Content
**Given:** User is viewing all content  
**When:** User taps "Indie" chip  
**Then:** Content grid filters to show only Indie content  
**And:** Active chip is highlighted

### [CP-CC-003] Category Deselection
**Given:** "Indie" category is selected  
**When:** User taps "Indie" chip again  
**Then:** Filter clears and all content shows

### [CP-CC-004] Category Scroll
**Given:** More categories than screen width
**When:** User swipes horizontally on chips
**Then:** Chips scroll smoothly
**And:** Edge fade indicates more content

---

## 4. Content Presentation Tests

### [CP-CP-001] Content Cards Display
**Given:** User is on Media Hub
**When:** Content loads
**Then:** Content shows as visual cards (not text rows)
**And:** Each card shows: Image, Title, Genre tag

### [CP-CP-002] TV Live Badge
**Given:** User is viewing TV content
**When:** Content is a live channel
**Then:** Card displays "LIVE" badge prominently

### [CP-CP-003] Viewer Count Display (Optional)
**Given:** TV live content has viewer data
**When:** Card is displayed
**Then:** Viewer count shows on card

### [CP-CP-004] Lazy Load Thumbnails
**Given:** User scrolls through content grid
**When:** New cards enter viewport
**Then:** Thumbnails load with fade-in animation (200ms)

### [CP-CP-005] TV Layout (2-Column Grid)
**Given:** User is in TV mode
**When:** Viewing content grid
**Then:** Content displays in 2-column grid layout

### [CP-CP-006] Music Layout (Horizontal Carousel)
**Given:** User is in Music mode
**When:** Viewing content sections
**Then:** Content displays in horizontal carousels

---

## 5. Personalization Tests

### [CP-PS-001] Continue Watching Section Exists
**Given:** User has previously watched content
**When:** User opens Media Hub
**Then:** "Continue Watching" section appears at top

### [CP-PS-002] Resume From Position
**Given:** User has partially watched a video
**When:** User taps the video in Continue Watching
**Then:** Playback resumes from last position (if > 10 seconds in)

### [CP-PS-003] Recently Played Section
**Given:** User has played content before
**When:** User opens Media Hub
**Then:** "Recently Played" section shows last 20 items

### [CP-PS-004] Favorites Section
**Given:** User has favorited content
**When:** User opens Media Hub
**Then:** "Favorites" section shows all favorited items

### [CP-PS-005] Cross-Device Persistence
**Given:** User favorites content on Device A
**When:** User logs into Device B
**Then:** Favorites sync and appear on Device B

---

## 6. Search Tests

### [CP-SR-001] Unified Search
**Given:** User is on Media Hub
**When:** User taps search icon
**Then:** Search opens covering both Music and TV content

### [CP-SR-002] Search Placeholder
**Given:** Search is open
**When:** Input is empty
**Then:** Placeholder shows "Search channels, artists, genres…"

### [CP-SR-003] Recent Searches on Focus
**Given:** User focuses on search input
**When:** User has previous searches
**Then:** Recent searches appear below input

### [CP-SR-004] Search Results
**Given:** User types a query
**When:** Query length > 2 characters
**Then:** Results show matching content from both modes
**And:** Results are grouped by type (Music/TV)

---

## 7. Quality & Settings Tests

### [CP-QS-001] Quality Options
**Given:** User opens Settings panel
**When:** Quality section is visible
**Then:** Options show: Auto, 480p, 720p, 1080p

### [CP-QS-002] Quality Preference Persistence
**Given:** User selects "720p" quality
**When:** User closes and reopens app
**Then:** Quality remains set to "720p"

### [CP-QS-003] Playback Speed (Music Only)
**Given:** Music is playing and settings open
**When:** User views settings
**Then:** Playback speed option is available (0.5x, 1x, 1.5x, 2x)

### [CP-QS-004] Playback Speed Hidden for TV
**Given:** TV is playing and settings open
**When:** User views settings
**Then:** Playback speed option is NOT visible

---

## 8. Mini Player Tests

### [CP-MP-001] Mini Player Appears
**Given:** Content is playing
**When:** User navigates to another tab
**Then:** Mini player appears above bottom navigation

### [CP-MP-002] Mini Player Controls
**Given:** Mini player is visible
**When:** User views mini player
**Then:** Play/Pause and Next buttons are accessible

### [CP-MP-003] Mini Player Tap Expands
**Given:** Mini player is visible
**When:** User taps on mini player (not controls)
**Then:** Full player screen opens

### [AND-MP-004] Mini Player Above Nav Bar
**Given:** Android device with navigation bar
**When:** Mini player is visible
**Then:** Mini player positioned above system nav bar

### [IOS-MP-005] Safe Area Aware
**Given:** iOS device with home indicator
**When:** Mini player is visible
**Then:** Mini player respects safe area insets

---

## 9. Platform-Specific Playback Tests

### [WEB-PB-001] HTML5 Video Player
**Given:** Web platform
**When:** Video content plays
**Then:** Uses HTML5 video element
**And:** Adaptive quality based on viewport

### [WEB-PB-002] No Background Playback
**Given:** Web platform with tab inactive
**When:** User switches to another tab
**Then:** Audio continues but video may pause (browser-dependent)

### [AND-PB-003] ExoPlayer Integration
**Given:** Android platform
**When:** Video content plays
**Then:** Uses ExoPlayer for adaptive streaming

### [AND-PB-004] Background Audio Foreground Service
**Given:** Android with music playing
**When:** User switches to another app
**Then:** Music continues via foreground service
**And:** Notification controls available

### [AND-PB-005] Bluetooth Headset Support
**Given:** Android with Bluetooth headset connected
**When:** Music is playing
**Then:** Audio routes to headset
**And:** Headset controls work (play/pause/skip)

### [AND-PB-006] Auto-Duck During Calls
**Given:** Android with music playing
**When:** Phone call comes in
**Then:** Music volume ducks or pauses
**And:** Resumes after call ends

### [IOS-PB-007] AVPlayer Integration
**Given:** iOS platform
**When:** Video/audio content plays
**Then:** Uses AVPlayer

### [IOS-PB-008] Background Audio Enabled
**Given:** iOS with audio playing
**When:** User locks screen or switches apps
**Then:** Audio continues playing

### [IOS-PB-009] Silent Switch Respect
**Given:** iOS with silent switch ON
**When:** User tries to play music
**Then:** No audio plays (respects silent mode)

### [IOS-PB-010] Lock Screen Controls
**Given:** iOS with audio playing
**When:** Device is locked
**Then:** Lock screen shows media controls
**And:** Album art displays

---

## 10. Accessibility Tests

### [CP-AC-001] Touch Target Size
**Given:** Any interactive element
**When:** Element is rendered
**Then:** Touch target is ≥ 44px (11mm)

### [CP-AC-002] Color Contrast
**Given:** Any text or icon
**When:** Rendered on background
**Then:** Contrast ratio ≥ 4.5:1 (WCAG AA)

### [CP-AC-003] Screen Reader Labels
**Given:** Any interactive element
**When:** Screen reader focuses on element
**Then:** Semantic label is announced

### [CP-AC-004] Dynamic Text Support
**Given:** User has system text size set to Large
**When:** App renders
**Then:** Text scales appropriately
**And:** Layout does not break

### [WEB-AC-005] Focus States
**Given:** Web platform with keyboard navigation
**When:** User tabs through elements
**Then:** Clear focus indicator is visible

---

## 11. Performance Tests

### [CP-PF-001] Time to First Frame < 2s
**Given:** User taps a video to play
**When:** Playback begins
**Then:** First frame appears in < 2 seconds

### [CP-PF-002] Smooth Scroll at 60fps
**Given:** Content grid with 50+ items
**When:** User scrolls quickly
**Then:** No jank or dropped frames

### [AND-PF-003] Memory Cleanup on Background
**Given:** Android with app in background
**When:** App has been backgrounded > 5 minutes
**Then:** Non-essential resources are released

---

## Test Execution Matrix

| Test ID | Web | Android | iOS |
|---------|-----|---------|-----|
| CP-HP-* | ✓ | ✓ | ✓ |
| CP-MS-* | ✓ | ✓ | ✓ |
| CP-CC-* | ✓ | ✓ | ✓ |
| CP-CP-* | ✓ | ✓ | ✓ |
| CP-PS-* | ✓ | ✓ | ✓ |
| CP-SR-* | ✓ | ✓ | ✓ |
| CP-QS-* | ✓ | ✓ | ✓ |
| CP-MP-* | ✓ | ✓ | ✓ |
| WEB-* | ✓ | - | - |
| AND-* | - | ✓ | - |
| IOS-* | - | - | ✓ |

