import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/adaptive.dart';
import '../../../l10n/generated/app_localizations.dart';

class LegalSection extends StatelessWidget {
  const LegalSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AdaptiveListSection(
      header: l10n.accountLegalHeader,
      children: [
        AdaptiveListTile(
          leading: Icon(
            isApplePlatform
                ? CupertinoIcons.doc_text
                : Icons.privacy_tip_outlined,
            size: 22,
          ),
          title: Text(l10n.accountPrivacyPolicy),
          onTap: () => launchUrl(
            Uri.parse('https://hoodik.io/privacy-policy'),
            mode: LaunchMode.externalApplication,
          ),
        ),
        AdaptiveListTile(
          leading: Icon(
            isApplePlatform
                ? CupertinoIcons.doc_plaintext
                : Icons.description_outlined,
            size: 22,
          ),
          title: Text(l10n.accountTermsOfService),
          onTap: () => launchUrl(
            Uri.parse('https://hoodik.io/terms-of-service'),
            mode: LaunchMode.externalApplication,
          ),
        ),
        AdaptiveListTile(
          leading: Icon(
            isApplePlatform ? CupertinoIcons.book : Icons.balance_outlined,
            size: 22,
          ),
          title: Text(l10n.accountOpenSourceLicenses),
          onTap: () =>
              showLicensePage(context: context, applicationName: 'Hoodik'),
        ),
      ],
    );
  }
}
