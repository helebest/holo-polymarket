# Privacy Policy

`holo-polymarket` is a local Agent Skills bundle. It does not collect, transmit,
or store any personal data on the maintainer's behalf.

## What the skills access

- **Polymarket Gamma & Data APIs** (`gamma-api.polymarket.com`,
  `data-api.polymarket.com`) — read-only market, leaderboard, position, trade,
  and history data, only when a query command is invoked.
- **Polymarket CLOB API** (`clob.polymarket.com`) — only when the
  `polymarket-trade` skill places, cancels, or reads orders/balances. These
  actions require credentials you provide locally and are dry-run by default.

## Credentials

- Credentials are read from local environment variables or a gitignored
  `KEY=VALUE` file (`./.credentials`, `~/.config/holo-polymarket/credentials`, or
  a legacy OpenClaw path). They are used only to authenticate and sign requests
  to Polymarket.
- The skills never write credentials anywhere and never print secret values.
  `trade.py whoami` reports only which fields are present plus the public wallet
  address.
- The private key controls funds; keep the credentials file out of version
  control and prefer a dedicated trading wallet.

## What we do not do

- No telemetry, analytics, or crash reporting.
- No outbound calls outside the documented Polymarket endpoints.
- The local file cache under `~/.cache/holo-polymarket/` stores only public API
  responses, never credentials.

## Reporting issues

File an issue at https://github.com/helebest/holo-polymarket/issues.
