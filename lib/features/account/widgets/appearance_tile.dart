import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/theme/hoodik_scheme.dart';

/// Lets the user pin the app to light or dark instead of following the OS.
class AppearanceTile extends ConsumerWidget {
  const AppearanceTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final selected = ref.watch(appThemeModeProvider);

    return AdaptiveListTile(
      leading: Icon(_icon(selected), size: 22, color: context.colors.iconEmber),
      title: Text(l10n.accountAppearance),
      subtitle: Text(l10n.accountAppearanceSubtitle),
      trailing: Text(
        _label(l10n, selected),
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
    ThemeMode current,
  ) async {
    final picked = await showDialog<ThemeMode>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return SimpleDialog(
          title: Text(l10n.accountAppearance),
          children: ThemeMode.values.map((mode) {
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, mode),
              child: Row(
                children: [
                  Icon(_icon(mode), size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_label(l10n, mode))),
                  if (mode == current)
                    Icon(
                      isApplePlatform
                          ? CupertinoIcons.checkmark_alt
                          : AppIcons.check,
                      size: 18,
                    ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
    if (picked != null) {
      await ref.read(appThemeModeProvider.notifier).set(picked);
    }
  }

  String _label(AppLocalizations l10n, ThemeMode mode) => switch (mode) {
    ThemeMode.system => l10n.serviceThemeModeSystem,
    ThemeMode.light => l10n.serviceThemeModeLight,
    ThemeMode.dark => l10n.serviceThemeModeDark,
  };

  IconData _icon(ThemeMode mode) => switch (mode) {
    ThemeMode.system =>
      isApplePlatform
          ? CupertinoIcons.circle_lefthalf_fill
          : Icons.brightness_auto_outlined,
    ThemeMode.light =>
      isApplePlatform ? CupertinoIcons.sun_max : Icons.light_mode_outlined,
    ThemeMode.dark =>
      isApplePlatform ? CupertinoIcons.moon : Icons.dark_mode_outlined,
  };
}
