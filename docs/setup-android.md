# Android Setup Guide

This guide walks you through setting up Syrah on Android.

## System Requirements

- Android 7.0 (Nougat) or later
- Approximately 50MB free storage
- VPN permission required

## Installation

### Option 1: Direct APK

1. Download the latest `.apk` file from [Releases](https://github.com/benyaminsalimi/syrah_app/releases)
2. Enable "Install from unknown sources" if prompted
3. Install the APK
4. Open Syrah

### Option 2: F-Droid (Coming Soon)

```
fdroid install com.netscope.app
```

### Option 3: Build from Source

See [Building from Source](#building-from-source) below.

## First Launch

When you first launch Syrah:

1. Grant VPN permission when prompted
2. The app will generate a CA certificate
3. Follow the certificate installation wizard

## VPN Permission

Syrah uses Android's VpnService to capture network traffic.

1. When starting the proxy, you'll see a VPN connection request
2. Tap **"OK"** to allow
3. A VPN icon will appear in the status bar when active

**Note:** This is a local VPN that doesn't send your traffic to external servers.

## Certificate Setup

### Automatic Installation

1. Open Syrah
2. Go to **Settings → Certificate Authority**
3. Tap **"Install Certificate"**
4. Follow the system prompts
5. Name the certificate (e.g., "Syrah")
6. The certificate is now installed

### Manual Installation

1. Export the certificate from Settings
2. Go to **Settings → Security → Encryption & credentials**
3. Tap **"Install a certificate"**
4. Select **"CA certificate"**
5. Tap **"Install anyway"** on the warning
6. Select the downloaded `.pem` file
7. Authenticate with your PIN/fingerprint

### Verification

To verify installation:
1. Go to **Settings → Security → Encryption & credentials**
2. Tap **"Trusted credentials"**
3. Go to **"User"** tab
4. You should see "Syrah Root CA"

## Android 7+ Certificate Trust

Starting from Android 7.0 (Nougat), apps don't trust user-installed CA certificates by default. This means:

- System apps and browsers will work fine
- Third-party apps may show certificate errors

### Solution 1: Debug APKs

Debug builds of Android apps trust user certificates. Ask developers for debug builds during testing.

### Solution 2: Network Security Config

For apps you're developing, add this to `res/xml/network_security_config.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config>
        <trust-anchors>
            <certificates src="system" />
            <certificates src="user" />
        </trust-anchors>
    </base-config>
</network-security-config>
```

And reference it in `AndroidManifest.xml`:

```xml
<application
    android:networkSecurityConfig="@xml/network_security_config"
    ...>
```

### Solution 3: Rooted Devices

On rooted devices, you can install the certificate as a system certificate:

1. Export the certificate
2. Convert to system format:
   ```bash
   openssl x509 -inform PEM -outform DER -in netscope.pem -out netscope.der
   subject_hash=$(openssl x509 -inform PEM -subject_hash_old -noout -in netscope.pem)
   mv netscope.der ${subject_hash}.0
   ```
3. Copy to system certificates:
   ```bash
   adb root
   adb remount
   adb push ${subject_hash}.0 /system/etc/security/cacerts/
   adb shell chmod 644 /system/etc/security/cacerts/${subject_hash}.0
   adb reboot
   ```

### Solution 4: Magisk Module

For Magisk rooted devices, use the "MagiskTrustUserCerts" module to move user certificates to system trust store.

## Configuring Device Traffic

### All Apps

1. Start the proxy in Syrah
2. Grant VPN permission
3. All device traffic will be captured

### Specific Apps Only (Android 10+)

1. Go to **Settings → Capture → App Filter**
2. Select which apps to intercept
3. Start the proxy

### Exclude System Apps

By default, some system apps bypass VPN. You can configure this in settings.

## Browser Configuration

### Chrome

Chrome uses the system proxy when VPN is active. Just start the Syrah proxy.

For certificate trust:
1. Visit any HTTPS site
2. If you see a warning, tap "Advanced"
3. Tap "Proceed" (after installing the certificate)

### Firefox

Firefox has its own certificate store:
1. Open Firefox
2. Type `about:config` in the address bar
3. Search for `security.enterprise_roots.enabled`
4. Set it to `true`
5. Restart Firefox

## Troubleshooting

### VPN Disconnects

If VPN keeps disconnecting:
1. Disable battery optimization for Syrah
2. Go to **Settings → Apps → Syrah → Battery**
3. Select **"Unrestricted"**

### Certificate Not Trusted

1. Verify certificate is installed in Settings
2. Some apps require system-level trust (see Android 7+ section)
3. Try reinstalling the certificate

### App Crashes When Intercepting

Some apps detect proxy/certificate modifications:
1. Try excluding the app from interception
2. Use debug builds of the app
3. Some apps simply cannot be intercepted

### Slow Performance

1. Reduce the number of intercepted apps
2. Clear old captured requests
3. Disable binary body capture for large files

## Building from Source

### Prerequisites

- Android Studio
- Flutter SDK 3.x
- Android SDK 21+

### Build Steps

```bash
# Clone repository
git clone https://github.com/benyaminsalimi/syrah_app.git
cd netscope

# Install melos
dart pub global activate melos

# Bootstrap project
melos bootstrap

# Build for Android
cd packages/netscope_app
flutter build apk --release
```

The APK will be at:
```
build/app/outputs/flutter-apk/app-release.apk
```

## Uninstallation

1. Stop the proxy and disconnect VPN
2. Remove the certificate:
   - Go to **Settings → Security → Encryption & credentials**
   - Tap **"Trusted credentials"**
   - Go to **"User"** tab
   - Select "Syrah Root CA" and remove
3. Uninstall the app

## Privacy & Security

- Syrah runs entirely on your device
- No data is sent to external servers
- The VPN is local-only (loopback)
- All certificates are generated locally
- Captured data stays on your device
