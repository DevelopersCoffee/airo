# Airo Super App - Project Rules & Conventions

## Project Overview
- **Name**: Airo - On-device AI platform for PDF/image/audio processing
- **Target Platforms**: Pixel 9 (Android), iOS 26, Chrome (PWA)
- **AI Model**: Gemma 1B (int4 quantized), LiteRT/AI Edge SDKs
- **Core Functions**: `fill_form()`, `schedule_notifications()`, `split_bill()`

## Architecture

### State Management
- **Use Riverpod** for all state management (StateProvider, StateNotifierProvider, FutureProvider)
- Domain-Driven Design: domain (models, services) → application (providers) → presentation (screens, widgets)

### AI/ML Strategy (Hybrid Approach)
1. **On-device first**: ML Kit OCR + Gemini Nano for privacy/offline
2. **Cloud fallback**: Gemini API (Flash/Pro) for complex tasks
3. **Limits**: Gemini Nano has 1024 prompt tokens, 4096 context
4. Look for `TODO: OPTIMIZATION` comments for on-device replacement opportunities

### Storage Strategy
- **Current MVP**: SharedPreferences + JSON (fast to implement)
- **Target**: SQLCipher for encrypted storage of financial data
- **Backup**: Firebase Firestore for cloud sync (future)

### Navigation
- Layer-based modular navigation using bottom sheets/overlays with stack-based history
- Use GoRouter for route management

## Code Conventions

### Testing
1. **Playwright** for browser E2E tests (Flutter Web with HTML renderer)
2. **Patrol** for iOS/Android device testing
3. **Unit Tests**: Write tests first (TDD approach)
4. Add test IDs using `Semantics` or `Key` for selectors

### Package Management
- Always use `flutter pub add/remove` - never manually edit pubspec.yaml
- Use existing dependencies (Dio, not http package)

### Git Workflow
- Conventional commits: `feat:`, `fix:`, `chore:`, `docs:`
- Push to both `master` and `main` branches for GitHub Pages
- Keep `.vscode/` local only (in .gitignore)

### File Organization
```
app/
├── lib/
│   ├── core/services/         # Shared services (AI, auth, storage)
│   ├── features/{feature}/
│   │   ├── application/       # Providers, controllers
│   │   ├── domain/            # Models, services
│   │   └── presentation/      # Screens, widgets
├── integration_test/          # Patrol E2E tests
├── test/                      # Unit tests
docs/                          # GitHub Pages documentation
.vscode/                       # Local config (not in git)
  ├── secrets/                 # API keys, credentials
  └── .augment/                # Augment context (pending tasks)
```

## Key Dependencies
- `google_mlkit_text_recognition`: OCR
- `image_picker`: Camera/gallery
- `dio`: HTTP client
- `shared_preferences`: Local storage (MVP)
- `patrol`: E2E device testing
- `flutter_riverpod`: State management

## API Keys & Secrets
- Store in `.vscode/secrets/` (gitignored)
- Gemini API key required for cloud-based parsing
- Structure: `.vscode/secrets/google.json`

## Success Metrics
- 90% offline accuracy
- <3s PDF extraction
- <1.2GB footprint
- F1≥0.9 extraction accuracy
- <5% battery per workflow

## Responsive & Adaptive Design Standards

### Mandatory Practices
1. **Never use fixed widths/heights** - Always use `Flexible`, `Expanded`, `AspectRatio`, or percentage-based constraints
2. **Always constrain content** - Wrap screens in `ResponsiveCenter` with appropriate `maxWidth` for web/desktop
3. **Use LayoutBuilder** - Switch layouts based on `constraints.maxWidth`, not device type
4. **Test all breakpoints** - Manually resize browser from 320px to 1920px width
5. **Preserve aspect ratios** - Use `AspectRatio` for images, videos, and square widgets (e.g., chess board, album art)

### Standard Breakpoints
```dart
// From ResponsiveBreakpoints class
Mobile:        < 600px
Tablet:        600-1024px
Desktop:       >= 1024px
Wide Desktop:  >= 1440px
```

### Max Width Guidelines
Use `ResponsiveCenter` with these standard max widths:
```dart
Forms/Auth:      400px  (ResponsiveBreakpoints.formMaxWidth)
Text content:    800px  (ResponsiveBreakpoints.textMaxWidth)
Standard screens: 1000px (ResponsiveBreakpoints.contentMaxWidth)
Dashboards:      1200px (ResponsiveBreakpoints.dashboardMaxWidth)
Wide content:    1440px (ResponsiveBreakpoints.wideMaxWidth)
```

### Responsive Components

#### 1. ResponsiveCenter (Content Constraint)
```dart
// Wrap screen content to prevent infinite stretching
ResponsiveCenter(
  maxWidth: ResponsiveBreakpoints.formMaxWidth,
  child: SingleChildScrollView(
    child: Column(children: [...]),
  ),
)
```

#### 2. AdaptiveLayout (Layout Switching)
```dart
// Different layouts for different screen sizes
AdaptiveLayout(
  mobileLayout: _buildMobileView(),
  tabletLayout: _buildTabletView(), // Optional
  desktopLayout: _buildDesktopView(),
)
```

#### 3. ResponsiveGrid (Dynamic Columns)
```dart
// Grid that adapts column count
LayoutBuilder(
  builder: (context, constraints) {
    final columns = ResponsiveBreakpoints.getGridColumns(
      constraints.maxWidth,
      mobile: 2, tablet: 3, desktop: 4,
    );
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) => ...,
    );
  },
)
```

#### 4. AdaptiveNavigation (Navigation Pattern)
```dart
// Bottom nav (mobile) → Navigation rail (desktop)
AdaptiveNavigation(
  selectedIndex: currentIndex,
  onDestinationSelected: (index) => ...,
  destinations: [
    AdaptiveNavigationDestination(
      icon: Icon(Icons.home),
      label: 'Home',
    ),
  ],
  child: currentScreen,
)
```

#### 5. AdaptiveDialog (Modal Presentation)
```dart
// Full-screen sheet (mobile) → Centered dialog (desktop)
AdaptiveDialog.show(
  context: context,
  maxWidth: 600,
  builder: (context) => MyDialogContent(),
);

// Or for alerts
AdaptiveDialog.showAlert(
  context: context,
  title: Text('Confirm'),
  content: Text('Are you sure?'),
  actions: [
    TextButton(onPressed: () => ..., child: Text('Cancel')),
    ElevatedButton(onPressed: () => ..., child: Text('Confirm')),
  ],
);
```

#### 6. AdaptiveBottomSheet
```dart
// Draggable sheet (mobile) → Dialog (desktop)
AdaptiveBottomSheet.show(
  context: context,
  initialChildSize: 0.6,
  builder: (context) => MySheetContent(),
);
```

#### 7. AdaptiveSpacing (Responsive Spacing)
```dart
// Spacing that scales with screen size
Padding(
  padding: AdaptiveSpacing.paddingMd(context),
  child: Column(
    children: [
      Text('Title'),
      AdaptiveSpacing.gapVerticalMd(context),
      Text('Content'),
    ],
  ),
)
```

#### 8. AdaptiveTypography (Responsive Text)
```dart
// Text that scales appropriately
AdaptiveText(
  'Welcome to Airo',
  style: Theme.of(context).textTheme.headlineLarge,
)

// Or get scaled font size
Text(
  'Custom text',
  style: TextStyle(
    fontSize: AdaptiveTypography.getScaledFontSize(context, 16),
  ),
)
```

### Web-Specific Rules
- **Renderer**: Use CanvasKit for production (`flutter build web --web-renderer canvaskit`)
- **Navigation**: BottomNavigationBar (mobile) → NavigationRail (desktop)
- **Modals**: BottomSheet (mobile) → Dialog with maxWidth (desktop)
- **Input**: Add hover effects and keyboard shortcuts on desktop
- **Never lock orientation** on web builds
- **Test in Chrome DevTools** with responsive mode (320px to 1920px)

### Breakpoint Helpers
```dart
// Check current breakpoint
if (ResponsiveBreakpoints.isMobile(context)) { ... }
if (ResponsiveBreakpoints.isTablet(context)) { ... }
if (ResponsiveBreakpoints.isDesktop(context)) { ... }

// Get value based on breakpoint
final padding = ResponsiveBreakpoints.getValue(
  context,
  mobile: 8.0,
  tablet: 16.0,
  desktop: 24.0,
);

// Get breakpoint name
final breakpoint = ResponsiveBreakpoints.getBreakpointName(context);
// Returns: 'mobile', 'tablet', 'desktop', or 'wide-desktop'
```

### Common Patterns

#### Auth Screens (Forms)
```dart
ResponsiveCenter(
  maxWidth: ResponsiveBreakpoints.formMaxWidth, // 400px
  child: Form(children: [...]),
)
```

#### Text-Heavy Screens (Reader, Articles)
```dart
ResponsiveCenter(
  maxWidth: ResponsiveBreakpoints.textMaxWidth, // 800px
  child: SingleChildScrollView(children: [...]),
)
```

#### Dashboard Screens (Grids, Cards)
```dart
ResponsiveCenter(
  maxWidth: ResponsiveBreakpoints.dashboardMaxWidth, // 1200px
  child: GridView(...),
)
```

#### Images/Media (Preserve Aspect Ratio)
```dart
// Instead of fixed height
AspectRatio(
  aspectRatio: 16 / 9, // or 1.0 for square
  child: Image.network(url, fit: BoxFit.cover),
)
```

### Testing Checklist
- [ ] Test at 320px (small mobile)
- [ ] Test at 600px (breakpoint: mobile → tablet)
- [ ] Test at 1024px (breakpoint: tablet → desktop)
- [ ] Test at 1440px (breakpoint: desktop → wide)
- [ ] Test at 1920px (wide desktop)
- [ ] Verify no horizontal scrolling
- [ ] Verify no content overflow
- [ ] Verify text remains readable at all sizes
- [ ] Verify touch targets are adequate (min 48x48dp)

### Migration Guide
When updating existing screens:
1. Wrap main content in `ResponsiveCenter` with appropriate `maxWidth`
2. Replace fixed heights with `AspectRatio` for media
3. Use `LayoutBuilder` for responsive grids
4. Replace `showDialog` with `AdaptiveDialog.show`
5. Replace `showModalBottomSheet` with `AdaptiveBottomSheet.show`
6. Use `AdaptiveSpacing` instead of hardcoded padding values

