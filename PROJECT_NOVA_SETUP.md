# Project Nova — OmniRoute setup

This fork is being prepared as the Project Nova local AI gateway. It remains based on OmniRoute and keeps the upstream MIT license.

## What this setup does

- Runs OmniRoute locally on `http://localhost:20128`.
- Keeps provider credentials on the local computer; do **not** commit `.env` or API keys.
- Makes the local OpenAI-compatible endpoint available at `http://localhost:20128/v1`.
- Provides helper commands for Codex and other supported coding tools after OmniRoute is running.

## Windows requirements

OmniRoute `3.8.51` requires Node.js `>=22.22.2 <23` or `>=24 <27`. Node 24 LTS is the recommended choice for this fork.

Git is also required if you are cloning this repository normally.

## One-command local preparation

From PowerShell in the repository folder:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\setup\project-nova-windows.ps1 -Install
```

The helper checks Node, installs dependencies with `npm ci`, and prints the next commands.

To start OmniRoute:

```powershell
.\scripts\setup\project-nova-windows.ps1 -Start
```

Then open:

- Dashboard: `http://localhost:20128`
- OpenAI-compatible API base: `http://localhost:20128/v1`

## Connect Codex

With OmniRoute already running:

```powershell
npx omniroute setup-codex
```

Or launch Codex through OmniRoute without permanently rewriting Codex configuration:

```powershell
npx omniroute run codex --model auto/coding
```

The upstream CLI also supports `setup-claude`, `setup-opencode`, `setup-cline`, `setup-roo`, `setup-aider`, `setup-qwen`, `setup-goose`, and other integrations.

## Provider setup

Use the OmniRoute dashboard to connect only the providers/accounts you actually want to use. Credentials must stay local. Never paste provider secrets into this repository or commit a generated `.env` file.

The routing model `auto/coding` is a useful coding-oriented default once providers are connected. `auto` is the balanced general default.

## Verify the local gateway

With OmniRoute running:

```powershell
.\scripts\setup\project-nova-windows.ps1 -Check
```

The check confirms the local dashboard is answering on port `20128` and reports the `/v1/models` endpoint status.

## Important

This helper does not bypass a provider's own terms, billing, authentication, or rate limits. OmniRoute can route between configured providers and free tiers, but each provider remains subject to its own rules and availability.
