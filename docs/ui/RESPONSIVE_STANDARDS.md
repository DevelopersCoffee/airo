# Responsive and adaptive design standards

Live conventions for the shared adaptive components in `core_ui`. Load this when
building or changing any screen that has to work across phone, tablet, TV, and
web.

Extracted from `.augment/rules.md` on 2026-07-29, which was a third
always-loaded context file carrying a stale product description alongside these
still-accurate standards. The standards survived; the stale framing did not.

## Mandatory practices

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

### 1. ResponsiveCenter (Content Constraint)
```dart
// Wrap screen content to prevent infinite stretching
ResponsiveCenter(
  maxWidth: ResponsiveBreakpoints.formMaxWidth,
  child: SingleChildScrollView(
    child: Column(children: [...]),
  ),
)
```

### 2. AdaptiveLayout (Layout Switching)
```dart
// Different layouts for different screen sizes
AdaptiveLayout(
  mobileLayout: _buildMobileView(),
  tabletLayout: _buildTabletView(), // Optional
  desktopLayout: _buildDesktopView(),
)
```

### 3. ResponsiveGrid (Dynamic Columns)
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

### 4. AdaptiveNavigation (Navigation Pattern)
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

### 5. AdaptiveDialog (Modal Presentation)
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

### 6. AdaptiveBottomSheet
```dart
// Draggable sheet (mobile) → Dialog (desktop)
AdaptiveBottomSheet.show(
  context: context,
  initialChildSize: 0.6,
  builder: (context) => MySheetContent(),
);
```

### 7. AdaptiveSpacing (Responsive Spacing)
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

### 8. AdaptiveTypography (Responsive Text)
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

### Auth Screens (Forms)
```dart
ResponsiveCenter(
  maxWidth: ResponsiveBreakpoints.formMaxWidth, // 400px
  child: Form(children: [...]),
)
```

### Text-Heavy Screens (Reader, Articles)
```dart
ResponsiveCenter(
  maxWidth: ResponsiveBreakpoints.textMaxWidth, // 800px
  child: SingleChildScrollView(children: [...]),
)
```

### Dashboard Screens (Grids, Cards)
```dart
ResponsiveCenter(
  maxWidth: ResponsiveBreakpoints.dashboardMaxWidth, // 1200px
  child: GridView(...),
)
```

### Images/Media (Preserve Aspect Ratio)
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
