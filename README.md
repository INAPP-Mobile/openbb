# Deploy and Host

[![Deploy to Railway](https://railway.app/button.svg)](https://railway.com/deploy/openbb)

![OpenBB Platform API](https://raw.githubusercontent.com/INAPP-Mobile/openbb/main/template-icon.svg)

**OpenBB** is an open-source, data-agnostic investment research platform. This template deploys **OpenBB Platform API** — the HTTP server that exposes the entire OpenBB data platform as a REST API — so you get a self-hosted endpoint for market data (equities, crypto, FX, commodities, fixed income, economy, news) from 70+ data providers, queryable over HTTP and streamable to LLM agents via MCP.

> **License note:** OpenBB is **AGPL-3.0**. This template runs the *installed packages* from [PyPI](https://pypi.org/project/openbb/) and their own `openbb-api` launcher — not a copy of the OpenBB source repo. If you modify and distribute, AGPLv3 obligations apply. For private, internal, or self-hosted use on your own Railway project, the AGPL network clause is typically fine, but consult your own counsel for commercial redistribution. [More: OpenBB license](https://github.com/OpenBB-finance/OpenBB/blob/main/LICENSE).

## About Hosting

The template deploys a **single service** — the OpenBB Platform REST API — built from one Dockerfile:

- **openbb** — `python:3.10-slim-bookworm` + `openbb[all]` (core + ~70 data providers + charting + MCP server) + `openbb-platform-api`, run by the `openbb-api` launcher (non-root, `HEALTHCHECK` on `/openapi.json`, `EXPOSE 6900`), `PORT=6900`.

No database, no volume. The API is stateless; provider credentials are sourced from environment variables at boot. Everything is provisioned by Railway — compute, TLS at the edge, and a public URL. You get one public base URL that serves the full REST API, Swagger UI, and OpenAPI spec.

## Why Deploy

- **Self-hosted market data API** — 70+ providers (yfinance, FRED, Polygon, EIA, SEC, CFTC, …) on one endpoint
- **Works out of the box** — free providers (yfinance) return real data with zero config
- **Full OpenAPI/REST** — 278+ documented endpoints; `provider` is an explicit parameter, not a hidden default
- **LLM-ready (MCP)** — ships `openbb-mcp`; expose the same endpoints as MCP tools for Claude/Cursor/Gemini agents
- **Credential-based access control** (optional) — flip `OPENBB_API_AUTH=true` for HTTP Basic auth on a shared/public project
- **One-click deploys** and predictable scaling — no DB, no migrations, restart-safe

## Common Use Cases

- **Quant / research tooling** — point backends, notebooks, or dashboards at a single market-data REST endpoint
- **LLM agent market research** — serve the API (or its MCP surface) to Claude, Cursor, Gemini, or any MCP client
- **Private data layer** — stand up OpenBB on your own Railway account so sensitive API keys and data never leave your infra
- **Internal market-data hub** — expose a single OpenAPI spec to product, research, and finance teams

## Dependencies for OpenBB

No external accounts, databases, or client tools are required. Optional: one or more data-provider API keys (FRED, Polygon, Alpha Vantage, etc.) to enable premium sources. Free providers (yfinance) return data with no credentials.

### Deployment Dependencies

Railway builds the service from this repository's Dockerfile (one `openbb[all]` pip install, ~6.5 GB download, cached by Rails' build). No database. No volume. The `PORT=6900` variable is injected automatically; the entrypoint maps it to the OpenBB launcher's bind port. All provider keys and the auth gate are set via the deploy form (see [Environment](#environment)).

## Endpoints

| Surface | Path | Purpose |
|---------|------|---------|
| OpenAPI spec | `/openapi.json` | Full REST schema (278+ paths) |
| Swagger UI | `/docs` | Interactive endpoint browser |
| ReDoc | `/redoc` | Read-only docs |
| Health / readiness | `/openapi.json` | 200 = API up |
| Market data (samples) | `/api/v1/equity/price/quote?provider=yfinance&symbol=AAPL` | Real-time equity quote (no key) |
| Market data (samples) | `/api/v1/equity/profile?provider=yfinance&symbol=AAPL` | Company profile (no key) |
| Market data (samples) | `/api/v1/equity/price/historical?provider=yfinance&symbol=AAPL&start_date=2025-01-01&end_date=2025-12-31` | Daily prices |
| Market data (keys) | `/api/v1/economy/cpi?provider=fred` | CPI (needs a free FRED key) |

> `provider` is a required query parameter on every endpoint (there is no implicit default) — if you omit it you get a 422. **`yfinance` needs no key**; most others (FRED, Polygon, Alpha Vantage, Benzinga, …) need an API key. See each endpoint's schema in `/openapi.json` for its full `provider_choices` list.

## MCP (optional)

The same image also ships the `openbb-mcp` launcher (bundled with `openbb[all]`). To run it in a second service on the same project, point the service's **start command** at:

```
openbb-mcp --transport streamable-http --host 0.0.0.0 --port $PORT
```

and give it its own public domain. It exposes every OpenBB REST endpoint as an MCP tool, so LLM agents can list tools, call them, and receive data directly. REST and MCP are independent surfaces — the REST service does **not** proxy through MCP; both read the same Python package.

## Environment

All variables are **optional**; the template works with zero config.

| Variable | Purpose | Default |
|----------|---------|---------|
| `PORT` | Listen port (injected by Railpack; mapped to `OPENBB_API_PORT` by the entrypoint) | `6900` |
| `TZ` | Timezone (IANA) for logs/output | `UTC` |
| `OPENBB_API_AUTH` | `true` → enable HTTP Basic auth on every endpoint | `false` |
| `OPENBB_API_USERNAME` / `OPENBB_API_PASSWORD` | Basic-auth credentials (used only when `OPENBB_API_AUTH=true`) | _(empty)_ |
| `POLYGON_API_KEY`, `FRED_API_KEY`, `ALPHA_VANTAGE_KEY`, … | Optional provider keys (any `*_API_KEY` / known credential name is picked up at boot) | _(empty)_ |

`yfinance` is a genuine no-key provider (quotes, profiles, historical prices). Most others — FRED, Polygon, Alpha Vantage, Benzinga, CoinDesk, etc. — need an API key, and some (FRED) offer a free-tier key that you paste in as the variable above. Keys you don't have can stay empty; those providers simply won't return data.

## Quick Start

1. Click **Deploy to Railway** (button above).
2. After the build + first deploy (~2–4 min), note the public URL shown on the service.
3. Open `https://<your-url>/docs` to browse the 278+ endpoints in Swagger.
4. Try this (free, no key): `https://<your-url>/api/v1/equity/price/quote?provider=yfinance&symbol=AAPL`.
5. Optional: add provider API keys to the **Variables** tab to unlock premium sources; set `OPENBB_API_AUTH=true` to gate the API if you expose it publicly.

## Troubleshooting

- **502 on first hit** — the OpenBB platform takes ~30–60s to load ~70 provider plugins at cold start. `railway.json` sets `healthcheckTimeout=300` and start-period=90s on the Dockerfile `HEALTHCHECK`; the deploy form uses these. Retry once if the first probe times out.
- **`{detail: {loc: query, provider}}` (422)** — every endpoint requires the `provider=` query parameter. It is not optional.
- **`{detail: "Not Found"}`** — path format is `/api/v1/<area>/<sub>/<call>` (e.g. `/api/v1/equity/price/quote`), not the command-line form (`openbb equity price quote`). Use `/openapi.json` to discover exact paths.
- **Provider `auth_error` / `insufficient_scope`** — the key for that provider isn't set, is wrong, or the free tier is exhausted. Add the correct `*_API_KEY` variable and redeploy.
- **AGPL concerns** — see the note at the top.

## Upstream

- OpenBB platform: https://github.com/OpenBB-finance/OpenBB
- Docs: https://docs.openbb.co
- This template is a thin wrapper around [PyPI `openbb[all]`](https://pypi.org/project/openbb/4.7.2/) + [`openbb-platform-api`](https://pypi.org/project/openbb-platform-api/1.3.6/), based on the vendor's own `build/docker/platformAPI.Dockerfile`.
