import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/services/preferences.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/theme/hoodik_scheme.dart';

/// Lets the user pick which bottom-nav tab is active when the app cold-starts
/// while logged in. Writes through to the persisted preference so the next
/// launch lands on the chosen tab.
class LandingBranchTile extends ConsumerWidget {
  const LandingBranchTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final selected = ref.watch(landingBranchProvider);

    return AdaptiveListTile(
      leading: Icon(
        isApplePlatform
            ? CupertinoIcons.square_stack_3d_down_right
            : Icons.home_outlined,
        size: 22,
        color: context.colors.iconEmber,
      ),
      title: Text(l10n.accountDefaultLanding),
      subtitle: Text(l10n.accountDefaultLandingSubtitle),
      trailing: Text(
        selected.label,
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
    LandingBranch current,
  ) async {
    final picked = await showDialog<LandingBranch>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(AppLocalizations.of(ctx).accountDefaultLanding),
        children: LandingBranch.values.map((branch) {
          final isCurrent = branch == current;
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, branch),
            child: Row(
              children: [
                Expanded(child: Text(branch.label)),
                if (isCurrent)
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
      ),
    );
    if (picked != null && picked != current) {
      await ref.read(landingBranchProvider.notifier).set(picked);
    }
  }
}
