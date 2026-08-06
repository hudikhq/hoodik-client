// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get accountActiveTransfers => 'Active transfers in progress';

  @override
  String get accountAdminHeader => 'ADMINISTRATION';

  @override
  String get accountAdminPanel => 'Admin Panel';

  @override
  String get accountAdminPanelSubtitle => 'Users, invitations & settings';

  @override
  String get accountAiAccessMacosOnly =>
      'AI Access via MCP is available on the macOS version of Hoodik.';

  @override
  String get accountAiAccessSubtitle => 'MCP server for AI agents';

  @override
  String get accountAiAccessTitle => 'AI Access';

  @override
  String get accountAllAccountsHeader => 'ALL ACCOUNTS';

  @override
  String get accountAuditAllStatuses => 'All statuses';

  @override
  String get accountAuditAllTools => 'All tools';

  @override
  String get accountAuditClearConfirmBody =>
      'This permanently removes every recorded tool invocation. Your files are not affected.';

  @override
  String get accountAuditClearConfirmTitle => 'Clear audit log?';

  @override
  String get accountAuditClearLog => 'Clear log';

  @override
  String get accountAuditCleared => 'Audit log cleared';

  @override
  String get accountAuditDuration => 'Duration';

  @override
  String get accountAuditEmptyBody =>
      'Every AI tool call is recorded here. Enable AI Access and connect an agent to see activity.';

  @override
  String get accountAuditEmptyTitle => 'No audit entries yet';

  @override
  String get accountAuditError => 'Error';

  @override
  String get accountAuditFilterByStatus => 'Filter by status';

  @override
  String get accountAuditFilterByTool => 'Filter by tool';

  @override
  String accountAuditLoadFailed(String error) {
    return 'Failed to load: $error';
  }

  @override
  String get accountAuditLogTitle => 'Audit Log';

  @override
  String accountAuditMilliseconds(int ms) {
    return '$ms ms';
  }

  @override
  String get accountAuditNoParams => '(no params)';

  @override
  String get accountAuditParamsHash => 'Params hash';

  @override
  String get accountAuditSession => 'Session';

  @override
  String get accountAuditStatus => 'Status';

  @override
  String get accountAuditStatusDenied => 'Denied';

  @override
  String get accountAuditStatusOk => 'Ok';

  @override
  String get accountAuditTimestamp => 'Timestamp';

  @override
  String get accountClear => 'Clear';

  @override
  String get accountDefaultLanding => 'Default landing';

  @override
  String get accountDefaultLandingSubtitle =>
      'The tab shown when the app opens';

  @override
  String get accountDiagnosticsExportLogs => 'Export Logs';

  @override
  String get accountDiagnosticsLogsInfo =>
      'Logs may contain filenames and server URLs so you can recognise what each line refers to. They never contain file contents, passwords, or encryption keys. You’ll see every line and can remove anything before sending.';

  @override
  String get accountDiagnosticsNoTelemetryBody =>
      'Hoodik doesn’t use Sentry, crash reporters, or any third-party analytics. The only data that leaves your device is what’s needed for encrypted file sync.';

  @override
  String get accountDiagnosticsNoTracking =>
      'We don’t track anything about your device.';

  @override
  String get accountDiagnosticsStep1 => 'Close Hoodik completely.';

  @override
  String get accountDiagnosticsStep2 => 'Open it again.';

  @override
  String get accountDiagnosticsStep3 => 'Try to reproduce the bug.';

  @override
  String get accountDiagnosticsStep4 =>
      'Come back here and tap Export Logs below.';

  @override
  String get accountDiagnosticsSubtitle => 'Send a bug report — no telemetry';

  @override
  String get accountDiagnosticsTellUsBody =>
      'This means when something breaks, we don’t know about it unless you tell us. Here’s the most useful way to do that:';

  @override
  String get accountDiagnosticsTitle => 'Privacy & Diagnostics';

  @override
  String get accountDisable => 'Disable';

  @override
  String get accountEnable => 'Enable';

  @override
  String get accountEnabled => 'Enabled';

  @override
  String get accountEnterPinBody =>
      'Enter your PIN to enable biometric unlock.';

  @override
  String get accountEnterPinTitle => 'Enter PIN';

  @override
  String get accountIncorrectPin => 'Incorrect PIN';

  @override
  String get accountLegalHeader => 'LEGAL';

  @override
  String get accountLogsClearAll => 'Clear all';

  @override
  String get accountLogsCopied => 'Logs copied to clipboard';

  @override
  String get accountLogsCopyToClipboard => 'Copy to Clipboard';

  @override
  String get accountLogsCurrentSession => 'Current session';

  @override
  String get accountLogsEmptyBody =>
      'Close the app, reopen it, reproduce the bug, then come back and try again.';

  @override
  String get accountLogsEmptyTitle => 'No log lines to review.';

  @override
  String accountLogsLineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines',
      one: '1 line',
    );
    return '$_temp0';
  }

  @override
  String get accountLogsPastDays => 'Past 3 days';

  @override
  String get accountLogsReviewTitle => 'Review Logs';

  @override
  String accountLogsSendViaEmail(String email) {
    return 'Send via Email ($email)';
  }

  @override
  String get accountLogsShareFailed =>
      'Sharing failed — try Copy to Clipboard instead';

  @override
  String get accountManageAccounts => 'Manage Accounts';

  @override
  String get accountManageAccountsSubtitle => 'Add or switch accounts';

  @override
  String get accountMcpActivityHeader => 'ACTIVITY';

  @override
  String get accountMcpAllowReadOnlyOff =>
      'All agent access paused when PIN-locked';

  @override
  String get accountMcpAllowReadOnlyOn =>
      'Agents may list and search files when PIN-locked';

  @override
  String get accountMcpAllowReadOnlyTitle =>
      'Allow read-only access while locked';

  @override
  String get accountMcpBearerToken => 'Bearer Token';

  @override
  String get accountMcpBurstCapacity => 'Burst capacity';

  @override
  String get accountMcpClearAuditLog => 'Clear audit log';

  @override
  String get accountMcpClearAuditLogSubtitle =>
      'Removes every recorded tool invocation';

  @override
  String get accountMcpConfigCopied => 'Config copied to clipboard';

  @override
  String get accountMcpConfigFootnote =>
      'Copy this JSON into your Claude Desktop or Claude Code MCP server configuration.';

  @override
  String get accountMcpConfigurationHeader => 'CONFIGURATION';

  @override
  String get accountMcpConnectClientSubtitle =>
      'Guided setup for Claude Desktop, Cursor, and others';

  @override
  String get accountMcpConnectClientTitle => 'Connect an AI client';

  @override
  String get accountMcpConnectionHeader => 'CONNECTION';

  @override
  String get accountMcpCopyConfig => 'Copy Config';

  @override
  String get accountMcpDisabled => 'Disabled';

  @override
  String get accountMcpEnable => 'Enable AI Access';

  @override
  String get accountMcpEnableFootnote =>
      'When enabled, AI agents like Claude Desktop and Claude Code can access your encrypted files through a local endpoint.';

  @override
  String get accountMcpEndpoint => 'Endpoint';

  @override
  String accountMcpLastAgentCall(String time) {
    return 'Last agent call $time';
  }

  @override
  String get accountMcpLockedFootnote =>
      'When the app is locked with a PIN, decrypting file content requires you to unlock. Read-only access exposes only encrypted metadata the server already knows.';

  @override
  String get accountMcpNoAgentActivity => 'No agent activity yet';

  @override
  String get accountMcpNotRunning => 'Not running';

  @override
  String get accountMcpOffSubtitle =>
      'Toggle AI Access to start the local MCP server.';

  @override
  String accountMcpPausedSubtitle(int port) {
    return 'Port $port reserved • restart to resume';
  }

  @override
  String accountMcpPerSecondOption(int value) {
    return '$value / sec';
  }

  @override
  String get accountMcpPort => 'Port';

  @override
  String get accountMcpPortRange => 'Port must be between 1024 and 65535';

  @override
  String accountMcpPortUpdated(int port) {
    return 'Port updated to $port';
  }

  @override
  String get accountMcpQuickActionsHeader => 'QUICK ACTIONS';

  @override
  String get accountMcpRateLimitFootnote =>
      'A token bucket throttles each AI session. Burst capacity is how many requests back-to-back are allowed before the bucket starts refilling at the configured rate.';

  @override
  String get accountMcpRateLimitHeader => 'RATE LIMIT';

  @override
  String get accountMcpRegenerate => 'Regenerate';

  @override
  String get accountMcpRequestsPerSecond => 'Requests per second';

  @override
  String accountMcpRetentionDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get accountMcpRetentionForever => 'Forever';

  @override
  String get accountMcpRetentionHeader => 'AUDIT RETENTION';

  @override
  String get accountMcpRetentionOneYear => '1 year';

  @override
  String get accountMcpRetentionTitle => 'Keep entries for';

  @override
  String get accountMcpRotateToken => 'Rotate bearer token';

  @override
  String get accountMcpRotateTokenSubtitle =>
      'Invalidates every configured AI client';

  @override
  String accountMcpRunningOnPort(int port) {
    return 'Running on port $port';
  }

  @override
  String get accountMcpSecurityHeader => 'SECURITY';

  @override
  String get accountMcpServerHeader => 'MCP SERVER';

  @override
  String get accountMcpStarting => 'Starting...';

  @override
  String get accountMcpStatusOff => 'Off';

  @override
  String get accountMcpStatusPaused => 'Paused';

  @override
  String get accountMcpStatusRunning => 'Running';

  @override
  String get accountMcpStopServer => 'Stop server';

  @override
  String get accountMcpStopServerSubtitle => 'Closes the local MCP port';

  @override
  String get accountMcpTokenCopied => 'Token copied to clipboard';

  @override
  String get accountMcpTokenRegenerated => 'Token regenerated';

  @override
  String get accountMcpUnavailable =>
      'MCP server is unavailable. Log in on macOS to continue.';

  @override
  String get accountMcpViewAuditLog => 'View audit log';

  @override
  String get accountMcpViewAuditLogSubtitle => 'Review every AI tool call';

  @override
  String get accountMcpWizardMacosOnly =>
      'The connect wizard is available in the macOS build of Hoodik.';

  @override
  String get accountNotConfigured => 'Not configured';

  @override
  String get accountNotSignedIn => 'Not signed in';

  @override
  String accountOfflineCacheStats(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0 · $size';
  }

  @override
  String get accountOfflineCacheTitle => 'Offline Cache';

  @override
  String get accountOfflineClearBody =>
      'This will remove all offline copies of your files from this device. Your files on the server are not affected.';

  @override
  String get accountOfflineClearTitle => 'Clear Offline Cache';

  @override
  String get accountOfflineCleared => 'Offline cache cleared';

  @override
  String get accountOfflineNoFiles => 'No files cached';

  @override
  String get accountOpenSourceLicenses => 'Open source licenses';

  @override
  String get accountPasscodeLock => 'Passcode Lock';

  @override
  String get accountPinLabel => 'PIN';

  @override
  String get accountPrivacyPolicy => 'Privacy Policy';

  @override
  String get accountRecoveryHide => 'Hide';

  @override
  String get accountRecoveryKeyBody =>
      'This is the credential that recovers your account if you ever forget your password. Keep a copy somewhere safe and private — anyone who has it can sign in as you. To use it, pick \"Log in with your key\" on the sign-in screen.';

  @override
  String get accountRecoveryKeyCopied => 'Recovery key copied';

  @override
  String get accountRecoveryKeyLocked =>
      'Your keys are not unlocked right now. Sign in with your password to export your recovery key.';

  @override
  String get accountRecoveryKeySubtitle => 'Back up your sign-in key';

  @override
  String get accountRecoveryKeyTitle => 'Recovery Key';

  @override
  String get accountRecoveryReveal => 'Reveal';

  @override
  String get accountRemovePasscodeBody =>
      'This will remove the PIN lock screen. You will need to sign in with your password next time.';

  @override
  String get accountRemovePasscodeTitle => 'Remove Passcode';

  @override
  String get accountSetUp => 'Set up';

  @override
  String get accountSetUpPinFirst => 'Set up a PIN first';

  @override
  String get accountSettingsHeader => 'SETTINGS';

  @override
  String get accountSharingDisabledMsg =>
      'You will no longer receive sharing emails.';

  @override
  String get accountSharingEmailToggle =>
      'Email me when a file is shared with me';

  @override
  String get accountSharingEmailsOff => 'Sharing emails are off.';

  @override
  String get accountSharingEmailsOn => 'Sharing emails are on.';

  @override
  String get accountSharingEnabledMsg =>
      'You will receive an email when someone shares a file with you.';

  @override
  String get accountSharingHeader => 'SHARING';

  @override
  String get accountSharingUpdateFailed =>
      'Could not update sharing notifications.';

  @override
  String get accountSignOut => 'Sign Out';

  @override
  String get accountSignOutConfirm => 'Are you sure you want to sign out?';

  @override
  String accountStorageQuota(String size) {
    return 'Quota: $size';
  }

  @override
  String get accountStorageTitle => 'Storage';

  @override
  String get accountStorageUnlimited => 'Unlimited';

  @override
  String accountStorageUsed(Object used) {
    return '$used used';
  }

  @override
  String accountStorageUsedOfTotal(Object used, Object total) {
    return '$used of $total used';
  }

  @override
  String get accountTermsOfService => 'Terms of Service';

  @override
  String get accountTitle => 'Account';

  @override
  String get accountWizardCallingInitialize => 'Calling initialize…';

  @override
  String accountWizardCapabilitiesList(String list) {
    return 'Capabilities: $list';
  }

  @override
  String get accountWizardCapabilitiesNone => 'Capabilities: none advertised';

  @override
  String get accountWizardConnected => 'Connected';

  @override
  String get accountWizardConnectionFailed =>
      'Connection failed. Check the server and token.';

  @override
  String get accountWizardCopyToClipboard => 'Copy to clipboard';

  @override
  String get accountWizardCopyToken => 'Copy token';

  @override
  String get accountWizardEnableHint => 'Enable to bind the local port.';

  @override
  String get accountWizardFailed => 'Failed';

  @override
  String get accountWizardFinish => 'Finish';

  @override
  String get accountWizardHideToken => 'Hide token';

  @override
  String get accountWizardNext => 'Next';

  @override
  String get accountWizardNoToken => '(no token)';

  @override
  String get accountWizardOpenFolder => 'Open config folder';

  @override
  String accountWizardProtocol(String version) {
    return 'protocol $version';
  }

  @override
  String get accountWizardReadyBody =>
      'Press \"Run test\" to call initialize against the local server.';

  @override
  String get accountWizardReadyTitle => 'Ready to test';

  @override
  String get accountWizardRegenerateConfirmBody =>
      'This invalidates existing agent sessions. You will need to paste the new token into every AI client you have configured.';

  @override
  String get accountWizardRegenerateConfirmTitle => 'Regenerate bearer token?';

  @override
  String get accountWizardRunTest => 'Run test';

  @override
  String accountWizardServerName(String name) {
    return 'Server $name';
  }

  @override
  String get accountWizardShowToken => 'Show token';

  @override
  String get accountWizardStep1Subtitle =>
      'The local MCP server needs to be running before we can hand credentials to your AI client.';

  @override
  String get accountWizardStep1Title => 'Step 1 of 4: Start the MCP server';

  @override
  String get accountWizardStep2Subtitle =>
      'Your AI client uses this token to authenticate every MCP call. Treat it like a password.';

  @override
  String get accountWizardStep2Title => 'Step 2 of 4: Review the bearer token';

  @override
  String get accountWizardStep3Title => 'Step 3 of 4: Copy into your AI client';

  @override
  String get accountWizardStep4Subtitle =>
      'We will call initialize over the local MCP socket and show you exactly what your AI client will see.';

  @override
  String get accountWizardStep4Title => 'Step 4 of 4: Verify the handshake';

  @override
  String get accountWizardTesting => 'Testing';

  @override
  String get accountWizardTryAgain => 'Try again';

  @override
  String adminActionFailed(String error) {
    return 'Failed: $error';
  }

  @override
  String get adminActionsHeader => 'ACTIONS';

  @override
  String get adminAdminRole => 'Admin role';

  @override
  String get adminAllowRegistration => 'Allow Registration';

  @override
  String get adminAllowRegistrationSubtitle =>
      'Let new users sign up without invitation';

  @override
  String get adminBadgeAdmin => 'admin';

  @override
  String get adminCopied => 'Copied';

  @override
  String get adminDefaultQuotaGbLabel => 'Default quota (GB)';

  @override
  String get adminDefaultQuotaHeader => 'DEFAULT QUOTA';

  @override
  String get adminDeleteUser => 'Delete User';

  @override
  String adminDeleteUserBody(String email) {
    return 'Permanently delete $email and ALL their files? This cannot be undone.';
  }

  @override
  String get adminDeleteUserSubtitle => 'Permanently delete user and all data';

  @override
  String get adminDisable => 'Disable';

  @override
  String get adminDisableTfa => 'Disable 2FA';

  @override
  String adminDisableTfaBody(String email) {
    return 'This will remove 2FA for $email. They will need to re-enable it themselves.';
  }

  @override
  String get adminDisableTfaTitle => 'Disable Two-Factor Auth';

  @override
  String get adminDisabled => 'Disabled';

  @override
  String get adminEditRoleQuotaTooltip => 'Edit role & quota';

  @override
  String get adminEditUserTitle => 'Edit User';

  @override
  String get adminEmailHeader => 'EMAIL';

  @override
  String get adminEmailLabel => 'Email';

  @override
  String adminEmailTestFailed(String error) {
    return 'Email test failed: $error';
  }

  @override
  String get adminEmailVerifiedLabel => 'Email Verified';

  @override
  String get adminEnabled => 'Enabled';

  @override
  String get adminEnforceEmailVerification => 'Enforce Email Verification';

  @override
  String get adminEnforceEmailVerificationSubtitle =>
      'Require users to verify email before login';

  @override
  String get adminExpire => 'Expire';

  @override
  String adminExpireInvitationBody(String email) {
    return 'Expire the invitation for $email? They will no longer be able to use it to register.';
  }

  @override
  String get adminExpireInvitationTitle => 'Expire Invitation';

  @override
  String adminFileCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0';
  }

  @override
  String adminInvitationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invitations',
      one: '1 invitation',
    );
    return '$_temp0';
  }

  @override
  String adminInvitationSent(String email) {
    return 'Invitation sent to $email';
  }

  @override
  String get adminInvite => 'Invite';

  @override
  String get adminKillAll => 'Kill All';

  @override
  String get adminKillAllSessions => 'Kill All Sessions';

  @override
  String adminKillAllSessionsBody(String email) {
    return 'This will sign $email out of all devices.';
  }

  @override
  String adminLastActive(String time) {
    return 'Active $time';
  }

  @override
  String get adminNoActiveSessions => 'No active sessions';

  @override
  String get adminNoFiles => 'No files';

  @override
  String get adminNoFilesSubtitle => 'This user has not uploaded any files';

  @override
  String get adminNoInvitations => 'No invitations yet';

  @override
  String get adminNoUsersFound => 'No users found';

  @override
  String get adminNotVerified => 'Not verified';

  @override
  String adminPaginationRange(int start, int end, int total) {
    return '$start–$end of $total';
  }

  @override
  String get adminPanelTitle => 'Admin Panel';

  @override
  String get adminQuotaDefaultHint => 'Leave empty for default';

  @override
  String get adminQuotaGbLabel => 'Quota (GB)';

  @override
  String get adminQuotaLabel => 'Quota';

  @override
  String get adminQuotaUnlimitedHint => 'Leave empty for unlimited';

  @override
  String get adminRegisteredLabel => 'Registered';

  @override
  String get adminRegistrationHeader => 'USER REGISTRATION';

  @override
  String get adminRoleAdmin => 'Admin';

  @override
  String get adminRoleLabel => 'Role';

  @override
  String get adminRoleUser => 'User';

  @override
  String get adminSaveSettings => 'Save Settings';

  @override
  String get adminSearchUsersHint => 'Search users...';

  @override
  String get adminSendInvitationTitle => 'Send Invitation';

  @override
  String get adminSendTest => 'Send Test';

  @override
  String adminSessionsHeader(int count) {
    return 'SESSIONS ($count)';
  }

  @override
  String get adminSettingsLoadFailed => 'Unable to load settings';

  @override
  String get adminSettingsSaved => 'Settings saved';

  @override
  String get adminSharingHeader => 'SHARING';

  @override
  String get adminSharingSubtitle =>
      'When off, the Share action disappears everywhere and the sharing endpoints stop responding. Existing shares are kept.';

  @override
  String get adminSharingToggle => 'Account-to-account sharing';

  @override
  String get adminStatusExpired => 'Expired';

  @override
  String get adminStatusPending => 'Pending';

  @override
  String get adminStatusRedeemed => 'Redeemed';

  @override
  String adminStorageHeader(String size, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return 'STORAGE ($size · $_temp0)';
  }

  @override
  String get adminTabInvitations => 'Invitations';

  @override
  String get adminTabSettings => 'Settings';

  @override
  String get adminTabUsers => 'Users';

  @override
  String get adminTestEmailSubtitle => 'Send a test email to verify SMTP';

  @override
  String get adminTestEmailTitle => 'Test Email Configuration';

  @override
  String get adminTwoFactorLabel => 'Two-Factor Auth';

  @override
  String get adminUnlimited => 'Unlimited';

  @override
  String get adminUserDeleted => 'User deleted';

  @override
  String get adminUserInfoHeader => 'USER INFO';

  @override
  String get adminUserUpdated => 'User updated';

  @override
  String get authAddAnotherAccount => 'Add another account';

  @override
  String get authAddNewServer => 'ADD NEW SERVER';

  @override
  String get authAddServer => 'Add Server';

  @override
  String get authBiometricFailed => 'Biometric failed';

  @override
  String get authBiometricFailedUsePin => 'Biometric failed — use your PIN';

  @override
  String get authBiometricLockedOut =>
      'Too many attempts — try again in 30 s, or use your PIN';

  @override
  String get authBiometricNotConfigured =>
      'Biometric not configured for this build — use your PIN';

  @override
  String get authBiometricNotEnrolled =>
      'No biometric enrolled on this device — use your PIN';

  @override
  String get authBiometricPermanentlyLockedOut =>
      'Biometric locked — unlock your device, then try again';

  @override
  String get authBiometricPinNotFound => 'Biometric PIN not found';

  @override
  String get authCheckEmailBody =>
      'Your account was created. Verify your email, then sign in to unlock encryption.';

  @override
  String get authCheckEmailTitle => 'Check your email';

  @override
  String get authConfirmPasswordLabel => 'Confirm Password';

  @override
  String get authConfirmPinLabel => 'Confirm PIN';

  @override
  String get authConnectToServer => 'Connect to a Server';

  @override
  String authConnectionFailed(String error) {
    return 'Connection failed: $error';
  }

  @override
  String get authCreateAccount => 'Create Account';

  @override
  String get authCreateAnAccount => 'Create an account';

  @override
  String get authCreatePasscode => 'Create a Passcode';

  @override
  String authDeleteServerConfirm(String name) {
    return 'Remove \"$name\" and all its accounts?';
  }

  @override
  String get authDeleteServerTitle => 'Delete Server';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authEmailPasswordRequired => 'Email and password are required';

  @override
  String get authEnterPasscode => 'Enter Passcode';

  @override
  String get authEnterPinPrompt => 'Please enter your PIN';

  @override
  String get authEnterTfaCode => 'Please enter your 2FA code';

  @override
  String get authExistingAccounts => 'EXISTING ACCOUNTS';

  @override
  String get authForget => 'Forget';

  @override
  String authForgetAccountConfirm(String email) {
    return 'This will remove the account \"$email\" from this device. All offline files for this account will be deleted. You can sign in again later.';
  }

  @override
  String get authForgetAccountTitle => 'Forget Account';

  @override
  String get authForgetThisAccount => 'Forget this account';

  @override
  String get authGetMyRecoveryKey => 'Get my recovery key';

  @override
  String get authInvalidCredentials => 'Invalid email or password';

  @override
  String get authKeyLoginIntro =>
      'Paste the recovery key you saved when you set up your account. It never leaves this device — it is only used to sign a login challenge.';

  @override
  String get authKeyLoginInvalidKey => 'This is not a valid private key';

  @override
  String get authKeyLoginNoAccount =>
      'The server accepted the key but returned no account';

  @override
  String get authKeyLoginNoIdentityKey =>
      'This recovery key carries no usable identity key';

  @override
  String get authKeyLoginSelfCheckFailed =>
      'This recovery key failed its self-check';

  @override
  String get authKeyLoginSessionFailed =>
      'Signed in, but the session could not be established';

  @override
  String get authKeyLoginTitle => 'Log In With Your Key';

  @override
  String get authKeyLoginUnrecognizedKey =>
      'The server did not recognize this key';

  @override
  String authLastUsed(String time) {
    return 'Last used $time';
  }

  @override
  String get authLater => 'Later';

  @override
  String get authLearnMore => 'Learn more';

  @override
  String get authLogIn => 'Log In';

  @override
  String get authLogInWithKey => 'Log in with your key';

  @override
  String get authLogInWithPassword => 'Log in with email and password';

  @override
  String get authManageAccounts => 'Manage Accounts';

  @override
  String get authMigrationNoticeBody =>
      'Your files are now protected with upgraded encryption, and you sign in without your password ever leaving this device.\n\nBecause this created new keys for your account, save a fresh copy of your recovery key — it is the only way back in if you forget your password. You can always find it under Account → Recovery Key.';

  @override
  String get authMigrationNoticeTitle => 'Your account security was upgraded';

  @override
  String get authNeedServerBody =>
      'Self-host for free, or get a managed instance.';

  @override
  String get authNeedServerTitle => 'Need a server?';

  @override
  String get authNeverUsed => 'Never used';

  @override
  String get authNoAccountFound => 'No account found';

  @override
  String get authNoActiveAccountOrKey =>
      'No active account or private key available';

  @override
  String get authNoServerSelected => 'No server selected';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authPasswordsDoNotMatch => 'Passwords do not match';

  @override
  String get authPasteRecoveryKeyFirst => 'Paste your recovery key first';

  @override
  String get authPinLabel => 'PIN';

  @override
  String get authPinPlaceholder => 'At least 4 characters';

  @override
  String authPinSetupFailed(String error) {
    return 'Failed to set up PIN: $error';
  }

  @override
  String get authPinTooShort => 'PIN must be at least 4 characters';

  @override
  String get authPinsDoNotMatch => 'PINs do not match';

  @override
  String get authRecoveryKeyEmpty => 'Recovery key is empty';

  @override
  String get authRecoveryKeyLabel => 'Recovery key';

  @override
  String get authRecoveryKeyMissingKeys =>
      'Recovery key is missing its identity or wrapping key';

  @override
  String get authRecoveryKeyUnrecognized =>
      'This does not look like a Hoodik recovery key';

  @override
  String authRegistrationFailed(String error) {
    return 'Registration failed: $error';
  }

  @override
  String get authRegistrationNotAllowed =>
      'Registration not allowed for this email';

  @override
  String get authSavedServers => 'SAVED SERVERS';

  @override
  String get authServerTooOldForRegister =>
      'This server is too old to create an account from this app. Please update the server, or sign in to an existing account.';

  @override
  String get authServerUrlLabel => 'Server URL';

  @override
  String get authServerUrlRequired => 'Please enter a server URL';

  @override
  String get authSetPin => 'Set PIN';

  @override
  String get authSetupPinIntro =>
      'Set a PIN to quickly unlock your account next time without entering your password.';

  @override
  String get authSignIn => 'Sign In';

  @override
  String get authSignInDifferentAccount => 'SIGN IN WITH A DIFFERENT ACCOUNT';

  @override
  String get authSignInToContinue => 'Please sign in to continue.';

  @override
  String get authSignInToUnlockEncryption =>
      'Please sign in with your password to unlock encryption.';

  @override
  String get authSkip => 'Skip';

  @override
  String get authSwitchAccount => 'SWITCH ACCOUNT';

  @override
  String get authTagline => 'End-to-End Encrypted Cloud Storage';

  @override
  String get authTfaCodeLabel => '2FA Code';

  @override
  String get authTfaRequired => 'Two-factor authentication code required';

  @override
  String get authUnknownServer => 'Unknown server';

  @override
  String get authUnlock => 'Unlock';

  @override
  String get authUnlockHoodik => 'Unlock Hoodik';

  @override
  String get authValidationError => 'Validation error — check your input';

  @override
  String get authWrongPin => 'Wrong PIN';

  @override
  String get authWrongPinOrAuthFailed => 'Wrong PIN or authentication failed';

  @override
  String get authWrongPinOrVerifyFailed => 'Wrong PIN or verification failed';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClose => 'Close';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonCreate => 'Create';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonDone => 'Done';

  @override
  String get commonDownload => 'Download';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonMove => 'Move';

  @override
  String get commonNever => 'Never';

  @override
  String get commonNo => 'No';

  @override
  String get commonOk => 'OK';

  @override
  String get commonOpen => 'Open';

  @override
  String get commonRemove => 'Remove';

  @override
  String get commonRename => 'Rename';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonSave => 'Save';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonSend => 'Send';

  @override
  String get commonShare => 'Share';

  @override
  String get commonUnknown => 'Unknown';

  @override
  String get commonUpload => 'Upload';

  @override
  String get commonYes => 'Yes';

  @override
  String get errorNoConnection =>
      'No connection. Check your network and try again.';

  @override
  String get errorNotAuthorized =>
      'You’re not authorized for this action. Try signing in again.';

  @override
  String errorRequestFailed(Object status) {
    return 'Request failed ($status).';
  }

  @override
  String get errorServerUnavailable =>
      'The server is having trouble. Try again in a moment.';

  @override
  String get filesAccountNotInitialized => 'Account not fully initialized';

  @override
  String filesAvailableOffline(String name) {
    return '$name available offline';
  }

  @override
  String filesCacheFailed(String error) {
    return 'Failed to cache: $error';
  }

  @override
  String get filesCancelled => 'Cancelled';

  @override
  String get filesCannotBeUndone => 'This cannot be undone.';

  @override
  String get filesCannotDecryptKey => 'Cannot decrypt file key';

  @override
  String get filesCannotDecryptSharedKey =>
      'Cannot decrypt the shared file key';

  @override
  String get filesCannotReadPath => 'Could not read file path';

  @override
  String get filesChooseFolder => 'Choose folder';

  @override
  String get filesChunksLabel => 'Chunks';

  @override
  String get filesCipherLabel => 'Cipher';

  @override
  String get filesClear => 'Clear';

  @override
  String filesConvertFailed(String error) {
    return 'Convert failed: $error';
  }

  @override
  String get filesConvertToNote => 'Convert to note';

  @override
  String get filesConvertedToNote => 'Converted to note';

  @override
  String filesCopiedToClipboard(String label) {
    return '$label copied to clipboard';
  }

  @override
  String get filesCopyLink => 'Copy Link';

  @override
  String get filesCreateFolder => 'Create Folder';

  @override
  String filesCreateFolderFailed(String error) {
    return 'Failed to create folder: $error';
  }

  @override
  String get filesCreateLink => 'Create Link';

  @override
  String filesCreateLinkFailed(String error) {
    return 'Failed to create link: $error';
  }

  @override
  String get filesCreatedLabel => 'Created';

  @override
  String get filesDateLabel => 'Date';

  @override
  String filesDeleteConfirmMessage(String name) {
    return 'Delete \"$name\"? This cannot be undone.';
  }

  @override
  String filesDeleteCountTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count items?',
      one: 'Delete 1 item?',
    );
    return '$_temp0';
  }

  @override
  String filesDeleteFailed(String error) {
    return 'Delete failed: $error';
  }

  @override
  String get filesDeleteFileTitle => 'Delete file?';

  @override
  String get filesDeleteFolderTitle => 'Delete folder?';

  @override
  String get filesDeleted => 'Deleted';

  @override
  String filesDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Deleted $count items',
      one: 'Deleted 1 item',
    );
    return '$_temp0';
  }

  @override
  String get filesDetails => 'Details';

  @override
  String get filesDiscard => 'Discard';

  @override
  String get filesDownloadingForOffline => 'Downloading for offline access...';

  @override
  String get filesDropToUpload => 'Drop files to upload';

  @override
  String get filesEmptyFolder => 'Empty folder';

  @override
  String get filesEmptyHint => 'Tap + to create a folder or upload a file';

  @override
  String get filesEmptyTitle => 'No files yet';

  @override
  String get filesEncryptedFallback => '(encrypted)';

  @override
  String filesEncryptedPlaceholder(String id) {
    return '[Encrypted] $id...';
  }

  @override
  String get filesExport => 'Export';

  @override
  String filesExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get filesExportStarted =>
      'Export started — share sheet will open when complete';

  @override
  String filesExportingTo(String path) {
    return 'Exporting to $path';
  }

  @override
  String filesFailedUploadsHeader(int count) {
    return 'Failed uploads ($count)';
  }

  @override
  String filesFailedUploadsTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count failed uploads',
      one: '1 failed upload',
    );
    return '$_temp0';
  }

  @override
  String get filesFolderCreated => 'Folder created';

  @override
  String get filesFolderLabel => 'Folder';

  @override
  String get filesFolderNameHint => 'Folder name';

  @override
  String filesForkFailed(String error) {
    return 'Failed to save to your drive: $error';
  }

  @override
  String get filesForkFolderUnsupported =>
      'Folders cannot be saved to your drive';

  @override
  String get filesForkQuotaExceeded =>
      'Not enough space to save this file to your drive';

  @override
  String filesForkSaved(String name) {
    return 'Saved \"$name\" to your drive';
  }

  @override
  String filesForkSaving(String name) {
    return 'Saving \"$name\" to your drive…';
  }

  @override
  String get filesIdLabel => 'ID';

  @override
  String get filesLeave => 'Leave';

  @override
  String filesLeaveShareBody(String name) {
    return 'You\'ll lose access to \"$name\" on future reads. Anything you\'ve already downloaded stays with you — end-to-end encryption can\'t recall what\'s already been decrypted on your device, and the owner can\'t un-share it.';
  }

  @override
  String get filesLeaveShareTitle => 'Leave this share?';

  @override
  String get filesLinkCopied => 'Link copied to clipboard';

  @override
  String get filesLinkCreatedTitle => 'Link Created';

  @override
  String filesLoadFailed(String error) {
    return 'Failed to load files: $error';
  }

  @override
  String filesLoadSharedFailed(String error) {
    return 'Failed to load shared items: $error';
  }

  @override
  String get filesMakeAvailableOffline => 'Make Available Offline';

  @override
  String get filesMembers => 'Members';

  @override
  String get filesMoreActions => 'More actions';

  @override
  String filesMoveFailed(String error) {
    return 'Move failed: $error';
  }

  @override
  String get filesMoveHere => 'Move here';

  @override
  String filesMoveItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Move $count items',
      one: 'Move 1 item',
    );
    return '$_temp0';
  }

  @override
  String get filesMoveToTitle => 'Move to...';

  @override
  String get filesMyFiles => 'My Files';

  @override
  String get filesNameInvalid => 'Invalid name';

  @override
  String get filesNameInvalidChars => 'Name cannot contain / or \\';

  @override
  String get filesNameLabel => 'Name';

  @override
  String get filesNewNameHint => 'New name';

  @override
  String get filesNoAccessToLeave => 'You do not have access to leave';

  @override
  String get filesNoSubfolders => 'No sub-folders';

  @override
  String get filesNotAuthenticated => 'Not authenticated';

  @override
  String get filesOfflineChip => 'Offline';

  @override
  String get filesOfflineCopyRemoved => 'Offline copy removed';

  @override
  String get filesOpsUnavailable => 'File operations not available';

  @override
  String get filesOpsUnavailableNoKey =>
      'File operations not available (no private key)';

  @override
  String filesOwnedBy(String name) {
    return 'Owned by $name';
  }

  @override
  String filesPinnedForOffline(String name) {
    return '$name pinned for offline access';
  }

  @override
  String get filesPreparing => 'Preparing…';

  @override
  String get filesPreview => 'Preview';

  @override
  String get filesPublicKeyUnavailable => 'Public key not available';

  @override
  String get filesQueued => 'Queued';

  @override
  String get filesRefresh => 'Refresh';

  @override
  String get filesRemoveOfflineCopy => 'Remove Offline Copy';

  @override
  String filesRenameFailed(String error) {
    return 'Rename failed: $error';
  }

  @override
  String get filesRenamed => 'Renamed';

  @override
  String filesRevokeFailed(String error) {
    return 'Failed to revoke: $error';
  }

  @override
  String get filesRootFolder => 'Root';

  @override
  String get filesSaveFileDialogTitle => 'Save file';

  @override
  String get filesSaveToMyDrive => 'Save to my drive';

  @override
  String get filesSelect => 'Select';

  @override
  String get filesSelectFilesTooltip => 'Select files';

  @override
  String filesSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String filesShareFailed(String error) {
    return 'Failed to share: $error';
  }

  @override
  String get filesSharedItemsNeedConnection =>
      'Shared items need a connection.';

  @override
  String filesSharedWith(int count) {
    return 'Shared with $count';
  }

  @override
  String get filesSizeLabel => 'Size';

  @override
  String get filesSortTooltip => 'Sort';

  @override
  String get filesStillUploading =>
      'This file is still uploading — give it a moment.';

  @override
  String get filesTakePhoto => 'Take Photo';

  @override
  String get filesTheseFolders => 'these folders';

  @override
  String get filesTitle => 'Files';

  @override
  String filesTransferActive(String verb, String fileName) {
    return '$verb $fileName';
  }

  @override
  String filesTransferActiveMore(String verb, String fileName, int count) {
    return '$verb $fileName (+$count more)';
  }

  @override
  String filesTransferCancelled(String fileName) {
    return '$fileName — Cancelled';
  }

  @override
  String filesTransferDone(String fileName) {
    return '$fileName — Done';
  }

  @override
  String filesTransferDoneSize(String size) {
    return 'Done  $size';
  }

  @override
  String filesTransferFailed(String fileName) {
    return '$fileName — Failed';
  }

  @override
  String filesTransferQueued(String fileName) {
    return '$fileName — Queued';
  }

  @override
  String filesTransfersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transfers',
      one: '1 transfer',
    );
    return '$_temp0';
  }

  @override
  String get filesTransfersDismissTooltip =>
      'Dismiss — transfers continue in background';

  @override
  String get filesTransfersTitle => 'Transfers';

  @override
  String get filesTypeLabel => 'Type';

  @override
  String get filesUnknownError => 'Unknown error';

  @override
  String filesUploadFailed(String error) {
    return 'Upload failed: $error';
  }

  @override
  String get filesUploadFile => 'Upload File';

  @override
  String get filesUploadHere => 'Upload here';

  @override
  String get filesUploadMedia => 'Upload Media';

  @override
  String filesUploadingChunks(int stored, int total) {
    return 'Uploading... $stored/$total chunks';
  }

  @override
  String filesViewAsTooltip(String mode) {
    return 'View as: $mode';
  }

  @override
  String get filesViewIcons => 'Icons';

  @override
  String get filesViewList => 'List';

  @override
  String get filesViewTree => 'Tree';

  @override
  String get filesYourDrive => 'your drive';

  @override
  String get languageSubtitle => 'App display language';

  @override
  String get languageSystem => 'System default';

  @override
  String get languageTitle => 'Language';

  @override
  String get linksCopiedToClipboard => 'Link copied to clipboard';

  @override
  String get linksCopyTooltip => 'Copy link';

  @override
  String linksDeleteBody(String name) {
    return 'This will remove the shared link for \"$name\". The file itself won\'t be deleted.';
  }

  @override
  String linksDeleteFailed(String error) {
    return 'Delete failed: $error';
  }

  @override
  String get linksDeleteLink => 'Delete link';

  @override
  String get linksDeleteTitle => 'Delete link?';

  @override
  String get linksDeleted => 'Link deleted';

  @override
  String linksDownloadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count downloads',
      one: '1 download',
    );
    return '$_temp0';
  }

  @override
  String get linksEmptySubtitle =>
      'Create a link from any file\'s context menu';

  @override
  String get linksEmptyTitle => 'No shared links';

  @override
  String get linksExpired => 'Expired';

  @override
  String linksExpiresInDays(int days) {
    return 'Expires in ${days}d';
  }

  @override
  String linksExpiresInHours(int hours) {
    return 'Expires in ${hours}h';
  }

  @override
  String get linksExpiresSoon => 'Expires soon';

  @override
  String get linksExpiryRemoved => 'Expiry removed — link never expires';

  @override
  String get linksExpiryUpdated => 'Expiry updated';

  @override
  String get linksNotAuthenticated => 'Not authenticated';

  @override
  String get linksRemoveExpiry => 'Remove expiry';

  @override
  String get linksSetExpiry => 'Set expiry';

  @override
  String linksUpdateFailed(String error) {
    return 'Update failed: $error';
  }

  @override
  String get notesAuthorAnonymous => 'Anonymous';

  @override
  String get notesAuthorYou => 'You';

  @override
  String get notesBlockquote => 'Blockquote';

  @override
  String get notesBold => 'Bold';

  @override
  String get notesBulletList => 'Bullet list';

  @override
  String get notesCannotDecrypt => 'Cannot decrypt file';

  @override
  String get notesCannotOpenNoKey => 'Cannot open — decryption key unavailable';

  @override
  String notesChunkCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chunks',
      one: '1 chunk',
    );
    return '$_temp0';
  }

  @override
  String get notesClearHistoryBody =>
      'Every historical version of this note will be permanently deleted. The current note stays.';

  @override
  String get notesClearHistoryTitle => 'Clear all history?';

  @override
  String get notesClearHistoryTooltip => 'Clear all history';

  @override
  String get notesCloseEditor => 'Close editor';

  @override
  String get notesCloseNote => 'Close note';

  @override
  String get notesCode => 'Code block';

  @override
  String get notesConflictBody =>
      'The server has an unfinished save for this note from another session. Overwriting will discard whatever that session was about to commit.';

  @override
  String get notesConflictDiscardMine => 'Drop my changes';

  @override
  String get notesConflictOverwrite => 'Discard remote, save mine';

  @override
  String get notesConflictTitle => 'Another save is in progress';

  @override
  String notesCreateFolderFailed(String error) {
    return 'Failed to create folder: $error';
  }

  @override
  String notesCreateFolderIn(String folder) {
    return 'Create a new folder in \"$folder\"';
  }

  @override
  String get notesCreateFolderInRoot => 'Create a new folder in root';

  @override
  String notesCreateNoteFailed(String error) {
    return 'Failed to create note: $error';
  }

  @override
  String notesCreateNoteIn(String folder) {
    return 'Create a new note in \"$folder\"';
  }

  @override
  String get notesCreateNoteInRoot => 'Create a new note in root';

  @override
  String notesCreatedNote(String name) {
    return 'Created \"$name\"';
  }

  @override
  String get notesCreatedNoteMissingKey =>
      'Created note missing encryption key';

  @override
  String get notesDeleteAll => 'Delete all';

  @override
  String notesDeleteFolderBody(String name) {
    return '\"$name\" and everything inside it will be permanently deleted.';
  }

  @override
  String notesDeleteFolderFailed(String error) {
    return 'Failed to delete folder: $error';
  }

  @override
  String get notesDeleteFolderTitle => 'Delete folder?';

  @override
  String notesDeleteNoteBody(String name) {
    return '\"$name\" will be permanently deleted.';
  }

  @override
  String notesDeleteNoteFailed(String error) {
    return 'Failed to delete: $error';
  }

  @override
  String get notesDeleteNoteTitle => 'Delete note?';

  @override
  String get notesDeleteThisVersion => 'Delete this version';

  @override
  String notesDeleteVersionFailed(String error) {
    return 'Delete failed: $error';
  }

  @override
  String notesDeleteVersionMsg(int version, String date) {
    return 'Permanently delete v$version from $date. Cannot be undone.';
  }

  @override
  String notesDeleteVersionTitle(int version) {
    return 'Delete v$version?';
  }

  @override
  String get notesDetails => 'Details';

  @override
  String get notesDiscard => 'Discard';

  @override
  String get notesEmptyHint => 'Create one from the sidebar\'s + button.';

  @override
  String get notesEmptyTitle => 'No notes yet';

  @override
  String notesEncryptedFallback(String id) {
    return '[Encrypted] $id…';
  }

  @override
  String get notesEncryptedName => '(encrypted)';

  @override
  String get notesExport => 'Export';

  @override
  String notesExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get notesExportStarted =>
      'Export started — share sheet will open when ready';

  @override
  String get notesExportToPdf => 'Export to PDF';

  @override
  String notesExportingTo(String path) {
    return 'Exporting to $path';
  }

  @override
  String get notesFileNotFound => 'File not found';

  @override
  String get notesFolderName => 'folder';

  @override
  String get notesFolderNameHint => 'My folder';

  @override
  String notesForkFailed(String error) {
    return 'Fork failed: $error';
  }

  @override
  String notesHeading(int level) {
    return 'Heading $level';
  }

  @override
  String get notesHideSidebar => 'Hide sidebar';

  @override
  String get notesHideKeyboard => 'Hide keyboard';

  @override
  String get notesHistory => 'Version history';

  @override
  String notesHistoryNamed(String name) {
    return 'History · $name';
  }

  @override
  String get notesItalic => 'Italic';

  @override
  String get notesKeyUnavailable =>
      'Cannot decrypt — file key or client unavailable';

  @override
  String get notesLoadFailed => 'Failed to load';

  @override
  String notesLoadNotesFailed(String error) {
    return 'Failed to load notes: $error';
  }

  @override
  String get notesMetadataUnavailable => 'File metadata unavailable';

  @override
  String notesModified(String when) {
    return 'Modified $when';
  }

  @override
  String get notesMore => 'More';

  @override
  String get notesMoreActions => 'More actions';

  @override
  String notesMoveFailed(String error) {
    return 'Move failed: $error';
  }

  @override
  String get notesMoveHere => 'Move here';

  @override
  String get notesMoveToTitle => 'Move to';

  @override
  String get notesMoved => 'Moved';

  @override
  String get notesNameRequired => 'Name is required';

  @override
  String get notesNewFolder => 'New folder';

  @override
  String notesNewIn(String name) {
    return 'New note or folder in $name';
  }

  @override
  String get notesNewNote => 'New note';

  @override
  String get notesNoHistory =>
      'No history yet. Edit the note to start building one.';

  @override
  String get notesNoServerId => 'Server returned no id';

  @override
  String get notesNotAuthenticated => 'Not authenticated';

  @override
  String get notesNotSignedIn => 'Not signed in';

  @override
  String get notesNoteNameHint => 'My note';

  @override
  String get notesNumberedList => 'Numbered list';

  @override
  String notesPdfExportFailed(String error) {
    return 'PDF export failed: $error';
  }

  @override
  String get notesPreview => 'Preview';

  @override
  String notesPreviewFailed(String error) {
    return 'Preview failed: $error';
  }

  @override
  String notesPurgeFailed(String error) {
    return 'Purge failed: $error';
  }

  @override
  String get notesRecentHeader => 'Recent notes';

  @override
  String get notesRedo => 'Redo';

  @override
  String notesRenameFailed(String error) {
    return 'Failed to rename: $error';
  }

  @override
  String notesRenameFolderFailed(String error) {
    return 'Failed to rename folder: $error';
  }

  @override
  String get notesRenameNote => 'Rename note';

  @override
  String get notesResetZoom => 'Reset zoom';

  @override
  String get notesRestore => 'Restore';

  @override
  String get notesRestoreAsNew => 'Restore as new note';

  @override
  String notesRestoreFailed(String error) {
    return 'Restore failed: $error';
  }

  @override
  String get notesRestoreHere => 'Restore in place';

  @override
  String get notesRestoreThisVersion => 'Restore this version';

  @override
  String notesRestoreVersionMsg(int version, String date) {
    return 'This replaces the current content with v$version from $date. Your current version stays in history so you can undo the restore later.';
  }

  @override
  String notesRestoreVersionTitle(int version) {
    return 'Restore v$version?';
  }

  @override
  String notesRestoredVersion(int version) {
    return 'Restored v$version';
  }

  @override
  String get notesRootName => 'root';

  @override
  String get notesSaveAndClose => 'Save & close';

  @override
  String notesSaveFailed(String error) {
    return 'Failed to save: $error';
  }

  @override
  String get notesSaveNoteDialogTitle => 'Save note';

  @override
  String get notesShowSidebar => 'Show sidebar';

  @override
  String get notesSidebarEmpty => 'No notes or folders';

  @override
  String get notesSidebarHeader => 'NOTES';

  @override
  String get notesStillUploading =>
      'This note is still uploading. If it stays stuck, delete it from the Files tab and create a new one.';

  @override
  String get notesStrikethrough => 'Strikethrough';

  @override
  String get notesTable => 'Table';

  @override
  String get notesThisFolder => 'this folder';

  @override
  String get notesThisNote => 'this note';

  @override
  String get notesTitle => 'Notes';

  @override
  String get notesUndo => 'Undo';

  @override
  String get notesUnsavedChangesBody =>
      'You have unsaved changes. What would you like to do?';

  @override
  String notesUnsavedChangesTitle(String name) {
    return 'Unsaved changes — $name';
  }

  @override
  String get notesUntitled => 'Untitled';

  @override
  String get notesZoomIn => 'Zoom in';

  @override
  String get notesZoomOut => 'Zoom out';

  @override
  String get previewCannotDecrypt => 'Cannot decrypt file';

  @override
  String get previewDecryptAfterDownloadFailed =>
      'Failed to decrypt after download';

  @override
  String previewDeleteFailed(String error) {
    return 'Failed to delete: $error';
  }

  @override
  String previewDeleteFileBody(String name) {
    return 'Delete \"$name\"? This cannot be undone.';
  }

  @override
  String get previewDeleteFileTitle => 'Delete file?';

  @override
  String get previewDownloadFailed => 'Download failed';

  @override
  String get previewExport => 'Export';

  @override
  String get previewFailedToLoadImage => 'Failed to load image';

  @override
  String previewFailedToRenderPage(String error) {
    return 'Failed to render page: $error';
  }

  @override
  String get previewNoPreviewAvailable => 'No preview available';

  @override
  String get previewNoPreviewableFiles => 'No previewable files';

  @override
  String previewPageCounter(int current, int total) {
    return 'Page $current / $total';
  }

  @override
  String get previewSaveFileTitle => 'Save file';

  @override
  String previewShowingFirstMb(String size) {
    return 'Showing first 1 MB of $size';
  }

  @override
  String relativeDaysAgo(int days) {
    return '${days}d ago';
  }

  @override
  String relativeHoursAgo(int hours) {
    return '${hours}h ago';
  }

  @override
  String get relativeJustNow => 'just now';

  @override
  String relativeMinutesAgo(int minutes) {
    return '${minutes}m ago';
  }

  @override
  String get searchEmptyPrompt => 'Search your files';

  @override
  String searchEncryptedFileFallback(String id) {
    return '[Encrypted] $id...';
  }

  @override
  String searchFailed(String error) {
    return 'Search failed: $error';
  }

  @override
  String get searchHint => 'Search files and notes…';

  @override
  String get searchNoResults => 'No results found';

  @override
  String serviceBugReportShareText(String email) {
    return 'Please describe what you were doing when the bug happened, including any steps to reproduce.\n\nSend to: $email';
  }

  @override
  String get serviceBugReportSubject => 'Hoodik bug report';

  @override
  String get serviceDownloadCancelled => 'Download cancelled';

  @override
  String get serviceDownloadFailed => 'Download failed';

  @override
  String get serviceFileAlreadyExists => 'File already exists';

  @override
  String get serviceFileNoEncryptionKey => 'File has no encryption key';

  @override
  String get serviceLandingBranchFiles => 'Files';

  @override
  String get serviceLandingBranchNotes => 'Notes';

  @override
  String get serviceNotificationDownloadComplete => 'Download complete';

  @override
  String get serviceNotificationReady => 'Ready';

  @override
  String get serviceNotificationUploadComplete => 'Upload complete';

  @override
  String get serviceOfflineManagerUnavailable =>
      'Offline manager not available';

  @override
  String get serviceTransferCancelled => 'Cancelled';

  @override
  String get serviceTransferDecrypting => 'Decrypting';

  @override
  String get serviceTransferDownloading => 'Downloading';

  @override
  String get serviceTransferEncrypting => 'Encrypting';

  @override
  String get serviceTransferUploading => 'Uploading';

  @override
  String get serviceUploadCancelled => 'Upload cancelled';

  @override
  String get serviceUploadFailed => 'Upload failed';

  @override
  String get serviceUploadWorkerUnavailable =>
      'Upload requires an active encrypt worker and tar transport. Please restart the app and try again.';

  @override
  String get sharesAccessRevoked => 'Access revoked';

  @override
  String sharesAccessRevokedFor(String email) {
    return 'Access revoked for $email';
  }

  @override
  String get sharesAddFiles => 'Add files';

  @override
  String get sharesAddMember => 'Add member';

  @override
  String sharesAddMemberFailed(String error) {
    return 'Failed to add member: $error';
  }

  @override
  String sharesAddMemberToGroup(String group) {
    return 'Add member to $group';
  }

  @override
  String get sharesAddedByCoOwner => 'Added by co-owner';

  @override
  String get sharesAddedByOwner => 'Added by owner';

  @override
  String get sharesAddedByUnknown => 'Added by unknown';

  @override
  String get sharesAllowAddFiles => 'Allow them to add new files';

  @override
  String get sharesAuditARecipient => 'a recipient';

  @override
  String get sharesAuditARecipientCapital => 'A recipient';

  @override
  String get sharesAuditAccessFallback => 'access';

  @override
  String get sharesAuditBadgeMismatch => 'Mismatch';

  @override
  String get sharesAuditBadgeSystem => 'System';

  @override
  String get sharesAuditBadgeVerified => 'Verified';

  @override
  String sharesAuditCoOwnerRevoked(String recipient, String file) {
    return '$recipient\'s access to $file via a co-owner was revoked';
  }

  @override
  String sharesAuditEdited(String sender, String file) {
    return '$sender edited shared file $file';
  }

  @override
  String get sharesAuditEmpty =>
      'No sharing activity yet. Events show up here when you share a file, change a role, or revoke access.';

  @override
  String sharesAuditEvicted(String recipient, String file) {
    return '$recipient lost access to $file (cascade)';
  }

  @override
  String sharesAuditFileIdLabel(String head) {
    return 'file $head…';
  }

  @override
  String sharesAuditForked(String sender, String file) {
    return '$sender forked $file into their drive';
  }

  @override
  String sharesAuditGrant(String sender, String file, String recipient) {
    return '$sender shared $file with $recipient';
  }

  @override
  String sharesAuditGrantAsRole(
    String sender,
    String file,
    String recipient,
    String role,
  ) {
    return '$sender shared $file with $recipient as $role';
  }

  @override
  String sharesAuditKeyRotation(String sender) {
    return '$sender rotated their account encryption keys';
  }

  @override
  String get sharesAuditLegendMismatch =>
      'failed verification — do not trust this row';

  @override
  String get sharesAuditLegendSystem =>
      'a server-attributed cascade event, no signature';

  @override
  String get sharesAuditLegendVerified => 'signature and chain check out';

  @override
  String get sharesAuditLinkBroken =>
      'Chain link to the previous visible event is broken.';

  @override
  String get sharesAuditLoadFailed => 'Couldn\'t load your sharing activity.';

  @override
  String get sharesAuditLoadFailedOffline =>
      'Could not load your sharing activity. Activity needs a connection to the server — try again once you are back online.';

  @override
  String sharesAuditMovedOut(String sender, String file) {
    return '$sender moved $file out of a shared folder';
  }

  @override
  String get sharesAuditPageBoundaryNote =>
      'Earlier event in this chain is on another page';

  @override
  String get sharesAuditRecipientFallback => 'recipient';

  @override
  String sharesAuditReshared(String sender, String file, String recipient) {
    return '$sender re-shared $file with $recipient';
  }

  @override
  String sharesAuditResharedAsRole(
    String sender,
    String file,
    String recipient,
    String role,
  ) {
    return '$sender re-shared $file with $recipient as $role';
  }

  @override
  String sharesAuditRestored(String sender, String file) {
    return '$sender restored a previous version of shared file $file';
  }

  @override
  String sharesAuditRevoked(String sender, String recipient, String file) {
    return '$sender revoked $recipient from $file';
  }

  @override
  String sharesAuditRoleChanged(String sender, String recipient, String file) {
    return '$sender changed $recipient\'s role on $file';
  }

  @override
  String sharesAuditRoleChangedFromTo(
    String sender,
    String recipient,
    String file,
    String before,
    String after,
  ) {
    return '$sender changed $recipient\'s role on $file from $before to $after';
  }

  @override
  String get sharesAuditSelfHashMismatch =>
      'Row content does not match its stored hash.';

  @override
  String sharesAuditShowingRecent(int shown, int total) {
    return 'Showing the $shown most recent of $total events.';
  }

  @override
  String get sharesAuditSignatureFailed =>
      'Signature failed verification on this event.';

  @override
  String get sharesAuditSystemSender => 'system';

  @override
  String get sharesAuditTamperedBody =>
      'This event failed verification. Treat its claim with suspicion and report it to the file owner.';

  @override
  String sharesAuditUploaded(String sender, String file) {
    return '$sender uploaded into shared folder $file';
  }

  @override
  String get sharesCannotAddSelfToGroup =>
      'You cannot add yourself to a group.';

  @override
  String get sharesCannotDecryptFileKey => 'Cannot decrypt the file key';

  @override
  String get sharesCannotShareWithSelf => 'You can\'t share with yourself.';

  @override
  String get sharesChangeRole => 'Change role';

  @override
  String get sharesDeleteGroup => 'Delete group';

  @override
  String sharesDeleteGroupBody(String name) {
    return 'Delete \"$name\"? Files you already shared with these people stay shared; the group is just removed as a saved selection.';
  }

  @override
  String get sharesDeleteGroupTitle => 'Delete group?';

  @override
  String get sharesDestinationIsShared =>
      'The destination is itself a shared folder. Pick a private folder or your drive root.';

  @override
  String get sharesEmailPlaceholder => 'someone@example.com';

  @override
  String get sharesEmailUnknownCannotChangeRole =>
      'Email unknown — cannot change role';

  @override
  String get sharesEnterMemberEmailFirst => 'Enter the member email first.';

  @override
  String get sharesEnterRecipientEmailFirst =>
      'Enter the recipient email first.';

  @override
  String get sharesEveryoneCanRead =>
      'Everyone listed will be able to read every file in this folder.';

  @override
  String sharesEvictFailed(String error) {
    return 'Failed to evict: $error';
  }

  @override
  String get sharesFindUser => 'Find user';

  @override
  String get sharesGiveGroupName => 'Give the group a name.';

  @override
  String sharesGroupCreateFailed(String error) {
    return 'Could not create the group: $error';
  }

  @override
  String get sharesGroupDeleteFailed => 'Could not delete the group.';

  @override
  String sharesGroupDeleted(String name) {
    return '\"$name\" deleted.';
  }

  @override
  String get sharesGroupLabel => 'Group';

  @override
  String sharesGroupMemberKeyUnverified(String email) {
    return 'A group member\'s key could not be verified — refusing to share. ($email)';
  }

  @override
  String get sharesGroupNameLabel => 'Group name';

  @override
  String get sharesGroupNamePlaceholder => 'e.g. Marketing team';

  @override
  String get sharesGroupNameTaken => 'A group with that name already exists.';

  @override
  String get sharesGroupNoOneElse =>
      'This group has no one else to share with yet.';

  @override
  String sharesGroupReady(String name) {
    return '\"$name\" is ready to receive members.';
  }

  @override
  String sharesGroupRenameFailed(String error) {
    return 'Could not rename the group: $error';
  }

  @override
  String get sharesGroupRoleCoOwnerDescription =>
      'Co-owner — can also manage members and rename.';

  @override
  String get sharesGroupRoleEditorDescription =>
      'Editor — can share files to the group.';

  @override
  String get sharesGroupRoleLabel => 'Group role';

  @override
  String get sharesGroupRoleOwnerDescription =>
      'Owner — full control of the group.';

  @override
  String get sharesGroupRoleReaderDescription =>
      'Reader — sees the group, nothing more.';

  @override
  String get sharesGroupsExplainer =>
      'Groups let you share with everyone in the group at once.';

  @override
  String get sharesGroupsLoadFailed => 'Could not load your groups.';

  @override
  String get sharesInvalidEmail => 'That doesn’t look like an email address.';

  @override
  String sharesItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get sharesKeyFingerprintMismatch =>
      'This account\'s key and fingerprint do not match. Sharing is blocked — do not proceed.';

  @override
  String get sharesLookupFailed => 'Could not look up that user.';

  @override
  String sharesMemberAddedToGroup(String email, String group) {
    return '$email is now part of \"$group\".';
  }

  @override
  String sharesMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String get sharesMemberEmailLabel => 'Member email';

  @override
  String sharesMemberNowRole(String email, String role) {
    return '$email is now $role.';
  }

  @override
  String get sharesMemberOfHeader => 'MEMBER OF';

  @override
  String get sharesMemberRemoveFailed => 'Could not remove the member.';

  @override
  String get sharesMemberRemoved => 'Member removed.';

  @override
  String get sharesMemberRoleChangeFailed =>
      'Could not change the member\'s role.';

  @override
  String sharesMembersCount(int count) {
    return 'Members ($count)';
  }

  @override
  String get sharesMembersLoadFailed => 'Could not load the member list.';

  @override
  String get sharesMembersLoadFailedOffline =>
      'Could not load the member list. The roster needs a connection to the server — try again once you are back online.';

  @override
  String get sharesMembersTitle => 'Members';

  @override
  String get sharesMismatchAcknowledge =>
      'I\'ve verified this new fingerprint with the recipient out of band.';

  @override
  String get sharesMoveAndShare => 'Move and share';

  @override
  String get sharesMoveAndShareTitle => 'Move and share folder?';

  @override
  String get sharesMoveCheckFailed =>
      'Could not check where these items live. Check your connection and try again.';

  @override
  String sharesMoveFailed(String error) {
    return 'Failed to move: $error';
  }

  @override
  String sharesMoveWillMove(String folder, String destination, String items) {
    return 'Moving \"$folder\" into \"$destination\" will move it and its $items.';
  }

  @override
  String sharesMoveWillShare(
    String folder,
    String destination,
    String items,
    String members,
  ) {
    return 'Moving \"$folder\" into \"$destination\" will share it and its $items with $members.';
  }

  @override
  String sharesMovedItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Moved $count items',
      one: 'Moved 1 item',
    );
    return '$_temp0';
  }

  @override
  String sharesNamesAndOthers(String first, String second, int count) {
    return '$first, $second and $count others';
  }

  @override
  String get sharesNewGroup => 'New group';

  @override
  String get sharesNewShareGroup => 'New share group';

  @override
  String get sharesNoAccessYet => 'No one has access yet.';

  @override
  String get sharesNoLongerHaveAccess =>
      'You no longer have access to this folder.';

  @override
  String get sharesNoMemberOfGroups => 'No one has added you to a group yet.';

  @override
  String get sharesNoMembersYet =>
      'No members yet — add someone to share with this group.';

  @override
  String get sharesNoOwnedGroups =>
      'You haven\'t created any groups yet. Groups let you share with several people at once.';

  @override
  String get sharesNoUserWithEmail => 'No Hoodik user with that email.';

  @override
  String get sharesNotAuthenticated => 'Not authenticated.';

  @override
  String get sharesNotGroupEditor =>
      'You\'re not an editor of any group yet. Create a group or ask its owner to make you an editor.';

  @override
  String get sharesOnlyOwnedIntoShared =>
      'You can only move files you own into a shared folder.';

  @override
  String get sharesOnlyOwnerCanMoveOut =>
      'Only the owner can move a file out of a shared folder.';

  @override
  String get sharesOnlyOwnerCanMoveThisOut =>
      'Only the owner can move this file out of the shared folder.';

  @override
  String sharesOwnedBy(String email) {
    return 'owned by $email';
  }

  @override
  String get sharesOwnedGroupsHeader => 'OWNED GROUPS';

  @override
  String get sharesOwnerCannotBeRemoved => 'The owner cannot be removed.';

  @override
  String get sharesPeopleWithAccess => 'People with access';

  @override
  String get sharesPickEditorToEnable => 'Pick Editor or Co-owner to enable';

  @override
  String sharesPreparingAccess(int done, int total) {
    return 'Preparing access ($done / $total)';
  }

  @override
  String get sharesPreviouslyTrusted => 'Previously trusted';

  @override
  String get sharesRecipientEmailLabel => 'Recipient email';

  @override
  String get sharesRecipientsLoadFailed =>
      'Could not load existing recipients.';

  @override
  String get sharesRefresh => 'Refresh';

  @override
  String get sharesRemoveMember => 'Remove member';

  @override
  String sharesRemoveMemberBody(String email, String name) {
    return 'Remove $email from \"$name\"? Files you already shared with them stay shared; they just won\'t be included next time you share with this group.';
  }

  @override
  String get sharesRemoveMemberTitle => 'Remove member?';

  @override
  String get sharesRenameGroup => 'Rename group';

  @override
  String sharesRenamedTo(String name) {
    return 'Renamed to \"$name\".';
  }

  @override
  String get sharesRevoke => 'Revoke';

  @override
  String get sharesRevokeAccessTitle => 'Revoke access?';

  @override
  String sharesRevokeCascadeExtra(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count shares',
      one: '1 share',
    );
    return 'This also removes $_temp0 they granted under this folder.';
  }

  @override
  String sharesRevokeFailed(String error) {
    return 'Failed to revoke: $error';
  }

  @override
  String sharesRevokeFileBody(String email) {
    return '$email will no longer be able to open this file.';
  }

  @override
  String sharesRevokeFolderBody(String name, String folder) {
    return '$name will lose access to $folder.';
  }

  @override
  String get sharesRoleCoOwner => 'Co-owner';

  @override
  String get sharesRoleCoOwnerDescription =>
      'Co-owner — can view, edit, re-share, and save copies.';

  @override
  String get sharesRoleEditor => 'Editor';

  @override
  String get sharesRoleEditorDescription =>
      'Editor — can view and edit. No re-share.';

  @override
  String get sharesRoleLabel => 'Role';

  @override
  String get sharesRoleOwner => 'Owner';

  @override
  String get sharesRoleReader => 'Reader';

  @override
  String get sharesRoleReaderDescription => 'Reader — can view only.';

  @override
  String get sharesServerReturnedNow => 'Server returned now';

  @override
  String get sharesSetGroupRole => 'Set group role';

  @override
  String sharesShareFailed(String error) {
    return 'Failed to share: $error';
  }

  @override
  String get sharesShareFileTitle => 'Share file';

  @override
  String get sharesShareFromShareMenu =>
      'Share a file to this group from its share menu.';

  @override
  String get sharesShareToGroup => 'Share to group';

  @override
  String sharesShareToGroupFailed(String error) {
    return 'Failed to share to group: $error';
  }

  @override
  String get sharesShareWithGroup => 'Share with a group';

  @override
  String sharesSharedWith(String email) {
    return 'Shared with $email';
  }

  @override
  String get sharesSharedWithGroup => 'Shared with the group.';

  @override
  String get sharesSharedWithMe => 'Shared with me';

  @override
  String get sharesSharingDisabled => 'Sharing is disabled on this server.';

  @override
  String sharesSubtreeTooLargeMove(int cap) {
    return 'This folder has more than $cap files. Move a sub-folder instead.';
  }

  @override
  String sharesSubtreeTooLargeShare(int cap) {
    return 'This folder has more than $cap files. Share a sub-folder instead.';
  }

  @override
  String get sharesTabActivity => 'Activity';

  @override
  String get sharesTabGroups => 'Groups';

  @override
  String get sharesTabPublicLinks => 'Public links';

  @override
  String get sharesTooManyLookups => 'Too many lookups, try again shortly.';

  @override
  String get sharesTrustFirstSight =>
      'First time sharing with this account. Compare the fingerprint out of band if you want certainty — we will warn loudly if it ever changes.';

  @override
  String get sharesTrustMismatchBody =>
      'This recipient\'s key fingerprint changed since you last trusted it. This is what a legitimate key rotation looks like — and also exactly what a key-substitution attack looks like. The server cannot tell them apart; only you can, by verifying out of band.';

  @override
  String get sharesTrustVerified =>
      'Verified — this fingerprint matches the one you trusted before.';

  @override
  String sharesTwoNames(String first, String second) {
    return '$first and $second';
  }

  @override
  String get widgetDismiss => 'Dismiss';

  @override
  String widgetOutdatedServer(String version, String latest) {
    return 'Your Hoodik server is $version. Upgrade to v$latest to get the latest features and bug fixes.';
  }

  @override
  String widgetOutdatedServerNoLatest(String version) {
    return 'Your Hoodik server is $version. Upgrade to the latest release for new features and bug fixes.';
  }

  @override
  String get widgetServerVersionUnknown => 'older than v1.16.0';

  @override
  String get widgetUpdate => 'Update';

  @override
  String widgetUpdateAvailable(String version) {
    return 'A new version of Hoodik (v$version) is available.';
  }

  @override
  String get widgetUpdateDownloaded =>
      'A new version of Hoodik has been downloaded.';

  @override
  String get widgetUpdateRestart => 'Restart';
}
