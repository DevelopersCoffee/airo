# Responsive & Adaptive UI Components

This directory contains reusable responsive and adaptive UI components for the Airo Super App. These components ensure consistent, professional UI across mobile, tablet, and desktop platforms.

## Components Overview

### 1. ResponsiveCenter
Constrains content width on large screens while maintaining full width on mobile.

```dart
ResponsiveCenter(
  maxWidth: ResponsiveBreakpoints.formMaxWidth, // 400px
  child: Form(children: [...]),
)
```

**Use cases:**
- Auth screens (400px)
- Text-heavy content (800px)
- Standard screens (1000px)
- Dashboards (1200px)

### 2. AdaptiveNavigation
Switches between bottom navigation bar (mobile) and navigation rail (desktop).

```dart
AdaptiveNavigation(
  selectedIndex: currentIndex,
  onDestinationSelected: (index) => setState(() => currentIndex = index),
  destinations: [
    AdaptiveNavigationDestination(
      icon: Icon(Icons.home),
      selectedIcon: Icon(Icons.home_filled),
      label: 'Home',
    ),
  ],
  child: currentScreen,
)
```

### 3. AdaptiveDialog
Shows full-screen bottom sheet on mobile, centered dialog on desktop.

```dart
// Custom dialog
AdaptiveDialog.show(
  context: context,
  maxWidth: 600,
  builder: (context) => MyDialogContent(),
);

// Alert dialog
AdaptiveDialog.showAlert(
  context: context,
  title: Text('Confirm Action'),
  content: Text('Are you sure?'),
  actions: [
    TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
    ElevatedButton(onPressed: () => ..., child: Text('Confirm')),
  ],
);
```

### 4. AdaptiveBottomSheet
Draggable bottom sheet on mobile, fixed dialog on desktop.

```dart
AdaptiveBottomSheet.show(
  context: context,
  initialChildSize: 0.6,
  minChildSize: 0.4,
  maxChildSize: 0.9,
  builder: (context) => MySheetContent(),
);
```

### 5. AdaptiveSpacing
Spacing that scales based on screen size.

```dart
Padding(
  padding: AdaptiveSpacing.paddingMd(context), // Scales: 13.6px → 16px → 18.4px
  child: Column(
    children: [
      Text('Title'),
      AdaptiveSpacing.gapVerticalMd(context), // Responsive gap
      Text('Content'),
    ],
  ),
)
```

**Available sizes:** `xxs`, `xs`, `sm`, `md`, `lg`, `xl`, `xxl`, `xxxl`

### 6. AdaptiveTypography
Text that scales appropriately for different screen sizes.

```dart
// Adaptive text widget
AdaptiveText(
  'Welcome to Airo',
  style: Theme.of(context).textTheme.headlineLarge,
)

// Get scaled font size
Text(
  'Custom text',
  style: TextStyle(
    fontSize: AdaptiveTypography.getScaledFontSize(context, 16),
  ),
)
```

### 7. AdaptiveInput
Form inputs optimized for different screen sizes.

```dart
AdaptiveTextField(
  controller: controller,
  decoration: InputDecoration(
    labelText: 'Email',
    prefixIcon: Icon(Icons.email),
  ),
  keyboardType: TextInputType.emailAddress,
)

// Or use form field
AdaptiveFormField(
  label: 'Password',
  obscureText: true,
  prefixIcon: Icon(Icons.lock),
  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
)
```

### 8. ResponsiveBreakpoints
Utility class for breakpoint detection and responsive values.

```dart
// Check breakpoint
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

// Get grid columns
final columns = ResponsiveBreakpoints.getGridColumns(
  width,
  mobile: 2,
  tablet: 3,
  desktop: 4,
);
```

## Standard Breakpoints

```dart
Mobile:        < 600px
Tablet:        600-1024px
Desktop:       >= 1024px
Wide Desktop:  >= 1440px
```

## Max Width Guidelines

```dart
Forms/Auth:      400px  (ResponsiveBreakpoints.formMaxWidth)
Text content:    800px  (ResponsiveBreakpoints.textMaxWidth)
Standard screens: 1000px (ResponsiveBreakpoints.contentMaxWidth)
Dashboards:      1200px (ResponsiveBreakpoints.dashboardMaxWidth)
Wide content:    1440px (ResponsiveBreakpoints.wideMaxWidth)
```

## Best Practices

1. **Always constrain content** - Use `ResponsiveCenter` to prevent infinite stretching
2. **Use LayoutBuilder** - Switch layouts based on constraints, not device type
3. **Preserve aspect ratios** - Use `AspectRatio` for images and media
4. **Test all breakpoints** - Resize browser from 320px to 1920px
5. **Use adaptive components** - Replace `showDialog` with `AdaptiveDialog.show`

## Migration Example

### Before (Fixed Layout)
```dart
Scaffold(
  body: SingleChildScrollView(
    padding: EdgeInsets.all(16),
    child: Column(children: [...]),
  ),
)
```

### After (Responsive Layout)
```dart
Scaffold(
  body: ResponsiveCenter(
    maxWidth: ResponsiveBreakpoints.contentMaxWidth,
    child: SingleChildScrollView(
      padding: AdaptiveSpacing.paddingMd(context),
      child: Column(children: [...]),
    ),
  ),
)
```

## See Also

- [.augment/rules.md](../../../.augment/rules.md) - Full responsive design standards
- [responsive_center.dart](responsive_center.dart) - Core responsive utilities
- [adaptive_dialog.dart](adaptive_dialog.dart) - Adaptive modal patterns

