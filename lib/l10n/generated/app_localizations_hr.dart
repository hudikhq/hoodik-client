// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Croatian (`hr`).
class AppLocalizationsHr extends AppLocalizations {
  AppLocalizationsHr([String locale = 'hr']) : super(locale);

  @override
  String get accountActiveTransfers => 'Aktivni transferi u tijeku';

  @override
  String get accountAdminHeader => 'ADMINISTRACIJA';

  @override
  String get accountAdminPanel => 'Admin panel';

  @override
  String get accountAdminPanelSubtitle => 'Korisnici, pozivnice i postavke';

  @override
  String get accountAiAccessMacosOnly =>
      'AI pristup putem MCP-a dostupan je u macOS verziji Hoodika.';

  @override
  String get accountAiAccessSubtitle => 'MCP server za AI agente';

  @override
  String get accountAiAccessTitle => 'AI pristup';

  @override
  String get accountAllAccountsHeader => 'SVI RAČUNI';

  @override
  String get accountAppearance => 'Izgled';

  @override
  String get accountAppearanceSubtitle => 'Svijetlo, tamno ili prema sustavu';

  @override
  String get accountAuditAllStatuses => 'Svi statusi';

  @override
  String get accountAuditAllTools => 'Svi alati';

  @override
  String get accountAuditClearConfirmBody =>
      'Ovo trajno uklanja sve zabilježene pozive alata. Tvoje datoteke ostaju netaknute.';

  @override
  String get accountAuditClearConfirmTitle => 'Očistiti audit log?';

  @override
  String get accountAuditClearLog => 'Očisti log';

  @override
  String get accountAuditCleared => 'Audit log je očišćen';

  @override
  String get accountAuditDuration => 'Trajanje';

  @override
  String get accountAuditEmptyBody =>
      'Svaki AI poziv alata bilježi se ovdje. Uključi AI pristup i poveži agenta da vidiš aktivnost.';

  @override
  String get accountAuditEmptyTitle => 'Još nema audit zapisa';

  @override
  String get accountAuditError => 'Greška';

  @override
  String get accountAuditFilterByStatus => 'Filtriraj po statusu';

  @override
  String get accountAuditFilterByTool => 'Filtriraj po alatu';

  @override
  String accountAuditLoadFailed(String error) {
    return 'Učitavanje nije uspjelo: $error';
  }

  @override
  String get accountAuditLogTitle => 'Audit log';

  @override
  String accountAuditMilliseconds(int ms) {
    return '$ms ms';
  }

  @override
  String get accountAuditNoParams => '(bez parametara)';

  @override
  String get accountAuditParamsHash => 'Hash parametara';

  @override
  String get accountAuditSession => 'Sesija';

  @override
  String get accountAuditStatus => 'Status';

  @override
  String get accountAuditStatusDenied => 'Odbijeno';

  @override
  String get accountAuditStatusOk => 'Ok';

  @override
  String get accountAuditTimestamp => 'Vremenska oznaka';

  @override
  String get accountClear => 'Očisti';

  @override
  String get accountDefaultLanding => 'Zadani početni ekran';

  @override
  String get accountDefaultLandingSubtitle =>
      'Kartica koja se prikazuje pri otvaranju aplikacije';

  @override
  String get accountDiagnosticsExportLogs => 'Izvezi logove';

  @override
  String get accountDiagnosticsLogsInfo =>
      'Logovi mogu sadržavati nazive datoteka i URL-ove servera da prepoznaš na što se koja linija odnosi. Nikada ne sadrže sadržaj datoteka, lozinke ni enkripcijske ključeve. Vidjet ćeš svaku liniju i prije slanja možeš ukloniti što god želiš.';

  @override
  String get accountDiagnosticsNoTelemetryBody =>
      'Hoodik ne koristi Sentry, crash reportere ni ikakvu analitiku trećih strana. Jedini podaci koji napuštaju tvoj uređaj su oni potrebni za enkriptiranu sinkronizaciju datoteka.';

  @override
  String get accountDiagnosticsNoTracking => 'Ne pratimo ništa o tvom uređaju.';

  @override
  String get accountDiagnosticsStep1 => 'Potpuno zatvori Hoodik.';

  @override
  String get accountDiagnosticsStep2 => 'Ponovno ga otvori.';

  @override
  String get accountDiagnosticsStep3 => 'Pokušaj reproducirati bug.';

  @override
  String get accountDiagnosticsStep4 =>
      'Vrati se ovdje i dodirni Izvezi logove ispod.';

  @override
  String get accountDiagnosticsSubtitle =>
      'Pošalji prijavu buga – bez telemetrije';

  @override
  String get accountDiagnosticsTellUsBody =>
      'To znači da kada nešto pukne, ne znamo za to dok nam ne javiš. Evo najkorisnijeg načina da to učiniš:';

  @override
  String get accountDiagnosticsTitle => 'Privatnost i dijagnostika';

  @override
  String get accountDisable => 'Isključi';

  @override
  String get accountEnable => 'Uključi';

  @override
  String get accountEnabled => 'Uključeno';

  @override
  String get accountEnterPinBody =>
      'Unesi svoj PIN za uključivanje biometrijskog otključavanja.';

  @override
  String get accountEnterPinTitle => 'Unesi PIN';

  @override
  String get accountIncorrectPin => 'Pogrešan PIN';

  @override
  String get accountLegalHeader => 'PRAVNO';

  @override
  String get accountLogsClearAll => 'Očisti sve';

  @override
  String get accountLogsCopied => 'Logovi su kopirani u međuspremnik';

  @override
  String get accountLogsCopyToClipboard => 'Kopiraj u međuspremnik';

  @override
  String get accountLogsCurrentSession => 'Trenutna sesija';

  @override
  String get accountLogsEmptyBody =>
      'Zatvori aplikaciju, ponovno je otvori, reproduciraj bug pa se vrati i pokušaj ponovno.';

  @override
  String get accountLogsEmptyTitle => 'Nema log linija za pregled.';

  @override
  String accountLogsLineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count linija',
      few: '$count linije',
      one: '$count linija',
    );
    return '$_temp0';
  }

  @override
  String get accountLogsPastDays => 'Zadnja 3 dana';

  @override
  String get accountLogsReviewTitle => 'Pregled logova';

  @override
  String accountLogsSendViaEmail(String email) {
    return 'Pošalji emailom ($email)';
  }

  @override
  String get accountLogsShareFailed =>
      'Dijeljenje nije uspjelo – pokušaj Kopiraj u međuspremnik';

  @override
  String get accountManageAccounts => 'Upravljanje računima';

  @override
  String get accountManageAccountsSubtitle => 'Dodaj ili promijeni račun';

  @override
  String get accountMcpActivityHeader => 'AKTIVNOST';

  @override
  String get accountMcpAllowReadOnlyOff =>
      'Sav pristup agenata pauziran dok je aplikacija zaključana PIN-om';

  @override
  String get accountMcpAllowReadOnlyOn =>
      'Agenti mogu listati i pretraživati datoteke dok je aplikacija zaključana PIN-om';

  @override
  String get accountMcpAllowReadOnlyTitle =>
      'Dopusti pristup samo za čitanje dok je zaključano';

  @override
  String get accountMcpBearerToken => 'Bearer token';

  @override
  String get accountMcpBurstCapacity => 'Burst kapacitet';

  @override
  String get accountMcpClearAuditLog => 'Očisti audit log';

  @override
  String get accountMcpClearAuditLogSubtitle =>
      'Uklanja sve zabilježene pozive alata';

  @override
  String get accountMcpConfigCopied =>
      'Konfiguracija je kopirana u međuspremnik';

  @override
  String get accountMcpConfigFootnote =>
      'Kopiraj ovaj JSON u svoju Claude Desktop ili Claude Code MCP server konfiguraciju.';

  @override
  String get accountMcpConfigurationHeader => 'KONFIGURACIJA';

  @override
  String get accountMcpConnectClientSubtitle =>
      'Vođeno postavljanje za Claude Desktop, Cursor i druge';

  @override
  String get accountMcpConnectClientTitle => 'Poveži AI klijenta';

  @override
  String get accountMcpConnectionHeader => 'VEZA';

  @override
  String get accountMcpCopyConfig => 'Kopiraj konfiguraciju';

  @override
  String get accountMcpDisabled => 'Isključeno';

  @override
  String get accountMcpEnable => 'Uključi AI pristup';

  @override
  String get accountMcpEnableFootnote =>
      'Kada je uključeno, AI agenti poput Claude Desktopa i Claude Codea mogu pristupiti tvojim enkriptiranim datotekama putem lokalnog endpointa.';

  @override
  String get accountMcpEndpoint => 'Endpoint';

  @override
  String accountMcpLastAgentCall(String time) {
    return 'Zadnji poziv agenta $time';
  }

  @override
  String get accountMcpLockedFootnote =>
      'Dok je aplikacija zaključana PIN-om, za dekriptiranje sadržaja datoteka moraš otključati. Pristup samo za čitanje izlaže samo enkriptirane metapodatke koje server ionako zna.';

  @override
  String get accountMcpNoAgentActivity => 'Još nema aktivnosti agenata';

  @override
  String get accountMcpNotRunning => 'Nije pokrenut';

  @override
  String get accountMcpOffSubtitle =>
      'Uključi AI pristup za pokretanje lokalnog MCP servera.';

  @override
  String accountMcpPausedSubtitle(int port) {
    return 'Port $port rezerviran • ponovno pokreni za nastavak';
  }

  @override
  String accountMcpPerSecondOption(int value) {
    return '$value / s';
  }

  @override
  String get accountMcpPort => 'Port';

  @override
  String get accountMcpPortRange => 'Port mora biti između 1024 i 65535';

  @override
  String accountMcpPortUpdated(int port) {
    return 'Port je promijenjen na $port';
  }

  @override
  String get accountMcpQuickActionsHeader => 'BRZE RADNJE';

  @override
  String get accountMcpRateLimitFootnote =>
      'Token bucket ograničava svaku AI sesiju. Burst kapacitet je broj uzastopnih zahtjeva dopuštenih prije nego što se bucket počne puniti podešenom brzinom.';

  @override
  String get accountMcpRateLimitHeader => 'RATE LIMIT';

  @override
  String get accountMcpRegenerate => 'Regeneriraj';

  @override
  String get accountMcpRequestsPerSecond => 'Zahtjeva po sekundi';

  @override
  String accountMcpRetentionDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dana',
      few: '$count dana',
      one: '$count dan',
    );
    return '$_temp0';
  }

  @override
  String get accountMcpRetentionForever => 'Zauvijek';

  @override
  String get accountMcpRetentionHeader => 'ČUVANJE AUDIT ZAPISA';

  @override
  String get accountMcpRetentionOneYear => '1 godina';

  @override
  String get accountMcpRetentionTitle => 'Čuvaj zapise';

  @override
  String get accountMcpRotateToken => 'Rotiraj bearer token';

  @override
  String get accountMcpRotateTokenSubtitle =>
      'Poništava sve konfigurirane AI klijente';

  @override
  String accountMcpRunningOnPort(int port) {
    return 'Pokrenut na portu $port';
  }

  @override
  String get accountMcpSecurityHeader => 'SIGURNOST';

  @override
  String get accountMcpServerHeader => 'MCP SERVER';

  @override
  String get accountMcpStarting => 'Pokretanje...';

  @override
  String get accountMcpStatusOff => 'Isključen';

  @override
  String get accountMcpStatusPaused => 'Pauziran';

  @override
  String get accountMcpStatusRunning => 'Pokrenut';

  @override
  String get accountMcpStopServer => 'Zaustavi server';

  @override
  String get accountMcpStopServerSubtitle => 'Zatvara lokalni MCP port';

  @override
  String get accountMcpTokenCopied => 'Token je kopiran u međuspremnik';

  @override
  String get accountMcpTokenRegenerated => 'Token je regeneriran';

  @override
  String get accountMcpToolsNoParams => 'Nema parametara';

  @override
  String get accountMcpToolsRawSchema => 'Sirova shema';

  @override
  String get accountMcpToolsRequired => 'obavezno';

  @override
  String get accountMcpToolsSubtitle => 'Što povezani agenti mogu pozvati';

  @override
  String get accountMcpToolsTitle => 'Alati agenta';

  @override
  String get accountMcpUnavailable =>
      'MCP server nije dostupan. Prijavi se na macOS-u za nastavak.';

  @override
  String get accountMcpViewAuditLog => 'Pogledaj audit log';

  @override
  String get accountMcpViewAuditLogSubtitle => 'Pregledaj svaki AI poziv alata';

  @override
  String get accountMcpWizardMacosOnly =>
      'Čarobnjak za povezivanje dostupan je u macOS verziji Hoodika.';

  @override
  String get accountNotConfigured => 'Nije konfigurirano';

  @override
  String get accountNotSignedIn => 'Nisi prijavljen';

  @override
  String accountOfflineCacheStats(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count datoteka',
      few: '$count datoteke',
      one: '$count datoteka',
    );
    return '$_temp0 · $size';
  }

  @override
  String get accountOfflineCacheTitle => 'Offline cache';

  @override
  String accountOfflineCacheOfLimit(String used, String limit) {
    return '$used od $limit';
  }

  @override
  String accountOfflineCacheUnlimited(String used) {
    return '$used · Neograničeno';
  }

  @override
  String get accountCacheLimitTitle => 'Ograničenje predmemorije';

  @override
  String get accountCacheLimit2Gb => '2 GB';

  @override
  String get accountCacheLimit8Gb => '8 GB';

  @override
  String get accountCacheLimit32Gb => '32 GB';

  @override
  String get accountCacheLimitUnlimited => 'Neograničeno';

  @override
  String get accountOfflineClearBody =>
      'Ovo će ukloniti sve offline kopije tvojih datoteka s ovog uređaja. Tvoje datoteke na serveru ostaju netaknute.';

  @override
  String get accountOfflineClearTitle => 'Očisti offline cache';

  @override
  String get accountOfflineCleared => 'Offline cache je očišćen';

  @override
  String get accountOfflineNoFiles => 'Nema keširanih datoteka';

  @override
  String get accountOpenSourceLicenses => 'Licence otvorenog koda';

  @override
  String get accountPasscodeLock => 'Zaključavanje PIN-om';

  @override
  String get accountPinLabel => 'PIN';

  @override
  String get accountPrivacyPolicy => 'Pravila privatnosti';

  @override
  String get accountRecoveryHide => 'Sakrij';

  @override
  String get accountRecoveryKeyBody =>
      'Ovo je vjerodajnica kojom vraćaš pristup računu ako ikada zaboraviš lozinku. Čuvaj kopiju na sigurnom i privatnom mjestu; svatko tko je ima može se prijaviti kao ti. Za korištenje odaberi \"Prijava ključem\" na ekranu za prijavu.';

  @override
  String get accountRecoveryKeyCopied => 'Ključ za oporavak je kopiran';

  @override
  String get accountRecoveryKeyLocked =>
      'Tvoji ključevi trenutno nisu otključani. Prijavi se lozinkom da izvezeš svoj ključ za oporavak.';

  @override
  String get accountRecoveryKeySubtitle =>
      'Napravi sigurnosnu kopiju svog ključa za prijavu';

  @override
  String get accountRecoveryKeyTitle => 'Ključ za oporavak';

  @override
  String get accountRecoveryReveal => 'Prikaži';

  @override
  String get accountRemovePasscodeBody =>
      'Ovo će ukloniti zaključani ekran s PIN-om. Sljedeći put ćeš se morati prijaviti lozinkom.';

  @override
  String get accountRemovePasscodeTitle => 'Ukloni PIN';

  @override
  String get accountSetUp => 'Postavi';

  @override
  String get accountSetUpPinFirst => 'Prvo postavi PIN';

  @override
  String get accountSettingsHeader => 'POSTAVKE';

  @override
  String get accountSharingDisabledMsg =>
      'Više nećeš primati emailove o dijeljenju.';

  @override
  String get accountSharingEmailToggle =>
      'Pošalji mi email kada netko podijeli datoteku sa mnom';

  @override
  String get accountSharingEmailsOff => 'Emailovi o dijeljenju su isključeni.';

  @override
  String get accountSharingEmailsOn => 'Primat ćeš emailove o dijeljenju.';

  @override
  String get accountSharingEnabledMsg =>
      'Primit ćeš email kada netko podijeli datoteku s tobom.';

  @override
  String get accountSharingHeader => 'DIJELJENJE';

  @override
  String get accountSharingUpdateFailed =>
      'Obavijesti o dijeljenju nije bilo moguće ažurirati.';

  @override
  String get accountSignOut => 'Odjava';

  @override
  String get accountSignOutConfirm => 'Sigurno se želiš odjaviti?';

  @override
  String accountStorageQuota(String size) {
    return 'Kvota: $size';
  }

  @override
  String get accountStorageTitle => 'Pohrana';

  @override
  String get accountStorageUnlimited => 'Neograničeno';

  @override
  String accountStorageUsed(Object used) {
    return 'Iskorišteno $used';
  }

  @override
  String accountStorageUsedOfTotal(Object used, Object total) {
    return 'Iskorišteno $used od $total';
  }

  @override
  String get accountTermsOfService => 'Uvjeti korištenja';

  @override
  String get accountTitle => 'Račun';

  @override
  String get accountWizardCallingInitialize => 'Pozivanje initialize…';

  @override
  String accountWizardCapabilitiesList(String list) {
    return 'Mogućnosti: $list';
  }

  @override
  String get accountWizardCapabilitiesNone =>
      'Mogućnosti: nijedna nije oglašena';

  @override
  String get accountWizardConnected => 'Povezano';

  @override
  String get accountWizardConnectionFailed =>
      'Povezivanje nije uspjelo. Provjeri server i token.';

  @override
  String get accountWizardCopyToClipboard => 'Kopiraj u međuspremnik';

  @override
  String get accountWizardCopyToken => 'Kopiraj token';

  @override
  String get accountWizardEnableHint => 'Uključi za vezanje lokalnog porta.';

  @override
  String get accountWizardFailed => 'Neuspjelo';

  @override
  String get accountWizardFinish => 'Završi';

  @override
  String get accountWizardHideToken => 'Sakrij token';

  @override
  String get accountWizardNext => 'Dalje';

  @override
  String get accountWizardNoToken => '(nema tokena)';

  @override
  String get accountWizardOpenFolder => 'Otvori folder s konfiguracijom';

  @override
  String accountWizardProtocol(String version) {
    return 'protokol $version';
  }

  @override
  String get accountWizardReadyBody =>
      'Pritisni \"Pokreni test\" za poziv initialize prema lokalnom serveru.';

  @override
  String get accountWizardReadyTitle => 'Spremno za test';

  @override
  String get accountWizardRegenerateConfirmBody =>
      'Ovo poništava postojeće sesije agenata. Novi token morat ćeš zalijepiti u svaki AI klijent koji si konfigurirao.';

  @override
  String get accountWizardRegenerateConfirmTitle =>
      'Regenerirati bearer token?';

  @override
  String get accountWizardRunTest => 'Pokreni test';

  @override
  String accountWizardServerName(String name) {
    return 'Server $name';
  }

  @override
  String get accountWizardShowToken => 'Prikaži token';

  @override
  String get accountWizardStep1Subtitle =>
      'Lokalni MCP server mora biti pokrenut prije nego što možemo predati vjerodajnice tvom AI klijentu.';

  @override
  String get accountWizardStep1Title => 'Korak 1 od 4: Pokreni MCP server';

  @override
  String get accountWizardStep2Subtitle =>
      'Tvoj AI klijent ovim tokenom autentificira svaki MCP poziv. Čuvaj ga kao lozinku.';

  @override
  String get accountWizardStep2Title => 'Korak 2 od 4: Pregledaj bearer token';

  @override
  String get accountWizardStep3Title =>
      'Korak 3 od 4: Kopiraj u svoj AI klijent';

  @override
  String get accountWizardStep4Subtitle =>
      'Pozvat ćemo initialize preko lokalnog MCP socketa i pokazati ti točno što će tvoj AI klijent vidjeti.';

  @override
  String get accountWizardStep4Title => 'Korak 4 od 4: Provjeri handshake';

  @override
  String get accountWizardTesting => 'Testiranje';

  @override
  String get accountWizardTryAgain => 'Pokušaj ponovno';

  @override
  String adminActionFailed(String error) {
    return 'Neuspjelo: $error';
  }

  @override
  String get adminActionsHeader => 'RADNJE';

  @override
  String get adminAdminRole => 'Admin uloga';

  @override
  String get adminAllowRegistration => 'Dopusti registraciju';

  @override
  String get adminAllowRegistrationSubtitle =>
      'Dopusti novim korisnicima registraciju bez pozivnice';

  @override
  String get adminBadgeAdmin => 'admin';

  @override
  String get adminCopied => 'Kopirano';

  @override
  String get adminDefaultQuotaGbLabel => 'Zadana kvota (GB)';

  @override
  String get adminDefaultQuotaHeader => 'ZADANA KVOTA';

  @override
  String get adminDeleteUser => 'Obriši korisnika';

  @override
  String adminDeleteUserBody(String email) {
    return 'Trajno obrisati $email i SVE njegove datoteke? Ovo se ne može poništiti.';
  }

  @override
  String get adminDeleteUserSubtitle => 'Trajno obriši korisnika i sve podatke';

  @override
  String get adminDisable => 'Isključi';

  @override
  String get adminDisableTfa => 'Isključi 2FA';

  @override
  String adminDisableTfaBody(String email) {
    return 'Ovo će ukloniti 2FA za $email. Morat će ga sam ponovno uključiti.';
  }

  @override
  String get adminDisableTfaTitle => 'Isključi dvofaktorsku autentifikaciju';

  @override
  String get adminDisabled => 'Isključeno';

  @override
  String get adminEditRoleQuotaTooltip => 'Uredi ulogu i kvotu';

  @override
  String get adminEditUserTitle => 'Uredi korisnika';

  @override
  String get adminEmailHeader => 'EMAIL';

  @override
  String get adminEmailLabel => 'Email';

  @override
  String adminEmailTestFailed(String error) {
    return 'Test emaila nije uspio: $error';
  }

  @override
  String get adminEmailVerifiedLabel => 'Email potvrđen';

  @override
  String get adminEnabled => 'Uključeno';

  @override
  String get adminEnforceEmailVerification => 'Zahtijevaj potvrdu emaila';

  @override
  String get adminEnforceEmailVerificationSubtitle =>
      'Korisnici moraju potvrditi email prije prijave';

  @override
  String get adminExpire => 'Poništi';

  @override
  String adminExpireInvitationBody(String email) {
    return 'Poništiti pozivnicu za $email? Više je neće moći iskoristiti za registraciju.';
  }

  @override
  String get adminExpireInvitationTitle => 'Poništi pozivnicu';

  @override
  String adminFileCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count datoteka',
      few: '$count datoteke',
      one: '$count datoteka',
    );
    return '$_temp0';
  }

  @override
  String adminInvitationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pozivnica',
      few: '$count pozivnice',
      one: '$count pozivnica',
    );
    return '$_temp0';
  }

  @override
  String adminInvitationSent(String email) {
    return 'Pozivnica je poslana na $email';
  }

  @override
  String get adminInvite => 'Pozovi';

  @override
  String get adminKillAll => 'Prekini sve';

  @override
  String get adminKillAllSessions => 'Prekini sve sesije';

  @override
  String adminKillAllSessionsBody(String email) {
    return 'Ovo će odjaviti $email sa svih uređaja.';
  }

  @override
  String adminLastActive(String time) {
    return 'Aktivan $time';
  }

  @override
  String get adminNoActiveSessions => 'Nema aktivnih sesija';

  @override
  String get adminNoFiles => 'Nema datoteka';

  @override
  String get adminNoFilesSubtitle =>
      'Ovaj korisnik nije uploadao nijednu datoteku';

  @override
  String get adminNoInvitations => 'Još nema pozivnica';

  @override
  String get adminNoUsersFound => 'Nema pronađenih korisnika';

  @override
  String get adminNotVerified => 'Nije potvrđen';

  @override
  String adminPaginationRange(int start, int end, int total) {
    return '$start–$end od $total';
  }

  @override
  String get adminPanelTitle => 'Admin panel';

  @override
  String get adminQuotaDefaultHint => 'Ostavi prazno za zadano';

  @override
  String get adminQuotaGbLabel => 'Kvota (GB)';

  @override
  String get adminQuotaLabel => 'Kvota';

  @override
  String get adminQuotaUnlimitedHint => 'Ostavi prazno za neograničeno';

  @override
  String get adminRegisteredLabel => 'Registriran';

  @override
  String get adminRegistrationHeader => 'REGISTRACIJA KORISNIKA';

  @override
  String get adminRoleAdmin => 'Admin';

  @override
  String get adminRoleLabel => 'Uloga';

  @override
  String get adminRoleUser => 'Korisnik';

  @override
  String get adminSaveSettings => 'Spremi postavke';

  @override
  String get adminSearchUsersHint => 'Pretraži korisnike...';

  @override
  String get adminSendInvitationTitle => 'Pošalji pozivnicu';

  @override
  String get adminSendTest => 'Pošalji test';

  @override
  String adminSessionsHeader(int count) {
    return 'SESIJE ($count)';
  }

  @override
  String get adminSettingsLoadFailed => 'Postavke nije bilo moguće učitati';

  @override
  String get adminSettingsSaved => 'Postavke su spremljene';

  @override
  String get adminSharingHeader => 'DIJELJENJE';

  @override
  String get adminSharingSubtitle =>
      'Kada je isključeno, opcija Podijeli nestaje posvuda, a endpointi za dijeljenje prestaju odgovarati. Postojeća dijeljenja ostaju sačuvana.';

  @override
  String get adminSharingToggle => 'Dijeljenje između računa';

  @override
  String get adminStatusExpired => 'Istekla';

  @override
  String get adminStatusPending => 'Na čekanju';

  @override
  String get adminStatusRedeemed => 'Iskorištena';

  @override
  String adminStorageHeader(String size, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count datoteka',
      few: '$count datoteke',
      one: '$count datoteka',
    );
    return 'POHRANA ($size · $_temp0)';
  }

  @override
  String get adminTabInvitations => 'Pozivnice';

  @override
  String get adminTabSettings => 'Postavke';

  @override
  String get adminTabUsers => 'Korisnici';

  @override
  String get adminTestEmailSubtitle =>
      'Pošalji testni email za provjeru SMTP-a';

  @override
  String get adminTestEmailTitle => 'Testiraj konfiguraciju emaila';

  @override
  String get adminTwoFactorLabel => 'Dvofaktorska autentifikacija';

  @override
  String get adminUnlimited => 'Neograničeno';

  @override
  String get adminUserDeleted => 'Korisnik je obrisan';

  @override
  String get adminUserInfoHeader => 'PODACI O KORISNIKU';

  @override
  String get adminUserUpdated => 'Korisnik je ažuriran';

  @override
  String get authAddAnotherAccount => 'Dodaj još jedan račun';

  @override
  String get authAddNewServer => 'DODAJ NOVI SERVER';

  @override
  String get authAddServer => 'Dodaj server';

  @override
  String get authBiometricFailed => 'Biometrija nije uspjela';

  @override
  String get authBiometricFailedUsePin =>
      'Biometrija nije uspjela – koristi svoj PIN';

  @override
  String get authBiometricLockedOut =>
      'Previše pokušaja – pokušaj ponovno za 30 s ili koristi svoj PIN';

  @override
  String get authBiometricNotConfigured =>
      'Biometrija nije konfigurirana za ovu verziju – koristi svoj PIN';

  @override
  String get authBiometricNotEnrolled =>
      'Na ovom uređaju nije postavljena biometrija – koristi svoj PIN';

  @override
  String get authBiometricPermanentlyLockedOut =>
      'Biometrija je zaključana – otključaj uređaj pa pokušaj ponovno';

  @override
  String get authBiometricPinNotFound => 'Biometrijski PIN nije pronađen';

  @override
  String get authCheckEmailBody =>
      'Tvoj račun je kreiran. Potvrdi email pa se prijavi da otključaš enkripciju.';

  @override
  String get authCheckEmailTitle => 'Provjeri email';

  @override
  String get authConfirmPasswordLabel => 'Potvrdi lozinku';

  @override
  String get authConfirmPinLabel => 'Potvrdi PIN';

  @override
  String get authConnectToServer => 'Poveži se sa serverom';

  @override
  String authConnectionFailed(String error) {
    return 'Povezivanje nije uspjelo: $error';
  }

  @override
  String get authCreateAccount => 'Kreiraj račun';

  @override
  String get authCreateAnAccount => 'Kreiraj račun';

  @override
  String get authCreatePasscode => 'Kreiraj PIN';

  @override
  String authDeleteServerConfirm(String name) {
    return 'Ukloniti \"$name\" i sve njegove račune?';
  }

  @override
  String get authDeleteServerTitle => 'Obriši server';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authEmailPasswordRequired => 'Email i lozinka su obavezni';

  @override
  String get authEnterPasscode => 'Unesi PIN';

  @override
  String get authEnterPinPrompt => 'Unesi svoj PIN';

  @override
  String get authEnterTfaCode => 'Unesi svoj 2FA kod';

  @override
  String get authExistingAccounts => 'POSTOJEĆI RAČUNI';

  @override
  String get authForget => 'Zaboravi';

  @override
  String authForgetAccountConfirm(String email) {
    return 'Ovo će ukloniti račun \"$email\" s ovog uređaja. Sve offline datoteke ovog računa bit će obrisane. Kasnije se možeš ponovno prijaviti.';
  }

  @override
  String get authForgetAccountTitle => 'Zaboravi račun';

  @override
  String get authForgetThisAccount => 'Zaboravi ovaj račun';

  @override
  String get authGetMyRecoveryKey => 'Prikaži moj ključ za oporavak';

  @override
  String get authInvalidCredentials => 'Neispravan email ili lozinka';

  @override
  String get authKeyLoginIntro =>
      'Zalijepi ključ za oporavak koji si spremio pri kreiranju računa. Nikada ne napušta ovaj uređaj – koristi se samo za potpisivanje izazova pri prijavi.';

  @override
  String get authKeyLoginInvalidKey => 'Ovo nije ispravan privatni ključ';

  @override
  String get authKeyLoginNoAccount =>
      'Server je prihvatio ključ, ali nije vratio račun';

  @override
  String get authKeyLoginNoIdentityKey =>
      'Ovaj ključ za oporavak ne sadrži upotrebljiv identitetski ključ';

  @override
  String get authKeyLoginSelfCheckFailed =>
      'Ovaj ključ za oporavak nije prošao samoprovjeru';

  @override
  String get authKeyLoginSessionFailed =>
      'Prijava je uspjela, ali sesiju nije bilo moguće uspostaviti';

  @override
  String get authKeyLoginTitle => 'Prijava ključem';

  @override
  String get authKeyLoginUnrecognizedKey => 'Server nije prepoznao ovaj ključ';

  @override
  String authLastUsed(String time) {
    return 'Zadnje korištenje $time';
  }

  @override
  String get authLater => 'Kasnije';

  @override
  String get authLearnMore => 'Saznaj više';

  @override
  String get authLogIn => 'Prijavi se';

  @override
  String get authLogInWithKey => 'Prijava ključem';

  @override
  String get authLogInWithPassword => 'Prijava emailom i lozinkom';

  @override
  String get authManageAccounts => 'Upravljanje računima';

  @override
  String get authMigrationNoticeBody =>
      'Tvoje datoteke sada su zaštićene nadograđenom enkripcijom, a prijavljuješ se tako da tvoja lozinka nikada ne napušta ovaj uređaj.\n\nBudući da su za tvoj račun generirani novi ključevi, spremi novu kopiju svog ključa za oporavak – to je jedini način povratka u račun ako zaboraviš lozinku. Uvijek ga možeš pronaći pod Račun → Ključ za oporavak.';

  @override
  String get authMigrationNoticeTitle => 'Sigurnost tvog računa je nadograđena';

  @override
  String get authNeedServerBody =>
      'Hostaj sam besplatno ili nabavi upravljanu instancu.';

  @override
  String get authNeedServerTitle => 'Trebaš server?';

  @override
  String get authNeverUsed => 'Nikad korišteno';

  @override
  String get authNoAccountFound => 'Račun nije pronađen';

  @override
  String get authNoActiveAccountOrKey =>
      'Nema aktivnog računa ni dostupnog privatnog ključa';

  @override
  String get authNoServerSelected => 'Nije odabran server';

  @override
  String get authPasswordLabel => 'Lozinka';

  @override
  String get authPasswordsDoNotMatch => 'Lozinke se ne podudaraju';

  @override
  String get authPasteRecoveryKeyFirst =>
      'Prvo zalijepi svoj ključ za oporavak';

  @override
  String get authPinLabel => 'PIN';

  @override
  String get authPinPlaceholder => 'Najmanje 4 znaka';

  @override
  String authPinSetupFailed(String error) {
    return 'Postavljanje PIN-a nije uspjelo: $error';
  }

  @override
  String get authPinTooShort => 'PIN mora imati najmanje 4 znaka';

  @override
  String get authPinsDoNotMatch => 'PIN-ovi se ne podudaraju';

  @override
  String get authRecoveryKeyEmpty => 'Ključ za oporavak je prazan';

  @override
  String get authRecoveryKeyLabel => 'Ključ za oporavak';

  @override
  String get authRecoveryKeyMissingKeys =>
      'Ključu za oporavak nedostaje identitetski ili wrapping ključ';

  @override
  String get authRecoveryKeyUnrecognized =>
      'Ovo ne izgleda kao Hoodik ključ za oporavak';

  @override
  String authRegistrationFailed(String error) {
    return 'Registracija nije uspjela: $error';
  }

  @override
  String get authRegistrationNotAllowed =>
      'Registracija nije dopuštena za ovaj email';

  @override
  String get authSavedServers => 'SPREMLJENI SERVERI';

  @override
  String get authServerTooOldForRegister =>
      'Ovaj server je prestar za kreiranje računa iz ove aplikacije. Ažuriraj server ili se prijavi u postojeći račun.';

  @override
  String get authServerUrlLabel => 'URL servera';

  @override
  String get authServerUrlRequired => 'Unesi URL servera';

  @override
  String get authSetPin => 'Postavi PIN';

  @override
  String get authSetupPinIntro =>
      'Postavi PIN da sljedeći put brzo otključaš račun bez unosa lozinke.';

  @override
  String get authSignIn => 'Prijavi se';

  @override
  String get authSignInDifferentAccount => 'PRIJAVA DRUGIM RAČUNOM';

  @override
  String get authSignInToContinue => 'Prijavi se za nastavak.';

  @override
  String get authSignInToUnlockEncryption =>
      'Prijavi se lozinkom da otključaš enkripciju.';

  @override
  String get authSkip => 'Preskoči';

  @override
  String get authSwitchAccount => 'PROMIJENI RAČUN';

  @override
  String get authTagline => 'End-to-end enkriptirana pohrana u oblaku';

  @override
  String get authTfaCodeLabel => '2FA kod';

  @override
  String get authTfaRequired => 'Potreban je kod dvofaktorske autentifikacije';

  @override
  String get authUnknownServer => 'Nepoznat server';

  @override
  String get authUnlock => 'Otključaj';

  @override
  String get authUnlockHoodik => 'Otključaj Hoodik';

  @override
  String get authValidationError => 'Greška validacije – provjeri unos';

  @override
  String get authWrongPin => 'Pogrešan PIN';

  @override
  String get authWrongPinOrAuthFailed =>
      'Pogrešan PIN ili autentifikacija nije uspjela';

  @override
  String get authWrongPinOrVerifyFailed =>
      'Pogrešan PIN ili provjera nije uspjela';

  @override
  String get commonAdd => 'Dodaj';

  @override
  String get commonCancel => 'Odustani';

  @override
  String get commonClose => 'Zatvori';

  @override
  String get commonConfirm => 'Potvrdi';

  @override
  String get commonCopy => 'Kopiraj';

  @override
  String get commonCreate => 'Kreiraj';

  @override
  String get commonDelete => 'Obriši';

  @override
  String get commonDone => 'Gotovo';

  @override
  String get commonDownload => 'Download';

  @override
  String get commonEdit => 'Uredi';

  @override
  String get commonLoading => 'Učitavanje...';

  @override
  String get commonMove => 'Premjesti';

  @override
  String get commonNever => 'Nikad';

  @override
  String get commonNo => 'Ne';

  @override
  String get commonOk => 'U redu';

  @override
  String get commonOpen => 'Otvori';

  @override
  String get commonRemove => 'Ukloni';

  @override
  String get commonRename => 'Preimenuj';

  @override
  String get commonRetry => 'Pokušaj ponovno';

  @override
  String get commonSave => 'Spremi';

  @override
  String get commonSend => 'Pošalji';

  @override
  String get commonShare => 'Podijeli';

  @override
  String get commonUnknown => 'Nepoznato';

  @override
  String get commonUpload => 'Upload';

  @override
  String get commonYes => 'Da';

  @override
  String get errorNoConnection =>
      'Nema veze sa serverom. Provjeri mrežu i pokušaj ponovno.';

  @override
  String get errorNotAuthorized =>
      'Nemaš ovlasti za ovu radnju. Prijavi se ponovno.';

  @override
  String errorRequestFailed(Object status) {
    return 'Zahtjev nije uspio ($status).';
  }

  @override
  String get errorServerUnavailable =>
      'Server trenutno ima poteškoća. Pokušaj ponovno za koji trenutak.';

  @override
  String get filesAccountNotInitialized => 'Račun nije potpuno inicijaliziran';

  @override
  String filesAvailableOffline(String name) {
    return '$name je dostupno offline';
  }

  @override
  String filesAvailableOfflineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count datoteka dostupno izvan mreže',
      few: '$count datoteke dostupne izvan mreže',
      one: '$count datoteka dostupna izvan mreže',
    );
    return '$_temp0';
  }

  @override
  String filesAvailableOfflinePartial(int ok, int total) {
    return '$ok od $total datoteka dostupno izvan mreže';
  }

  @override
  String filesCacheFailed(String error) {
    return 'Keširanje nije uspjelo: $error';
  }

  @override
  String get filesCancelled => 'Otkazano';

  @override
  String get filesCannotBeUndone => 'Ovo se ne može poništiti.';

  @override
  String get filesCannotDecryptKey => 'Ključ datoteke nije moguće dekriptirati';

  @override
  String get filesCannotDecryptSharedKey =>
      'Ključ dijeljene datoteke nije moguće dekriptirati';

  @override
  String get filesCannotReadPath =>
      'Putanju datoteke nije bilo moguće pročitati';

  @override
  String get filesChooseFolder => 'Odaberi folder';

  @override
  String get filesChunksLabel => 'Chunkovi';

  @override
  String get filesCipherLabel => 'Cipher';

  @override
  String get filesClear => 'Očisti';

  @override
  String filesConvertFailed(String error) {
    return 'Pretvaranje nije uspjelo: $error';
  }

  @override
  String get filesConvertToNote => 'Pretvori u bilješku';

  @override
  String get filesConvertedToNote => 'Pretvoreno u bilješku';

  @override
  String filesCopiedToClipboard(String label) {
    return '$label kopirano u međuspremnik';
  }

  @override
  String get filesCopyLink => 'Kopiraj link';

  @override
  String get filesCreateFolder => 'Kreiraj folder';

  @override
  String filesCreateFolderFailed(String error) {
    return 'Kreiranje foldera nije uspjelo: $error';
  }

  @override
  String get filesCreateLink => 'Kreiraj link';

  @override
  String filesCreateLinkFailed(String error) {
    return 'Kreiranje linka nije uspjelo: $error';
  }

  @override
  String get filesCreatedLabel => 'Kreirano';

  @override
  String get filesDateLabel => 'Datum';

  @override
  String filesDeleteConfirmMessage(String name) {
    return 'Obrisati \"$name\"? Ovo se ne može poništiti.';
  }

  @override
  String filesDeleteCountTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Obrisati $count stavki?',
      few: 'Obrisati $count stavke?',
      one: 'Obrisati $count stavku?',
    );
    return '$_temp0';
  }

  @override
  String filesDeleteFailed(String error) {
    return 'Brisanje nije uspjelo: $error';
  }

  @override
  String get filesDeleteFileTitle => 'Obrisati datoteku?';

  @override
  String get filesDeleteFolderTitle => 'Obrisati folder?';

  @override
  String get filesDeleted => 'Obrisano';

  @override
  String filesDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Obrisano $count stavki',
      few: 'Obrisane $count stavke',
      one: 'Obrisana $count stavka',
    );
    return '$_temp0';
  }

  @override
  String get filesDetails => 'Detalji';

  @override
  String get filesDiscard => 'Odbaci';

  @override
  String get filesDownloadingForOffline => 'Download za offline pristup...';

  @override
  String get filesDropToUpload => 'Ispusti datoteke za upload';

  @override
  String get filesEmptyFolder => 'Prazan folder';

  @override
  String get filesEmptyAction => 'Dodaj prvu datoteku';

  @override
  String get filesEmptyTitle => 'Još nema datoteka';

  @override
  String get filesEncryptedFallback => '(enkriptirano)';

  @override
  String filesEncryptedPlaceholder(String id) {
    return '[Enkriptirano] $id...';
  }

  @override
  String get filesExport => 'Izvezi';

  @override
  String get filesExportBulkBody =>
      'Svaka datoteka će se prvo preuzeti i dešifrirati. To može potrajati, a mjesto slanja biraš kad sve datoteke budu spremne.';

  @override
  String filesExportBulkTitle(int count) {
    return 'Izvesti $count datoteka?';
  }

  @override
  String get filesExportedNone => 'Nije uspio izvoz nijedne datoteke';

  @override
  String filesExportedPartial(int success, int total) {
    return 'Izvezeno $success od $total datoteka';
  }

  @override
  String filesBulkFoldersSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mapa bit će preskočeno.',
      few: '$count mape bit će preskočene.',
      one: '$count mapa bit će preskočena.',
    );
    return '$_temp0';
  }

  @override
  String get filesBulkLargeExport =>
      'Ovo je velik izvoz i može potrajati nekoliko minuta.';

  @override
  String get filesBulkLargeDownload =>
      'Ovo je veliko preuzimanje i može potrajati nekoliko minuta.';

  @override
  String filesExportFailed(String error) {
    return 'Izvoz nije uspio: $error';
  }

  @override
  String get filesExportStarted =>
      'Izvoz je pokrenut – dijalog za dijeljenje otvorit će se po završetku';

  @override
  String filesExportingTo(String path) {
    return 'Izvoz u $path';
  }

  @override
  String filesFailedUploadsHeader(int count) {
    return 'Neuspjeli uploadi ($count)';
  }

  @override
  String filesFailedUploadsTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count neuspjelih uploada',
      few: '$count neuspjela uploada',
      one: '$count neuspjeli upload',
    );
    return '$_temp0';
  }

  @override
  String get filesFolderCreated => 'Folder je kreiran';

  @override
  String get filesFolderLabel => 'Folder';

  @override
  String get filesFolderNameHint => 'Naziv foldera';

  @override
  String filesForkFailed(String error) {
    return 'Spremanje u tvoje datoteke nije uspjelo: $error';
  }

  @override
  String get filesForkFolderUnsupported =>
      'Foldere nije moguće spremiti u tvoje datoteke';

  @override
  String get filesForkQuotaExceeded =>
      'Nema dovoljno prostora da ovu datoteku spremiš u svoje datoteke';

  @override
  String filesForkSaved(String name) {
    return '\"$name\" je spremljeno u tvoje datoteke';
  }

  @override
  String filesForkSaving(String name) {
    return 'Spremanje \"$name\" u tvoje datoteke…';
  }

  @override
  String get filesIdLabel => 'ID';

  @override
  String get filesLeave => 'Napusti';

  @override
  String filesLeaveShareBody(String name) {
    return 'Izgubit ćeš pristup \"$name\" pri budućim čitanjima. Sve što si već preuzeo ostaje kod tebe – end-to-end enkripcija ne može povući ono što je već dekriptirano na tvom uređaju, a vlasnik to ne može poništiti.';
  }

  @override
  String get filesLeaveShareTitle => 'Napustiti ovo dijeljenje?';

  @override
  String get filesLinkCopied => 'Link je kopiran u međuspremnik';

  @override
  String get filesLinkCreatedTitle => 'Link kreiran';

  @override
  String filesLoadFailed(String error) {
    return 'Učitavanje datoteka nije uspjelo: $error';
  }

  @override
  String filesLoadSharedFailed(String error) {
    return 'Učitavanje dijeljenih stavki nije uspjelo: $error';
  }

  @override
  String get filesMakeAvailableOffline => 'Učini dostupnim offline';

  @override
  String get filesOfflineBulkBody =>
      'Šifrirane kopije preuzet će se na ovaj uređaj. To može potrajati. Datoteke koje su već izvan mreže ostaju kakve jesu.';

  @override
  String filesOfflineBulkTitle(int count) {
    return 'Učiniti $count datoteka dostupnima izvan mreže?';
  }

  @override
  String get filesOfflineNone => 'Nema ništa za učiniti dostupnim izvan mreže';

  @override
  String get filesMembers => 'Članovi';

  @override
  String get filesMoreActions => 'Više radnji';

  @override
  String filesMoveFailed(String error) {
    return 'Premještanje nije uspjelo: $error';
  }

  @override
  String get filesMoveHere => 'Premjesti ovdje';

  @override
  String filesMoveItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Premjesti $count stavki',
      few: 'Premjesti $count stavke',
      one: 'Premjesti $count stavku',
    );
    return '$_temp0';
  }

  @override
  String get filesMoveToTitle => 'Premjesti u...';

  @override
  String get filesMyFiles => 'Moje datoteke';

  @override
  String get filesNameInvalid => 'Neispravan naziv';

  @override
  String get filesNameInvalidChars => 'Naziv ne smije sadržavati / ni \\';

  @override
  String get filesNameLabel => 'Naziv';

  @override
  String get filesNewNameHint => 'Novi naziv';

  @override
  String get filesNoAccessToLeave => 'Nemaš pristup koji možeš napustiti';

  @override
  String get filesNoSubfolders => 'Nema podfoldera';

  @override
  String get filesNotAuthenticated => 'Nisi prijavljen';

  @override
  String get filesOfflineChip => 'Offline';

  @override
  String get filesOfflineCopyRemoved => 'Offline kopija je uklonjena';

  @override
  String get filesOpsUnavailable => 'Operacije s datotekama nisu dostupne';

  @override
  String get filesOpsUnavailableNoKey =>
      'Operacije s datotekama nisu dostupne (nema privatnog ključa)';

  @override
  String filesOwnedBy(String name) {
    return 'Vlasnik: $name';
  }

  @override
  String filesPinnedForOffline(String name) {
    return '$name je spremljeno za offline pristup';
  }

  @override
  String get filesPreparing => 'Priprema…';

  @override
  String get filesPreview => 'Pregled';

  @override
  String get filesPublicKeyUnavailable => 'Javni ključ nije dostupan';

  @override
  String get filesQueued => 'Na čekanju';

  @override
  String get filesRefresh => 'Osvježi';

  @override
  String get filesRemoveOfflineCopy => 'Ukloni offline kopiju';

  @override
  String filesRenameFailed(String error) {
    return 'Preimenovanje nije uspjelo: $error';
  }

  @override
  String get filesRenamed => 'Preimenovano';

  @override
  String filesRevokeFailed(String error) {
    return 'Opoziv nije uspio: $error';
  }

  @override
  String get filesRootFolder => 'Root';

  @override
  String get filesSaveFileDialogTitle => 'Spremi datoteku';

  @override
  String get filesSaveToMyDrive => 'Spremi u moje datoteke';

  @override
  String get filesSelect => 'Odaberi';

  @override
  String get filesSelectAll => 'Odaberi sve';

  @override
  String get filesSelectFilesTooltip => 'Odaberi datoteke';

  @override
  String filesSelectedCount(int count) {
    return 'Odabrano: $count';
  }

  @override
  String filesShareFailed(String error) {
    return 'Dijeljenje nije uspjelo: $error';
  }

  @override
  String get filesSharedItemsNeedConnection =>
      'Za dijeljene stavke potrebna je veza sa serverom.';

  @override
  String filesSharedWith(int count) {
    return 'Podijeljeno s $count';
  }

  @override
  String get filesSizeLabel => 'Veličina';

  @override
  String get filesSortTooltip => 'Sortiraj';

  @override
  String get filesStillUploading =>
      'Ova datoteka se još uploada – pričekaj trenutak.';

  @override
  String get filesTakePhoto => 'Snimi fotografiju';

  @override
  String get filesTheseFolders => 'ove foldere';

  @override
  String get filesTitle => 'Datoteke';

  @override
  String filesTransferActive(String verb, String fileName) {
    return '$verb $fileName';
  }

  @override
  String filesTransferActiveMore(String verb, String fileName, int count) {
    return '$verb $fileName (+ još $count)';
  }

  @override
  String filesTransferCancelled(String fileName) {
    return '$fileName – Otkazano';
  }

  @override
  String filesTransferDone(String fileName) {
    return '$fileName – Gotovo';
  }

  @override
  String filesTransferDoneSize(String size) {
    return 'Gotovo  $size';
  }

  @override
  String filesTransferFailed(String fileName) {
    return '$fileName – Neuspjelo';
  }

  @override
  String filesTransferQueued(String fileName) {
    return '$fileName – Na čekanju';
  }

  @override
  String filesTransfersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transfera',
      few: '$count transfera',
      one: '$count transfer',
    );
    return '$_temp0';
  }

  @override
  String get filesTransfersDismissTooltip =>
      'Zatvori – transferi se nastavljaju u pozadini';

  @override
  String get filesTransfersMinimizeTooltip => 'Smanji';

  @override
  String get filesTransfersTitle => 'Transferi';

  @override
  String get filesTypeLabel => 'Vrsta';

  @override
  String get filesUnknownError => 'Nepoznata greška';

  @override
  String filesUploadFailed(String error) {
    return 'Upload nije uspio: $error';
  }

  @override
  String get filesUploadFile => 'Upload datoteke';

  @override
  String get filesUploadHere => 'Upload ovdje';

  @override
  String get filesUploadMedia => 'Upload medija';

  @override
  String get filesUploadTo => 'Upload u…';

  @override
  String filesUploadingChunks(int stored, int total) {
    return 'Upload... $stored/$total chunkova';
  }

  @override
  String filesViewAsTooltip(String mode) {
    return 'Prikaz: $mode';
  }

  @override
  String get filesViewIcons => 'Ikone';

  @override
  String get filesViewList => 'Popis';

  @override
  String get filesViewTree => 'Stablo';

  @override
  String get filesYourDrive => 'tvoje datoteke';

  @override
  String get languageSubtitle => 'Jezik prikaza aplikacije';

  @override
  String get languageSystem => 'Zadano sustavom';

  @override
  String get languageTitle => 'Jezik';

  @override
  String get linksCopiedToClipboard => 'Link je kopiran u međuspremnik';

  @override
  String get linksCopyTooltip => 'Kopiraj link';

  @override
  String linksDeleteBody(String name) {
    return 'Ovo će ukloniti javni link za \"$name\". Sama datoteka neće biti obrisana.';
  }

  @override
  String linksDeleteFailed(String error) {
    return 'Brisanje nije uspjelo: $error';
  }

  @override
  String get linksDeleteLink => 'Obriši link';

  @override
  String get linksDeleteTitle => 'Obrisati link?';

  @override
  String get linksDeleted => 'Link je obrisan';

  @override
  String linksDownloadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count downloada',
      few: '$count downloada',
      one: '$count download',
    );
    return '$_temp0';
  }

  @override
  String get linksEmptySubtitle =>
      'Kreiraj link iz izbornika bilo koje datoteke';

  @override
  String get linksEmptyTitle => 'Nema javnih linkova';

  @override
  String get linksExpired => 'Istekao';

  @override
  String linksExpiresInDays(int days) {
    return 'Istječe za $days d';
  }

  @override
  String linksExpiresInHours(int hours) {
    return 'Istječe za $hours h';
  }

  @override
  String get linksExpiresSoon => 'Uskoro istječe';

  @override
  String get linksExpiryRemoved => 'Istek je uklonjen – link nikad ne istječe';

  @override
  String get linksExpiryUpdated => 'Istek je ažuriran';

  @override
  String get linksNotAuthenticated => 'Nisi prijavljen';

  @override
  String get linksRemoveExpiry => 'Ukloni istek';

  @override
  String get linksSetExpiry => 'Postavi istek';

  @override
  String linksUpdateFailed(String error) {
    return 'Ažuriranje nije uspjelo: $error';
  }

  @override
  String get notesAuthorAnonymous => 'Anonimno';

  @override
  String get notesAuthorYou => 'Ti';

  @override
  String get notesBlockquote => 'Citat';

  @override
  String get notesBold => 'Podebljano';

  @override
  String get notesBulletList => 'Nenumerirani popis';

  @override
  String get notesCannotDecrypt => 'Datoteku nije moguće dekriptirati';

  @override
  String get notesCannotOpenNoKey =>
      'Nije moguće otvoriti – ključ za dekriptiranje nije dostupan';

  @override
  String notesChunkCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chunkova',
      few: '$count chunka',
      one: '$count chunk',
    );
    return '$_temp0';
  }

  @override
  String get notesClearHistoryBody =>
      'Sve povijesne verzije ove bilješke bit će trajno obrisane. Trenutna bilješka ostaje.';

  @override
  String get notesClearHistoryTitle => 'Očistiti svu povijest?';

  @override
  String get notesClearHistoryTooltip => 'Očisti svu povijest';

  @override
  String get notesCloseEditor => 'Zatvori editor';

  @override
  String get notesCloseNote => 'Zatvori bilješku';

  @override
  String get notesCode => 'Blok koda';

  @override
  String get notesConflictBody =>
      'Server ima nedovršeno spremanje ove bilješke iz druge sesije. Prepisivanje će odbaciti ono što je ta sesija htjela spremiti.';

  @override
  String get notesConflictDiscardMine => 'Odbaci moje izmjene';

  @override
  String get notesConflictOverwrite => 'Odbaci udaljeno i spremi moje';

  @override
  String get notesConflictTitle => 'Drugo spremanje je u tijeku';

  @override
  String notesCreateFolderFailed(String error) {
    return 'Kreiranje foldera nije uspjelo: $error';
  }

  @override
  String notesCreateFolderIn(String folder) {
    return 'Kreiraj novi folder u \"$folder\"';
  }

  @override
  String get notesCreateFolderInRoot => 'Kreiraj novi folder u rootu';

  @override
  String get notesCreateHere => 'Stvori ovdje';

  @override
  String notesCreateNoteFailed(String error) {
    return 'Kreiranje bilješke nije uspjelo: $error';
  }

  @override
  String notesCreateNoteIn(String folder) {
    return 'Kreiraj novu bilješku u \"$folder\"';
  }

  @override
  String get notesCreateNoteInRoot => 'Kreiraj novu bilješku u rootu';

  @override
  String notesCreatedNote(String name) {
    return 'Kreirano \"$name\"';
  }

  @override
  String get notesCreatedNoteMissingKey =>
      'Kreiranoj bilješci nedostaje enkripcijski ključ';

  @override
  String get notesDeleteAll => 'Obriši sve';

  @override
  String notesDeleteFolderBody(String name) {
    return '\"$name\" i sve u njemu bit će trajno obrisano.';
  }

  @override
  String notesDeleteFolderFailed(String error) {
    return 'Brisanje foldera nije uspjelo: $error';
  }

  @override
  String get notesDeleteFolderTitle => 'Obrisati folder?';

  @override
  String notesDeleteNoteBody(String name) {
    return '\"$name\" bit će trajno obrisana.';
  }

  @override
  String notesDeleteNoteFailed(String error) {
    return 'Brisanje nije uspjelo: $error';
  }

  @override
  String get notesDeleteNoteTitle => 'Obrisati bilješku?';

  @override
  String get notesDeleteThisVersion => 'Obriši ovu verziju';

  @override
  String notesDeleteVersionFailed(String error) {
    return 'Brisanje nije uspjelo: $error';
  }

  @override
  String notesDeleteVersionMsg(int version, String date) {
    return 'v$version od $date bit će trajno obrisana. Ovo se ne može poništiti.';
  }

  @override
  String notesDeleteVersionTitle(int version) {
    return 'Obrisati v$version?';
  }

  @override
  String get notesDetails => 'Detalji';

  @override
  String get notesDiscard => 'Odbaci';

  @override
  String get notesEmptyHint => 'Kreiraj je gumbom + u bočnoj traci.';

  @override
  String get notesEmptyTitle => 'Još nema bilješki';

  @override
  String notesEncryptedFallback(String id) {
    return '[Enkriptirano] $id…';
  }

  @override
  String get notesEncryptedName => '(enkriptirano)';

  @override
  String get notesExport => 'Izvezi';

  @override
  String notesExportFailed(String error) {
    return 'Izvoz nije uspio: $error';
  }

  @override
  String get notesExportStarted =>
      'Izvoz je pokrenut – dijalog za dijeljenje otvorit će se kada bude spreman';

  @override
  String get notesExportToPdf => 'Izvezi PDF';

  @override
  String notesExportingTo(String path) {
    return 'Izvoz u $path';
  }

  @override
  String get notesFileNotFound => 'Datoteka nije pronađena';

  @override
  String get notesFind => 'Pronađi';

  @override
  String get notesFindClose => 'Zatvori pretragu';

  @override
  String get notesFindCaseSensitive => 'Razlikuj velika i mala slova';

  @override
  String notesFindMatches(int index, int count) {
    return '$index od $count';
  }

  @override
  String get notesFindNext => 'Sljedeće poklapanje';

  @override
  String get notesFindPrev => 'Prethodno poklapanje';

  @override
  String get notesFolderName => 'folder';

  @override
  String get notesFolderNameHint => 'Moj folder';

  @override
  String notesForkFailed(String error) {
    return 'Fork nije uspio: $error';
  }

  @override
  String notesHeading(int level) {
    return 'Naslov $level';
  }

  @override
  String get notesHideSidebar => 'Sakrij bočnu traku';

  @override
  String get notesHideKeyboard => 'Sakrij tipkovnicu';

  @override
  String get notesHistory => 'Povijest verzija';

  @override
  String notesHistoryNamed(String name) {
    return 'Povijest · $name';
  }

  @override
  String get notesItalic => 'Kurziv';

  @override
  String get notesKeyUnavailable =>
      'Dekriptiranje nije moguće – ključ datoteke ili klijent nije dostupan';

  @override
  String get notesLoadFailed => 'Učitavanje nije uspjelo';

  @override
  String notesLoadNotesFailed(String error) {
    return 'Učitavanje bilješki nije uspjelo: $error';
  }

  @override
  String get notesMetadataUnavailable => 'Metapodaci datoteke nisu dostupni';

  @override
  String notesModified(String when) {
    return 'Izmijenjeno $when';
  }

  @override
  String get notesMore => 'Više';

  @override
  String get notesMoreActions => 'Više radnji';

  @override
  String notesMoveFailed(String error) {
    return 'Premještanje nije uspjelo: $error';
  }

  @override
  String get notesMoveHere => 'Premjesti ovdje';

  @override
  String get notesMoveToTitle => 'Premjesti u';

  @override
  String get notesMoved => 'Premješteno';

  @override
  String get notesNameRequired => 'Naziv je obavezan';

  @override
  String get notesNewFolder => 'Novi folder';

  @override
  String notesNewIn(String name) {
    return 'Nova bilješka ili folder u $name';
  }

  @override
  String get notesNewNote => 'Nova bilješka';

  @override
  String get notesNoHistory =>
      'Još nema povijesti. Uredi bilješku da je počneš graditi.';

  @override
  String get notesNoServerId => 'Server nije vratio ID';

  @override
  String get notesNotAuthenticated => 'Nisi prijavljen';

  @override
  String get notesNotSignedIn => 'Nisi prijavljen';

  @override
  String get notesNoteNameHint => 'Moja bilješka';

  @override
  String get notesNumberedList => 'Numerirani popis';

  @override
  String notesPdfExportFailed(String error) {
    return 'PDF izvoz nije uspio: $error';
  }

  @override
  String get notesPreview => 'Pregled';

  @override
  String notesPreviewFailed(String error) {
    return 'Pregled nije uspio: $error';
  }

  @override
  String notesPurgeFailed(String error) {
    return 'Čišćenje nije uspjelo: $error';
  }

  @override
  String get notesRecentHeader => 'Nedavne bilješke';

  @override
  String get notesRedo => 'Ponovi';

  @override
  String notesRenameFailed(String error) {
    return 'Preimenovanje nije uspjelo: $error';
  }

  @override
  String notesRenameFolderFailed(String error) {
    return 'Preimenovanje foldera nije uspjelo: $error';
  }

  @override
  String get notesRenameNote => 'Preimenuj bilješku';

  @override
  String get notesResetZoom => 'Poništi zoom';

  @override
  String get notesRestore => 'Vrati';

  @override
  String get notesRestoreAsNew => 'Vrati kao novu bilješku';

  @override
  String notesRestoreFailed(String error) {
    return 'Vraćanje nije uspjelo: $error';
  }

  @override
  String get notesRestoreHere => 'Vrati na mjesto';

  @override
  String get notesRestoreThisVersion => 'Vrati ovu verziju';

  @override
  String notesRestoreVersionMsg(int version, String date) {
    return 'Ovo zamjenjuje trenutni sadržaj s v$version od $date. Tvoja trenutna verzija ostaje u povijesti, pa vraćanje kasnije možeš poništiti.';
  }

  @override
  String notesRestoreVersionTitle(int version) {
    return 'Vratiti v$version?';
  }

  @override
  String notesRestoredVersion(int version) {
    return 'Vraćena v$version';
  }

  @override
  String get notesRootName => 'root';

  @override
  String get notesSaveAndClose => 'Spremi i zatvori';

  @override
  String notesSaveFailed(String error) {
    return 'Spremanje nije uspjelo: $error';
  }

  @override
  String get notesSaveNoteDialogTitle => 'Spremi bilješku';

  @override
  String get notesShowSidebar => 'Prikaži bočnu traku';

  @override
  String get notesSidebarEmpty => 'Nema bilješki ni foldera';

  @override
  String get notesSidebarHeader => 'Bilješke';

  @override
  String get notesStillUploading =>
      'Ova bilješka se još uploada. Ako ostane zaglavljena, obriši je u kartici Datoteke i kreiraj novu.';

  @override
  String get notesStrikethrough => 'Precrtano';

  @override
  String get notesTable => 'Tablica';

  @override
  String get notesTaskList => 'Popis zadataka';

  @override
  String get notesThisFolder => 'ovaj folder';

  @override
  String get notesThisNote => 'ova bilješka';

  @override
  String get notesTitle => 'Bilješke';

  @override
  String get notesUndo => 'Poništi';

  @override
  String get notesUnsavedChangesBody =>
      'Imaš nespremljene izmjene. Što želiš učiniti?';

  @override
  String notesUnsavedChangesTitle(String name) {
    return 'Nespremljene izmjene – $name';
  }

  @override
  String get notesUntitled => 'Bez naziva';

  @override
  String get notesZoomIn => 'Povećaj';

  @override
  String get notesZoomOut => 'Smanji';

  @override
  String get previewCannotDecrypt => 'Datoteku nije moguće dekriptirati';

  @override
  String get previewDecryptAfterDownloadFailed =>
      'Dekriptiranje nakon downloada nije uspjelo';

  @override
  String previewDeleteFailed(String error) {
    return 'Brisanje nije uspjelo: $error';
  }

  @override
  String previewDeleteFileBody(String name) {
    return 'Obrisati \"$name\"? Ovo se ne može poništiti.';
  }

  @override
  String get previewDeleteFileTitle => 'Obrisati datoteku?';

  @override
  String get previewDownloadFailed => 'Download nije uspio';

  @override
  String get previewExport => 'Izvezi';

  @override
  String get previewFailedToLoadImage => 'Učitavanje slike nije uspjelo';

  @override
  String previewFailedToRenderPage(String error) {
    return 'Prikaz stranice nije uspio: $error';
  }

  @override
  String get previewNoPreviewAvailable => 'Pregled nije dostupan';

  @override
  String get previewNoPreviewableFiles => 'Nema datoteka za pregled';

  @override
  String previewPageCounter(int current, int total) {
    return 'Stranica $current / $total';
  }

  @override
  String get previewSaveFileTitle => 'Spremi datoteku';

  @override
  String previewShowingFirstMb(String size) {
    return 'Prikazan je prvi 1 MB od $size';
  }

  @override
  String relativeDaysAgo(int days) {
    return 'prije $days d';
  }

  @override
  String relativeHoursAgo(int hours) {
    return 'prije $hours h';
  }

  @override
  String get relativeJustNow => 'upravo sada';

  @override
  String relativeMinutesAgo(int minutes) {
    return 'prije $minutes min';
  }

  @override
  String get searchEmptyPrompt => 'Pretraži svoje datoteke';

  @override
  String searchEncryptedFileFallback(String id) {
    return '[Enkriptirano] $id...';
  }

  @override
  String searchFailed(String error) {
    return 'Pretraga nije uspjela: $error';
  }

  @override
  String get searchHint => 'Pretraži datoteke i bilješke…';

  @override
  String get searchNoResults => 'Nema rezultata';

  @override
  String serviceBugReportShareText(String email) {
    return 'Opiši što si radio kada se bug dogodio, uključujući korake za reprodukciju.\n\nPošalji na: $email';
  }

  @override
  String get serviceBugReportSubject => 'Hoodik bug report';

  @override
  String get serviceDownloadCancelled => 'Download je otkazan';

  @override
  String get serviceDownloadFailed => 'Download nije uspio';

  @override
  String get serviceFileAlreadyExists => 'Datoteka već postoji';

  @override
  String get serviceTransferSelectionName => 'Odabrane stavke';

  @override
  String get serviceUploadPartialConflict =>
      'Prekinuto prenošenje s ovim imenom sadrži drugačiji sadržaj. Obriši ga da bi prenio ovu datoteku.';

  @override
  String get serviceFileNoEncryptionKey => 'Datoteka nema enkripcijski ključ';

  @override
  String get serviceLandingBranchFiles => 'Datoteke';

  @override
  String get serviceLandingBranchNotes => 'Bilješke';

  @override
  String get serviceNotificationDownloadComplete => 'Download dovršen';

  @override
  String get serviceNotificationReady => 'Spremno';

  @override
  String get serviceNotificationUploadComplete => 'Upload dovršen';

  @override
  String get serviceOfflineManagerUnavailable =>
      'Offline upravitelj nije dostupan';

  @override
  String get serviceThemeModeDark => 'Tamno';

  @override
  String get serviceThemeModeLight => 'Svijetlo';

  @override
  String get serviceThemeModeSystem => 'Sustav';

  @override
  String get serviceTransferCancelled => 'Otkazano';

  @override
  String get serviceTransferDecrypting => 'Dekriptiranje';

  @override
  String get serviceTransferDownloading => 'Download';

  @override
  String get serviceTransferEncrypting => 'Enkriptiranje';

  @override
  String get serviceTransferUploading => 'Upload';

  @override
  String get serviceUploadCancelled => 'Upload je otkazan';

  @override
  String get serviceUploadFailed => 'Upload nije uspio';

  @override
  String get serviceUploadWorkerUnavailable =>
      'Upload zahtijeva aktivan encrypt worker i tar transport. Ponovno pokreni aplikaciju i pokušaj ponovno.';

  @override
  String get sharesAccessRevoked => 'Pristup je opozvan';

  @override
  String sharesAccessRevokedFor(String email) {
    return 'Pristup je opozvan za $email';
  }

  @override
  String get sharesAddFiles => 'Dodaj datoteke';

  @override
  String get sharesAddMember => 'Dodaj člana';

  @override
  String sharesAddMemberFailed(String error) {
    return 'Dodavanje člana nije uspjelo: $error';
  }

  @override
  String sharesAddMemberToGroup(String group) {
    return 'Dodaj člana u $group';
  }

  @override
  String get sharesAddedByCoOwner => 'Dodao suvlasnik';

  @override
  String get sharesAddedByOwner => 'Dodao vlasnik';

  @override
  String get sharesAddedByUnknown => 'Dodao nepoznat korisnik';

  @override
  String get sharesAllowAddFiles => 'Dopusti dodavanje novih datoteka';

  @override
  String get sharesAuditARecipient => 'primatelj';

  @override
  String get sharesAuditARecipientCapital => 'Primatelj';

  @override
  String get sharesAuditAccessFallback => 'pristup';

  @override
  String get sharesAuditBadgeMismatch => 'Nepodudaranje';

  @override
  String get sharesAuditBadgeSystem => 'Sustav';

  @override
  String get sharesAuditBadgeVerified => 'Provjereno';

  @override
  String sharesAuditCoOwnerRevoked(String recipient, String file) {
    return 'Pristup korisnika $recipient datoteci $file preko suvlasnika je opozvan';
  }

  @override
  String sharesAuditEdited(String sender, String file) {
    return '$sender je uredio $file u dijeljenju';
  }

  @override
  String get sharesAuditEmpty =>
      'Još nema aktivnosti dijeljenja. Događaji se pojavljuju ovdje kada podijeliš datoteku, promijeniš ulogu ili opozoveš pristup.';

  @override
  String sharesAuditEvicted(String recipient, String file) {
    return '$recipient više ne može otvoriti $file (kaskadni opoziv)';
  }

  @override
  String sharesAuditFileIdLabel(String head) {
    return 'datoteku $head…';
  }

  @override
  String sharesAuditForked(String sender, String file) {
    return '$sender je forkao $file u svoje datoteke';
  }

  @override
  String sharesAuditGrant(String sender, String file, String recipient) {
    return '$sender je podijelio $file s $recipient';
  }

  @override
  String sharesAuditGrantAsRole(
    String sender,
    String file,
    String recipient,
    String role,
  ) {
    return '$sender je podijelio $file s $recipient kao $role';
  }

  @override
  String sharesAuditKeyRotation(String sender) {
    return '$sender je rotirao enkripcijske ključeve svog računa';
  }

  @override
  String get sharesAuditLegendMismatch =>
      'nije prošao provjeru – ne vjeruj ovom retku';

  @override
  String get sharesAuditLegendSystem =>
      'kaskadni događaj pripisan serveru, bez potpisa';

  @override
  String get sharesAuditLegendVerified => 'potpis i lanac su u redu';

  @override
  String get sharesAuditLinkBroken =>
      'Veza lanca s prethodnim vidljivim događajem je prekinuta.';

  @override
  String get sharesAuditLoadFailed =>
      'Aktivnost dijeljenja nije bilo moguće učitati.';

  @override
  String get sharesAuditLoadFailedOffline =>
      'Aktivnost dijeljenja nije bilo moguće učitati. Za aktivnost je potrebna veza sa serverom – pokušaj ponovno kada budeš online.';

  @override
  String sharesAuditMovedOut(String sender, String file) {
    return '$sender je premjestio $file iz dijeljenog foldera';
  }

  @override
  String get sharesAuditPageBoundaryNote =>
      'Raniji događaj u ovom lancu nalazi se na drugoj stranici';

  @override
  String get sharesAuditRecipientFallback => 'primatelj';

  @override
  String sharesAuditReshared(String sender, String file, String recipient) {
    return '$sender je dalje podijelio $file s $recipient';
  }

  @override
  String sharesAuditResharedAsRole(
    String sender,
    String file,
    String recipient,
    String role,
  ) {
    return '$sender je dalje podijelio $file s $recipient kao $role';
  }

  @override
  String sharesAuditRestored(String sender, String file) {
    return '$sender je vratio prethodnu verziju dijeljene datoteke $file';
  }

  @override
  String sharesAuditRevoked(String sender, String recipient, String file) {
    return '$sender je opozvao pristup korisniku $recipient za $file';
  }

  @override
  String sharesAuditRoleChanged(String sender, String recipient, String file) {
    return '$sender je promijenio ulogu korisnika $recipient na $file';
  }

  @override
  String sharesAuditRoleChangedFromTo(
    String sender,
    String recipient,
    String file,
    String before,
    String after,
  ) {
    return '$sender je promijenio ulogu korisnika $recipient na $file iz $before u $after';
  }

  @override
  String get sharesAuditSelfHashMismatch =>
      'Sadržaj retka ne odgovara spremljenom hashu.';

  @override
  String sharesAuditShowingRecent(int shown, int total) {
    return 'Prikazano je $shown najnovijih od $total događaja.';
  }

  @override
  String get sharesAuditSignatureFailed =>
      'Provjera potpisa ovog događaja nije uspjela.';

  @override
  String get sharesAuditSystemSender => 'sustav';

  @override
  String get sharesAuditTamperedBody =>
      'Ovaj događaj nije prošao provjeru. Njegovu tvrdnju uzmi s rezervom i prijavi ga vlasniku datoteke.';

  @override
  String sharesAuditUploaded(String sender, String file) {
    return '$sender je uploadao u dijeljeni folder $file';
  }

  @override
  String get sharesCannotAddSelfToGroup =>
      'Ne možeš dodati samog sebe u grupu.';

  @override
  String get sharesCannotDecryptFileKey =>
      'Ključ datoteke nije moguće dekriptirati';

  @override
  String get sharesCannotShareWithSelf => 'Ne možeš dijeliti sam sa sobom.';

  @override
  String get sharesChangeRole => 'Promijeni ulogu';

  @override
  String get sharesDeleteGroup => 'Obriši grupu';

  @override
  String sharesDeleteGroupBody(String name) {
    return 'Obrisati \"$name\"? Datoteke već podijeljene s njezinim članovima ostaju podijeljene; grupa samo prestaje biti odredište za dijeljenje.';
  }

  @override
  String get sharesDeleteGroupTitle => 'Obrisati grupu?';

  @override
  String get sharesDestinationIsShared =>
      'Odredište je i samo dijeljeni folder. Odaberi privatni folder ili root svojih datoteka.';

  @override
  String get sharesEmailPlaceholder => 'netko@primjer.com';

  @override
  String get sharesEmailUnknownCannotChangeRole =>
      'Email nepoznat – ulogu nije moguće promijeniti';

  @override
  String get sharesEnterMemberEmailFirst => 'Prvo unesi email člana.';

  @override
  String get sharesEnterRecipientEmailFirst => 'Prvo unesi email primatelja.';

  @override
  String get sharesEveryoneCanRead =>
      'Svi navedeni moći će čitati svaku datoteku u ovom folderu.';

  @override
  String sharesEvictFailed(String error) {
    return 'Uklanjanje nije uspjelo: $error';
  }

  @override
  String get sharesFindUser => 'Pronađi korisnika';

  @override
  String get sharesGiveGroupName => 'Daj grupi naziv.';

  @override
  String sharesGroupCreateFailed(String error) {
    return 'Kreiranje grupe nije uspjelo: $error';
  }

  @override
  String get sharesGroupDeleteFailed => 'Grupu nije bilo moguće obrisati.';

  @override
  String sharesGroupDeleted(String name) {
    return '\"$name\" je obrisana.';
  }

  @override
  String get sharesGroupLabel => 'Grupa';

  @override
  String sharesGroupMemberKeyUnverified(String email) {
    return 'Ključ člana grupe nije bilo moguće provjeriti – dijeljenje je odbijeno. ($email)';
  }

  @override
  String get sharesGroupNameLabel => 'Naziv grupe';

  @override
  String get sharesGroupNamePlaceholder => 'npr. Marketing tim';

  @override
  String get sharesGroupNameTaken => 'Grupa s tim nazivom već postoji.';

  @override
  String get sharesGroupNoOneElse =>
      'U ovoj grupi još nema nikoga s kim bi dijelio.';

  @override
  String sharesGroupReady(String name) {
    return '\"$name\" je spremna za primanje članova.';
  }

  @override
  String sharesGroupRenameFailed(String error) {
    return 'Preimenovanje grupe nije uspjelo: $error';
  }

  @override
  String get sharesGroupRoleCoOwnerDescription =>
      'Suvlasnik – može i upravljati članovima i preimenovati grupu.';

  @override
  String get sharesGroupRoleEditorDescription =>
      'Urednik – može dijeliti datoteke u grupu.';

  @override
  String get sharesGroupRoleLabel => 'Uloga u grupi';

  @override
  String get sharesGroupRoleOwnerDescription =>
      'Vlasnik – potpuna kontrola nad grupom.';

  @override
  String get sharesGroupRoleReaderDescription =>
      'Čitatelj – vidi grupu, ništa više.';

  @override
  String get sharesGroupsExplainer =>
      'Grupe omogućuju dijeljenje sa svima u grupi odjednom.';

  @override
  String get sharesGroupsLoadFailed => 'Grupe nije bilo moguće učitati.';

  @override
  String get sharesInvalidEmail => 'To ne izgleda kao email adresa.';

  @override
  String sharesItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stavki',
      few: '$count stavke',
      one: '$count stavka',
    );
    return '$_temp0';
  }

  @override
  String get sharesKeyFingerprintMismatch =>
      'Ključ i fingerprint ovog računa se ne podudaraju. Dijeljenje je blokirano – nemoj nastaviti.';

  @override
  String get sharesLookupFailed => 'Korisnika nije bilo moguće pronaći.';

  @override
  String sharesMemberAddedToGroup(String email, String group) {
    return '$email je sada dio grupe \"$group\".';
  }

  @override
  String sharesMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count članova',
      few: '$count člana',
      one: '$count član',
    );
    return '$_temp0';
  }

  @override
  String get sharesMemberEmailLabel => 'Email člana';

  @override
  String sharesMemberNowRole(String email, String role) {
    return '$email je sada $role.';
  }

  @override
  String get sharesMemberOfHeader => 'ČLANSTVA';

  @override
  String get sharesMemberRemoveFailed => 'Člana nije bilo moguće ukloniti.';

  @override
  String get sharesMemberRemoved => 'Član je uklonjen.';

  @override
  String get sharesMemberRoleChangeFailed =>
      'Ulogu člana nije bilo moguće promijeniti.';

  @override
  String sharesMembersCount(int count) {
    return 'Članovi ($count)';
  }

  @override
  String get sharesMembersLoadFailed =>
      'Popis članova nije bilo moguće učitati.';

  @override
  String get sharesMembersLoadFailedOffline =>
      'Popis članova nije bilo moguće učitati. Za popis je potrebna veza sa serverom – pokušaj ponovno kada budeš online.';

  @override
  String get sharesMembersTitle => 'Članovi';

  @override
  String get sharesMismatchAcknowledge =>
      'Potvrdio sam ovaj novi fingerprint s primateljem drugim kanalom.';

  @override
  String get sharesMoveAndShare => 'Premjesti i podijeli';

  @override
  String get sharesMoveAndShareTitle => 'Premjestiti i podijeliti folder?';

  @override
  String get sharesMoveCheckFailed =>
      'Nije bilo moguće provjeriti gdje se ove stavke nalaze. Provjeri vezu i pokušaj ponovno.';

  @override
  String sharesMoveFailed(String error) {
    return 'Premještanje nije uspjelo: $error';
  }

  @override
  String sharesMoveWillMove(String folder, String destination, String items) {
    return 'Premjestiš li \"$folder\" u \"$destination\", premjestit će se folder i $items u njemu.';
  }

  @override
  String sharesMoveWillShare(
    String folder,
    String destination,
    String items,
    String members,
  ) {
    return 'Premjestiš li \"$folder\" u \"$destination\", folder i $items u njemu bit će podijeljeni s $members.';
  }

  @override
  String sharesMovedItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Premješteno $count stavki',
      few: 'Premještene $count stavke',
      one: 'Premještena $count stavka',
    );
    return '$_temp0';
  }

  @override
  String sharesNamesAndOthers(String first, String second, int count) {
    return '$first, $second i još $count';
  }

  @override
  String get sharesNewGroup => 'Nova grupa';

  @override
  String get sharesNewShareGroup => 'Nova grupa za dijeljenje';

  @override
  String get sharesNoAccessYet => 'Još nitko nema pristup.';

  @override
  String get sharesNoLongerHaveAccess => 'Više nemaš pristup ovom folderu.';

  @override
  String get sharesNoMemberOfGroups => 'Nitko te još nije dodao u grupu.';

  @override
  String get sharesNoMembersYet =>
      'Još nema članova – dodaj nekoga da odjednom dijeliš s cijelom grupom.';

  @override
  String get sharesNoOwnedGroups =>
      'Još nemaš nijednu grupu. Grupe omogućuju dijeljenje s više ljudi odjednom.';

  @override
  String get sharesNoUserWithEmail =>
      'Nismo pronašli Hoodik račun za taj email.';

  @override
  String get sharesNotAuthenticated => 'Nisi prijavljen.';

  @override
  String get sharesNotGroupEditor =>
      'Još nisi urednik nijedne grupe. Kreiraj grupu ili zamoli njezinog vlasnika da te postavi za urednika.';

  @override
  String get sharesOnlyOwnedIntoShared =>
      'U dijeljeni folder možeš premjestiti samo datoteke čiji si vlasnik.';

  @override
  String get sharesOnlyOwnerCanMoveOut =>
      'Samo vlasnik može premjestiti datoteku iz dijeljenog foldera.';

  @override
  String get sharesOnlyOwnerCanMoveThisOut =>
      'Samo vlasnik može premjestiti ovu datoteku iz dijeljenog foldera.';

  @override
  String sharesOwnedBy(String email) {
    return 'vlasnik: $email';
  }

  @override
  String get sharesOwnedGroupsHeader => 'MOJE GRUPE';

  @override
  String get sharesOwnerCannotBeRemoved => 'Vlasnika nije moguće ukloniti.';

  @override
  String get sharesPeopleWithAccess => 'Osobe s pristupom';

  @override
  String get sharesPickEditorToEnable =>
      'Odaberi Urednika ili Suvlasnika za uključivanje';

  @override
  String sharesPreparingAccess(int done, int total) {
    return 'Priprema pristupa ($done / $total)';
  }

  @override
  String get sharesPreviouslyTrusted => 'Prethodno potvrđen';

  @override
  String get sharesRecipientEmailLabel => 'Email primatelja';

  @override
  String get sharesRecipientsLoadFailed =>
      'Postojeće primatelje nije bilo moguće učitati.';

  @override
  String get sharesRefresh => 'Osvježi';

  @override
  String get sharesRemoveMember => 'Ukloni člana';

  @override
  String sharesRemoveMemberBody(String email, String name) {
    return 'Ukloniti $email iz \"$name\"? Datoteke koje su već podijeljene s njim ostaju podijeljene; samo neće biti uključen sljedeći put kad podijeliš u grupu.';
  }

  @override
  String get sharesRemoveMemberTitle => 'Ukloniti člana?';

  @override
  String get sharesRenameGroup => 'Preimenuj grupu';

  @override
  String sharesRenamedTo(String name) {
    return 'Novi naziv je \"$name\".';
  }

  @override
  String get sharesRevoke => 'Opozovi';

  @override
  String get sharesRevokeAccessTitle => 'Opozvati pristup?';

  @override
  String sharesRevokeCascadeExtra(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Ovo ujedno uklanja i $count dijeljenja koja je ta osoba dodijelila unutar ovog foldera.',
      few:
          'Ovo ujedno uklanja i $count dijeljenja koja je ta osoba dodijelila unutar ovog foldera.',
      one:
          'Ovo ujedno uklanja i $count dijeljenje koje je ta osoba dodijelila unutar ovog foldera.',
    );
    return '$_temp0';
  }

  @override
  String sharesRevokeFailed(String error) {
    return 'Opoziv nije uspio: $error';
  }

  @override
  String sharesRevokeFileBody(String email) {
    return '$email više neće moći otvoriti ovu datoteku.';
  }

  @override
  String sharesRevokeFolderBody(String name, String folder) {
    return '$name će izgubiti pristup folderu $folder.';
  }

  @override
  String get sharesRoleCoOwner => 'Suvlasnik';

  @override
  String get sharesRoleCoOwnerDescription =>
      'Suvlasnik – može pregledavati, uređivati, dalje dijeliti i spremati kopije.';

  @override
  String get sharesRoleEditor => 'Urednik';

  @override
  String get sharesRoleEditorDescription =>
      'Urednik – može pregledavati i uređivati. Ne može dalje dijeliti.';

  @override
  String get sharesRoleLabel => 'Uloga';

  @override
  String get sharesRoleOwner => 'Vlasnik';

  @override
  String get sharesRoleReader => 'Čitatelj';

  @override
  String get sharesRoleReaderDescription =>
      'Čitatelj – može samo pregledavati.';

  @override
  String get sharesServerReturnedNow => 'Server je vratio trenutno vrijeme';

  @override
  String get sharesSetGroupRole => 'Postavi ulogu u grupi';

  @override
  String sharesShareFailed(String error) {
    return 'Dijeljenje nije uspjelo: $error';
  }

  @override
  String get sharesShareFileTitle => 'Podijeli datoteku';

  @override
  String get sharesShareFromShareMenu =>
      'Podijeli datoteku u ovu grupu iz njezinog izbornika za dijeljenje.';

  @override
  String get sharesShareToGroup => 'Podijeli u grupu';

  @override
  String sharesShareToGroupFailed(String error) {
    return 'Dijeljenje u grupu nije uspjelo: $error';
  }

  @override
  String get sharesShareWithGroup => 'Podijeli s grupom';

  @override
  String sharesSharedWith(String email) {
    return 'Podijeljeno s $email';
  }

  @override
  String get sharesSharedWithGroup => 'Podijeljeno s grupom.';

  @override
  String get sharesSharedWithMe => 'Podijeljeno sa mnom';

  @override
  String get sharesSharingDisabled =>
      'Dijeljenje je isključeno na ovom serveru.';

  @override
  String sharesSubtreeTooLargeMove(int cap) {
    return 'Ovaj folder ima više od $cap datoteka. Premjesti radije podfolder.';
  }

  @override
  String sharesSubtreeTooLargeShare(int cap) {
    return 'Ovaj folder ima više od $cap datoteka. Podijeli radije podfolder.';
  }

  @override
  String get sharesTabActivity => 'Aktivnost';

  @override
  String get sharesTabGroups => 'Grupe';

  @override
  String get sharesTabPublicLinks => 'Javni linkovi';

  @override
  String get sharesTooManyLookups => 'Previše upita, pokušaj ponovno uskoro.';

  @override
  String get sharesTrustFirstSight =>
      'Prvi put dijeliš s ovim računom. Za potpunu sigurnost usporedi fingerprint drugim kanalom; glasno ćemo upozoriti ako se ikada promijeni.';

  @override
  String get sharesTrustMismatchBody =>
      'Fingerprint ključa ovog primatelja promijenio se otkad si ga zadnji put potvrdio. Ovako izgleda legitimna rotacija ključa – ali i točno ovako izgleda napad zamjenom ključa. Server ih ne može razlikovati; možeš samo ti, provjerom drugim kanalom.';

  @override
  String get sharesTrustVerified =>
      'Provjereno – ovaj fingerprint odgovara onome koji si ranije potvrdio.';

  @override
  String sharesTwoNames(String first, String second) {
    return '$first i $second';
  }

  @override
  String get tabAccount => 'Račun';

  @override
  String get tabFiles => 'Datoteke';

  @override
  String get tabNotes => 'Bilješke';

  @override
  String get tabSearch => 'Pretraga';

  @override
  String get tabShare => 'Dijeljenje';

  @override
  String get widgetDismiss => 'Zatvori';

  @override
  String widgetOutdatedServer(String version, String latest) {
    return 'Tvoj Hoodik server je na verziji $version. Nadogradi na v$latest za najnovije funkcionalnosti i ispravke bugova.';
  }

  @override
  String widgetOutdatedServerNoLatest(String version) {
    return 'Tvoj Hoodik server je na verziji $version. Nadogradi na najnovije izdanje za nove funkcionalnosti i ispravke bugova.';
  }

  @override
  String get widgetServerVersionUnknown => 'stariji od v1.16.0';

  @override
  String get widgetUpdate => 'Ažuriraj';

  @override
  String widgetUpdateAvailable(String version) {
    return 'Dostupna je nova verzija Hoodika (v$version).';
  }

  @override
  String get widgetUpdateDownloaded => 'Nova verzija Hoodika je preuzeta.';

  @override
  String get widgetUpdateRestart => 'Ponovno pokreni';

  @override
  String get searchRequiresUpdate =>
      'Pretraga traži ažuriranje aplikacije. Datoteke su sigurne — ažuriraj Hoodik da ih ponovno pretražuješ.';

  @override
  String get searchViewFolder => 'Prikaži folder';

  @override
  String get reindexTitle => 'Nadogradnja search indeksa';

  @override
  String get reindexExplanation =>
      'Pojačali smo hashiranje naziva datoteka i bilješki za pretragu pa ih je puno teže probiti. Datoteke treba ponovno indeksirati na ovom uređaju da koriste novi format. Bilješke se pritom preuzimaju i dekriptiraju, pa to može potrajati. Datoteke koje još nisu obrađene neće se pojaviti u pretrazi.';

  @override
  String reindexProgress(int done, int total) {
    return '$done od $total datoteka';
  }

  @override
  String reindexFailed(int count) {
    return '$count datoteka nije uspjelo ponovno indeksirati, pokušat ćemo ponovno sljedeći put.';
  }

  @override
  String get reindexBackground => 'Nastavi u pozadini';

  @override
  String get reindexCancel => 'Odustani';

  @override
  String get reindexDone => 'Gotovo';

  @override
  String get serverTooOldForSearch =>
      'Ovaj server je prestar za pretragu. Traži od administratora da ažurira Hoodik na 2.5.0 ili noviji.';

  @override
  String get appBelowMinimumVersion =>
      'Ovaj server traži noviju verziju aplikacije. Ažuriraj Hoodik da nastaviš.';

  @override
  String get appBelowRecommendedVersion =>
      'Za ovaj server dostupna je novija verzija aplikacije.';

  @override
  String get serverBelowMinimumTitle => 'Ovaj server je prestar';

  @override
  String serverBelowMinimumBody(String required, String reported) {
    return 'Za sigurno korištenje ove aplikacije potreban je Hoodik $required ili noviji. Ovaj javlja $reported. Ažuriraj server pa pokušaj ponovno.';
  }

  @override
  String get serverVersionUnknown => 'verzija prestara da se javi';

  @override
  String get serverBelowRecommendedVersion =>
      'Ovaj server zaostaje za verzijom za koju je aplikacija građena. Dok se ne ažurira, neke stvari mogu nedostajati.';
}
