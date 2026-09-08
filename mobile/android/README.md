# OmniRoute Mobile for Android

This is a lightweight Android phone client for OmniRoute. The phone app connects to an OmniRoute server running on a PC, VPS, or other reachable host and displays the OmniRoute dashboard in an Android WebView.

## First launch

1. Open OmniRoute Mobile.
2. Enter the address of your OmniRoute server.
3. Tap **Connect**.

Examples:

- `https://your-omniroute-server.example`
- `http://192.168.1.50:20128` for a server on the same local network

The app saves the server address locally on the phone. Use the **Server** button to change it later.

## Build

The GitHub Actions workflow `.github/workflows/android-phone-build.yml` automatically builds a debug APK and uploads it as the `OmniRoute-Mobile-Android` artifact.

This client does not bypass provider quotas. OmniRoute's provider routing and fallback behavior remains controlled by the server.
