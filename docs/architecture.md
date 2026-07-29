# Hoodik App Architecture

## Summary

The Hoodik app is a Flutter-based mobile/desktop client for self-hosted, end-to-end encrypted cloud storage. All cryptographic operations run client-side via Rust FFI (the same `cryptfns` and `transfer` crates the web frontend uses via WASM). The server never sees plaintext data. Read this document first when onboarding to the codebase.

---

## Tech Stack

| Technology | Purpose | Package |
|------------|---------|---------|
| Flutter 3.41+ | UI framework | -- |
| Dart 3.11+ | Language | -- |
| Riverpod | State management | `flutter_riverpod` |
| GoRouter | Routing & navigation | `go_router` |
| Drift | Local SQLite database | `drift` |
| Dio | HTTP client | `dio` with `cookie_jar` |
| flutter_rust_bridge v2.11.1 | Rust FFI bindings | `flutter_rust_bridge` |
| local_auth | Biometric authentication | `local_auth` |
| flutter_secure_storage | Keychain/Keystore access | `flutter_secure_storage` |

---

## Architecture Overview

The app is a Flutter client that communicates with a self-hosted Hoodik server. All cryptographic operations happen client-side via Rust FFI (the same `cryptfns` and `transfer` crates used by the web frontend via WASM).

```
+-----------------------------------------+
|               Flutter UI                |
|  (Riverpod providers + GoRouter)        |
+-----------------------------------------+
|            Core Services                |
|  FileOperations, TransferManager,       |
|  OfflineManager, SyncService,           |
|  AuthService, CryptoService             |
+--------------+--------------------------+
|  Worker      |    Rust FFI              |
|  Isolates    |    (flutter_rust_bridge)  |
|  (upload,    |    +------------------+  |
|   download,  |    | cryptfns crate   |  |
|   decrypt)   |    | transfer crate   |  |
|              |    +------------------+  |
+--------------+--------------------------+
|         Local Storage                   |
|  Drift SQLite (servers, accounts,       |
|  cached files, offline files,           |
|  pending uploads)                       |
+-----------------------------------------+
```

---

## Directory Structure

Listed at directory granularity — individual filenames move too often for a
document to track them honestly.

```
lib/
├── main.dart          # App entry point
├── router.dart        # GoRouter configuration
├── core/
│   ├── providers.dart # All Riverpod providers
│   ├── api/           # Dio HTTP clients, one per server domain, plus wire models
│   ├── auth/          # Login, signature auth, session management
│   ├── crypto/        # Key management, file/name encryption, search tokenization
│   ├── mcp/           # Embedded MCP server (desktop): protocol, tools, audit log
│   ├── platform/      # Platform integration (tray, window, share targets)
│   ├── services/      # Transfers, offline cache, sync, thumbnails, log export
│   ├── storage/       # Drift SQLite schema + queries
│   ├── theme/         # Material 3 theme and the Hoodik palette
│   ├── utils/         # Small shared helpers (hex, redaction, formatting)
│   ├── widgets/       # Platform-adaptive widget wrappers
│   └── workers/       # Upload, download and decrypt isolates + typed messages
├── features/          # One directory per feature, each with screens/ and its
│   │                  # own widgets/, services/, providers/ as needed
│   ├── account/       # Account settings, multi-account, diagnostics, MCP setup
│   ├── admin/         # Admin panel (users, invitations, settings)
│   ├── auth/          # Login, unlock, PIN setup, server selection, recovery
│   ├── files/         # File browser and file operations UI
│   ├── links/         # Public link management
│   ├── notes/         # Markdown notes and the editor
│   ├── preview/       # File preview (images, video, PDF, text)
│   ├── search/        # Tokenized search UI
│   └── shares/        # Account-to-account sharing and share groups
├── l10n/              # ARB translation sources (en, fr, de, hr)
└── src/rust/          # Auto-generated FFI bindings (DO NOT EDIT)
rust/
├── src/api.rs         # Rust FFI functions
├── Cargo.toml         # Rust dependencies
└── .cargo/config.toml # Local path patches for hoodik crates
```

---

## State Management (Riverpod)

All providers are centralized in `lib/core/providers.dart`. Key providers:

| Provider | Type | Purpose |
|----------|------|---------|
| `databaseProvider` | `Provider<AppDatabase>` | Drift database singleton |
| `activeAccountProvider` | `StateProvider<Account?>` | Currently active account |
| `decryptedPrivateKeyProvider` | `StateProvider<Uint8List?>` | In-memory private key (never written to disk in plaintext) |
| `apiClientProvider` | `Provider<ApiClient>` | Dio HTTP client for active account |
| `fileOperationsProvider` | `Provider<FileOperations>` | File upload/download/preview |
| `workerManagerProvider` | `Provider<WorkerManager>` | Isolate management |
| `offlineManagerProvider` | `Provider<OfflineManager>` | Encrypted offline cache |
| `syncServiceProvider` | `Provider<SyncService>` | Directory sync + pending uploads |
| `connectivityProvider` | `ChangeNotifierProvider<ConnectivityService>` | Online/offline detection |
| `transferManagerProvider` | `Provider<TransferManager>` | Transfer progress tracking |

Screen-local state uses `ConsumerStatefulWidget` + `setState`.

---

## Routing (GoRouter)

Defined in `lib/router.dart`. Key patterns:

- `context.go()` -- replaces the navigation stack (auth transitions: login -> home, logout -> server selection)
- `context.push()` -- preserves the stack (settings, detail views, anything with a back button)
- Auth guard: redirects to login if not authenticated
- ShellRoute with bottom navigation (Files, Notes, Search, Share, Account tabs)
- Admin routes outside ShellRoute with `rootNavigatorKey`

---

## Worker Isolates

Three background isolates handle heavy work off the main thread:

| Worker | File | Purpose |
|--------|------|---------|
| Upload Worker | `upload_worker.dart` | Chunked encrypted upload via Rust FFI |
| Download Worker | `download_worker.dart` | Concurrent encrypted download via Rust FFI |
| Decrypt Worker | `decrypt_worker.dart` | Batch file name decryption |

The `WorkerManager` (`worker_manager.dart`) spawns all three isolates at startup and provides a main-thread fallback if an isolate is not available. Communication uses typed `WorkerCommand`/`WorkerResponse` messages defined in `worker_messages.dart`.

Progress is tracked via atomic counters polled from the Rust FFI layer (200ms intervals), surfaced through `TransferManager` -> `TransferOverlay` UI widget.

---

## Rust FFI Bridge

The app uses `flutter_rust_bridge` v2.11.1 to call into the same Rust crates used by the web frontend (WASM):

- **`cryptfns`** -- Ed25519, hybrid X25519 + ML-KEM-768 wrapping, RSA-2048 (legacy), AEGIS-128L/AEGIS-256, Ascon-128a, ChaCha20-Poly1305, OPAQUE, BERT tokenizer, hashing
- **`transfer`** -- Chunked upload/download with concurrent I/O, encryption, checksums

FFI functions are defined in `rust/src/api.rs`. Dart bindings are auto-generated in `lib/src/rust/`.

**Path dependency:** The Rust crate depends on the main hoodik repo via local path patches in `rust/.cargo/config.toml`:

```toml
[patch."https://github.com/hudikhq/hoodik"]
transfer = { path = "../../hoodik/transfer" }
cryptfns = { path = "../../hoodik/cryptfns" }
```

The main hoodik repo must be checked out at `../../hoodik/` relative to the `rust/` directory.

**Codegen:** After modifying `rust/src/api.rs`, run:

```shell
flutter_rust_bridge_codegen generate
```

Known issue: codegen sometimes sets `stem: 'UNKNOWN'` in `lib/src/rust/frb_generated.dart` -- fix it manually to `'hoodik_mobile'`.

---

## Platform-Adaptive UI

Every screen uses the adaptive widget library at `lib/core/widgets/adaptive.dart`. Never use raw Material or Cupertino widgets when an adaptive equivalent exists:

| Instead of | Use |
|------------|-----|
| `Scaffold` / `CupertinoPageScaffold` | `AdaptiveScaffold` |
| `ElevatedButton` / `CupertinoButton.filled` | `AdaptiveButton` |
| `TextButton` / `CupertinoButton` | `AdaptiveTextButton` |
| `TextField` / `CupertinoTextField` | `AdaptiveTextField` |
| `AlertDialog` / `CupertinoAlertDialog` | `showAdaptiveAlert()` |
| `ListTile` / `CupertinoListTile` | `AdaptiveListTile` |
| `Card(Column(...))` / `CupertinoListSection` | `AdaptiveListSection` |
| `CircularProgressIndicator` / `CupertinoActivityIndicator` | `AdaptiveLoadingIndicator` |

Platform detection: `isApplePlatform` (from `dart:io Platform.isIOS || Platform.isMacOS`).

---

## UI Conventions

- Icon sizes: 18-28px (never 40px+ on functional screens)
- Horizontal padding: 24px for screen content, 16px for list items within cards
- Colors: always use `theme.colorScheme.*`, never hardcode
- Fonts: system font on Apple, Inter on everything else (handled by `HoodikTheme`)
- AppBar: `centerTitle: isApplePlatform`
- Grouped lists: `AdaptiveListSection(header: 'SECTION NAME')` with UPPERCASE headers
- Safe areas: always wrap scrollable content in `SafeArea`
- Haptic feedback: `.selectionClick()` on tab switches, `.lightImpact()` on success, `.heavyImpact()` on failure

---

## Local Database (Drift SQLite)

Schema in `lib/core/storage/database.dart` (schema version 5):

| Table | Purpose |
|-------|---------|
| `Servers` | Saved server URLs |
| `Accounts` | User accounts (multi-server, multi-account) |
| `CachedFiles` | Directory listing cache for offline browsing |
| `OfflineFiles` | Encrypted file blobs cached on disk |
| `PendingUploads` | Upload queue for offline-queued files |

---

## Security Model

End-to-end encryption is the core value proposition. The server never has access to plaintext data.

### Private key handling

- The user's private key (Ed25519 identity + X25519/ML-KEM-768 wrapping keys; RSA-2048 on legacy accounts) is decrypted in memory only (`decryptedPrivateKeyProvider`). It is never written to disk in plaintext.
- PIN encryption uses Ascon-128a with the PIN padded to 32 bytes. The encrypted key is stored in the local SQLite database.
- On logout, the in-memory private key is cleared immediately.

### Cryptographic primitives (via Rust FFI)

| Primitive | Algorithm |
|-----------|-----------|
| Identity / signing | Ed25519 (legacy accounts: RSA-2048 PKCS#1) |
| Key wrapping | hybrid X25519 + ML-KEM-768, post-quantum (legacy accounts: RSA-2048) |
| Symmetric (default) | AEGIS-128L (hardware-accelerated AEAD) |
| Symmetric (supported) | AEGIS-256, Ascon-128a, ChaCha20-Poly1305 |
| Login | OPAQUE (RFC 9807, ristretto255-SHA512), Argon2id KSF |
| Key derivation | SHA-2, Blake2b |
| Search tokenization | BERT-base-cased -> SHA256 |
| Integrity | CRC16 (chunk upload), MD5, SHA1, SHA256, BLAKE2b (file hashes) |

### Search is privacy-preserving

File names are tokenized with a BERT tokenizer, hashed with SHA256, and only hashes are sent to the server. Plaintext search terms never leave the client.

---

## Key Design Decisions

1. **Reuse Rust, don't reimplement in Dart.** Always check `cryptfns` and `transfer` crates first. Add new functionality to shared Rust crates so all clients benefit.
2. **Small, focused files.** If a screen file grows past ~300 lines, extract widgets to a `widgets/` subdirectory.
3. **Feature-based organization.** `lib/features/{feature}/screens/` and `lib/features/{feature}/widgets/`.
4. **Heavy work off main thread.** Crypto and file I/O run in isolates with main-thread fallback.
5. **Every screen must have an escape route.** No dead-ends. User must always be able to go back.
6. **Don't over-engineer.** Three similar lines of code is better than a premature abstraction.

---

## Key Files Reference

### Core Infrastructure

| What | Path |
|------|------|
| App entry | `lib/main.dart` |
| Routing | `lib/router.dart` |
| Providers | `lib/core/providers.dart` |
| Database | `lib/core/storage/database.dart` |
| Adaptive widgets | `lib/core/widgets/adaptive.dart` |
| Theme | `lib/core/theme/hoodik_theme.dart` |

### API & Auth

| What | Path |
|------|------|
| API client | `lib/core/api/api_client.dart` |
| Auth service | `lib/core/auth/auth_service.dart` |

### Crypto

| What | Path |
|------|------|
| Crypto service | `lib/core/crypto/crypto_service.dart` |
| File crypto | `lib/core/crypto/file_crypto.dart` |
| Hex utilities | `lib/core/utils/hex.dart` |

### Services

| What | Path |
|------|------|
| File operations | `lib/core/services/file_operations.dart` |
| Transfer manager | `lib/core/services/transfer_manager.dart` |
| Offline manager | `lib/core/services/offline_manager.dart` |
| Sync service | `lib/core/services/sync_service.dart` |
| Connectivity service | `lib/core/services/connectivity_service.dart` |
| Share handler | `lib/core/services/share_handler.dart` |
| Thumbnail generator | `lib/core/services/thumbnail_generator.dart` |

### Workers

| What | Path |
|------|------|
| Worker manager | `lib/core/workers/worker_manager.dart` |
| Upload worker | `lib/core/workers/upload_worker.dart` |
| Download worker | `lib/core/workers/download_worker.dart` |
| Decrypt worker | `lib/core/workers/decrypt_worker.dart` |
| Worker messages | `lib/core/workers/worker_messages.dart` |

### Feature Screens

| What | Path |
|------|------|
| Files screen | `lib/features/files/screens/files_screen.dart` |
| Links screen | `lib/features/links/screens/links_screen.dart` |
| Account screen | `lib/features/account/screens/account_screen.dart` |
| Login screen | `lib/features/auth/screens/login_screen.dart` |
| Unlock screen | `lib/features/auth/screens/unlock_screen.dart` |
| Admin panel | `lib/features/admin/screens/admin_panel_screen.dart` |
| Preview screen | `lib/features/preview/screens/preview_screen.dart` |

### Preview System

| What | Path |
|------|------|
| Preview loader | `lib/features/preview/providers/preview_loader.dart` |
| Preview providers | `lib/features/preview/providers/preview_providers.dart` |
| Preview cache | `lib/features/preview/providers/preview_cache.dart` |
| Offline preview helpers | `lib/features/preview/providers/offline_preview_helpers.dart` |
| Image preview | `lib/features/preview/widgets/preview_image.dart` |
| Video preview | `lib/features/preview/widgets/preview_video.dart` |
| PDF preview | `lib/features/preview/widgets/preview_pdf.dart` |
| Text preview | `lib/features/preview/widgets/preview_text.dart` |

Preview downloads use the same `downloadAndPinOffline` pipeline as "Make Available Offline". Chunks are cached in the offline store so subsequent previews load from disk. Progress is tracked via `TransferManager` — preview widgets watch `transferManagerProvider` for active transfers matching their file ID.

### Rust FFI

| What | Path |
|------|------|
| Rust FFI source | `rust/src/api.rs` |
| Rust config | `rust/Cargo.toml` |
| Path patches | `rust/.cargo/config.toml` |
| Generated FFI | `lib/src/rust/` (do not edit, except stem fix) |
