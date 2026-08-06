// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get accountActiveTransfers => 'Transferts actifs en cours';

  @override
  String get accountAdminHeader => 'ADMINISTRATION';

  @override
  String get accountAdminPanel => 'Panneau d’administration';

  @override
  String get accountAdminPanelSubtitle =>
      'Utilisateurs, invitations et paramètres';

  @override
  String get accountAiAccessMacosOnly =>
      'L’accès IA via MCP est disponible dans la version macOS de Hoodik.';

  @override
  String get accountAiAccessSubtitle => 'Serveur MCP pour agents IA';

  @override
  String get accountAiAccessTitle => 'Accès IA';

  @override
  String get accountAllAccountsHeader => 'TOUS LES COMPTES';

  @override
  String get accountAuditAllStatuses => 'Tous les statuts';

  @override
  String get accountAuditAllTools => 'Tous les outils';

  @override
  String get accountAuditClearConfirmBody =>
      'Cela supprime définitivement chaque appel d’outil enregistré. Vos fichiers ne sont pas affectés.';

  @override
  String get accountAuditClearConfirmTitle => 'Effacer le journal d’audit ?';

  @override
  String get accountAuditClearLog => 'Effacer le journal';

  @override
  String get accountAuditCleared => 'Journal d’audit effacé';

  @override
  String get accountAuditDuration => 'Durée';

  @override
  String get accountAuditEmptyBody =>
      'Chaque appel d’outil IA est enregistré ici. Activez l’accès IA et connectez un agent pour voir l’activité.';

  @override
  String get accountAuditEmptyTitle => 'Aucune entrée d’audit pour l’instant';

  @override
  String get accountAuditError => 'Erreur';

  @override
  String get accountAuditFilterByStatus => 'Filtrer par statut';

  @override
  String get accountAuditFilterByTool => 'Filtrer par outil';

  @override
  String accountAuditLoadFailed(String error) {
    return 'Échec du chargement : $error';
  }

  @override
  String get accountAuditLogTitle => 'Journal d’audit';

  @override
  String accountAuditMilliseconds(int ms) {
    return '$ms ms';
  }

  @override
  String get accountAuditNoParams => '(aucun paramètre)';

  @override
  String get accountAuditParamsHash => 'Hachage des paramètres';

  @override
  String get accountAuditSession => 'Session';

  @override
  String get accountAuditStatus => 'Statut';

  @override
  String get accountAuditStatusDenied => 'Refusé';

  @override
  String get accountAuditStatusOk => 'Ok';

  @override
  String get accountAuditTimestamp => 'Horodatage';

  @override
  String get accountClear => 'Effacer';

  @override
  String get accountDefaultLanding => 'Écran d’accueil';

  @override
  String get accountDefaultLandingSubtitle =>
      'L’onglet affiché à l’ouverture de l’application';

  @override
  String get accountDiagnosticsExportLogs => 'Exporter les journaux';

  @override
  String get accountDiagnosticsLogsInfo =>
      'Les journaux peuvent contenir des noms de fichiers et des URL de serveur afin que vous puissiez reconnaître à quoi chaque ligne se réfère. Ils ne contiennent jamais le contenu des fichiers, les mots de passe ni les clés de chiffrement. Vous verrez chaque ligne et pourrez retirer ce que vous voulez avant l’envoi.';

  @override
  String get accountDiagnosticsNoTelemetryBody =>
      'Hoodik n’utilise ni Sentry, ni rapporteur de plantage, ni aucun service d’analyse tiers. Les seules données qui quittent votre appareil sont celles nécessaires à la synchronisation chiffrée de vos fichiers.';

  @override
  String get accountDiagnosticsNoTracking =>
      'Nous ne suivons rien concernant votre appareil.';

  @override
  String get accountDiagnosticsStep1 => 'Fermez complètement Hoodik.';

  @override
  String get accountDiagnosticsStep2 => 'Rouvrez l’application.';

  @override
  String get accountDiagnosticsStep3 => 'Essayez de reproduire le bug.';

  @override
  String get accountDiagnosticsStep4 =>
      'Revenez ici et touchez Exporter les journaux ci-dessous.';

  @override
  String get accountDiagnosticsSubtitle =>
      'Envoyer un rapport de bug — sans télémétrie';

  @override
  String get accountDiagnosticsTellUsBody =>
      'Cela signifie que lorsque quelque chose casse, nous ne le savons pas, sauf si vous nous le dites. Voici la façon la plus utile de le faire :';

  @override
  String get accountDiagnosticsTitle => 'Confidentialité et diagnostics';

  @override
  String get accountDisable => 'Désactiver';

  @override
  String get accountEnable => 'Activer';

  @override
  String get accountEnabled => 'Activé';

  @override
  String get accountEnterPinBody =>
      'Saisissez votre code PIN pour activer le déverrouillage biométrique.';

  @override
  String get accountEnterPinTitle => 'Saisir le code PIN';

  @override
  String get accountIncorrectPin => 'Code PIN incorrect';

  @override
  String get accountLegalHeader => 'MENTIONS LÉGALES';

  @override
  String get accountLogsClearAll => 'Tout effacer';

  @override
  String get accountLogsCopied => 'Journaux copiés dans le presse-papiers';

  @override
  String get accountLogsCopyToClipboard => 'Copier dans le presse-papiers';

  @override
  String get accountLogsCurrentSession => 'Session actuelle';

  @override
  String get accountLogsEmptyBody =>
      'Fermez l’application, rouvrez-la, reproduisez le bug, puis revenez et réessayez.';

  @override
  String get accountLogsEmptyTitle => 'Aucune ligne de journal à examiner.';

  @override
  String accountLogsLineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lignes',
      one: '$count ligne',
    );
    return '$_temp0';
  }

  @override
  String get accountLogsPastDays => '3 derniers jours';

  @override
  String get accountLogsReviewTitle => 'Examiner les journaux';

  @override
  String accountLogsSendViaEmail(String email) {
    return 'Envoyer par e-mail ($email)';
  }

  @override
  String get accountLogsShareFailed =>
      'Échec du partage — essayez plutôt Copier dans le presse-papiers';

  @override
  String get accountManageAccounts => 'Gérer les comptes';

  @override
  String get accountManageAccountsSubtitle => 'Ajouter ou changer de compte';

  @override
  String get accountMcpActivityHeader => 'ACTIVITÉ';

  @override
  String get accountMcpAllowReadOnlyOff =>
      'Tout accès des agents est suspendu quand l’application est verrouillée';

  @override
  String get accountMcpAllowReadOnlyOn =>
      'Les agents peuvent lister et rechercher les fichiers quand l’application est verrouillée';

  @override
  String get accountMcpAllowReadOnlyTitle =>
      'Autoriser l’accès en lecture seule pendant le verrouillage';

  @override
  String get accountMcpBearerToken => 'Jeton Bearer';

  @override
  String get accountMcpBurstCapacity => 'Capacité de rafale';

  @override
  String get accountMcpClearAuditLog => 'Effacer le journal d’audit';

  @override
  String get accountMcpClearAuditLogSubtitle =>
      'Supprime chaque appel d’outil enregistré';

  @override
  String get accountMcpConfigCopied =>
      'Configuration copiée dans le presse-papiers';

  @override
  String get accountMcpConfigFootnote =>
      'Copiez ce JSON dans la configuration de serveur MCP de Claude Desktop ou Claude Code.';

  @override
  String get accountMcpConfigurationHeader => 'CONFIGURATION';

  @override
  String get accountMcpConnectClientSubtitle =>
      'Assistant de configuration pour Claude Desktop, Cursor et autres';

  @override
  String get accountMcpConnectClientTitle => 'Connecter un client IA';

  @override
  String get accountMcpConnectionHeader => 'CONNEXION';

  @override
  String get accountMcpCopyConfig => 'Copier la configuration';

  @override
  String get accountMcpDisabled => 'Désactivé';

  @override
  String get accountMcpEnable => 'Activer l’accès IA';

  @override
  String get accountMcpEnableFootnote =>
      'Une fois activé, les agents IA comme Claude Desktop et Claude Code peuvent accéder à vos fichiers chiffrés via un endpoint local.';

  @override
  String get accountMcpEndpoint => 'Endpoint';

  @override
  String accountMcpLastAgentCall(String time) {
    return 'Dernier appel d’agent $time';
  }

  @override
  String get accountMcpLockedFootnote =>
      'Lorsque l’application est verrouillée par un code PIN, le déchiffrement du contenu des fichiers nécessite un déverrouillage. L’accès en lecture seule n’expose que des métadonnées chiffrées que le serveur connaît déjà.';

  @override
  String get accountMcpNoAgentActivity =>
      'Aucune activité d’agent pour l’instant';

  @override
  String get accountMcpNotRunning => 'À l’arrêt';

  @override
  String get accountMcpOffSubtitle =>
      'Activez l’accès IA pour démarrer le serveur MCP local.';

  @override
  String accountMcpPausedSubtitle(int port) {
    return 'Port $port réservé • redémarrez pour reprendre';
  }

  @override
  String accountMcpPerSecondOption(int value) {
    return '$value / s';
  }

  @override
  String get accountMcpPort => 'Port';

  @override
  String get accountMcpPortRange =>
      'Le port doit être compris entre 1024 et 65535';

  @override
  String accountMcpPortUpdated(int port) {
    return 'Port mis à jour : $port';
  }

  @override
  String get accountMcpQuickActionsHeader => 'ACTIONS RAPIDES';

  @override
  String get accountMcpRateLimitFootnote =>
      'Un seau à jetons limite chaque session IA. La capacité de rafale est le nombre de requêtes consécutives autorisées avant que le seau ne se remplisse au rythme configuré.';

  @override
  String get accountMcpRateLimitHeader => 'LIMITE DE DÉBIT';

  @override
  String get accountMcpRegenerate => 'Régénérer';

  @override
  String get accountMcpRequestsPerSecond => 'Requêtes par seconde';

  @override
  String accountMcpRetentionDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: '$count jour',
    );
    return '$_temp0';
  }

  @override
  String get accountMcpRetentionForever => 'Pour toujours';

  @override
  String get accountMcpRetentionHeader => 'RÉTENTION D’AUDIT';

  @override
  String get accountMcpRetentionOneYear => '1 an';

  @override
  String get accountMcpRetentionTitle => 'Conserver les entrées pendant';

  @override
  String get accountMcpRotateToken => 'Renouveler le jeton Bearer';

  @override
  String get accountMcpRotateTokenSubtitle =>
      'Invalide tous les clients IA configurés';

  @override
  String accountMcpRunningOnPort(int port) {
    return 'En cours d’exécution sur le port $port';
  }

  @override
  String get accountMcpSecurityHeader => 'SÉCURITÉ';

  @override
  String get accountMcpServerHeader => 'SERVEUR MCP';

  @override
  String get accountMcpStarting => 'Démarrage…';

  @override
  String get accountMcpStatusOff => 'Désactivé';

  @override
  String get accountMcpStatusPaused => 'En pause';

  @override
  String get accountMcpStatusRunning => 'En cours d’exécution';

  @override
  String get accountMcpStopServer => 'Arrêter le serveur';

  @override
  String get accountMcpStopServerSubtitle => 'Ferme le port MCP local';

  @override
  String get accountMcpTokenCopied => 'Jeton copié dans le presse-papiers';

  @override
  String get accountMcpTokenRegenerated => 'Jeton régénéré';

  @override
  String get accountMcpUnavailable =>
      'Le serveur MCP est indisponible. Connectez-vous sur macOS pour continuer.';

  @override
  String get accountMcpViewAuditLog => 'Voir le journal d’audit';

  @override
  String get accountMcpViewAuditLogSubtitle =>
      'Examiner chaque appel d’outil IA';

  @override
  String get accountMcpWizardMacosOnly =>
      'L’assistant de connexion est disponible dans la version macOS de Hoodik.';

  @override
  String get accountNotConfigured => 'Non configuré';

  @override
  String get accountNotSignedIn => 'Non connecté';

  @override
  String accountOfflineCacheStats(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers',
      one: '$count fichier',
    );
    return '$_temp0 · $size';
  }

  @override
  String get accountOfflineCacheTitle => 'Cache hors ligne';

  @override
  String get accountOfflineClearBody =>
      'Cela supprimera toutes les copies hors ligne de vos fichiers sur cet appareil. Vos fichiers sur le serveur ne sont pas affectés.';

  @override
  String get accountOfflineClearTitle => 'Vider le cache hors ligne';

  @override
  String get accountOfflineCleared => 'Cache hors ligne vidé';

  @override
  String get accountOfflineNoFiles => 'Aucun fichier en cache';

  @override
  String get accountOpenSourceLicenses => 'Licences open source';

  @override
  String get accountPasscodeLock => 'Verrouillage par code PIN';

  @override
  String get accountPinLabel => 'Code PIN';

  @override
  String get accountPrivacyPolicy => 'Politique de confidentialité';

  @override
  String get accountRecoveryHide => 'Masquer';

  @override
  String get accountRecoveryKeyBody =>
      'C’est l’élément qui permet de récupérer votre compte si vous oubliez un jour votre mot de passe. Conservez-en une copie en lieu sûr et privé — quiconque la possède peut se connecter à votre place. Pour l’utiliser, choisissez « Se connecter avec votre clé » sur l’écran de connexion.';

  @override
  String get accountRecoveryKeyCopied => 'Clé de récupération copiée';

  @override
  String get accountRecoveryKeyLocked =>
      'Vos clés ne sont pas déverrouillées pour le moment. Connectez-vous avec votre mot de passe pour exporter votre clé de récupération.';

  @override
  String get accountRecoveryKeySubtitle => 'Sauvegardez votre clé de connexion';

  @override
  String get accountRecoveryKeyTitle => 'Clé de récupération';

  @override
  String get accountRecoveryReveal => 'Afficher';

  @override
  String get accountRemovePasscodeBody =>
      'Cela supprimera l’écran de verrouillage par code PIN. Vous devrez vous connecter avec votre mot de passe la prochaine fois.';

  @override
  String get accountRemovePasscodeTitle => 'Supprimer le code PIN';

  @override
  String get accountSetUp => 'Configurer';

  @override
  String get accountSetUpPinFirst => 'Configurez d’abord un code PIN';

  @override
  String get accountSettingsHeader => 'PARAMÈTRES';

  @override
  String get accountSharingDisabledMsg =>
      'Vous ne recevrez plus d’e-mails de partage.';

  @override
  String get accountSharingEmailToggle =>
      'M’envoyer un e-mail lorsqu’un fichier est partagé avec moi';

  @override
  String get accountSharingEmailsOff =>
      'Les e-mails de partage sont désactivés.';

  @override
  String get accountSharingEmailsOn => 'Les e-mails de partage sont activés.';

  @override
  String get accountSharingEnabledMsg =>
      'Vous recevrez un e-mail lorsqu’une personne partage un fichier avec vous.';

  @override
  String get accountSharingHeader => 'PARTAGE';

  @override
  String get accountSharingUpdateFailed =>
      'Impossible de mettre à jour les notifications de partage.';

  @override
  String get accountSignOut => 'Déconnexion';

  @override
  String get accountSignOutConfirm => 'Voulez-vous vraiment vous déconnecter ?';

  @override
  String accountStorageQuota(String size) {
    return 'Quota : $size';
  }

  @override
  String get accountStorageTitle => 'Stockage';

  @override
  String get accountStorageUnlimited => 'Illimité';

  @override
  String accountStorageUsed(Object used) {
    return '$used utilisés';
  }

  @override
  String accountStorageUsedOfTotal(Object used, Object total) {
    return '$used sur $total utilisés';
  }

  @override
  String get accountTermsOfService => 'Conditions d’utilisation';

  @override
  String get accountTitle => 'Compte';

  @override
  String get accountWizardCallingInitialize => 'Appel d’initialize…';

  @override
  String accountWizardCapabilitiesList(String list) {
    return 'Capacités : $list';
  }

  @override
  String get accountWizardCapabilitiesNone => 'Capacités : aucune annoncée';

  @override
  String get accountWizardConnected => 'Connecté';

  @override
  String get accountWizardConnectionFailed =>
      'Échec de la connexion. Vérifiez le serveur et le jeton.';

  @override
  String get accountWizardCopyToClipboard => 'Copier dans le presse-papiers';

  @override
  String get accountWizardCopyToken => 'Copier le jeton';

  @override
  String get accountWizardEnableHint => 'Activez pour lier le port local.';

  @override
  String get accountWizardFailed => 'Échec';

  @override
  String get accountWizardFinish => 'Terminer';

  @override
  String get accountWizardHideToken => 'Masquer le jeton';

  @override
  String get accountWizardNext => 'Suivant';

  @override
  String get accountWizardNoToken => '(aucun jeton)';

  @override
  String get accountWizardOpenFolder => 'Ouvrir le dossier de configuration';

  @override
  String accountWizardProtocol(String version) {
    return 'protocole $version';
  }

  @override
  String get accountWizardReadyBody =>
      'Appuyez sur « Lancer le test » pour appeler initialize sur le serveur local.';

  @override
  String get accountWizardReadyTitle => 'Prêt pour le test';

  @override
  String get accountWizardRegenerateConfirmBody =>
      'Cela invalide les sessions d’agent existantes. Vous devrez coller le nouveau jeton dans chaque client IA que vous avez configuré.';

  @override
  String get accountWizardRegenerateConfirmTitle =>
      'Régénérer le jeton Bearer ?';

  @override
  String get accountWizardRunTest => 'Lancer le test';

  @override
  String accountWizardServerName(String name) {
    return 'Serveur $name';
  }

  @override
  String get accountWizardShowToken => 'Afficher le jeton';

  @override
  String get accountWizardStep1Subtitle =>
      'Le serveur MCP local doit être en cours d’exécution avant de pouvoir transmettre les identifiants à votre client IA.';

  @override
  String get accountWizardStep1Title =>
      'Étape 1 sur 4 : démarrer le serveur MCP';

  @override
  String get accountWizardStep2Subtitle =>
      'Votre client IA utilise ce jeton pour authentifier chaque appel MCP. Traitez-le comme un mot de passe.';

  @override
  String get accountWizardStep2Title =>
      'Étape 2 sur 4 : vérifier le jeton Bearer';

  @override
  String get accountWizardStep3Title =>
      'Étape 3 sur 4 : copier dans votre client IA';

  @override
  String get accountWizardStep4Subtitle =>
      'Nous appellerons initialize via le socket MCP local et vous montrerons exactement ce que votre client IA verra.';

  @override
  String get accountWizardStep4Title => 'Étape 4 sur 4 : vérifier le handshake';

  @override
  String get accountWizardTesting => 'Test en cours';

  @override
  String get accountWizardTryAgain => 'Réessayer';

  @override
  String adminActionFailed(String error) {
    return 'Échec : $error';
  }

  @override
  String get adminActionsHeader => 'ACTIONS';

  @override
  String get adminAdminRole => 'Rôle administrateur';

  @override
  String get adminAllowRegistration => 'Autoriser l’inscription';

  @override
  String get adminAllowRegistrationSubtitle =>
      'Permettre aux nouveaux utilisateurs de s’inscrire sans invitation';

  @override
  String get adminBadgeAdmin => 'admin';

  @override
  String get adminCopied => 'Copié';

  @override
  String get adminDefaultQuotaGbLabel => 'Quota par défaut (Go)';

  @override
  String get adminDefaultQuotaHeader => 'QUOTA PAR DÉFAUT';

  @override
  String get adminDeleteUser => 'Supprimer l’utilisateur';

  @override
  String adminDeleteUserBody(String email) {
    return 'Supprimer définitivement $email et TOUS ses fichiers ? Cette action est irréversible.';
  }

  @override
  String get adminDeleteUserSubtitle =>
      'Supprime définitivement l’utilisateur et toutes ses données';

  @override
  String get adminDisable => 'Désactiver';

  @override
  String get adminDisableTfa => 'Désactiver la 2FA';

  @override
  String adminDisableTfaBody(String email) {
    return 'Cela supprimera la 2FA pour $email. L’utilisateur devra la réactiver lui-même.';
  }

  @override
  String get adminDisableTfaTitle =>
      'Désactiver l’authentification à deux facteurs';

  @override
  String get adminDisabled => 'Désactivée';

  @override
  String get adminEditRoleQuotaTooltip => 'Modifier le rôle et le quota';

  @override
  String get adminEditUserTitle => 'Modifier l’utilisateur';

  @override
  String get adminEmailHeader => 'E-MAIL';

  @override
  String get adminEmailLabel => 'E-mail';

  @override
  String adminEmailTestFailed(String error) {
    return 'Échec de l’e-mail de test : $error';
  }

  @override
  String get adminEmailVerifiedLabel => 'E-mail vérifié';

  @override
  String get adminEnabled => 'Activée';

  @override
  String get adminEnforceEmailVerification =>
      'Exiger la vérification de l’e-mail';

  @override
  String get adminEnforceEmailVerificationSubtitle =>
      'Exiger que les utilisateurs vérifient leur e-mail avant la connexion';

  @override
  String get adminExpire => 'Faire expirer';

  @override
  String adminExpireInvitationBody(String email) {
    return 'Faire expirer l’invitation pour $email ? Elle ne pourra plus être utilisée pour s’inscrire.';
  }

  @override
  String get adminExpireInvitationTitle => 'Faire expirer l’invitation';

  @override
  String adminFileCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers',
      one: '$count fichier',
    );
    return '$_temp0';
  }

  @override
  String adminInvitationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invitations',
      one: '$count invitation',
    );
    return '$_temp0';
  }

  @override
  String adminInvitationSent(String email) {
    return 'Invitation envoyée à $email';
  }

  @override
  String get adminInvite => 'Inviter';

  @override
  String get adminKillAll => 'Tout révoquer';

  @override
  String get adminKillAllSessions => 'Révoquer toutes les sessions';

  @override
  String adminKillAllSessionsBody(String email) {
    return 'Cela déconnectera $email de tous les appareils.';
  }

  @override
  String adminLastActive(String time) {
    return 'Actif $time';
  }

  @override
  String get adminNoActiveSessions => 'Aucune session active';

  @override
  String get adminNoFiles => 'Aucun fichier';

  @override
  String get adminNoFilesSubtitle =>
      'Cet utilisateur n’a téléversé aucun fichier';

  @override
  String get adminNoInvitations => 'Aucune invitation pour l’instant';

  @override
  String get adminNoUsersFound => 'Aucun utilisateur trouvé';

  @override
  String get adminNotVerified => 'Non vérifié';

  @override
  String adminPaginationRange(int start, int end, int total) {
    return '$start–$end sur $total';
  }

  @override
  String get adminPanelTitle => 'Panneau d’administration';

  @override
  String get adminQuotaDefaultHint => 'Laissez vide pour la valeur par défaut';

  @override
  String get adminQuotaGbLabel => 'Quota (Go)';

  @override
  String get adminQuotaLabel => 'Quota';

  @override
  String get adminQuotaUnlimitedHint => 'Laissez vide pour un quota illimité';

  @override
  String get adminRegisteredLabel => 'Inscription';

  @override
  String get adminRegistrationHeader => 'INSCRIPTION DES UTILISATEURS';

  @override
  String get adminRoleAdmin => 'Administrateur';

  @override
  String get adminRoleLabel => 'Rôle';

  @override
  String get adminRoleUser => 'Utilisateur';

  @override
  String get adminSaveSettings => 'Enregistrer les paramètres';

  @override
  String get adminSearchUsersHint => 'Rechercher des utilisateurs…';

  @override
  String get adminSendInvitationTitle => 'Envoyer une invitation';

  @override
  String get adminSendTest => 'Envoyer le test';

  @override
  String adminSessionsHeader(int count) {
    return 'SESSIONS ($count)';
  }

  @override
  String get adminSettingsLoadFailed => 'Impossible de charger les paramètres';

  @override
  String get adminSettingsSaved => 'Paramètres enregistrés';

  @override
  String get adminSharingHeader => 'PARTAGE';

  @override
  String get adminSharingSubtitle =>
      'Si désactivé, l’action Partager disparaît partout et les endpoints de partage cessent de répondre. Les partages existants sont conservés.';

  @override
  String get adminSharingToggle => 'Partage entre comptes';

  @override
  String get adminStatusExpired => 'Expirée';

  @override
  String get adminStatusPending => 'En attente';

  @override
  String get adminStatusRedeemed => 'Utilisée';

  @override
  String adminStorageHeader(String size, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers',
      one: '$count fichier',
    );
    return 'STOCKAGE ($size · $_temp0)';
  }

  @override
  String get adminTabInvitations => 'Invitations';

  @override
  String get adminTabSettings => 'Paramètres';

  @override
  String get adminTabUsers => 'Utilisateurs';

  @override
  String get adminTestEmailSubtitle =>
      'Envoyer un e-mail de test pour vérifier le SMTP';

  @override
  String get adminTestEmailTitle => 'Tester la configuration e-mail';

  @override
  String get adminTwoFactorLabel => 'Authentification à deux facteurs';

  @override
  String get adminUnlimited => 'Illimité';

  @override
  String get adminUserDeleted => 'Utilisateur supprimé';

  @override
  String get adminUserInfoHeader => 'INFOS UTILISATEUR';

  @override
  String get adminUserUpdated => 'Utilisateur mis à jour';

  @override
  String get authAddAnotherAccount => 'Ajouter un autre compte';

  @override
  String get authAddNewServer => 'AJOUTER UN NOUVEAU SERVEUR';

  @override
  String get authAddServer => 'Ajouter un serveur';

  @override
  String get authBiometricFailed => 'Échec de la biométrie';

  @override
  String get authBiometricFailedUsePin =>
      'Échec de la biométrie — utilisez votre code PIN';

  @override
  String get authBiometricLockedOut =>
      'Trop de tentatives — réessayez dans 30 s, ou utilisez votre code PIN';

  @override
  String get authBiometricNotConfigured =>
      'Biométrie non configurée pour cette version — utilisez votre code PIN';

  @override
  String get authBiometricNotEnrolled =>
      'Aucune biométrie enregistrée sur cet appareil — utilisez votre code PIN';

  @override
  String get authBiometricPermanentlyLockedOut =>
      'Biométrie verrouillée — déverrouillez votre appareil, puis réessayez';

  @override
  String get authBiometricPinNotFound => 'Code PIN biométrique introuvable';

  @override
  String get authCheckEmailBody =>
      'Votre compte a été créé. Vérifiez votre e-mail, puis connectez-vous pour déverrouiller le chiffrement.';

  @override
  String get authCheckEmailTitle => 'Vérifiez votre boîte mail';

  @override
  String get authConfirmPasswordLabel => 'Confirmer le mot de passe';

  @override
  String get authConfirmPinLabel => 'Confirmer le code PIN';

  @override
  String get authConnectToServer => 'Se connecter à un serveur';

  @override
  String authConnectionFailed(String error) {
    return 'Échec de la connexion : $error';
  }

  @override
  String get authCreateAccount => 'Créer un compte';

  @override
  String get authCreateAnAccount => 'Créer un compte';

  @override
  String get authCreatePasscode => 'Créer un code PIN';

  @override
  String authDeleteServerConfirm(String name) {
    return 'Supprimer « $name » et tous ses comptes ?';
  }

  @override
  String get authDeleteServerTitle => 'Supprimer le serveur';

  @override
  String get authEmailLabel => 'E-mail';

  @override
  String get authEmailPasswordRequired =>
      'L’e-mail et le mot de passe sont requis';

  @override
  String get authEnterPasscode => 'Saisir le code PIN';

  @override
  String get authEnterPinPrompt => 'Veuillez saisir votre code PIN';

  @override
  String get authEnterTfaCode => 'Veuillez saisir votre code 2FA';

  @override
  String get authExistingAccounts => 'COMPTES EXISTANTS';

  @override
  String get authForget => 'Oublier';

  @override
  String authForgetAccountConfirm(String email) {
    return 'Cela supprimera le compte « $email » de cet appareil. Tous les fichiers hors ligne de ce compte seront supprimés. Vous pourrez vous reconnecter plus tard.';
  }

  @override
  String get authForgetAccountTitle => 'Oublier le compte';

  @override
  String get authForgetThisAccount => 'Oublier ce compte';

  @override
  String get authGetMyRecoveryKey => 'Obtenir ma clé de récupération';

  @override
  String get authInvalidCredentials => 'E-mail ou mot de passe invalide';

  @override
  String get authKeyLoginIntro =>
      'Collez la clé de récupération que vous avez enregistrée lors de la création de votre compte. Elle ne quitte jamais cet appareil — elle sert uniquement à signer un défi de connexion.';

  @override
  String get authKeyLoginInvalidKey => 'Ceci n’est pas une clé privée valide';

  @override
  String get authKeyLoginNoAccount =>
      'Le serveur a accepté la clé mais n’a renvoyé aucun compte';

  @override
  String get authKeyLoginNoIdentityKey =>
      'Cette clé de récupération ne contient aucune clé d’identité utilisable';

  @override
  String get authKeyLoginSelfCheckFailed =>
      'Cette clé de récupération a échoué à son auto-vérification';

  @override
  String get authKeyLoginSessionFailed =>
      'Connexion réussie, mais la session n’a pas pu être établie';

  @override
  String get authKeyLoginTitle => 'Se connecter avec votre clé';

  @override
  String get authKeyLoginUnrecognizedKey =>
      'Le serveur n’a pas reconnu cette clé';

  @override
  String authLastUsed(String time) {
    return 'Dernière utilisation $time';
  }

  @override
  String get authLater => 'Plus tard';

  @override
  String get authLearnMore => 'En savoir plus';

  @override
  String get authLogIn => 'Se connecter';

  @override
  String get authLogInWithKey => 'Se connecter avec votre clé';

  @override
  String get authLogInWithPassword => 'Connexion avec e-mail et mot de passe';

  @override
  String get authManageAccounts => 'Gérer les comptes';

  @override
  String get authMigrationNoticeBody =>
      'Vos fichiers sont désormais protégés par un chiffrement renforcé, et vous vous connectez sans que votre mot de passe ne quitte jamais cet appareil.\n\nComme cette opération a généré de nouvelles clés pour votre compte, enregistrez une nouvelle copie de votre clé de récupération — c’est le seul moyen de retrouver l’accès si vous oubliez votre mot de passe. Vous la trouverez toujours dans Compte → Clé de récupération.';

  @override
  String get authMigrationNoticeTitle =>
      'La sécurité de votre compte a été renforcée';

  @override
  String get authNeedServerBody =>
      'Hébergez-le gratuitement vous-même, ou obtenez une instance gérée.';

  @override
  String get authNeedServerTitle => 'Besoin d’un serveur ?';

  @override
  String get authNeverUsed => 'Jamais utilisé';

  @override
  String get authNoAccountFound => 'Aucun compte trouvé';

  @override
  String get authNoActiveAccountOrKey =>
      'Aucun compte actif ni clé privée disponible';

  @override
  String get authNoServerSelected => 'Aucun serveur sélectionné';

  @override
  String get authPasswordLabel => 'Mot de passe';

  @override
  String get authPasswordsDoNotMatch =>
      'Les mots de passe ne correspondent pas';

  @override
  String get authPasteRecoveryKeyFirst =>
      'Collez d’abord votre clé de récupération';

  @override
  String get authPinLabel => 'Code PIN';

  @override
  String get authPinPlaceholder => 'Au moins 4 caractères';

  @override
  String authPinSetupFailed(String error) {
    return 'Échec de la configuration du code PIN : $error';
  }

  @override
  String get authPinTooShort =>
      'Le code PIN doit contenir au moins 4 caractères';

  @override
  String get authPinsDoNotMatch => 'Les codes PIN ne correspondent pas';

  @override
  String get authRecoveryKeyEmpty => 'La clé de récupération est vide';

  @override
  String get authRecoveryKeyLabel => 'Clé de récupération';

  @override
  String get authRecoveryKeyMissingKeys =>
      'Il manque à la clé de récupération sa clé d’identité ou d’encapsulation';

  @override
  String get authRecoveryKeyUnrecognized =>
      'Ceci ne ressemble pas à une clé de récupération Hoodik';

  @override
  String authRegistrationFailed(String error) {
    return 'Échec de l’inscription : $error';
  }

  @override
  String get authRegistrationNotAllowed =>
      'L’inscription n’est pas autorisée pour cette adresse e-mail';

  @override
  String get authSavedServers => 'SERVEURS ENREGISTRÉS';

  @override
  String get authServerTooOldForRegister =>
      'Ce serveur est trop ancien pour créer un compte depuis cette application. Mettez à jour le serveur, ou connectez-vous à un compte existant.';

  @override
  String get authServerUrlLabel => 'URL du serveur';

  @override
  String get authServerUrlRequired => 'Veuillez saisir une URL de serveur';

  @override
  String get authSetPin => 'Définir le code PIN';

  @override
  String get authSetupPinIntro =>
      'Définissez un code PIN pour déverrouiller rapidement votre compte la prochaine fois, sans saisir votre mot de passe.';

  @override
  String get authSignIn => 'Se connecter';

  @override
  String get authSignInDifferentAccount => 'SE CONNECTER AVEC UN AUTRE COMPTE';

  @override
  String get authSignInToContinue => 'Veuillez vous connecter pour continuer.';

  @override
  String get authSignInToUnlockEncryption =>
      'Veuillez vous connecter avec votre mot de passe pour déverrouiller le chiffrement.';

  @override
  String get authSkip => 'Passer';

  @override
  String get authSwitchAccount => 'CHANGER DE COMPTE';

  @override
  String get authTagline => 'Stockage cloud chiffré de bout en bout';

  @override
  String get authTfaCodeLabel => 'Code 2FA';

  @override
  String get authTfaRequired =>
      'Le code d’authentification à deux facteurs est requis';

  @override
  String get authUnknownServer => 'Serveur inconnu';

  @override
  String get authUnlock => 'Déverrouiller';

  @override
  String get authUnlockHoodik => 'Déverrouiller Hoodik';

  @override
  String get authValidationError =>
      'Erreur de validation — vérifiez votre saisie';

  @override
  String get authWrongPin => 'Code PIN erroné';

  @override
  String get authWrongPinOrAuthFailed =>
      'Code PIN erroné ou échec de l’authentification';

  @override
  String get authWrongPinOrVerifyFailed =>
      'Code PIN erroné ou échec de la vérification';

  @override
  String get commonAdd => 'Ajouter';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonClose => 'Fermer';

  @override
  String get commonConfirm => 'Confirmer';

  @override
  String get commonCopy => 'Copier';

  @override
  String get commonCreate => 'Créer';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonDone => 'Terminé';

  @override
  String get commonDownload => 'Télécharger';

  @override
  String get commonEdit => 'Modifier';

  @override
  String get commonLoading => 'Chargement…';

  @override
  String get commonMove => 'Déplacer';

  @override
  String get commonNever => 'Jamais';

  @override
  String get commonNo => 'Non';

  @override
  String get commonOk => 'OK';

  @override
  String get commonOpen => 'Ouvrir';

  @override
  String get commonRemove => 'Retirer';

  @override
  String get commonRename => 'Renommer';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonSearch => 'Rechercher';

  @override
  String get commonSend => 'Envoyer';

  @override
  String get commonShare => 'Partager';

  @override
  String get commonUnknown => 'Inconnu';

  @override
  String get commonUpload => 'Téléverser';

  @override
  String get commonYes => 'Oui';

  @override
  String get errorNoConnection =>
      'Pas de connexion. Vérifiez votre réseau et réessayez.';

  @override
  String get errorNotAuthorized =>
      'Vous n’êtes pas autorisé à effectuer cette action. Reconnectez-vous et réessayez.';

  @override
  String errorRequestFailed(Object status) {
    return 'La requête a échoué ($status).';
  }

  @override
  String get errorServerUnavailable =>
      'Le serveur rencontre un problème. Réessayez dans un instant.';

  @override
  String get filesAccountNotInitialized => 'Compte pas entièrement initialisé';

  @override
  String filesAvailableOffline(String name) {
    return '$name disponible hors ligne';
  }

  @override
  String filesCacheFailed(String error) {
    return 'Échec de la mise en cache : $error';
  }

  @override
  String get filesCancelled => 'Annulé';

  @override
  String get filesCannotBeUndone => 'Cette action est irréversible.';

  @override
  String get filesCannotDecryptKey =>
      'Impossible de déchiffrer la clé du fichier';

  @override
  String get filesCannotDecryptSharedKey =>
      'Impossible de déchiffrer la clé du fichier partagé';

  @override
  String get filesCannotReadPath => 'Impossible de lire le chemin du fichier';

  @override
  String get filesChooseFolder => 'Choisir un dossier';

  @override
  String get filesChunksLabel => 'Fragments';

  @override
  String get filesCipherLabel => 'Algorithme de chiffrement';

  @override
  String get filesClear => 'Effacer';

  @override
  String filesConvertFailed(String error) {
    return 'Échec de la conversion : $error';
  }

  @override
  String get filesConvertToNote => 'Convertir en note';

  @override
  String get filesConvertedToNote => 'Converti en note';

  @override
  String filesCopiedToClipboard(String label) {
    return '$label copié dans le presse-papiers';
  }

  @override
  String get filesCopyLink => 'Copier le lien';

  @override
  String get filesCreateFolder => 'Créer un dossier';

  @override
  String filesCreateFolderFailed(String error) {
    return 'Échec de la création du dossier : $error';
  }

  @override
  String get filesCreateLink => 'Créer le lien';

  @override
  String filesCreateLinkFailed(String error) {
    return 'Échec de la création du lien : $error';
  }

  @override
  String get filesCreatedLabel => 'Créé';

  @override
  String get filesDateLabel => 'Date';

  @override
  String filesDeleteConfirmMessage(String name) {
    return 'Supprimer « $name » ? Cette action est irréversible.';
  }

  @override
  String filesDeleteCountTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Supprimer $count éléments ?',
      one: 'Supprimer $count élément ?',
    );
    return '$_temp0';
  }

  @override
  String filesDeleteFailed(String error) {
    return 'Échec de la suppression : $error';
  }

  @override
  String get filesDeleteFileTitle => 'Supprimer le fichier ?';

  @override
  String get filesDeleteFolderTitle => 'Supprimer le dossier ?';

  @override
  String get filesDeleted => 'Supprimé';

  @override
  String filesDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments supprimés',
      one: '$count élément supprimé',
    );
    return '$_temp0';
  }

  @override
  String get filesDetails => 'Détails';

  @override
  String get filesDiscard => 'Abandonner';

  @override
  String get filesDownloadingForOffline =>
      'Téléchargement pour l’accès hors ligne…';

  @override
  String get filesDropToUpload => 'Déposez des fichiers pour les téléverser';

  @override
  String get filesEmptyFolder => 'Dossier vide';

  @override
  String get filesEmptyHint =>
      'Touchez + pour créer un dossier ou téléverser un fichier';

  @override
  String get filesEmptyTitle => 'Aucun fichier pour l’instant';

  @override
  String get filesEncryptedFallback => '(chiffré)';

  @override
  String filesEncryptedPlaceholder(String id) {
    return '[Chiffré] $id…';
  }

  @override
  String get filesExport => 'Exporter';

  @override
  String filesExportFailed(String error) {
    return 'Échec de l’export : $error';
  }

  @override
  String get filesExportStarted =>
      'Export démarré — la feuille de partage s’ouvrira une fois terminé';

  @override
  String filesExportingTo(String path) {
    return 'Export vers $path';
  }

  @override
  String filesFailedUploadsHeader(int count) {
    return 'Téléversements échoués ($count)';
  }

  @override
  String filesFailedUploadsTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count téléversements échoués',
      one: '$count téléversement échoué',
    );
    return '$_temp0';
  }

  @override
  String get filesFolderCreated => 'Dossier créé';

  @override
  String get filesFolderLabel => 'Dossier';

  @override
  String get filesFolderNameHint => 'Nom du dossier';

  @override
  String filesForkFailed(String error) {
    return 'Échec de l’enregistrement dans votre espace : $error';
  }

  @override
  String get filesForkFolderUnsupported =>
      'Les dossiers ne peuvent pas être enregistrés dans votre espace';

  @override
  String get filesForkQuotaExceeded =>
      'Espace insuffisant pour enregistrer ce fichier dans votre espace';

  @override
  String filesForkSaved(String name) {
    return '« $name » enregistré dans votre espace';
  }

  @override
  String filesForkSaving(String name) {
    return 'Enregistrement de « $name » dans votre espace…';
  }

  @override
  String get filesIdLabel => 'ID';

  @override
  String get filesLeave => 'Quitter';

  @override
  String filesLeaveShareBody(String name) {
    return 'Vous perdrez l’accès à « $name » lors des prochaines lectures. Tout ce que vous avez déjà téléchargé reste chez vous — le chiffrement de bout en bout ne peut pas rappeler ce qui a déjà été déchiffré sur votre appareil, et le propriétaire ne peut pas l’annuler.';
  }

  @override
  String get filesLeaveShareTitle => 'Quitter ce partage ?';

  @override
  String get filesLinkCopied => 'Lien copié dans le presse-papiers';

  @override
  String get filesLinkCreatedTitle => 'Lien créé';

  @override
  String filesLoadFailed(String error) {
    return 'Échec du chargement des fichiers : $error';
  }

  @override
  String filesLoadSharedFailed(String error) {
    return 'Échec du chargement des éléments partagés : $error';
  }

  @override
  String get filesMakeAvailableOffline => 'Rendre disponible hors ligne';

  @override
  String get filesMembers => 'Membres';

  @override
  String get filesMoreActions => 'Plus d’actions';

  @override
  String filesMoveFailed(String error) {
    return 'Échec du déplacement : $error';
  }

  @override
  String get filesMoveHere => 'Déplacer ici';

  @override
  String filesMoveItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Déplacer $count éléments',
      one: 'Déplacer $count élément',
    );
    return '$_temp0';
  }

  @override
  String get filesMoveToTitle => 'Déplacer vers…';

  @override
  String get filesMyFiles => 'Mes fichiers';

  @override
  String get filesNameInvalid => 'Nom invalide';

  @override
  String get filesNameInvalidChars => 'Le nom ne peut pas contenir / ni \\';

  @override
  String get filesNameLabel => 'Nom';

  @override
  String get filesNewNameHint => 'Nouveau nom';

  @override
  String get filesNoAccessToLeave => 'Vous n’avez pas d’accès à quitter';

  @override
  String get filesNoSubfolders => 'Aucun sous-dossier';

  @override
  String get filesNotAuthenticated => 'Non authentifié';

  @override
  String get filesOfflineChip => 'Hors ligne';

  @override
  String get filesOfflineCopyRemoved => 'Copie hors ligne supprimée';

  @override
  String get filesOpsUnavailable => 'Opérations sur les fichiers indisponibles';

  @override
  String get filesOpsUnavailableNoKey =>
      'Opérations sur les fichiers indisponibles (aucune clé privée)';

  @override
  String filesOwnedBy(String name) {
    return 'Appartient à $name';
  }

  @override
  String filesPinnedForOffline(String name) {
    return '$name épinglé pour l’accès hors ligne';
  }

  @override
  String get filesPreparing => 'Préparation…';

  @override
  String get filesPreview => 'Aperçu';

  @override
  String get filesPublicKeyUnavailable => 'Clé publique indisponible';

  @override
  String get filesQueued => 'En file d’attente';

  @override
  String get filesRefresh => 'Actualiser';

  @override
  String get filesRemoveOfflineCopy => 'Supprimer la copie hors ligne';

  @override
  String filesRenameFailed(String error) {
    return 'Échec du renommage : $error';
  }

  @override
  String get filesRenamed => 'Renommé';

  @override
  String filesRevokeFailed(String error) {
    return 'Échec de la révocation : $error';
  }

  @override
  String get filesRootFolder => 'Racine';

  @override
  String get filesSaveFileDialogTitle => 'Enregistrer le fichier';

  @override
  String get filesSaveToMyDrive => 'Enregistrer dans mon espace';

  @override
  String get filesSelect => 'Sélectionner';

  @override
  String get filesSelectFilesTooltip => 'Sélectionner des fichiers';

  @override
  String filesSelectedCount(int count) {
    return '$count sélectionné(s)';
  }

  @override
  String filesShareFailed(String error) {
    return 'Échec du partage : $error';
  }

  @override
  String get filesSharedItemsNeedConnection =>
      'Les éléments partagés nécessitent une connexion.';

  @override
  String filesSharedWith(int count) {
    return 'Partagé avec $count';
  }

  @override
  String get filesSizeLabel => 'Taille';

  @override
  String get filesSortTooltip => 'Trier';

  @override
  String get filesStillUploading =>
      'Ce fichier est encore en cours de téléversement — patientez un instant.';

  @override
  String get filesTakePhoto => 'Prendre une photo';

  @override
  String get filesTheseFolders => 'ces dossiers';

  @override
  String get filesTitle => 'Fichiers';

  @override
  String filesTransferActive(String verb, String fileName) {
    return '$verb $fileName';
  }

  @override
  String filesTransferActiveMore(String verb, String fileName, int count) {
    return '$verb $fileName (+$count autres)';
  }

  @override
  String filesTransferCancelled(String fileName) {
    return '$fileName — Annulé';
  }

  @override
  String filesTransferDone(String fileName) {
    return '$fileName — Terminé';
  }

  @override
  String filesTransferDoneSize(String size) {
    return 'Terminé  $size';
  }

  @override
  String filesTransferFailed(String fileName) {
    return '$fileName — Échoué';
  }

  @override
  String filesTransferQueued(String fileName) {
    return '$fileName — En file d’attente';
  }

  @override
  String filesTransfersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transferts',
      one: '$count transfert',
    );
    return '$_temp0';
  }

  @override
  String get filesTransfersDismissTooltip =>
      'Fermer — les transferts continuent en arrière-plan';

  @override
  String get filesTransfersTitle => 'Transferts';

  @override
  String get filesTypeLabel => 'Type';

  @override
  String get filesUnknownError => 'Erreur inconnue';

  @override
  String filesUploadFailed(String error) {
    return 'Échec du téléversement : $error';
  }

  @override
  String get filesUploadFile => 'Téléverser un fichier';

  @override
  String get filesUploadHere => 'Téléverser ici';

  @override
  String get filesUploadMedia => 'Téléverser des médias';

  @override
  String filesUploadingChunks(int stored, int total) {
    return 'Téléversement… $stored/$total fragments';
  }

  @override
  String filesViewAsTooltip(String mode) {
    return 'Affichage : $mode';
  }

  @override
  String get filesViewIcons => 'Icônes';

  @override
  String get filesViewList => 'Liste';

  @override
  String get filesViewTree => 'Arborescence';

  @override
  String get filesYourDrive => 'votre espace';

  @override
  String get languageSubtitle => 'Langue d’affichage de l’application';

  @override
  String get languageSystem => 'Par défaut du système';

  @override
  String get languageTitle => 'Langue';

  @override
  String get linksCopiedToClipboard => 'Lien copié dans le presse-papiers';

  @override
  String get linksCopyTooltip => 'Copier le lien';

  @override
  String linksDeleteBody(String name) {
    return 'Cela supprimera le lien partagé pour « $name ». Le fichier lui-même ne sera pas supprimé.';
  }

  @override
  String linksDeleteFailed(String error) {
    return 'Échec de la suppression : $error';
  }

  @override
  String get linksDeleteLink => 'Supprimer le lien';

  @override
  String get linksDeleteTitle => 'Supprimer le lien ?';

  @override
  String get linksDeleted => 'Lien supprimé';

  @override
  String linksDownloadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count téléchargements',
      one: '$count téléchargement',
    );
    return '$_temp0';
  }

  @override
  String get linksEmptySubtitle =>
      'Créez un lien depuis le menu contextuel de n’importe quel fichier';

  @override
  String get linksEmptyTitle => 'Aucun lien partagé';

  @override
  String get linksExpired => 'Expiré';

  @override
  String linksExpiresInDays(int days) {
    return 'Expire dans $days j';
  }

  @override
  String linksExpiresInHours(int hours) {
    return 'Expire dans $hours h';
  }

  @override
  String get linksExpiresSoon => 'Expire bientôt';

  @override
  String get linksExpiryRemoved =>
      'Expiration supprimée — le lien n’expire jamais';

  @override
  String get linksExpiryUpdated => 'Expiration mise à jour';

  @override
  String get linksNotAuthenticated => 'Non authentifié';

  @override
  String get linksRemoveExpiry => 'Supprimer l’expiration';

  @override
  String get linksSetExpiry => 'Définir l’expiration';

  @override
  String linksUpdateFailed(String error) {
    return 'Échec de la mise à jour : $error';
  }

  @override
  String get notesAuthorAnonymous => 'Anonyme';

  @override
  String get notesAuthorYou => 'Vous';

  @override
  String get notesBlockquote => 'Citation';

  @override
  String get notesBold => 'Gras';

  @override
  String get notesBulletList => 'Liste à puces';

  @override
  String get notesCannotDecrypt => 'Impossible de déchiffrer le fichier';

  @override
  String get notesCannotOpenNoKey =>
      'Ouverture impossible — clé de déchiffrement indisponible';

  @override
  String notesChunkCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fragments',
      one: '$count fragment',
    );
    return '$_temp0';
  }

  @override
  String get notesClearHistoryBody =>
      'Toutes les versions historiques de cette note seront définitivement supprimées. La note actuelle est conservée.';

  @override
  String get notesClearHistoryTitle => 'Effacer tout l’historique ?';

  @override
  String get notesClearHistoryTooltip => 'Effacer tout l’historique';

  @override
  String get notesCloseEditor => 'Fermer l’éditeur';

  @override
  String get notesCloseNote => 'Fermer la note';

  @override
  String get notesCode => 'Bloc de code';

  @override
  String get notesConflictBody =>
      'Le serveur a un enregistrement inachevé de cette note provenant d’une autre session. Écraser abandonnera ce que cette session était sur le point de valider.';

  @override
  String get notesConflictDiscardMine => 'Abandonner mes modifications';

  @override
  String get notesConflictOverwrite =>
      'Abandonner la version distante, enregistrer la mienne';

  @override
  String get notesConflictTitle => 'Un autre enregistrement est en cours';

  @override
  String notesCreateFolderFailed(String error) {
    return 'Échec de la création du dossier : $error';
  }

  @override
  String notesCreateFolderIn(String folder) {
    return 'Créer un nouveau dossier dans « $folder »';
  }

  @override
  String get notesCreateFolderInRoot => 'Créer un nouveau dossier à la racine';

  @override
  String notesCreateNoteFailed(String error) {
    return 'Échec de la création de la note : $error';
  }

  @override
  String notesCreateNoteIn(String folder) {
    return 'Créer une nouvelle note dans « $folder »';
  }

  @override
  String get notesCreateNoteInRoot => 'Créer une nouvelle note à la racine';

  @override
  String notesCreatedNote(String name) {
    return '« $name » créée';
  }

  @override
  String get notesCreatedNoteMissingKey =>
      'La note créée n’a pas de clé de chiffrement';

  @override
  String get notesDeleteAll => 'Tout supprimer';

  @override
  String notesDeleteFolderBody(String name) {
    return '« $name » et tout son contenu seront définitivement supprimés.';
  }

  @override
  String notesDeleteFolderFailed(String error) {
    return 'Échec de la suppression du dossier : $error';
  }

  @override
  String get notesDeleteFolderTitle => 'Supprimer le dossier ?';

  @override
  String notesDeleteNoteBody(String name) {
    return '« $name » sera définitivement supprimée.';
  }

  @override
  String notesDeleteNoteFailed(String error) {
    return 'Échec de la suppression : $error';
  }

  @override
  String get notesDeleteNoteTitle => 'Supprimer la note ?';

  @override
  String get notesDeleteThisVersion => 'Supprimer cette version';

  @override
  String notesDeleteVersionFailed(String error) {
    return 'Échec de la suppression : $error';
  }

  @override
  String notesDeleteVersionMsg(int version, String date) {
    return 'La v$version du $date sera supprimée définitivement. Cette action est irréversible.';
  }

  @override
  String notesDeleteVersionTitle(int version) {
    return 'Supprimer la v$version ?';
  }

  @override
  String get notesDetails => 'Détails';

  @override
  String get notesDiscard => 'Abandonner';

  @override
  String get notesEmptyHint =>
      'Créez-en une depuis le bouton + de la barre latérale.';

  @override
  String get notesEmptyTitle => 'Aucune note pour l’instant';

  @override
  String notesEncryptedFallback(String id) {
    return '[Chiffré] $id…';
  }

  @override
  String get notesEncryptedName => '(chiffré)';

  @override
  String get notesExport => 'Exporter';

  @override
  String notesExportFailed(String error) {
    return 'Échec de l’export : $error';
  }

  @override
  String get notesExportStarted =>
      'Export démarré — la feuille de partage s’ouvrira une fois prêt';

  @override
  String get notesExportToPdf => 'Exporter en PDF';

  @override
  String notesExportingTo(String path) {
    return 'Export vers $path';
  }

  @override
  String get notesFileNotFound => 'Fichier introuvable';

  @override
  String get notesFolderName => 'dossier';

  @override
  String get notesFolderNameHint => 'Mon dossier';

  @override
  String notesForkFailed(String error) {
    return 'Échec de la duplication : $error';
  }

  @override
  String notesHeading(int level) {
    return 'Titre $level';
  }

  @override
  String get notesHideSidebar => 'Masquer la barre latérale';

  @override
  String get notesHideKeyboard => 'Masquer le clavier';

  @override
  String get notesHistory => 'Historique des versions';

  @override
  String notesHistoryNamed(String name) {
    return 'Historique · $name';
  }

  @override
  String get notesItalic => 'Italique';

  @override
  String get notesKeyUnavailable =>
      'Déchiffrement impossible — clé du fichier ou client indisponible';

  @override
  String get notesLoadFailed => 'Échec du chargement';

  @override
  String notesLoadNotesFailed(String error) {
    return 'Échec du chargement des notes : $error';
  }

  @override
  String get notesMetadataUnavailable => 'Métadonnées du fichier indisponibles';

  @override
  String notesModified(String when) {
    return 'Modifiée $when';
  }

  @override
  String get notesMore => 'Plus';

  @override
  String get notesMoreActions => 'Plus d’actions';

  @override
  String notesMoveFailed(String error) {
    return 'Échec du déplacement : $error';
  }

  @override
  String get notesMoveHere => 'Déplacer ici';

  @override
  String get notesMoveToTitle => 'Déplacer vers';

  @override
  String get notesMoved => 'Déplacé';

  @override
  String get notesNameRequired => 'Le nom est requis';

  @override
  String get notesNewFolder => 'Nouveau dossier';

  @override
  String notesNewIn(String name) {
    return 'Nouvelle note ou dossier dans $name';
  }

  @override
  String get notesNewNote => 'Nouvelle note';

  @override
  String get notesNoHistory =>
      'Aucun historique pour l’instant. Modifiez la note pour commencer à en constituer un.';

  @override
  String get notesNoServerId => 'Le serveur n’a renvoyé aucun identifiant';

  @override
  String get notesNotAuthenticated => 'Non authentifié';

  @override
  String get notesNotSignedIn => 'Non connecté';

  @override
  String get notesNoteNameHint => 'Ma note';

  @override
  String get notesNumberedList => 'Liste numérotée';

  @override
  String notesPdfExportFailed(String error) {
    return 'Échec de l’export PDF : $error';
  }

  @override
  String get notesPreview => 'Aperçu';

  @override
  String notesPreviewFailed(String error) {
    return 'Échec de l’aperçu : $error';
  }

  @override
  String notesPurgeFailed(String error) {
    return 'Échec de la purge : $error';
  }

  @override
  String get notesRecentHeader => 'Notes récentes';

  @override
  String get notesRedo => 'Rétablir';

  @override
  String notesRenameFailed(String error) {
    return 'Échec du renommage : $error';
  }

  @override
  String notesRenameFolderFailed(String error) {
    return 'Échec du renommage du dossier : $error';
  }

  @override
  String get notesRenameNote => 'Renommer la note';

  @override
  String get notesResetZoom => 'Réinitialiser le zoom';

  @override
  String get notesRestore => 'Restaurer';

  @override
  String get notesRestoreAsNew => 'Restaurer comme nouvelle note';

  @override
  String notesRestoreFailed(String error) {
    return 'Échec de la restauration : $error';
  }

  @override
  String get notesRestoreHere => 'Restaurer sur place';

  @override
  String get notesRestoreThisVersion => 'Restaurer cette version';

  @override
  String notesRestoreVersionMsg(int version, String date) {
    return 'Ceci remplace le contenu actuel par la v$version du $date. Votre version actuelle reste dans l’historique, vous pourrez donc annuler la restauration plus tard.';
  }

  @override
  String notesRestoreVersionTitle(int version) {
    return 'Restaurer la v$version ?';
  }

  @override
  String notesRestoredVersion(int version) {
    return 'v$version restaurée';
  }

  @override
  String get notesRootName => 'racine';

  @override
  String get notesSaveAndClose => 'Enregistrer et fermer';

  @override
  String notesSaveFailed(String error) {
    return 'Échec de l’enregistrement : $error';
  }

  @override
  String get notesSaveNoteDialogTitle => 'Enregistrer la note';

  @override
  String get notesShowSidebar => 'Afficher la barre latérale';

  @override
  String get notesSidebarEmpty => 'Aucune note ni dossier';

  @override
  String get notesSidebarHeader => 'NOTES';

  @override
  String get notesStillUploading =>
      'Cette note est encore en cours de téléversement. Si elle reste bloquée, supprimez-la depuis l’onglet Fichiers et créez-en une nouvelle.';

  @override
  String get notesStrikethrough => 'Barré';

  @override
  String get notesTable => 'Tableau';

  @override
  String get notesThisFolder => 'ce dossier';

  @override
  String get notesThisNote => 'cette note';

  @override
  String get notesTitle => 'Notes';

  @override
  String get notesUndo => 'Annuler';

  @override
  String get notesUnsavedChangesBody =>
      'Vous avez des modifications non enregistrées. Que voulez-vous faire ?';

  @override
  String notesUnsavedChangesTitle(String name) {
    return 'Modifications non enregistrées — $name';
  }

  @override
  String get notesUntitled => 'Sans titre';

  @override
  String get notesZoomIn => 'Zoom avant';

  @override
  String get notesZoomOut => 'Zoom arrière';

  @override
  String get previewCannotDecrypt => 'Impossible de déchiffrer le fichier';

  @override
  String get previewDecryptAfterDownloadFailed =>
      'Échec du déchiffrement après le téléchargement';

  @override
  String previewDeleteFailed(String error) {
    return 'Échec de la suppression : $error';
  }

  @override
  String previewDeleteFileBody(String name) {
    return 'Supprimer « $name » ? Cette action est irréversible.';
  }

  @override
  String get previewDeleteFileTitle => 'Supprimer le fichier ?';

  @override
  String get previewDownloadFailed => 'Échec du téléchargement';

  @override
  String get previewExport => 'Exporter';

  @override
  String get previewFailedToLoadImage => 'Échec du chargement de l’image';

  @override
  String previewFailedToRenderPage(String error) {
    return 'Échec du rendu de la page : $error';
  }

  @override
  String get previewNoPreviewAvailable => 'Aucun aperçu disponible';

  @override
  String get previewNoPreviewableFiles => 'Aucun fichier prévisualisable';

  @override
  String previewPageCounter(int current, int total) {
    return 'Page $current / $total';
  }

  @override
  String get previewSaveFileTitle => 'Enregistrer le fichier';

  @override
  String previewShowingFirstMb(String size) {
    return 'Affichage du premier Mo sur $size';
  }

  @override
  String relativeDaysAgo(int days) {
    return 'il y a $days j';
  }

  @override
  String relativeHoursAgo(int hours) {
    return 'il y a $hours h';
  }

  @override
  String get relativeJustNow => 'à l’instant';

  @override
  String relativeMinutesAgo(int minutes) {
    return 'il y a $minutes min';
  }

  @override
  String get searchEmptyPrompt => 'Recherchez vos fichiers';

  @override
  String searchEncryptedFileFallback(String id) {
    return '[Chiffré] $id…';
  }

  @override
  String searchFailed(String error) {
    return 'Échec de la recherche : $error';
  }

  @override
  String get searchHint => 'Rechercher des fichiers et des notes…';

  @override
  String get searchNoResults => 'Aucun résultat';

  @override
  String serviceBugReportShareText(String email) {
    return 'Décrivez ce que vous faisiez lorsque le bug s’est produit, avec si possible les étapes pour le reproduire.\n\nÀ envoyer à : $email';
  }

  @override
  String get serviceBugReportSubject => 'Rapport de bug Hoodik';

  @override
  String get serviceDownloadCancelled => 'Téléchargement annulé';

  @override
  String get serviceDownloadFailed => 'Échec du téléchargement';

  @override
  String get serviceFileAlreadyExists => 'Le fichier existe déjà';

  @override
  String get serviceFileNoEncryptionKey =>
      'Le fichier n’a pas de clé de chiffrement';

  @override
  String get serviceLandingBranchFiles => 'Fichiers';

  @override
  String get serviceLandingBranchNotes => 'Notes';

  @override
  String get serviceNotificationDownloadComplete => 'Téléchargement terminé';

  @override
  String get serviceNotificationReady => 'Prêt';

  @override
  String get serviceNotificationUploadComplete => 'Téléversement terminé';

  @override
  String get serviceOfflineManagerUnavailable =>
      'Gestionnaire hors ligne indisponible';

  @override
  String get serviceTransferCancelled => 'Annulé';

  @override
  String get serviceTransferDecrypting => 'Déchiffrement';

  @override
  String get serviceTransferDownloading => 'Téléchargement';

  @override
  String get serviceTransferEncrypting => 'Chiffrement';

  @override
  String get serviceTransferUploading => 'Téléversement';

  @override
  String get serviceUploadCancelled => 'Téléversement annulé';

  @override
  String get serviceUploadFailed => 'Échec du téléversement';

  @override
  String get serviceUploadWorkerUnavailable =>
      'Le téléversement nécessite un worker de chiffrement actif et le transport tar. Veuillez redémarrer l’application et réessayer.';

  @override
  String get sharesAccessRevoked => 'Accès révoqué';

  @override
  String sharesAccessRevokedFor(String email) {
    return 'Accès révoqué pour $email';
  }

  @override
  String get sharesAddFiles => 'Ajouter des fichiers';

  @override
  String get sharesAddMember => 'Ajouter un membre';

  @override
  String sharesAddMemberFailed(String error) {
    return 'Impossible d’ajouter le membre : $error';
  }

  @override
  String sharesAddMemberToGroup(String group) {
    return 'Ajouter un membre à $group';
  }

  @override
  String get sharesAddedByCoOwner => 'Ajouté par un copropriétaire';

  @override
  String get sharesAddedByOwner => 'Ajouté par le propriétaire';

  @override
  String get sharesAddedByUnknown => 'Ajouté par un inconnu';

  @override
  String get sharesAllowAddFiles => 'Autoriser à ajouter de nouveaux fichiers';

  @override
  String get sharesAuditARecipient => 'un destinataire';

  @override
  String get sharesAuditARecipientCapital => 'Un destinataire';

  @override
  String get sharesAuditAccessFallback => 'accès';

  @override
  String get sharesAuditBadgeMismatch => 'Divergence';

  @override
  String get sharesAuditBadgeSystem => 'Système';

  @override
  String get sharesAuditBadgeVerified => 'Vérifié';

  @override
  String sharesAuditCoOwnerRevoked(String recipient, String file) {
    return 'L’accès de $recipient à $file via un copropriétaire a été révoqué';
  }

  @override
  String sharesAuditEdited(String sender, String file) {
    return '$sender a modifié le fichier partagé $file';
  }

  @override
  String get sharesAuditEmpty =>
      'Aucune activité de partage pour l’instant. Les événements apparaissent ici lorsque vous partagez un fichier, changez un rôle ou révoquez un accès.';

  @override
  String sharesAuditEvicted(String recipient, String file) {
    return '$recipient a perdu l’accès à $file (cascade)';
  }

  @override
  String sharesAuditFileIdLabel(String head) {
    return 'fichier $head…';
  }

  @override
  String sharesAuditForked(String sender, String file) {
    return '$sender a dupliqué $file dans son espace';
  }

  @override
  String sharesAuditGrant(String sender, String file, String recipient) {
    return '$sender a partagé $file avec $recipient';
  }

  @override
  String sharesAuditGrantAsRole(
    String sender,
    String file,
    String recipient,
    String role,
  ) {
    return '$sender a partagé $file avec $recipient en tant que $role';
  }

  @override
  String sharesAuditKeyRotation(String sender) {
    return '$sender a effectué la rotation des clés de chiffrement de son compte';
  }

  @override
  String get sharesAuditLegendMismatch =>
      'vérification échouée — ne faites pas confiance à cette ligne';

  @override
  String get sharesAuditLegendSystem =>
      'événement de cascade attribué au serveur, sans signature';

  @override
  String get sharesAuditLegendVerified => 'signature et chaîne vérifiées';

  @override
  String get sharesAuditLinkBroken =>
      'Le chaînage vers l’événement visible précédent est rompu.';

  @override
  String get sharesAuditLoadFailed =>
      'Impossible de charger votre activité de partage.';

  @override
  String get sharesAuditLoadFailedOffline =>
      'Impossible de charger votre activité de partage. L’activité nécessite une connexion au serveur — réessayez une fois de retour en ligne.';

  @override
  String sharesAuditMovedOut(String sender, String file) {
    return '$sender a déplacé $file hors d’un dossier partagé';
  }

  @override
  String get sharesAuditPageBoundaryNote =>
      'Un événement antérieur de cette chaîne se trouve sur une autre page';

  @override
  String get sharesAuditRecipientFallback => 'destinataire';

  @override
  String sharesAuditReshared(String sender, String file, String recipient) {
    return '$sender a repartagé $file avec $recipient';
  }

  @override
  String sharesAuditResharedAsRole(
    String sender,
    String file,
    String recipient,
    String role,
  ) {
    return '$sender a repartagé $file avec $recipient en tant que $role';
  }

  @override
  String sharesAuditRestored(String sender, String file) {
    return '$sender a restauré une version antérieure du fichier partagé $file';
  }

  @override
  String sharesAuditRevoked(String sender, String recipient, String file) {
    return '$sender a révoqué l’accès de $recipient à $file';
  }

  @override
  String sharesAuditRoleChanged(String sender, String recipient, String file) {
    return '$sender a changé le rôle de $recipient sur $file';
  }

  @override
  String sharesAuditRoleChangedFromTo(
    String sender,
    String recipient,
    String file,
    String before,
    String after,
  ) {
    return '$sender a changé le rôle de $recipient sur $file de $before à $after';
  }

  @override
  String get sharesAuditSelfHashMismatch =>
      'Le contenu de la ligne ne correspond pas à son hachage enregistré.';

  @override
  String sharesAuditShowingRecent(int shown, int total) {
    return 'Affichage des $shown événements les plus récents sur $total.';
  }

  @override
  String get sharesAuditSignatureFailed =>
      'La vérification de la signature a échoué pour cet événement.';

  @override
  String get sharesAuditSystemSender => 'système';

  @override
  String get sharesAuditTamperedBody =>
      'Cet événement a échoué à la vérification. Considérez son contenu avec méfiance et signalez-le au propriétaire du fichier.';

  @override
  String sharesAuditUploaded(String sender, String file) {
    return '$sender a téléversé dans le dossier partagé $file';
  }

  @override
  String get sharesCannotAddSelfToGroup =>
      'Vous ne pouvez pas vous ajouter vous-même à un groupe.';

  @override
  String get sharesCannotDecryptFileKey =>
      'Impossible de déchiffrer la clé du fichier';

  @override
  String get sharesCannotShareWithSelf =>
      'Vous ne pouvez pas partager avec vous-même.';

  @override
  String get sharesChangeRole => 'Changer le rôle';

  @override
  String get sharesDeleteGroup => 'Supprimer le groupe';

  @override
  String sharesDeleteGroupBody(String name) {
    return 'Supprimer « $name » ? Les fichiers déjà partagés avec ces personnes restent partagés ; le groupe est simplement retiré comme sélection enregistrée.';
  }

  @override
  String get sharesDeleteGroupTitle => 'Supprimer le groupe ?';

  @override
  String get sharesDestinationIsShared =>
      'La destination est elle-même un dossier partagé. Choisissez un dossier privé ou la racine de votre espace.';

  @override
  String get sharesEmailPlaceholder => 'quelquun@exemple.com';

  @override
  String get sharesEmailUnknownCannotChangeRole =>
      'E-mail inconnu — impossible de changer le rôle';

  @override
  String get sharesEnterMemberEmailFirst =>
      'Saisissez d’abord l’adresse e-mail du membre.';

  @override
  String get sharesEnterRecipientEmailFirst =>
      'Saisissez d’abord l’adresse e-mail du destinataire.';

  @override
  String get sharesEveryoneCanRead =>
      'Toutes les personnes listées pourront lire chaque fichier de ce dossier.';

  @override
  String sharesEvictFailed(String error) {
    return 'Échec de la révocation en cascade : $error';
  }

  @override
  String get sharesFindUser => 'Trouver l’utilisateur';

  @override
  String get sharesGiveGroupName => 'Donnez un nom au groupe.';

  @override
  String sharesGroupCreateFailed(String error) {
    return 'Impossible de créer le groupe : $error';
  }

  @override
  String get sharesGroupDeleteFailed => 'Impossible de supprimer le groupe.';

  @override
  String sharesGroupDeleted(String name) {
    return '« $name » a été supprimé.';
  }

  @override
  String get sharesGroupLabel => 'Groupe';

  @override
  String sharesGroupMemberKeyUnverified(String email) {
    return 'La clé d’un membre du groupe n’a pas pu être vérifiée — partage refusé. ($email)';
  }

  @override
  String get sharesGroupNameLabel => 'Nom du groupe';

  @override
  String get sharesGroupNamePlaceholder => 'ex. Équipe marketing';

  @override
  String get sharesGroupNameTaken => 'Un groupe portant ce nom existe déjà.';

  @override
  String get sharesGroupNoOneElse =>
      'Ce groupe n’a encore personne d’autre avec qui partager.';

  @override
  String sharesGroupReady(String name) {
    return '« $name » est prêt à recevoir des membres.';
  }

  @override
  String sharesGroupRenameFailed(String error) {
    return 'Impossible de renommer le groupe : $error';
  }

  @override
  String get sharesGroupRoleCoOwnerDescription =>
      'Copropriétaire — peut aussi gérer les membres et renommer.';

  @override
  String get sharesGroupRoleEditorDescription =>
      'Éditeur — peut partager des fichiers avec le groupe.';

  @override
  String get sharesGroupRoleLabel => 'Rôle dans le groupe';

  @override
  String get sharesGroupRoleOwnerDescription =>
      'Propriétaire — contrôle total du groupe.';

  @override
  String get sharesGroupRoleReaderDescription =>
      'Lecteur — voit le groupe, rien de plus.';

  @override
  String get sharesGroupsExplainer =>
      'Les groupes vous permettent de partager avec tous leurs membres en une seule fois.';

  @override
  String get sharesGroupsLoadFailed => 'Impossible de charger vos groupes.';

  @override
  String get sharesInvalidEmail =>
      'Cela ne ressemble pas à une adresse e-mail.';

  @override
  String sharesItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments',
      one: '$count élément',
    );
    return '$_temp0';
  }

  @override
  String get sharesKeyFingerprintMismatch =>
      'La clé et l’empreinte de ce compte ne correspondent pas. Le partage est bloqué — n’allez pas plus loin.';

  @override
  String get sharesLookupFailed => 'Impossible de trouver cet utilisateur.';

  @override
  String sharesMemberAddedToGroup(String email, String group) {
    return '$email fait maintenant partie de « $group ».';
  }

  @override
  String sharesMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membres',
      one: '$count membre',
    );
    return '$_temp0';
  }

  @override
  String get sharesMemberEmailLabel => 'Adresse e-mail du membre';

  @override
  String sharesMemberNowRole(String email, String role) {
    return '$email est désormais $role.';
  }

  @override
  String get sharesMemberOfHeader => 'MEMBRE DE';

  @override
  String get sharesMemberRemoveFailed => 'Impossible de retirer le membre.';

  @override
  String get sharesMemberRemoved => 'Membre retiré.';

  @override
  String get sharesMemberRoleChangeFailed =>
      'Impossible de changer le rôle du membre.';

  @override
  String sharesMembersCount(int count) {
    return 'Membres ($count)';
  }

  @override
  String get sharesMembersLoadFailed =>
      'Impossible de charger la liste des membres.';

  @override
  String get sharesMembersLoadFailedOffline =>
      'Impossible de charger la liste des membres. Elle nécessite une connexion au serveur — réessayez une fois de retour en ligne.';

  @override
  String get sharesMembersTitle => 'Membres';

  @override
  String get sharesMismatchAcknowledge =>
      'J’ai vérifié cette nouvelle empreinte avec le destinataire par un autre canal.';

  @override
  String get sharesMoveAndShare => 'Déplacer et partager';

  @override
  String get sharesMoveAndShareTitle => 'Déplacer et partager le dossier ?';

  @override
  String get sharesMoveCheckFailed =>
      'Impossible de vérifier où se trouvent ces éléments. Vérifiez votre connexion et réessayez.';

  @override
  String sharesMoveFailed(String error) {
    return 'Échec du déplacement : $error';
  }

  @override
  String sharesMoveWillMove(String folder, String destination, String items) {
    return 'Déplacer « $folder » dans « $destination » déplacera ce dossier et ses $items.';
  }

  @override
  String sharesMoveWillShare(
    String folder,
    String destination,
    String items,
    String members,
  ) {
    return 'Déplacer « $folder » dans « $destination » partagera ce dossier et ses $items avec $members.';
  }

  @override
  String sharesMovedItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments déplacés',
      one: '$count élément déplacé',
    );
    return '$_temp0';
  }

  @override
  String sharesNamesAndOthers(String first, String second, int count) {
    return '$first, $second et $count autres';
  }

  @override
  String get sharesNewGroup => 'Nouveau groupe';

  @override
  String get sharesNewShareGroup => 'Nouveau groupe de partage';

  @override
  String get sharesNoAccessYet => 'Aucun compte n’a encore accès.';

  @override
  String get sharesNoLongerHaveAccess => 'Vous n’avez plus accès à ce dossier.';

  @override
  String get sharesNoMemberOfGroups =>
      'Personne ne vous a encore ajouté à un groupe.';

  @override
  String get sharesNoMembersYet =>
      'Aucun membre pour l’instant — ajoutez quelqu’un pour partager avec tout le groupe en une seule fois.';

  @override
  String get sharesNoOwnedGroups =>
      'Vous n’avez encore créé aucun groupe. Les groupes vous permettent de partager avec plusieurs personnes à la fois.';

  @override
  String get sharesNoUserWithEmail =>
      'Aucun compte Hoodik trouvé pour cette adresse e-mail.';

  @override
  String get sharesNotAuthenticated => 'Non authentifié.';

  @override
  String get sharesNotGroupEditor =>
      'Vous n’êtes encore éditeur d’aucun groupe. Créez un groupe ou demandez à son propriétaire de vous nommer éditeur.';

  @override
  String get sharesOnlyOwnedIntoShared =>
      'Vous ne pouvez déplacer dans un dossier partagé que des fichiers qui vous appartiennent.';

  @override
  String get sharesOnlyOwnerCanMoveOut =>
      'Seul le propriétaire peut déplacer un fichier hors d’un dossier partagé.';

  @override
  String get sharesOnlyOwnerCanMoveThisOut =>
      'Seul le propriétaire peut déplacer ce fichier hors du dossier partagé.';

  @override
  String sharesOwnedBy(String email) {
    return 'appartient à $email';
  }

  @override
  String get sharesOwnedGroupsHeader => 'VOS GROUPES';

  @override
  String get sharesOwnerCannotBeRemoved =>
      'Le propriétaire ne peut pas être retiré.';

  @override
  String get sharesPeopleWithAccess => 'Personnes ayant accès';

  @override
  String get sharesPickEditorToEnable =>
      'Choisissez Éditeur ou Copropriétaire pour activer';

  @override
  String sharesPreparingAccess(int done, int total) {
    return 'Préparation des accès ($done / $total)';
  }

  @override
  String get sharesPreviouslyTrusted => 'Empreinte que vous avez vérifiée';

  @override
  String get sharesRecipientEmailLabel => 'Adresse e-mail du destinataire';

  @override
  String get sharesRecipientsLoadFailed =>
      'Impossible de charger les destinataires existants.';

  @override
  String get sharesRefresh => 'Actualiser';

  @override
  String get sharesRemoveMember => 'Retirer le membre';

  @override
  String sharesRemoveMemberBody(String email, String name) {
    return 'Retirer $email de « $name » ? Les fichiers déjà partagés avec cette personne restent partagés ; elle ne sera simplement plus incluse la prochaine fois que vous partagerez avec ce groupe.';
  }

  @override
  String get sharesRemoveMemberTitle => 'Retirer le membre ?';

  @override
  String get sharesRenameGroup => 'Renommer le groupe';

  @override
  String sharesRenamedTo(String name) {
    return 'S’appelle désormais « $name ».';
  }

  @override
  String get sharesRevoke => 'Révoquer';

  @override
  String get sharesRevokeAccessTitle => 'Révoquer l’accès ?';

  @override
  String sharesRevokeCascadeExtra(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count partages qu’il a accordés',
      one: '$count partage qu’il a accordé',
    );
    return 'Cela supprime aussi $_temp0 en aval dans ce dossier.';
  }

  @override
  String sharesRevokeFailed(String error) {
    return 'Échec de la révocation : $error';
  }

  @override
  String sharesRevokeFileBody(String email) {
    return '$email ne pourra plus ouvrir ce fichier.';
  }

  @override
  String sharesRevokeFolderBody(String name, String folder) {
    return '$name perdra l’accès à $folder.';
  }

  @override
  String get sharesRoleCoOwner => 'Copropriétaire';

  @override
  String get sharesRoleCoOwnerDescription =>
      'Copropriétaire — peut consulter, modifier, repartager et enregistrer des copies.';

  @override
  String get sharesRoleEditor => 'Éditeur';

  @override
  String get sharesRoleEditorDescription =>
      'Éditeur — peut consulter et modifier. Pas de repartage.';

  @override
  String get sharesRoleLabel => 'Rôle';

  @override
  String get sharesRoleOwner => 'Propriétaire';

  @override
  String get sharesRoleReader => 'Lecteur';

  @override
  String get sharesRoleReaderDescription =>
      'Lecteur — peut uniquement consulter.';

  @override
  String get sharesServerReturnedNow => 'Empreinte renvoyée par le serveur';

  @override
  String get sharesSetGroupRole => 'Définir le rôle dans le groupe';

  @override
  String sharesShareFailed(String error) {
    return 'Échec du partage : $error';
  }

  @override
  String get sharesShareFileTitle => 'Partager le fichier';

  @override
  String get sharesShareFromShareMenu =>
      'Partagez un fichier avec ce groupe depuis son menu de partage.';

  @override
  String get sharesShareToGroup => 'Partager avec le groupe';

  @override
  String sharesShareToGroupFailed(String error) {
    return 'Échec du partage avec le groupe : $error';
  }

  @override
  String get sharesShareWithGroup => 'Partager avec un groupe';

  @override
  String sharesSharedWith(String email) {
    return 'Partagé avec $email';
  }

  @override
  String get sharesSharedWithGroup => 'Partagé avec le groupe.';

  @override
  String get sharesSharedWithMe => 'Partagés avec moi';

  @override
  String get sharesSharingDisabled =>
      'Le partage est désactivé sur ce serveur.';

  @override
  String sharesSubtreeTooLargeMove(int cap) {
    return 'Ce dossier contient plus de $cap fichiers. Déplacez plutôt un sous-dossier.';
  }

  @override
  String sharesSubtreeTooLargeShare(int cap) {
    return 'Ce dossier contient plus de $cap fichiers. Partagez plutôt un sous-dossier.';
  }

  @override
  String get sharesTabActivity => 'Activité';

  @override
  String get sharesTabGroups => 'Groupes';

  @override
  String get sharesTabPublicLinks => 'Liens publics';

  @override
  String get sharesTooManyLookups =>
      'Trop de recherches, réessayez dans un instant.';

  @override
  String get sharesTrustFirstSight =>
      'Premier partage avec ce compte. Comparez l’empreinte par un autre canal si vous voulez en être certain — nous vous alerterons clairement si elle change un jour.';

  @override
  String get sharesTrustMismatchBody =>
      'L’empreinte de clé de ce destinataire a changé depuis votre dernière vérification. C’est à quoi ressemble une rotation de clés légitime — et aussi exactement à quoi ressemble une attaque par substitution de clé. Le serveur ne peut pas faire la différence ; vous seul le pouvez, en vérifiant par un autre canal.';

  @override
  String get sharesTrustVerified =>
      'Vérifiée — cette empreinte correspond à celle que vous avez déjà vérifiée.';

  @override
  String sharesTwoNames(String first, String second) {
    return '$first et $second';
  }

  @override
  String get widgetDismiss => 'Ignorer';

  @override
  String widgetOutdatedServer(String version, String latest) {
    return 'Votre serveur Hoodik est en $version. Passez à la v$latest pour profiter des dernières fonctionnalités et corrections de bugs.';
  }

  @override
  String widgetOutdatedServerNoLatest(String version) {
    return 'Votre serveur Hoodik est en $version. Passez à la dernière version pour profiter des nouvelles fonctionnalités et corrections de bugs.';
  }

  @override
  String get widgetServerVersionUnknown => 'antérieure à la v1.16.0';

  @override
  String get widgetUpdate => 'Mettre à jour';

  @override
  String widgetUpdateAvailable(String version) {
    return 'Une nouvelle version de Hoodik (v$version) est disponible.';
  }

  @override
  String get widgetUpdateDownloaded =>
      'Une nouvelle version de Hoodik a été téléchargée.';

  @override
  String get widgetUpdateRestart => 'Redémarrer';
}
