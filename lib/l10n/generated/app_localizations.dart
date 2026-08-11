import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('fr'),
    Locale('hr'),
  ];

  /// No description provided for @accountActiveTransfers.
  ///
  /// In en, this message translates to:
  /// **'Active transfers in progress'**
  String get accountActiveTransfers;

  /// No description provided for @accountAdminHeader.
  ///
  /// In en, this message translates to:
  /// **'ADMINISTRATION'**
  String get accountAdminHeader;

  /// No description provided for @accountAdminPanel.
  ///
  /// In en, this message translates to:
  /// **'Admin Panel'**
  String get accountAdminPanel;

  /// No description provided for @accountAdminPanelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Users, invitations & settings'**
  String get accountAdminPanelSubtitle;

  /// No description provided for @accountAiAccessMacosOnly.
  ///
  /// In en, this message translates to:
  /// **'AI Access via MCP is available on the macOS version of Hoodik.'**
  String get accountAiAccessMacosOnly;

  /// No description provided for @accountAiAccessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'MCP server for AI agents'**
  String get accountAiAccessSubtitle;

  /// No description provided for @accountAiAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Access'**
  String get accountAiAccessTitle;

  /// No description provided for @accountAllAccountsHeader.
  ///
  /// In en, this message translates to:
  /// **'ALL ACCOUNTS'**
  String get accountAllAccountsHeader;

  /// No description provided for @accountAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get accountAppearance;

  /// No description provided for @accountAppearanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Light, dark, or follow the system'**
  String get accountAppearanceSubtitle;

  /// No description provided for @accountAuditAllStatuses.
  ///
  /// In en, this message translates to:
  /// **'All statuses'**
  String get accountAuditAllStatuses;

  /// No description provided for @accountAuditAllTools.
  ///
  /// In en, this message translates to:
  /// **'All tools'**
  String get accountAuditAllTools;

  /// No description provided for @accountAuditClearConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently removes every recorded tool invocation. Your files are not affected.'**
  String get accountAuditClearConfirmBody;

  /// No description provided for @accountAuditClearConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear audit log?'**
  String get accountAuditClearConfirmTitle;

  /// No description provided for @accountAuditClearLog.
  ///
  /// In en, this message translates to:
  /// **'Clear log'**
  String get accountAuditClearLog;

  /// No description provided for @accountAuditCleared.
  ///
  /// In en, this message translates to:
  /// **'Audit log cleared'**
  String get accountAuditCleared;

  /// No description provided for @accountAuditDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get accountAuditDuration;

  /// No description provided for @accountAuditEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Every AI tool call is recorded here. Enable AI Access and connect an agent to see activity.'**
  String get accountAuditEmptyBody;

  /// No description provided for @accountAuditEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No audit entries yet'**
  String get accountAuditEmptyTitle;

  /// No description provided for @accountAuditError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get accountAuditError;

  /// No description provided for @accountAuditFilterByStatus.
  ///
  /// In en, this message translates to:
  /// **'Filter by status'**
  String get accountAuditFilterByStatus;

  /// No description provided for @accountAuditFilterByTool.
  ///
  /// In en, this message translates to:
  /// **'Filter by tool'**
  String get accountAuditFilterByTool;

  /// No description provided for @accountAuditLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load: {error}'**
  String accountAuditLoadFailed(String error);

  /// No description provided for @accountAuditLogTitle.
  ///
  /// In en, this message translates to:
  /// **'Audit Log'**
  String get accountAuditLogTitle;

  /// No description provided for @accountAuditMilliseconds.
  ///
  /// In en, this message translates to:
  /// **'{ms} ms'**
  String accountAuditMilliseconds(int ms);

  /// No description provided for @accountAuditNoParams.
  ///
  /// In en, this message translates to:
  /// **'(no params)'**
  String get accountAuditNoParams;

  /// No description provided for @accountAuditParamsHash.
  ///
  /// In en, this message translates to:
  /// **'Params hash'**
  String get accountAuditParamsHash;

  /// No description provided for @accountAuditSession.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get accountAuditSession;

  /// No description provided for @accountAuditStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get accountAuditStatus;

  /// No description provided for @accountAuditStatusDenied.
  ///
  /// In en, this message translates to:
  /// **'Denied'**
  String get accountAuditStatusDenied;

  /// No description provided for @accountAuditStatusOk.
  ///
  /// In en, this message translates to:
  /// **'Ok'**
  String get accountAuditStatusOk;

  /// No description provided for @accountAuditTimestamp.
  ///
  /// In en, this message translates to:
  /// **'Timestamp'**
  String get accountAuditTimestamp;

  /// No description provided for @accountClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get accountClear;

  /// No description provided for @accountDefaultLanding.
  ///
  /// In en, this message translates to:
  /// **'Default landing'**
  String get accountDefaultLanding;

  /// No description provided for @accountDefaultLandingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The tab shown when the app opens'**
  String get accountDefaultLandingSubtitle;

  /// No description provided for @accountDiagnosticsExportLogs.
  ///
  /// In en, this message translates to:
  /// **'Export Logs'**
  String get accountDiagnosticsExportLogs;

  /// No description provided for @accountDiagnosticsLogsInfo.
  ///
  /// In en, this message translates to:
  /// **'Logs may contain filenames and server URLs so you can recognise what each line refers to. They never contain file contents, passwords, or encryption keys. You’ll see every line and can remove anything before sending.'**
  String get accountDiagnosticsLogsInfo;

  /// No description provided for @accountDiagnosticsNoTelemetryBody.
  ///
  /// In en, this message translates to:
  /// **'Hoodik doesn’t use Sentry, crash reporters, or any third-party analytics. The only data that leaves your device is what’s needed for encrypted file sync.'**
  String get accountDiagnosticsNoTelemetryBody;

  /// No description provided for @accountDiagnosticsNoTracking.
  ///
  /// In en, this message translates to:
  /// **'We don’t track anything about your device.'**
  String get accountDiagnosticsNoTracking;

  /// No description provided for @accountDiagnosticsStep1.
  ///
  /// In en, this message translates to:
  /// **'Close Hoodik completely.'**
  String get accountDiagnosticsStep1;

  /// No description provided for @accountDiagnosticsStep2.
  ///
  /// In en, this message translates to:
  /// **'Open it again.'**
  String get accountDiagnosticsStep2;

  /// No description provided for @accountDiagnosticsStep3.
  ///
  /// In en, this message translates to:
  /// **'Try to reproduce the bug.'**
  String get accountDiagnosticsStep3;

  /// No description provided for @accountDiagnosticsStep4.
  ///
  /// In en, this message translates to:
  /// **'Come back here and tap Export Logs below.'**
  String get accountDiagnosticsStep4;

  /// No description provided for @accountDiagnosticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send a bug report — no telemetry'**
  String get accountDiagnosticsSubtitle;

  /// No description provided for @accountDiagnosticsTellUsBody.
  ///
  /// In en, this message translates to:
  /// **'This means when something breaks, we don’t know about it unless you tell us. Here’s the most useful way to do that:'**
  String get accountDiagnosticsTellUsBody;

  /// No description provided for @accountDiagnosticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Diagnostics'**
  String get accountDiagnosticsTitle;

  /// No description provided for @accountDisable.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get accountDisable;

  /// No description provided for @accountEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get accountEnable;

  /// No description provided for @accountEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get accountEnabled;

  /// No description provided for @accountEnterPinBody.
  ///
  /// In en, this message translates to:
  /// **'Enter your PIN to enable biometric unlock.'**
  String get accountEnterPinBody;

  /// No description provided for @accountEnterPinTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter PIN'**
  String get accountEnterPinTitle;

  /// No description provided for @accountIncorrectPin.
  ///
  /// In en, this message translates to:
  /// **'Incorrect PIN'**
  String get accountIncorrectPin;

  /// No description provided for @accountLegalHeader.
  ///
  /// In en, this message translates to:
  /// **'LEGAL'**
  String get accountLegalHeader;

  /// No description provided for @accountLogsClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get accountLogsClearAll;

  /// No description provided for @accountLogsCopied.
  ///
  /// In en, this message translates to:
  /// **'Logs copied to clipboard'**
  String get accountLogsCopied;

  /// No description provided for @accountLogsCopyToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy to Clipboard'**
  String get accountLogsCopyToClipboard;

  /// No description provided for @accountLogsCurrentSession.
  ///
  /// In en, this message translates to:
  /// **'Current session'**
  String get accountLogsCurrentSession;

  /// No description provided for @accountLogsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Close the app, reopen it, reproduce the bug, then come back and try again.'**
  String get accountLogsEmptyBody;

  /// No description provided for @accountLogsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No log lines to review.'**
  String get accountLogsEmptyTitle;

  /// No description provided for @accountLogsLineCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 line} other{{count} lines}}'**
  String accountLogsLineCount(int count);

  /// No description provided for @accountLogsPastDays.
  ///
  /// In en, this message translates to:
  /// **'Past 3 days'**
  String get accountLogsPastDays;

  /// No description provided for @accountLogsReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review Logs'**
  String get accountLogsReviewTitle;

  /// No description provided for @accountLogsSendViaEmail.
  ///
  /// In en, this message translates to:
  /// **'Send via Email ({email})'**
  String accountLogsSendViaEmail(String email);

  /// No description provided for @accountLogsShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Sharing failed — try Copy to Clipboard instead'**
  String get accountLogsShareFailed;

  /// No description provided for @accountManageAccounts.
  ///
  /// In en, this message translates to:
  /// **'Manage Accounts'**
  String get accountManageAccounts;

  /// No description provided for @accountManageAccountsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add or switch accounts'**
  String get accountManageAccountsSubtitle;

  /// No description provided for @accountMcpActivityHeader.
  ///
  /// In en, this message translates to:
  /// **'ACTIVITY'**
  String get accountMcpActivityHeader;

  /// No description provided for @accountMcpAllowReadOnlyOff.
  ///
  /// In en, this message translates to:
  /// **'All agent access paused when PIN-locked'**
  String get accountMcpAllowReadOnlyOff;

  /// No description provided for @accountMcpAllowReadOnlyOn.
  ///
  /// In en, this message translates to:
  /// **'Agents may list and search files when PIN-locked'**
  String get accountMcpAllowReadOnlyOn;

  /// No description provided for @accountMcpAllowReadOnlyTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow read-only access while locked'**
  String get accountMcpAllowReadOnlyTitle;

  /// No description provided for @accountMcpBearerToken.
  ///
  /// In en, this message translates to:
  /// **'Bearer Token'**
  String get accountMcpBearerToken;

  /// No description provided for @accountMcpBurstCapacity.
  ///
  /// In en, this message translates to:
  /// **'Burst capacity'**
  String get accountMcpBurstCapacity;

  /// No description provided for @accountMcpClearAuditLog.
  ///
  /// In en, this message translates to:
  /// **'Clear audit log'**
  String get accountMcpClearAuditLog;

  /// No description provided for @accountMcpClearAuditLogSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Removes every recorded tool invocation'**
  String get accountMcpClearAuditLogSubtitle;

  /// No description provided for @accountMcpConfigCopied.
  ///
  /// In en, this message translates to:
  /// **'Config copied to clipboard'**
  String get accountMcpConfigCopied;

  /// No description provided for @accountMcpConfigFootnote.
  ///
  /// In en, this message translates to:
  /// **'Copy this JSON into your Claude Desktop or Claude Code MCP server configuration.'**
  String get accountMcpConfigFootnote;

  /// No description provided for @accountMcpConfigurationHeader.
  ///
  /// In en, this message translates to:
  /// **'CONFIGURATION'**
  String get accountMcpConfigurationHeader;

  /// No description provided for @accountMcpConnectClientSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Guided setup for Claude Desktop, Cursor, and others'**
  String get accountMcpConnectClientSubtitle;

  /// No description provided for @accountMcpConnectClientTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect an AI client'**
  String get accountMcpConnectClientTitle;

  /// No description provided for @accountMcpConnectionHeader.
  ///
  /// In en, this message translates to:
  /// **'CONNECTION'**
  String get accountMcpConnectionHeader;

  /// No description provided for @accountMcpCopyConfig.
  ///
  /// In en, this message translates to:
  /// **'Copy Config'**
  String get accountMcpCopyConfig;

  /// No description provided for @accountMcpDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get accountMcpDisabled;

  /// No description provided for @accountMcpEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable AI Access'**
  String get accountMcpEnable;

  /// No description provided for @accountMcpEnableFootnote.
  ///
  /// In en, this message translates to:
  /// **'When enabled, AI agents like Claude Desktop and Claude Code can access your encrypted files through a local endpoint.'**
  String get accountMcpEnableFootnote;

  /// No description provided for @accountMcpEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Endpoint'**
  String get accountMcpEndpoint;

  /// No description provided for @accountMcpLastAgentCall.
  ///
  /// In en, this message translates to:
  /// **'Last agent call {time}'**
  String accountMcpLastAgentCall(String time);

  /// No description provided for @accountMcpLockedFootnote.
  ///
  /// In en, this message translates to:
  /// **'When the app is locked with a PIN, decrypting file content requires you to unlock. Read-only access exposes only encrypted metadata the server already knows.'**
  String get accountMcpLockedFootnote;

  /// No description provided for @accountMcpNoAgentActivity.
  ///
  /// In en, this message translates to:
  /// **'No agent activity yet'**
  String get accountMcpNoAgentActivity;

  /// No description provided for @accountMcpNotRunning.
  ///
  /// In en, this message translates to:
  /// **'Not running'**
  String get accountMcpNotRunning;

  /// No description provided for @accountMcpOffSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Toggle AI Access to start the local MCP server.'**
  String get accountMcpOffSubtitle;

  /// No description provided for @accountMcpPausedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Port {port} reserved • restart to resume'**
  String accountMcpPausedSubtitle(int port);

  /// No description provided for @accountMcpPerSecondOption.
  ///
  /// In en, this message translates to:
  /// **'{value} / sec'**
  String accountMcpPerSecondOption(int value);

  /// No description provided for @accountMcpPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get accountMcpPort;

  /// No description provided for @accountMcpPortRange.
  ///
  /// In en, this message translates to:
  /// **'Port must be between 1024 and 65535'**
  String get accountMcpPortRange;

  /// No description provided for @accountMcpPortUpdated.
  ///
  /// In en, this message translates to:
  /// **'Port updated to {port}'**
  String accountMcpPortUpdated(int port);

  /// No description provided for @accountMcpQuickActionsHeader.
  ///
  /// In en, this message translates to:
  /// **'QUICK ACTIONS'**
  String get accountMcpQuickActionsHeader;

  /// No description provided for @accountMcpRateLimitFootnote.
  ///
  /// In en, this message translates to:
  /// **'A token bucket throttles each AI session. Burst capacity is how many requests back-to-back are allowed before the bucket starts refilling at the configured rate.'**
  String get accountMcpRateLimitFootnote;

  /// No description provided for @accountMcpRateLimitHeader.
  ///
  /// In en, this message translates to:
  /// **'RATE LIMIT'**
  String get accountMcpRateLimitHeader;

  /// No description provided for @accountMcpRegenerate.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get accountMcpRegenerate;

  /// No description provided for @accountMcpRequestsPerSecond.
  ///
  /// In en, this message translates to:
  /// **'Requests per second'**
  String get accountMcpRequestsPerSecond;

  /// No description provided for @accountMcpRetentionDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String accountMcpRetentionDays(int count);

  /// No description provided for @accountMcpRetentionForever.
  ///
  /// In en, this message translates to:
  /// **'Forever'**
  String get accountMcpRetentionForever;

  /// No description provided for @accountMcpRetentionHeader.
  ///
  /// In en, this message translates to:
  /// **'AUDIT RETENTION'**
  String get accountMcpRetentionHeader;

  /// No description provided for @accountMcpRetentionOneYear.
  ///
  /// In en, this message translates to:
  /// **'1 year'**
  String get accountMcpRetentionOneYear;

  /// No description provided for @accountMcpRetentionTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep entries for'**
  String get accountMcpRetentionTitle;

  /// No description provided for @accountMcpRotateToken.
  ///
  /// In en, this message translates to:
  /// **'Rotate bearer token'**
  String get accountMcpRotateToken;

  /// No description provided for @accountMcpRotateTokenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Invalidates every configured AI client'**
  String get accountMcpRotateTokenSubtitle;

  /// No description provided for @accountMcpRunningOnPort.
  ///
  /// In en, this message translates to:
  /// **'Running on port {port}'**
  String accountMcpRunningOnPort(int port);

  /// No description provided for @accountMcpSecurityHeader.
  ///
  /// In en, this message translates to:
  /// **'SECURITY'**
  String get accountMcpSecurityHeader;

  /// No description provided for @accountMcpServerHeader.
  ///
  /// In en, this message translates to:
  /// **'MCP SERVER'**
  String get accountMcpServerHeader;

  /// No description provided for @accountMcpStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting...'**
  String get accountMcpStarting;

  /// No description provided for @accountMcpStatusOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get accountMcpStatusOff;

  /// No description provided for @accountMcpStatusPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get accountMcpStatusPaused;

  /// No description provided for @accountMcpStatusRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get accountMcpStatusRunning;

  /// No description provided for @accountMcpStopServer.
  ///
  /// In en, this message translates to:
  /// **'Stop server'**
  String get accountMcpStopServer;

  /// No description provided for @accountMcpStopServerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Closes the local MCP port'**
  String get accountMcpStopServerSubtitle;

  /// No description provided for @accountMcpTokenCopied.
  ///
  /// In en, this message translates to:
  /// **'Token copied to clipboard'**
  String get accountMcpTokenCopied;

  /// No description provided for @accountMcpTokenRegenerated.
  ///
  /// In en, this message translates to:
  /// **'Token regenerated'**
  String get accountMcpTokenRegenerated;

  /// No description provided for @accountMcpUnavailable.
  ///
  /// In en, this message translates to:
  /// **'MCP server is unavailable. Log in on macOS to continue.'**
  String get accountMcpUnavailable;

  /// No description provided for @accountMcpViewAuditLog.
  ///
  /// In en, this message translates to:
  /// **'View audit log'**
  String get accountMcpViewAuditLog;

  /// No description provided for @accountMcpViewAuditLogSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review every AI tool call'**
  String get accountMcpViewAuditLogSubtitle;

  /// No description provided for @accountMcpWizardMacosOnly.
  ///
  /// In en, this message translates to:
  /// **'The connect wizard is available in the macOS build of Hoodik.'**
  String get accountMcpWizardMacosOnly;

  /// No description provided for @accountNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get accountNotConfigured;

  /// No description provided for @accountNotSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get accountNotSignedIn;

  /// No description provided for @accountOfflineCacheStats.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file} other{{count} files}} · {size}'**
  String accountOfflineCacheStats(int count, String size);

  /// No description provided for @accountOfflineCacheTitle.
  ///
  /// In en, this message translates to:
  /// **'Offline Cache'**
  String get accountOfflineCacheTitle;

  /// No description provided for @accountOfflineClearBody.
  ///
  /// In en, this message translates to:
  /// **'This will remove all offline copies of your files from this device. Your files on the server are not affected.'**
  String get accountOfflineClearBody;

  /// No description provided for @accountOfflineClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Offline Cache'**
  String get accountOfflineClearTitle;

  /// No description provided for @accountOfflineCleared.
  ///
  /// In en, this message translates to:
  /// **'Offline cache cleared'**
  String get accountOfflineCleared;

  /// No description provided for @accountOfflineNoFiles.
  ///
  /// In en, this message translates to:
  /// **'No files cached'**
  String get accountOfflineNoFiles;

  /// No description provided for @accountOpenSourceLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open source licenses'**
  String get accountOpenSourceLicenses;

  /// No description provided for @accountPasscodeLock.
  ///
  /// In en, this message translates to:
  /// **'Passcode Lock'**
  String get accountPasscodeLock;

  /// No description provided for @accountPinLabel.
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get accountPinLabel;

  /// No description provided for @accountPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get accountPrivacyPolicy;

  /// No description provided for @accountRecoveryHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get accountRecoveryHide;

  /// No description provided for @accountRecoveryKeyBody.
  ///
  /// In en, this message translates to:
  /// **'This is the credential that recovers your account if you ever forget your password. Keep a copy somewhere safe and private — anyone who has it can sign in as you. To use it, pick \"Log in with your key\" on the sign-in screen.'**
  String get accountRecoveryKeyBody;

  /// No description provided for @accountRecoveryKeyCopied.
  ///
  /// In en, this message translates to:
  /// **'Recovery key copied'**
  String get accountRecoveryKeyCopied;

  /// No description provided for @accountRecoveryKeyLocked.
  ///
  /// In en, this message translates to:
  /// **'Your keys are not unlocked right now. Sign in with your password to export your recovery key.'**
  String get accountRecoveryKeyLocked;

  /// No description provided for @accountRecoveryKeySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Back up your sign-in key'**
  String get accountRecoveryKeySubtitle;

  /// No description provided for @accountRecoveryKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'Recovery Key'**
  String get accountRecoveryKeyTitle;

  /// No description provided for @accountRecoveryReveal.
  ///
  /// In en, this message translates to:
  /// **'Reveal'**
  String get accountRecoveryReveal;

  /// No description provided for @accountRemovePasscodeBody.
  ///
  /// In en, this message translates to:
  /// **'This will remove the PIN lock screen. You will need to sign in with your password next time.'**
  String get accountRemovePasscodeBody;

  /// No description provided for @accountRemovePasscodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove Passcode'**
  String get accountRemovePasscodeTitle;

  /// No description provided for @accountSetUp.
  ///
  /// In en, this message translates to:
  /// **'Set up'**
  String get accountSetUp;

  /// No description provided for @accountSetUpPinFirst.
  ///
  /// In en, this message translates to:
  /// **'Set up a PIN first'**
  String get accountSetUpPinFirst;

  /// No description provided for @accountSettingsHeader.
  ///
  /// In en, this message translates to:
  /// **'SETTINGS'**
  String get accountSettingsHeader;

  /// No description provided for @accountSharingDisabledMsg.
  ///
  /// In en, this message translates to:
  /// **'You will no longer receive sharing emails.'**
  String get accountSharingDisabledMsg;

  /// No description provided for @accountSharingEmailToggle.
  ///
  /// In en, this message translates to:
  /// **'Email me when a file is shared with me'**
  String get accountSharingEmailToggle;

  /// No description provided for @accountSharingEmailsOff.
  ///
  /// In en, this message translates to:
  /// **'Sharing emails are off.'**
  String get accountSharingEmailsOff;

  /// No description provided for @accountSharingEmailsOn.
  ///
  /// In en, this message translates to:
  /// **'Sharing emails are on.'**
  String get accountSharingEmailsOn;

  /// No description provided for @accountSharingEnabledMsg.
  ///
  /// In en, this message translates to:
  /// **'You will receive an email when someone shares a file with you.'**
  String get accountSharingEnabledMsg;

  /// No description provided for @accountSharingHeader.
  ///
  /// In en, this message translates to:
  /// **'SHARING'**
  String get accountSharingHeader;

  /// No description provided for @accountSharingUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update sharing notifications.'**
  String get accountSharingUpdateFailed;

  /// No description provided for @accountSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get accountSignOut;

  /// No description provided for @accountSignOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get accountSignOutConfirm;

  /// No description provided for @accountStorageQuota.
  ///
  /// In en, this message translates to:
  /// **'Quota: {size}'**
  String accountStorageQuota(String size);

  /// No description provided for @accountStorageTitle.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get accountStorageTitle;

  /// No description provided for @accountStorageUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get accountStorageUnlimited;

  /// No description provided for @accountStorageUsed.
  ///
  /// In en, this message translates to:
  /// **'{used} used'**
  String accountStorageUsed(Object used);

  /// No description provided for @accountStorageUsedOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{used} of {total} used'**
  String accountStorageUsedOfTotal(Object used, Object total);

  /// No description provided for @accountTermsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get accountTermsOfService;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @accountWizardCallingInitialize.
  ///
  /// In en, this message translates to:
  /// **'Calling initialize…'**
  String get accountWizardCallingInitialize;

  /// No description provided for @accountWizardCapabilitiesList.
  ///
  /// In en, this message translates to:
  /// **'Capabilities: {list}'**
  String accountWizardCapabilitiesList(String list);

  /// No description provided for @accountWizardCapabilitiesNone.
  ///
  /// In en, this message translates to:
  /// **'Capabilities: none advertised'**
  String get accountWizardCapabilitiesNone;

  /// No description provided for @accountWizardConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get accountWizardConnected;

  /// No description provided for @accountWizardConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed. Check the server and token.'**
  String get accountWizardConnectionFailed;

  /// No description provided for @accountWizardCopyToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy to clipboard'**
  String get accountWizardCopyToClipboard;

  /// No description provided for @accountWizardCopyToken.
  ///
  /// In en, this message translates to:
  /// **'Copy token'**
  String get accountWizardCopyToken;

  /// No description provided for @accountWizardEnableHint.
  ///
  /// In en, this message translates to:
  /// **'Enable to bind the local port.'**
  String get accountWizardEnableHint;

  /// No description provided for @accountWizardFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get accountWizardFailed;

  /// No description provided for @accountWizardFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get accountWizardFinish;

  /// No description provided for @accountWizardHideToken.
  ///
  /// In en, this message translates to:
  /// **'Hide token'**
  String get accountWizardHideToken;

  /// No description provided for @accountWizardNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get accountWizardNext;

  /// No description provided for @accountWizardNoToken.
  ///
  /// In en, this message translates to:
  /// **'(no token)'**
  String get accountWizardNoToken;

  /// No description provided for @accountWizardOpenFolder.
  ///
  /// In en, this message translates to:
  /// **'Open config folder'**
  String get accountWizardOpenFolder;

  /// No description provided for @accountWizardProtocol.
  ///
  /// In en, this message translates to:
  /// **'protocol {version}'**
  String accountWizardProtocol(String version);

  /// No description provided for @accountWizardReadyBody.
  ///
  /// In en, this message translates to:
  /// **'Press \"Run test\" to call initialize against the local server.'**
  String get accountWizardReadyBody;

  /// No description provided for @accountWizardReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Ready to test'**
  String get accountWizardReadyTitle;

  /// No description provided for @accountWizardRegenerateConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This invalidates existing agent sessions. You will need to paste the new token into every AI client you have configured.'**
  String get accountWizardRegenerateConfirmBody;

  /// No description provided for @accountWizardRegenerateConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Regenerate bearer token?'**
  String get accountWizardRegenerateConfirmTitle;

  /// No description provided for @accountWizardRunTest.
  ///
  /// In en, this message translates to:
  /// **'Run test'**
  String get accountWizardRunTest;

  /// No description provided for @accountWizardServerName.
  ///
  /// In en, this message translates to:
  /// **'Server {name}'**
  String accountWizardServerName(String name);

  /// No description provided for @accountWizardShowToken.
  ///
  /// In en, this message translates to:
  /// **'Show token'**
  String get accountWizardShowToken;

  /// No description provided for @accountWizardStep1Subtitle.
  ///
  /// In en, this message translates to:
  /// **'The local MCP server needs to be running before we can hand credentials to your AI client.'**
  String get accountWizardStep1Subtitle;

  /// No description provided for @accountWizardStep1Title.
  ///
  /// In en, this message translates to:
  /// **'Step 1 of 4: Start the MCP server'**
  String get accountWizardStep1Title;

  /// No description provided for @accountWizardStep2Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Your AI client uses this token to authenticate every MCP call. Treat it like a password.'**
  String get accountWizardStep2Subtitle;

  /// No description provided for @accountWizardStep2Title.
  ///
  /// In en, this message translates to:
  /// **'Step 2 of 4: Review the bearer token'**
  String get accountWizardStep2Title;

  /// No description provided for @accountWizardStep3Title.
  ///
  /// In en, this message translates to:
  /// **'Step 3 of 4: Copy into your AI client'**
  String get accountWizardStep3Title;

  /// No description provided for @accountWizardStep4Subtitle.
  ///
  /// In en, this message translates to:
  /// **'We will call initialize over the local MCP socket and show you exactly what your AI client will see.'**
  String get accountWizardStep4Subtitle;

  /// No description provided for @accountWizardStep4Title.
  ///
  /// In en, this message translates to:
  /// **'Step 4 of 4: Verify the handshake'**
  String get accountWizardStep4Title;

  /// No description provided for @accountWizardTesting.
  ///
  /// In en, this message translates to:
  /// **'Testing'**
  String get accountWizardTesting;

  /// No description provided for @accountWizardTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get accountWizardTryAgain;

  /// No description provided for @adminActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String adminActionFailed(String error);

  /// No description provided for @adminActionsHeader.
  ///
  /// In en, this message translates to:
  /// **'ACTIONS'**
  String get adminActionsHeader;

  /// No description provided for @adminAdminRole.
  ///
  /// In en, this message translates to:
  /// **'Admin role'**
  String get adminAdminRole;

  /// No description provided for @adminAllowRegistration.
  ///
  /// In en, this message translates to:
  /// **'Allow Registration'**
  String get adminAllowRegistration;

  /// No description provided for @adminAllowRegistrationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Let new users sign up without invitation'**
  String get adminAllowRegistrationSubtitle;

  /// No description provided for @adminBadgeAdmin.
  ///
  /// In en, this message translates to:
  /// **'admin'**
  String get adminBadgeAdmin;

  /// No description provided for @adminCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get adminCopied;

  /// No description provided for @adminDefaultQuotaGbLabel.
  ///
  /// In en, this message translates to:
  /// **'Default quota (GB)'**
  String get adminDefaultQuotaGbLabel;

  /// No description provided for @adminDefaultQuotaHeader.
  ///
  /// In en, this message translates to:
  /// **'DEFAULT QUOTA'**
  String get adminDefaultQuotaHeader;

  /// No description provided for @adminDeleteUser.
  ///
  /// In en, this message translates to:
  /// **'Delete User'**
  String get adminDeleteUser;

  /// No description provided for @adminDeleteUserBody.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete {email} and ALL their files? This cannot be undone.'**
  String adminDeleteUserBody(String email);

  /// No description provided for @adminDeleteUserSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete user and all data'**
  String get adminDeleteUserSubtitle;

  /// No description provided for @adminDisable.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get adminDisable;

  /// No description provided for @adminDisableTfa.
  ///
  /// In en, this message translates to:
  /// **'Disable 2FA'**
  String get adminDisableTfa;

  /// No description provided for @adminDisableTfaBody.
  ///
  /// In en, this message translates to:
  /// **'This will remove 2FA for {email}. They will need to re-enable it themselves.'**
  String adminDisableTfaBody(String email);

  /// No description provided for @adminDisableTfaTitle.
  ///
  /// In en, this message translates to:
  /// **'Disable Two-Factor Auth'**
  String get adminDisableTfaTitle;

  /// No description provided for @adminDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get adminDisabled;

  /// No description provided for @adminEditRoleQuotaTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit role & quota'**
  String get adminEditRoleQuotaTooltip;

  /// No description provided for @adminEditUserTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit User'**
  String get adminEditUserTitle;

  /// No description provided for @adminEmailHeader.
  ///
  /// In en, this message translates to:
  /// **'EMAIL'**
  String get adminEmailHeader;

  /// No description provided for @adminEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get adminEmailLabel;

  /// No description provided for @adminEmailTestFailed.
  ///
  /// In en, this message translates to:
  /// **'Email test failed: {error}'**
  String adminEmailTestFailed(String error);

  /// No description provided for @adminEmailVerifiedLabel.
  ///
  /// In en, this message translates to:
  /// **'Email Verified'**
  String get adminEmailVerifiedLabel;

  /// No description provided for @adminEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get adminEnabled;

  /// No description provided for @adminEnforceEmailVerification.
  ///
  /// In en, this message translates to:
  /// **'Enforce Email Verification'**
  String get adminEnforceEmailVerification;

  /// No description provided for @adminEnforceEmailVerificationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Require users to verify email before login'**
  String get adminEnforceEmailVerificationSubtitle;

  /// No description provided for @adminExpire.
  ///
  /// In en, this message translates to:
  /// **'Expire'**
  String get adminExpire;

  /// No description provided for @adminExpireInvitationBody.
  ///
  /// In en, this message translates to:
  /// **'Expire the invitation for {email}? They will no longer be able to use it to register.'**
  String adminExpireInvitationBody(String email);

  /// No description provided for @adminExpireInvitationTitle.
  ///
  /// In en, this message translates to:
  /// **'Expire Invitation'**
  String get adminExpireInvitationTitle;

  /// No description provided for @adminFileCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file} other{{count} files}}'**
  String adminFileCount(int count);

  /// No description provided for @adminInvitationCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 invitation} other{{count} invitations}}'**
  String adminInvitationCount(int count);

  /// No description provided for @adminInvitationSent.
  ///
  /// In en, this message translates to:
  /// **'Invitation sent to {email}'**
  String adminInvitationSent(String email);

  /// No description provided for @adminInvite.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get adminInvite;

  /// No description provided for @adminKillAll.
  ///
  /// In en, this message translates to:
  /// **'Kill All'**
  String get adminKillAll;

  /// No description provided for @adminKillAllSessions.
  ///
  /// In en, this message translates to:
  /// **'Kill All Sessions'**
  String get adminKillAllSessions;

  /// No description provided for @adminKillAllSessionsBody.
  ///
  /// In en, this message translates to:
  /// **'This will sign {email} out of all devices.'**
  String adminKillAllSessionsBody(String email);

  /// No description provided for @adminLastActive.
  ///
  /// In en, this message translates to:
  /// **'Active {time}'**
  String adminLastActive(String time);

  /// No description provided for @adminNoActiveSessions.
  ///
  /// In en, this message translates to:
  /// **'No active sessions'**
  String get adminNoActiveSessions;

  /// No description provided for @adminNoFiles.
  ///
  /// In en, this message translates to:
  /// **'No files'**
  String get adminNoFiles;

  /// No description provided for @adminNoFilesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This user has not uploaded any files'**
  String get adminNoFilesSubtitle;

  /// No description provided for @adminNoInvitations.
  ///
  /// In en, this message translates to:
  /// **'No invitations yet'**
  String get adminNoInvitations;

  /// No description provided for @adminNoUsersFound.
  ///
  /// In en, this message translates to:
  /// **'No users found'**
  String get adminNoUsersFound;

  /// No description provided for @adminNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Not verified'**
  String get adminNotVerified;

  /// No description provided for @adminPaginationRange.
  ///
  /// In en, this message translates to:
  /// **'{start}–{end} of {total}'**
  String adminPaginationRange(int start, int end, int total);

  /// No description provided for @adminPanelTitle.
  ///
  /// In en, this message translates to:
  /// **'Admin Panel'**
  String get adminPanelTitle;

  /// No description provided for @adminQuotaDefaultHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for default'**
  String get adminQuotaDefaultHint;

  /// No description provided for @adminQuotaGbLabel.
  ///
  /// In en, this message translates to:
  /// **'Quota (GB)'**
  String get adminQuotaGbLabel;

  /// No description provided for @adminQuotaLabel.
  ///
  /// In en, this message translates to:
  /// **'Quota'**
  String get adminQuotaLabel;

  /// No description provided for @adminQuotaUnlimitedHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for unlimited'**
  String get adminQuotaUnlimitedHint;

  /// No description provided for @adminRegisteredLabel.
  ///
  /// In en, this message translates to:
  /// **'Registered'**
  String get adminRegisteredLabel;

  /// No description provided for @adminRegistrationHeader.
  ///
  /// In en, this message translates to:
  /// **'USER REGISTRATION'**
  String get adminRegistrationHeader;

  /// No description provided for @adminRoleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get adminRoleAdmin;

  /// No description provided for @adminRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get adminRoleLabel;

  /// No description provided for @adminRoleUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get adminRoleUser;

  /// No description provided for @adminSaveSettings.
  ///
  /// In en, this message translates to:
  /// **'Save Settings'**
  String get adminSaveSettings;

  /// No description provided for @adminSearchUsersHint.
  ///
  /// In en, this message translates to:
  /// **'Search users...'**
  String get adminSearchUsersHint;

  /// No description provided for @adminSendInvitationTitle.
  ///
  /// In en, this message translates to:
  /// **'Send Invitation'**
  String get adminSendInvitationTitle;

  /// No description provided for @adminSendTest.
  ///
  /// In en, this message translates to:
  /// **'Send Test'**
  String get adminSendTest;

  /// No description provided for @adminSessionsHeader.
  ///
  /// In en, this message translates to:
  /// **'SESSIONS ({count})'**
  String adminSessionsHeader(int count);

  /// No description provided for @adminSettingsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load settings'**
  String get adminSettingsLoadFailed;

  /// No description provided for @adminSettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved'**
  String get adminSettingsSaved;

  /// No description provided for @adminSharingHeader.
  ///
  /// In en, this message translates to:
  /// **'SHARING'**
  String get adminSharingHeader;

  /// No description provided for @adminSharingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When off, the Share action disappears everywhere and the sharing endpoints stop responding. Existing shares are kept.'**
  String get adminSharingSubtitle;

  /// No description provided for @adminSharingToggle.
  ///
  /// In en, this message translates to:
  /// **'Account-to-account sharing'**
  String get adminSharingToggle;

  /// No description provided for @adminStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get adminStatusExpired;

  /// No description provided for @adminStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get adminStatusPending;

  /// No description provided for @adminStatusRedeemed.
  ///
  /// In en, this message translates to:
  /// **'Redeemed'**
  String get adminStatusRedeemed;

  /// No description provided for @adminStorageHeader.
  ///
  /// In en, this message translates to:
  /// **'STORAGE ({size} · {count, plural, =1{1 file} other{{count} files}})'**
  String adminStorageHeader(String size, int count);

  /// No description provided for @adminTabInvitations.
  ///
  /// In en, this message translates to:
  /// **'Invitations'**
  String get adminTabInvitations;

  /// No description provided for @adminTabSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get adminTabSettings;

  /// No description provided for @adminTabUsers.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get adminTabUsers;

  /// No description provided for @adminTestEmailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send a test email to verify SMTP'**
  String get adminTestEmailSubtitle;

  /// No description provided for @adminTestEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Test Email Configuration'**
  String get adminTestEmailTitle;

  /// No description provided for @adminTwoFactorLabel.
  ///
  /// In en, this message translates to:
  /// **'Two-Factor Auth'**
  String get adminTwoFactorLabel;

  /// No description provided for @adminUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get adminUnlimited;

  /// No description provided for @adminUserDeleted.
  ///
  /// In en, this message translates to:
  /// **'User deleted'**
  String get adminUserDeleted;

  /// No description provided for @adminUserInfoHeader.
  ///
  /// In en, this message translates to:
  /// **'USER INFO'**
  String get adminUserInfoHeader;

  /// No description provided for @adminUserUpdated.
  ///
  /// In en, this message translates to:
  /// **'User updated'**
  String get adminUserUpdated;

  /// No description provided for @authAddAnotherAccount.
  ///
  /// In en, this message translates to:
  /// **'Add another account'**
  String get authAddAnotherAccount;

  /// No description provided for @authAddNewServer.
  ///
  /// In en, this message translates to:
  /// **'ADD NEW SERVER'**
  String get authAddNewServer;

  /// No description provided for @authAddServer.
  ///
  /// In en, this message translates to:
  /// **'Add Server'**
  String get authAddServer;

  /// No description provided for @authBiometricFailed.
  ///
  /// In en, this message translates to:
  /// **'Biometric failed'**
  String get authBiometricFailed;

  /// No description provided for @authBiometricFailedUsePin.
  ///
  /// In en, this message translates to:
  /// **'Biometric failed — use your PIN'**
  String get authBiometricFailedUsePin;

  /// No description provided for @authBiometricLockedOut.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts — try again in 30 s, or use your PIN'**
  String get authBiometricLockedOut;

  /// No description provided for @authBiometricNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Biometric not configured for this build — use your PIN'**
  String get authBiometricNotConfigured;

  /// No description provided for @authBiometricNotEnrolled.
  ///
  /// In en, this message translates to:
  /// **'No biometric enrolled on this device — use your PIN'**
  String get authBiometricNotEnrolled;

  /// No description provided for @authBiometricPermanentlyLockedOut.
  ///
  /// In en, this message translates to:
  /// **'Biometric locked — unlock your device, then try again'**
  String get authBiometricPermanentlyLockedOut;

  /// No description provided for @authBiometricPinNotFound.
  ///
  /// In en, this message translates to:
  /// **'Biometric PIN not found'**
  String get authBiometricPinNotFound;

  /// No description provided for @authCheckEmailBody.
  ///
  /// In en, this message translates to:
  /// **'Your account was created. Verify your email, then sign in to unlock encryption.'**
  String get authCheckEmailBody;

  /// No description provided for @authCheckEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get authCheckEmailTitle;

  /// No description provided for @authConfirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get authConfirmPasswordLabel;

  /// No description provided for @authConfirmPinLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm PIN'**
  String get authConfirmPinLabel;

  /// No description provided for @authConnectToServer.
  ///
  /// In en, this message translates to:
  /// **'Connect to a Server'**
  String get authConnectToServer;

  /// No description provided for @authConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed: {error}'**
  String authConnectionFailed(String error);

  /// No description provided for @authCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get authCreateAccount;

  /// No description provided for @authCreateAnAccount.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get authCreateAnAccount;

  /// No description provided for @authCreatePasscode.
  ///
  /// In en, this message translates to:
  /// **'Create a Passcode'**
  String get authCreatePasscode;

  /// No description provided for @authDeleteServerConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{name}\" and all its accounts?'**
  String authDeleteServerConfirm(String name);

  /// No description provided for @authDeleteServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Server'**
  String get authDeleteServerTitle;

  /// No description provided for @authEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmailLabel;

  /// No description provided for @authEmailPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Email and password are required'**
  String get authEmailPasswordRequired;

  /// No description provided for @authEnterPasscode.
  ///
  /// In en, this message translates to:
  /// **'Enter Passcode'**
  String get authEnterPasscode;

  /// No description provided for @authEnterPinPrompt.
  ///
  /// In en, this message translates to:
  /// **'Please enter your PIN'**
  String get authEnterPinPrompt;

  /// No description provided for @authEnterTfaCode.
  ///
  /// In en, this message translates to:
  /// **'Please enter your 2FA code'**
  String get authEnterTfaCode;

  /// No description provided for @authExistingAccounts.
  ///
  /// In en, this message translates to:
  /// **'EXISTING ACCOUNTS'**
  String get authExistingAccounts;

  /// No description provided for @authForget.
  ///
  /// In en, this message translates to:
  /// **'Forget'**
  String get authForget;

  /// No description provided for @authForgetAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will remove the account \"{email}\" from this device. All offline files for this account will be deleted. You can sign in again later.'**
  String authForgetAccountConfirm(String email);

  /// No description provided for @authForgetAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Forget Account'**
  String get authForgetAccountTitle;

  /// No description provided for @authForgetThisAccount.
  ///
  /// In en, this message translates to:
  /// **'Forget this account'**
  String get authForgetThisAccount;

  /// No description provided for @authGetMyRecoveryKey.
  ///
  /// In en, this message translates to:
  /// **'Get my recovery key'**
  String get authGetMyRecoveryKey;

  /// No description provided for @authInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password'**
  String get authInvalidCredentials;

  /// No description provided for @authKeyLoginIntro.
  ///
  /// In en, this message translates to:
  /// **'Paste the recovery key you saved when you set up your account. It never leaves this device — it is only used to sign a login challenge.'**
  String get authKeyLoginIntro;

  /// No description provided for @authKeyLoginInvalidKey.
  ///
  /// In en, this message translates to:
  /// **'This is not a valid private key'**
  String get authKeyLoginInvalidKey;

  /// No description provided for @authKeyLoginNoAccount.
  ///
  /// In en, this message translates to:
  /// **'The server accepted the key but returned no account'**
  String get authKeyLoginNoAccount;

  /// No description provided for @authKeyLoginNoIdentityKey.
  ///
  /// In en, this message translates to:
  /// **'This recovery key carries no usable identity key'**
  String get authKeyLoginNoIdentityKey;

  /// No description provided for @authKeyLoginSelfCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'This recovery key failed its self-check'**
  String get authKeyLoginSelfCheckFailed;

  /// No description provided for @authKeyLoginSessionFailed.
  ///
  /// In en, this message translates to:
  /// **'Signed in, but the session could not be established'**
  String get authKeyLoginSessionFailed;

  /// No description provided for @authKeyLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Log In With Your Key'**
  String get authKeyLoginTitle;

  /// No description provided for @authKeyLoginUnrecognizedKey.
  ///
  /// In en, this message translates to:
  /// **'The server did not recognize this key'**
  String get authKeyLoginUnrecognizedKey;

  /// No description provided for @authLastUsed.
  ///
  /// In en, this message translates to:
  /// **'Last used {time}'**
  String authLastUsed(String time);

  /// No description provided for @authLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get authLater;

  /// No description provided for @authLearnMore.
  ///
  /// In en, this message translates to:
  /// **'Learn more'**
  String get authLearnMore;

  /// No description provided for @authLogIn.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get authLogIn;

  /// No description provided for @authLogInWithKey.
  ///
  /// In en, this message translates to:
  /// **'Log in with your key'**
  String get authLogInWithKey;

  /// No description provided for @authLogInWithPassword.
  ///
  /// In en, this message translates to:
  /// **'Log in with email and password'**
  String get authLogInWithPassword;

  /// No description provided for @authManageAccounts.
  ///
  /// In en, this message translates to:
  /// **'Manage Accounts'**
  String get authManageAccounts;

  /// No description provided for @authMigrationNoticeBody.
  ///
  /// In en, this message translates to:
  /// **'Your files are now protected with upgraded encryption, and you sign in without your password ever leaving this device.\n\nBecause this created new keys for your account, save a fresh copy of your recovery key — it is the only way back in if you forget your password. You can always find it under Account → Recovery Key.'**
  String get authMigrationNoticeBody;

  /// No description provided for @authMigrationNoticeTitle.
  ///
  /// In en, this message translates to:
  /// **'Your account security was upgraded'**
  String get authMigrationNoticeTitle;

  /// No description provided for @authNeedServerBody.
  ///
  /// In en, this message translates to:
  /// **'Self-host for free, or get a managed instance.'**
  String get authNeedServerBody;

  /// No description provided for @authNeedServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Need a server?'**
  String get authNeedServerTitle;

  /// No description provided for @authNeverUsed.
  ///
  /// In en, this message translates to:
  /// **'Never used'**
  String get authNeverUsed;

  /// No description provided for @authNoAccountFound.
  ///
  /// In en, this message translates to:
  /// **'No account found'**
  String get authNoAccountFound;

  /// No description provided for @authNoActiveAccountOrKey.
  ///
  /// In en, this message translates to:
  /// **'No active account or private key available'**
  String get authNoActiveAccountOrKey;

  /// No description provided for @authNoServerSelected.
  ///
  /// In en, this message translates to:
  /// **'No server selected'**
  String get authNoServerSelected;

  /// No description provided for @authPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPasswordLabel;

  /// No description provided for @authPasswordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get authPasswordsDoNotMatch;

  /// No description provided for @authPasteRecoveryKeyFirst.
  ///
  /// In en, this message translates to:
  /// **'Paste your recovery key first'**
  String get authPasteRecoveryKeyFirst;

  /// No description provided for @authPinLabel.
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get authPinLabel;

  /// No description provided for @authPinPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'At least 4 characters'**
  String get authPinPlaceholder;

  /// No description provided for @authPinSetupFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to set up PIN: {error}'**
  String authPinSetupFailed(String error);

  /// No description provided for @authPinTooShort.
  ///
  /// In en, this message translates to:
  /// **'PIN must be at least 4 characters'**
  String get authPinTooShort;

  /// No description provided for @authPinsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'PINs do not match'**
  String get authPinsDoNotMatch;

  /// No description provided for @authRecoveryKeyEmpty.
  ///
  /// In en, this message translates to:
  /// **'Recovery key is empty'**
  String get authRecoveryKeyEmpty;

  /// No description provided for @authRecoveryKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Recovery key'**
  String get authRecoveryKeyLabel;

  /// No description provided for @authRecoveryKeyMissingKeys.
  ///
  /// In en, this message translates to:
  /// **'Recovery key is missing its identity or wrapping key'**
  String get authRecoveryKeyMissingKeys;

  /// No description provided for @authRecoveryKeyUnrecognized.
  ///
  /// In en, this message translates to:
  /// **'This does not look like a Hoodik recovery key'**
  String get authRecoveryKeyUnrecognized;

  /// No description provided for @authRegistrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed: {error}'**
  String authRegistrationFailed(String error);

  /// No description provided for @authRegistrationNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Registration not allowed for this email'**
  String get authRegistrationNotAllowed;

  /// No description provided for @authSavedServers.
  ///
  /// In en, this message translates to:
  /// **'SAVED SERVERS'**
  String get authSavedServers;

  /// No description provided for @authServerTooOldForRegister.
  ///
  /// In en, this message translates to:
  /// **'This server is too old to create an account from this app. Please update the server, or sign in to an existing account.'**
  String get authServerTooOldForRegister;

  /// No description provided for @authServerUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get authServerUrlLabel;

  /// No description provided for @authServerUrlRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a server URL'**
  String get authServerUrlRequired;

  /// No description provided for @authSetPin.
  ///
  /// In en, this message translates to:
  /// **'Set PIN'**
  String get authSetPin;

  /// No description provided for @authSetupPinIntro.
  ///
  /// In en, this message translates to:
  /// **'Set a PIN to quickly unlock your account next time without entering your password.'**
  String get authSetupPinIntro;

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get authSignIn;

  /// No description provided for @authSignInDifferentAccount.
  ///
  /// In en, this message translates to:
  /// **'SIGN IN WITH A DIFFERENT ACCOUNT'**
  String get authSignInDifferentAccount;

  /// No description provided for @authSignInToContinue.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to continue.'**
  String get authSignInToContinue;

  /// No description provided for @authSignInToUnlockEncryption.
  ///
  /// In en, this message translates to:
  /// **'Please sign in with your password to unlock encryption.'**
  String get authSignInToUnlockEncryption;

  /// No description provided for @authSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get authSkip;

  /// No description provided for @authSwitchAccount.
  ///
  /// In en, this message translates to:
  /// **'SWITCH ACCOUNT'**
  String get authSwitchAccount;

  /// No description provided for @authTagline.
  ///
  /// In en, this message translates to:
  /// **'End-to-End Encrypted Cloud Storage'**
  String get authTagline;

  /// No description provided for @authTfaCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'2FA Code'**
  String get authTfaCodeLabel;

  /// No description provided for @authTfaRequired.
  ///
  /// In en, this message translates to:
  /// **'Two-factor authentication code required'**
  String get authTfaRequired;

  /// No description provided for @authUnknownServer.
  ///
  /// In en, this message translates to:
  /// **'Unknown server'**
  String get authUnknownServer;

  /// No description provided for @authUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get authUnlock;

  /// No description provided for @authUnlockHoodik.
  ///
  /// In en, this message translates to:
  /// **'Unlock Hoodik'**
  String get authUnlockHoodik;

  /// No description provided for @authValidationError.
  ///
  /// In en, this message translates to:
  /// **'Validation error — check your input'**
  String get authValidationError;

  /// No description provided for @authWrongPin.
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN'**
  String get authWrongPin;

  /// No description provided for @authWrongPinOrAuthFailed.
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN or authentication failed'**
  String get authWrongPinOrAuthFailed;

  /// No description provided for @authWrongPinOrVerifyFailed.
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN or verification failed'**
  String get authWrongPinOrVerifyFailed;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get commonCopy;

  /// No description provided for @commonCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get commonCreate;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get commonDownload;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get commonLoading;

  /// No description provided for @commonMove.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get commonMove;

  /// No description provided for @commonNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get commonNever;

  /// No description provided for @commonNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get commonOpen;

  /// No description provided for @commonRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// No description provided for @commonRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get commonRename;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get commonSend;

  /// No description provided for @commonShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get commonShare;

  /// No description provided for @commonUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get commonUnknown;

  /// No description provided for @commonUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get commonUpload;

  /// No description provided for @commonYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// No description provided for @errorNoConnection.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your network and try again.'**
  String get errorNoConnection;

  /// No description provided for @errorNotAuthorized.
  ///
  /// In en, this message translates to:
  /// **'You’re not authorized for this action. Try signing in again.'**
  String get errorNotAuthorized;

  /// No description provided for @errorRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Request failed ({status}).'**
  String errorRequestFailed(Object status);

  /// No description provided for @errorServerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The server is having trouble. Try again in a moment.'**
  String get errorServerUnavailable;

  /// No description provided for @filesAccountNotInitialized.
  ///
  /// In en, this message translates to:
  /// **'Account not fully initialized'**
  String get filesAccountNotInitialized;

  /// No description provided for @filesAvailableOffline.
  ///
  /// In en, this message translates to:
  /// **'{name} available offline'**
  String filesAvailableOffline(String name);

  /// No description provided for @filesCacheFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to cache: {error}'**
  String filesCacheFailed(String error);

  /// No description provided for @filesCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get filesCancelled;

  /// No description provided for @filesCannotBeUndone.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get filesCannotBeUndone;

  /// No description provided for @filesCannotDecryptKey.
  ///
  /// In en, this message translates to:
  /// **'Cannot decrypt file key'**
  String get filesCannotDecryptKey;

  /// No description provided for @filesCannotDecryptSharedKey.
  ///
  /// In en, this message translates to:
  /// **'Cannot decrypt the shared file key'**
  String get filesCannotDecryptSharedKey;

  /// No description provided for @filesCannotReadPath.
  ///
  /// In en, this message translates to:
  /// **'Could not read file path'**
  String get filesCannotReadPath;

  /// No description provided for @filesChooseFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose folder'**
  String get filesChooseFolder;

  /// No description provided for @filesChunksLabel.
  ///
  /// In en, this message translates to:
  /// **'Chunks'**
  String get filesChunksLabel;

  /// No description provided for @filesCipherLabel.
  ///
  /// In en, this message translates to:
  /// **'Cipher'**
  String get filesCipherLabel;

  /// No description provided for @filesClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get filesClear;

  /// No description provided for @filesConvertFailed.
  ///
  /// In en, this message translates to:
  /// **'Convert failed: {error}'**
  String filesConvertFailed(String error);

  /// No description provided for @filesConvertToNote.
  ///
  /// In en, this message translates to:
  /// **'Convert to note'**
  String get filesConvertToNote;

  /// No description provided for @filesConvertedToNote.
  ///
  /// In en, this message translates to:
  /// **'Converted to note'**
  String get filesConvertedToNote;

  /// No description provided for @filesCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'{label} copied to clipboard'**
  String filesCopiedToClipboard(String label);

  /// No description provided for @filesCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy Link'**
  String get filesCopyLink;

  /// No description provided for @filesCreateFolder.
  ///
  /// In en, this message translates to:
  /// **'Create Folder'**
  String get filesCreateFolder;

  /// No description provided for @filesCreateFolderFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create folder: {error}'**
  String filesCreateFolderFailed(String error);

  /// No description provided for @filesCreateLink.
  ///
  /// In en, this message translates to:
  /// **'Create Link'**
  String get filesCreateLink;

  /// No description provided for @filesCreateLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create link: {error}'**
  String filesCreateLinkFailed(String error);

  /// No description provided for @filesCreatedLabel.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get filesCreatedLabel;

  /// No description provided for @filesDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get filesDateLabel;

  /// No description provided for @filesDeleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? This cannot be undone.'**
  String filesDeleteConfirmMessage(String name);

  /// No description provided for @filesDeleteCountTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Delete 1 item?} other{Delete {count} items?}}'**
  String filesDeleteCountTitle(int count);

  /// No description provided for @filesDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed: {error}'**
  String filesDeleteFailed(String error);

  /// No description provided for @filesDeleteFileTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete file?'**
  String get filesDeleteFileTitle;

  /// No description provided for @filesDeleteFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete folder?'**
  String get filesDeleteFolderTitle;

  /// No description provided for @filesDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get filesDeleted;

  /// No description provided for @filesDeletedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Deleted 1 item} other{Deleted {count} items}}'**
  String filesDeletedCount(int count);

  /// No description provided for @filesDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get filesDetails;

  /// No description provided for @filesDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get filesDiscard;

  /// No description provided for @filesDownloadingForOffline.
  ///
  /// In en, this message translates to:
  /// **'Downloading for offline access...'**
  String get filesDownloadingForOffline;

  /// No description provided for @filesDropToUpload.
  ///
  /// In en, this message translates to:
  /// **'Drop files to upload'**
  String get filesDropToUpload;

  /// No description provided for @filesEmptyFolder.
  ///
  /// In en, this message translates to:
  /// **'Empty folder'**
  String get filesEmptyFolder;

  /// No description provided for @filesEmptyAction.
  ///
  /// In en, this message translates to:
  /// **'Add your first file'**
  String get filesEmptyAction;

  /// No description provided for @filesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No files yet'**
  String get filesEmptyTitle;

  /// No description provided for @filesEncryptedFallback.
  ///
  /// In en, this message translates to:
  /// **'(encrypted)'**
  String get filesEncryptedFallback;

  /// No description provided for @filesEncryptedPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'[Encrypted] {id}...'**
  String filesEncryptedPlaceholder(String id);

  /// No description provided for @filesExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get filesExport;

  /// No description provided for @filesExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String filesExportFailed(String error);

  /// No description provided for @filesExportStarted.
  ///
  /// In en, this message translates to:
  /// **'Export started — share sheet will open when complete'**
  String get filesExportStarted;

  /// No description provided for @filesExportingTo.
  ///
  /// In en, this message translates to:
  /// **'Exporting to {path}'**
  String filesExportingTo(String path);

  /// No description provided for @filesFailedUploadsHeader.
  ///
  /// In en, this message translates to:
  /// **'Failed uploads ({count})'**
  String filesFailedUploadsHeader(int count);

  /// No description provided for @filesFailedUploadsTooltip.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 failed upload} other{{count} failed uploads}}'**
  String filesFailedUploadsTooltip(int count);

  /// No description provided for @filesFolderCreated.
  ///
  /// In en, this message translates to:
  /// **'Folder created'**
  String get filesFolderCreated;

  /// No description provided for @filesFolderLabel.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get filesFolderLabel;

  /// No description provided for @filesFolderNameHint.
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get filesFolderNameHint;

  /// No description provided for @filesForkFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save to your drive: {error}'**
  String filesForkFailed(String error);

  /// No description provided for @filesForkFolderUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Folders cannot be saved to your drive'**
  String get filesForkFolderUnsupported;

  /// No description provided for @filesForkQuotaExceeded.
  ///
  /// In en, this message translates to:
  /// **'Not enough space to save this file to your drive'**
  String get filesForkQuotaExceeded;

  /// No description provided for @filesForkSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved \"{name}\" to your drive'**
  String filesForkSaved(String name);

  /// No description provided for @filesForkSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving \"{name}\" to your drive…'**
  String filesForkSaving(String name);

  /// No description provided for @filesIdLabel.
  ///
  /// In en, this message translates to:
  /// **'ID'**
  String get filesIdLabel;

  /// No description provided for @filesLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get filesLeave;

  /// No description provided for @filesLeaveShareBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ll lose access to \"{name}\" on future reads. Anything you\'ve already downloaded stays with you — end-to-end encryption can\'t recall what\'s already been decrypted on your device, and the owner can\'t un-share it.'**
  String filesLeaveShareBody(String name);

  /// No description provided for @filesLeaveShareTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave this share?'**
  String get filesLeaveShareTitle;

  /// No description provided for @filesLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied to clipboard'**
  String get filesLinkCopied;

  /// No description provided for @filesLinkCreatedTitle.
  ///
  /// In en, this message translates to:
  /// **'Link Created'**
  String get filesLinkCreatedTitle;

  /// No description provided for @filesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load files: {error}'**
  String filesLoadFailed(String error);

  /// No description provided for @filesLoadSharedFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load shared items: {error}'**
  String filesLoadSharedFailed(String error);

  /// No description provided for @filesMakeAvailableOffline.
  ///
  /// In en, this message translates to:
  /// **'Make Available Offline'**
  String get filesMakeAvailableOffline;

  /// No description provided for @filesMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get filesMembers;

  /// No description provided for @filesMoreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get filesMoreActions;

  /// No description provided for @filesMoveFailed.
  ///
  /// In en, this message translates to:
  /// **'Move failed: {error}'**
  String filesMoveFailed(String error);

  /// No description provided for @filesMoveHere.
  ///
  /// In en, this message translates to:
  /// **'Move here'**
  String get filesMoveHere;

  /// No description provided for @filesMoveItems.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Move 1 item} other{Move {count} items}}'**
  String filesMoveItems(int count);

  /// No description provided for @filesMoveToTitle.
  ///
  /// In en, this message translates to:
  /// **'Move to...'**
  String get filesMoveToTitle;

  /// No description provided for @filesMyFiles.
  ///
  /// In en, this message translates to:
  /// **'My Files'**
  String get filesMyFiles;

  /// No description provided for @filesNameInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid name'**
  String get filesNameInvalid;

  /// No description provided for @filesNameInvalidChars.
  ///
  /// In en, this message translates to:
  /// **'Name cannot contain / or \\'**
  String get filesNameInvalidChars;

  /// No description provided for @filesNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get filesNameLabel;

  /// No description provided for @filesNewNameHint.
  ///
  /// In en, this message translates to:
  /// **'New name'**
  String get filesNewNameHint;

  /// No description provided for @filesNoAccessToLeave.
  ///
  /// In en, this message translates to:
  /// **'You do not have access to leave'**
  String get filesNoAccessToLeave;

  /// No description provided for @filesNoSubfolders.
  ///
  /// In en, this message translates to:
  /// **'No sub-folders'**
  String get filesNoSubfolders;

  /// No description provided for @filesNotAuthenticated.
  ///
  /// In en, this message translates to:
  /// **'Not authenticated'**
  String get filesNotAuthenticated;

  /// No description provided for @filesOfflineChip.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get filesOfflineChip;

  /// No description provided for @filesOfflineCopyRemoved.
  ///
  /// In en, this message translates to:
  /// **'Offline copy removed'**
  String get filesOfflineCopyRemoved;

  /// No description provided for @filesOpsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'File operations not available'**
  String get filesOpsUnavailable;

  /// No description provided for @filesOpsUnavailableNoKey.
  ///
  /// In en, this message translates to:
  /// **'File operations not available (no private key)'**
  String get filesOpsUnavailableNoKey;

  /// No description provided for @filesOwnedBy.
  ///
  /// In en, this message translates to:
  /// **'Owned by {name}'**
  String filesOwnedBy(String name);

  /// No description provided for @filesPinnedForOffline.
  ///
  /// In en, this message translates to:
  /// **'{name} pinned for offline access'**
  String filesPinnedForOffline(String name);

  /// No description provided for @filesPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing…'**
  String get filesPreparing;

  /// No description provided for @filesPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get filesPreview;

  /// No description provided for @filesPublicKeyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Public key not available'**
  String get filesPublicKeyUnavailable;

  /// No description provided for @filesQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get filesQueued;

  /// No description provided for @filesRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get filesRefresh;

  /// No description provided for @filesRemoveOfflineCopy.
  ///
  /// In en, this message translates to:
  /// **'Remove Offline Copy'**
  String get filesRemoveOfflineCopy;

  /// No description provided for @filesRenameFailed.
  ///
  /// In en, this message translates to:
  /// **'Rename failed: {error}'**
  String filesRenameFailed(String error);

  /// No description provided for @filesRenamed.
  ///
  /// In en, this message translates to:
  /// **'Renamed'**
  String get filesRenamed;

  /// No description provided for @filesRevokeFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to revoke: {error}'**
  String filesRevokeFailed(String error);

  /// No description provided for @filesRootFolder.
  ///
  /// In en, this message translates to:
  /// **'Root'**
  String get filesRootFolder;

  /// No description provided for @filesSaveFileDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Save file'**
  String get filesSaveFileDialogTitle;

  /// No description provided for @filesSaveToMyDrive.
  ///
  /// In en, this message translates to:
  /// **'Save to my drive'**
  String get filesSaveToMyDrive;

  /// No description provided for @filesSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get filesSelect;

  /// No description provided for @filesSelectFilesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Select files'**
  String get filesSelectFilesTooltip;

  /// No description provided for @filesSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String filesSelectedCount(int count);

  /// No description provided for @filesShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to share: {error}'**
  String filesShareFailed(String error);

  /// No description provided for @filesSharedItemsNeedConnection.
  ///
  /// In en, this message translates to:
  /// **'Shared items need a connection.'**
  String get filesSharedItemsNeedConnection;

  /// No description provided for @filesSharedWith.
  ///
  /// In en, this message translates to:
  /// **'Shared with {count}'**
  String filesSharedWith(int count);

  /// No description provided for @filesSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get filesSizeLabel;

  /// No description provided for @filesSortTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get filesSortTooltip;

  /// No description provided for @filesStillUploading.
  ///
  /// In en, this message translates to:
  /// **'This file is still uploading — give it a moment.'**
  String get filesStillUploading;

  /// No description provided for @filesTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get filesTakePhoto;

  /// No description provided for @filesTheseFolders.
  ///
  /// In en, this message translates to:
  /// **'these folders'**
  String get filesTheseFolders;

  /// No description provided for @filesTitle.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get filesTitle;

  /// No description provided for @filesTransferActive.
  ///
  /// In en, this message translates to:
  /// **'{verb} {fileName}'**
  String filesTransferActive(String verb, String fileName);

  /// No description provided for @filesTransferActiveMore.
  ///
  /// In en, this message translates to:
  /// **'{verb} {fileName} (+{count} more)'**
  String filesTransferActiveMore(String verb, String fileName, int count);

  /// No description provided for @filesTransferCancelled.
  ///
  /// In en, this message translates to:
  /// **'{fileName} — Cancelled'**
  String filesTransferCancelled(String fileName);

  /// No description provided for @filesTransferDone.
  ///
  /// In en, this message translates to:
  /// **'{fileName} — Done'**
  String filesTransferDone(String fileName);

  /// No description provided for @filesTransferDoneSize.
  ///
  /// In en, this message translates to:
  /// **'Done  {size}'**
  String filesTransferDoneSize(String size);

  /// No description provided for @filesTransferFailed.
  ///
  /// In en, this message translates to:
  /// **'{fileName} — Failed'**
  String filesTransferFailed(String fileName);

  /// No description provided for @filesTransferQueued.
  ///
  /// In en, this message translates to:
  /// **'{fileName} — Queued'**
  String filesTransferQueued(String fileName);

  /// No description provided for @filesTransfersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 transfer} other{{count} transfers}}'**
  String filesTransfersCount(int count);

  /// No description provided for @filesTransfersDismissTooltip.
  ///
  /// In en, this message translates to:
  /// **'Dismiss — transfers continue in background'**
  String get filesTransfersDismissTooltip;

  /// No description provided for @filesTransfersMinimizeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get filesTransfersMinimizeTooltip;

  /// No description provided for @filesTransfersTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfers'**
  String get filesTransfersTitle;

  /// No description provided for @filesTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get filesTypeLabel;

  /// No description provided for @filesUnknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get filesUnknownError;

  /// No description provided for @filesUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed: {error}'**
  String filesUploadFailed(String error);

  /// No description provided for @filesUploadFile.
  ///
  /// In en, this message translates to:
  /// **'Upload File'**
  String get filesUploadFile;

  /// No description provided for @filesUploadHere.
  ///
  /// In en, this message translates to:
  /// **'Upload here'**
  String get filesUploadHere;

  /// No description provided for @filesUploadMedia.
  ///
  /// In en, this message translates to:
  /// **'Upload Media'**
  String get filesUploadMedia;

  /// No description provided for @filesUploadTo.
  ///
  /// In en, this message translates to:
  /// **'Upload to…'**
  String get filesUploadTo;

  /// No description provided for @filesUploadingChunks.
  ///
  /// In en, this message translates to:
  /// **'Uploading... {stored}/{total} chunks'**
  String filesUploadingChunks(int stored, int total);

  /// No description provided for @filesViewAsTooltip.
  ///
  /// In en, this message translates to:
  /// **'View as: {mode}'**
  String filesViewAsTooltip(String mode);

  /// No description provided for @filesViewIcons.
  ///
  /// In en, this message translates to:
  /// **'Icons'**
  String get filesViewIcons;

  /// No description provided for @filesViewList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get filesViewList;

  /// No description provided for @filesViewTree.
  ///
  /// In en, this message translates to:
  /// **'Tree'**
  String get filesViewTree;

  /// No description provided for @filesYourDrive.
  ///
  /// In en, this message translates to:
  /// **'your drive'**
  String get filesYourDrive;

  /// No description provided for @languageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'App display language'**
  String get languageSubtitle;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// No description provided for @linksCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Link copied to clipboard'**
  String get linksCopiedToClipboard;

  /// No description provided for @linksCopyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get linksCopyTooltip;

  /// No description provided for @linksDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This will remove the shared link for \"{name}\". The file itself won\'t be deleted.'**
  String linksDeleteBody(String name);

  /// No description provided for @linksDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed: {error}'**
  String linksDeleteFailed(String error);

  /// No description provided for @linksDeleteLink.
  ///
  /// In en, this message translates to:
  /// **'Delete link'**
  String get linksDeleteLink;

  /// No description provided for @linksDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete link?'**
  String get linksDeleteTitle;

  /// No description provided for @linksDeleted.
  ///
  /// In en, this message translates to:
  /// **'Link deleted'**
  String get linksDeleted;

  /// No description provided for @linksDownloadCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 download} other{{count} downloads}}'**
  String linksDownloadCount(int count);

  /// No description provided for @linksEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a link from any file\'s context menu'**
  String get linksEmptySubtitle;

  /// No description provided for @linksEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No shared links'**
  String get linksEmptyTitle;

  /// No description provided for @linksExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get linksExpired;

  /// No description provided for @linksExpiresInDays.
  ///
  /// In en, this message translates to:
  /// **'Expires in {days}d'**
  String linksExpiresInDays(int days);

  /// No description provided for @linksExpiresInHours.
  ///
  /// In en, this message translates to:
  /// **'Expires in {hours}h'**
  String linksExpiresInHours(int hours);

  /// No description provided for @linksExpiresSoon.
  ///
  /// In en, this message translates to:
  /// **'Expires soon'**
  String get linksExpiresSoon;

  /// No description provided for @linksExpiryRemoved.
  ///
  /// In en, this message translates to:
  /// **'Expiry removed — link never expires'**
  String get linksExpiryRemoved;

  /// No description provided for @linksExpiryUpdated.
  ///
  /// In en, this message translates to:
  /// **'Expiry updated'**
  String get linksExpiryUpdated;

  /// No description provided for @linksNotAuthenticated.
  ///
  /// In en, this message translates to:
  /// **'Not authenticated'**
  String get linksNotAuthenticated;

  /// No description provided for @linksRemoveExpiry.
  ///
  /// In en, this message translates to:
  /// **'Remove expiry'**
  String get linksRemoveExpiry;

  /// No description provided for @linksSetExpiry.
  ///
  /// In en, this message translates to:
  /// **'Set expiry'**
  String get linksSetExpiry;

  /// No description provided for @linksUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Update failed: {error}'**
  String linksUpdateFailed(String error);

  /// No description provided for @notesAuthorAnonymous.
  ///
  /// In en, this message translates to:
  /// **'Anonymous'**
  String get notesAuthorAnonymous;

  /// No description provided for @notesAuthorYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get notesAuthorYou;

  /// No description provided for @notesBlockquote.
  ///
  /// In en, this message translates to:
  /// **'Blockquote'**
  String get notesBlockquote;

  /// No description provided for @notesBold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get notesBold;

  /// No description provided for @notesBulletList.
  ///
  /// In en, this message translates to:
  /// **'Bullet list'**
  String get notesBulletList;

  /// No description provided for @notesCannotDecrypt.
  ///
  /// In en, this message translates to:
  /// **'Cannot decrypt file'**
  String get notesCannotDecrypt;

  /// No description provided for @notesCannotOpenNoKey.
  ///
  /// In en, this message translates to:
  /// **'Cannot open — decryption key unavailable'**
  String get notesCannotOpenNoKey;

  /// No description provided for @notesChunkCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 chunk} other{{count} chunks}}'**
  String notesChunkCount(int count);

  /// No description provided for @notesClearHistoryBody.
  ///
  /// In en, this message translates to:
  /// **'Every historical version of this note will be permanently deleted. The current note stays.'**
  String get notesClearHistoryBody;

  /// No description provided for @notesClearHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear all history?'**
  String get notesClearHistoryTitle;

  /// No description provided for @notesClearHistoryTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear all history'**
  String get notesClearHistoryTooltip;

  /// No description provided for @notesCloseEditor.
  ///
  /// In en, this message translates to:
  /// **'Close editor'**
  String get notesCloseEditor;

  /// No description provided for @notesCloseNote.
  ///
  /// In en, this message translates to:
  /// **'Close note'**
  String get notesCloseNote;

  /// No description provided for @notesCode.
  ///
  /// In en, this message translates to:
  /// **'Code block'**
  String get notesCode;

  /// No description provided for @notesConflictBody.
  ///
  /// In en, this message translates to:
  /// **'The server has an unfinished save for this note from another session. Overwriting will discard whatever that session was about to commit.'**
  String get notesConflictBody;

  /// No description provided for @notesConflictDiscardMine.
  ///
  /// In en, this message translates to:
  /// **'Drop my changes'**
  String get notesConflictDiscardMine;

  /// No description provided for @notesConflictOverwrite.
  ///
  /// In en, this message translates to:
  /// **'Discard remote, save mine'**
  String get notesConflictOverwrite;

  /// No description provided for @notesConflictTitle.
  ///
  /// In en, this message translates to:
  /// **'Another save is in progress'**
  String get notesConflictTitle;

  /// No description provided for @notesCreateFolderFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create folder: {error}'**
  String notesCreateFolderFailed(String error);

  /// No description provided for @notesCreateFolderIn.
  ///
  /// In en, this message translates to:
  /// **'Create a new folder in \"{folder}\"'**
  String notesCreateFolderIn(String folder);

  /// No description provided for @notesCreateFolderInRoot.
  ///
  /// In en, this message translates to:
  /// **'Create a new folder in root'**
  String get notesCreateFolderInRoot;

  /// No description provided for @notesCreateHere.
  ///
  /// In en, this message translates to:
  /// **'Create here'**
  String get notesCreateHere;

  /// No description provided for @notesCreateNoteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create note: {error}'**
  String notesCreateNoteFailed(String error);

  /// No description provided for @notesCreateNoteIn.
  ///
  /// In en, this message translates to:
  /// **'Create a new note in \"{folder}\"'**
  String notesCreateNoteIn(String folder);

  /// No description provided for @notesCreateNoteInRoot.
  ///
  /// In en, this message translates to:
  /// **'Create a new note in root'**
  String get notesCreateNoteInRoot;

  /// No description provided for @notesCreatedNote.
  ///
  /// In en, this message translates to:
  /// **'Created \"{name}\"'**
  String notesCreatedNote(String name);

  /// No description provided for @notesCreatedNoteMissingKey.
  ///
  /// In en, this message translates to:
  /// **'Created note missing encryption key'**
  String get notesCreatedNoteMissingKey;

  /// No description provided for @notesDeleteAll.
  ///
  /// In en, this message translates to:
  /// **'Delete all'**
  String get notesDeleteAll;

  /// No description provided for @notesDeleteFolderBody.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" and everything inside it will be permanently deleted.'**
  String notesDeleteFolderBody(String name);

  /// No description provided for @notesDeleteFolderFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete folder: {error}'**
  String notesDeleteFolderFailed(String error);

  /// No description provided for @notesDeleteFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete folder?'**
  String get notesDeleteFolderTitle;

  /// No description provided for @notesDeleteNoteBody.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" will be permanently deleted.'**
  String notesDeleteNoteBody(String name);

  /// No description provided for @notesDeleteNoteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete: {error}'**
  String notesDeleteNoteFailed(String error);

  /// No description provided for @notesDeleteNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete note?'**
  String get notesDeleteNoteTitle;

  /// No description provided for @notesDeleteThisVersion.
  ///
  /// In en, this message translates to:
  /// **'Delete this version'**
  String get notesDeleteThisVersion;

  /// No description provided for @notesDeleteVersionFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed: {error}'**
  String notesDeleteVersionFailed(String error);

  /// No description provided for @notesDeleteVersionMsg.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete v{version} from {date}. Cannot be undone.'**
  String notesDeleteVersionMsg(int version, String date);

  /// No description provided for @notesDeleteVersionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete v{version}?'**
  String notesDeleteVersionTitle(int version);

  /// No description provided for @notesDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get notesDetails;

  /// No description provided for @notesDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get notesDiscard;

  /// No description provided for @notesEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Create one from the sidebar\'s + button.'**
  String get notesEmptyHint;

  /// No description provided for @notesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No notes yet'**
  String get notesEmptyTitle;

  /// No description provided for @notesEncryptedFallback.
  ///
  /// In en, this message translates to:
  /// **'[Encrypted] {id}…'**
  String notesEncryptedFallback(String id);

  /// No description provided for @notesEncryptedName.
  ///
  /// In en, this message translates to:
  /// **'(encrypted)'**
  String get notesEncryptedName;

  /// No description provided for @notesExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get notesExport;

  /// No description provided for @notesExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String notesExportFailed(String error);

  /// No description provided for @notesExportStarted.
  ///
  /// In en, this message translates to:
  /// **'Export started — share sheet will open when ready'**
  String get notesExportStarted;

  /// No description provided for @notesExportToPdf.
  ///
  /// In en, this message translates to:
  /// **'Export to PDF'**
  String get notesExportToPdf;

  /// No description provided for @notesExportingTo.
  ///
  /// In en, this message translates to:
  /// **'Exporting to {path}'**
  String notesExportingTo(String path);

  /// No description provided for @notesFileNotFound.
  ///
  /// In en, this message translates to:
  /// **'File not found'**
  String get notesFileNotFound;

  /// No description provided for @notesFolderName.
  ///
  /// In en, this message translates to:
  /// **'folder'**
  String get notesFolderName;

  /// No description provided for @notesFolderNameHint.
  ///
  /// In en, this message translates to:
  /// **'My folder'**
  String get notesFolderNameHint;

  /// No description provided for @notesForkFailed.
  ///
  /// In en, this message translates to:
  /// **'Fork failed: {error}'**
  String notesForkFailed(String error);

  /// No description provided for @notesHeading.
  ///
  /// In en, this message translates to:
  /// **'Heading {level}'**
  String notesHeading(int level);

  /// No description provided for @notesHideSidebar.
  ///
  /// In en, this message translates to:
  /// **'Hide sidebar'**
  String get notesHideSidebar;

  /// No description provided for @notesHideKeyboard.
  ///
  /// In en, this message translates to:
  /// **'Hide keyboard'**
  String get notesHideKeyboard;

  /// No description provided for @notesHistory.
  ///
  /// In en, this message translates to:
  /// **'Version history'**
  String get notesHistory;

  /// No description provided for @notesHistoryNamed.
  ///
  /// In en, this message translates to:
  /// **'History · {name}'**
  String notesHistoryNamed(String name);

  /// No description provided for @notesItalic.
  ///
  /// In en, this message translates to:
  /// **'Italic'**
  String get notesItalic;

  /// No description provided for @notesKeyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Cannot decrypt — file key or client unavailable'**
  String get notesKeyUnavailable;

  /// No description provided for @notesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load'**
  String get notesLoadFailed;

  /// No description provided for @notesLoadNotesFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load notes: {error}'**
  String notesLoadNotesFailed(String error);

  /// No description provided for @notesMetadataUnavailable.
  ///
  /// In en, this message translates to:
  /// **'File metadata unavailable'**
  String get notesMetadataUnavailable;

  /// No description provided for @notesModified.
  ///
  /// In en, this message translates to:
  /// **'Modified {when}'**
  String notesModified(String when);

  /// No description provided for @notesMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get notesMore;

  /// No description provided for @notesMoreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get notesMoreActions;

  /// No description provided for @notesMoveFailed.
  ///
  /// In en, this message translates to:
  /// **'Move failed: {error}'**
  String notesMoveFailed(String error);

  /// No description provided for @notesMoveHere.
  ///
  /// In en, this message translates to:
  /// **'Move here'**
  String get notesMoveHere;

  /// No description provided for @notesMoveToTitle.
  ///
  /// In en, this message translates to:
  /// **'Move to'**
  String get notesMoveToTitle;

  /// No description provided for @notesMoved.
  ///
  /// In en, this message translates to:
  /// **'Moved'**
  String get notesMoved;

  /// No description provided for @notesNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get notesNameRequired;

  /// No description provided for @notesNewFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get notesNewFolder;

  /// No description provided for @notesNewIn.
  ///
  /// In en, this message translates to:
  /// **'New note or folder in {name}'**
  String notesNewIn(String name);

  /// No description provided for @notesNewNote.
  ///
  /// In en, this message translates to:
  /// **'New note'**
  String get notesNewNote;

  /// No description provided for @notesNoHistory.
  ///
  /// In en, this message translates to:
  /// **'No history yet. Edit the note to start building one.'**
  String get notesNoHistory;

  /// No description provided for @notesNoServerId.
  ///
  /// In en, this message translates to:
  /// **'Server returned no id'**
  String get notesNoServerId;

  /// No description provided for @notesNotAuthenticated.
  ///
  /// In en, this message translates to:
  /// **'Not authenticated'**
  String get notesNotAuthenticated;

  /// No description provided for @notesNotSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get notesNotSignedIn;

  /// No description provided for @notesNoteNameHint.
  ///
  /// In en, this message translates to:
  /// **'My note'**
  String get notesNoteNameHint;

  /// No description provided for @notesNumberedList.
  ///
  /// In en, this message translates to:
  /// **'Numbered list'**
  String get notesNumberedList;

  /// No description provided for @notesPdfExportFailed.
  ///
  /// In en, this message translates to:
  /// **'PDF export failed: {error}'**
  String notesPdfExportFailed(String error);

  /// No description provided for @notesPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get notesPreview;

  /// No description provided for @notesPreviewFailed.
  ///
  /// In en, this message translates to:
  /// **'Preview failed: {error}'**
  String notesPreviewFailed(String error);

  /// No description provided for @notesPurgeFailed.
  ///
  /// In en, this message translates to:
  /// **'Purge failed: {error}'**
  String notesPurgeFailed(String error);

  /// No description provided for @notesRecentHeader.
  ///
  /// In en, this message translates to:
  /// **'Recent notes'**
  String get notesRecentHeader;

  /// No description provided for @notesRedo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get notesRedo;

  /// No description provided for @notesRenameFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to rename: {error}'**
  String notesRenameFailed(String error);

  /// No description provided for @notesRenameFolderFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to rename folder: {error}'**
  String notesRenameFolderFailed(String error);

  /// No description provided for @notesRenameNote.
  ///
  /// In en, this message translates to:
  /// **'Rename note'**
  String get notesRenameNote;

  /// No description provided for @notesResetZoom.
  ///
  /// In en, this message translates to:
  /// **'Reset zoom'**
  String get notesResetZoom;

  /// No description provided for @notesRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get notesRestore;

  /// No description provided for @notesRestoreAsNew.
  ///
  /// In en, this message translates to:
  /// **'Restore as new note'**
  String get notesRestoreAsNew;

  /// No description provided for @notesRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed: {error}'**
  String notesRestoreFailed(String error);

  /// No description provided for @notesRestoreHere.
  ///
  /// In en, this message translates to:
  /// **'Restore in place'**
  String get notesRestoreHere;

  /// No description provided for @notesRestoreThisVersion.
  ///
  /// In en, this message translates to:
  /// **'Restore this version'**
  String get notesRestoreThisVersion;

  /// No description provided for @notesRestoreVersionMsg.
  ///
  /// In en, this message translates to:
  /// **'This replaces the current content with v{version} from {date}. Your current version stays in history so you can undo the restore later.'**
  String notesRestoreVersionMsg(int version, String date);

  /// No description provided for @notesRestoreVersionTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore v{version}?'**
  String notesRestoreVersionTitle(int version);

  /// No description provided for @notesRestoredVersion.
  ///
  /// In en, this message translates to:
  /// **'Restored v{version}'**
  String notesRestoredVersion(int version);

  /// No description provided for @notesRootName.
  ///
  /// In en, this message translates to:
  /// **'root'**
  String get notesRootName;

  /// No description provided for @notesSaveAndClose.
  ///
  /// In en, this message translates to:
  /// **'Save & close'**
  String get notesSaveAndClose;

  /// No description provided for @notesSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save: {error}'**
  String notesSaveFailed(String error);

  /// No description provided for @notesSaveNoteDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Save note'**
  String get notesSaveNoteDialogTitle;

  /// No description provided for @notesShowSidebar.
  ///
  /// In en, this message translates to:
  /// **'Show sidebar'**
  String get notesShowSidebar;

  /// No description provided for @notesSidebarEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notes or folders'**
  String get notesSidebarEmpty;

  /// No description provided for @notesSidebarHeader.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notesSidebarHeader;

  /// No description provided for @notesStillUploading.
  ///
  /// In en, this message translates to:
  /// **'This note is still uploading. If it stays stuck, delete it from the Files tab and create a new one.'**
  String get notesStillUploading;

  /// No description provided for @notesStrikethrough.
  ///
  /// In en, this message translates to:
  /// **'Strikethrough'**
  String get notesStrikethrough;

  /// No description provided for @notesTable.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get notesTable;

  /// No description provided for @notesTaskList.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get notesTaskList;

  /// No description provided for @notesThisFolder.
  ///
  /// In en, this message translates to:
  /// **'this folder'**
  String get notesThisFolder;

  /// No description provided for @notesThisNote.
  ///
  /// In en, this message translates to:
  /// **'this note'**
  String get notesThisNote;

  /// No description provided for @notesTitle.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notesTitle;

  /// No description provided for @notesUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get notesUndo;

  /// No description provided for @notesUnsavedChangesBody.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. What would you like to do?'**
  String get notesUnsavedChangesBody;

  /// No description provided for @notesUnsavedChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes — {name}'**
  String notesUnsavedChangesTitle(String name);

  /// No description provided for @notesUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get notesUntitled;

  /// No description provided for @notesZoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get notesZoomIn;

  /// No description provided for @notesZoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get notesZoomOut;

  /// No description provided for @previewCannotDecrypt.
  ///
  /// In en, this message translates to:
  /// **'Cannot decrypt file'**
  String get previewCannotDecrypt;

  /// No description provided for @previewDecryptAfterDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to decrypt after download'**
  String get previewDecryptAfterDownloadFailed;

  /// No description provided for @previewDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete: {error}'**
  String previewDeleteFailed(String error);

  /// No description provided for @previewDeleteFileBody.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? This cannot be undone.'**
  String previewDeleteFileBody(String name);

  /// No description provided for @previewDeleteFileTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete file?'**
  String get previewDeleteFileTitle;

  /// No description provided for @previewDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get previewDownloadFailed;

  /// No description provided for @previewExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get previewExport;

  /// No description provided for @previewFailedToLoadImage.
  ///
  /// In en, this message translates to:
  /// **'Failed to load image'**
  String get previewFailedToLoadImage;

  /// No description provided for @previewFailedToRenderPage.
  ///
  /// In en, this message translates to:
  /// **'Failed to render page: {error}'**
  String previewFailedToRenderPage(String error);

  /// No description provided for @previewNoPreviewAvailable.
  ///
  /// In en, this message translates to:
  /// **'No preview available'**
  String get previewNoPreviewAvailable;

  /// No description provided for @previewNoPreviewableFiles.
  ///
  /// In en, this message translates to:
  /// **'No previewable files'**
  String get previewNoPreviewableFiles;

  /// No description provided for @previewPageCounter.
  ///
  /// In en, this message translates to:
  /// **'Page {current} / {total}'**
  String previewPageCounter(int current, int total);

  /// No description provided for @previewSaveFileTitle.
  ///
  /// In en, this message translates to:
  /// **'Save file'**
  String get previewSaveFileTitle;

  /// No description provided for @previewShowingFirstMb.
  ///
  /// In en, this message translates to:
  /// **'Showing first 1 MB of {size}'**
  String previewShowingFirstMb(String size);

  /// No description provided for @relativeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String relativeDaysAgo(int days);

  /// No description provided for @relativeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String relativeHoursAgo(int hours);

  /// No description provided for @relativeJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get relativeJustNow;

  /// No description provided for @relativeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String relativeMinutesAgo(int minutes);

  /// No description provided for @searchEmptyPrompt.
  ///
  /// In en, this message translates to:
  /// **'Search your files'**
  String get searchEmptyPrompt;

  /// No description provided for @searchEncryptedFileFallback.
  ///
  /// In en, this message translates to:
  /// **'[Encrypted] {id}...'**
  String searchEncryptedFileFallback(String id);

  /// No description provided for @searchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed: {error}'**
  String searchFailed(String error);

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search files and notes…'**
  String get searchHint;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get searchNoResults;

  /// No description provided for @serviceBugReportShareText.
  ///
  /// In en, this message translates to:
  /// **'Please describe what you were doing when the bug happened, including any steps to reproduce.\n\nSend to: {email}'**
  String serviceBugReportShareText(String email);

  /// No description provided for @serviceBugReportSubject.
  ///
  /// In en, this message translates to:
  /// **'Hoodik bug report'**
  String get serviceBugReportSubject;

  /// No description provided for @serviceDownloadCancelled.
  ///
  /// In en, this message translates to:
  /// **'Download cancelled'**
  String get serviceDownloadCancelled;

  /// No description provided for @serviceDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get serviceDownloadFailed;

  /// No description provided for @serviceFileAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'File already exists'**
  String get serviceFileAlreadyExists;

  /// No description provided for @serviceFileNoEncryptionKey.
  ///
  /// In en, this message translates to:
  /// **'File has no encryption key'**
  String get serviceFileNoEncryptionKey;

  /// No description provided for @serviceLandingBranchFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get serviceLandingBranchFiles;

  /// No description provided for @serviceLandingBranchNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get serviceLandingBranchNotes;

  /// No description provided for @serviceNotificationDownloadComplete.
  ///
  /// In en, this message translates to:
  /// **'Download complete'**
  String get serviceNotificationDownloadComplete;

  /// No description provided for @serviceNotificationReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get serviceNotificationReady;

  /// No description provided for @serviceNotificationUploadComplete.
  ///
  /// In en, this message translates to:
  /// **'Upload complete'**
  String get serviceNotificationUploadComplete;

  /// No description provided for @serviceOfflineManagerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Offline manager not available'**
  String get serviceOfflineManagerUnavailable;

  /// No description provided for @serviceThemeModeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get serviceThemeModeDark;

  /// No description provided for @serviceThemeModeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get serviceThemeModeLight;

  /// No description provided for @serviceThemeModeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get serviceThemeModeSystem;

  /// No description provided for @serviceTransferCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get serviceTransferCancelled;

  /// No description provided for @serviceTransferDecrypting.
  ///
  /// In en, this message translates to:
  /// **'Decrypting'**
  String get serviceTransferDecrypting;

  /// No description provided for @serviceTransferDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get serviceTransferDownloading;

  /// No description provided for @serviceTransferEncrypting.
  ///
  /// In en, this message translates to:
  /// **'Encrypting'**
  String get serviceTransferEncrypting;

  /// No description provided for @serviceTransferUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading'**
  String get serviceTransferUploading;

  /// No description provided for @serviceUploadCancelled.
  ///
  /// In en, this message translates to:
  /// **'Upload cancelled'**
  String get serviceUploadCancelled;

  /// No description provided for @serviceUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed'**
  String get serviceUploadFailed;

  /// No description provided for @serviceUploadWorkerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Upload requires an active encrypt worker and tar transport. Please restart the app and try again.'**
  String get serviceUploadWorkerUnavailable;

  /// No description provided for @sharesAccessRevoked.
  ///
  /// In en, this message translates to:
  /// **'Access revoked'**
  String get sharesAccessRevoked;

  /// No description provided for @sharesAccessRevokedFor.
  ///
  /// In en, this message translates to:
  /// **'Access revoked for {email}'**
  String sharesAccessRevokedFor(String email);

  /// No description provided for @sharesAddFiles.
  ///
  /// In en, this message translates to:
  /// **'Add files'**
  String get sharesAddFiles;

  /// No description provided for @sharesAddMember.
  ///
  /// In en, this message translates to:
  /// **'Add member'**
  String get sharesAddMember;

  /// No description provided for @sharesAddMemberFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to add member: {error}'**
  String sharesAddMemberFailed(String error);

  /// No description provided for @sharesAddMemberToGroup.
  ///
  /// In en, this message translates to:
  /// **'Add member to {group}'**
  String sharesAddMemberToGroup(String group);

  /// No description provided for @sharesAddedByCoOwner.
  ///
  /// In en, this message translates to:
  /// **'Added by co-owner'**
  String get sharesAddedByCoOwner;

  /// No description provided for @sharesAddedByOwner.
  ///
  /// In en, this message translates to:
  /// **'Added by owner'**
  String get sharesAddedByOwner;

  /// No description provided for @sharesAddedByUnknown.
  ///
  /// In en, this message translates to:
  /// **'Added by unknown'**
  String get sharesAddedByUnknown;

  /// No description provided for @sharesAllowAddFiles.
  ///
  /// In en, this message translates to:
  /// **'Allow them to add new files'**
  String get sharesAllowAddFiles;

  /// No description provided for @sharesAuditARecipient.
  ///
  /// In en, this message translates to:
  /// **'a recipient'**
  String get sharesAuditARecipient;

  /// No description provided for @sharesAuditARecipientCapital.
  ///
  /// In en, this message translates to:
  /// **'A recipient'**
  String get sharesAuditARecipientCapital;

  /// No description provided for @sharesAuditAccessFallback.
  ///
  /// In en, this message translates to:
  /// **'access'**
  String get sharesAuditAccessFallback;

  /// No description provided for @sharesAuditBadgeMismatch.
  ///
  /// In en, this message translates to:
  /// **'Mismatch'**
  String get sharesAuditBadgeMismatch;

  /// No description provided for @sharesAuditBadgeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get sharesAuditBadgeSystem;

  /// No description provided for @sharesAuditBadgeVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get sharesAuditBadgeVerified;

  /// No description provided for @sharesAuditCoOwnerRevoked.
  ///
  /// In en, this message translates to:
  /// **'{recipient}\'s access to {file} via a co-owner was revoked'**
  String sharesAuditCoOwnerRevoked(String recipient, String file);

  /// No description provided for @sharesAuditEdited.
  ///
  /// In en, this message translates to:
  /// **'{sender} edited shared file {file}'**
  String sharesAuditEdited(String sender, String file);

  /// No description provided for @sharesAuditEmpty.
  ///
  /// In en, this message translates to:
  /// **'No sharing activity yet. Events show up here when you share a file, change a role, or revoke access.'**
  String get sharesAuditEmpty;

  /// No description provided for @sharesAuditEvicted.
  ///
  /// In en, this message translates to:
  /// **'{recipient} lost access to {file} (cascade)'**
  String sharesAuditEvicted(String recipient, String file);

  /// No description provided for @sharesAuditFileIdLabel.
  ///
  /// In en, this message translates to:
  /// **'file {head}…'**
  String sharesAuditFileIdLabel(String head);

  /// No description provided for @sharesAuditForked.
  ///
  /// In en, this message translates to:
  /// **'{sender} forked {file} into their drive'**
  String sharesAuditForked(String sender, String file);

  /// No description provided for @sharesAuditGrant.
  ///
  /// In en, this message translates to:
  /// **'{sender} shared {file} with {recipient}'**
  String sharesAuditGrant(String sender, String file, String recipient);

  /// No description provided for @sharesAuditGrantAsRole.
  ///
  /// In en, this message translates to:
  /// **'{sender} shared {file} with {recipient} as {role}'**
  String sharesAuditGrantAsRole(
    String sender,
    String file,
    String recipient,
    String role,
  );

  /// No description provided for @sharesAuditKeyRotation.
  ///
  /// In en, this message translates to:
  /// **'{sender} rotated their account encryption keys'**
  String sharesAuditKeyRotation(String sender);

  /// No description provided for @sharesAuditLegendMismatch.
  ///
  /// In en, this message translates to:
  /// **'failed verification — do not trust this row'**
  String get sharesAuditLegendMismatch;

  /// No description provided for @sharesAuditLegendSystem.
  ///
  /// In en, this message translates to:
  /// **'a server-attributed cascade event, no signature'**
  String get sharesAuditLegendSystem;

  /// No description provided for @sharesAuditLegendVerified.
  ///
  /// In en, this message translates to:
  /// **'signature and chain check out'**
  String get sharesAuditLegendVerified;

  /// No description provided for @sharesAuditLinkBroken.
  ///
  /// In en, this message translates to:
  /// **'Chain link to the previous visible event is broken.'**
  String get sharesAuditLinkBroken;

  /// No description provided for @sharesAuditLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your sharing activity.'**
  String get sharesAuditLoadFailed;

  /// No description provided for @sharesAuditLoadFailedOffline.
  ///
  /// In en, this message translates to:
  /// **'Could not load your sharing activity. Activity needs a connection to the server — try again once you are back online.'**
  String get sharesAuditLoadFailedOffline;

  /// No description provided for @sharesAuditMovedOut.
  ///
  /// In en, this message translates to:
  /// **'{sender} moved {file} out of a shared folder'**
  String sharesAuditMovedOut(String sender, String file);

  /// No description provided for @sharesAuditPageBoundaryNote.
  ///
  /// In en, this message translates to:
  /// **'Earlier event in this chain is on another page'**
  String get sharesAuditPageBoundaryNote;

  /// No description provided for @sharesAuditRecipientFallback.
  ///
  /// In en, this message translates to:
  /// **'recipient'**
  String get sharesAuditRecipientFallback;

  /// No description provided for @sharesAuditReshared.
  ///
  /// In en, this message translates to:
  /// **'{sender} re-shared {file} with {recipient}'**
  String sharesAuditReshared(String sender, String file, String recipient);

  /// No description provided for @sharesAuditResharedAsRole.
  ///
  /// In en, this message translates to:
  /// **'{sender} re-shared {file} with {recipient} as {role}'**
  String sharesAuditResharedAsRole(
    String sender,
    String file,
    String recipient,
    String role,
  );

  /// No description provided for @sharesAuditRestored.
  ///
  /// In en, this message translates to:
  /// **'{sender} restored a previous version of shared file {file}'**
  String sharesAuditRestored(String sender, String file);

  /// No description provided for @sharesAuditRevoked.
  ///
  /// In en, this message translates to:
  /// **'{sender} revoked {recipient} from {file}'**
  String sharesAuditRevoked(String sender, String recipient, String file);

  /// No description provided for @sharesAuditRoleChanged.
  ///
  /// In en, this message translates to:
  /// **'{sender} changed {recipient}\'s role on {file}'**
  String sharesAuditRoleChanged(String sender, String recipient, String file);

  /// No description provided for @sharesAuditRoleChangedFromTo.
  ///
  /// In en, this message translates to:
  /// **'{sender} changed {recipient}\'s role on {file} from {before} to {after}'**
  String sharesAuditRoleChangedFromTo(
    String sender,
    String recipient,
    String file,
    String before,
    String after,
  );

  /// No description provided for @sharesAuditSelfHashMismatch.
  ///
  /// In en, this message translates to:
  /// **'Row content does not match its stored hash.'**
  String get sharesAuditSelfHashMismatch;

  /// No description provided for @sharesAuditShowingRecent.
  ///
  /// In en, this message translates to:
  /// **'Showing the {shown} most recent of {total} events.'**
  String sharesAuditShowingRecent(int shown, int total);

  /// No description provided for @sharesAuditSignatureFailed.
  ///
  /// In en, this message translates to:
  /// **'Signature failed verification on this event.'**
  String get sharesAuditSignatureFailed;

  /// No description provided for @sharesAuditSystemSender.
  ///
  /// In en, this message translates to:
  /// **'system'**
  String get sharesAuditSystemSender;

  /// No description provided for @sharesAuditTamperedBody.
  ///
  /// In en, this message translates to:
  /// **'This event failed verification. Treat its claim with suspicion and report it to the file owner.'**
  String get sharesAuditTamperedBody;

  /// No description provided for @sharesAuditUploaded.
  ///
  /// In en, this message translates to:
  /// **'{sender} uploaded into shared folder {file}'**
  String sharesAuditUploaded(String sender, String file);

  /// No description provided for @sharesCannotAddSelfToGroup.
  ///
  /// In en, this message translates to:
  /// **'You cannot add yourself to a group.'**
  String get sharesCannotAddSelfToGroup;

  /// No description provided for @sharesCannotDecryptFileKey.
  ///
  /// In en, this message translates to:
  /// **'Cannot decrypt the file key'**
  String get sharesCannotDecryptFileKey;

  /// No description provided for @sharesCannotShareWithSelf.
  ///
  /// In en, this message translates to:
  /// **'You can\'t share with yourself.'**
  String get sharesCannotShareWithSelf;

  /// No description provided for @sharesChangeRole.
  ///
  /// In en, this message translates to:
  /// **'Change role'**
  String get sharesChangeRole;

  /// No description provided for @sharesDeleteGroup.
  ///
  /// In en, this message translates to:
  /// **'Delete group'**
  String get sharesDeleteGroup;

  /// No description provided for @sharesDeleteGroupBody.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? Files you already shared with these people stay shared; the group is just removed as a saved selection.'**
  String sharesDeleteGroupBody(String name);

  /// No description provided for @sharesDeleteGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete group?'**
  String get sharesDeleteGroupTitle;

  /// No description provided for @sharesDestinationIsShared.
  ///
  /// In en, this message translates to:
  /// **'The destination is itself a shared folder. Pick a private folder or your drive root.'**
  String get sharesDestinationIsShared;

  /// No description provided for @sharesEmailPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'someone@example.com'**
  String get sharesEmailPlaceholder;

  /// No description provided for @sharesEmailUnknownCannotChangeRole.
  ///
  /// In en, this message translates to:
  /// **'Email unknown — cannot change role'**
  String get sharesEmailUnknownCannotChangeRole;

  /// No description provided for @sharesEnterMemberEmailFirst.
  ///
  /// In en, this message translates to:
  /// **'Enter the member email first.'**
  String get sharesEnterMemberEmailFirst;

  /// No description provided for @sharesEnterRecipientEmailFirst.
  ///
  /// In en, this message translates to:
  /// **'Enter the recipient email first.'**
  String get sharesEnterRecipientEmailFirst;

  /// No description provided for @sharesEveryoneCanRead.
  ///
  /// In en, this message translates to:
  /// **'Everyone listed will be able to read every file in this folder.'**
  String get sharesEveryoneCanRead;

  /// No description provided for @sharesEvictFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to evict: {error}'**
  String sharesEvictFailed(String error);

  /// No description provided for @sharesFindUser.
  ///
  /// In en, this message translates to:
  /// **'Find user'**
  String get sharesFindUser;

  /// No description provided for @sharesGiveGroupName.
  ///
  /// In en, this message translates to:
  /// **'Give the group a name.'**
  String get sharesGiveGroupName;

  /// No description provided for @sharesGroupCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create the group: {error}'**
  String sharesGroupCreateFailed(String error);

  /// No description provided for @sharesGroupDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete the group.'**
  String get sharesGroupDeleteFailed;

  /// No description provided for @sharesGroupDeleted.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" deleted.'**
  String sharesGroupDeleted(String name);

  /// No description provided for @sharesGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get sharesGroupLabel;

  /// No description provided for @sharesGroupMemberKeyUnverified.
  ///
  /// In en, this message translates to:
  /// **'A group member\'s key could not be verified — refusing to share. ({email})'**
  String sharesGroupMemberKeyUnverified(String email);

  /// No description provided for @sharesGroupNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get sharesGroupNameLabel;

  /// No description provided for @sharesGroupNamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'e.g. Marketing team'**
  String get sharesGroupNamePlaceholder;

  /// No description provided for @sharesGroupNameTaken.
  ///
  /// In en, this message translates to:
  /// **'A group with that name already exists.'**
  String get sharesGroupNameTaken;

  /// No description provided for @sharesGroupNoOneElse.
  ///
  /// In en, this message translates to:
  /// **'This group has no one else to share with yet.'**
  String get sharesGroupNoOneElse;

  /// No description provided for @sharesGroupReady.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" is ready to receive members.'**
  String sharesGroupReady(String name);

  /// No description provided for @sharesGroupRenameFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not rename the group: {error}'**
  String sharesGroupRenameFailed(String error);

  /// No description provided for @sharesGroupRoleCoOwnerDescription.
  ///
  /// In en, this message translates to:
  /// **'Co-owner — can also manage members and rename.'**
  String get sharesGroupRoleCoOwnerDescription;

  /// No description provided for @sharesGroupRoleEditorDescription.
  ///
  /// In en, this message translates to:
  /// **'Editor — can share files to the group.'**
  String get sharesGroupRoleEditorDescription;

  /// No description provided for @sharesGroupRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Group role'**
  String get sharesGroupRoleLabel;

  /// No description provided for @sharesGroupRoleOwnerDescription.
  ///
  /// In en, this message translates to:
  /// **'Owner — full control of the group.'**
  String get sharesGroupRoleOwnerDescription;

  /// No description provided for @sharesGroupRoleReaderDescription.
  ///
  /// In en, this message translates to:
  /// **'Reader — sees the group, nothing more.'**
  String get sharesGroupRoleReaderDescription;

  /// No description provided for @sharesGroupsExplainer.
  ///
  /// In en, this message translates to:
  /// **'Groups let you share with everyone in the group at once.'**
  String get sharesGroupsExplainer;

  /// No description provided for @sharesGroupsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load your groups.'**
  String get sharesGroupsLoadFailed;

  /// No description provided for @sharesInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'That doesn’t look like an email address.'**
  String get sharesInvalidEmail;

  /// No description provided for @sharesItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String sharesItemCount(int count);

  /// No description provided for @sharesKeyFingerprintMismatch.
  ///
  /// In en, this message translates to:
  /// **'This account\'s key and fingerprint do not match. Sharing is blocked — do not proceed.'**
  String get sharesKeyFingerprintMismatch;

  /// No description provided for @sharesLookupFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not look up that user.'**
  String get sharesLookupFailed;

  /// No description provided for @sharesMemberAddedToGroup.
  ///
  /// In en, this message translates to:
  /// **'{email} is now part of \"{group}\".'**
  String sharesMemberAddedToGroup(String email, String group);

  /// No description provided for @sharesMemberCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 member} other{{count} members}}'**
  String sharesMemberCount(int count);

  /// No description provided for @sharesMemberEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Member email'**
  String get sharesMemberEmailLabel;

  /// No description provided for @sharesMemberNowRole.
  ///
  /// In en, this message translates to:
  /// **'{email} is now {role}.'**
  String sharesMemberNowRole(String email, String role);

  /// No description provided for @sharesMemberOfHeader.
  ///
  /// In en, this message translates to:
  /// **'MEMBER OF'**
  String get sharesMemberOfHeader;

  /// No description provided for @sharesMemberRemoveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not remove the member.'**
  String get sharesMemberRemoveFailed;

  /// No description provided for @sharesMemberRemoved.
  ///
  /// In en, this message translates to:
  /// **'Member removed.'**
  String get sharesMemberRemoved;

  /// No description provided for @sharesMemberRoleChangeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not change the member\'s role.'**
  String get sharesMemberRoleChangeFailed;

  /// No description provided for @sharesMembersCount.
  ///
  /// In en, this message translates to:
  /// **'Members ({count})'**
  String sharesMembersCount(int count);

  /// No description provided for @sharesMembersLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the member list.'**
  String get sharesMembersLoadFailed;

  /// No description provided for @sharesMembersLoadFailedOffline.
  ///
  /// In en, this message translates to:
  /// **'Could not load the member list. The roster needs a connection to the server — try again once you are back online.'**
  String get sharesMembersLoadFailedOffline;

  /// No description provided for @sharesMembersTitle.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get sharesMembersTitle;

  /// No description provided for @sharesMismatchAcknowledge.
  ///
  /// In en, this message translates to:
  /// **'I\'ve verified this new fingerprint with the recipient out of band.'**
  String get sharesMismatchAcknowledge;

  /// No description provided for @sharesMoveAndShare.
  ///
  /// In en, this message translates to:
  /// **'Move and share'**
  String get sharesMoveAndShare;

  /// No description provided for @sharesMoveAndShareTitle.
  ///
  /// In en, this message translates to:
  /// **'Move and share folder?'**
  String get sharesMoveAndShareTitle;

  /// No description provided for @sharesMoveCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check where these items live. Check your connection and try again.'**
  String get sharesMoveCheckFailed;

  /// No description provided for @sharesMoveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to move: {error}'**
  String sharesMoveFailed(String error);

  /// No description provided for @sharesMoveWillMove.
  ///
  /// In en, this message translates to:
  /// **'Moving \"{folder}\" into \"{destination}\" will move it and its {items}.'**
  String sharesMoveWillMove(String folder, String destination, String items);

  /// No description provided for @sharesMoveWillShare.
  ///
  /// In en, this message translates to:
  /// **'Moving \"{folder}\" into \"{destination}\" will share it and its {items} with {members}.'**
  String sharesMoveWillShare(
    String folder,
    String destination,
    String items,
    String members,
  );

  /// No description provided for @sharesMovedItems.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Moved 1 item} other{Moved {count} items}}'**
  String sharesMovedItems(int count);

  /// No description provided for @sharesNamesAndOthers.
  ///
  /// In en, this message translates to:
  /// **'{first}, {second} and {count} others'**
  String sharesNamesAndOthers(String first, String second, int count);

  /// No description provided for @sharesNewGroup.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get sharesNewGroup;

  /// No description provided for @sharesNewShareGroup.
  ///
  /// In en, this message translates to:
  /// **'New share group'**
  String get sharesNewShareGroup;

  /// No description provided for @sharesNoAccessYet.
  ///
  /// In en, this message translates to:
  /// **'No one has access yet.'**
  String get sharesNoAccessYet;

  /// No description provided for @sharesNoLongerHaveAccess.
  ///
  /// In en, this message translates to:
  /// **'You no longer have access to this folder.'**
  String get sharesNoLongerHaveAccess;

  /// No description provided for @sharesNoMemberOfGroups.
  ///
  /// In en, this message translates to:
  /// **'No one has added you to a group yet.'**
  String get sharesNoMemberOfGroups;

  /// No description provided for @sharesNoMembersYet.
  ///
  /// In en, this message translates to:
  /// **'No members yet — add someone to share with this group.'**
  String get sharesNoMembersYet;

  /// No description provided for @sharesNoOwnedGroups.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t created any groups yet. Groups let you share with several people at once.'**
  String get sharesNoOwnedGroups;

  /// No description provided for @sharesNoUserWithEmail.
  ///
  /// In en, this message translates to:
  /// **'No Hoodik user with that email.'**
  String get sharesNoUserWithEmail;

  /// No description provided for @sharesNotAuthenticated.
  ///
  /// In en, this message translates to:
  /// **'Not authenticated.'**
  String get sharesNotAuthenticated;

  /// No description provided for @sharesNotGroupEditor.
  ///
  /// In en, this message translates to:
  /// **'You\'re not an editor of any group yet. Create a group or ask its owner to make you an editor.'**
  String get sharesNotGroupEditor;

  /// No description provided for @sharesOnlyOwnedIntoShared.
  ///
  /// In en, this message translates to:
  /// **'You can only move files you own into a shared folder.'**
  String get sharesOnlyOwnedIntoShared;

  /// No description provided for @sharesOnlyOwnerCanMoveOut.
  ///
  /// In en, this message translates to:
  /// **'Only the owner can move a file out of a shared folder.'**
  String get sharesOnlyOwnerCanMoveOut;

  /// No description provided for @sharesOnlyOwnerCanMoveThisOut.
  ///
  /// In en, this message translates to:
  /// **'Only the owner can move this file out of the shared folder.'**
  String get sharesOnlyOwnerCanMoveThisOut;

  /// No description provided for @sharesOwnedBy.
  ///
  /// In en, this message translates to:
  /// **'owned by {email}'**
  String sharesOwnedBy(String email);

  /// No description provided for @sharesOwnedGroupsHeader.
  ///
  /// In en, this message translates to:
  /// **'OWNED GROUPS'**
  String get sharesOwnedGroupsHeader;

  /// No description provided for @sharesOwnerCannotBeRemoved.
  ///
  /// In en, this message translates to:
  /// **'The owner cannot be removed.'**
  String get sharesOwnerCannotBeRemoved;

  /// No description provided for @sharesPeopleWithAccess.
  ///
  /// In en, this message translates to:
  /// **'People with access'**
  String get sharesPeopleWithAccess;

  /// No description provided for @sharesPickEditorToEnable.
  ///
  /// In en, this message translates to:
  /// **'Pick Editor or Co-owner to enable'**
  String get sharesPickEditorToEnable;

  /// No description provided for @sharesPreparingAccess.
  ///
  /// In en, this message translates to:
  /// **'Preparing access ({done} / {total})'**
  String sharesPreparingAccess(int done, int total);

  /// No description provided for @sharesPreviouslyTrusted.
  ///
  /// In en, this message translates to:
  /// **'Previously trusted'**
  String get sharesPreviouslyTrusted;

  /// No description provided for @sharesRecipientEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Recipient email'**
  String get sharesRecipientEmailLabel;

  /// No description provided for @sharesRecipientsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load existing recipients.'**
  String get sharesRecipientsLoadFailed;

  /// No description provided for @sharesRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get sharesRefresh;

  /// No description provided for @sharesRemoveMember.
  ///
  /// In en, this message translates to:
  /// **'Remove member'**
  String get sharesRemoveMember;

  /// No description provided for @sharesRemoveMemberBody.
  ///
  /// In en, this message translates to:
  /// **'Remove {email} from \"{name}\"? Files you already shared with them stay shared; they just won\'t be included next time you share with this group.'**
  String sharesRemoveMemberBody(String email, String name);

  /// No description provided for @sharesRemoveMemberTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove member?'**
  String get sharesRemoveMemberTitle;

  /// No description provided for @sharesRenameGroup.
  ///
  /// In en, this message translates to:
  /// **'Rename group'**
  String get sharesRenameGroup;

  /// No description provided for @sharesRenamedTo.
  ///
  /// In en, this message translates to:
  /// **'Renamed to \"{name}\".'**
  String sharesRenamedTo(String name);

  /// No description provided for @sharesRevoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get sharesRevoke;

  /// No description provided for @sharesRevokeAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Revoke access?'**
  String get sharesRevokeAccessTitle;

  /// No description provided for @sharesRevokeCascadeExtra.
  ///
  /// In en, this message translates to:
  /// **'This also removes {count, plural, =1{1 share} other{{count} shares}} they granted under this folder.'**
  String sharesRevokeCascadeExtra(int count);

  /// No description provided for @sharesRevokeFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to revoke: {error}'**
  String sharesRevokeFailed(String error);

  /// No description provided for @sharesRevokeFileBody.
  ///
  /// In en, this message translates to:
  /// **'{email} will no longer be able to open this file.'**
  String sharesRevokeFileBody(String email);

  /// No description provided for @sharesRevokeFolderBody.
  ///
  /// In en, this message translates to:
  /// **'{name} will lose access to {folder}.'**
  String sharesRevokeFolderBody(String name, String folder);

  /// No description provided for @sharesRoleCoOwner.
  ///
  /// In en, this message translates to:
  /// **'Co-owner'**
  String get sharesRoleCoOwner;

  /// No description provided for @sharesRoleCoOwnerDescription.
  ///
  /// In en, this message translates to:
  /// **'Co-owner — can view, edit, re-share, and save copies.'**
  String get sharesRoleCoOwnerDescription;

  /// No description provided for @sharesRoleEditor.
  ///
  /// In en, this message translates to:
  /// **'Editor'**
  String get sharesRoleEditor;

  /// No description provided for @sharesRoleEditorDescription.
  ///
  /// In en, this message translates to:
  /// **'Editor — can view and edit. No re-share.'**
  String get sharesRoleEditorDescription;

  /// No description provided for @sharesRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get sharesRoleLabel;

  /// No description provided for @sharesRoleOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get sharesRoleOwner;

  /// No description provided for @sharesRoleReader.
  ///
  /// In en, this message translates to:
  /// **'Reader'**
  String get sharesRoleReader;

  /// No description provided for @sharesRoleReaderDescription.
  ///
  /// In en, this message translates to:
  /// **'Reader — can view only.'**
  String get sharesRoleReaderDescription;

  /// No description provided for @sharesServerReturnedNow.
  ///
  /// In en, this message translates to:
  /// **'Server returned now'**
  String get sharesServerReturnedNow;

  /// No description provided for @sharesSetGroupRole.
  ///
  /// In en, this message translates to:
  /// **'Set group role'**
  String get sharesSetGroupRole;

  /// No description provided for @sharesShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to share: {error}'**
  String sharesShareFailed(String error);

  /// No description provided for @sharesShareFileTitle.
  ///
  /// In en, this message translates to:
  /// **'Share file'**
  String get sharesShareFileTitle;

  /// No description provided for @sharesShareFromShareMenu.
  ///
  /// In en, this message translates to:
  /// **'Share a file to this group from its share menu.'**
  String get sharesShareFromShareMenu;

  /// No description provided for @sharesShareToGroup.
  ///
  /// In en, this message translates to:
  /// **'Share to group'**
  String get sharesShareToGroup;

  /// No description provided for @sharesShareToGroupFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to share to group: {error}'**
  String sharesShareToGroupFailed(String error);

  /// No description provided for @sharesShareWithGroup.
  ///
  /// In en, this message translates to:
  /// **'Share with a group'**
  String get sharesShareWithGroup;

  /// No description provided for @sharesSharedWith.
  ///
  /// In en, this message translates to:
  /// **'Shared with {email}'**
  String sharesSharedWith(String email);

  /// No description provided for @sharesSharedWithGroup.
  ///
  /// In en, this message translates to:
  /// **'Shared with the group.'**
  String get sharesSharedWithGroup;

  /// No description provided for @sharesSharedWithMe.
  ///
  /// In en, this message translates to:
  /// **'Shared with me'**
  String get sharesSharedWithMe;

  /// No description provided for @sharesSharingDisabled.
  ///
  /// In en, this message translates to:
  /// **'Sharing is disabled on this server.'**
  String get sharesSharingDisabled;

  /// No description provided for @sharesSubtreeTooLargeMove.
  ///
  /// In en, this message translates to:
  /// **'This folder has more than {cap} files. Move a sub-folder instead.'**
  String sharesSubtreeTooLargeMove(int cap);

  /// No description provided for @sharesSubtreeTooLargeShare.
  ///
  /// In en, this message translates to:
  /// **'This folder has more than {cap} files. Share a sub-folder instead.'**
  String sharesSubtreeTooLargeShare(int cap);

  /// No description provided for @sharesTabActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get sharesTabActivity;

  /// No description provided for @sharesTabGroups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get sharesTabGroups;

  /// No description provided for @sharesTabPublicLinks.
  ///
  /// In en, this message translates to:
  /// **'Public links'**
  String get sharesTabPublicLinks;

  /// No description provided for @sharesTooManyLookups.
  ///
  /// In en, this message translates to:
  /// **'Too many lookups, try again shortly.'**
  String get sharesTooManyLookups;

  /// No description provided for @sharesTrustFirstSight.
  ///
  /// In en, this message translates to:
  /// **'First time sharing with this account. Compare the fingerprint out of band if you want certainty — we will warn loudly if it ever changes.'**
  String get sharesTrustFirstSight;

  /// No description provided for @sharesTrustMismatchBody.
  ///
  /// In en, this message translates to:
  /// **'This recipient\'s key fingerprint changed since you last trusted it. This is what a legitimate key rotation looks like — and also exactly what a key-substitution attack looks like. The server cannot tell them apart; only you can, by verifying out of band.'**
  String get sharesTrustMismatchBody;

  /// No description provided for @sharesTrustVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified — this fingerprint matches the one you trusted before.'**
  String get sharesTrustVerified;

  /// No description provided for @sharesTwoNames.
  ///
  /// In en, this message translates to:
  /// **'{first} and {second}'**
  String sharesTwoNames(String first, String second);

  /// No description provided for @tabAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get tabAccount;

  /// No description provided for @tabFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get tabFiles;

  /// No description provided for @tabNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get tabNotes;

  /// No description provided for @tabSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get tabSearch;

  /// No description provided for @tabShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get tabShare;

  /// No description provided for @widgetDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get widgetDismiss;

  /// No description provided for @widgetOutdatedServer.
  ///
  /// In en, this message translates to:
  /// **'Your Hoodik server is {version}. Upgrade to v{latest} to get the latest features and bug fixes.'**
  String widgetOutdatedServer(String version, String latest);

  /// No description provided for @widgetOutdatedServerNoLatest.
  ///
  /// In en, this message translates to:
  /// **'Your Hoodik server is {version}. Upgrade to the latest release for new features and bug fixes.'**
  String widgetOutdatedServerNoLatest(String version);

  /// No description provided for @widgetServerVersionUnknown.
  ///
  /// In en, this message translates to:
  /// **'older than v1.16.0'**
  String get widgetServerVersionUnknown;

  /// No description provided for @widgetUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get widgetUpdate;

  /// No description provided for @widgetUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'A new version of Hoodik (v{version}) is available.'**
  String widgetUpdateAvailable(String version);

  /// No description provided for @widgetUpdateDownloaded.
  ///
  /// In en, this message translates to:
  /// **'A new version of Hoodik has been downloaded.'**
  String get widgetUpdateDownloaded;

  /// No description provided for @widgetUpdateRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get widgetUpdateRestart;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'fr', 'hr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
    case 'hr':
      return AppLocalizationsHr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
