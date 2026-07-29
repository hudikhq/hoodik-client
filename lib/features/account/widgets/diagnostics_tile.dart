import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/adaptive.dart';
import '../../../l10n/generated/app_localizations.dart';

class DiagnosticsTile extends StatelessWidget {
  const DiagnosticsTile({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return AdaptiveListTile(
      leading: Icon(
        isApplePlatform
            ? CupertinoIcons.doc_text_search
            : Icons.bug_report_outlined,
        size: 22,
        color: theme.colorScheme.secondary,
      ),
      title: Text(l10n.accountDiagnosticsTitle),
      subtitle: Text(l10n.accountDiagnosticsSubtitle),
      onTap: () => context.push('/account/diagnostics'),
    );
  }
}
