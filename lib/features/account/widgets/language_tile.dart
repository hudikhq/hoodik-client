import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/widgets/app_icons.dart';

/// Lets the user override the app display language. Options are shown in
/// their own language so a user stuck in the wrong one can still find theirs.
class LanguageTile extends ConsumerWidget {
  const LanguageTile({super.key});

  static const _names = {
    'en': 'English',
    'fr': 'Français',
    'de': 'Deutsch',
    'hr': 'Hrvatski',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final selected = ref.watch(appLocaleProvider);

    return AdaptiveListTile(
      leading: Icon(
        isApplePlatform ? CupertinoIcons.globe : Icons.language_outlined,
        size: 22,
        color: theme.colorScheme.secondary,
      ),
      title: Text(l10n.languageTitle),
      subtitle: Text(l10n.languageSubtitle),
      trailing: Text(
        selected == null
            ? l10n.languageSystem
            : _names[selected.languageCode] ?? selected.languageCode,
        style: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
      onTap: () => _pick(context, ref, selected),
    );
  }

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    Locale? current,
  ) async {
    final l10n = AppLocalizations.of(context);

    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.languageTitle),
        children: [
          _option(ctx, l10n.languageSystem, 'system', current == null),
          for (final code in AppLocaleNotifier.supported)
            _option(ctx, _names[code]!, code, current?.languageCode == code),
        ],
      ),
    );

    if (picked == null) return;
    await ref
        .read(appLocaleProvider.notifier)
        .set(picked == 'system' ? null : Locale(picked));
  }

  Widget _option(BuildContext ctx, String label, String value, bool isCurrent) {
    return SimpleDialogOption(
      onPressed: () => Navigator.pop(ctx, value),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          if (isCurrent)
            Icon(
              isApplePlatform ? CupertinoIcons.checkmark_alt : AppIcons.check,
              size: 18,
            ),
        ],
      ),
    );
  }
}
