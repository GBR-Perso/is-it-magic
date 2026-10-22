# MCP Server (TypeScript) — Conventions

> How an MCP server in front of an existing API is organised, so changes land in the right place.
> Guidance for planning and implementation — not enforced line-rules.

## Role

- The MCP server is another consumer of the app's API, never a second backend: no database, no business rules
- The API stays the security boundary. The MCP server authenticates the caller and forwards their token; the API authorises
- A self-contained TypeScript package (`@modelcontextprotocol/sdk`, `zod`) in its own folder — no dependency on the front end or its generated client

## Transport & configuration

- Streamable HTTP at `/mcp` for deployed use; stdio only as a local convenience
- All configuration read once from environment variables in one config module; an env template lists them
- Never log tokens or API response bodies — log method, path, status and duration only

## Sessions & scaling

- **Prefer stateless**: build a fresh server and transport per request (`sessionIdGenerator: undefined`). It scales to zero and out freely
- A server holding sessions in memory must run as exactly one always-on instance — scaling to zero drops open sessions, and a second instance cannot see the first one's. Never change its replica settings without moving the sessions out first

## Auth

- MCP clients expect the server to be an OAuth authorisation server with dynamic client registration. When the identity provider does not offer it, the server proxies OAuth in front of the provider
- **Never change the OAuth proxy or token verification without explicit confirmation** — a mistake there opens the API to every MCP client
- Tools call the API with the **caller's** token, read per request from `extra.authInfo?.token` — never a token captured when the session opened (it expires), never a service identity

## Tools

- Tool names are `snake_case` constants, verb first: `get_<entities>`, `get_<entity>`, `create_<entity>`, `update_<entity>`, `delete_<entity>`
- Tools live under `tools/`, one file per entity (or per tool while there are few), each exporting a `register…` function; the server wires them all in one spot
- Every tool has a description an LLM can act on, a `zod` input schema and `annotations`: `readOnlyHint: true` for reads; writes state `readOnlyHint`, `destructiveHint`, `idempotentHint` and `openWorldHint` explicitly
- API failures come back as `isError` tool results with a readable message, never as thrown errors. A 401/403 tells the user to re-authenticate
- Updates are partial: read the current entity, merge only the supplied fields, then write

## Tests

- Unit-test each tool with the API client mocked: annotations, the API calls made, the error results
- Keep at least one end-to-end test that connects through the SDK `Client` over HTTP and calls a tool
