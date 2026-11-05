# Railynx

Railynx answers one question: which Railway IP actually works from here, right now?

## How a scan runs

1. You paste a `vless://` link — Railynx reads your server details out of it.
2. It walks the candidate range (69.46.46.0/24 by default) and talks to each address.
3. Nothing is taken on faith: every candidate has to complete a real VLESS handshake and return an HTTP 204 through the tunnel, three rounds in a row.
4. Survivors land in a ranked list, fastest first. Copy the winners as plain IPs, or let Railynx write finished configs that keep your link's name and settings.

## Platforms

- **Android** — one universal APK, plus per-ABI builds.
- **Windows** — a portable zip; unpack it and run `Railynx.exe`.

Both share this single Flutter codebase, the same screens and the same engine.

## Build it yourself

```sh
flutter pub get
flutter test            # engine golden tests + UI tests
flutter build apk --release --split-per-abi
flutter build windows --release
```

## Layout

- `lib/engine/` — probing, handshake checks and config writing (pure Dart).
- `lib/ui/` — the screens.
- `test/` — golden fixtures for the engine and widget tests for the UI.
