#!/usr/bin/env python3
"""Register a deterministic test user on an ephemeral hoodik server.

Used exclusively by scripts/compat/bootstrap.sh. Not a general-purpose tool.

Why this exists: the compat gate needs a known user before the Patrol E2E
tests can log in, and every supported server version (v1.7.0+) validates the
register payload identically — pubkey (PKCS#1 PEM) + fingerprint + password-
encrypted private key. The app reads `encrypted_private_key` back on login
and decrypts it with the password (Ascon-128a, 32-byte key derived from the
password padded to 32 chars with '0'). This script reproduces the exact same
scheme so the app's login ceremony succeeds.

Dependencies (installed into scripts/compat/.venv by bootstrap.sh):
  cryptography  — RSA-2048 PKCS#1 PEM keygen, modulus extraction
  ascon         — Ascon-128a AEAD, matches cryptfns::aes::encrypt
  requests      — HTTP POST to /api/auth/register
"""

import argparse
import hashlib
import json
import sys
from pathlib import Path

try:
    import ascon
    import requests
    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.primitives.asymmetric import rsa
except ImportError as exc:
    sys.stderr.write(
        "register_test_user.py: missing dependency — run bootstrap.sh which "
        f"sets up scripts/compat/.venv ({exc})\n"
    )
    sys.exit(2)


def password_to_key_nonce(password: str) -> tuple[bytes, bytes]:
    """Mirror of `CryptoService._passwordToKey` in lib/core/crypto/crypto_service.dart.

    Pad the password to exactly 32 chars with '0' (truncate if longer), UTF-8
    encode, then split into a 16-byte Ascon key and 16-byte Ascon nonce.
    """
    if len(password) >= 32:
        padded = password[:32]
    else:
        padded = password + "0" * (32 - len(password))
    material = padded.encode("utf-8")
    assert len(material) == 32, "password material must be 32 bytes"
    return material[:16], material[16:]


def rsa_fingerprint(public_key: rsa.RSAPublicKey) -> str:
    """Match cryptfns::rsa::fingerprint: sha256(hex(n_bytes_be)).

    Not sha256 of the raw bytes — sha256 of the *hex string* encoded as ASCII.
    The digest is returned as lowercase hex (sha256's stable textual form).
    """
    n = public_key.public_numbers().n
    n_bytes = n.to_bytes((n.bit_length() + 7) // 8, "big")
    hex_str = n_bytes.hex()
    return hashlib.sha256(hex_str.encode("ascii")).hexdigest()


def generate_fixture(password: str) -> dict:
    """Generate RSA-2048 PKCS#1 keys, fingerprint, and password-encrypted key."""
    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    public_key = private_key.public_key()

    private_pem = private_key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.TraditionalOpenSSL,  # PKCS#1
        encryption_algorithm=serialization.NoEncryption(),
    ).decode("utf-8")

    public_pem = public_key.public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.PKCS1,
    ).decode("utf-8")

    fingerprint = rsa_fingerprint(public_key)
    key, nonce = password_to_key_nonce(password)

    # Ascon-128a AEAD; ciphertext includes a 16-byte tag suffix. The hoodik
    # server stores the (ciphertext || tag) blob as hex and gives it back on
    # login in the same form.
    blob = ascon.encrypt(
        key=key,
        nonce=nonce,
        associateddata=b"",
        plaintext=private_pem.encode("utf-8"),
        variant="Ascon-128a",
    )
    encrypted_private_key = blob.hex()

    return {
        "pubkey": public_pem,
        "fingerprint": fingerprint,
        "encrypted_private_key": encrypted_private_key,
    }


def post_register(base_url: str, email: str, password: str, fixture: dict) -> None:
    payload = {
        "email": email,
        "password": password,
        "pubkey": fixture["pubkey"],
        "fingerprint": fixture["fingerprint"],
        "encrypted_private_key": fixture["encrypted_private_key"],
    }
    resp = requests.post(
        f"{base_url.rstrip('/')}/api/auth/register",
        json=payload,
        timeout=10,
    )
    if resp.status_code in (200, 201, 204):
        return

    # 422 with `invalid_email` means a previous run already registered this
    # user — harmless on a re-used volume. For the compat gate we wipe the
    # volume between runs so we shouldn't hit this, but tolerating it keeps
    # re-runs cheap during local iteration.
    if resp.status_code == 422 and "invalid_email" in resp.text:
        sys.stderr.write("register_test_user.py: user already exists, reusing\n")
        return

    sys.stderr.write(
        f"register_test_user.py: register failed HTTP {resp.status_code}: "
        f"{resp.text[:500]}\n"
    )
    sys.exit(1)


def main() -> int:
    parser = argparse.ArgumentParser(description="Register the compat test user.")
    parser.add_argument("--base-url", required=True)
    parser.add_argument("--email", required=True)
    parser.add_argument("--password", required=True)
    parser.add_argument(
        "--dump-to",
        type=Path,
        help="Write the generated credentials (private_key_pem + encrypted "
        "blob) as JSON to this path. Consumed by the Patrol test so it can "
        "skip the server-round-trip and assert on crypto fields directly.",
    )
    args = parser.parse_args()

    fixture = generate_fixture(args.password)
    post_register(args.base_url, args.email, args.password, fixture)

    if args.dump_to:
        args.dump_to.write_text(
            json.dumps(
                {
                    "email": args.email,
                    "password": args.password,
                    "fingerprint": fixture["fingerprint"],
                },
                indent=2,
            )
        )

    return 0


if __name__ == "__main__":
    sys.exit(main())
