---
description: Flutter widget development patterns and conventions for Ops Deck
---

# Flutter Widget Development

## When to Use
- Building new screens or UI components
- Modifying existing widgets
- Adding responsive layouts
- Implementing Material Design 3 components

## Patterns

### Screen Widget Structure
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MyScreen extends StatefulWidget {
  const MyScreen({super.key});

  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProvider();
    });
  }

  void _initializeProvider() {
    final provider = context.read<MyProvider>();
    provider.initialize().then((_) {
      if (provider.isConfigured) {
        provider.startUpdates();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    context.read<MyProvider>().stopUpdates();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: Consumer<MyProvider>(
        builder: (context, provider, _) {
          if (!provider.isConfigured) return _buildNotConfigured(context);
          if (provider.isLoading && provider.data.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null && provider.data.isEmpty) {
            return _buildError(context, provider.error!);
          }
          return _buildContent(context, provider);
        },
      ),
    );
  }
}
```

### Responsive Layout Pattern
```dart
Widget _buildContent(BuildContext context, MyProvider provider) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 600;
      return isMobile
          ? _buildMobileLayout(context, provider)
          : _buildDesktopLayout(context, provider);
    },
  );
}
```

### Theme Colors (Project Standard)
```dart
// Always use theme colors, not hardcoded values
const primaryGreen = Color(0xFF00FF41);
const secondaryGreen = Color(0xFF238636);
const backgroundColor = Color(0xFF0D1117);
const surfaceColor = Color(0xFF161B22);
const borderColor = Color(0xFF30363D);
const mutedTextColor = Color(0xFF8B949E);
const errorRed = Color(0xFFF85149);
```

### Text Styling (Monospace Theme)
```dart
// All text uses monospace for terminal aesthetic
const TextStyle(
  fontFamily: 'monospace',
  fontSize: 13,
  color: Color(0xFFE6EDF3),
)
```

## Best Practices

1. **Use const constructors** - Add `const` to all widgets that can be const
2. **Extract build methods** - Private methods like `_buildAppBar()`, `_buildContent()`
3. **Check mounted before setState** - Always verify `mounted` after async operations
4. **Use Consumer not Provider.of** - For reactive rebuilds in build method
5. **Handle all states** - Not configured, loading, error, and content states

## Common Tasks

### Adding a New Screen
1. Create file in `lib/screens/`
2. Use `StatefulWidget` if needs initialization or local state
3. Add Consumer for provider access
4. Handle all four states (not configured, loading, error, content)
5. Add navigation from calling screen

### Adding a New Widget
1. Create file in `lib/widgets/<feature>/`
2. Use `const` constructor with `super.key`
3. Accept callbacks via `Function` parameters (e.g., `onTap`, `onChanged`)
4. Use `Theme.of(context)` for colors

### Navigation
```dart
// Push to new screen
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const MyScreen()),
);

// Return from screen
Navigator.pop(context);

// Return with result
Navigator.pop(context, result);
```
