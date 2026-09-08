# Jakob's OmniRoute Setup

This fork is prepared for a Windows-first OmniRoute setup.

## What this gives you

- OmniRoute desktop app for Windows x64.
- Local dashboard/server on the normal OmniRoute port (`20128`).
- The existing OmniRoute provider/routing system remains unchanged.
- A GitHub Actions workflow in this fork can build a Windows installer and portable build without requiring a local compiler toolchain.

## Important security rule

Do **not** commit API keys, provider tokens, passwords, OAuth tokens, or a real `.env` file to GitHub. Configure credentials inside OmniRoute or in a local `.env` only.

## Local Windows setup

1. Install Node.js 24.
2. Clone this repository and check out `release/v3.8.51`.
3. In the repository folder run:

```powershell
npm ci
npm run electron:build:win
```

The Windows outputs are written to:

```text
electron/dist-electron/
```

The Electron configuration currently builds both:

- `OmniRoute.Setup.3.8.51.exe` (installer)
- a Windows x64 portable executable

## Development mode

To run the dashboard/server during development:

```powershell
npm ci
npm run dev
```

OmniRoute's desktop development command is:

```powershell
npm run electron:dev
```

The project waits for the local OmniRoute service at:

```text
http://localhost:20128
```

## GitHub build

The `Build Jakob OmniRoute Windows` workflow builds the Windows desktop package on a GitHub-hosted Windows runner and uploads `electron/dist-electron` as an Actions artifact.

This workflow does not contain or require personal provider keys.

## Fork maintenance

This repository is a fork of OmniRoute. Keep personal setup changes small and isolated so upstream releases can still be merged cleanly.
