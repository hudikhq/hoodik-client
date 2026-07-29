# Third-party software

Hoodik App is distributed under [CC BY-NC 4.0](./LICENSE.md). It includes
third-party software under its own terms, listed here.

Dart and Flutter dependencies declare their licenses in `pubspec.yaml` /
`pubspec.lock`, and Flutter collects them automatically — the full text of every
one is in the app under **Account → Open source licenses**.

This file covers what that automatic collection cannot see.

## Bundled into `assets/editor/editor.html`

The markdown editor is a pre-built single-file bundle, so its dependencies are
not Dart packages and do not appear in `pubspec.lock`. The bundle is produced
from [`editor/`](https://github.com/hudikhq/hoodik/tree/master/editor) in the
`hoodik` repository (`scripts/copy-editor.sh` copies the build output here), and
the minifier does not preserve license banners — hence this list. The same
notices are registered with Flutter's license registry in
[`lib/core/utils/bundled_licenses.dart`](lib/core/utils/bundled_licenses.dart)
so they ship inside the app binary as well as in this repository.

| Library | License |
|---------|---------|
| [Milkdown](https://milkdown.dev) | MIT |
| [ProseMirror](https://prosemirror.net) | MIT |
| [refractor](https://github.com/wooorm/refractor) | MIT |
| [DOMPurify](https://github.com/cure53/DOMPurify) | Apache-2.0 (see below) |

DOMPurify is offered under `MPL-2.0 OR Apache-2.0`. This distribution takes it
under **Apache-2.0**.

## Vendored build tooling

| Component | License |
|-----------|---------|
| [`rust_builder/cargokit`](rust_builder/cargokit) | MIT — see `rust_builder/cargokit/LICENSE` |

## Rust crates

The Rust FFI layer depends on `cryptfns` and `transfer` from the
[hoodik](https://github.com/hudikhq/hoodik) repository, plus their transitive
crates. Run `cargo license` (or `cargo tree`) in `rust/` for the resolved set;
`rust/Cargo.lock` pins exact versions.

## Reporting a problem with this list

If something is missing, misattributed, or licensed differently than stated,
open an issue or email `hello@hudik.eu` and it will be corrected.
