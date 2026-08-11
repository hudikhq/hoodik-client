import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'adaptive.dart';

/// The app's icon vocabulary, named by what a control *does* rather than by
/// which set the glyph came from.
///
/// Each entry resolves to a Material glyph on Android and an SF-Symbol-shaped
/// Cupertino one on iOS and macOS. Reaching for `Icons.delete_outline`
/// directly ships Android's glyph to an iPhone, which is the most common
/// native tell there is — the same failure mode the color steps solved for
/// text, in a different medium.
///
/// Not every icon belongs here. A glyph used once, in one screen, with no
/// Cupertino equivalent worth the indirection, stays a literal; this class
/// covers the vocabulary the app actually repeats.
class AppIcons {
  AppIcons._();

  static IconData _pick({
    required IconData material,
    required IconData cupertino,
  }) => isApplePlatform ? cupertino : material;

  // Structure and navigation
  static IconData get back =>
      _pick(material: Icons.arrow_back, cupertino: CupertinoIcons.back);
  static IconData get close =>
      _pick(material: Icons.close, cupertino: CupertinoIcons.xmark);
  static IconData get chevronForward => _pick(
    material: Icons.chevron_right,
    cupertino: CupertinoIcons.chevron_forward,
  );
  static IconData get expand => _pick(
    material: Icons.expand_more,
    cupertino: CupertinoIcons.chevron_down,
  );
  static IconData get overflowVertical => _pick(
    material: Icons.more_vert,
    cupertino: CupertinoIcons.ellipsis_vertical,
  );
  static IconData get overflowHorizontal =>
      _pick(material: Icons.more_horiz, cupertino: CupertinoIcons.ellipsis);
  static IconData get search =>
      _pick(material: Icons.search, cupertino: CupertinoIcons.search);
  static IconData get refresh =>
      _pick(material: Icons.refresh, cupertino: CupertinoIcons.arrow_clockwise);
  static IconData get settings =>
      _pick(material: Icons.settings_outlined, cupertino: CupertinoIcons.gear);

  // Status and feedback
  static IconData get error => _pick(
    material: Icons.error_outline,
    cupertino: CupertinoIcons.exclamationmark_circle,
  );
  static IconData get info => _pick(
    material: Icons.info_outline,
    cupertino: CupertinoIcons.info_circle,
  );
  static IconData get success => _pick(
    material: Icons.check_circle,
    cupertino: CupertinoIcons.checkmark_circle,
  );
  static IconData get check =>
      _pick(material: Icons.check, cupertino: CupertinoIcons.checkmark);
  static IconData get schedule =>
      _pick(material: Icons.schedule, cupertino: CupertinoIcons.clock);
  static IconData get history =>
      _pick(material: Icons.history, cupertino: CupertinoIcons.clock);

  // Content
  static IconData get folder =>
      _pick(material: Icons.folder, cupertino: CupertinoIcons.folder);
  static IconData get folderOpen =>
      _pick(material: Icons.folder_open, cupertino: CupertinoIcons.folder_open);
  static IconData get note => _pick(
    material: Icons.sticky_note_2_outlined,
    cupertino: CupertinoIcons.doc_text,
  );
  static IconData get noteEdit =>
      _pick(material: Icons.edit_note, cupertino: CupertinoIcons.square_pencil);
  static IconData get link =>
      _pick(material: Icons.link, cupertino: CupertinoIcons.link);
  static IconData get storage =>
      _pick(material: Icons.storage, cupertino: CupertinoIcons.tray_full);

  // Verbs
  static IconData get add =>
      _pick(material: Icons.add, cupertino: CupertinoIcons.add);
  static IconData get edit =>
      _pick(material: Icons.edit, cupertino: CupertinoIcons.pencil);
  static IconData get delete =>
      _pick(material: Icons.delete_outline, cupertino: CupertinoIcons.trash);
  static IconData get copy =>
      _pick(material: Icons.copy, cupertino: CupertinoIcons.doc_on_doc);
  static IconData get share =>
      _pick(material: Icons.share, cupertino: CupertinoIcons.share);
  static IconData get download => _pick(
    material: Icons.save_alt,
    cupertino: CupertinoIcons.arrow_down_to_line,
  );
  static IconData get move => _pick(
    material: Icons.drive_file_move_outline,
    cupertino: CupertinoIcons.folder_badge_plus,
  );
  static IconData get preview =>
      _pick(material: Icons.visibility, cupertino: CupertinoIcons.eye);
  static IconData get signOut => _pick(
    material: Icons.logout,
    cupertino: CupertinoIcons.square_arrow_right,
  );

  // Sharing and identity
  static IconData get members =>
      _pick(material: Icons.group_outlined, cupertino: CupertinoIcons.person_2);
  static IconData get memberAdd => _pick(
    material: Icons.group_add_outlined,
    cupertino: CupertinoIcons.person_add,
  );
  static IconData get memberRemove => _pick(
    material: Icons.person_remove_outlined,
    cupertino: CupertinoIcons.person_badge_minus,
  );
  static IconData get locked =>
      _pick(material: Icons.lock_outline, cupertino: CupertinoIcons.lock);
  static IconData get unlocked =>
      _pick(material: Icons.lock_open, cupertino: CupertinoIcons.lock_open);
  static IconData get verified => _pick(
    material: Icons.verified_user_outlined,
    cupertino: CupertinoIcons.checkmark_seal,
  );

  // Transfer and offline
  static IconData get offlineAvailable => _pick(
    material: Icons.offline_pin,
    cupertino: CupertinoIcons.checkmark_seal,
  );
  static IconData get cloudDownload => _pick(
    material: Icons.cloud_download,
    cupertino: CupertinoIcons.cloud_download,
  );
  static IconData get cloudUpload => _pick(
    material: Icons.upload_file,
    cupertino: CupertinoIcons.cloud_upload,
  );

  // Sorting
  static IconData get sortAscending =>
      _pick(material: Icons.arrow_upward, cupertino: CupertinoIcons.arrow_up);
  static IconData get sortDescending => _pick(
    material: Icons.arrow_downward,
    cupertino: CupertinoIcons.arrow_down,
  );
}
