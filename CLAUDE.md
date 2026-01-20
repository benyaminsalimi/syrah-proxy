# CLAUDE.md - SyrahProxy Project Guide

This file provides guidance for Claude Code (claude.ai/code) when working with this codebase.

## Project Overview

SyrahProxy is an open-source HTTP/HTTPS debugging proxy built with Flutter for macOS. It's designed as a Proxyman alternative.

- **App Name**: SyrahProxy
- **Website**: https://proxy.syrah.dev
- **Repository**: https://github.com/benyaminsalimi/syrah-proxy
- **License**: MIT
- **Platform**: macOS (Android coming soon)

## Tech Stack

- **Framework**: Flutter 3.x
- **State Management**: Riverpod
- **Proxy Backend**: mitmproxy (bundled as subprocess)
- **UI**: Native macOS styling
- **Monorepo**: Melos

## Project Structure

```
syrah-proxy/
├── packages/
│   ├── syrah_app/              # Main Flutter application
│   │   ├── lib/
│   │   │   ├── app/            # App config, themes, router
│   │   │   ├── features/       # Feature modules
│   │   │   │   ├── home/       # Main screen with request list
│   │   │   │   ├── detail/     # Request detail panel
│   │   │   │   ├── settings/   # Settings screens
│   │   │   │   └── composer/   # Request composer
│   │   │   └── services/       # Services (mitmproxy bridge, certificates)
│   │   └── macos/              # macOS-specific code
│   │
│   ├── syrah_core/             # Shared Dart models (freezed)
│   └── syrah_proxy_macos/      # macOS native plugin
│
├── tools/                      # Build tools, mitmproxy download
└── docs/                       # Documentation
```

## Key Files

| File | Purpose |
|------|---------|
| `packages/syrah_app/lib/main.dart` | App entry point |
| `packages/syrah_app/lib/app/app.dart` | Main app widget with macOS menu bar |
| `packages/syrah_app/lib/features/home/home_screen.dart` | Main UI with toolbar, sidebar, request list |
| `packages/syrah_app/lib/features/home/home_controller.dart` | Main state management (Riverpod) |
| `packages/syrah_app/lib/features/home/widgets/request_list.dart` | Request table with resizable columns |
| `packages/syrah_app/lib/features/home/widgets/sidebar.dart` | Domain tree sidebar |
| `packages/syrah_app/lib/features/settings/settings_screen_new.dart` | Active settings screen |
| `packages/syrah_app/lib/services/mitmproxy_bridge.dart` | mitmproxy WebSocket communication |
| `packages/syrah_app/lib/services/certificate_service.dart` | CA certificate management |
| `packages/syrah_app/lib/services/tray_service.dart` | macOS menu bar tray icon |

## Common Commands

```bash
# Install dependencies
cd packages/syrah_app && flutter pub get

# Build macOS release
flutter build macos --release

# Run macOS app
flutter run -d macos

# Code generation (freezed models)
melos run generate

# Clean build
flutter clean && flutter pub get
```

## Architecture Notes

### mitmproxy Integration
- SyrahProxy uses mitmproxy as the proxy engine (not custom Swift)
- mitmproxy runs as a subprocess
- Communication via WebSocket (MitmproxyBridge)
- Python addon (`syrah_bridge.py`) handles flow events

### State Management
- Uses Riverpod with StateNotifier pattern
- `HomeController` manages proxy state, flows, filters, pins
- Key providers:
  - `homeControllerProvider` - main state
  - `proxyRunningProvider` - proxy status
  - `filteredFlowsProvider` - filtered request list
  - `selectedFlowProvider` - currently selected request

### UI Components
- **Toolbar**: Toggle sidebar, app logo, proxy controls, certificate trust
- **Sidebar**: Domain tree, pinning, filters
- **Request List**: Resizable columns with headers
- **Detail Panel**: Request/response details (resizable)

## Branding

- **App Name**: SyrahProxy (not "Syrah" or "netscope")
- **Logo**: Wine glass icon at `assets/icons/syrah_logo.png`
- **Color**: Wine red (#722F37)
- **Bundle ID**: dev.syrah.proxy

## Common Tasks

### Adding a new feature
1. Create feature folder in `lib/features/`
2. Add route in `lib/app/router/app_router.dart`
3. Add state in `home_controller.dart` if needed

### Updating branding
- App name: `macos/Runner/Configs/AppInfo.xcconfig`
- Logo: `assets/icons/syrah_logo.png`
- About dialog: `lib/features/settings/settings_screen_new.dart`
- Menu bar: `lib/app/app.dart`

### Certificate management
- Certificates stored in `~/.syrah/`
- Generator: `lib/services/certificate_generator.dart`
- UI: `lib/services/certificate_service.dart`

## Testing

```bash
# Run tests
flutter test

# Run specific test file
flutter test test/home_controller_test.dart
```

## Known Issues

- TLS interception requires mitmproxy CA certificate to be trusted
- Some features are placeholders (breakpoints, map local/remote, scripting)

## Resources

- [mitmproxy Docs](https://docs.mitmproxy.org/)
- [Flutter Riverpod](https://riverpod.dev/)
- [Flutter Platform Channels](https://docs.flutter.dev/platform-integration/platform-channels)
