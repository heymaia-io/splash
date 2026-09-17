#!/usr/bin/env bash
# Boots the fixture Komga server and seeds it. Idempotent-ish: claim/library creation errors are ignored on re-runs.
set -euo pipefail
cd "$(dirname "$0")"
BASE="http://localhost:25601"
EMAIL="admin@fixture.local"
PASS="fixture-password"

python3 generate_library.py
docker compose up -d

echo "waiting for Komga..."
until curl -sf "$BASE/api/v1/claim" >/dev/null; do sleep 2; done

curl -sf -X POST "$BASE/api/v1/claim" -H "X-Komga-Email: $EMAIL" -H "X-Komga-Password: $PASS" >/dev/null || true
AUTH=(-u "$EMAIL:$PASS")

lib_id() { curl -sf "${AUTH[@]}" "$BASE/api/v1/libraries" | python3 -c "import json,sys; print(next((l['id'] for l in json.load(sys.stdin) if l['name']=='$1'),''))"; }
create_lib() {
  [ -n "$(lib_id "$1")" ] && return 0
  curl -sf "${AUTH[@]}" -X POST "$BASE/api/v1/libraries" -H 'Content-Type: application/json' -d "$2" >/dev/null
}
create_lib Comics  '{"name":"Comics","root":"/data/Comics","oneshotsDirectory":"_oneshots"}'
create_lib Manga   '{"name":"Manga","root":"/data/Manga"}'
create_lib Webtoon '{"name":"Webtoon","root":"/data/Webtoon"}'

echo "waiting for scan/analysis..."
for _ in $(seq 1 60); do
  n=$(curl -sf "${AUTH[@]}" "$BASE/api/v1/books?size=1" | python3 -c "import json,sys; print(json.load(sys.stdin)['totalElements'])")
  [ "$n" -ge 12 ] && break; sleep 2
done
sleep 5

series_id() { curl -sf "${AUTH[@]}" -X POST "$BASE/api/v1/series/list" -H 'Content-Type: application/json' \
  -d "{\"condition\":{\"title\":{\"operator\":\"is\",\"value\":\"$1\"}}}" | python3 -c "import json,sys; print(json.load(sys.stdin)['content'][0]['id'])"; }
HERO=$(series_id "Fixture Hero"); MANGA=$(series_id "Fixture Manga")

has() { curl -sf "${AUTH[@]}" "$BASE/api/v1/$1" | python3 -c "import json,sys; print(any(c['name']=='$2' for c in json.load(sys.stdin)['content']))"; }
if [ "$(has collections 'Fixture Collection')" = "False" ]; then
  curl -sf "${AUTH[@]}" -X POST "$BASE/api/v1/collections" -H 'Content-Type: application/json' \
    -d "{\"name\":\"Fixture Collection\",\"ordered\":false,\"seriesIds\":[\"$HERO\",\"$MANGA\"]}" >/dev/null
fi
if [ "$(has readlists 'Fixture Read List')" = "False" ]; then
  BOOKS=$(curl -sf "${AUTH[@]}" -X POST "$BASE/api/v1/books/list?sort=metadata.numberSort,asc" -H 'Content-Type: application/json' \
    -d "{\"condition\":{\"seriesId\":{\"operator\":\"is\",\"value\":\"$HERO\"}}}" | python3 -c "import json,sys; print(json.dumps([b['id'] for b in json.load(sys.stdin)['content']][:2]))")
  curl -sf "${AUTH[@]}" -X POST "$BASE/api/v1/readlists" -H 'Content-Type: application/json' \
    -d "{\"name\":\"Fixture Read List\",\"summary\":\"fixture\",\"ordered\":true,\"bookIds\":$BOOKS}" >/dev/null
fi

# ComicInfo has no reliable webtoon flag -> set reading direction explicitly (exercises the CONTINUOUS reader).
WEBTOON=$(series_id "Fixture Webtoon")
curl -sf "${AUTH[@]}" -X PATCH "$BASE/api/v1/series/$WEBTOON/metadata" -H 'Content-Type: application/json' \
  -d '{"readingDirection":"WEBTOON","readingDirectionLock":true}' >/dev/null

curl -sf "${AUTH[@]}" "$BASE/v3/api-docs" -o openapi.json
echo "Komga $(curl -sf "${AUTH[@]}" "$BASE/actuator/info" | python3 -c "import json,sys; print(json.load(sys.stdin).get('build',{}).get('version'))") ready at $BASE ($EMAIL / $PASS)"
