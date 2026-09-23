#!/usr/bin/env bash
# ship-testflight.sh — bump, archive, export, upload, and attach "What to Test".
#
#   scripts/ship-testflight.sh "What changed, in words a tester reads"
#
# ⭐ WHY THIS EXISTS (2026-09-21). The pipeline below was hand-typed into the
# terminal for builds 21–29, and the notes script lived in a temp folder that was
# wiped between sessions. A process that has to be re-derived every time is a
# rule that must be remembered, and those do not survive. This is the one copy.
#
# The three ASC gotchas it handles (see ~/Athena/reference/appstore-connect-upload.md):
#   1. Internal testers get every build automatically — never POST a group.
#   2. The upload does not carry notes; they are a separate call.
#   3. That call 409s after the first build, so the existing localization is PATCHed.
set -euo pipefail

NOTES="${1:?usage: scripts/ship-testflight.sh \"What to Test notes\"}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
PBX="$REPO/BrainDiet.xcodeproj/project.pbxproj"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/braindiet-ship.XXXX")"
# ⭐ CREDENTIALS LIVE OUTSIDE THE REPO (2026-09-22). This repo is public for the
# Shipaton Next Gen entry, so the key and issuer IDs are read from the
# environment, falling back to a local config file. The private .p8 was always
# outside the repo and still is.
if [[ -f "$HOME/.appstoreconnect/braindiet.env" ]]; then
  # shellcheck disable=SC1091
  source "$HOME/.appstoreconnect/braindiet.env"
fi
KEY_ID="${ASC_KEY_ID:?set ASC_KEY_ID (or create ~/.appstoreconnect/braindiet.env)}"
ISSUER="${ASC_ISSUER_ID:?set ASC_ISSUER_ID (or create ~/.appstoreconnect/braindiet.env)}"

# ⭐ THE NEXT NUMBER COMES FROM APPLE, NOT FROM THE FILE (2026-09-22). Build 31
# bumped the file, archived, then died on a network error — leaving the repo
# claiming 31 while TestFlight still had 30, so the next run would have skipped a
# number and nobody would know 31 never existed. Deriving it from the highest
# build ASC has seen makes a failed ship self-healing: re-run and it reuses the
# number instead of burning a new one.
cur=$(grep -m1 -o 'CURRENT_PROJECT_VERSION = [0-9]*;' "$PBX" | grep -o '[0-9]*')
latest=$(KEY_ID="$KEY_ID" ISSUER="$ISSUER" python3 - <<'PY'
import jwt, time, json, os, urllib.request
KEY = os.path.expanduser(f"~/.appstoreconnect/private_keys/AuthKey_{os.environ['KEY_ID']}.p8")
tok = jwt.encode({"iss": os.environ["ISSUER"], "exp": int(time.time()) + 900, "aud": "appstoreconnect-v1"},
                 open(KEY).read(), algorithm="ES256", headers={"kid": os.environ["KEY_ID"], "typ": "JWT"})
req = urllib.request.Request("https://api.appstoreconnect.apple.com/v1/builds"
                             "?filter[app]=6795648624&sort=-uploadedDate&limit=20")
req.add_header("Authorization", "Bearer " + tok)
try:
    data = json.load(urllib.request.urlopen(req))["data"]
    print(max(int(b["attributes"]["version"]) for b in data))
except Exception:
    print(0)
PY
)
[[ "$latest" == "0" ]] && { echo "could not reach App Store Connect — check the network before shipping" >&2; exit 1; }
next=$((latest + 1))
sed -i '' "s/CURRENT_PROJECT_VERSION = $cur;/CURRENT_PROJECT_VERSION = $next;/g" "$PBX"
echo ">> TestFlight has $latest · building $next (file said $cur)"

# com.apple.provenance cannot be removed and is harmless; only FinderInfo breaks codesign.
xattr -cr "$REPO" 2>/dev/null || true

xcodebuild -project "$REPO/BrainDiet.xcodeproj" -scheme BrainDiet -configuration Release \
  -destination "generic/platform=iOS" -archivePath "$WORK/BrainDiet.xcarchive" archive -quiet
xcodebuild -exportArchive -archivePath "$WORK/BrainDiet.xcarchive" \
  -exportOptionsPlist "$REPO/ExportOptions.plist" -exportPath "$WORK/export" -quiet

APP="$WORK/BrainDiet.xcarchive/Products/Applications/BrainDiet.app"
[[ "$(plutil -extract CFBundleVersion raw "$APP/Info.plist")" == "$next" ]] || { echo "archive carries the wrong build number" >&2; exit 1; }
[[ "$(ls "$APP/PlugIns" | wc -l | tr -d ' ')" == "3" ]] || { echo "expected 3 extensions in the archive" >&2; exit 1; }

# ⭐ RETRY, AND FAIL LOUDLY. The upload is the one step that depends on a network
# that is not always there. Build 31 died on -1009 and the run still reported
# success, because the pipeline's exit status came from the reader, not altool.
uploaded=0
for attempt in 1 2 3; do
  if xcrun altool --upload-app -f "$WORK/export/BrainDiet.ipa" -t ios \
       --apiKey "$KEY_ID" --apiIssuer "$ISSUER" 2>&1 | tee "$WORK/upload.log" \
       | grep -E "UPLOAD SUCCEEDED|Delivery UUID|ERROR"
     grep -q "UPLOAD SUCCEEDED" "$WORK/upload.log"; then
    uploaded=1; break
  fi
  echo ">> upload attempt $attempt failed; retrying in 60s" >&2
  sleep 60
done
[[ "$uploaded" == "1" ]] || {
  echo "UPLOAD FAILED after 3 attempts — build $next did NOT reach TestFlight." >&2
  tail -3 "$WORK/upload.log" >&2
  exit 1
}

NOTES="$NOTES" WANT="$next" KEY_ID="$KEY_ID" ISSUER="$ISSUER" python3 - <<'PY'
import jwt, time, json, os, sys, urllib.request, urllib.error
KEY = os.path.expanduser(f"~/.appstoreconnect/private_keys/AuthKey_{os.environ['KEY_ID']}.p8")
APP, WANT, NOTES = "6795648624", os.environ["WANT"], os.environ["NOTES"]

def call(method, path, body=None):
    tok = jwt.encode({"iss": os.environ["ISSUER"], "exp": int(time.time()) + 900, "aud": "appstoreconnect-v1"},
                     open(KEY).read(), algorithm="ES256", headers={"kid": os.environ["KEY_ID"], "typ": "JWT"})
    req = urllib.request.Request("https://api.appstoreconnect.apple.com" + path, method=method,
                                 data=json.dumps(body).encode() if body else None)
    req.add_header("Authorization", "Bearer " + tok)
    if body: req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read(); return r.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"{}")

for _ in range(40):                     # processing takes ~2–10 minutes
    _, b = call("GET", f"/v1/builds?filter[app]={APP}&sort=-uploadedDate&limit=5")
    row = next((x for x in b.get("data", []) if x["attributes"]["version"] == WANT), None)
    if row and row["attributes"]["processingState"] == "VALID": break
    time.sleep(30)
else:
    sys.exit(f"build {WANT} never reached VALID")

bid = row["id"]
_, locs = call("GET", f"/v1/builds/{bid}/betaBuildLocalizations")
loc = next((l for l in locs.get("data", []) if l["attributes"]["locale"] == "en-US"), None)
if loc:
    s, _ = call("PATCH", f"/v1/betaBuildLocalizations/{loc['id']}",
                {"data": {"type": "betaBuildLocalizations", "id": loc["id"], "attributes": {"whatsNew": NOTES}}})
else:
    s, _ = call("POST", "/v1/betaBuildLocalizations",
                {"data": {"type": "betaBuildLocalizations", "attributes": {"locale": "en-US", "whatsNew": NOTES},
                          "relationships": {"build": {"data": {"type": "builds", "id": bid}}}}})
for _ in range(10):                     # READY_FOR_BETA_TESTING flips to IN_ within a minute
    _, d = call("GET", f"/v1/builds/{bid}/buildBetaDetail")
    state = d["data"]["attributes"]["internalBuildState"]
    if state == "IN_BETA_TESTING": break
    time.sleep(15)
print(f">> build {WANT} VALID · {state} · notes {s}")
PY

rm -rf "$WORK"
