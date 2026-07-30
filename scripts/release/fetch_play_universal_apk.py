#!/usr/bin/env python3
"""Download the Play-signed universal APK for a version code.

Play processes every uploaded bundle into APKs signed with the app
signing key. The universal APK among them carries the same signature as
store installs, which is what makes it worth attaching to a GitHub
release: either install source can update the other.

Credentials come from GOOGLE_PLAY_SERVICE_ACCOUNT (the JSON itself, not
a path), matching how CI stores the secret. APK generation can lag the
bundle upload by a few minutes, so the lookup retries on a bounded
schedule.
"""

import argparse
import json
import os
import sys
import time
from urllib.parse import quote

from google.auth.transport.requests import AuthorizedSession
from google.oauth2 import service_account

BASE = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications"
ATTEMPTS = 20
DELAY_SECONDS = 30


def session_from_env() -> AuthorizedSession:
    raw = os.environ.get("GOOGLE_PLAY_SERVICE_ACCOUNT")
    if not raw:
        sys.exit("GOOGLE_PLAY_SERVICE_ACCOUNT is not set")
    creds = service_account.Credentials.from_service_account_info(
        json.loads(raw),
        scopes=["https://www.googleapis.com/auth/androidpublisher"],
    )
    return AuthorizedSession(creds)


def find_universal_download_id(
    session: AuthorizedSession, package: str, version_code: int
) -> str:
    url = f"{BASE}/{package}/generatedApks/{version_code}"
    for attempt in range(1, ATTEMPTS + 1):
        resp = session.get(url)
        if resp.status_code == 200:
            for entry in resp.json().get("generatedApks", []):
                universal = entry.get("generatedUniversalApk")
                if universal:
                    cert = entry.get("certificateSha256Hash", "unknown")
                    print(f"found universal APK, signing cert {cert}")
                    return universal["downloadId"]
        elif resp.status_code != 404 and resp.status_code < 500:
            sys.exit(
                f"generatedApks lookup failed: "
                f"HTTP {resp.status_code}: {resp.text[:300]}"
            )
        if attempt < ATTEMPTS:
            print(
                f"universal APK not ready (attempt {attempt}/{ATTEMPTS}), "
                f"retrying in {DELAY_SECONDS}s"
            )
            time.sleep(DELAY_SECONDS)
    sys.exit(
        f"universal APK for version code {version_code} never appeared "
        f"after {ATTEMPTS} attempts"
    )


def download(
    session: AuthorizedSession,
    package: str,
    version_code: int,
    download_id: str,
    output: str,
) -> None:
    # downloadId is base64 and can contain '/', '+' and '=', which must not
    # reach the URL path raw.
    url = (
        f"{BASE}/{package}/generatedApks/{version_code}"
        f"/downloads/{quote(download_id, safe='')}:download?alt=media"
    )
    with session.get(url, stream=True) as resp:
        if resp.status_code != 200:
            sys.exit(f"download failed: HTTP {resp.status_code}: {resp.text[:300]}")
        with open(output, "wb") as fh:
            for chunk in resp.iter_content(chunk_size=1 << 20):
                fh.write(chunk)
    size = os.path.getsize(output)
    if size < 1 << 20:
        sys.exit(f"downloaded APK is suspiciously small ({size} bytes)")
    print(f"wrote {output} ({size / (1 << 20):.1f} MiB)")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", required=True)
    parser.add_argument("--version-code", required=True, type=int)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    session = session_from_env()
    download_id = find_universal_download_id(session, args.package, args.version_code)
    download(session, args.package, args.version_code, download_id, args.output)


if __name__ == "__main__":
    main()
