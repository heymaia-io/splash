# Komga fixture server

Deterministic Komga instance used by every phase of the iOS port (plan: Phase 0).

```sh
./setup.sh                 # generate CBZs, start container, seed data, dump openapi.json
docker compose down        # stop (data persists in ./data, gitignored)
```

- URL: `http://localhost:25601` — admin `admin@fixture.local` / `fixture-password`
- Libraries: **Comics** (2 series + 1 oneshot in `_oneshots`), **Manga** (RTL series + double-page spread series), **Webtoon** (tall pages, `readingDirection=WEBTOON`)
- 1 collection (`Fixture Collection`), 1 ordered read list (`Fixture Read List`)
- `openapi.json`: `GET /v3/api-docs` snapshot, the wire-format source of truth (see `docs/wire-format.md`)

Server facts verified against this fixture (Komga 1.27.0):
- `GET /api/v1/books/{id}/file` **ignores `Range`** (always `200` + full body) → download resume via `resumeData` is not possible; retries restart from zero.
- Timestamps are ISO-8601, with *and* without fractional seconds (`2026-09-17T08:08:36Z`, `...57.524+00:00`).
