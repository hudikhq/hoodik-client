import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/theme/hoodik_scheme.dart';
import '../../../l10n/generated/app_localizations.dart';

class PreviewPreloadTile extends ConsumerWidget {
  const PreviewPreloadTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final enabled = ref.watch(previewPreloadProvider);

    void toggle() => ref.read(previewPreloadProvider.notifier).set(!enabled);

    return AdaptiveListTile(
      leading: Icon(
        AppIcons.preview,
        size: 22,
        color: context.colors.iconEmber,
      ),
      title: Text(l10n.accountPreviewPreloadTitle),
      subtitle: Text(l10n.accountPreviewPreloadSubtitle),
      trailing: CupertinoSwitch(value: enabled, onChanged: (_) => toggle()),
      onTap: toggle,
    );
  }
}
