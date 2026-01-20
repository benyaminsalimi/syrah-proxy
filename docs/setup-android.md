# Android Setup Guide

> **Note:** Android support is coming soon! This documentation is a preview of planned features.

## Planned Features

- Material 3 design
- VpnService-based traffic capture
- User certificate installation
- Background proxy service
- Per-app traffic filtering

## Stay Updated

- Watch the repository: [github.com/benyaminsalimi/syrah-proxy](https://github.com/benyaminsalimi/syrah-proxy)
- Visit: [proxy.syrah.dev](https://proxy.syrah.dev)

---

## Preview: How Android Setup Will Work

### System Requirements

- Android 7.0 (Nougat) or later
- Approximately 50MB free storage
- VPN permission required

### VPN Permission

SyrahProxy will use Android's VpnService to capture network traffic.

1. When starting the proxy, you'll see a VPN connection request
2. Tap **"OK"** to allow
3. A VPN icon will appear in the status bar when active

**Note:** This is a local VPN that doesn't send your traffic to external servers.

### Certificate Setup

1. Open SyrahProxy
2. Go to **Settings → Certificate Authority**
3. Tap **"Install Certificate"**
4. Follow the system prompts
5. Name the certificate (e.g., "SyrahProxy")

### Android 7+ Certificate Trust

Starting from Android 7.0 (Nougat), apps don't trust user-installed CA certificates by default.

**Solutions:**
- Use debug builds of apps during testing
- Add network security config for apps you develop
- Use Magisk module for rooted devices

### Privacy & Security

- SyrahProxy runs entirely on your device
- No data is sent to external servers
- The VPN is local-only (loopback)
- All certificates are generated locally
- Captured data stays on your device
