# Contract: Runtime Configuration

## Purpose

Defines how deployment-specific network configuration must behave for the stabilized client.

## Required Configuration Inputs

The client must resolve and validate these values before creating affected transport clients:

- `authBaseUrl`
- `chatBaseUrl`
- `fileBaseUrl`
- `wsBaseUrl`

## Behavioral Guarantees

- Maintainers can supply deployment-specific values without editing source files.
- Missing or invalid required values produce an explicit blocking configuration error before affected network flows begin.
- Network clients must consume one validated environment profile rather than each reading independent constants.
- Partial silent fallback to hardcoded defaults is not allowed for this feature.

## Validation Rules

- Each required value must be present.
- HTTP/HTTPS endpoints must be syntactically valid URLs for REST clients.
- WebSocket endpoint must be a syntactically valid WS/WSS URL.
- Validation failures must report which required values are invalid or missing.

## Operational Notes

- Contributor-facing setup documentation must explain how to supply environment values for local and release verification.
- If build tooling or startup flow changes the way configuration is supplied, reflect that change in `README.md`.
- Flutter Dart defines take precedence, with `.env` allowed only as a local fallback.
- An explicitly supplied empty or invalid Dart define must not fall back to `.env`; validation must block affected flows.
- Supported keys are:
  - `APP_ENVIRONMENT_NAME`
  - `APP_AUTH_BASE_URL`
  - `APP_CHAT_BASE_URL`
  - `APP_FILE_BASE_URL`
  - `APP_WS_BASE_URL`
