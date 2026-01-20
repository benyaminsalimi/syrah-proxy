# macOS Setup Guide

This guide walks you through setting up Syrah on macOS.

## System Requirements

- macOS 11.0 (Big Sur) or later
- Apple Silicon or Intel Mac
- Approximately 100MB free disk space

## Installation

### Option 1: DMG Installer (Recommended)

1. Download the latest `.dmg` file from [Releases](https://github.com/benyaminsalimi/syrah_app/releases)
2. Open the DMG file
3. Drag Syrah to your Applications folder
4. Eject the DMG

### Option 2: Homebrew (Coming Soon)

```bash
brew install --cask netscope
```

### Option 3: Build from Source

See [Building from Source](#building-from-source) below.

## First Launch

When you first launch Syrah:

1. macOS may show a security warning. Click "Open" to proceed.
2. Grant necessary permissions when prompted
3. The app will generate a CA certificate

## Certificate Setup

To intercept HTTPS traffic, you need to install and trust the CA certificate.

### Automatic Installation

1. Open Syrah
2. Go to **Settings → Certificate Authority**
3. Click **"Install Certificate"**
4. Enter your password when prompted
5. The certificate will be added to your Keychain

### Manual Installation

1. Export the certificate from Settings → Certificate Authority
2. Double-click the `.pem` file
3. Keychain Access will open
4. Find "Syrah Root CA" in the login keychain
5. Double-click the certificate
6. Expand "Trust" section
7. Set "When using this certificate" to **"Always Trust"**
8. Close the window and enter your password

### Verification

To verify the certificate is installed:

```bash
security find-certificate -c "Syrah" ~/Library/Keychains/login.keychain-db
```

## Proxy Configuration

### Automatic System Proxy

Syrah can automatically configure system proxy settings:

1. Go to **Settings → Proxy**
2. Enable **"Auto-configure System Proxy"**
3. Click **"Start Proxy"**

### Manual Configuration

1. Open **System Preferences → Network**
2. Select your network interface (Wi-Fi or Ethernet)
3. Click **"Advanced..." → Proxies**
4. Enable **"Web Proxy (HTTP)"** and **"Secure Web Proxy (HTTPS)"**
5. Set server to `127.0.0.1` and port to `8080`
6. Click **"OK"** and **"Apply"**

## Configuring Browsers

### Safari

Safari uses system proxy settings automatically.

### Chrome

Chrome uses system proxy settings by default. To verify:
1. Visit `chrome://net-internals/#proxy`
2. Confirm proxy is configured

### Firefox

Firefox has its own proxy settings:
1. Open **Preferences → General → Network Settings**
2. Select **"Manual proxy configuration"**
3. Set HTTP Proxy to `127.0.0.1` and Port to `8080`
4. Check **"Also use this proxy for HTTPS"**

### Certificate Trust in Firefox

Firefox has its own certificate store:
1. Open **Preferences → Privacy & Security → Certificates**
2. Click **"View Certificates..."**
3. Go to **"Authorities"** tab
4. Click **"Import..."**
5. Select the exported Syrah certificate

## Troubleshooting

### Certificate Not Trusted

If you see certificate warnings:
1. Open Keychain Access
2. Find "Syrah Root CA"
3. Make sure it's set to "Always Trust"

### Proxy Not Working

1. Verify Syrah is running and proxy is started
2. Check system proxy settings
3. Try restarting the network interface
4. Check firewall settings

### Permission Issues

Syrah requires certain permissions:
- **Network access**: To act as a proxy server
- **Keychain access**: To manage certificates

If permissions are denied:
1. Open **System Preferences → Security & Privacy → Privacy**
2. Add Syrah to allowed apps

## Building from Source

### Prerequisites

- Xcode 15+
- Flutter SDK 3.x
- CocoaPods

### Build Steps

```bash
# Clone repository
git clone https://github.com/benyaminsalimi/syrah_app.git
cd netscope

# Install melos
dart pub global activate melos

# Bootstrap project
melos bootstrap

# Build for macOS
cd packages/netscope_app
flutter build macos --release
```

The app bundle will be at:
```
build/macos/Build/Products/Release/netscope_app.app
```

## Uninstallation

1. Quit Syrah
2. Delete Syrah from Applications
3. Remove certificate from Keychain:
   - Open Keychain Access
   - Find "Syrah Root CA"
   - Delete it
4. Reset proxy settings if needed

## Network Extension (Advanced)

For capturing traffic from other apps without proxy configuration,
Syrah can use a Network Extension. This requires:

1. Apple Developer account
2. Network Extension entitlement
3. Code signing with proper provisioning profile

This is optional and the basic proxy mode works without it.
