// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get accountActiveTransfers => 'Übertragungen laufen gerade';

  @override
  String get accountAdminHeader => 'VERWALTUNG';

  @override
  String get accountAdminPanel => 'Admin-Bereich';

  @override
  String get accountAdminPanelSubtitle =>
      'Benutzer, Einladungen & Einstellungen';

  @override
  String get accountAiAccessMacosOnly =>
      'KI-Zugriff über MCP ist in der macOS-Version von Hoodik verfügbar.';

  @override
  String get accountAiAccessSubtitle => 'MCP-Server für KI-Agenten';

  @override
  String get accountAiAccessTitle => 'KI-Zugriff';

  @override
  String get accountAllAccountsHeader => 'ALLE KONTEN';

  @override
  String get accountAppearance => 'Erscheinungsbild';

  @override
  String get accountAppearanceSubtitle => 'Hell, dunkel oder dem System folgen';

  @override
  String get accountAuditAllStatuses => 'Alle Status';

  @override
  String get accountAuditAllTools => 'Alle Tools';

  @override
  String get accountAuditClearConfirmBody =>
      'Dies entfernt alle aufgezeichneten Tool-Aufrufe endgültig. Ihre Dateien sind nicht betroffen.';

  @override
  String get accountAuditClearConfirmTitle => 'Audit-Log leeren?';

  @override
  String get accountAuditClearLog => 'Log leeren';

  @override
  String get accountAuditCleared => 'Audit-Log geleert';

  @override
  String get accountAuditDuration => 'Dauer';

  @override
  String get accountAuditEmptyBody =>
      'Jeder KI-Tool-Aufruf wird hier aufgezeichnet. Aktivieren Sie den KI-Zugriff und verbinden Sie einen Agenten, um Aktivität zu sehen.';

  @override
  String get accountAuditEmptyTitle => 'Noch keine Audit-Einträge';

  @override
  String get accountAuditError => 'Fehler';

  @override
  String get accountAuditFilterByStatus => 'Nach Status filtern';

  @override
  String get accountAuditFilterByTool => 'Nach Tool filtern';

  @override
  String accountAuditLoadFailed(String error) {
    return 'Laden fehlgeschlagen: $error';
  }

  @override
  String get accountAuditLogTitle => 'Audit-Log';

  @override
  String accountAuditMilliseconds(int ms) {
    return '$ms ms';
  }

  @override
  String get accountAuditNoParams => '(keine Parameter)';

  @override
  String get accountAuditParamsHash => 'Parameter-Hash';

  @override
  String get accountAuditSession => 'Sitzung';

  @override
  String get accountAuditStatus => 'Status';

  @override
  String get accountAuditStatusDenied => 'Abgelehnt';

  @override
  String get accountAuditStatusOk => 'Ok';

  @override
  String get accountAuditTimestamp => 'Zeitstempel';

  @override
  String get accountClear => 'Leeren';

  @override
  String get accountDefaultLanding => 'Startansicht';

  @override
  String get accountDefaultLandingSubtitle =>
      'Der Tab, der beim Öffnen der App angezeigt wird';

  @override
  String get accountDiagnosticsExportLogs => 'Logs exportieren';

  @override
  String get accountDiagnosticsLogsInfo =>
      'Logs können Dateinamen und Server-URLs enthalten, damit Sie erkennen, worauf sich jede Zeile bezieht. Sie enthalten niemals Dateiinhalte, Passwörter oder Verschlüsselungsschlüssel. Sie sehen jede Zeile und können vor dem Senden alles entfernen.';

  @override
  String get accountDiagnosticsNoTelemetryBody =>
      'Hoodik verwendet weder Sentry noch Crash-Reporter oder Analytics von Drittanbietern. Ihr Gerät sendet nur die Daten, die für die verschlüsselte Dateisynchronisierung nötig sind.';

  @override
  String get accountDiagnosticsNoTracking =>
      'Wir erfassen nichts über Ihr Gerät.';

  @override
  String get accountDiagnosticsStep1 => 'Schließen Sie Hoodik vollständig.';

  @override
  String get accountDiagnosticsStep2 => 'Öffnen Sie die App erneut.';

  @override
  String get accountDiagnosticsStep3 =>
      'Versuchen Sie, den Fehler zu reproduzieren.';

  @override
  String get accountDiagnosticsStep4 =>
      'Kommen Sie hierher zurück und tippen Sie unten auf „Logs exportieren“.';

  @override
  String get accountDiagnosticsSubtitle =>
      'Fehlerbericht senden – keine Telemetrie';

  @override
  String get accountDiagnosticsTellUsBody =>
      'Wenn etwas kaputtgeht, erfahren wir es deshalb nur, wenn Sie es uns mitteilen. So helfen Sie uns am besten:';

  @override
  String get accountDiagnosticsTitle => 'Datenschutz & Diagnose';

  @override
  String get accountDisable => 'Deaktivieren';

  @override
  String get accountEnable => 'Aktivieren';

  @override
  String get accountEnabled => 'Aktiviert';

  @override
  String get accountEnterPinBody =>
      'Geben Sie Ihre PIN ein, um die biometrische Entsperrung zu aktivieren.';

  @override
  String get accountEnterPinTitle => 'PIN eingeben';

  @override
  String get accountIncorrectPin => 'Falsche PIN';

  @override
  String get accountLegalHeader => 'RECHTLICHES';

  @override
  String get accountLogsClearAll => 'Alle löschen';

  @override
  String get accountLogsCopied => 'Logs in die Zwischenablage kopiert';

  @override
  String get accountLogsCopyToClipboard => 'In die Zwischenablage kopieren';

  @override
  String get accountLogsCurrentSession => 'Aktuelle Sitzung';

  @override
  String get accountLogsEmptyBody =>
      'Schließen Sie die App, öffnen Sie sie erneut, reproduzieren Sie den Fehler und versuchen Sie es dann hier noch einmal.';

  @override
  String get accountLogsEmptyTitle => 'Keine Log-Zeilen zum Überprüfen.';

  @override
  String accountLogsLineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Zeilen',
      one: '1 Zeile',
    );
    return '$_temp0';
  }

  @override
  String get accountLogsPastDays => 'Letzte 3 Tage';

  @override
  String get accountLogsReviewTitle => 'Logs überprüfen';

  @override
  String accountLogsSendViaEmail(String email) {
    return 'Per E-Mail senden ($email)';
  }

  @override
  String get accountLogsShareFailed =>
      'Teilen fehlgeschlagen – verwenden Sie stattdessen „In die Zwischenablage kopieren“';

  @override
  String get accountManageAccounts => 'Konten verwalten';

  @override
  String get accountManageAccountsSubtitle => 'Konten hinzufügen oder wechseln';

  @override
  String get accountMcpActivityHeader => 'AKTIVITÄT';

  @override
  String get accountMcpAllowReadOnlyOff =>
      'Bei PIN-Sperre ist jeglicher Agentenzugriff pausiert';

  @override
  String get accountMcpAllowReadOnlyOn =>
      'Agenten dürfen bei PIN-Sperre Dateien auflisten und durchsuchen';

  @override
  String get accountMcpAllowReadOnlyTitle =>
      'Lesezugriff im gesperrten Zustand erlauben';

  @override
  String get accountMcpBearerToken => 'Bearer-Token';

  @override
  String get accountMcpBurstCapacity => 'Burst-Kapazität';

  @override
  String get accountMcpClearAuditLog => 'Audit-Log leeren';

  @override
  String get accountMcpClearAuditLogSubtitle =>
      'Entfernt alle aufgezeichneten Tool-Aufrufe';

  @override
  String get accountMcpConfigCopied =>
      'Konfiguration in die Zwischenablage kopiert';

  @override
  String get accountMcpConfigFootnote =>
      'Kopieren Sie dieses JSON in die MCP-Server-Konfiguration von Claude Desktop oder Claude Code.';

  @override
  String get accountMcpConfigurationHeader => 'KONFIGURATION';

  @override
  String get accountMcpConnectClientSubtitle =>
      'Geführte Einrichtung für Claude Desktop, Cursor und andere';

  @override
  String get accountMcpConnectClientTitle => 'KI-Client verbinden';

  @override
  String get accountMcpConnectionHeader => 'VERBINDUNG';

  @override
  String get accountMcpCopyConfig => 'Konfiguration kopieren';

  @override
  String get accountMcpDisabled => 'Deaktiviert';

  @override
  String get accountMcpEnable => 'KI-Zugriff aktivieren';

  @override
  String get accountMcpEnableFootnote =>
      'Wenn aktiviert, können KI-Agenten wie Claude Desktop und Claude Code über einen lokalen Endpunkt auf Ihre verschlüsselten Dateien zugreifen.';

  @override
  String get accountMcpEndpoint => 'Endpunkt';

  @override
  String accountMcpLastAgentCall(String time) {
    return 'Letzter Agentenaufruf $time';
  }

  @override
  String get accountMcpLockedFootnote =>
      'Wenn die App mit einer PIN gesperrt ist, müssen Sie sie zum Entschlüsseln von Dateiinhalten entsperren. Der Lesezugriff gibt nur verschlüsselte Metadaten preis, die der Server ohnehin kennt.';

  @override
  String get accountMcpNoAgentActivity => 'Noch keine Agentenaktivität';

  @override
  String get accountMcpNotRunning => 'Nicht aktiv';

  @override
  String get accountMcpOffSubtitle =>
      'Aktivieren Sie den KI-Zugriff, um den lokalen MCP-Server zu starten.';

  @override
  String accountMcpPausedSubtitle(int port) {
    return 'Port $port reserviert • zum Fortsetzen neu starten';
  }

  @override
  String accountMcpPerSecondOption(int value) {
    return '$value / Sek.';
  }

  @override
  String get accountMcpPort => 'Port';

  @override
  String get accountMcpPortRange =>
      'Der Port muss zwischen 1024 und 65535 liegen';

  @override
  String accountMcpPortUpdated(int port) {
    return 'Port auf $port geändert';
  }

  @override
  String get accountMcpQuickActionsHeader => 'SCHNELLAKTIONEN';

  @override
  String get accountMcpRateLimitFootnote =>
      'Ein Token-Bucket drosselt jede KI-Sitzung. Die Burst-Kapazität bestimmt, wie viele Anfragen direkt hintereinander erlaubt sind, bevor sich der Bucket mit der konfigurierten Rate wieder füllt.';

  @override
  String get accountMcpRateLimitHeader => 'RATENLIMIT';

  @override
  String get accountMcpRegenerate => 'Neu erzeugen';

  @override
  String get accountMcpRequestsPerSecond => 'Anfragen pro Sekunde';

  @override
  String accountMcpRetentionDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage',
      one: '1 Tag',
    );
    return '$_temp0';
  }

  @override
  String get accountMcpRetentionForever => 'Unbegrenzt';

  @override
  String get accountMcpRetentionHeader => 'AUDIT-AUFBEWAHRUNG';

  @override
  String get accountMcpRetentionOneYear => '1 Jahr';

  @override
  String get accountMcpRetentionTitle => 'Einträge aufbewahren für';

  @override
  String get accountMcpRotateToken => 'Bearer-Token rotieren';

  @override
  String get accountMcpRotateTokenSubtitle =>
      'Macht jeden konfigurierten KI-Client ungültig';

  @override
  String accountMcpRunningOnPort(int port) {
    return 'Läuft auf Port $port';
  }

  @override
  String get accountMcpSecurityHeader => 'SICHERHEIT';

  @override
  String get accountMcpServerHeader => 'MCP-SERVER';

  @override
  String get accountMcpStarting => 'Wird gestartet...';

  @override
  String get accountMcpStatusOff => 'Aus';

  @override
  String get accountMcpStatusPaused => 'Pausiert';

  @override
  String get accountMcpStatusRunning => 'Aktiv';

  @override
  String get accountMcpStopServer => 'Server stoppen';

  @override
  String get accountMcpStopServerSubtitle => 'Schließt den lokalen MCP-Port';

  @override
  String get accountMcpTokenCopied => 'Token in die Zwischenablage kopiert';

  @override
  String get accountMcpTokenRegenerated => 'Token neu erzeugt';

  @override
  String get accountMcpUnavailable =>
      'MCP-Server ist nicht verfügbar. Melden Sie sich auf macOS an, um fortzufahren.';

  @override
  String get accountMcpViewAuditLog => 'Audit-Log ansehen';

  @override
  String get accountMcpViewAuditLogSubtitle =>
      'Jeden KI-Tool-Aufruf überprüfen';

  @override
  String get accountMcpWizardMacosOnly =>
      'Der Verbindungsassistent ist in der macOS-Version von Hoodik verfügbar.';

  @override
  String get accountNotConfigured => 'Nicht konfiguriert';

  @override
  String get accountNotSignedIn => 'Nicht angemeldet';

  @override
  String accountOfflineCacheStats(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien',
      one: '1 Datei',
    );
    return '$_temp0 · $size';
  }

  @override
  String get accountOfflineCacheTitle => 'Offline-Cache';

  @override
  String accountOfflineCacheOfLimit(String used, String limit) {
    return '$used von $limit';
  }

  @override
  String accountOfflineCacheUnlimited(String used) {
    return '$used · Unbegrenzt';
  }

  @override
  String get accountCacheLimitTitle => 'Cache-Limit';

  @override
  String get accountCacheLimit2Gb => '2 GB';

  @override
  String get accountCacheLimit8Gb => '8 GB';

  @override
  String get accountCacheLimit32Gb => '32 GB';

  @override
  String get accountCacheLimitUnlimited => 'Unbegrenzt';

  @override
  String get accountOfflineClearBody =>
      'Dies entfernt alle Offline-Kopien Ihrer Dateien von diesem Gerät. Ihre Dateien auf dem Server sind nicht betroffen.';

  @override
  String get accountOfflineClearTitle => 'Offline-Cache leeren';

  @override
  String get accountOfflineCleared => 'Offline-Cache geleert';

  @override
  String get accountOfflineNoFiles => 'Keine Dateien im Cache';

  @override
  String get accountOpenSourceLicenses => 'Open-Source-Lizenzen';

  @override
  String get accountPasscodeLock => 'PIN-Sperre';

  @override
  String get accountPinLabel => 'PIN';

  @override
  String get accountPrivacyPolicy => 'Datenschutzerklärung';

  @override
  String get accountRecoveryHide => 'Verbergen';

  @override
  String get accountRecoveryKeyBody =>
      'Mit diesem Schlüssel stellen Sie Ihr Konto wieder her, falls Sie Ihr Passwort einmal vergessen. Bewahren Sie eine Kopie an einem sicheren, privaten Ort auf – wer diesen Schlüssel besitzt, kann sich als Sie anmelden. Wählen Sie zur Verwendung „Mit Schlüssel anmelden“ auf der Anmeldeseite.';

  @override
  String get accountRecoveryKeyCopied => 'Wiederherstellungsschlüssel kopiert';

  @override
  String get accountRecoveryKeyLocked =>
      'Ihre Schlüssel sind gerade nicht entsperrt. Melden Sie sich mit Ihrem Passwort an, um Ihren Wiederherstellungsschlüssel zu exportieren.';

  @override
  String get accountRecoveryKeySubtitle => 'Sichern Sie Ihren Anmeldeschlüssel';

  @override
  String get accountRecoveryKeyTitle => 'Wiederherstellungsschlüssel';

  @override
  String get accountRecoveryReveal => 'Anzeigen';

  @override
  String get accountRemovePasscodeBody =>
      'Dies entfernt den PIN-Sperrbildschirm. Beim nächsten Mal müssen Sie sich mit Ihrem Passwort anmelden.';

  @override
  String get accountRemovePasscodeTitle => 'PIN entfernen';

  @override
  String get accountSetUp => 'Einrichten';

  @override
  String get accountSetUpPinFirst => 'Richten Sie zuerst eine PIN ein';

  @override
  String get accountSettingsHeader => 'EINSTELLUNGEN';

  @override
  String get accountSharingDisabledMsg =>
      'Sie erhalten keine Freigabe-E-Mails mehr.';

  @override
  String get accountSharingEmailToggle =>
      'E-Mail senden, wenn jemand eine Datei mit mir teilt';

  @override
  String get accountSharingEmailsOff => 'Freigabe-E-Mails sind deaktiviert.';

  @override
  String get accountSharingEmailsOn => 'Sie erhalten Freigabe-E-Mails.';

  @override
  String get accountSharingEnabledMsg =>
      'Sie erhalten eine E-Mail, wenn jemand eine Datei mit Ihnen teilt.';

  @override
  String get accountSharingHeader => 'FREIGABEN';

  @override
  String get accountSharingUpdateFailed =>
      'Freigabe-Benachrichtigungen konnten nicht aktualisiert werden.';

  @override
  String get accountSignOut => 'Abmelden';

  @override
  String get accountSignOutConfirm => 'Möchten Sie sich wirklich abmelden?';

  @override
  String accountStorageQuota(String size) {
    return 'Kontingent: $size';
  }

  @override
  String get accountStorageTitle => 'Speicher';

  @override
  String get accountStorageUnlimited => 'Unbegrenzt';

  @override
  String accountStorageUsed(Object used) {
    return '$used belegt';
  }

  @override
  String accountStorageUsedOfTotal(Object used, Object total) {
    return '$used von $total belegt';
  }

  @override
  String get accountTermsOfService => 'Nutzungsbedingungen';

  @override
  String get accountTitle => 'Konto';

  @override
  String get accountWizardCallingInitialize => 'initialize wird aufgerufen…';

  @override
  String accountWizardCapabilitiesList(String list) {
    return 'Capabilities: $list';
  }

  @override
  String get accountWizardCapabilitiesNone => 'Capabilities: keine gemeldet';

  @override
  String get accountWizardConnected => 'Verbunden';

  @override
  String get accountWizardConnectionFailed =>
      'Verbindung fehlgeschlagen. Prüfen Sie Server und Token.';

  @override
  String get accountWizardCopyToClipboard => 'In die Zwischenablage kopieren';

  @override
  String get accountWizardCopyToken => 'Token kopieren';

  @override
  String get accountWizardEnableHint =>
      'Aktivieren, um den lokalen Port zu binden.';

  @override
  String get accountWizardFailed => 'Fehlgeschlagen';

  @override
  String get accountWizardFinish => 'Fertigstellen';

  @override
  String get accountWizardHideToken => 'Token verbergen';

  @override
  String get accountWizardNext => 'Weiter';

  @override
  String get accountWizardNoToken => '(kein Token)';

  @override
  String get accountWizardOpenFolder => 'Konfigurationsordner öffnen';

  @override
  String accountWizardProtocol(String version) {
    return 'Protokoll $version';
  }

  @override
  String get accountWizardReadyBody =>
      'Wählen Sie „Test ausführen“, um initialize gegen den lokalen Server aufzurufen.';

  @override
  String get accountWizardReadyTitle => 'Bereit zum Testen';

  @override
  String get accountWizardRegenerateConfirmBody =>
      'Dies macht bestehende Agentensitzungen ungültig. Sie müssen das neue Token in jeden konfigurierten KI-Client einfügen.';

  @override
  String get accountWizardRegenerateConfirmTitle =>
      'Bearer-Token neu erzeugen?';

  @override
  String get accountWizardRunTest => 'Test ausführen';

  @override
  String accountWizardServerName(String name) {
    return 'Server $name';
  }

  @override
  String get accountWizardShowToken => 'Token anzeigen';

  @override
  String get accountWizardStep1Subtitle =>
      'Der lokale MCP-Server muss laufen, bevor wir Ihrem KI-Client Zugangsdaten übergeben können.';

  @override
  String get accountWizardStep1Title => 'Schritt 1 von 4: MCP-Server starten';

  @override
  String get accountWizardStep2Subtitle =>
      'Ihr KI-Client authentifiziert mit diesem Token jeden MCP-Aufruf. Behandeln Sie es wie ein Passwort.';

  @override
  String get accountWizardStep2Title =>
      'Schritt 2 von 4: Bearer-Token überprüfen';

  @override
  String get accountWizardStep3Title =>
      'Schritt 3 von 4: In Ihren KI-Client kopieren';

  @override
  String get accountWizardStep4Subtitle =>
      'Wir rufen initialize über den lokalen MCP-Socket auf und zeigen Ihnen genau, was Ihr KI-Client sehen wird.';

  @override
  String get accountWizardStep4Title =>
      'Schritt 4 von 4: Handshake verifizieren';

  @override
  String get accountWizardTesting => 'Wird getestet';

  @override
  String get accountWizardTryAgain => 'Erneut versuchen';

  @override
  String adminActionFailed(String error) {
    return 'Fehlgeschlagen: $error';
  }

  @override
  String get adminActionsHeader => 'AKTIONEN';

  @override
  String get adminAdminRole => 'Admin-Rolle';

  @override
  String get adminAllowRegistration => 'Registrierung erlauben';

  @override
  String get adminAllowRegistrationSubtitle =>
      'Neue Benutzer können sich ohne Einladung registrieren';

  @override
  String get adminBadgeAdmin => 'Admin';

  @override
  String get adminCopied => 'Kopiert';

  @override
  String get adminDefaultQuotaGbLabel => 'Standard-Kontingent (GB)';

  @override
  String get adminDefaultQuotaHeader => 'STANDARD-KONTINGENT';

  @override
  String get adminDeleteUser => 'Benutzer löschen';

  @override
  String adminDeleteUserBody(String email) {
    return '$email und ALLE zugehörigen Dateien endgültig löschen? Dies kann nicht rückgängig gemacht werden.';
  }

  @override
  String get adminDeleteUserSubtitle =>
      'Benutzer und alle Daten endgültig löschen';

  @override
  String get adminDisable => 'Deaktivieren';

  @override
  String get adminDisableTfa => '2FA deaktivieren';

  @override
  String adminDisableTfaBody(String email) {
    return 'Dies entfernt die 2FA für $email. Die Person muss sie selbst wieder aktivieren.';
  }

  @override
  String get adminDisableTfaTitle =>
      'Zwei-Faktor-Authentifizierung deaktivieren';

  @override
  String get adminDisabled => 'Deaktiviert';

  @override
  String get adminEditRoleQuotaTooltip => 'Rolle & Kontingent bearbeiten';

  @override
  String get adminEditUserTitle => 'Benutzer bearbeiten';

  @override
  String get adminEmailHeader => 'E-MAIL';

  @override
  String get adminEmailLabel => 'E-Mail';

  @override
  String adminEmailTestFailed(String error) {
    return 'E-Mail-Test fehlgeschlagen: $error';
  }

  @override
  String get adminEmailVerifiedLabel => 'E-Mail verifiziert';

  @override
  String get adminEnabled => 'Aktiviert';

  @override
  String get adminEnforceEmailVerification => 'E-Mail-Verifizierung erzwingen';

  @override
  String get adminEnforceEmailVerificationSubtitle =>
      'Benutzer müssen ihre E-Mail-Adresse vor der Anmeldung verifizieren';

  @override
  String get adminExpire => 'Ablaufen lassen';

  @override
  String adminExpireInvitationBody(String email) {
    return 'Die Einladung für $email ablaufen lassen? Sie kann dann nicht mehr zur Registrierung verwendet werden.';
  }

  @override
  String get adminExpireInvitationTitle => 'Einladung ablaufen lassen';

  @override
  String adminFileCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien',
      one: '1 Datei',
    );
    return '$_temp0';
  }

  @override
  String adminInvitationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einladungen',
      one: '1 Einladung',
    );
    return '$_temp0';
  }

  @override
  String adminInvitationSent(String email) {
    return 'Einladung an $email gesendet';
  }

  @override
  String get adminInvite => 'Einladen';

  @override
  String get adminKillAll => 'Alle beenden';

  @override
  String get adminKillAllSessions => 'Alle Sitzungen beenden';

  @override
  String adminKillAllSessionsBody(String email) {
    return 'Dies meldet $email auf allen Geräten ab.';
  }

  @override
  String adminLastActive(String time) {
    return 'Aktiv $time';
  }

  @override
  String get adminNoActiveSessions => 'Keine aktiven Sitzungen';

  @override
  String get adminNoFiles => 'Keine Dateien';

  @override
  String get adminNoFilesSubtitle =>
      'Dieser Benutzer hat keine Dateien hochgeladen';

  @override
  String get adminNoInvitations => 'Noch keine Einladungen';

  @override
  String get adminNoUsersFound => 'Keine Benutzer gefunden';

  @override
  String get adminNotVerified => 'Nicht verifiziert';

  @override
  String adminPaginationRange(int start, int end, int total) {
    return '$start–$end von $total';
  }

  @override
  String get adminPanelTitle => 'Admin-Bereich';

  @override
  String get adminQuotaDefaultHint => 'Leer lassen für Standard';

  @override
  String get adminQuotaGbLabel => 'Kontingent (GB)';

  @override
  String get adminQuotaLabel => 'Kontingent';

  @override
  String get adminQuotaUnlimitedHint => 'Leer lassen für unbegrenzt';

  @override
  String get adminRegisteredLabel => 'Registriert';

  @override
  String get adminRegistrationHeader => 'BENUTZERREGISTRIERUNG';

  @override
  String get adminRoleAdmin => 'Admin';

  @override
  String get adminRoleLabel => 'Rolle';

  @override
  String get adminRoleUser => 'Benutzer';

  @override
  String get adminSaveSettings => 'Einstellungen speichern';

  @override
  String get adminSearchUsersHint => 'Benutzer suchen...';

  @override
  String get adminSendInvitationTitle => 'Einladung senden';

  @override
  String get adminSendTest => 'Test senden';

  @override
  String adminSessionsHeader(int count) {
    return 'SITZUNGEN ($count)';
  }

  @override
  String get adminSettingsLoadFailed =>
      'Einstellungen konnten nicht geladen werden';

  @override
  String get adminSettingsSaved => 'Einstellungen gespeichert';

  @override
  String get adminSharingHeader => 'TEILEN';

  @override
  String get adminSharingSubtitle =>
      'Wenn deaktiviert, verschwindet die Aktion „Teilen“ überall und die Freigabe-Endpunkte antworten nicht mehr. Bestehende Freigaben bleiben erhalten.';

  @override
  String get adminSharingToggle => 'Teilen zwischen Konten';

  @override
  String get adminStatusExpired => 'Abgelaufen';

  @override
  String get adminStatusPending => 'Ausstehend';

  @override
  String get adminStatusRedeemed => 'Eingelöst';

  @override
  String adminStorageHeader(String size, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien',
      one: '1 Datei',
    );
    return 'SPEICHER ($size · $_temp0)';
  }

  @override
  String get adminTabInvitations => 'Einladungen';

  @override
  String get adminTabSettings => 'Einstellungen';

  @override
  String get adminTabUsers => 'Benutzer';

  @override
  String get adminTestEmailSubtitle =>
      'Test-E-Mail senden, um SMTP zu überprüfen';

  @override
  String get adminTestEmailTitle => 'E-Mail-Konfiguration testen';

  @override
  String get adminTwoFactorLabel => 'Zwei-Faktor-Authentifizierung';

  @override
  String get adminUnlimited => 'Unbegrenzt';

  @override
  String get adminUserDeleted => 'Benutzer gelöscht';

  @override
  String get adminUserInfoHeader => 'BENUTZERINFO';

  @override
  String get adminUserUpdated => 'Benutzer aktualisiert';

  @override
  String get authAddAnotherAccount => 'Weiteres Konto hinzufügen';

  @override
  String get authAddNewServer => 'NEUEN SERVER HINZUFÜGEN';

  @override
  String get authAddServer => 'Server hinzufügen';

  @override
  String get authBiometricFailed => 'Biometrische Entsperrung fehlgeschlagen';

  @override
  String get authBiometricFailedUsePin =>
      'Biometrische Entsperrung fehlgeschlagen – verwenden Sie Ihre PIN';

  @override
  String get authBiometricLockedOut =>
      'Zu viele Versuche – versuchen Sie es in 30 s erneut oder verwenden Sie Ihre PIN';

  @override
  String get authBiometricNotConfigured =>
      'Biometrie ist in dieser Version nicht konfiguriert – verwenden Sie Ihre PIN';

  @override
  String get authBiometricNotEnrolled =>
      'Auf diesem Gerät ist keine Biometrie eingerichtet – verwenden Sie Ihre PIN';

  @override
  String get authBiometricPermanentlyLockedOut =>
      'Biometrie gesperrt – entsperren Sie Ihr Gerät und versuchen Sie es erneut';

  @override
  String get authBiometricPinNotFound => 'Biometrische PIN nicht gefunden';

  @override
  String get authCheckEmailBody =>
      'Ihr Konto wurde erstellt. Verifizieren Sie Ihre E-Mail-Adresse und melden Sie sich dann an, um die Verschlüsselung zu entsperren.';

  @override
  String get authCheckEmailTitle => 'Prüfen Sie Ihre E-Mails';

  @override
  String get authConfirmPasswordLabel => 'Passwort bestätigen';

  @override
  String get authConfirmPinLabel => 'PIN bestätigen';

  @override
  String get authConnectToServer => 'Mit einem Server verbinden';

  @override
  String authConnectionFailed(String error) {
    return 'Verbindung fehlgeschlagen: $error';
  }

  @override
  String get authCreateAccount => 'Konto erstellen';

  @override
  String get authCreateAnAccount => 'Konto erstellen';

  @override
  String get authCreatePasscode => 'PIN erstellen';

  @override
  String authDeleteServerConfirm(String name) {
    return '„$name“ und alle zugehörigen Konten entfernen?';
  }

  @override
  String get authDeleteServerTitle => 'Server löschen';

  @override
  String get authEmailLabel => 'E-Mail';

  @override
  String get authEmailPasswordRequired =>
      'E-Mail-Adresse und Passwort sind erforderlich';

  @override
  String get authEnterPasscode => 'PIN eingeben';

  @override
  String get authEnterPinPrompt => 'Bitte geben Sie Ihre PIN ein';

  @override
  String get authEnterTfaCode => 'Bitte geben Sie Ihren 2FA-Code ein';

  @override
  String get authExistingAccounts => 'VORHANDENE KONTEN';

  @override
  String get authForget => 'Verwerfen';

  @override
  String authForgetAccountConfirm(String email) {
    return 'Dies entfernt das Konto „$email“ von diesem Gerät. Alle Offline-Dateien dieses Kontos werden gelöscht. Sie können sich später erneut anmelden.';
  }

  @override
  String get authForgetAccountTitle => 'Konto verwerfen';

  @override
  String get authForgetThisAccount => 'Dieses Konto verwerfen';

  @override
  String get authGetMyRecoveryKey => 'Wiederherstellungsschlüssel anzeigen';

  @override
  String get authInvalidCredentials =>
      'Ungültige E-Mail-Adresse oder ungültiges Passwort';

  @override
  String get authKeyLoginIntro =>
      'Fügen Sie den Wiederherstellungsschlüssel ein, den Sie bei der Kontoeinrichtung gespeichert haben. Er verlässt dieses Gerät nie – er wird nur verwendet, um eine Anmelde-Challenge zu signieren.';

  @override
  String get authKeyLoginInvalidKey =>
      'Dies ist kein gültiger privater Schlüssel';

  @override
  String get authKeyLoginNoAccount =>
      'Der Server hat den Schlüssel akzeptiert, aber kein Konto zurückgegeben';

  @override
  String get authKeyLoginNoIdentityKey =>
      'Dieser Wiederherstellungsschlüssel enthält keinen verwendbaren Identitätsschlüssel';

  @override
  String get authKeyLoginSelfCheckFailed =>
      'Dieser Wiederherstellungsschlüssel hat seinen Selbsttest nicht bestanden';

  @override
  String get authKeyLoginSessionFailed =>
      'Angemeldet, aber die Sitzung konnte nicht aufgebaut werden';

  @override
  String get authKeyLoginTitle => 'Mit Schlüssel anmelden';

  @override
  String get authKeyLoginUnrecognizedKey =>
      'Der Server hat diesen Schlüssel nicht erkannt';

  @override
  String authLastUsed(String time) {
    return 'Zuletzt verwendet $time';
  }

  @override
  String get authLater => 'Später';

  @override
  String get authLearnMore => 'Mehr erfahren';

  @override
  String get authLogIn => 'Anmelden';

  @override
  String get authLogInWithKey => 'Mit Schlüssel anmelden';

  @override
  String get authLogInWithPassword => 'Mit E-Mail und Passwort anmelden';

  @override
  String get authManageAccounts => 'Konten verwalten';

  @override
  String get authMigrationNoticeBody =>
      'Ihre Dateien sind jetzt mit verbesserter Verschlüsselung geschützt, und Ihre Anmeldung erfolgt, ohne dass Ihr Passwort dieses Gerät verlässt.\n\nDa dabei neue Schlüssel für Ihr Konto erzeugt wurden, speichern Sie bitte eine neue Kopie Ihres Wiederherstellungsschlüssels – er ist der einzige Weg zurück in Ihr Konto, falls Sie Ihr Passwort vergessen. Sie finden ihn jederzeit unter Konto → Wiederherstellungsschlüssel.';

  @override
  String get authMigrationNoticeTitle =>
      'Die Sicherheit Ihres Kontos wurde verbessert';

  @override
  String get authNeedServerBody =>
      'Hosten Sie kostenlos selbst oder holen Sie sich eine verwaltete Instanz.';

  @override
  String get authNeedServerTitle => 'Sie brauchen einen Server?';

  @override
  String get authNeverUsed => 'Nie verwendet';

  @override
  String get authNoAccountFound => 'Kein Konto gefunden';

  @override
  String get authNoActiveAccountOrKey =>
      'Kein aktives Konto oder privater Schlüssel verfügbar';

  @override
  String get authNoServerSelected => 'Kein Server ausgewählt';

  @override
  String get authPasswordLabel => 'Passwort';

  @override
  String get authPasswordsDoNotMatch => 'Passwörter stimmen nicht überein';

  @override
  String get authPasteRecoveryKeyFirst =>
      'Fügen Sie zuerst Ihren Wiederherstellungsschlüssel ein';

  @override
  String get authPinLabel => 'PIN';

  @override
  String get authPinPlaceholder => 'Mindestens 4 Zeichen';

  @override
  String authPinSetupFailed(String error) {
    return 'PIN-Einrichtung fehlgeschlagen: $error';
  }

  @override
  String get authPinTooShort => 'Die PIN muss mindestens 4 Zeichen lang sein';

  @override
  String get authPinsDoNotMatch => 'PINs stimmen nicht überein';

  @override
  String get authRecoveryKeyEmpty => 'Wiederherstellungsschlüssel ist leer';

  @override
  String get authRecoveryKeyLabel => 'Wiederherstellungsschlüssel';

  @override
  String get authRecoveryKeyMissingKeys =>
      'Dem Wiederherstellungsschlüssel fehlt der Identitäts- oder Wrapping-Schlüssel';

  @override
  String get authRecoveryKeyUnrecognized =>
      'Das sieht nicht wie ein Hoodik-Wiederherstellungsschlüssel aus';

  @override
  String authRegistrationFailed(String error) {
    return 'Registrierung fehlgeschlagen: $error';
  }

  @override
  String get authRegistrationNotAllowed =>
      'Registrierung ist für diese E-Mail-Adresse nicht erlaubt';

  @override
  String get authSavedServers => 'GESPEICHERTE SERVER';

  @override
  String get authServerTooOldForRegister =>
      'Dieser Server ist zu alt, um über diese App ein Konto zu erstellen. Bitte aktualisieren Sie den Server oder melden Sie sich mit einem bestehenden Konto an.';

  @override
  String get authServerUrlLabel => 'Server-URL';

  @override
  String get authServerUrlRequired => 'Bitte geben Sie eine Server-URL ein';

  @override
  String get authSetPin => 'PIN festlegen';

  @override
  String get authSetupPinIntro =>
      'Legen Sie eine PIN fest, um Ihr Konto beim nächsten Mal schnell zu entsperren, ohne Ihr Passwort einzugeben.';

  @override
  String get authSignIn => 'Anmelden';

  @override
  String get authSignInDifferentAccount => 'MIT EINEM ANDEREN KONTO ANMELDEN';

  @override
  String get authSignInToContinue =>
      'Bitte melden Sie sich an, um fortzufahren.';

  @override
  String get authSignInToUnlockEncryption =>
      'Bitte melden Sie sich mit Ihrem Passwort an, um die Verschlüsselung zu entsperren.';

  @override
  String get authSkip => 'Überspringen';

  @override
  String get authSwitchAccount => 'KONTO WECHSELN';

  @override
  String get authTagline => 'Ende-zu-Ende-verschlüsselter Cloud-Speicher';

  @override
  String get authTfaCodeLabel => '2FA-Code';

  @override
  String get authTfaRequired => 'Zwei-Faktor-Code ist erforderlich';

  @override
  String get authUnknownServer => 'Unbekannter Server';

  @override
  String get authUnlock => 'Entsperren';

  @override
  String get authUnlockHoodik => 'Hoodik entsperren';

  @override
  String get authValidationError =>
      'Validierungsfehler – prüfen Sie Ihre Eingaben';

  @override
  String get authWrongPin => 'Falsche PIN';

  @override
  String get authWrongPinOrAuthFailed =>
      'Falsche PIN oder Authentifizierung fehlgeschlagen';

  @override
  String get authWrongPinOrVerifyFailed =>
      'Falsche PIN oder Verifizierung fehlgeschlagen';

  @override
  String get commonAdd => 'Hinzufügen';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonClose => 'Schließen';

  @override
  String get commonConfirm => 'Bestätigen';

  @override
  String get commonCopy => 'Kopieren';

  @override
  String get commonCreate => 'Erstellen';

  @override
  String get commonDelete => 'Löschen';

  @override
  String get commonDone => 'Fertig';

  @override
  String get commonDownload => 'Herunterladen';

  @override
  String get commonEdit => 'Bearbeiten';

  @override
  String get commonLoading => 'Wird geladen...';

  @override
  String get commonMove => 'Verschieben';

  @override
  String get commonNever => 'Nie';

  @override
  String get commonNo => 'Nein';

  @override
  String get commonOk => 'OK';

  @override
  String get commonOpen => 'Öffnen';

  @override
  String get commonRemove => 'Entfernen';

  @override
  String get commonRename => 'Umbenennen';

  @override
  String get commonRetry => 'Erneut versuchen';

  @override
  String get commonSave => 'Speichern';

  @override
  String get commonSend => 'Senden';

  @override
  String get commonShare => 'Teilen';

  @override
  String get commonUnknown => 'Unbekannt';

  @override
  String get commonUpload => 'Hochladen';

  @override
  String get commonYes => 'Ja';

  @override
  String get errorNoConnection =>
      'Keine Verbindung. Prüfen Sie Ihr Netzwerk und versuchen Sie es erneut.';

  @override
  String get errorNotAuthorized =>
      'Sie sind für diese Aktion nicht autorisiert. Melden Sie sich erneut an.';

  @override
  String errorRequestFailed(Object status) {
    return 'Anfrage fehlgeschlagen ($status).';
  }

  @override
  String get errorServerUnavailable =>
      'Der Server hat gerade Probleme. Versuchen Sie es gleich noch einmal.';

  @override
  String get filesAccountNotInitialized =>
      'Konto ist nicht vollständig initialisiert';

  @override
  String filesAvailableOffline(String name) {
    return '$name ist offline verfügbar';
  }

  @override
  String filesAvailableOfflineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien offline verfügbar',
      one: '1 Datei offline verfügbar',
    );
    return '$_temp0';
  }

  @override
  String filesAvailableOfflinePartial(int ok, int total) {
    return '$ok von $total Dateien offline verfügbar';
  }

  @override
  String filesCacheFailed(String error) {
    return 'Zwischenspeichern fehlgeschlagen: $error';
  }

  @override
  String get filesCancelled => 'Abgebrochen';

  @override
  String get filesCannotBeUndone =>
      'Dies kann nicht rückgängig gemacht werden.';

  @override
  String get filesCannotDecryptKey =>
      'Dateischlüssel kann nicht entschlüsselt werden';

  @override
  String get filesCannotDecryptSharedKey =>
      'Der geteilte Dateischlüssel kann nicht entschlüsselt werden';

  @override
  String get filesCannotReadPath => 'Dateipfad konnte nicht gelesen werden';

  @override
  String get filesChooseFolder => 'Ordner auswählen';

  @override
  String get filesChunksLabel => 'Chunks';

  @override
  String get filesCipherLabel => 'Verschlüsselungsverfahren';

  @override
  String get filesClear => 'Leeren';

  @override
  String filesConvertFailed(String error) {
    return 'Umwandlung fehlgeschlagen: $error';
  }

  @override
  String get filesConvertToNote => 'In Notiz umwandeln';

  @override
  String get filesConvertedToNote => 'In Notiz umgewandelt';

  @override
  String filesCopiedToClipboard(String label) {
    return '$label in die Zwischenablage kopiert';
  }

  @override
  String get filesCopyLink => 'Link kopieren';

  @override
  String get filesCreateFolder => 'Ordner erstellen';

  @override
  String filesCreateFolderFailed(String error) {
    return 'Ordner konnte nicht erstellt werden: $error';
  }

  @override
  String get filesCreateLink => 'Link erstellen';

  @override
  String filesCreateLinkFailed(String error) {
    return 'Link konnte nicht erstellt werden: $error';
  }

  @override
  String get filesCreatedLabel => 'Erstellt';

  @override
  String get filesDateLabel => 'Datum';

  @override
  String filesDeleteConfirmMessage(String name) {
    return '„$name“ löschen? Dies kann nicht rückgängig gemacht werden.';
  }

  @override
  String filesDeleteCountTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Elemente löschen?',
      one: '1 Element löschen?',
    );
    return '$_temp0';
  }

  @override
  String filesDeleteFailed(String error) {
    return 'Löschen fehlgeschlagen: $error';
  }

  @override
  String get filesDeleteFileTitle => 'Datei löschen?';

  @override
  String get filesDeleteFolderTitle => 'Ordner löschen?';

  @override
  String get filesDeleted => 'Gelöscht';

  @override
  String filesDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Elemente gelöscht',
      one: '1 Element gelöscht',
    );
    return '$_temp0';
  }

  @override
  String get filesDetails => 'Details';

  @override
  String get filesDiscard => 'Verwerfen';

  @override
  String get filesDownloadingForOffline =>
      'Wird für Offline-Zugriff heruntergeladen...';

  @override
  String get filesDropToUpload => 'Dateien zum Hochladen hier ablegen';

  @override
  String get filesEmptyFolder => 'Leerer Ordner';

  @override
  String get filesEmptyAction => 'Erste Datei hinzufügen';

  @override
  String get filesEmptyTitle => 'Noch keine Dateien';

  @override
  String get filesEncryptedFallback => '(verschlüsselt)';

  @override
  String filesEncryptedPlaceholder(String id) {
    return '[Verschlüsselt] $id...';
  }

  @override
  String get filesExport => 'Exportieren';

  @override
  String get filesExportBulkBody =>
      'Jede Datei wird zuerst heruntergeladen und entschlüsselt. Das kann eine Weile dauern. Danach kannst du wählen, wohin die Dateien gehen.';

  @override
  String filesExportBulkTitle(int count) {
    return '$count Dateien exportieren?';
  }

  @override
  String get filesExportedNone => 'Keine Dateien konnten exportiert werden';

  @override
  String filesExportedPartial(int success, int total) {
    return '$success von $total Dateien exportiert';
  }

  @override
  String filesBulkFoldersSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Ordner werden übersprungen.',
      one: '$count Ordner wird übersprungen.',
    );
    return '$_temp0';
  }

  @override
  String get filesBulkLargeExport =>
      'Dieser Export ist groß und kann mehrere Minuten dauern.';

  @override
  String get filesBulkLargeDownload =>
      'Dieser Download ist groß und kann mehrere Minuten dauern.';

  @override
  String filesExportFailed(String error) {
    return 'Export fehlgeschlagen: $error';
  }

  @override
  String get filesExportStarted =>
      'Export gestartet – das Teilen-Menü öffnet sich, sobald er abgeschlossen ist';

  @override
  String filesExportingTo(String path) {
    return 'Wird nach $path exportiert';
  }

  @override
  String filesFailedUploadsHeader(int count) {
    return 'Fehlgeschlagene Uploads ($count)';
  }

  @override
  String filesFailedUploadsTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fehlgeschlagene Uploads',
      one: '1 fehlgeschlagener Upload',
    );
    return '$_temp0';
  }

  @override
  String get filesFolderCreated => 'Ordner erstellt';

  @override
  String get filesFolderLabel => 'Ordner';

  @override
  String get filesFolderNameHint => 'Ordnername';

  @override
  String filesForkFailed(String error) {
    return 'Speichern in Ihren Dateien fehlgeschlagen: $error';
  }

  @override
  String get filesForkFolderUnsupported =>
      'Ordner können nicht in Ihren Dateien gespeichert werden';

  @override
  String get filesForkQuotaExceeded =>
      'Nicht genug Speicherplatz, um diese Datei in Ihren Dateien zu speichern';

  @override
  String filesForkSaved(String name) {
    return '„$name“ wurde in Ihren Dateien gespeichert';
  }

  @override
  String filesForkSaving(String name) {
    return '„$name“ wird in Ihren Dateien gespeichert…';
  }

  @override
  String get filesIdLabel => 'ID';

  @override
  String get filesLeave => 'Verlassen';

  @override
  String filesLeaveShareBody(String name) {
    return 'Sie verlieren künftig den Zugriff auf „$name“. Bereits Heruntergeladenes bleibt bei Ihnen – Ende-zu-Ende-Verschlüsselung kann nicht zurückholen, was auf Ihrem Gerät bereits entschlüsselt wurde, und der Eigentümer kann das Teilen nicht ungeschehen machen.';
  }

  @override
  String get filesLeaveShareTitle => 'Diese Freigabe verlassen?';

  @override
  String get filesLinkCopied => 'Link in die Zwischenablage kopiert';

  @override
  String get filesLinkCreatedTitle => 'Link erstellt';

  @override
  String filesLoadFailed(String error) {
    return 'Dateien konnten nicht geladen werden: $error';
  }

  @override
  String filesLoadSharedFailed(String error) {
    return 'Geteilte Elemente konnten nicht geladen werden: $error';
  }

  @override
  String get filesMakeAvailableOffline => 'Offline verfügbar machen';

  @override
  String get filesOfflineBulkBody =>
      'Verschlüsselte Kopien werden auf dieses Gerät heruntergeladen. Das kann eine Weile dauern. Dateien, die bereits offline sind, bleiben unverändert.';

  @override
  String filesOfflineBulkTitle(int count) {
    return '$count Dateien offline verfügbar machen?';
  }

  @override
  String get filesOfflineNone => 'Nichts zum Offline-Verfügbar-Machen';

  @override
  String get filesMembers => 'Mitglieder';

  @override
  String get filesMoreActions => 'Weitere Aktionen';

  @override
  String filesMoveFailed(String error) {
    return 'Verschieben fehlgeschlagen: $error';
  }

  @override
  String get filesMoveHere => 'Hierher verschieben';

  @override
  String filesMoveItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Elemente verschieben',
      one: '1 Element verschieben',
    );
    return '$_temp0';
  }

  @override
  String get filesMoveToTitle => 'Verschieben nach...';

  @override
  String get filesMyFiles => 'Meine Dateien';

  @override
  String get filesNameInvalid => 'Ungültiger Name';

  @override
  String get filesNameInvalidChars => 'Der Name darf weder / noch \\ enthalten';

  @override
  String get filesNameLabel => 'Name';

  @override
  String get filesNewNameHint => 'Neuer Name';

  @override
  String get filesNoAccessToLeave =>
      'Sie haben keinen Zugriff, den Sie verlassen könnten';

  @override
  String get filesNoSubfolders => 'Keine Unterordner';

  @override
  String get filesNotAuthenticated => 'Nicht angemeldet';

  @override
  String get filesOfflineChip => 'Offline';

  @override
  String get filesOfflineCopyRemoved => 'Offline-Kopie entfernt';

  @override
  String get filesOpsUnavailable => 'Dateioperationen nicht verfügbar';

  @override
  String get filesOpsUnavailableNoKey =>
      'Dateioperationen nicht verfügbar (kein privater Schlüssel)';

  @override
  String filesOwnedBy(String name) {
    return 'Eigentümer: $name';
  }

  @override
  String filesPinnedForOffline(String name) {
    return '$name für Offline-Zugriff gespeichert';
  }

  @override
  String get filesPreparing => 'Wird vorbereitet…';

  @override
  String get filesPreview => 'Vorschau';

  @override
  String get filesPublicKeyUnavailable =>
      'Öffentlicher Schlüssel nicht verfügbar';

  @override
  String get filesQueued => 'In Warteschlange';

  @override
  String get filesRefresh => 'Aktualisieren';

  @override
  String get filesRemoveOfflineCopy => 'Offline-Kopie entfernen';

  @override
  String filesRenameFailed(String error) {
    return 'Umbenennen fehlgeschlagen: $error';
  }

  @override
  String get filesRenamed => 'Umbenannt';

  @override
  String filesRevokeFailed(String error) {
    return 'Widerrufen fehlgeschlagen: $error';
  }

  @override
  String get filesRootFolder => 'Hauptordner';

  @override
  String get filesSaveFileDialogTitle => 'Datei speichern';

  @override
  String get filesSaveToMyDrive => 'In meinen Dateien speichern';

  @override
  String get filesSelect => 'Auswählen';

  @override
  String get filesSelectAll => 'Alle auswählen';

  @override
  String get filesSelectFilesTooltip => 'Dateien auswählen';

  @override
  String filesSelectedCount(int count) {
    return '$count ausgewählt';
  }

  @override
  String filesShareFailed(String error) {
    return 'Teilen fehlgeschlagen: $error';
  }

  @override
  String get filesSharedItemsNeedConnection =>
      'Geteilte Elemente benötigen eine Verbindung.';

  @override
  String filesSharedWith(int count) {
    return 'Mit $count geteilt';
  }

  @override
  String get filesSizeLabel => 'Größe';

  @override
  String get filesSortTooltip => 'Sortieren';

  @override
  String get filesStillUploading =>
      'Diese Datei wird noch hochgeladen – einen Moment bitte.';

  @override
  String get filesTakePhoto => 'Foto aufnehmen';

  @override
  String get filesTheseFolders => 'diese Ordner';

  @override
  String get filesTitle => 'Dateien';

  @override
  String filesTransferActive(String verb, String fileName) {
    return '$verb: $fileName';
  }

  @override
  String filesTransferActiveMore(String verb, String fileName, int count) {
    return '$verb: $fileName (+$count weitere)';
  }

  @override
  String filesTransferCancelled(String fileName) {
    return '$fileName – Abgebrochen';
  }

  @override
  String filesTransferDone(String fileName) {
    return '$fileName – Fertig';
  }

  @override
  String filesTransferDoneSize(String size) {
    return 'Fertig  $size';
  }

  @override
  String filesTransferFailed(String fileName) {
    return '$fileName – Fehlgeschlagen';
  }

  @override
  String filesTransferQueued(String fileName) {
    return '$fileName – In Warteschlange';
  }

  @override
  String filesTransfersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Übertragungen',
      one: '1 Übertragung',
    );
    return '$_temp0';
  }

  @override
  String get filesTransfersDismissTooltip =>
      'Ausblenden – Übertragungen laufen im Hintergrund weiter';

  @override
  String get filesTransfersMinimizeTooltip => 'Minimieren';

  @override
  String get filesTransfersTitle => 'Übertragungen';

  @override
  String get filesTypeLabel => 'Typ';

  @override
  String get filesUnknownError => 'Unbekannter Fehler';

  @override
  String filesUploadFailed(String error) {
    return 'Upload fehlgeschlagen: $error';
  }

  @override
  String get filesUploadFile => 'Datei hochladen';

  @override
  String get filesUploadHere => 'Hierher hochladen';

  @override
  String get filesUploadMedia => 'Medien hochladen';

  @override
  String get filesUploadTo => 'Hochladen nach…';

  @override
  String filesUploadingChunks(int stored, int total) {
    return 'Wird hochgeladen... $stored/$total Chunks';
  }

  @override
  String filesViewAsTooltip(String mode) {
    return 'Ansicht: $mode';
  }

  @override
  String get filesViewIcons => 'Symbole';

  @override
  String get filesViewList => 'Liste';

  @override
  String get filesViewTree => 'Baum';

  @override
  String get filesYourDrive => 'Ihre Dateien';

  @override
  String get languageSubtitle => 'Anzeigesprache der App';

  @override
  String get languageSystem => 'Systemstandard';

  @override
  String get languageTitle => 'Sprache';

  @override
  String get linksCopiedToClipboard => 'Link in die Zwischenablage kopiert';

  @override
  String get linksCopyTooltip => 'Link kopieren';

  @override
  String linksDeleteBody(String name) {
    return 'Dies entfernt den Freigabelink für „$name“. Die Datei selbst wird nicht gelöscht.';
  }

  @override
  String linksDeleteFailed(String error) {
    return 'Löschen fehlgeschlagen: $error';
  }

  @override
  String get linksDeleteLink => 'Link löschen';

  @override
  String get linksDeleteTitle => 'Link löschen?';

  @override
  String get linksDeleted => 'Link gelöscht';

  @override
  String linksDownloadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Downloads',
      one: '1 Download',
    );
    return '$_temp0';
  }

  @override
  String get linksEmptySubtitle =>
      'Erstellen Sie einen Link über das Kontextmenü einer Datei';

  @override
  String get linksEmptyTitle => 'Keine öffentlichen Links';

  @override
  String get linksExpired => 'Abgelaufen';

  @override
  String linksExpiresInDays(int days) {
    return 'Läuft in $days T. ab';
  }

  @override
  String linksExpiresInHours(int hours) {
    return 'Läuft in $hours Std. ab';
  }

  @override
  String get linksExpiresSoon => 'Läuft bald ab';

  @override
  String get linksExpiryRemoved =>
      'Ablaufdatum entfernt – der Link läuft nie ab';

  @override
  String get linksExpiryUpdated => 'Ablaufdatum aktualisiert';

  @override
  String get linksNotAuthenticated => 'Nicht angemeldet';

  @override
  String get linksRemoveExpiry => 'Ablaufdatum entfernen';

  @override
  String get linksSetExpiry => 'Ablaufdatum festlegen';

  @override
  String linksUpdateFailed(String error) {
    return 'Aktualisierung fehlgeschlagen: $error';
  }

  @override
  String get notesAuthorAnonymous => 'Anonym';

  @override
  String get notesAuthorYou => 'Sie';

  @override
  String get notesBlockquote => 'Zitat';

  @override
  String get notesBold => 'Fett';

  @override
  String get notesBulletList => 'Aufzählung';

  @override
  String get notesCannotDecrypt => 'Datei kann nicht entschlüsselt werden';

  @override
  String get notesCannotOpenNoKey =>
      'Öffnen nicht möglich – Entschlüsselungsschlüssel nicht verfügbar';

  @override
  String notesChunkCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Chunks',
      one: '1 Chunk',
    );
    return '$_temp0';
  }

  @override
  String get notesClearHistoryBody =>
      'Alle früheren Versionen dieser Notiz werden endgültig gelöscht. Die aktuelle Notiz bleibt erhalten.';

  @override
  String get notesClearHistoryTitle => 'Gesamten Verlauf löschen?';

  @override
  String get notesClearHistoryTooltip => 'Gesamten Verlauf löschen';

  @override
  String get notesCloseEditor => 'Editor schließen';

  @override
  String get notesCloseNote => 'Notiz schließen';

  @override
  String get notesCode => 'Codeblock';

  @override
  String get notesConflictBody =>
      'Der Server hat einen nicht abgeschlossenen Speichervorgang für diese Notiz aus einer anderen Sitzung. Beim Überschreiben wird verworfen, was diese Sitzung gerade speichern wollte.';

  @override
  String get notesConflictDiscardMine => 'Meine Änderungen verwerfen';

  @override
  String get notesConflictOverwrite =>
      'Entfernte Änderung verwerfen, meine speichern';

  @override
  String get notesConflictTitle => 'Ein anderer Speichervorgang läuft';

  @override
  String notesCreateFolderFailed(String error) {
    return 'Ordner konnte nicht erstellt werden: $error';
  }

  @override
  String notesCreateFolderIn(String folder) {
    return 'Neuen Ordner in „$folder“ erstellen';
  }

  @override
  String get notesCreateFolderInRoot => 'Neuen Ordner im Hauptordner erstellen';

  @override
  String get notesCreateHere => 'Hier erstellen';

  @override
  String notesCreateNoteFailed(String error) {
    return 'Notiz konnte nicht erstellt werden: $error';
  }

  @override
  String notesCreateNoteIn(String folder) {
    return 'Neue Notiz in „$folder“ erstellen';
  }

  @override
  String get notesCreateNoteInRoot => 'Neue Notiz im Hauptordner erstellen';

  @override
  String notesCreatedNote(String name) {
    return '„$name“ erstellt';
  }

  @override
  String get notesCreatedNoteMissingKey =>
      'Der erstellten Notiz fehlt der Verschlüsselungsschlüssel';

  @override
  String get notesDeleteAll => 'Alle löschen';

  @override
  String notesDeleteFolderBody(String name) {
    return '„$name“ und der gesamte Inhalt werden endgültig gelöscht.';
  }

  @override
  String notesDeleteFolderFailed(String error) {
    return 'Ordner konnte nicht gelöscht werden: $error';
  }

  @override
  String get notesDeleteFolderTitle => 'Ordner löschen?';

  @override
  String notesDeleteNoteBody(String name) {
    return '„$name“ wird endgültig gelöscht.';
  }

  @override
  String notesDeleteNoteFailed(String error) {
    return 'Löschen fehlgeschlagen: $error';
  }

  @override
  String get notesDeleteNoteTitle => 'Notiz löschen?';

  @override
  String get notesDeleteThisVersion => 'Diese Version löschen';

  @override
  String notesDeleteVersionFailed(String error) {
    return 'Löschen fehlgeschlagen: $error';
  }

  @override
  String notesDeleteVersionMsg(int version, String date) {
    return 'v$version vom $date wird endgültig gelöscht. Dies kann nicht rückgängig gemacht werden.';
  }

  @override
  String notesDeleteVersionTitle(int version) {
    return 'v$version löschen?';
  }

  @override
  String get notesDetails => 'Details';

  @override
  String get notesDiscard => 'Verwerfen';

  @override
  String get notesEmptyHint =>
      'Erstellen Sie eine über die +-Schaltfläche in der Seitenleiste.';

  @override
  String get notesEmptyTitle => 'Noch keine Notizen';

  @override
  String notesEncryptedFallback(String id) {
    return '[Verschlüsselt] $id…';
  }

  @override
  String get notesEncryptedName => '(verschlüsselt)';

  @override
  String get notesExport => 'Exportieren';

  @override
  String notesExportFailed(String error) {
    return 'Export fehlgeschlagen: $error';
  }

  @override
  String get notesExportStarted =>
      'Export gestartet – das Teilen-Menü öffnet sich, sobald er fertig ist';

  @override
  String get notesExportToPdf => 'Als PDF exportieren';

  @override
  String notesExportingTo(String path) {
    return 'Wird nach $path exportiert';
  }

  @override
  String get notesFileNotFound => 'Datei nicht gefunden';

  @override
  String get notesFolderName => 'Ordner';

  @override
  String get notesFolderNameHint => 'Mein Ordner';

  @override
  String notesForkFailed(String error) {
    return 'Kopieren fehlgeschlagen: $error';
  }

  @override
  String notesHeading(int level) {
    return 'Überschrift $level';
  }

  @override
  String get notesHideSidebar => 'Seitenleiste ausblenden';

  @override
  String get notesHideKeyboard => 'Tastatur ausblenden';

  @override
  String get notesHistory => 'Versionsverlauf';

  @override
  String notesHistoryNamed(String name) {
    return 'Verlauf · $name';
  }

  @override
  String get notesItalic => 'Kursiv';

  @override
  String get notesKeyUnavailable =>
      'Entschlüsseln nicht möglich – Dateischlüssel oder Client nicht verfügbar';

  @override
  String get notesLoadFailed => 'Laden fehlgeschlagen';

  @override
  String notesLoadNotesFailed(String error) {
    return 'Notizen konnten nicht geladen werden: $error';
  }

  @override
  String get notesMetadataUnavailable => 'Dateimetadaten nicht verfügbar';

  @override
  String notesModified(String when) {
    return 'Geändert $when';
  }

  @override
  String get notesMore => 'Mehr';

  @override
  String get notesMoreActions => 'Weitere Aktionen';

  @override
  String notesMoveFailed(String error) {
    return 'Verschieben fehlgeschlagen: $error';
  }

  @override
  String get notesMoveHere => 'Hierher verschieben';

  @override
  String get notesMoveToTitle => 'Verschieben nach';

  @override
  String get notesMoved => 'Verschoben';

  @override
  String get notesNameRequired => 'Name ist erforderlich';

  @override
  String get notesNewFolder => 'Neuer Ordner';

  @override
  String notesNewIn(String name) {
    return 'Neue Notiz oder neuer Ordner in $name';
  }

  @override
  String get notesNewNote => 'Neue Notiz';

  @override
  String get notesNoHistory =>
      'Noch kein Verlauf. Bearbeiten Sie die Notiz, um einen aufzubauen.';

  @override
  String get notesNoServerId => 'Der Server hat keine ID zurückgegeben';

  @override
  String get notesNotAuthenticated => 'Nicht angemeldet';

  @override
  String get notesNotSignedIn => 'Nicht angemeldet';

  @override
  String get notesNoteNameHint => 'Meine Notiz';

  @override
  String get notesNumberedList => 'Nummerierte Liste';

  @override
  String notesPdfExportFailed(String error) {
    return 'PDF-Export fehlgeschlagen: $error';
  }

  @override
  String get notesPreview => 'Vorschau';

  @override
  String notesPreviewFailed(String error) {
    return 'Vorschau fehlgeschlagen: $error';
  }

  @override
  String notesPurgeFailed(String error) {
    return 'Löschen des Verlaufs fehlgeschlagen: $error';
  }

  @override
  String get notesRecentHeader => 'Neueste Notizen';

  @override
  String get notesRedo => 'Wiederholen';

  @override
  String notesRenameFailed(String error) {
    return 'Umbenennen fehlgeschlagen: $error';
  }

  @override
  String notesRenameFolderFailed(String error) {
    return 'Ordner konnte nicht umbenannt werden: $error';
  }

  @override
  String get notesRenameNote => 'Notiz umbenennen';

  @override
  String get notesResetZoom => 'Zoom zurücksetzen';

  @override
  String get notesRestore => 'Wiederherstellen';

  @override
  String get notesRestoreAsNew => 'Als neue Notiz wiederherstellen';

  @override
  String notesRestoreFailed(String error) {
    return 'Wiederherstellen fehlgeschlagen: $error';
  }

  @override
  String get notesRestoreHere => 'Direkt wiederherstellen';

  @override
  String get notesRestoreThisVersion => 'Diese Version wiederherstellen';

  @override
  String notesRestoreVersionMsg(int version, String date) {
    return 'Dies ersetzt den aktuellen Inhalt durch v$version vom $date. Ihre aktuelle Version bleibt im Verlauf, sodass Sie die Wiederherstellung später rückgängig machen können.';
  }

  @override
  String notesRestoreVersionTitle(int version) {
    return 'v$version wiederherstellen?';
  }

  @override
  String notesRestoredVersion(int version) {
    return 'v$version wiederhergestellt';
  }

  @override
  String get notesRootName => 'Hauptordner';

  @override
  String get notesSaveAndClose => 'Speichern & schließen';

  @override
  String notesSaveFailed(String error) {
    return 'Speichern fehlgeschlagen: $error';
  }

  @override
  String get notesSaveNoteDialogTitle => 'Notiz speichern';

  @override
  String get notesShowSidebar => 'Seitenleiste anzeigen';

  @override
  String get notesSidebarEmpty => 'Keine Notizen oder Ordner';

  @override
  String get notesSidebarHeader => 'Notizen';

  @override
  String get notesStillUploading =>
      'Diese Notiz wird noch hochgeladen. Falls sie hängen bleibt, löschen Sie sie im Tab „Dateien“ und erstellen Sie eine neue.';

  @override
  String get notesStrikethrough => 'Durchgestrichen';

  @override
  String get notesTable => 'Tabelle';

  @override
  String get notesTaskList => 'Checkliste';

  @override
  String get notesThisFolder => 'dieser Ordner';

  @override
  String get notesThisNote => 'diese Notiz';

  @override
  String get notesTitle => 'Notizen';

  @override
  String get notesUndo => 'Rückgängig';

  @override
  String get notesUnsavedChangesBody =>
      'Sie haben ungespeicherte Änderungen. Was möchten Sie tun?';

  @override
  String notesUnsavedChangesTitle(String name) {
    return 'Ungespeicherte Änderungen – $name';
  }

  @override
  String get notesUntitled => 'Ohne Titel';

  @override
  String get notesZoomIn => 'Vergrößern';

  @override
  String get notesZoomOut => 'Verkleinern';

  @override
  String get previewCannotDecrypt => 'Datei kann nicht entschlüsselt werden';

  @override
  String get previewDecryptAfterDownloadFailed =>
      'Entschlüsseln nach dem Download fehlgeschlagen';

  @override
  String previewDeleteFailed(String error) {
    return 'Löschen fehlgeschlagen: $error';
  }

  @override
  String previewDeleteFileBody(String name) {
    return '„$name“ löschen? Dies kann nicht rückgängig gemacht werden.';
  }

  @override
  String get previewDeleteFileTitle => 'Datei löschen?';

  @override
  String get previewDownloadFailed => 'Download fehlgeschlagen';

  @override
  String get previewExport => 'Exportieren';

  @override
  String get previewFailedToLoadImage => 'Bild konnte nicht geladen werden';

  @override
  String previewFailedToRenderPage(String error) {
    return 'Seite konnte nicht dargestellt werden: $error';
  }

  @override
  String get previewNoPreviewAvailable => 'Keine Vorschau verfügbar';

  @override
  String get previewNoPreviewableFiles => 'Keine Dateien mit Vorschau';

  @override
  String previewPageCounter(int current, int total) {
    return 'Seite $current / $total';
  }

  @override
  String get previewSaveFileTitle => 'Datei speichern';

  @override
  String previewShowingFirstMb(String size) {
    return 'Zeigt das erste 1 MB von $size';
  }

  @override
  String relativeDaysAgo(int days) {
    return 'vor $days T.';
  }

  @override
  String relativeHoursAgo(int hours) {
    return 'vor $hours Std.';
  }

  @override
  String get relativeJustNow => 'gerade eben';

  @override
  String relativeMinutesAgo(int minutes) {
    return 'vor $minutes Min.';
  }

  @override
  String get searchEmptyPrompt => 'Durchsuchen Sie Ihre Dateien';

  @override
  String searchEncryptedFileFallback(String id) {
    return '[Verschlüsselt] $id...';
  }

  @override
  String searchFailed(String error) {
    return 'Suche fehlgeschlagen: $error';
  }

  @override
  String get searchHint => 'Dateien und Notizen suchen…';

  @override
  String get searchNoResults => 'Keine Ergebnisse gefunden';

  @override
  String serviceBugReportShareText(String email) {
    return 'Bitte beschreiben Sie, was Sie getan haben, als der Fehler auftrat, einschließlich der Schritte zur Reproduktion.\n\nSenden an: $email';
  }

  @override
  String get serviceBugReportSubject => 'Hoodik-Fehlerbericht';

  @override
  String get serviceDownloadCancelled => 'Download abgebrochen';

  @override
  String get serviceDownloadFailed => 'Download fehlgeschlagen';

  @override
  String get serviceFileAlreadyExists => 'Datei existiert bereits';

  @override
  String get serviceTransferSelectionName => 'Ausgewählte Elemente';

  @override
  String get serviceUploadPartialConflict =>
      'Ein unterbrochener Upload mit diesem Namen enthält anderen Inhalt. Lösche ihn, um diese Datei hochzuladen.';

  @override
  String get serviceFileNoEncryptionKey =>
      'Datei hat keinen Verschlüsselungsschlüssel';

  @override
  String get serviceLandingBranchFiles => 'Dateien';

  @override
  String get serviceLandingBranchNotes => 'Notizen';

  @override
  String get serviceNotificationDownloadComplete => 'Download abgeschlossen';

  @override
  String get serviceNotificationReady => 'Bereit';

  @override
  String get serviceNotificationUploadComplete => 'Upload abgeschlossen';

  @override
  String get serviceOfflineManagerUnavailable =>
      'Offline-Verwaltung nicht verfügbar';

  @override
  String get serviceThemeModeDark => 'Dunkel';

  @override
  String get serviceThemeModeLight => 'Hell';

  @override
  String get serviceThemeModeSystem => 'System';

  @override
  String get serviceTransferCancelled => 'Abgebrochen';

  @override
  String get serviceTransferDecrypting => 'Wird entschlüsselt';

  @override
  String get serviceTransferDownloading => 'Wird heruntergeladen';

  @override
  String get serviceTransferEncrypting => 'Wird verschlüsselt';

  @override
  String get serviceTransferUploading => 'Wird hochgeladen';

  @override
  String get serviceUploadCancelled => 'Upload abgebrochen';

  @override
  String get serviceUploadFailed => 'Upload fehlgeschlagen';

  @override
  String get serviceUploadWorkerUnavailable =>
      'Der Upload benötigt einen aktiven Verschlüsselungs-Worker und Tar-Transport. Bitte starten Sie die App neu und versuchen Sie es erneut.';

  @override
  String get sharesAccessRevoked => 'Zugriff widerrufen';

  @override
  String sharesAccessRevokedFor(String email) {
    return 'Zugriff für $email widerrufen';
  }

  @override
  String get sharesAddFiles => 'Dateien hinzufügen';

  @override
  String get sharesAddMember => 'Mitglied hinzufügen';

  @override
  String sharesAddMemberFailed(String error) {
    return 'Mitglied konnte nicht hinzugefügt werden: $error';
  }

  @override
  String sharesAddMemberToGroup(String group) {
    return 'Mitglied zu $group hinzufügen';
  }

  @override
  String get sharesAddedByCoOwner => 'Von Miteigentümer hinzugefügt';

  @override
  String get sharesAddedByOwner => 'Vom Eigentümer hinzugefügt';

  @override
  String get sharesAddedByUnknown => 'Von unbekannt hinzugefügt';

  @override
  String get sharesAllowAddFiles => 'Darf neue Dateien hinzufügen';

  @override
  String get sharesAuditARecipient => 'ein Empfänger';

  @override
  String get sharesAuditARecipientCapital => 'Ein Empfänger';

  @override
  String get sharesAuditAccessFallback => 'Zugriff';

  @override
  String get sharesAuditBadgeMismatch => 'Abweichung';

  @override
  String get sharesAuditBadgeSystem => 'System';

  @override
  String get sharesAuditBadgeVerified => 'Verifiziert';

  @override
  String sharesAuditCoOwnerRevoked(String recipient, String file) {
    return 'Der über einen Miteigentümer gewährte Zugriff von $recipient auf $file wurde widerrufen';
  }

  @override
  String sharesAuditEdited(String sender, String file) {
    return '$sender hat die geteilte Datei $file bearbeitet';
  }

  @override
  String get sharesAuditEmpty =>
      'Noch keine Freigabe-Aktivität. Ereignisse erscheinen hier, wenn Sie eine Datei teilen, eine Rolle ändern oder Zugriff widerrufen.';

  @override
  String sharesAuditEvicted(String recipient, String file) {
    return '$recipient hat den Zugriff auf $file verloren (Kaskade)';
  }

  @override
  String sharesAuditFileIdLabel(String head) {
    return 'Datei $head…';
  }

  @override
  String sharesAuditForked(String sender, String file) {
    return '$sender hat $file in die eigenen Dateien kopiert';
  }

  @override
  String sharesAuditGrant(String sender, String file, String recipient) {
    return '$sender hat $file mit $recipient geteilt';
  }

  @override
  String sharesAuditGrantAsRole(
    String sender,
    String file,
    String recipient,
    String role,
  ) {
    return '$sender hat $file mit $recipient als $role geteilt';
  }

  @override
  String sharesAuditKeyRotation(String sender) {
    return '$sender hat die Verschlüsselungsschlüssel des Kontos rotiert';
  }

  @override
  String get sharesAuditLegendMismatch =>
      'Verifizierung fehlgeschlagen – vertrauen Sie dieser Zeile nicht';

  @override
  String get sharesAuditLegendSystem =>
      'ein vom Server zugeordnetes Kaskadenereignis, ohne Signatur';

  @override
  String get sharesAuditLegendVerified => 'Signatur und Kette sind in Ordnung';

  @override
  String get sharesAuditLinkBroken =>
      'Kettenverknüpfung zum vorherigen sichtbaren Ereignis ist unterbrochen.';

  @override
  String get sharesAuditLoadFailed =>
      'Ihre Freigabe-Aktivität konnte nicht geladen werden.';

  @override
  String get sharesAuditLoadFailedOffline =>
      'Ihre Freigabe-Aktivität konnte nicht geladen werden. Die Aktivität benötigt eine Verbindung zum Server – versuchen Sie es erneut, sobald Sie wieder online sind.';

  @override
  String sharesAuditMovedOut(String sender, String file) {
    return '$sender hat $file aus einem geteilten Ordner verschoben';
  }

  @override
  String get sharesAuditPageBoundaryNote =>
      'Ein früheres Ereignis dieser Kette befindet sich auf einer anderen Seite';

  @override
  String get sharesAuditRecipientFallback => 'Empfänger';

  @override
  String sharesAuditReshared(String sender, String file, String recipient) {
    return '$sender hat $file mit $recipient weitergeteilt';
  }

  @override
  String sharesAuditResharedAsRole(
    String sender,
    String file,
    String recipient,
    String role,
  ) {
    return '$sender hat $file mit $recipient als $role weitergeteilt';
  }

  @override
  String sharesAuditRestored(String sender, String file) {
    return '$sender hat eine frühere Version der geteilten Datei $file wiederhergestellt';
  }

  @override
  String sharesAuditRevoked(String sender, String recipient, String file) {
    return '$sender hat den Zugriff von $recipient auf $file widerrufen';
  }

  @override
  String sharesAuditRoleChanged(String sender, String recipient, String file) {
    return '$sender hat die Rolle von $recipient für $file geändert';
  }

  @override
  String sharesAuditRoleChangedFromTo(
    String sender,
    String recipient,
    String file,
    String before,
    String after,
  ) {
    return '$sender hat die Rolle von $recipient für $file von $before zu $after geändert';
  }

  @override
  String get sharesAuditSelfHashMismatch =>
      'Zeileninhalt stimmt nicht mit dem gespeicherten Hash überein.';

  @override
  String sharesAuditShowingRecent(int shown, int total) {
    return 'Die $shown neuesten von $total Ereignissen werden angezeigt.';
  }

  @override
  String get sharesAuditSignatureFailed =>
      'Signaturprüfung für dieses Ereignis fehlgeschlagen.';

  @override
  String get sharesAuditSystemSender => 'System';

  @override
  String get sharesAuditTamperedBody =>
      'Dieses Ereignis hat die Verifizierung nicht bestanden. Behandeln Sie seine Aussage mit Misstrauen und melden Sie es dem Eigentümer der Datei.';

  @override
  String sharesAuditUploaded(String sender, String file) {
    return '$sender hat in den geteilten Ordner $file hochgeladen';
  }

  @override
  String get sharesCannotAddSelfToGroup =>
      'Sie können sich nicht selbst zu einer Gruppe hinzufügen.';

  @override
  String get sharesCannotDecryptFileKey =>
      'Der Dateischlüssel kann nicht entschlüsselt werden';

  @override
  String get sharesCannotShareWithSelf =>
      'Sie können nicht mit sich selbst teilen.';

  @override
  String get sharesChangeRole => 'Rolle ändern';

  @override
  String get sharesDeleteGroup => 'Gruppe löschen';

  @override
  String sharesDeleteGroupBody(String name) {
    return '„$name“ löschen? Bereits mit diesen Personen geteilte Dateien bleiben geteilt; nur die Gruppe wird als gespeicherte Auswahl entfernt.';
  }

  @override
  String get sharesDeleteGroupTitle => 'Gruppe löschen?';

  @override
  String get sharesDestinationIsShared =>
      'Das Ziel ist selbst ein geteilter Ordner. Wählen Sie einen privaten Ordner oder Ihren Hauptordner.';

  @override
  String get sharesEmailPlaceholder => 'jemand@example.com';

  @override
  String get sharesEmailUnknownCannotChangeRole =>
      'E-Mail unbekannt – Rolle kann nicht geändert werden';

  @override
  String get sharesEnterMemberEmailFirst =>
      'Geben Sie zuerst die E-Mail-Adresse des Mitglieds ein.';

  @override
  String get sharesEnterRecipientEmailFirst =>
      'Geben Sie zuerst die E-Mail-Adresse des Empfängers ein.';

  @override
  String get sharesEveryoneCanRead =>
      'Alle aufgeführten Personen können jede Datei in diesem Ordner lesen.';

  @override
  String sharesEvictFailed(String error) {
    return 'Entfernen fehlgeschlagen: $error';
  }

  @override
  String get sharesFindUser => 'Benutzer finden';

  @override
  String get sharesGiveGroupName => 'Geben Sie der Gruppe einen Namen.';

  @override
  String sharesGroupCreateFailed(String error) {
    return 'Gruppe konnte nicht erstellt werden: $error';
  }

  @override
  String get sharesGroupDeleteFailed => 'Gruppe konnte nicht gelöscht werden.';

  @override
  String sharesGroupDeleted(String name) {
    return '„$name“ wurde gelöscht.';
  }

  @override
  String get sharesGroupLabel => 'Gruppe';

  @override
  String sharesGroupMemberKeyUnverified(String email) {
    return 'Der Schlüssel eines Gruppenmitglieds konnte nicht verifiziert werden – das Teilen wird abgelehnt. ($email)';
  }

  @override
  String get sharesGroupNameLabel => 'Gruppenname';

  @override
  String get sharesGroupNamePlaceholder => 'z. B. Marketing-Team';

  @override
  String get sharesGroupNameTaken =>
      'Eine Gruppe mit diesem Namen existiert bereits.';

  @override
  String get sharesGroupNoOneElse =>
      'In dieser Gruppe gibt es noch niemanden, mit dem geteilt werden könnte.';

  @override
  String sharesGroupReady(String name) {
    return '„$name“ ist bereit für Mitglieder.';
  }

  @override
  String sharesGroupRenameFailed(String error) {
    return 'Gruppe konnte nicht umbenannt werden: $error';
  }

  @override
  String get sharesGroupRoleCoOwnerDescription =>
      'Miteigentümer – kann zusätzlich Mitglieder verwalten und umbenennen.';

  @override
  String get sharesGroupRoleEditorDescription =>
      'Bearbeiter – kann Dateien in die Gruppe teilen.';

  @override
  String get sharesGroupRoleLabel => 'Gruppenrolle';

  @override
  String get sharesGroupRoleOwnerDescription =>
      'Eigentümer – volle Kontrolle über die Gruppe.';

  @override
  String get sharesGroupRoleReaderDescription =>
      'Leser – sieht die Gruppe, mehr nicht.';

  @override
  String get sharesGroupsExplainer =>
      'Mit Gruppen teilen Sie mit allen Gruppenmitgliedern auf einmal.';

  @override
  String get sharesGroupsLoadFailed =>
      'Ihre Gruppen konnten nicht geladen werden.';

  @override
  String get sharesInvalidEmail =>
      'Das sieht nicht wie eine E-Mail-Adresse aus.';

  @override
  String sharesItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Elemente',
      one: '1 Element',
    );
    return '$_temp0';
  }

  @override
  String get sharesKeyFingerprintMismatch =>
      'Schlüssel und Fingerabdruck dieses Kontos stimmen nicht überein. Das Teilen ist blockiert – fahren Sie nicht fort.';

  @override
  String get sharesLookupFailed =>
      'Dieser Benutzer konnte nicht gefunden werden.';

  @override
  String sharesMemberAddedToGroup(String email, String group) {
    return '$email gehört jetzt zu „$group“.';
  }

  @override
  String sharesMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Mitglieder',
      one: '1 Mitglied',
    );
    return '$_temp0';
  }

  @override
  String get sharesMemberEmailLabel => 'E-Mail-Adresse des Mitglieds';

  @override
  String sharesMemberNowRole(String email, String role) {
    return '$email ist jetzt $role.';
  }

  @override
  String get sharesMemberOfHeader => 'MITGLIED IN';

  @override
  String get sharesMemberRemoveFailed =>
      'Mitglied konnte nicht entfernt werden.';

  @override
  String get sharesMemberRemoved => 'Mitglied entfernt.';

  @override
  String get sharesMemberRoleChangeFailed =>
      'Die Rolle des Mitglieds konnte nicht geändert werden.';

  @override
  String sharesMembersCount(int count) {
    return 'Mitglieder ($count)';
  }

  @override
  String get sharesMembersLoadFailed =>
      'Mitgliederliste konnte nicht geladen werden.';

  @override
  String get sharesMembersLoadFailedOffline =>
      'Mitgliederliste konnte nicht geladen werden. Die Liste benötigt eine Verbindung zum Server – versuchen Sie es erneut, sobald Sie wieder online sind.';

  @override
  String get sharesMembersTitle => 'Mitglieder';

  @override
  String get sharesMismatchAcknowledge =>
      'Ich habe diesen neuen Fingerabdruck mit dem Empfänger über einen unabhängigen Kanal verifiziert.';

  @override
  String get sharesMoveAndShare => 'Verschieben und teilen';

  @override
  String get sharesMoveAndShareTitle => 'Ordner verschieben und teilen?';

  @override
  String get sharesMoveCheckFailed =>
      'Es konnte nicht geprüft werden, wo sich diese Elemente befinden. Prüfen Sie Ihre Verbindung und versuchen Sie es erneut.';

  @override
  String sharesMoveFailed(String error) {
    return 'Verschieben fehlgeschlagen: $error';
  }

  @override
  String sharesMoveWillMove(String folder, String destination, String items) {
    return 'Wenn Sie „$folder“ nach „$destination“ verschieben, werden der Ordner und seine $items verschoben.';
  }

  @override
  String sharesMoveWillShare(
    String folder,
    String destination,
    String items,
    String members,
  ) {
    return 'Wenn Sie „$folder“ nach „$destination“ verschieben, teilen Sie den Ordner und seine $items mit $members.';
  }

  @override
  String sharesMovedItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Elemente verschoben',
      one: '1 Element verschoben',
    );
    return '$_temp0';
  }

  @override
  String sharesNamesAndOthers(String first, String second, int count) {
    return '$first, $second und $count weitere';
  }

  @override
  String get sharesNewGroup => 'Neue Gruppe';

  @override
  String get sharesNewShareGroup => 'Neue Freigabegruppe';

  @override
  String get sharesNoAccessYet => 'Noch niemand hat Zugriff.';

  @override
  String get sharesNoLongerHaveAccess =>
      'Sie haben keinen Zugriff mehr auf diesen Ordner.';

  @override
  String get sharesNoMemberOfGroups =>
      'Noch niemand hat Sie zu einer Gruppe hinzugefügt.';

  @override
  String get sharesNoMembersYet =>
      'Noch keine Mitglieder – fügen Sie jemanden hinzu, um mit dieser Gruppe zu teilen.';

  @override
  String get sharesNoOwnedGroups =>
      'Sie haben noch keine Gruppen erstellt. Mit Gruppen teilen Sie mit mehreren Personen gleichzeitig.';

  @override
  String get sharesNoUserWithEmail =>
      'Kein Hoodik-Benutzer mit dieser E-Mail-Adresse.';

  @override
  String get sharesNotAuthenticated => 'Nicht angemeldet.';

  @override
  String get sharesNotGroupEditor =>
      'Sie sind noch kein Bearbeiter einer Gruppe. Erstellen Sie eine Gruppe oder bitten Sie deren Eigentümer, Sie zum Bearbeiter zu machen.';

  @override
  String get sharesOnlyOwnedIntoShared =>
      'Sie können nur eigene Dateien in einen geteilten Ordner verschieben.';

  @override
  String get sharesOnlyOwnerCanMoveOut =>
      'Nur der Eigentümer kann eine Datei aus einem geteilten Ordner verschieben.';

  @override
  String get sharesOnlyOwnerCanMoveThisOut =>
      'Nur der Eigentümer kann diese Datei aus dem geteilten Ordner verschieben.';

  @override
  String sharesOwnedBy(String email) {
    return 'Eigentümer: $email';
  }

  @override
  String get sharesOwnedGroupsHeader => 'EIGENE GRUPPEN';

  @override
  String get sharesOwnerCannotBeRemoved =>
      'Der Eigentümer kann nicht entfernt werden.';

  @override
  String get sharesPeopleWithAccess => 'Personen mit Zugriff';

  @override
  String get sharesPickEditorToEnable =>
      'Wählen Sie Bearbeiter oder Miteigentümer zum Aktivieren';

  @override
  String sharesPreparingAccess(int done, int total) {
    return 'Zugriff wird vorbereitet ($done / $total)';
  }

  @override
  String get sharesPreviouslyTrusted => 'Zuvor vertraut';

  @override
  String get sharesRecipientEmailLabel => 'E-Mail-Adresse des Empfängers';

  @override
  String get sharesRecipientsLoadFailed =>
      'Bestehende Empfänger konnten nicht geladen werden.';

  @override
  String get sharesRefresh => 'Aktualisieren';

  @override
  String get sharesRemoveMember => 'Mitglied entfernen';

  @override
  String sharesRemoveMemberBody(String email, String name) {
    return '$email aus „$name“ entfernen? Bereits geteilte Dateien bleiben geteilt; die Person wird nur beim nächsten Teilen an die Gruppe nicht mehr einbezogen.';
  }

  @override
  String get sharesRemoveMemberTitle => 'Mitglied entfernen?';

  @override
  String get sharesRenameGroup => 'Gruppe umbenennen';

  @override
  String sharesRenamedTo(String name) {
    return 'Umbenannt in „$name“.';
  }

  @override
  String get sharesRevoke => 'Widerrufen';

  @override
  String get sharesRevokeAccessTitle => 'Zugriff widerrufen?';

  @override
  String sharesRevokeCascadeExtra(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'werden auch $count Freigaben',
      one: 'wird auch 1 Freigabe',
    );
    return 'Dadurch $_temp0 entfernt, die diese Person unterhalb dieses Ordners vergeben hat.';
  }

  @override
  String sharesRevokeFailed(String error) {
    return 'Widerrufen fehlgeschlagen: $error';
  }

  @override
  String sharesRevokeFileBody(String email) {
    return '$email kann diese Datei nicht mehr öffnen.';
  }

  @override
  String sharesRevokeFolderBody(String name, String folder) {
    return '$name verliert den Zugriff auf $folder.';
  }

  @override
  String get sharesRoleCoOwner => 'Miteigentümer';

  @override
  String get sharesRoleCoOwnerDescription =>
      'Miteigentümer – kann ansehen, bearbeiten, weiterteilen und Kopien speichern.';

  @override
  String get sharesRoleEditor => 'Bearbeiter';

  @override
  String get sharesRoleEditorDescription =>
      'Bearbeiter – kann ansehen und bearbeiten. Kein Weiterteilen.';

  @override
  String get sharesRoleLabel => 'Rolle';

  @override
  String get sharesRoleOwner => 'Eigentümer';

  @override
  String get sharesRoleReader => 'Leser';

  @override
  String get sharesRoleReaderDescription => 'Leser – kann nur ansehen.';

  @override
  String get sharesServerReturnedNow => 'Server hat „jetzt“ zurückgegeben';

  @override
  String get sharesSetGroupRole => 'Gruppenrolle festlegen';

  @override
  String sharesShareFailed(String error) {
    return 'Teilen fehlgeschlagen: $error';
  }

  @override
  String get sharesShareFileTitle => 'Datei teilen';

  @override
  String get sharesShareFromShareMenu =>
      'Teilen Sie eine Datei über ihr Teilen-Menü in diese Gruppe.';

  @override
  String get sharesShareToGroup => 'In Gruppe teilen';

  @override
  String sharesShareToGroupFailed(String error) {
    return 'Teilen in die Gruppe fehlgeschlagen: $error';
  }

  @override
  String get sharesShareWithGroup => 'Mit einer Gruppe teilen';

  @override
  String sharesSharedWith(String email) {
    return 'Mit $email geteilt';
  }

  @override
  String get sharesSharedWithGroup => 'Mit der Gruppe geteilt.';

  @override
  String get sharesSharedWithMe => 'Mit mir geteilt';

  @override
  String get sharesSharingDisabled =>
      'Das Teilen ist auf diesem Server deaktiviert.';

  @override
  String sharesSubtreeTooLargeMove(int cap) {
    return 'Dieser Ordner enthält mehr als $cap Dateien. Verschieben Sie stattdessen einen Unterordner.';
  }

  @override
  String sharesSubtreeTooLargeShare(int cap) {
    return 'Dieser Ordner enthält mehr als $cap Dateien. Teilen Sie stattdessen einen Unterordner.';
  }

  @override
  String get sharesTabActivity => 'Aktivität';

  @override
  String get sharesTabGroups => 'Gruppen';

  @override
  String get sharesTabPublicLinks => 'Öffentliche Links';

  @override
  String get sharesTooManyLookups =>
      'Zu viele Abfragen – versuchen Sie es gleich erneut.';

  @override
  String get sharesTrustFirstSight =>
      'Sie teilen zum ersten Mal mit diesem Konto. Vergleichen Sie den Fingerabdruck über einen unabhängigen Kanal, wenn Sie sichergehen wollen – wir warnen deutlich, falls er sich jemals ändert.';

  @override
  String get sharesTrustMismatchBody =>
      'Der Fingerabdruck des Empfängerschlüssels hat sich geändert, seit Sie ihm zuletzt vertraut haben. So sieht eine legitime Schlüsselerneuerung aus – und genau so sieht auch ein Schlüsselaustausch-Angriff aus. Der Server kann die beiden Fälle nicht unterscheiden; nur Sie können das, durch Verifizierung über einen unabhängigen Kanal.';

  @override
  String get sharesTrustVerified =>
      'Verifiziert – dieser Fingerabdruck stimmt mit dem überein, dem Sie zuvor vertraut haben.';

  @override
  String sharesTwoNames(String first, String second) {
    return '$first und $second';
  }

  @override
  String get tabAccount => 'Konto';

  @override
  String get tabFiles => 'Dateien';

  @override
  String get tabNotes => 'Notizen';

  @override
  String get tabSearch => 'Suche';

  @override
  String get tabShare => 'Teilen';

  @override
  String get widgetDismiss => 'Ausblenden';

  @override
  String widgetOutdatedServer(String version, String latest) {
    return 'Ihr Hoodik-Server ist auf Version $version. Aktualisieren Sie auf v$latest, um die neuesten Funktionen und Fehlerbehebungen zu erhalten.';
  }

  @override
  String widgetOutdatedServerNoLatest(String version) {
    return 'Ihr Hoodik-Server ist auf Version $version. Aktualisieren Sie auf die neueste Version, um neue Funktionen und Fehlerbehebungen zu erhalten.';
  }

  @override
  String get widgetServerVersionUnknown => 'älter als v1.16.0';

  @override
  String get widgetUpdate => 'Aktualisieren';

  @override
  String widgetUpdateAvailable(String version) {
    return 'Eine neue Version von Hoodik (v$version) ist verfügbar.';
  }

  @override
  String get widgetUpdateDownloaded =>
      'Eine neue Version von Hoodik wurde heruntergeladen.';

  @override
  String get widgetUpdateRestart => 'Neu starten';

  @override
  String get searchRequiresUpdate =>
      'Die Suche benötigt ein App-Update. Deine Dateien sind sicher — aktualisiere Hoodik, um sie wieder zu durchsuchen.';

  @override
  String get searchViewFolder => 'Ordner anzeigen';

  @override
  String get reindexTitle => 'Verbesserung des Suchindex';

  @override
  String get reindexExplanation =>
      'Wir haben das Hashing deiner Dateinamen und Notizen für die Suche verstärkt, sodass es deutlich schwerer zu knacken ist. Deine Dateien müssen auf diesem Gerät neu indexiert werden, um das neue Format zu nutzen. Notizen werden dabei heruntergeladen und entschlüsselt, deshalb kann das einen Moment dauern. Noch nicht verarbeitete Dateien erscheinen nicht in der Suche.';

  @override
  String reindexProgress(int done, int total) {
    return '$done von $total Dateien';
  }

  @override
  String reindexFailed(int count) {
    return '$count Dateien konnten nicht neu indexiert werden und werden beim nächsten Mal erneut versucht.';
  }

  @override
  String get reindexBackground => 'Im Hintergrund fortsetzen';

  @override
  String get reindexCancel => 'Abbrechen';

  @override
  String get serverTooOldForSearch =>
      'Dieser Server ist zu alt für die Suche. Bitte den Betreiber, Hoodik auf 2.5.0 oder neuer zu aktualisieren.';

  @override
  String get appBelowMinimumVersion =>
      'Dieser Server benötigt eine neuere Version der App. Aktualisiere Hoodik, um sie weiter zu nutzen.';

  @override
  String get appBelowRecommendedVersion =>
      'Für diesen Server ist eine neuere Version der App verfügbar.';

  @override
  String get serverBelowMinimumTitle => 'Dieser Server ist zu alt';

  @override
  String serverBelowMinimumBody(String required, String reported) {
    return 'Für die sichere Nutzung dieser App wird Hoodik $required oder neuer benötigt. Dieser Server meldet $reported. Aktualisiere den Server und versuche es erneut.';
  }

  @override
  String get serverVersionUnknown =>
      'eine Version, die zu alt ist, um sich zu melden';

  @override
  String get serverBelowRecommendedVersion =>
      'Dieser Server ist älter als die Version, für die diese App gebaut wurde. Bis zur Aktualisierung können Funktionen fehlen.';
}
