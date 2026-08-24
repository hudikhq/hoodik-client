//! Functions exposed to Flutter via flutter_rust_bridge.
//!
//! Each function here is a thin wrapper around `cryptfns` and `transfer` crate
//! operations, adapted for FFI-friendly types (Strings, Vec<u8>, JSON).

use std::path::PathBuf;
use std::str::FromStr;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::Arc;

use flutter_rust_bridge::frb;

// ---------------------------------------------------------------------------
// RSA key management
// ---------------------------------------------------------------------------

/// Generate a new RSA-2048 keypair.
/// Returns (private_key_pem, public_key_pem, fingerprint).
#[frb(sync)]
pub fn generate_rsa_keypair() -> Result<RsaKeyPair, String> {
    let private_key = cryptfns::rsa::private::generate().map_err(|e| e.to_string())?;
    let public_key =
        cryptfns::rsa::public::from_private(&private_key).map_err(|e| e.to_string())?;
    let private_pem =
        cryptfns::rsa::private::to_string(&private_key).map_err(|e| e.to_string())?;
    let public_pem = cryptfns::rsa::public::to_string(&public_key).map_err(|e| e.to_string())?;
    let fingerprint = cryptfns::rsa::fingerprint(public_key).map_err(|e| e.to_string())?;

    Ok(RsaKeyPair {
        private_key_pem: private_pem,
        public_key_pem: public_pem,
        fingerprint,
    })
}

/// Derive the public key PEM and fingerprint from a private key PEM.
#[frb(sync)]
pub fn rsa_public_from_private(private_key_pem: String) -> Result<RsaPublicInfo, String> {
    let private_key =
        cryptfns::rsa::private::from_str(&private_key_pem).map_err(|e| e.to_string())?;
    let public_key =
        cryptfns::rsa::public::from_private(&private_key).map_err(|e| e.to_string())?;
    let public_pem = cryptfns::rsa::public::to_string(&public_key).map_err(|e| e.to_string())?;
    let fingerprint = cryptfns::rsa::fingerprint(public_key).map_err(|e| e.to_string())?;

    Ok(RsaPublicInfo {
        public_key_pem: public_pem,
        fingerprint,
    })
}

/// Sign a message with an RSA private key (PSS + SHA256).
/// Returns the signature as a base64 string.
#[frb(sync)]
pub fn rsa_sign(message: String, private_key_pem: String) -> Result<String, String> {
    cryptfns::rsa::private::sign(&message, &private_key_pem).map_err(|e| e.to_string())
}

/// Verify an RSA signature (PSS + SHA256).
#[frb(sync)]
pub fn rsa_verify(
    message: String,
    signature: String,
    public_key_pem: String,
) -> Result<bool, String> {
    match cryptfns::rsa::public::verify(&message, &signature, &public_key_pem) {
        Ok(()) => Ok(true),
        Err(_) => Ok(false),
    }
}

/// Encrypt a plaintext string with an RSA public key (PKCS#1 v1.5).
/// Returns the ciphertext as a base64 string.
#[frb(sync)]
pub fn rsa_encrypt(plaintext: String, public_key_pem: String) -> Result<String, String> {
    cryptfns::rsa::public::encrypt(&plaintext, &public_key_pem).map_err(|e| e.to_string())
}

/// Decrypt a base64-encoded ciphertext with an RSA private key (PKCS#1 v1.5).
/// Returns the plaintext as a UTF-8 string.
#[frb(sync)]
pub fn rsa_decrypt(ciphertext_b64: String, private_key_pem: String) -> Result<String, String> {
    cryptfns::rsa::private::decrypt(&ciphertext_b64, &private_key_pem).map_err(|e| e.to_string())
}

// ---------------------------------------------------------------------------
// Hybrid key wrapping (X25519 + ML-KEM-768) and Ed25519 identity
// ---------------------------------------------------------------------------

/// Generate a new hybrid wrapping keypair.
/// Returns the private and public key PEM containers.
#[frb(sync)]
pub fn generate_wrapping_keypair() -> Result<WrappingKeyPair, String> {
    let private_pem = cryptfns::ecdh::private::generate().map_err(|e| e.to_string())?;
    let public_pem =
        cryptfns::ecdh::public::from_private(&private_pem).map_err(|e| e.to_string())?;

    Ok(WrappingKeyPair {
        private_pem,
        public_pem,
    })
}

/// Wrap a file key to a recipient's hybrid wrapping public key.
/// Returns the wrap blob as a base64 string.
#[frb(sync)]
pub fn wrapping_wrap(file_key: Vec<u8>, recipient_public_pem: String) -> Result<String, String> {
    cryptfns::ecdh::wrap(&file_key, &recipient_public_pem).map_err(|e| e.to_string())
}

/// Unwrap a base64 hybrid wrap blob with the recipient's wrapping private key.
/// Returns the file key bytes.
#[frb(sync)]
pub fn wrapping_unwrap(blob: String, private_pem: String) -> Result<Vec<u8>, String> {
    cryptfns::ecdh::unwrap(&blob, &private_pem).map_err(|e| e.to_string())
}

/// Generate a new Ed25519 keypair.
/// Returns (private_pem PKCS#8, public_pem SPKI).
#[frb(sync)]
pub fn generate_ed25519_keypair() -> Result<Ed25519KeyPair, String> {
    let private_pem = cryptfns::ed25519::private::generate().map_err(|e| e.to_string())?;
    let public_pem =
        cryptfns::ed25519::public::from_private(&private_pem).map_err(|e| e.to_string())?;

    Ok(Ed25519KeyPair {
        private_pem,
        public_pem,
    })
}

/// Sign a message with an Ed25519 private key.
/// Returns the signature as a base64 string.
#[frb(sync)]
pub fn ed25519_sign(message: String, private_pem: String) -> Result<String, String> {
    cryptfns::ed25519::private::sign(&message, &private_pem).map_err(|e| e.to_string())
}

/// Sign raw bytes with an Ed25519 private key.
/// Returns the signature as a base64 string.
#[frb(sync)]
pub fn ed25519_sign_bytes(message: Vec<u8>, private_pem: String) -> Result<String, String> {
    cryptfns::ed25519::private::sign_bytes(&message, &private_pem).map_err(|e| e.to_string())
}

/// Verify an Ed25519 signature.
#[frb(sync)]
pub fn ed25519_verify(
    message: String,
    signature: String,
    public_pem: String,
) -> Result<bool, String> {
    match cryptfns::ed25519::public::verify(&message, &signature, &public_pem) {
        Ok(()) => Ok(true),
        Err(_) => Ok(false),
    }
}

/// Verify an Ed25519 signature over raw bytes.
#[frb(sync)]
pub fn ed25519_verify_bytes(
    message: Vec<u8>,
    signature: String,
    public_pem: String,
) -> Result<bool, String> {
    match cryptfns::ed25519::public::verify_bytes(&message, &signature, &public_pem) {
        Ok(()) => Ok(true),
        Err(_) => Ok(false),
    }
}

/// SHA-256 fingerprint of a SPKI public key PEM, as 64 hex chars — the
/// Curve25519 counterpart to [rsa_fingerprint_public].
#[frb(sync)]
pub fn spki_fingerprint(public_pem: String) -> Result<String, String> {
    cryptfns::spki::fingerprint(&public_pem).map_err(|e| e.to_string())
}

// ---------------------------------------------------------------------------
// Symmetric cipher operations
// ---------------------------------------------------------------------------

/// Generate a random symmetric key for the given cipher.
/// Cipher: "aegis128l" (default), "ascon128a", "chacha20poly1305", "aegis256"
#[frb(sync)]
pub fn cipher_generate_key(cipher: String) -> Result<Vec<u8>, String> {
    let c = cryptfns::cipher::Cipher::from_str(&cipher).map_err(|e| e.to_string())?;
    c.generate_key().map_err(|e| e.to_string())
}

/// Encrypt plaintext bytes with a symmetric cipher.
#[frb(sync)]
pub fn cipher_encrypt(cipher: String, key: Vec<u8>, plaintext: Vec<u8>) -> Result<Vec<u8>, String> {
    let c = cryptfns::cipher::Cipher::from_str(&cipher).map_err(|e| e.to_string())?;
    c.encrypt(key, plaintext).map_err(|e| e.to_string())
}

/// Decrypt ciphertext bytes with a symmetric cipher.
#[frb(sync)]
pub fn cipher_decrypt(
    cipher: String,
    key: Vec<u8>,
    ciphertext: Vec<u8>,
) -> Result<Vec<u8>, String> {
    let c = cryptfns::cipher::Cipher::from_str(&cipher).map_err(|e| e.to_string())?;
    c.decrypt(key, ciphertext).map_err(|e| e.to_string())
}

/// Encrypt a metadata string (file name, thumbnail, link fields) with a
/// fresh random nonce prepended to the ciphertext. Metadata strings share
/// the file key with the content chunks, so encrypting them with the key
/// blob as-is would reuse the embedded nonce.
#[frb(sync)]
pub fn cipher_encrypt_string(
    cipher: String,
    key: Vec<u8>,
    plaintext: Vec<u8>,
) -> Result<Vec<u8>, String> {
    let c = cryptfns::cipher::Cipher::from_str(&cipher).map_err(|e| e.to_string())?;
    c.encrypt_string(key, plaintext).map_err(|e| e.to_string())
}

/// Decrypt a metadata string. Tries the prepended random nonce first, then
/// falls back to the legacy embedded-nonce layout so metadata written before
/// per-string nonces still decrypts — the AEAD tag rejects the wrong branch.
#[frb(sync)]
pub fn cipher_decrypt_string(
    cipher: String,
    key: Vec<u8>,
    ciphertext: Vec<u8>,
) -> Result<Vec<u8>, String> {
    let c = cryptfns::cipher::Cipher::from_str(&cipher).map_err(|e| e.to_string())?;
    c.decrypt_string(key, ciphertext).map_err(|e| e.to_string())
}

/// Encrypt one chunk of a multi-chunk payload with a per-chunk derived nonce.
/// Chunk 0 is byte-identical to [cipher_encrypt], so single-chunk payloads
/// stay wire-compatible with every existing file.
#[frb(sync)]
pub fn cipher_encrypt_chunk(
    cipher: String,
    key: Vec<u8>,
    chunk_index: u64,
    plaintext: Vec<u8>,
) -> Result<Vec<u8>, String> {
    let c = cryptfns::cipher::Cipher::from_str(&cipher).map_err(|e| e.to_string())?;
    c.encrypt_chunk(&key, chunk_index, plaintext)
        .map_err(|e| e.to_string())
}

/// Decrypt one chunk of a multi-chunk payload. Tries the per-chunk nonce
/// first, then falls back to the blob's own nonce so files uploaded before
/// per-chunk nonces existed still decrypt — the AEAD tag rejects the wrong
/// branch.
#[frb(sync)]
pub fn cipher_decrypt_chunk(
    cipher: String,
    key: Vec<u8>,
    chunk_index: u64,
    ciphertext: Vec<u8>,
) -> Result<Vec<u8>, String> {
    let c = cryptfns::cipher::Cipher::from_str(&cipher).map_err(|e| e.to_string())?;
    c.decrypt_chunk(&key, chunk_index, ciphertext)
        .map_err(|e| e.to_string())
}

// ---------------------------------------------------------------------------
// Hashing
// ---------------------------------------------------------------------------

/// Compute SHA-256 hash of the input bytes. Returns hex string.
#[frb(sync)]
pub fn sha256_digest(data: Vec<u8>) -> String {
    cryptfns::sha256::digest(data.as_slice())
}

/// Compute CRC-16 checksum. Returns hex string.
#[frb(sync)]
pub fn crc16_digest(data: Vec<u8>) -> String {
    cryptfns::crc::crc16_digest(&data)
}

// ---------------------------------------------------------------------------
// Search tagging (for privacy-preserving search)
// ---------------------------------------------------------------------------
//
// Tokens are tagged with HMAC under a key the server never sees, rather than
// hashed. A bare digest of a BERT token is reversible with a table over the
// public vocabulary, which is what the old scheme stored. Two keys: the
// account's, from its private key, covering everything it owns; and each
// file's own, which already travels to every share recipient.

/// Derive the account-wide search key from a private key PEM. Hex-encoded so
/// it can be held alongside the other client-side key material.
#[frb(sync)]
pub fn search_root_key(private_key_pem: String) -> Result<String, String> {
    cryptfns::search::root_key(&private_key_pem)
        .map(cryptfns::hex::encode)
        .map_err(|e| e.to_string())
}

/// Derive a file's search key from the key its contents are encrypted with.
#[frb(sync)]
pub fn search_file_key(file_key: Vec<u8>) -> Result<String, String> {
    cryptfns::search::file_key(&file_key)
        .map(cryptfns::hex::encode)
        .map_err(|e| e.to_string())
}

/// Tag one value: a file name for `name_hash`, or a single query word.
#[frb(sync)]
pub fn search_tag(key_hex: String, value: String) -> Result<String, String> {
    let key = cryptfns::hex::decode(&key_hex).map_err(|e| e.to_string())?;
    cryptfns::search::tag(&key, &value).map_err(|e| e.to_string())
}

/// Tokenize and tag text. Format: "tag:weight;tag:weight;..."
#[frb(sync)]
pub fn search_tag_tokens(key_hex: String, text: String) -> Result<String, String> {
    let key = cryptfns::hex::decode(&key_hex).map_err(|e| e.to_string())?;
    let tokens = cryptfns::search::tag_tokens(&key, &text).map_err(|e| e.to_string())?;
    Ok(cryptfns::tokenizer::into_string(tokens))
}

// ---------------------------------------------------------------------------
// Base64 encoding/decoding
// ---------------------------------------------------------------------------

/// Base64 encode bytes.
#[frb(sync)]
pub fn base64_encode(data: Vec<u8>) -> String {
    cryptfns::base64::encode(data)
}

/// Base64 decode a string to bytes.
#[frb(sync)]
pub fn base64_decode(data: String) -> Result<Vec<u8>, String> {
    cryptfns::base64::decode(&data).map_err(|e| e.to_string())
}

// ---------------------------------------------------------------------------
// Sharing v1 ASN.1 DER encoders
// ---------------------------------------------------------------------------

fn share_role_from_u8(v: u8) -> Result<cryptfns::asn1::ShareRoleEnum, String> {
    match v {
        0 => Ok(cryptfns::asn1::ShareRoleEnum::Reader),
        1 => Ok(cryptfns::asn1::ShareRoleEnum::Editor),
        2 => Ok(cryptfns::asn1::ShareRoleEnum::CoOwner),
        other => Err(format!("invalid share_role discriminant: {other}")),
    }
}

fn bytes_to_array_ffi<const N: usize>(input: &[u8], field: &str) -> Result<[u8; N], String> {
    if input.len() != N {
        return Err(format!(
            "field {field}: expected {N} bytes, got {}",
            input.len()
        ));
    }
    let mut out = [0u8; N];
    out.copy_from_slice(input);
    Ok(out)
}

/// DER-encode a v1 share-request payload. Byte-for-byte equivalent to the
/// WASM `share_payload_encode_v1`; both call `cryptfns::asn1` directly.
#[frb(sync)]
pub fn share_payload_encode_v1(
    sender_id: Vec<u8>,
    recipient_id: Vec<u8>,
    recipient_pubkey_fingerprint: Vec<u8>,
    share_role: u8,
    root_file_id: Vec<u8>,
    entries_hash: Vec<u8>,
    timestamp: i64,
    nonce: Vec<u8>,
) -> Result<Vec<u8>, String> {
    let payload = cryptfns::asn1::ShareRequestPayloadV1 {
        sender_id: bytes_to_array_ffi::<16>(&sender_id, "sender_id")?,
        recipient_id: bytes_to_array_ffi::<16>(&recipient_id, "recipient_id")?,
        recipient_pubkey_fingerprint: bytes_to_array_ffi::<32>(
            &recipient_pubkey_fingerprint,
            "recipient_pubkey_fingerprint",
        )?,
        share_role: share_role_from_u8(share_role)?,
        root_file_id: bytes_to_array_ffi::<16>(&root_file_id, "root_file_id")?,
        entries_hash: bytes_to_array_ffi::<32>(&entries_hash, "entries_hash")?,
        timestamp,
        nonce: bytes_to_array_ffi::<16>(&nonce, "nonce")?,
    };
    cryptfns::asn1::encode_share_request_v1(&payload).map_err(|e| e.to_string())
}

/// DER-encode a v1 folder member-signature payload.
#[frb(sync)]
pub fn member_sig_encode_v1(
    user_id: Vec<u8>,
    pubkey_der: Vec<u8>,
    fingerprint: Vec<u8>,
    share_role: u8,
    signed_at: i64,
) -> Result<Vec<u8>, String> {
    let payload = cryptfns::asn1::MemberSigPayloadV1 {
        user_id: bytes_to_array_ffi::<16>(&user_id, "user_id")?,
        pubkey_der,
        fingerprint: bytes_to_array_ffi::<32>(&fingerprint, "fingerprint")?,
        share_role: share_role_from_u8(share_role)?,
        signed_at,
    };
    cryptfns::asn1::encode_member_sig_v1(&payload).map_err(|e| e.to_string())
}

/// DER-encode a v1 folder member list. Byte-for-byte equivalent to the
/// WASM `folder_member_list_encode_v1`. Members travel as flat parallel
/// arrays so the FFI surface stays a single sync call: `user_ids` and
/// `signed_by_user_ids` concatenate every 16-byte UUID, `pubkey_finger-
/// prints` concatenates every 32-byte SHA-256, and `share_roles` /
/// `is_owner_flags` carry one byte per member. The encoder sorts by
/// `user_id` so callers can pass members in any order.
#[frb(sync)]
#[allow(clippy::too_many_arguments)]
pub fn folder_member_list_encode_v1(
    folder_id: Vec<u8>,
    folder_owner_id: Vec<u8>,
    user_ids: Vec<u8>,
    pubkey_fingerprints: Vec<u8>,
    share_roles: Vec<u8>,
    is_owner_flags: Vec<u8>,
    signed_by_user_ids: Vec<u8>,
    members_signed_at: i64,
) -> Result<Vec<u8>, String> {
    let count = share_roles.len();
    if is_owner_flags.len() != count {
        return Err(format!(
            "is_owner_flags length {} does not match share_roles length {count}",
            is_owner_flags.len()
        ));
    }
    if user_ids.len() != count * 16 {
        return Err(format!(
            "user_ids length {} does not match {} expected for {count} members",
            user_ids.len(),
            count * 16
        ));
    }
    if signed_by_user_ids.len() != count * 16 {
        return Err(format!(
            "signed_by_user_ids length {} does not match {} expected for {count} members",
            signed_by_user_ids.len(),
            count * 16
        ));
    }
    if pubkey_fingerprints.len() != count * 32 {
        return Err(format!(
            "pubkey_fingerprints length {} does not match {} expected for {count} members",
            pubkey_fingerprints.len(),
            count * 32
        ));
    }

    let mut members = Vec::with_capacity(count);
    for i in 0..count {
        let user_id =
            bytes_to_array_ffi::<16>(&user_ids[i * 16..(i + 1) * 16], "user_id")?;
        let signed_by_user_id = bytes_to_array_ffi::<16>(
            &signed_by_user_ids[i * 16..(i + 1) * 16],
            "signed_by_user_id",
        )?;
        let pubkey_fingerprint = bytes_to_array_ffi::<32>(
            &pubkey_fingerprints[i * 32..(i + 1) * 32],
            "pubkey_fingerprint",
        )?;
        members.push(cryptfns::asn1::FolderListMember {
            user_id,
            pubkey_fingerprint,
            share_role: share_role_from_u8(share_roles[i])?,
            is_owner: is_owner_flags[i] != 0,
            signed_by_user_id,
        });
    }

    let payload = cryptfns::asn1::FolderMemberListV1 {
        folder_id: bytes_to_array_ffi::<16>(&folder_id, "folder_id")?,
        folder_owner_id: bytes_to_array_ffi::<16>(&folder_owner_id, "folder_owner_id")?,
        members,
        members_signed_at,
    };
    cryptfns::asn1::encode_folder_member_list_v1(&payload).map_err(|e| e.to_string())
}

/// DER-encode a v1 audit-event row body. Pass `share_role = 255` for
/// events that don't carry a role (e.g. `revoke`).
#[frb(sync)]
pub fn audit_event_encode_v1(
    sender_id: Vec<u8>,
    recipient_id: Vec<u8>,
    file_id: Vec<u8>,
    action: String,
    share_role: u8,
    created_at: i64,
) -> Result<Vec<u8>, String> {
    let share_role = match share_role {
        255 => None,
        v => Some(share_role_from_u8(v)?),
    };
    let row = cryptfns::asn1::AuditEventRowV1 {
        sender_id: bytes_to_array_ffi::<16>(&sender_id, "sender_id")?,
        recipient_id: bytes_to_array_ffi::<16>(&recipient_id, "recipient_id")?,
        file_id: bytes_to_array_ffi::<16>(&file_id, "file_id")?,
        action,
        share_role,
        created_at,
    };
    cryptfns::asn1::encode_audit_event_v1(&row).map_err(|e| e.to_string())
}

fn audit_action_from_u8(v: u8) -> Result<cryptfns::asn1::AuditEventActionEnum, String> {
    use cryptfns::asn1::AuditEventActionEnum::*;
    match v {
        0 => Ok(Grant),
        1 => Ok(Revoke),
        2 => Ok(RoleChange),
        3 => Ok(SharedFolderUpload),
        4 => Ok(Fork),
        5 => Ok(SharedByCoOwner),
        6 => Ok(SharedFolderEdit),
        7 => Ok(SharedFolderRestore),
        8 => Ok(SharedFolderEvict),
        9 => Ok(SharedFolderMoveOut),
        other => Err(format!("invalid audit action discriminant: {other}")),
    }
}

/// DER-encode a v1 audit-event signature input. `recipient_id` is absent
/// when the caller passes an empty `Vec` (255 is a legal UUID byte, so an
/// empty buffer is the sentinel); each role field uses byte `255` for an
/// absent role.
#[frb(sync)]
#[allow(clippy::too_many_arguments)]
pub fn audit_event_sig_input_encode_v1(
    sender_id: Vec<u8>,
    recipient_id: Vec<u8>,
    file_id: Vec<u8>,
    action: u8,
    share_role_before: u8,
    share_role_after: u8,
    timestamp: i64,
) -> Result<Vec<u8>, String> {
    let recipient_id = if recipient_id.is_empty() {
        None
    } else {
        Some(bytes_to_array_ffi::<16>(&recipient_id, "recipient_id")?)
    };
    let share_role_before = match share_role_before {
        255 => None,
        v => Some(share_role_from_u8(v)?),
    };
    let share_role_after = match share_role_after {
        255 => None,
        v => Some(share_role_from_u8(v)?),
    };

    let payload = cryptfns::asn1::AuditEventSigInputV1 {
        sender_id: bytes_to_array_ffi::<16>(&sender_id, "sender_id")?,
        recipient_id,
        file_id: bytes_to_array_ffi::<16>(&file_id, "file_id")?,
        action: audit_action_from_u8(action)?,
        share_role_before,
        share_role_after,
        timestamp,
    };
    cryptfns::asn1::encode_audit_event_sig_input_v1(&payload).map_err(|e| e.to_string())
}

/// DER-encode the canonical entries list that `entries_hash` commits to.
/// `file_ids` concatenates every 16-byte file UUID, `encrypted_keys_flat`
/// concatenates every per-entry ciphertext, and `encrypted_key_lengths`
/// carries each ciphertext length so the flat buffer can be sliced. The
/// encoder sorts by `file_id`, so the hash is stable under input ordering.
#[frb(sync)]
pub fn entries_encode_v1(
    file_ids: Vec<u8>,
    encrypted_keys_flat: Vec<u8>,
    encrypted_key_lengths: Vec<u32>,
) -> Result<Vec<u8>, String> {
    let count = encrypted_key_lengths.len();
    if file_ids.len() != count * 16 {
        return Err(format!(
            "file_ids length {} does not match {} expected for {count} entries",
            file_ids.len(),
            count * 16
        ));
    }

    let expected_total: usize = encrypted_key_lengths.iter().map(|&n| n as usize).sum();
    if encrypted_keys_flat.len() != expected_total {
        return Err(format!(
            "encrypted_keys_flat length {} does not match summed lengths {expected_total}",
            encrypted_keys_flat.len()
        ));
    }

    let mut entries = Vec::with_capacity(count);
    let mut key_cursor = 0usize;
    for (i, &len) in encrypted_key_lengths.iter().enumerate() {
        let len = len as usize;
        let file_id =
            bytes_to_array_ffi::<16>(&file_ids[i * 16..(i + 1) * 16], "file_id")?;
        let encrypted_key = encrypted_keys_flat[key_cursor..key_cursor + len].to_vec();
        key_cursor += len;
        entries.push(cryptfns::asn1::ShareEntry {
            file_id,
            encrypted_key,
        });
    }

    cryptfns::asn1::encode_entries_v1(&entries).map_err(|e| e.to_string())
}

/// Sign raw bytes (RSA-PSS-SHA256) with a PEM private key. Sharing payloads
/// are DER blobs that aren't valid UTF-8, so they can't go through the
/// string-typed `rsa_sign`. Returns a base64 signature.
#[frb(sync)]
pub fn rsa_sign_bytes(message: Vec<u8>, private_key_pem: String) -> Result<String, String> {
    cryptfns::rsa::private::sign_bytes(&message, &private_key_pem).map_err(|e| e.to_string())
}

/// Verify an RSA-PSS-SHA256 signature over raw bytes with a PEM public key.
#[frb(sync)]
pub fn rsa_verify_bytes(
    message: Vec<u8>,
    signature: String,
    public_key_pem: String,
) -> Result<bool, String> {
    match cryptfns::rsa::public::verify_bytes(&message, &signature, &public_key_pem) {
        Ok(()) => Ok(true),
        Err(_) => Ok(false),
    }
}

/// SHA-256 fingerprint (`sha256(hex(modulus))`) of a PEM public key — the
/// same value the server stores in `users.fingerprint`, derived client-side
/// for TOFU verification of a recipient before sharing.
#[frb(sync)]
pub fn rsa_fingerprint_public(public_key_pem: String) -> Result<String, String> {
    let public_key =
        cryptfns::rsa::public::from_str(&public_key_pem).map_err(|e| e.to_string())?;
    cryptfns::rsa::fingerprint(public_key).map_err(|e| e.to_string())
}

/// PKCS#1 DER bytes of a PEM public key — the `pubkey_der` octet string the
/// `member_sig` encoder commits to. The byte conversion lives in `cryptfns`
/// so web and mobile produce identical member signatures.
#[frb(sync)]
pub fn rsa_pkcs1_der_from_pem(public_key_pem: String) -> Result<Vec<u8>, String> {
    cryptfns::rsa::public::to_pkcs1_der(&public_key_pem).map_err(|e| e.to_string())
}

/// The `MemberSigPayloadV1.pubkey_der` canonical for a recipient of the given
/// key type: PKCS#1 DER body for `"rsa"`, SPKI DER body for `"curve25519"`.
/// The dispatch lives in `cryptfns` so web and mobile commit to identical
/// bytes.
#[frb(sync)]
pub fn member_pubkey_der(key_type: String, public_key_pem: String) -> Result<Vec<u8>, String> {
    let key_type = cryptfns::identity::KeyType::from_str(&key_type).map_err(|e| e.to_string())?;
    key_type
        .member_pubkey_der(&public_key_pem)
        .map_err(|e| e.to_string())
}

// ---------------------------------------------------------------------------
// OPAQUE (PAKE login/registration) — client half
// ---------------------------------------------------------------------------

/// Begin an OPAQUE registration. Returns the opaque client state to carry
/// forward and the base64 message to POST to the server's `registration/start`.
#[frb(sync)]
pub fn opaque_client_registration_start(password: Vec<u8>) -> Result<OpaqueClientStart, String> {
    let start = cryptfns::opaque::client_registration_start(&password).map_err(|e| e.to_string())?;
    Ok(OpaqueClientStart {
        state: start.state,
        message: start.message,
    })
}

/// Finish an OPAQUE registration against the server's `registration_response`.
/// Returns the base64 message to POST and the export key used to seal the
/// user's key bundle.
///
/// A registration always seals under the current default KSF, read straight
/// from the shared crate so a work-factor change stays in lockstep with what the
/// server records for the account.
#[frb(sync)]
pub fn opaque_client_registration_finish(
    registration_state: String,
    registration_response: String,
    password: Vec<u8>,
) -> Result<OpaqueRegisterFinish, String> {
    let ksf = cryptfns::opaque::current_ksf_params();
    let result = cryptfns::opaque::client_registration_finish_with_params(
        &registration_state,
        &registration_response,
        &password,
        ksf.m_cost,
        ksf.t_cost,
        ksf.p_cost,
    )
    .map_err(|e| e.to_string())?;
    Ok(OpaqueRegisterFinish {
        message: result.message,
        export_key: result.export_key,
    })
}

/// Begin an OPAQUE login. Returns the opaque client state and the base64
/// message to POST to the server's `login/start`.
#[frb(sync)]
pub fn opaque_client_login_start(password: Vec<u8>) -> Result<OpaqueClientStart, String> {
    let start = cryptfns::opaque::client_login_start(&password).map_err(|e| e.to_string())?;
    Ok(OpaqueClientStart {
        state: start.state,
        message: start.message,
    })
}

/// Finish an OPAQUE login against the server's `credential_response`. Returns
/// the finalization message, the shared session key, and the export key that
/// unseals the user's key bundle.
///
/// The KSF parameters are the account's own, echoed by `login/start`. The
/// `export_key` only matches what registration produced when it is stretched
/// with those same parameters, so a future work-factor raise cannot lock the
/// account out.
#[frb(sync)]
pub fn opaque_client_login_finish(
    login_state: String,
    credential_response: String,
    password: Vec<u8>,
    m_cost: u32,
    t_cost: u32,
    p_cost: u32,
) -> Result<OpaqueLoginFinish, String> {
    let result = cryptfns::opaque::client_login_finish_with_params(
        &login_state,
        &credential_response,
        &password,
        m_cost,
        t_cost,
        p_cost,
    )
    .map_err(|e| e.to_string())?;
    Ok(OpaqueLoginFinish {
        finalization: result.finalization,
        session_key: result.session_key,
        export_key: result.export_key,
    })
}

// ---------------------------------------------------------------------------
// Key-bundle envelope (KEK-sealed identity + wrapping keys)
// ---------------------------------------------------------------------------

/// Derive the 32-byte key-encryption key from an OPAQUE export key.
#[frb(sync)]
pub fn envelope_derive_kek(export_key: Vec<u8>) -> Result<Vec<u8>, String> {
    let kek = cryptfns::envelope::derive_kek(&export_key).map_err(|e| e.to_string())?;
    Ok(kek.to_vec())
}

/// Seal a key bundle under a KEK. Returns the base64 envelope.
#[frb(sync)]
pub fn envelope_seal(kek: Vec<u8>, bundle: Vec<u8>) -> Result<String, String> {
    let kek: [u8; 32] = kek
        .try_into()
        .map_err(|k: Vec<u8>| format!("kek must be 32 bytes, got {}", k.len()))?;
    cryptfns::envelope::seal(&kek, &bundle).map_err(|e| e.to_string())
}

/// Open a base64 envelope with a KEK. Returns the plaintext key bundle.
#[frb(sync)]
pub fn envelope_open(kek: Vec<u8>, envelope: String) -> Result<Vec<u8>, String> {
    let kek: [u8; 32] = kek
        .try_into()
        .map_err(|k: Vec<u8>| format!("kek must be 32 bytes, got {}", k.len()))?;
    cryptfns::envelope::open(&kek, &envelope).map_err(|e| e.to_string())
}

/// Re-seal an envelope under a new KEK without exposing the plaintext bundle
/// to the caller — the password-change path.
#[frb(sync)]
pub fn envelope_rewrap(
    old_kek: Vec<u8>,
    new_kek: Vec<u8>,
    envelope: String,
) -> Result<String, String> {
    let old_kek: [u8; 32] = old_kek
        .try_into()
        .map_err(|k: Vec<u8>| format!("old_kek must be 32 bytes, got {}", k.len()))?;
    let new_kek: [u8; 32] = new_kek
        .try_into()
        .map_err(|k: Vec<u8>| format!("new_kek must be 32 bytes, got {}", k.len()))?;
    cryptfns::envelope::rewrap(&old_kek, &new_kek, &envelope).map_err(|e| e.to_string())
}

// ---------------------------------------------------------------------------
// Argon2id KDF (device-key vault PIN wrap)
// ---------------------------------------------------------------------------

/// Derive a 32-byte key from `secret` and `salt` with Argon2id at the same
/// frozen cost as the OPAQUE KSF (m=64 MiB, t=3, p=1). The device-key vault
/// folds the PIN into its wrap key through this, so grinding a stolen
/// `app.db` + keychain pair costs a memory-hard derivation per PIN guess
/// instead of one SHA-256. Async so the work runs on the FRB worker pool
/// rather than the platform thread.
pub async fn argon2id_derive_key(secret: Vec<u8>, salt: Vec<u8>) -> Result<Vec<u8>, String> {
    use argon2::{Algorithm, Argon2, Params, Version};

    let params = Params::new(64 * 1024, 3, 1, Some(32)).map_err(|e| e.to_string())?;
    let mut out = [0u8; 32];
    Argon2::new(Algorithm::Argon2id, Version::V0x13, params)
        .hash_password_into(&secret, &salt, &mut out)
        .map_err(|e| e.to_string())?;
    Ok(out.to_vec())
}

// ---------------------------------------------------------------------------
// Key-transition certificate (old identity → new identity)
// ---------------------------------------------------------------------------

/// Sign a key-transition certificate binding the user's old identity key to
/// their new Curve25519 identity + wrapping keys. `old_key_type` is `"rsa"` or
/// `"curve25519"`. Returns the two detached signatures the server records.
#[frb(sync)]
#[allow(clippy::too_many_arguments)]
pub fn transition_sign(
    user_id: Vec<u8>,
    old_key_type: String,
    old_key_pem: String,
    old_fingerprint: String,
    new_identity_key_pem: String,
    new_wrapping_key_pem: String,
    new_fingerprint: String,
    issued_at: i64,
    old_private_key: String,
    new_identity_private_key: String,
) -> Result<TransitionSignatures, String> {
    let signatures = cryptfns::transition::sign_certificate(
        &user_id,
        &old_key_type,
        &old_key_pem,
        &old_fingerprint,
        &new_identity_key_pem,
        &new_wrapping_key_pem,
        &new_fingerprint,
        issued_at,
        &old_private_key,
        &new_identity_private_key,
    )
    .map_err(|e| e.to_string())?;
    Ok(TransitionSignatures {
        old_signature: signatures.old_signature,
        new_signature: signatures.new_signature,
    })
}

/// Verify another user's transition certificate from server-supplied fields:
/// the old key's endorsement of the new keys, the new identity key's proof of
/// possession, and each fingerprint against the key it names. `user_id` must
/// be the 16 UUID bytes the caller resolved the signer as — the canonical
/// binds it, so a certificate replayed from a different account fails.
/// `old_key_spki` is the old key's member-DER (the PEM body); the signatures
/// are base64.
#[frb(sync)]
#[allow(clippy::too_many_arguments)]
pub fn transition_verify(
    user_id: Vec<u8>,
    old_key_type: String,
    old_key_spki: Vec<u8>,
    old_fingerprint: String,
    new_identity_key_pem: String,
    new_wrapping_key_pem: String,
    new_fingerprint: String,
    issued_at: i64,
    old_signature: String,
    new_signature: String,
) -> Result<bool, String> {
    Ok(cryptfns::transition::verify_certificate(
        &user_id,
        &old_key_type,
        &old_key_spki,
        &old_fingerprint,
        &new_identity_key_pem,
        &new_wrapping_key_pem,
        &new_fingerprint,
        issued_at,
        &old_signature,
        &new_signature,
    )
    .is_ok())
}

/// Sign the key-rotation audit event with the new identity key — the first act
/// of the rotated identity, appended to the owner's audit chain so a later
/// reader sees why the signing key changed. `user_id` is the 16 raw UUID bytes;
/// the fingerprints are the hex strings held in `users.fingerprint`. Returns the
/// base64 signature submitted as `audit_event_signature`; the server re-encodes
/// the same canonical from its own record and aborts the migration if it does
/// not verify.
#[frb(sync)]
pub fn sign_key_rotation_audit(
    user_id: Vec<u8>,
    old_fingerprint: String,
    new_fingerprint: String,
    rotated_at: i64,
    new_identity_private_key: String,
) -> Result<String, String> {
    cryptfns::transition::sign_key_rotation_audit(
        &user_id,
        &old_fingerprint,
        &new_fingerprint,
        rotated_at,
        &new_identity_private_key,
    )
    .map_err(|e| e.to_string())
}

// ---------------------------------------------------------------------------
// File transfer (upload/download)
// ---------------------------------------------------------------------------

/// Upload a file to the Hoodik server.
///
/// Runs the full chunked-upload pipeline from the `transfer` crate:
/// concurrent chunk encryption + upload (8 parallel), CRC checksums, retry on
/// mismatch, resume support, and inline SHA-256/MD5/SHA-1/BLAKE2b hashing.
///
/// Uses `spawn_blocking` + a single-threaded tokio `LocalSet` internally so
/// that the transfer crate's `!Send` futures work within FRB's multi-threaded
/// executor.
///
/// Returns the computed file hashes as JSON.
pub async fn upload_file(
    base_url: String,
    cookie: String,
    file_id: String,
    file_path: String,
    encryption_key: Vec<u8>,
    cipher: String,
    already_uploaded: Vec<u64>,
) -> Result<String, String> {
    let cancel_flag = register_cancel_flag(&file_id);
    let (transferred, total) = register_progress(&file_id);
    let file_id_cleanup = file_id.clone();

    let result = tokio::task::spawn_blocking(move || {
        let rt = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .map_err(|e| e.to_string())?;

        let local = tokio::task::LocalSet::new();
        local.block_on(&rt, async move {
            let auth = transfer::types::Auth {
                base_url,
                jwt_token: None,
                refresh_token: None,
                cookie: Some(cookie),
            };

            let http = transfer::native::http::NativeHttpClient::new()
                .map_err(|e| e.to_string())?;
            let source =
                transfer::native::source::FileSource::new(PathBuf::from(&file_path))
                    .await
                    .map_err(|e| e.to_string())?;

            let progress = transfer::native::progress::NativeProgressReporter::new(
                move |json: &str| {
                    if let Ok(v) = serde_json::from_str::<serde_json::Value>(json) {
                        if let Some(chunk) = v.get("chunk").and_then(|c| c.as_u64()) {
                            transferred.store(chunk, Ordering::Relaxed);
                        }
                        if let Some(tc) = v.get("total_chunks").and_then(|c| c.as_u64()) {
                            total.store(tc, Ordering::Relaxed);
                        }
                    }
                },
                cancel_flag,
            );

            let mut uploader =
                transfer::Uploader::new(auth, &file_id, encryption_key);

            if !cipher.is_empty() {
                uploader = uploader.with_cipher(&cipher);
            }
            if !already_uploaded.is_empty() {
                uploader = uploader.with_already_uploaded(&already_uploaded);
            }

            let hashes = uploader
                .run(&http, &source, &progress, None)
                .await
                .map_err(|e| e.to_string())?;

            serde_json::to_string(&hashes).map_err(|e| e.to_string())
        })
    })
    .await
    .map_err(|e| e.to_string())?;

    clear_progress(&file_id_cleanup);
    result
}

/// Download a file from the Hoodik server and return the decrypted bytes.
///
/// Uses the transfer crate's concurrent download pipeline (16 parallel chunk
/// fetches with sliding window, out-of-order reassembly).
pub async fn download_file(
    base_url: String,
    cookie: String,
    file_id: String,
    file_size: u64,
    chunk_count: u64,
    decryption_key: Vec<u8>,
    cipher: String,
    direct_urls: Vec<String>,
) -> Result<Vec<u8>, String> {
    let cancel_flag = register_cancel_flag(&file_id);
    let (transferred, total) = register_progress(&file_id);
    total.store(file_size, Ordering::Relaxed);
    let file_id_cleanup = file_id.clone();

    let result = tokio::task::spawn_blocking(move || {
        let rt = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .map_err(|e| e.to_string())?;

        let local = tokio::task::LocalSet::new();
        local.block_on(&rt, async move {
            let auth = transfer::types::Auth {
                base_url,
                jwt_token: None,
                refresh_token: None,
                cookie: Some(cookie),
            };

            let http = transfer::native::http::NativeHttpClient::new()
                .map_err(|e| e.to_string())?;

            let progress = transfer::native::progress::NativeProgressReporter::new(
                move |json: &str| {
                    if let Ok(v) = serde_json::from_str::<serde_json::Value>(json) {
                        if let Some(bytes) = v.get("bytes_downloaded").and_then(|b| b.as_u64()) {
                            transferred.store(bytes, Ordering::Relaxed);
                        }
                        if let Some(tb) = v.get("total_bytes").and_then(|b| b.as_u64()) {
                            total.store(tb, Ordering::Relaxed);
                        }
                    }
                },
                cancel_flag,
            );

            let mut downloader = transfer::Downloader::new(
                auth, &file_id, file_size, chunk_count, decryption_key,
            );

            if !cipher.is_empty() {
                downloader = downloader.with_cipher(&cipher);
            }

            if !direct_urls.is_empty() {
                downloader = downloader.with_direct_urls(direct_urls);
            }

            downloader
                .run(&http, &progress)
                .await
                .map_err(|e| e.to_string())
        })
    })
    .await
    .map_err(|e| e.to_string())?;

    clear_progress(&file_id_cleanup);
    result
}

/// Download a file and save it to a local path instead of returning bytes.
/// Better for large files — avoids holding the entire file in memory.
pub async fn download_file_to_path(
    base_url: String,
    cookie: String,
    file_id: String,
    file_size: u64,
    chunk_count: u64,
    decryption_key: Vec<u8>,
    cipher: String,
    output_path: String,
    direct_urls: Vec<String>,
) -> Result<(), String> {
    let bytes = download_file(
        base_url,
        cookie,
        file_id,
        file_size,
        chunk_count,
        decryption_key,
        cipher,
        direct_urls,
    )
    .await?;

    tokio::fs::write(&output_path, &bytes)
        .await
        .map_err(|e| e.to_string())
}

// ---------------------------------------------------------------------------
// Chunk-based download (no decryption) + on-demand decrypt
// ---------------------------------------------------------------------------

/// Download encrypted chunks to a directory without decrypting.
///
/// Each chunk is saved as `{output_dir}/{chunk_index:06}.enc`.  Uses 16
/// concurrent downloads with a sliding window — same throughput as the
/// original pipeline but with ~4 MB peak memory instead of the full file.
///
/// `already_downloaded` lists chunk indices to skip (resume support).
///
/// `direct_urls`, when non-empty, holds one presigned storage URL per chunk
/// index. Those chunks are fetched straight from the bucket and carry no
/// session credentials; any index the list does not cover falls back to the
/// server, so a short or absent list degrades instead of failing.
pub async fn download_encrypted_chunks(
    base_url: String,
    cookie: String,
    file_id: String,
    file_size: u64,
    chunk_count: u64,
    output_dir: String,
    already_downloaded: Vec<u64>,
    direct_urls: Vec<String>,
) -> Result<(), String> {
    let cancel_flag = register_cancel_flag(&file_id);
    let (transferred, total) = register_progress(&file_id);
    total.store(file_size, Ordering::Relaxed);
    let file_id_cleanup = file_id.clone();

    let result = tokio::task::spawn_blocking(move || {
        let rt = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .map_err(|e| e.to_string())?;

        let local = tokio::task::LocalSet::new();
        local.block_on(&rt, async move {
            let auth = transfer::types::Auth {
                base_url,
                jwt_token: None,
                refresh_token: None,
                cookie: Some(cookie),
            };

            let http = transfer::native::http::NativeHttpClient::new()
                .map_err(|e| e.to_string())?;

            let progress = transfer::native::progress::NativeProgressReporter::new(
                move |json: &str| {
                    if let Ok(v) = serde_json::from_str::<serde_json::Value>(json) {
                        if let Some(bytes) = v.get("bytes_downloaded").and_then(|b| b.as_u64()) {
                            transferred.store(bytes, Ordering::Relaxed);
                        }
                        if let Some(tb) = v.get("total_bytes").and_then(|b| b.as_u64()) {
                            total.store(tb, Ordering::Relaxed);
                        }
                    }
                },
                cancel_flag,
            );

            // Ensure the output directory exists.
            tokio::fs::create_dir_all(&output_dir)
                .await
                .map_err(|e| e.to_string())?;

            transfer::download::download_chunks_to_dir(
                &http,
                &progress,
                &auth,
                &file_id,
                file_size,
                chunk_count,
                &output_dir,
                &already_downloaded,
                if direct_urls.is_empty() {
                    None
                } else {
                    Some(direct_urls.as_slice())
                },
            )
            .await
            .map_err(|e| e.to_string())
        })
    })
    .await
    .map_err(|e| e.to_string())?;

    clear_progress(&file_id_cleanup);
    result
}

/// Download a file's encrypted chunks as one tar stream and unpack to
/// `{output_dir}/{index:06}.enc`. Uses the server's `?format=tar` endpoint
/// so the whole file arrives in a single HTTP response instead of N
/// per-chunk GETs — the decisive win on high-latency links and the
/// fallback path when the OS-native background downloader isn't
/// available (desktop Linux/Windows, self-signed certs on iOS/macOS).
///
/// `already_downloaded` lists chunk indices already cached on disk. The
/// tar endpoint itself returns the full archive — existing chunks on
/// disk are simply left untouched because the bulk extract rewrites by
/// filename. Kept in the signature to match the per-chunk fallback so
/// the pipeline can feed either implementation the same arguments.
pub async fn download_file_as_tar(
    base_url: String,
    cookie: String,
    file_id: String,
    file_size: u64,
    chunk_count: u64,
    output_dir: String,
    already_downloaded: Vec<u64>,
) -> Result<(), String> {
    let _ = (chunk_count, already_downloaded);

    let cancel_flag = register_cancel_flag(&file_id);
    let (transferred, total) = register_progress(&file_id);
    total.store(file_size, Ordering::Relaxed);
    let file_id_cleanup = file_id.clone();

    let result = tokio::task::spawn_blocking(move || {
        let rt = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .map_err(|e| e.to_string())?;

        let local = tokio::task::LocalSet::new();
        local.block_on(&rt, async move {
            let auth = transfer::types::Auth {
                base_url,
                jwt_token: None,
                refresh_token: None,
                cookie: Some(cookie),
            };

            let http = transfer::native::http::NativeHttpClient::new()
                .map_err(|e| e.to_string())?;

            let progress = transfer::native::progress::NativeProgressReporter::new(
                move |json: &str| {
                    if let Ok(v) = serde_json::from_str::<serde_json::Value>(json) {
                        if let Some(bytes) = v.get("bytes_downloaded").and_then(|b| b.as_u64()) {
                            transferred.store(bytes, Ordering::Relaxed);
                        }
                        if let Some(tb) = v.get("total_bytes").and_then(|b| b.as_u64()) {
                            total.store(tb, Ordering::Relaxed);
                        }
                    }
                },
                cancel_flag,
            );

            tokio::fs::create_dir_all(&output_dir)
                .await
                .map_err(|e| e.to_string())?;

            transfer::download::download_chunks_to_dir_bulk(
                &http,
                &progress,
                &auth,
                &file_id,
                file_size,
                &output_dir,
            )
            .await
            .map_err(|e| e.to_string())
        })
    })
    .await
    .map_err(|e| e.to_string())?;

    clear_progress(&file_id_cleanup);
    result
}

/// Upload previously-encrypted chunks from `{chunks_dir}/{index:06}.enc`
/// as a single tar stream to `POST /api/storage/{file_id}?format=tar`.
///
/// Returns the server's `chunks_stored` / `finished_upload_at` so the
/// caller can tell whether the upload completed on this attempt. Older
/// servers that don't understand `?format=tar` surface that through the
/// normal HTTP error path; the pipeline reads that signal and falls back
/// to per-chunk uploads.
pub async fn upload_file_as_tar(
    base_url: String,
    cookie: String,
    file_id: String,
    chunks_dir: String,
    chunk_count: u64,
) -> Result<UploadCompleteSummary, String> {
    let cancel_flag = register_cancel_flag(&file_id);
    let (transferred, total) = register_progress(&file_id);
    total.store(chunk_count, Ordering::Relaxed);
    let file_id_cleanup = file_id.clone();

    let result: Result<UploadCompleteSummary, String> = tokio::task::spawn_blocking(move || {
        let rt = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .map_err(|e| e.to_string())?;

        let local = tokio::task::LocalSet::new();
        local.block_on(&rt, async move {
            let auth = transfer::types::Auth {
                base_url,
                jwt_token: None,
                refresh_token: None,
                cookie: Some(cookie),
            };

            let http = transfer::native::http::NativeHttpClient::new()
                .map_err(|e| e.to_string())?;

            let progress = transfer::native::progress::NativeProgressReporter::new(
                move |json: &str| {
                    if let Ok(v) = serde_json::from_str::<serde_json::Value>(json) {
                        if let Some(bytes) = v.get("bytes_downloaded").and_then(|b| b.as_u64()) {
                            transferred.store(bytes, Ordering::Relaxed);
                        }
                        if let Some(tb) = v.get("total_bytes").and_then(|b| b.as_u64()) {
                            total.store(tb, Ordering::Relaxed);
                        }
                    }
                },
                cancel_flag,
            );

            let resp = transfer::upload_tar::upload_chunks_as_tar(
                &http,
                &progress,
                &auth,
                &file_id,
                &chunks_dir,
                chunk_count,
            )
            .await
            .map_err(|e| e.to_string())?;

            Ok(UploadCompleteSummary {
                chunks_stored: resp.chunks_stored.unwrap_or(0),
                finished_upload_at: resp.finished_upload_at,
            })
        })
    })
    .await
    .map_err(|e| e.to_string())?;

    clear_progress(&file_id_cleanup);
    result
}

/// Decrypt previously downloaded encrypted chunks to a single output file.
///
/// Reads chunks sequentially from `{chunks_dir}/{index:06}.enc`, decrypts
/// each with the given key+cipher, and streams plaintext to `output_path`.
/// Peak memory: ~4 MB (one chunk at a time).
pub async fn decrypt_chunks_to_file(
    chunks_dir: String,
    chunk_count: u64,
    decryption_key: Vec<u8>,
    cipher: String,
    output_path: String,
    file_id: String,
) -> Result<(), String> {
    let file_id_cleanup = file_id.clone();
    let (transferred, total) = register_progress(&file_id);
    total.store(chunk_count, Ordering::Relaxed);

    let result = tokio::task::spawn_blocking(move || {
        let rt = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .map_err(|e| e.to_string())?;

        let local = tokio::task::LocalSet::new();
        local.block_on(&rt, async move {
            transfer::download::decrypt_chunks_to_file(
                &chunks_dir,
                chunk_count,
                &decryption_key,
                &cipher,
                &output_path,
            )
            .await
            .map_err(|e| e.to_string())?;

            transferred.store(chunk_count, Ordering::Relaxed);
            Ok(())
        })
    })
    .await
    .map_err(|e| e.to_string())?;

    clear_progress(&file_id_cleanup);
    result
}

/// Unpack a tar archive of encrypted chunks into individual files.
///
/// Reads the archive at [`tar_path`] sequentially and writes every regular
/// file entry to `{output_dir}/{entry_name}`. Headers are parsed one at a
/// time and only the current entry's payload lives in memory, so archives
/// much larger than free RAM unpack without swapping.
///
/// Pure local I/O — no network, no decryption. Decryption happens later via
/// [`decrypt_chunks_to_file`]. Counterpart to [`pack_chunks_to_tar`].
#[frb(sync)]
pub fn unpack_tar_to_chunks(tar_path: String, output_dir: String) -> Result<(), String> {
    use std::fs;
    use std::io::{BufReader, Read, Write};

    fs::create_dir_all(&output_dir).map_err(|e| format!("create {output_dir}: {e}"))?;

    let file = fs::File::open(&tar_path).map_err(|e| format!("open {tar_path}: {e}"))?;
    let mut reader = BufReader::new(file);
    let mut header = [0u8; 512];
    let mut copy_buf = vec![0u8; 64 * 1024];

    loop {
        match reader.read_exact(&mut header) {
            Ok(()) => {}
            Err(ref e) if e.kind() == std::io::ErrorKind::UnexpectedEof => break,
            Err(e) => return Err(format!("read header: {e}")),
        }

        if header.iter().all(|&b| b == 0) {
            break;
        }

        let name_end = header[..100].iter().position(|&b| b == 0).unwrap_or(100);
        let name = std::str::from_utf8(&header[..name_end])
            .map_err(|e| format!("invalid tar entry name: {e}"))?
            .to_string();

        let size_str = std::str::from_utf8(&header[124..135])
            .map_err(|e| format!("invalid tar size field: {e}"))?
            .trim_matches('\0')
            .trim();
        let size = u64::from_str_radix(size_str, 8)
            .map_err(|e| format!("invalid tar size '{size_str}': {e}"))?;

        let out_path = format!("{output_dir}/{name}");
        let mut out_file =
            fs::File::create(&out_path).map_err(|e| format!("create {out_path}: {e}"))?;

        let mut remaining = size;
        while remaining > 0 {
            let to_read = remaining.min(copy_buf.len() as u64) as usize;
            reader
                .read_exact(&mut copy_buf[..to_read])
                .map_err(|e| format!("read payload of {name}: {e}"))?;
            out_file
                .write_all(&copy_buf[..to_read])
                .map_err(|e| format!("write {out_path}: {e}"))?;
            remaining -= to_read as u64;
        }

        let padding = transfer::tar::tar_padding_len(size);
        if padding > 0 {
            reader
                .read_exact(&mut copy_buf[..padding])
                .map_err(|e| format!("read padding of {name}: {e}"))?;
        }
    }

    Ok(())
}

/// Build a tar archive containing `{chunks_dir}/{index:06}.enc` for every
/// index in `[0, chunk_count)` and write it to [`tar_path`].
///
/// Chunks are streamed one at a time into the output archive so peak memory
/// stays at one chunk (~4 MB) rather than the full archive. Pure local I/O
/// — the caller uploads the resulting file through `background_downloader`
/// so the transfer survives app suspension. Counterpart to
/// [`unpack_tar_to_chunks`].
#[frb(sync)]
pub fn pack_chunks_to_tar(
    chunks_dir: String,
    chunk_count: u64,
    tar_path: String,
) -> Result<(), String> {
    use std::fs;
    use std::io::{BufWriter, Read, Write};

    if let Some(parent) = std::path::Path::new(&tar_path).parent() {
        if !parent.as_os_str().is_empty() {
            fs::create_dir_all(parent).map_err(|e| format!("create {parent:?}: {e}"))?;
        }
    }

    let out = fs::File::create(&tar_path).map_err(|e| format!("create {tar_path}: {e}"))?;
    let mut writer = BufWriter::new(out);
    let mut copy_buf = vec![0u8; 64 * 1024];

    for idx in 0..chunk_count {
        let name = format!("{:06}.enc", idx);
        let chunk_path = format!("{chunks_dir}/{name}");
        let mut chunk_file =
            fs::File::open(&chunk_path).map_err(|e| format!("open {chunk_path}: {e}"))?;
        let size = chunk_file
            .metadata()
            .map_err(|e| format!("stat {chunk_path}: {e}"))?
            .len();

        let header = transfer::tar::tar_header(&name, size);
        writer
            .write_all(&header)
            .map_err(|e| format!("write header for {name}: {e}"))?;

        let mut remaining = size;
        while remaining > 0 {
            let to_read = remaining.min(copy_buf.len() as u64) as usize;
            let read = chunk_file
                .read(&mut copy_buf[..to_read])
                .map_err(|e| format!("read {chunk_path}: {e}"))?;
            if read == 0 {
                return Err(format!(
                    "{chunk_path} shrank during packing: {} bytes missing",
                    remaining
                ));
            }
            writer
                .write_all(&copy_buf[..read])
                .map_err(|e| format!("write body for {name}: {e}"))?;
            remaining -= read as u64;
        }

        let padding = transfer::tar::tar_padding_len(size);
        if padding > 0 {
            let zeros = [0u8; 512];
            writer
                .write_all(&zeros[..padding])
                .map_err(|e| format!("write padding for {name}: {e}"))?;
        }
    }

    let end_block = [0u8; transfer::tar::TAR_END_OF_ARCHIVE_LEN];
    writer
        .write_all(&end_block)
        .map_err(|e| format!("write end-of-archive: {e}"))?;
    writer
        .flush()
        .map_err(|e| format!("flush {tar_path}: {e}"))?;

    Ok(())
}

// ---------------------------------------------------------------------------
// Transfer cancellation
// ---------------------------------------------------------------------------

use std::sync::Mutex;
use std::collections::HashMap;

/// Global cancellation flags keyed by file_id.
static CANCEL_FLAGS: std::sync::LazyLock<Mutex<HashMap<String, Arc<AtomicBool>>>> =
    std::sync::LazyLock::new(|| Mutex::new(HashMap::new()));

/// Global progress counters keyed by file_id: (bytes_transferred, total_bytes).
///
/// Updated by the `NativeProgressReporter` callback inside the transfer crate
/// and polled from Dart via [get_transfer_progress].
static TRANSFER_PROGRESS: std::sync::LazyLock<
    Mutex<HashMap<String, (Arc<AtomicU64>, Arc<AtomicU64>)>>,
> = std::sync::LazyLock::new(|| Mutex::new(HashMap::new()));

fn register_cancel_flag(file_id: &str) -> Arc<AtomicBool> {
    let flag = Arc::new(AtomicBool::new(false));
    CANCEL_FLAGS
        .lock()
        .unwrap()
        .insert(file_id.to_string(), flag.clone());
    flag
}

/// Register progress counters for a transfer.
/// Returns (transferred, total) atomic counters that can be updated from the
/// progress callback and polled from Dart.
fn register_progress(file_id: &str) -> (Arc<AtomicU64>, Arc<AtomicU64>) {
    let transferred = Arc::new(AtomicU64::new(0));
    let total = Arc::new(AtomicU64::new(0));
    TRANSFER_PROGRESS.lock().unwrap().insert(
        file_id.to_string(),
        (transferred.clone(), total.clone()),
    );
    (transferred, total)
}

/// Remove progress counters for a completed/failed transfer.
fn clear_progress(file_id: &str) {
    TRANSFER_PROGRESS.lock().unwrap().remove(file_id);
}

/// How far a transfer has got.
///
/// A named struct rather than a tuple: the generated binding for an
/// `Option<(u64, u64)>` decodes the pair as a `List<dynamic>` while declaring
/// it a Dart record, so every call threw
/// `type 'List<dynamic>' is not a subtype of type '(BigInt, BigInt)'`. Nothing
/// caught it, because the only caller polls from a timer where a throw goes to
/// the zone and disappears.
pub struct TransferProgress {
    /// Downloads count bytes; uploads count chunks.
    pub transferred: u64,
    /// The matching total, in the same unit.
    pub total: u64,
}

/// Poll the current progress of a transfer.
///
/// - For downloads: bytes downloaded out of total bytes.
/// - For uploads: chunks completed out of total chunks.
///
/// Returns `None` if no transfer with the given file_id is active.
#[frb(sync)]
pub fn get_transfer_progress(file_id: String) -> Option<TransferProgress> {
    TRANSFER_PROGRESS
        .lock()
        .unwrap()
        .get(&file_id)
        .map(|(t, total)| TransferProgress {
            transferred: t.load(Ordering::Relaxed),
            total: total.load(Ordering::Relaxed),
        })
}

/// Cancel an in-progress upload or download.
#[frb(sync)]
pub fn cancel_transfer(file_id: String) {
    if let Some(flag) = CANCEL_FLAGS.lock().unwrap().remove(&file_id) {
        flag.store(true, std::sync::atomic::Ordering::Relaxed);
    }
    clear_progress(&file_id);
}

// ---------------------------------------------------------------------------
// DTOs for flutter_rust_bridge
// ---------------------------------------------------------------------------

#[frb]
pub struct RsaKeyPair {
    pub private_key_pem: String,
    pub public_key_pem: String,
    pub fingerprint: String,
}

#[frb]
pub struct RsaPublicInfo {
    pub public_key_pem: String,
    pub fingerprint: String,
}

#[frb]
pub struct WrappingKeyPair {
    pub private_pem: String,
    pub public_pem: String,
}

#[frb]
pub struct Ed25519KeyPair {
    pub private_pem: String,
    pub public_pem: String,
}

#[frb]
pub struct OpaqueClientStart {
    pub state: String,
    pub message: String,
}

#[frb]
pub struct OpaqueRegisterFinish {
    pub message: String,
    pub export_key: String,
}

#[frb]
pub struct OpaqueLoginFinish {
    pub finalization: String,
    pub session_key: String,
    pub export_key: String,
}

#[frb]
pub struct TransitionSignatures {
    pub old_signature: String,
    pub new_signature: String,
}

/// Minimal subset of the server's upload-complete response that the
/// Flutter pipeline needs. Matches the `chunks_stored` / `finished_upload_at`
/// fields of `transfer::types::ChunkResponse`, flattened for FFI.
#[frb(non_opaque)]
pub struct UploadCompleteSummary {
    pub chunks_stored: i64,
    pub finished_upload_at: Option<i64>,
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_rsa_roundtrip() {
        let keypair = generate_rsa_keypair().unwrap();
        assert!(keypair.private_key_pem.contains("BEGIN RSA PRIVATE KEY"));
        assert!(keypair.public_key_pem.contains("BEGIN RSA PUBLIC KEY"));
        assert!(!keypair.fingerprint.is_empty());

        // Sign and verify
        let message = "hello world";
        let sig = rsa_sign(message.to_string(), keypair.private_key_pem.clone()).unwrap();
        let valid =
            rsa_verify(message.to_string(), sig.clone(), keypair.public_key_pem.clone()).unwrap();
        assert!(valid);

        // Encrypt and decrypt
        let plaintext = "secret data";
        let encrypted =
            rsa_encrypt(plaintext.to_string(), keypair.public_key_pem.clone()).unwrap();
        let decrypted = rsa_decrypt(encrypted, keypair.private_key_pem.clone()).unwrap();
        assert_eq!(decrypted, plaintext);
    }

    #[test]
    fn test_rsa_public_from_private() {
        let keypair = generate_rsa_keypair().unwrap();
        let info = rsa_public_from_private(keypair.private_key_pem).unwrap();
        assert_eq!(info.public_key_pem, keypair.public_key_pem);
        assert_eq!(info.fingerprint, keypair.fingerprint);
    }

    #[test]
    fn test_wrapping_wrap_unwrap_roundtrip() {
        let keypair = generate_wrapping_keypair().unwrap();
        assert!(keypair.private_pem.contains("BEGIN HOODIK WRAPPING PRIVATE KEY"));
        assert!(keypair.public_pem.contains("BEGIN HOODIK WRAPPING KEY"));

        let file_key = cipher_generate_key("aegis128l".to_string()).unwrap();
        let blob = wrapping_wrap(file_key.clone(), keypair.public_pem.clone()).unwrap();
        let unwrapped = wrapping_unwrap(blob.clone(), keypair.private_pem).unwrap();
        assert_eq!(unwrapped, file_key);

        let other = generate_wrapping_keypair().unwrap();
        assert!(wrapping_unwrap(blob, other.private_pem).is_err());
    }

    #[test]
    fn test_ed25519_sign_verify() {
        let keypair = generate_ed25519_keypair().unwrap();
        let message = "hello world";
        let sig = ed25519_sign(message.to_string(), keypair.private_pem.clone()).unwrap();
        let valid =
            ed25519_verify(message.to_string(), sig.clone(), keypair.public_pem.clone()).unwrap();
        assert!(valid);

        let tampered =
            ed25519_verify("hello world!".to_string(), sig, keypair.public_pem).unwrap();
        assert!(!tampered);
    }

    #[test]
    fn test_ed25519_sign_verify_bytes() {
        let keypair = generate_ed25519_keypair().unwrap();
        let message = vec![0u8, 159, 146, 150];
        let sig = ed25519_sign_bytes(message.clone(), keypair.private_pem).unwrap();
        let valid =
            ed25519_verify_bytes(message.clone(), sig.clone(), keypair.public_pem.clone())
                .unwrap();
        assert!(valid);

        let mut tampered = message;
        tampered[0] ^= 1;
        assert!(!ed25519_verify_bytes(tampered, sig, keypair.public_pem).unwrap());
    }

    #[test]
    fn test_member_pubkey_der_dispatches_by_key_type() {
        let rsa = generate_rsa_keypair().unwrap();
        assert_eq!(
            member_pubkey_der("rsa".to_string(), rsa.public_key_pem.clone()).unwrap(),
            rsa_pkcs1_der_from_pem(rsa.public_key_pem).unwrap()
        );

        let ed = generate_ed25519_keypair().unwrap();
        let pem_body = ed
            .public_pem
            .lines()
            .filter(|line| !line.starts_with("-----"))
            .collect::<String>();
        assert_eq!(
            member_pubkey_der("curve25519".to_string(), ed.public_pem).unwrap(),
            cryptfns::base64::decode(&pem_body).unwrap()
        );

        assert!(member_pubkey_der("ed448".to_string(), String::new()).is_err());
    }

    #[test]
    fn test_spki_fingerprint() {
        // spki_fingerprint is for the Ed25519 identity key (an SPKI PUBLIC KEY
        // PEM); the wrapping key is a different, non-SPKI container.
        let keypair = generate_ed25519_keypair().unwrap();
        let fingerprint = spki_fingerprint(keypair.public_pem.clone()).unwrap();
        assert_eq!(fingerprint.len(), 64);
        assert!(fingerprint.chars().all(|c| c.is_ascii_hexdigit()));
        assert_eq!(spki_fingerprint(keypair.public_pem).unwrap(), fingerprint);
    }

    #[test]
    fn test_cipher_roundtrip_aegis() {
        let key = cipher_generate_key("aegis128l".to_string()).unwrap();
        let plaintext = b"hello encrypted world".to_vec();
        let encrypted =
            cipher_encrypt("aegis128l".to_string(), key.clone(), plaintext.clone()).unwrap();
        let decrypted = cipher_decrypt("aegis128l".to_string(), key, encrypted).unwrap();
        assert_eq!(decrypted, plaintext);
    }

    #[test]
    fn test_cipher_roundtrip_chacha() {
        let key = cipher_generate_key("chacha20poly1305".to_string()).unwrap();
        let plaintext = b"hello chacha world".to_vec();
        let encrypted =
            cipher_encrypt("chacha20poly1305".to_string(), key.clone(), plaintext.clone()).unwrap();
        let decrypted = cipher_decrypt("chacha20poly1305".to_string(), key, encrypted).unwrap();
        assert_eq!(decrypted, plaintext);
    }

    #[test]
    fn test_cipher_roundtrip_ascon() {
        let key = cipher_generate_key("ascon128a".to_string()).unwrap();
        let plaintext = b"hello ascon world".to_vec();
        let encrypted =
            cipher_encrypt("ascon128a".to_string(), key.clone(), plaintext.clone()).unwrap();
        let decrypted = cipher_decrypt("ascon128a".to_string(), key, encrypted).unwrap();
        assert_eq!(decrypted, plaintext);
    }

    #[test]
    fn test_cipher_roundtrip_aegis256() {
        let key = cipher_generate_key("aegis256".to_string()).unwrap();
        let plaintext = b"hello aegis256 world".to_vec();
        let encrypted =
            cipher_encrypt("aegis256".to_string(), key.clone(), plaintext.clone()).unwrap();
        let decrypted = cipher_decrypt("aegis256".to_string(), key, encrypted).unwrap();
        assert_eq!(decrypted, plaintext);
    }

    #[test]
    fn test_sha256() {
        let hash = sha256_digest(b"hello".to_vec());
        assert_eq!(
            hash,
            "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
        );
    }

    #[test]
    fn test_base64_roundtrip() {
        let data = b"hello world".to_vec();
        let encoded = base64_encode(data.clone());
        let decoded = base64_decode(encoded).unwrap();
        assert_eq!(decoded, data);
    }

    #[test]
    fn test_transfer_progress_lifecycle() {
        let file_id = "test-progress-file".to_string();

        // No progress before registration.
        assert!(get_transfer_progress(file_id.clone()).is_none());

        // Register and verify initial state.
        let (transferred, total) = register_progress(&file_id);
        total.store(10000, Ordering::Relaxed);

        let progress = get_transfer_progress(file_id.clone()).unwrap();
        assert_eq!((progress.transferred, progress.total), (0, 10000));

        // Simulate progress updates.
        transferred.store(5000, Ordering::Relaxed);
        let progress = get_transfer_progress(file_id.clone()).unwrap();
        assert_eq!((progress.transferred, progress.total), (5000, 10000));

        // Clear and verify removal.
        clear_progress(&file_id);
        assert!(get_transfer_progress(file_id.clone()).is_none());
    }

    #[test]
    fn test_cancel_clears_progress() {
        let file_id = "test-cancel-progress".to_string();

        // Register cancel flag and progress.
        let _flag = register_cancel_flag(&file_id);
        let (_transferred, total) = register_progress(&file_id);
        total.store(5000, Ordering::Relaxed);

        assert!(get_transfer_progress(file_id.clone()).is_some());

        // Cancel should clear both the flag and the progress.
        cancel_transfer(file_id.clone());
        assert!(get_transfer_progress(file_id.clone()).is_none());
    }

    /// Round-trip a handful of chunks through [`pack_chunks_to_tar`] +
    /// [`unpack_tar_to_chunks`]. Confirms the tar payload matches the
    /// per-chunk expectation used by the Hoodik server's `?format=tar`
    /// endpoint so the new Dart wiring produces wire-compatible archives.
    #[test]
    fn test_pack_unpack_roundtrip() {
        let tmp = std::env::temp_dir().join(format!(
            "hoodik_tar_roundtrip_{}",
            std::process::id()
        ));
        let _ = std::fs::remove_dir_all(&tmp);
        std::fs::create_dir_all(&tmp).unwrap();

        let src_dir = tmp.join("chunks");
        let unpacked_dir = tmp.join("unpacked");
        let tar_path = tmp.join("out.tar");
        std::fs::create_dir_all(&src_dir).unwrap();

        let chunks: Vec<Vec<u8>> = vec![
            vec![0xAA; 100],
            vec![0xBB; 512],
            vec![0xCC; 1500],
        ];
        for (i, data) in chunks.iter().enumerate() {
            let path = src_dir.join(format!("{:06}.enc", i));
            std::fs::write(path, data).unwrap();
        }

        pack_chunks_to_tar(
            src_dir.to_string_lossy().into_owned(),
            chunks.len() as u64,
            tar_path.to_string_lossy().into_owned(),
        )
        .unwrap();

        unpack_tar_to_chunks(
            tar_path.to_string_lossy().into_owned(),
            unpacked_dir.to_string_lossy().into_owned(),
        )
        .unwrap();

        for (i, expected) in chunks.iter().enumerate() {
            let read = std::fs::read(unpacked_dir.join(format!("{:06}.enc", i))).unwrap();
            assert_eq!(&read, expected, "chunk {i} mismatch");
        }

        std::fs::remove_dir_all(&tmp).ok();
    }

    /// FFI `folder_member_list_encode_v1` must produce identical bytes
    /// regardless of caller-supplied member ordering — JS, Dart, and the
    /// Rust integration suite all rely on the encoder sorting by
    /// `user_id` before emitting bytes.
    #[test]
    fn test_folder_member_list_encode_is_order_independent() {
        let folder_id = vec![0xF0u8; 16];
        let owner_id = vec![0x11u8; 16];

        let mut user_ids = Vec::new();
        user_ids.extend_from_slice(&[0x11u8; 16]);
        user_ids.extend_from_slice(&[0x22u8; 16]);
        let mut fingerprints = Vec::new();
        fingerprints.extend_from_slice(&[0xA1u8; 32]);
        fingerprints.extend_from_slice(&[0xB2u8; 32]);
        let share_roles = vec![0u8, 2u8];
        let is_owner_flags = vec![1u8, 0u8];
        let mut signed_by = Vec::new();
        signed_by.extend_from_slice(&[0x11u8; 16]);
        signed_by.extend_from_slice(&[0x11u8; 16]);

        let ordered = folder_member_list_encode_v1(
            folder_id.clone(),
            owner_id.clone(),
            user_ids.clone(),
            fingerprints.clone(),
            share_roles.clone(),
            is_owner_flags.clone(),
            signed_by.clone(),
            1_736_000_000,
        )
        .unwrap();

        let mut user_ids_rev = Vec::new();
        user_ids_rev.extend_from_slice(&[0x22u8; 16]);
        user_ids_rev.extend_from_slice(&[0x11u8; 16]);
        let mut fingerprints_rev = Vec::new();
        fingerprints_rev.extend_from_slice(&[0xB2u8; 32]);
        fingerprints_rev.extend_from_slice(&[0xA1u8; 32]);
        let share_roles_rev = vec![2u8, 0u8];
        let is_owner_flags_rev = vec![0u8, 1u8];

        let reversed = folder_member_list_encode_v1(
            folder_id,
            owner_id,
            user_ids_rev,
            fingerprints_rev,
            share_roles_rev,
            is_owner_flags_rev,
            signed_by,
            1_736_000_000,
        )
        .unwrap();

        assert_eq!(ordered, reversed);
    }

    /// [`pack_chunks_to_tar`] refuses to proceed when a referenced chunk
    /// file is missing. The Dart pipeline relies on this to surface encrypt-
    /// stage bugs instead of uploading truncated tar archives.
    #[test]
    fn test_pack_fails_on_missing_chunk() {
        let tmp = std::env::temp_dir().join(format!(
            "hoodik_tar_missing_{}",
            std::process::id()
        ));
        let _ = std::fs::remove_dir_all(&tmp);
        std::fs::create_dir_all(&tmp).unwrap();

        let result = pack_chunks_to_tar(
            tmp.join("missing").to_string_lossy().into_owned(),
            2,
            tmp.join("out.tar").to_string_lossy().into_owned(),
        );
        assert!(result.is_err());

        std::fs::remove_dir_all(&tmp).ok();
    }

    #[test]
    fn test_envelope_seal_open_roundtrip() {
        let kek = envelope_derive_kek(b"export-key-material".to_vec()).unwrap();
        let bundle = b"identity+wrapping key bundle".to_vec();

        let sealed = envelope_seal(kek.clone(), bundle.clone()).unwrap();
        let opened = envelope_open(kek, sealed.clone()).unwrap();
        assert_eq!(opened, bundle);

        let wrong_kek = envelope_derive_kek(b"different-export-key".to_vec()).unwrap();
        assert!(envelope_open(wrong_kek, sealed).is_err());
    }

    #[test]
    fn test_envelope_derive_kek_is_deterministic() {
        let a = envelope_derive_kek(b"same-export-key".to_vec()).unwrap();
        let b = envelope_derive_kek(b"same-export-key".to_vec()).unwrap();
        assert_eq!(a, b);
        assert_eq!(a.len(), 32);
    }

    #[test]
    fn test_envelope_rewrap_changes_kek() {
        let old_kek = envelope_derive_kek(b"old-export".to_vec()).unwrap();
        let new_kek = envelope_derive_kek(b"new-export".to_vec()).unwrap();
        let bundle = b"secret bundle".to_vec();

        let sealed = envelope_seal(old_kek.clone(), bundle.clone()).unwrap();
        let rewrapped = envelope_rewrap(old_kek, new_kek.clone(), sealed).unwrap();

        assert_eq!(envelope_open(new_kek, rewrapped).unwrap(), bundle);
    }

    #[test]
    fn test_transition_sign_rsa_old_key() {
        let old = generate_rsa_keypair().unwrap();
        let new_identity = generate_ed25519_keypair().unwrap();
        let new_wrapping = generate_wrapping_keypair().unwrap();

        let old_fingerprint = "aa".repeat(32);
        let new_fingerprint = "bb".repeat(32);

        let sigs = transition_sign(
            vec![0x11u8; 16],
            "rsa".to_string(),
            old.public_key_pem,
            old_fingerprint,
            new_identity.public_pem,
            new_wrapping.public_pem,
            new_fingerprint,
            1_736_000_000,
            old.private_key_pem,
            new_identity.private_pem,
        )
        .unwrap();

        assert!(!sigs.old_signature.is_empty());
        assert!(!sigs.new_signature.is_empty());
    }

    #[test]
    fn test_cipher_chunk_roundtrip_and_legacy_fallback() {
        let key = cipher_generate_key("aegis128l".to_string()).unwrap();
        let plaintext = b"chunked payload".to_vec();

        // Chunk 0 stays byte-identical to the whole-payload encryption.
        assert_eq!(
            cipher_encrypt_chunk("aegis128l".to_string(), key.clone(), 0, plaintext.clone())
                .unwrap(),
            cipher_encrypt("aegis128l".to_string(), key.clone(), plaintext.clone()).unwrap()
        );

        let chunk3 =
            cipher_encrypt_chunk("aegis128l".to_string(), key.clone(), 3, plaintext.clone())
                .unwrap();
        assert_eq!(
            cipher_decrypt_chunk("aegis128l".to_string(), key.clone(), 3, chunk3).unwrap(),
            plaintext
        );

        // A pre-fix blob (fixed nonce at every index) still decrypts.
        let legacy =
            cipher_encrypt("aegis128l".to_string(), key.clone(), plaintext.clone()).unwrap();
        assert_eq!(
            cipher_decrypt_chunk("aegis128l".to_string(), key, 3, legacy).unwrap(),
            plaintext
        );
    }

    #[test]
    fn test_transition_verify_accepts_genuine_and_rejects_forged() {
        let old = generate_rsa_keypair().unwrap();
        let new_identity = generate_ed25519_keypair().unwrap();
        let new_wrapping = generate_wrapping_keypair().unwrap();
        let old_fingerprint = old.fingerprint.clone();
        let new_fingerprint = spki_fingerprint(new_identity.public_pem.clone()).unwrap();

        let sigs = transition_sign(
            vec![0x11u8; 16],
            "rsa".to_string(),
            old.public_key_pem.clone(),
            old_fingerprint.clone(),
            new_identity.public_pem.clone(),
            new_wrapping.public_pem.clone(),
            new_fingerprint.clone(),
            1_736_000_000,
            old.private_key_pem,
            new_identity.private_pem,
        )
        .unwrap();

        let old_spki = rsa_pkcs1_der_from_pem(old.public_key_pem).unwrap();
        let verify = |old_sig: &str, new_sig: &str| {
            transition_verify(
                vec![0x11u8; 16],
                "rsa".to_string(),
                old_spki.clone(),
                old_fingerprint.clone(),
                new_identity.public_pem.clone(),
                new_wrapping.public_pem.clone(),
                new_fingerprint.clone(),
                1_736_000_000,
                old_sig.to_string(),
                new_sig.to_string(),
            )
            .unwrap()
        };

        assert!(verify(&sigs.old_signature, &sigs.new_signature));
        assert!(!verify("", ""));
        assert!(!verify(&sigs.new_signature, &sigs.old_signature));
    }

    #[test]
    fn test_sign_key_rotation_audit_roundtrip() {
        let new_identity = generate_ed25519_keypair().unwrap();
        let user_id = vec![0x22u8; 16];
        let old_fingerprint = "aa".repeat(32);
        let new_fingerprint = "bb".repeat(32);

        let sig = sign_key_rotation_audit(
            user_id.clone(),
            old_fingerprint.clone(),
            new_fingerprint.clone(),
            1_736_000_000,
            new_identity.private_pem.clone(),
        )
        .unwrap();
        assert!(!sig.is_empty());

        cryptfns::transition::verify_key_rotation_audit(
            &user_id,
            &old_fingerprint,
            &new_fingerprint,
            1_736_000_000,
            &sig,
            &new_identity.public_pem,
        )
        .unwrap();

        // A verifier that reconstructs a different rotated_at must reject it.
        assert!(cryptfns::transition::verify_key_rotation_audit(
            &user_id,
            &old_fingerprint,
            &new_fingerprint,
            1_736_000_001,
            &sig,
            &new_identity.public_pem,
        )
        .is_err());
    }

    #[test]
    fn test_opaque_client_registration_start_shape() {
        let start = opaque_client_registration_start(b"correct horse battery".to_vec()).unwrap();
        assert!(!start.state.is_empty());
        assert!(!start.message.is_empty());
    }

    #[tokio::test]
    async fn test_argon2id_derive_key_is_deterministic_and_salted() {
        let secret = b"device-key||pin".to_vec();
        let salt = b"salt-16-bytes-ab".to_vec();

        let a = argon2id_derive_key(secret.clone(), salt.clone()).await.unwrap();
        assert_eq!(a.len(), 32);
        assert_eq!(a, argon2id_derive_key(secret.clone(), salt.clone()).await.unwrap());

        assert_ne!(a, argon2id_derive_key(secret, b"salt-16-bytes-cd".to_vec()).await.unwrap());
        assert_ne!(a, argon2id_derive_key(b"other-secret".to_vec(), salt).await.unwrap());
    }
}
