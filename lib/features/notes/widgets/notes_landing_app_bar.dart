import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../l10n/generated/app_localizations.dart';

/// The mobile notes bar shown while no note is open.
///
/// Creating a note is an app-bar action rather than a floating button: iOS
/// has no FAB, and a button hovering over the last row of the recent-notes
/// list covers the thing the user is reaching for. Desktop never sees this —
/// the sidebar is always visible there and carries its own create control.
class NotesLandingAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const NotesLandingAppBar({super.key, required this.onCreateNote});

  final VoidCallback onCreateNote;

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppBar(
      // Leave `leading` null so Scaffold auto-adds the hamburger for the
      // drawer. Users can also swipe from the left edge.
      title: Text(l10n.notesTitle),
      actions: [
        IconButton(
          icon: Icon(isApplePlatform ? CupertinoIcons.add : AppIcons.add),
          tooltip: l10n.notesNewNote,
          onPressed: onCreateNote,
        ),
      ],
    );
  }
}
