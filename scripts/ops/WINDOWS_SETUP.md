# Windows setup helper

On Windows, open `scripts\ops\SETUP_WINDOWS.bat` from the repository checkout to run the guided OmniRoute setup.

The helper verifies that Node.js is within OmniRoute's supported runtime range, installs dependencies, builds the production standalone server, links the local `omniroute` CLI, runs the guided setup, and can start the server when setup finishes.

Supported Node.js versions are Node 22.22.2 or newer on the 22.x line, or Node 24 through 26.

Provider quotas and rate limits are still enforced by the providers themselves. OmniRoute can use configured fallback providers when one provider is unavailable or rate-limited, but it does not remove provider-imposed limits.
