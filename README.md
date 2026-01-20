# SyrahProxy

**Open-source network debugging proxy for macOS**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-macOS-green.svg)]()

SyrahProxy is a full-featured HTTP/HTTPS debugging proxy application built with Flutter for macOS. It provides Proxyman-like functionality with a native platform look.

**Website**: [proxy.syrah.dev](https://proxy.syrah.dev)

## Features

### Core Features
- **SSL/HTTPS Inspection** - Man-in-the-middle proxy with dynamic certificate generation (powered by mitmproxy)
- **Request/Response Viewing** - JSON syntax highlighting, headers, body inspection
- **Resizable UI** - Adjustable sidebar, request columns, and detail panel
- **Domain Grouping** - Requests organized by host in sidebar
- **Pinning** - Pin specific domains to filter traffic
- **System Proxy** - One-click system proxy configuration
- **Certificate Management** - Generate and trust custom CA certificates

### macOS Features
- Native macOS menu bar integration
- System tray icon with quick controls
- Keyboard shortcuts (⌘R to toggle proxy, ⌘K to clear)
- System proxy configuration
- Keychain certificate management

### Coming Soon
- **Breakpoints** - Pause and modify requests/responses on-the-fly
- **Map Local** - Mock responses using local files
- **Map Remote** - Redirect traffic to alternative endpoints
- **Scripting** - JavaScript-based request/response manipulation
- **WebSocket Debugging** - Real-time WebSocket protocol support
- **Diff Tool** - Side-by-side request/response comparison
- **Network Throttling** - Simulate slow network conditions
- **Android Support** - Android app coming soon

## Screenshots

*Coming soon*

## Installation

### Prerequisites
- macOS 12.0 or later
- Flutter SDK 3.x or later
- Xcode 15+
- Melos for monorepo management

### Setup

1. Clone the repository:
```bash
git clone https://github.com/benyaminsalimi/syrah-proxy.git
cd syrah-proxy
```

2. Install melos globally:
```bash
dart pub global activate melos
```

3. Add pub-cache bin to PATH (if not already):
```bash
export PATH="$PATH:$HOME/.pub-cache/bin"
```

4. Bootstrap the monorepo (installs dependencies for all packages):
```bash
melos bootstrap
```

5. Run code generation (generates freezed models, JSON serialization, etc.):
```bash
melos run generate
```

### Building the App

```bash
cd packages/syrah_app
flutter build macos --debug   # Debug build
flutter build macos --release # Release build
```

The built app will be at:
- Debug: `build/macos/Build/Products/Debug/SyrahProxy.app`
- Release: `build/macos/Build/Products/Release/SyrahProxy.app`

To run directly:
```bash
flutter run -d macos
```

Or open the built app:
```bash
open build/macos/Build/Products/Release/SyrahProxy.app
```

### Development Commands

```bash
# Clean all packages
melos clean

# Run code generation for all packages
melos run generate

# Run tests for all packages
melos run test

# Analyze all packages
melos run analyze
```

## Project Structure

```
syrah-proxy/
├── packages/
│   ├── syrah_app/             # Main Flutter application
│   │   ├── lib/
│   │   │   ├── app/           # App configuration, themes, router
│   │   │   ├── features/      # Feature modules
│   │   │   │   ├── home/      # Main request list view
│   │   │   │   ├── detail/    # Request detail view
│   │   │   │   ├── settings/  # App settings
│   │   │   │   └── composer/  # Request composer
│   │   │   └── services/      # mitmproxy bridge, certificates
│   │   └── macos/
│   │
│   ├── syrah_core/            # Shared Dart models and logic
│   │   └── lib/
│   │       ├── models/        # Data models (freezed)
│   │       ├── services/      # Business logic
│   │       └── utils/         # Utilities (HAR, cURL, code gen)
│   │
│   └── syrah_proxy_macos/     # macOS native plugin
│       └── macos/Classes/
│           ├── CertificateAuthority.swift
│           ├── ProxyEngine.swift
│           └── SyrahProxyMacosPlugin.swift
│
├── tools/                     # Build tools
├── docs/                      # Documentation
└── melos.yaml                 # Monorepo configuration
```

## Certificate Setup

SyrahProxy requires a trusted CA certificate to intercept HTTPS traffic.

1. Open SyrahProxy and click "Trust Certificate" in the toolbar
2. Click "Generate Certificate" if you don't have one
3. Click "Install Certificate" - Keychain Access will open
4. Find "SyrahProxy CA" certificate
5. Double-click and select "Always Trust" under Trust settings
6. Enter your password when prompted
7. Restart your browser

## Architecture

### Proxy Engine
SyrahProxy uses **mitmproxy** as its proxy backend:
- mitmproxy runs as a subprocess
- Communication via WebSocket
- Custom Python addon handles flow events
- Supports HTTP/1.1, HTTP/2, WebSocket, gRPC

### Flutter Communication
- `MitmproxyBridge`: WebSocket client for real-time flow updates
- `CertificateService`: CA certificate generation and trust management
- `TrayService`: macOS menu bar tray icon

### State Management
The app uses Riverpod for state management:
- `HomeController`: Main state (flows, filters, pins, proxy status)
- Feature-based architecture with clean separation

## Contributing

Contributions are welcome! Please read our [Contributing Guidelines](CONTRIBUTING.md) before submitting a PR.

### Development Setup

1. Fork and clone the repository
2. Install dependencies: `melos bootstrap`
3. Run code generation: `melos run generate`
4. Create a feature branch
5. Make your changes
6. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [mitmproxy](https://mitmproxy.org/) - Proxy engine
- [Proxyman](https://proxyman.io/) - Feature inspiration
- [Riverpod](https://riverpod.dev/) - State management
- [Flutter](https://flutter.dev/) - UI framework

## Support

- GitHub Issues: [Report a bug](https://github.com/benyaminsalimi/syrah-proxy/issues)
- Website: [proxy.syrah.dev](https://proxy.syrah.dev)
- Documentation: [docs/](docs/)

---

Made with ❤️ by the Syrah Project
