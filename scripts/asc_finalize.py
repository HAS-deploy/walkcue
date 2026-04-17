#!/usr/bin/env python3
"""
Post-upload finalization for SleepWindow.

- waits for the uploaded build to appear (processing takes 10-30 min)
- sets export compliance on the build (uses non-exempt encryption = false)
- links the build to the 1.0 app version
- sets primary category = PRODUCTIVITY, secondary = LIFESTYLE
"""
import os, time, json, urllib.request, urllib.parse, sys, datetime
import jwt

APP_ID = os.environ.get("APP_ID", "6762465676")
KEY_ID = os.environ["ASC_KEY_ID"]
ISSUER = os.environ["ASC_ISSUER_ID"]
KEY_PATH = os.environ.get("ASC_KEY_PATH", f"{os.path.expanduser('~')}/.appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8")
BASE = "https://api.appstoreconnect.apple.com"
BUNDLE_ID = "com.sleepwindow.app"


def token():
    with open(KEY_PATH, "rb") as f: key = f.read()
    return jwt.encode(
        {"iss": ISSUER, "iat": int(time.time()), "exp": int(time.time()) + 1200, "aud": "appstoreconnect-v1"},
        key, algorithm="ES256", headers={"kid": KEY_ID, "typ": "JWT"})


def req(method, path, body=None, params=None):
    if params:
        path = path + "?" + urllib.parse.urlencode(params, safe="[]")
    url = path if path.startswith("http") else BASE + path
    headers = {"Authorization": f"Bearer {token()}"}
    data = None
    if body is not None:
        data = json.dumps(body).encode()
        headers["Content-Type"] = "application/json"
    r = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        return json.loads(urllib.request.urlopen(r).read() or b"{}")
    except urllib.error.HTTPError as e:
        body_s = e.read().decode(errors="replace")
        print(f"HTTP {e.code} {method} {url}\n{body_s}", file=sys.stderr)
        raise


def wait_for_build(timeout=1800, interval=30):
    """Poll for a processed build. Picks newest by uploadedDate attribute."""
    start = time.time()
    while time.time() - start < timeout:
        resp = req("GET", f"/v1/apps/{APP_ID}/builds", params={"limit": 20})
        builds = sorted(
            resp.get("data", []),
            key=lambda b: b["attributes"].get("uploadedDate") or "",
            reverse=True,
        )
        if not builds:
            print("  no builds yet")
        for b in builds[:3]:
            state = b["attributes"]["processingState"]
            version = b["attributes"]["version"]
            uploaded = b["attributes"].get("uploadedDate", "")
            print(f"  build {b['id']} v={version} state={state} uploaded={uploaded}")
        newest = builds[0] if builds else None
        if newest and newest["attributes"]["processingState"] == "VALID":
            return newest
        time.sleep(interval)
    raise RuntimeError("timed out waiting for build to process")


def set_export_compliance(build_id):
    print(f"Setting export compliance on build {build_id} ...")
    try:
        req("PATCH", f"/v1/builds/{build_id}", {
            "data": {
                "type": "builds",
                "id": build_id,
                "attributes": {"usesNonExemptEncryption": False},
            }
        })
        print("  -> done")
    except Exception as e:
        print(f"  skipped ({e})")


def link_build_to_version(build_id):
    # find latest editable version
    versions = req("GET", f"/v1/apps/{APP_ID}/appStoreVersions", params={"limit": 5})
    v = None
    for version in versions.get("data", []):
        if version["attributes"]["appStoreState"] in {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED"}:
            v = version
            break
    if not v:
        print("No editable version found")
        return
    print(f"Linking build {build_id} to version {v['attributes']['versionString']} ({v['id']}) ...")
    req("PATCH", f"/v1/appStoreVersions/{v['id']}/relationships/build", {
        "data": {"type": "builds", "id": build_id}
    })
    print("  -> linked")


def set_category():
    # Find the in-prep appInfo
    infos = req("GET", f"/v1/apps/{APP_ID}/appInfos", params={"limit": 5})
    info = None
    for i in infos.get("data", []):
        if i["attributes"]["state"] not in {"READY_FOR_DISTRIBUTION", "APPLE_REJECTED"}:
            info = i
            break
    if not info:
        info = infos["data"][0]
    info_id = info["id"]
    print(f"Setting category on appInfo {info_id} ...")
    try:
        req("PATCH", f"/v1/appInfos/{info_id}", {
            "data": {
                "type": "appInfos",
                "id": info_id,
                "relationships": {
                    "primaryCategory": {"data": {"type": "appCategories", "id": "PRODUCTIVITY"}},
                    "secondaryCategory": {"data": {"type": "appCategories", "id": "LIFESTYLE"}},
                },
            }
        })
        print("  -> done")
    except Exception as e:
        print(f"  skipped ({e})")


if __name__ == "__main__":
    action = sys.argv[1] if len(sys.argv) > 1 else "all"
    if action in ("all", "wait"):
        build = wait_for_build()
        if action == "wait":
            print(f"BUILD_ID={build['id']}")
            sys.exit(0)
    else:
        build = None

    if action in ("all", "compliance"):
        if build is None:
            # use most recent
            resp = req("GET", f"/v1/apps/{APP_ID}/builds", params={"limit": 20})
            build = resp["data"][0]
        set_export_compliance(build["id"])
    if action in ("all", "link"):
        if build is None:
            resp = req("GET", f"/v1/apps/{APP_ID}/builds", params={"limit": 20})
            build = resp["data"][0]
        link_build_to_version(build["id"])
    if action in ("all", "category"):
        set_category()
