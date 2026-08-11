import 'package:flutter/material.dart';

import '../../../core/theme/hoodik_colors.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Full-screen tint + icon shown while a desktop drag is hovering
/// over the files screen, so users know the drop will be accepted.
class FilesDropOverlay extends StatelessWidget {
  const FilesDropOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: HoodikColors.blueish400.withValues(alpha: 0.15),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_upload_outlined,
              size: 56,
              color: HoodikColors.blueish300.withValues(alpha: 0.9),
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context).filesDropToUpload,
              style: TextStyle(
                color: HoodikColors.dirtyWhite,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
