# Phone version

OmniRoute Mobile is the Android phone client for this fork. It is designed for phones first and connects to an OmniRoute server running elsewhere.

Current phone features:

- Android launcher app
- Server-address setup screen
- Remembers the selected OmniRoute server
- Full dashboard in an in-app WebView
- Back, Home, and Server controls
- Supports HTTPS servers and same-network HTTP addresses
- GitHub Actions APK build

The mobile client intentionally keeps provider credentials and routing logic on the OmniRoute server rather than embedding them into the APK.
