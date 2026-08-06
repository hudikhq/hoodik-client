// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ServersTable extends Servers with TableInfo<$ServersTable, Server> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ServersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trustSelfSignedCertsMeta =
      const VerificationMeta('trustSelfSignedCerts');
  @override
  late final GeneratedColumn<bool> trustSelfSignedCerts = GeneratedColumn<bool>(
    'trust_self_signed_certs',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("trust_self_signed_certs" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _useHeaderAuthMeta = const VerificationMeta(
    'useHeaderAuth',
  );
  @override
  late final GeneratedColumn<bool> useHeaderAuth = GeneratedColumn<bool>(
    'use_header_auth',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("use_header_auth" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    url,
    name,
    trustSelfSignedCerts,
    useHeaderAuth,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'servers';
  @override
  VerificationContext validateIntegrity(
    Insertable<Server> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('trust_self_signed_certs')) {
      context.handle(
        _trustSelfSignedCertsMeta,
        trustSelfSignedCerts.isAcceptableOrUnknown(
          data['trust_self_signed_certs']!,
          _trustSelfSignedCertsMeta,
        ),
      );
    }
    if (data.containsKey('use_header_auth')) {
      context.handle(
        _useHeaderAuthMeta,
        useHeaderAuth.isAcceptableOrUnknown(
          data['use_header_auth']!,
          _useHeaderAuthMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Server map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Server(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      trustSelfSignedCerts: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}trust_self_signed_certs'],
      )!,
      useHeaderAuth: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}use_header_auth'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ServersTable createAlias(String alias) {
    return $ServersTable(attachedDatabase, alias);
  }
}

class Server extends DataClass implements Insertable<Server> {
  final String id;
  final String url;
  final String name;

  /// Accept the server's TLS certificate even if it's self-signed or
  /// otherwise untrusted by the OS. Useful for self-hosted instances on
  /// local networks.
  final bool trustSelfSignedCerts;

  /// Whether this server uses header-based auth (`USE_HEADERS_FOR_AUTH=true`)
  /// instead of cookies. Auto-detected on first login.
  final bool useHeaderAuth;
  final DateTime createdAt;
  const Server({
    required this.id,
    required this.url,
    required this.name,
    required this.trustSelfSignedCerts,
    required this.useHeaderAuth,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['url'] = Variable<String>(url);
    map['name'] = Variable<String>(name);
    map['trust_self_signed_certs'] = Variable<bool>(trustSelfSignedCerts);
    map['use_header_auth'] = Variable<bool>(useHeaderAuth);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ServersCompanion toCompanion(bool nullToAbsent) {
    return ServersCompanion(
      id: Value(id),
      url: Value(url),
      name: Value(name),
      trustSelfSignedCerts: Value(trustSelfSignedCerts),
      useHeaderAuth: Value(useHeaderAuth),
      createdAt: Value(createdAt),
    );
  }

  factory Server.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Server(
      id: serializer.fromJson<String>(json['id']),
      url: serializer.fromJson<String>(json['url']),
      name: serializer.fromJson<String>(json['name']),
      trustSelfSignedCerts: serializer.fromJson<bool>(
        json['trustSelfSignedCerts'],
      ),
      useHeaderAuth: serializer.fromJson<bool>(json['useHeaderAuth']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'url': serializer.toJson<String>(url),
      'name': serializer.toJson<String>(name),
      'trustSelfSignedCerts': serializer.toJson<bool>(trustSelfSignedCerts),
      'useHeaderAuth': serializer.toJson<bool>(useHeaderAuth),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Server copyWith({
    String? id,
    String? url,
    String? name,
    bool? trustSelfSignedCerts,
    bool? useHeaderAuth,
    DateTime? createdAt,
  }) => Server(
    id: id ?? this.id,
    url: url ?? this.url,
    name: name ?? this.name,
    trustSelfSignedCerts: trustSelfSignedCerts ?? this.trustSelfSignedCerts,
    useHeaderAuth: useHeaderAuth ?? this.useHeaderAuth,
    createdAt: createdAt ?? this.createdAt,
  );
  Server copyWithCompanion(ServersCompanion data) {
    return Server(
      id: data.id.present ? data.id.value : this.id,
      url: data.url.present ? data.url.value : this.url,
      name: data.name.present ? data.name.value : this.name,
      trustSelfSignedCerts: data.trustSelfSignedCerts.present
          ? data.trustSelfSignedCerts.value
          : this.trustSelfSignedCerts,
      useHeaderAuth: data.useHeaderAuth.present
          ? data.useHeaderAuth.value
          : this.useHeaderAuth,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Server(')
          ..write('id: $id, ')
          ..write('url: $url, ')
          ..write('name: $name, ')
          ..write('trustSelfSignedCerts: $trustSelfSignedCerts, ')
          ..write('useHeaderAuth: $useHeaderAuth, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    url,
    name,
    trustSelfSignedCerts,
    useHeaderAuth,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Server &&
          other.id == this.id &&
          other.url == this.url &&
          other.name == this.name &&
          other.trustSelfSignedCerts == this.trustSelfSignedCerts &&
          other.useHeaderAuth == this.useHeaderAuth &&
          other.createdAt == this.createdAt);
}

class ServersCompanion extends UpdateCompanion<Server> {
  final Value<String> id;
  final Value<String> url;
  final Value<String> name;
  final Value<bool> trustSelfSignedCerts;
  final Value<bool> useHeaderAuth;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ServersCompanion({
    this.id = const Value.absent(),
    this.url = const Value.absent(),
    this.name = const Value.absent(),
    this.trustSelfSignedCerts = const Value.absent(),
    this.useHeaderAuth = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ServersCompanion.insert({
    required String id,
    required String url,
    required String name,
    this.trustSelfSignedCerts = const Value.absent(),
    this.useHeaderAuth = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       url = Value(url),
       name = Value(name);
  static Insertable<Server> custom({
    Expression<String>? id,
    Expression<String>? url,
    Expression<String>? name,
    Expression<bool>? trustSelfSignedCerts,
    Expression<bool>? useHeaderAuth,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (url != null) 'url': url,
      if (name != null) 'name': name,
      if (trustSelfSignedCerts != null)
        'trust_self_signed_certs': trustSelfSignedCerts,
      if (useHeaderAuth != null) 'use_header_auth': useHeaderAuth,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ServersCompanion copyWith({
    Value<String>? id,
    Value<String>? url,
    Value<String>? name,
    Value<bool>? trustSelfSignedCerts,
    Value<bool>? useHeaderAuth,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ServersCompanion(
      id: id ?? this.id,
      url: url ?? this.url,
      name: name ?? this.name,
      trustSelfSignedCerts: trustSelfSignedCerts ?? this.trustSelfSignedCerts,
      useHeaderAuth: useHeaderAuth ?? this.useHeaderAuth,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (trustSelfSignedCerts.present) {
      map['trust_self_signed_certs'] = Variable<bool>(
        trustSelfSignedCerts.value,
      );
    }
    if (useHeaderAuth.present) {
      map['use_header_auth'] = Variable<bool>(useHeaderAuth.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ServersCompanion(')
          ..write('id: $id, ')
          ..write('url: $url, ')
          ..write('name: $name, ')
          ..write('trustSelfSignedCerts: $trustSelfSignedCerts, ')
          ..write('useHeaderAuth: $useHeaderAuth, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AccountsTable extends Accounts with TableInfo<$AccountsTable, Account> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES servers (id)',
    ),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fingerprintMeta = const VerificationMeta(
    'fingerprint',
  );
  @override
  late final GeneratedColumn<String> fingerprint = GeneratedColumn<String>(
    'fingerprint',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _publicKeyMeta = const VerificationMeta(
    'publicKey',
  );
  @override
  late final GeneratedColumn<String> publicKey = GeneratedColumn<String>(
    'public_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wrappingPublicKeyMeta = const VerificationMeta(
    'wrappingPublicKey',
  );
  @override
  late final GeneratedColumn<String> wrappingPublicKey =
      GeneratedColumn<String>(
        'wrapping_public_key',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _encryptedPrivateKeyMeta =
      const VerificationMeta('encryptedPrivateKey');
  @override
  late final GeneratedColumn<String> encryptedPrivateKey =
      GeneratedColumn<String>(
        'encrypted_private_key',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _pinEncryptedPrivateKeyMeta =
      const VerificationMeta('pinEncryptedPrivateKey');
  @override
  late final GeneratedColumn<String> pinEncryptedPrivateKey =
      GeneratedColumn<String>(
        'pin_encrypted_private_key',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _biometricPinMeta = const VerificationMeta(
    'biometricPin',
  );
  @override
  late final GeneratedColumn<String> biometricPin = GeneratedColumn<String>(
    'biometric_pin',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _quotaMeta = const VerificationMeta('quota');
  @override
  late final GeneratedColumn<int> quota = GeneratedColumn<int>(
    'quota',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _lastUsedAtMeta = const VerificationMeta(
    'lastUsedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastUsedAt = GeneratedColumn<DateTime>(
    'last_used_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cacheLimitBytesMeta = const VerificationMeta(
    'cacheLimitBytes',
  );
  @override
  late final GeneratedColumn<int> cacheLimitBytes = GeneratedColumn<int>(
    'cache_limit_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _headerJwtMeta = const VerificationMeta(
    'headerJwt',
  );
  @override
  late final GeneratedColumn<String> headerJwt = GeneratedColumn<String>(
    'header_jwt',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<String?, String>
  headerRefreshToken = GeneratedColumn<String>(
    'header_refresh_token',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<String?>($AccountsTable.$converterheaderRefreshToken);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverId,
    userId,
    email,
    fingerprint,
    publicKey,
    wrappingPublicKey,
    encryptedPrivateKey,
    pinEncryptedPrivateKey,
    biometricPin,
    quota,
    role,
    isActive,
    createdAt,
    lastUsedAt,
    cacheLimitBytes,
    headerJwt,
    headerRefreshToken,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Account> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    } else if (isInserting) {
      context.missing(_emailMeta);
    }
    if (data.containsKey('fingerprint')) {
      context.handle(
        _fingerprintMeta,
        fingerprint.isAcceptableOrUnknown(
          data['fingerprint']!,
          _fingerprintMeta,
        ),
      );
    }
    if (data.containsKey('public_key')) {
      context.handle(
        _publicKeyMeta,
        publicKey.isAcceptableOrUnknown(data['public_key']!, _publicKeyMeta),
      );
    }
    if (data.containsKey('wrapping_public_key')) {
      context.handle(
        _wrappingPublicKeyMeta,
        wrappingPublicKey.isAcceptableOrUnknown(
          data['wrapping_public_key']!,
          _wrappingPublicKeyMeta,
        ),
      );
    }
    if (data.containsKey('encrypted_private_key')) {
      context.handle(
        _encryptedPrivateKeyMeta,
        encryptedPrivateKey.isAcceptableOrUnknown(
          data['encrypted_private_key']!,
          _encryptedPrivateKeyMeta,
        ),
      );
    }
    if (data.containsKey('pin_encrypted_private_key')) {
      context.handle(
        _pinEncryptedPrivateKeyMeta,
        pinEncryptedPrivateKey.isAcceptableOrUnknown(
          data['pin_encrypted_private_key']!,
          _pinEncryptedPrivateKeyMeta,
        ),
      );
    }
    if (data.containsKey('biometric_pin')) {
      context.handle(
        _biometricPinMeta,
        biometricPin.isAcceptableOrUnknown(
          data['biometric_pin']!,
          _biometricPinMeta,
        ),
      );
    }
    if (data.containsKey('quota')) {
      context.handle(
        _quotaMeta,
        quota.isAcceptableOrUnknown(data['quota']!, _quotaMeta),
      );
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('last_used_at')) {
      context.handle(
        _lastUsedAtMeta,
        lastUsedAt.isAcceptableOrUnknown(
          data['last_used_at']!,
          _lastUsedAtMeta,
        ),
      );
    }
    if (data.containsKey('cache_limit_bytes')) {
      context.handle(
        _cacheLimitBytesMeta,
        cacheLimitBytes.isAcceptableOrUnknown(
          data['cache_limit_bytes']!,
          _cacheLimitBytesMeta,
        ),
      );
    }
    if (data.containsKey('header_jwt')) {
      context.handle(
        _headerJwtMeta,
        headerJwt.isAcceptableOrUnknown(data['header_jwt']!, _headerJwtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Account map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Account(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      )!,
      fingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fingerprint'],
      ),
      publicKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}public_key'],
      ),
      wrappingPublicKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wrapping_public_key'],
      ),
      encryptedPrivateKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_private_key'],
      ),
      pinEncryptedPrivateKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pin_encrypted_private_key'],
      ),
      biometricPin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}biometric_pin'],
      ),
      quota: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quota'],
      ),
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastUsedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_used_at'],
      ),
      cacheLimitBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cache_limit_bytes'],
      ),
      headerJwt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}header_jwt'],
      ),
      headerRefreshToken: $AccountsTable.$converterheaderRefreshToken.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}header_refresh_token'],
        ),
      ),
    );
  }

  @override
  $AccountsTable createAlias(String alias) {
    return $AccountsTable(attachedDatabase, alias);
  }

  static TypeConverter<String?, String?> $converterheaderRefreshToken =
      const AtRestTextConverter();
}

class Account extends DataClass implements Insertable<Account> {
  final String id;
  final String serverId;
  final String userId;
  final String email;
  final String? fingerprint;
  final String? publicKey;

  /// Hybrid wrapping public key (PEM) for curve accounts. Null for legacy
  /// RSA accounts, which wrap to [publicKey]. Encrypting a value to the
  /// account's own key (e.g. the local MCP bearer token) needs this, since the
  /// in-memory identity key of a curve account is Ed25519 and can't do RSA.
  final String? wrappingPublicKey;
  final String? encryptedPrivateKey;

  /// The private key encrypted with the user's PIN (hex string).
  /// Used for quick unlock without password.
  final String? pinEncryptedPrivateKey;

  /// The user's PIN stored for biometric unlock.
  /// When set, the unlock screen auto-prompts biometric and uses this PIN
  /// to decrypt the private key if authentication succeeds.
  final String? biometricPin;
  final int? quota;
  final String? role;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastUsedAt;

  /// Per-account offline cache size limit in bytes. `0` = unlimited.
  /// Defaults to null (use [kDefaultCacheLimitBytes]).
  final int? cacheLimitBytes;

  /// Persisted JWT for header-auth servers (survives app restart).
  final String? headerJwt;

  /// Persisted refresh token UUID for header-auth servers. Sealed at rest via
  /// [AtRestTextConverter] — a live session token is account access until it
  /// rotates, so it must not sit in plaintext in a cold copy of the database.
  final String? headerRefreshToken;
  const Account({
    required this.id,
    required this.serverId,
    required this.userId,
    required this.email,
    this.fingerprint,
    this.publicKey,
    this.wrappingPublicKey,
    this.encryptedPrivateKey,
    this.pinEncryptedPrivateKey,
    this.biometricPin,
    this.quota,
    this.role,
    required this.isActive,
    required this.createdAt,
    this.lastUsedAt,
    this.cacheLimitBytes,
    this.headerJwt,
    this.headerRefreshToken,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['server_id'] = Variable<String>(serverId);
    map['user_id'] = Variable<String>(userId);
    map['email'] = Variable<String>(email);
    if (!nullToAbsent || fingerprint != null) {
      map['fingerprint'] = Variable<String>(fingerprint);
    }
    if (!nullToAbsent || publicKey != null) {
      map['public_key'] = Variable<String>(publicKey);
    }
    if (!nullToAbsent || wrappingPublicKey != null) {
      map['wrapping_public_key'] = Variable<String>(wrappingPublicKey);
    }
    if (!nullToAbsent || encryptedPrivateKey != null) {
      map['encrypted_private_key'] = Variable<String>(encryptedPrivateKey);
    }
    if (!nullToAbsent || pinEncryptedPrivateKey != null) {
      map['pin_encrypted_private_key'] = Variable<String>(
        pinEncryptedPrivateKey,
      );
    }
    if (!nullToAbsent || biometricPin != null) {
      map['biometric_pin'] = Variable<String>(biometricPin);
    }
    if (!nullToAbsent || quota != null) {
      map['quota'] = Variable<int>(quota);
    }
    if (!nullToAbsent || role != null) {
      map['role'] = Variable<String>(role);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastUsedAt != null) {
      map['last_used_at'] = Variable<DateTime>(lastUsedAt);
    }
    if (!nullToAbsent || cacheLimitBytes != null) {
      map['cache_limit_bytes'] = Variable<int>(cacheLimitBytes);
    }
    if (!nullToAbsent || headerJwt != null) {
      map['header_jwt'] = Variable<String>(headerJwt);
    }
    if (!nullToAbsent || headerRefreshToken != null) {
      map['header_refresh_token'] = Variable<String>(
        $AccountsTable.$converterheaderRefreshToken.toSql(headerRefreshToken),
      );
    }
    return map;
  }

  AccountsCompanion toCompanion(bool nullToAbsent) {
    return AccountsCompanion(
      id: Value(id),
      serverId: Value(serverId),
      userId: Value(userId),
      email: Value(email),
      fingerprint: fingerprint == null && nullToAbsent
          ? const Value.absent()
          : Value(fingerprint),
      publicKey: publicKey == null && nullToAbsent
          ? const Value.absent()
          : Value(publicKey),
      wrappingPublicKey: wrappingPublicKey == null && nullToAbsent
          ? const Value.absent()
          : Value(wrappingPublicKey),
      encryptedPrivateKey: encryptedPrivateKey == null && nullToAbsent
          ? const Value.absent()
          : Value(encryptedPrivateKey),
      pinEncryptedPrivateKey: pinEncryptedPrivateKey == null && nullToAbsent
          ? const Value.absent()
          : Value(pinEncryptedPrivateKey),
      biometricPin: biometricPin == null && nullToAbsent
          ? const Value.absent()
          : Value(biometricPin),
      quota: quota == null && nullToAbsent
          ? const Value.absent()
          : Value(quota),
      role: role == null && nullToAbsent ? const Value.absent() : Value(role),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
      lastUsedAt: lastUsedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastUsedAt),
      cacheLimitBytes: cacheLimitBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(cacheLimitBytes),
      headerJwt: headerJwt == null && nullToAbsent
          ? const Value.absent()
          : Value(headerJwt),
      headerRefreshToken: headerRefreshToken == null && nullToAbsent
          ? const Value.absent()
          : Value(headerRefreshToken),
    );
  }

  factory Account.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Account(
      id: serializer.fromJson<String>(json['id']),
      serverId: serializer.fromJson<String>(json['serverId']),
      userId: serializer.fromJson<String>(json['userId']),
      email: serializer.fromJson<String>(json['email']),
      fingerprint: serializer.fromJson<String?>(json['fingerprint']),
      publicKey: serializer.fromJson<String?>(json['publicKey']),
      wrappingPublicKey: serializer.fromJson<String?>(
        json['wrappingPublicKey'],
      ),
      encryptedPrivateKey: serializer.fromJson<String?>(
        json['encryptedPrivateKey'],
      ),
      pinEncryptedPrivateKey: serializer.fromJson<String?>(
        json['pinEncryptedPrivateKey'],
      ),
      biometricPin: serializer.fromJson<String?>(json['biometricPin']),
      quota: serializer.fromJson<int?>(json['quota']),
      role: serializer.fromJson<String?>(json['role']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastUsedAt: serializer.fromJson<DateTime?>(json['lastUsedAt']),
      cacheLimitBytes: serializer.fromJson<int?>(json['cacheLimitBytes']),
      headerJwt: serializer.fromJson<String?>(json['headerJwt']),
      headerRefreshToken: serializer.fromJson<String?>(
        json['headerRefreshToken'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'serverId': serializer.toJson<String>(serverId),
      'userId': serializer.toJson<String>(userId),
      'email': serializer.toJson<String>(email),
      'fingerprint': serializer.toJson<String?>(fingerprint),
      'publicKey': serializer.toJson<String?>(publicKey),
      'wrappingPublicKey': serializer.toJson<String?>(wrappingPublicKey),
      'encryptedPrivateKey': serializer.toJson<String?>(encryptedPrivateKey),
      'pinEncryptedPrivateKey': serializer.toJson<String?>(
        pinEncryptedPrivateKey,
      ),
      'biometricPin': serializer.toJson<String?>(biometricPin),
      'quota': serializer.toJson<int?>(quota),
      'role': serializer.toJson<String?>(role),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastUsedAt': serializer.toJson<DateTime?>(lastUsedAt),
      'cacheLimitBytes': serializer.toJson<int?>(cacheLimitBytes),
      'headerJwt': serializer.toJson<String?>(headerJwt),
      'headerRefreshToken': serializer.toJson<String?>(headerRefreshToken),
    };
  }

  Account copyWith({
    String? id,
    String? serverId,
    String? userId,
    String? email,
    Value<String?> fingerprint = const Value.absent(),
    Value<String?> publicKey = const Value.absent(),
    Value<String?> wrappingPublicKey = const Value.absent(),
    Value<String?> encryptedPrivateKey = const Value.absent(),
    Value<String?> pinEncryptedPrivateKey = const Value.absent(),
    Value<String?> biometricPin = const Value.absent(),
    Value<int?> quota = const Value.absent(),
    Value<String?> role = const Value.absent(),
    bool? isActive,
    DateTime? createdAt,
    Value<DateTime?> lastUsedAt = const Value.absent(),
    Value<int?> cacheLimitBytes = const Value.absent(),
    Value<String?> headerJwt = const Value.absent(),
    Value<String?> headerRefreshToken = const Value.absent(),
  }) => Account(
    id: id ?? this.id,
    serverId: serverId ?? this.serverId,
    userId: userId ?? this.userId,
    email: email ?? this.email,
    fingerprint: fingerprint.present ? fingerprint.value : this.fingerprint,
    publicKey: publicKey.present ? publicKey.value : this.publicKey,
    wrappingPublicKey: wrappingPublicKey.present
        ? wrappingPublicKey.value
        : this.wrappingPublicKey,
    encryptedPrivateKey: encryptedPrivateKey.present
        ? encryptedPrivateKey.value
        : this.encryptedPrivateKey,
    pinEncryptedPrivateKey: pinEncryptedPrivateKey.present
        ? pinEncryptedPrivateKey.value
        : this.pinEncryptedPrivateKey,
    biometricPin: biometricPin.present ? biometricPin.value : this.biometricPin,
    quota: quota.present ? quota.value : this.quota,
    role: role.present ? role.value : this.role,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    lastUsedAt: lastUsedAt.present ? lastUsedAt.value : this.lastUsedAt,
    cacheLimitBytes: cacheLimitBytes.present
        ? cacheLimitBytes.value
        : this.cacheLimitBytes,
    headerJwt: headerJwt.present ? headerJwt.value : this.headerJwt,
    headerRefreshToken: headerRefreshToken.present
        ? headerRefreshToken.value
        : this.headerRefreshToken,
  );
  Account copyWithCompanion(AccountsCompanion data) {
    return Account(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      userId: data.userId.present ? data.userId.value : this.userId,
      email: data.email.present ? data.email.value : this.email,
      fingerprint: data.fingerprint.present
          ? data.fingerprint.value
          : this.fingerprint,
      publicKey: data.publicKey.present ? data.publicKey.value : this.publicKey,
      wrappingPublicKey: data.wrappingPublicKey.present
          ? data.wrappingPublicKey.value
          : this.wrappingPublicKey,
      encryptedPrivateKey: data.encryptedPrivateKey.present
          ? data.encryptedPrivateKey.value
          : this.encryptedPrivateKey,
      pinEncryptedPrivateKey: data.pinEncryptedPrivateKey.present
          ? data.pinEncryptedPrivateKey.value
          : this.pinEncryptedPrivateKey,
      biometricPin: data.biometricPin.present
          ? data.biometricPin.value
          : this.biometricPin,
      quota: data.quota.present ? data.quota.value : this.quota,
      role: data.role.present ? data.role.value : this.role,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastUsedAt: data.lastUsedAt.present
          ? data.lastUsedAt.value
          : this.lastUsedAt,
      cacheLimitBytes: data.cacheLimitBytes.present
          ? data.cacheLimitBytes.value
          : this.cacheLimitBytes,
      headerJwt: data.headerJwt.present ? data.headerJwt.value : this.headerJwt,
      headerRefreshToken: data.headerRefreshToken.present
          ? data.headerRefreshToken.value
          : this.headerRefreshToken,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Account(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('userId: $userId, ')
          ..write('email: $email, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('publicKey: $publicKey, ')
          ..write('wrappingPublicKey: $wrappingPublicKey, ')
          ..write('encryptedPrivateKey: $encryptedPrivateKey, ')
          ..write('pinEncryptedPrivateKey: $pinEncryptedPrivateKey, ')
          ..write('biometricPin: $biometricPin, ')
          ..write('quota: $quota, ')
          ..write('role: $role, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastUsedAt: $lastUsedAt, ')
          ..write('cacheLimitBytes: $cacheLimitBytes, ')
          ..write('headerJwt: $headerJwt, ')
          ..write('headerRefreshToken: $headerRefreshToken')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    serverId,
    userId,
    email,
    fingerprint,
    publicKey,
    wrappingPublicKey,
    encryptedPrivateKey,
    pinEncryptedPrivateKey,
    biometricPin,
    quota,
    role,
    isActive,
    createdAt,
    lastUsedAt,
    cacheLimitBytes,
    headerJwt,
    headerRefreshToken,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Account &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.userId == this.userId &&
          other.email == this.email &&
          other.fingerprint == this.fingerprint &&
          other.publicKey == this.publicKey &&
          other.wrappingPublicKey == this.wrappingPublicKey &&
          other.encryptedPrivateKey == this.encryptedPrivateKey &&
          other.pinEncryptedPrivateKey == this.pinEncryptedPrivateKey &&
          other.biometricPin == this.biometricPin &&
          other.quota == this.quota &&
          other.role == this.role &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt &&
          other.lastUsedAt == this.lastUsedAt &&
          other.cacheLimitBytes == this.cacheLimitBytes &&
          other.headerJwt == this.headerJwt &&
          other.headerRefreshToken == this.headerRefreshToken);
}

class AccountsCompanion extends UpdateCompanion<Account> {
  final Value<String> id;
  final Value<String> serverId;
  final Value<String> userId;
  final Value<String> email;
  final Value<String?> fingerprint;
  final Value<String?> publicKey;
  final Value<String?> wrappingPublicKey;
  final Value<String?> encryptedPrivateKey;
  final Value<String?> pinEncryptedPrivateKey;
  final Value<String?> biometricPin;
  final Value<int?> quota;
  final Value<String?> role;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  final Value<DateTime?> lastUsedAt;
  final Value<int?> cacheLimitBytes;
  final Value<String?> headerJwt;
  final Value<String?> headerRefreshToken;
  final Value<int> rowid;
  const AccountsCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.userId = const Value.absent(),
    this.email = const Value.absent(),
    this.fingerprint = const Value.absent(),
    this.publicKey = const Value.absent(),
    this.wrappingPublicKey = const Value.absent(),
    this.encryptedPrivateKey = const Value.absent(),
    this.pinEncryptedPrivateKey = const Value.absent(),
    this.biometricPin = const Value.absent(),
    this.quota = const Value.absent(),
    this.role = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastUsedAt = const Value.absent(),
    this.cacheLimitBytes = const Value.absent(),
    this.headerJwt = const Value.absent(),
    this.headerRefreshToken = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AccountsCompanion.insert({
    required String id,
    required String serverId,
    required String userId,
    required String email,
    this.fingerprint = const Value.absent(),
    this.publicKey = const Value.absent(),
    this.wrappingPublicKey = const Value.absent(),
    this.encryptedPrivateKey = const Value.absent(),
    this.pinEncryptedPrivateKey = const Value.absent(),
    this.biometricPin = const Value.absent(),
    this.quota = const Value.absent(),
    this.role = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastUsedAt = const Value.absent(),
    this.cacheLimitBytes = const Value.absent(),
    this.headerJwt = const Value.absent(),
    this.headerRefreshToken = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       serverId = Value(serverId),
       userId = Value(userId),
       email = Value(email);
  static Insertable<Account> custom({
    Expression<String>? id,
    Expression<String>? serverId,
    Expression<String>? userId,
    Expression<String>? email,
    Expression<String>? fingerprint,
    Expression<String>? publicKey,
    Expression<String>? wrappingPublicKey,
    Expression<String>? encryptedPrivateKey,
    Expression<String>? pinEncryptedPrivateKey,
    Expression<String>? biometricPin,
    Expression<int>? quota,
    Expression<String>? role,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastUsedAt,
    Expression<int>? cacheLimitBytes,
    Expression<String>? headerJwt,
    Expression<String>? headerRefreshToken,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (userId != null) 'user_id': userId,
      if (email != null) 'email': email,
      if (fingerprint != null) 'fingerprint': fingerprint,
      if (publicKey != null) 'public_key': publicKey,
      if (wrappingPublicKey != null) 'wrapping_public_key': wrappingPublicKey,
      if (encryptedPrivateKey != null)
        'encrypted_private_key': encryptedPrivateKey,
      if (pinEncryptedPrivateKey != null)
        'pin_encrypted_private_key': pinEncryptedPrivateKey,
      if (biometricPin != null) 'biometric_pin': biometricPin,
      if (quota != null) 'quota': quota,
      if (role != null) 'role': role,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (lastUsedAt != null) 'last_used_at': lastUsedAt,
      if (cacheLimitBytes != null) 'cache_limit_bytes': cacheLimitBytes,
      if (headerJwt != null) 'header_jwt': headerJwt,
      if (headerRefreshToken != null)
        'header_refresh_token': headerRefreshToken,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AccountsCompanion copyWith({
    Value<String>? id,
    Value<String>? serverId,
    Value<String>? userId,
    Value<String>? email,
    Value<String?>? fingerprint,
    Value<String?>? publicKey,
    Value<String?>? wrappingPublicKey,
    Value<String?>? encryptedPrivateKey,
    Value<String?>? pinEncryptedPrivateKey,
    Value<String?>? biometricPin,
    Value<int?>? quota,
    Value<String?>? role,
    Value<bool>? isActive,
    Value<DateTime>? createdAt,
    Value<DateTime?>? lastUsedAt,
    Value<int?>? cacheLimitBytes,
    Value<String?>? headerJwt,
    Value<String?>? headerRefreshToken,
    Value<int>? rowid,
  }) {
    return AccountsCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      fingerprint: fingerprint ?? this.fingerprint,
      publicKey: publicKey ?? this.publicKey,
      wrappingPublicKey: wrappingPublicKey ?? this.wrappingPublicKey,
      encryptedPrivateKey: encryptedPrivateKey ?? this.encryptedPrivateKey,
      pinEncryptedPrivateKey:
          pinEncryptedPrivateKey ?? this.pinEncryptedPrivateKey,
      biometricPin: biometricPin ?? this.biometricPin,
      quota: quota ?? this.quota,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      cacheLimitBytes: cacheLimitBytes ?? this.cacheLimitBytes,
      headerJwt: headerJwt ?? this.headerJwt,
      headerRefreshToken: headerRefreshToken ?? this.headerRefreshToken,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (fingerprint.present) {
      map['fingerprint'] = Variable<String>(fingerprint.value);
    }
    if (publicKey.present) {
      map['public_key'] = Variable<String>(publicKey.value);
    }
    if (wrappingPublicKey.present) {
      map['wrapping_public_key'] = Variable<String>(wrappingPublicKey.value);
    }
    if (encryptedPrivateKey.present) {
      map['encrypted_private_key'] = Variable<String>(
        encryptedPrivateKey.value,
      );
    }
    if (pinEncryptedPrivateKey.present) {
      map['pin_encrypted_private_key'] = Variable<String>(
        pinEncryptedPrivateKey.value,
      );
    }
    if (biometricPin.present) {
      map['biometric_pin'] = Variable<String>(biometricPin.value);
    }
    if (quota.present) {
      map['quota'] = Variable<int>(quota.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastUsedAt.present) {
      map['last_used_at'] = Variable<DateTime>(lastUsedAt.value);
    }
    if (cacheLimitBytes.present) {
      map['cache_limit_bytes'] = Variable<int>(cacheLimitBytes.value);
    }
    if (headerJwt.present) {
      map['header_jwt'] = Variable<String>(headerJwt.value);
    }
    if (headerRefreshToken.present) {
      map['header_refresh_token'] = Variable<String>(
        $AccountsTable.$converterheaderRefreshToken.toSql(
          headerRefreshToken.value,
        ),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountsCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('userId: $userId, ')
          ..write('email: $email, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('publicKey: $publicKey, ')
          ..write('wrappingPublicKey: $wrappingPublicKey, ')
          ..write('encryptedPrivateKey: $encryptedPrivateKey, ')
          ..write('pinEncryptedPrivateKey: $pinEncryptedPrivateKey, ')
          ..write('biometricPin: $biometricPin, ')
          ..write('quota: $quota, ')
          ..write('role: $role, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastUsedAt: $lastUsedAt, ')
          ..write('cacheLimitBytes: $cacheLimitBytes, ')
          ..write('headerJwt: $headerJwt, ')
          ..write('headerRefreshToken: $headerRefreshToken, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedFilesTable extends CachedFiles
    with TableInfo<$CachedFilesTable, CachedFile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedFilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id)',
    ),
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dirIdMeta = const VerificationMeta('dirId');
  @override
  late final GeneratedColumn<String> dirId = GeneratedColumn<String>(
    'dir_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _encryptedNameMeta = const VerificationMeta(
    'encryptedName',
  );
  @override
  late final GeneratedColumn<String> encryptedName = GeneratedColumn<String>(
    'encrypted_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<String?, String> decryptedName =
      GeneratedColumn<String>(
        'decrypted_name',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<String?>($CachedFilesTable.$converterdecryptedName);
  static const VerificationMeta _encryptedKeyMeta = const VerificationMeta(
    'encryptedKey',
  );
  @override
  late final GeneratedColumn<String> encryptedKey = GeneratedColumn<String>(
    'encrypted_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _encryptedThumbnailMeta =
      const VerificationMeta('encryptedThumbnail');
  @override
  late final GeneratedColumn<String> encryptedThumbnail =
      GeneratedColumn<String>(
        'encrypted_thumbnail',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _mimeMeta = const VerificationMeta('mime');
  @override
  late final GeneratedColumn<String> mime = GeneratedColumn<String>(
    'mime',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _chunksMeta = const VerificationMeta('chunks');
  @override
  late final GeneratedColumn<int> chunks = GeneratedColumn<int>(
    'chunks',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _chunksStoredMeta = const VerificationMeta(
    'chunksStored',
  );
  @override
  late final GeneratedColumn<int> chunksStored = GeneratedColumn<int>(
    'chunks_stored',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cipherMeta = const VerificationMeta('cipher');
  @override
  late final GeneratedColumn<String> cipher = GeneratedColumn<String>(
    'cipher',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('aegis128l'),
  );
  static const VerificationMeta _fileModifiedAtMeta = const VerificationMeta(
    'fileModifiedAt',
  );
  @override
  late final GeneratedColumn<int> fileModifiedAt = GeneratedColumn<int>(
    'file_modified_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _finishedUploadAtMeta = const VerificationMeta(
    'finishedUploadAt',
  );
  @override
  late final GeneratedColumn<int> finishedUploadAt = GeneratedColumn<int>(
    'finished_upload_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<CachePolicyType, String>
  cachePolicy = GeneratedColumn<String>(
    'cache_policy',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(CachePolicyType.auto.name),
  ).withConverter<CachePolicyType>($CachedFilesTable.$convertercachePolicy);
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    accountId,
    id,
    dirId,
    encryptedName,
    decryptedName,
    encryptedKey,
    encryptedThumbnail,
    mime,
    size,
    chunks,
    chunksStored,
    cipher,
    fileModifiedAt,
    createdAt,
    finishedUploadAt,
    cachePolicy,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_files';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedFile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('dir_id')) {
      context.handle(
        _dirIdMeta,
        dirId.isAcceptableOrUnknown(data['dir_id']!, _dirIdMeta),
      );
    }
    if (data.containsKey('encrypted_name')) {
      context.handle(
        _encryptedNameMeta,
        encryptedName.isAcceptableOrUnknown(
          data['encrypted_name']!,
          _encryptedNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_encryptedNameMeta);
    }
    if (data.containsKey('encrypted_key')) {
      context.handle(
        _encryptedKeyMeta,
        encryptedKey.isAcceptableOrUnknown(
          data['encrypted_key']!,
          _encryptedKeyMeta,
        ),
      );
    }
    if (data.containsKey('encrypted_thumbnail')) {
      context.handle(
        _encryptedThumbnailMeta,
        encryptedThumbnail.isAcceptableOrUnknown(
          data['encrypted_thumbnail']!,
          _encryptedThumbnailMeta,
        ),
      );
    }
    if (data.containsKey('mime')) {
      context.handle(
        _mimeMeta,
        mime.isAcceptableOrUnknown(data['mime']!, _mimeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeMeta);
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    }
    if (data.containsKey('chunks')) {
      context.handle(
        _chunksMeta,
        chunks.isAcceptableOrUnknown(data['chunks']!, _chunksMeta),
      );
    }
    if (data.containsKey('chunks_stored')) {
      context.handle(
        _chunksStoredMeta,
        chunksStored.isAcceptableOrUnknown(
          data['chunks_stored']!,
          _chunksStoredMeta,
        ),
      );
    }
    if (data.containsKey('cipher')) {
      context.handle(
        _cipherMeta,
        cipher.isAcceptableOrUnknown(data['cipher']!, _cipherMeta),
      );
    }
    if (data.containsKey('file_modified_at')) {
      context.handle(
        _fileModifiedAtMeta,
        fileModifiedAt.isAcceptableOrUnknown(
          data['file_modified_at']!,
          _fileModifiedAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('finished_upload_at')) {
      context.handle(
        _finishedUploadAtMeta,
        finishedUploadAt.isAcceptableOrUnknown(
          data['finished_upload_at']!,
          _finishedUploadAtMeta,
        ),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId, id};
  @override
  CachedFile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedFile(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      dirId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dir_id'],
      ),
      encryptedName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_name'],
      )!,
      decryptedName: $CachedFilesTable.$converterdecryptedName.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}decrypted_name'],
        ),
      ),
      encryptedKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_key'],
      ),
      encryptedThumbnail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_thumbnail'],
      ),
      mime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      ),
      chunks: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chunks'],
      ),
      chunksStored: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chunks_stored'],
      ),
      cipher: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cipher'],
      )!,
      fileModifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_modified_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      ),
      finishedUploadAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}finished_upload_at'],
      ),
      cachePolicy: $CachedFilesTable.$convertercachePolicy.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}cache_policy'],
        )!,
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $CachedFilesTable createAlias(String alias) {
    return $CachedFilesTable(attachedDatabase, alias);
  }

  static TypeConverter<String?, String?> $converterdecryptedName =
      const AtRestTextConverter();
  static JsonTypeConverter2<CachePolicyType, String, String>
  $convertercachePolicy = const EnumNameConverter<CachePolicyType>(
    CachePolicyType.values,
  );
}

class CachedFile extends DataClass implements Insertable<CachedFile> {
  final String accountId;
  final String id;
  final String? dirId;
  final String encryptedName;

  /// Decrypted file name, cached for display. Sealed at rest via
  /// [AtRestTextConverter] so a cold copy of the database never reveals the
  /// plaintext names of cached files.
  final String? decryptedName;
  final String? encryptedKey;
  final String? encryptedThumbnail;
  final String mime;
  final int? size;
  final int? chunks;
  final int? chunksStored;
  final String cipher;
  final int? fileModifiedAt;
  final int? createdAt;
  final int? finishedUploadAt;
  final CachePolicyType cachePolicy;
  final DateTime? syncedAt;
  const CachedFile({
    required this.accountId,
    required this.id,
    this.dirId,
    required this.encryptedName,
    this.decryptedName,
    this.encryptedKey,
    this.encryptedThumbnail,
    required this.mime,
    this.size,
    this.chunks,
    this.chunksStored,
    required this.cipher,
    this.fileModifiedAt,
    this.createdAt,
    this.finishedUploadAt,
    required this.cachePolicy,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || dirId != null) {
      map['dir_id'] = Variable<String>(dirId);
    }
    map['encrypted_name'] = Variable<String>(encryptedName);
    if (!nullToAbsent || decryptedName != null) {
      map['decrypted_name'] = Variable<String>(
        $CachedFilesTable.$converterdecryptedName.toSql(decryptedName),
      );
    }
    if (!nullToAbsent || encryptedKey != null) {
      map['encrypted_key'] = Variable<String>(encryptedKey);
    }
    if (!nullToAbsent || encryptedThumbnail != null) {
      map['encrypted_thumbnail'] = Variable<String>(encryptedThumbnail);
    }
    map['mime'] = Variable<String>(mime);
    if (!nullToAbsent || size != null) {
      map['size'] = Variable<int>(size);
    }
    if (!nullToAbsent || chunks != null) {
      map['chunks'] = Variable<int>(chunks);
    }
    if (!nullToAbsent || chunksStored != null) {
      map['chunks_stored'] = Variable<int>(chunksStored);
    }
    map['cipher'] = Variable<String>(cipher);
    if (!nullToAbsent || fileModifiedAt != null) {
      map['file_modified_at'] = Variable<int>(fileModifiedAt);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<int>(createdAt);
    }
    if (!nullToAbsent || finishedUploadAt != null) {
      map['finished_upload_at'] = Variable<int>(finishedUploadAt);
    }
    {
      map['cache_policy'] = Variable<String>(
        $CachedFilesTable.$convertercachePolicy.toSql(cachePolicy),
      );
    }
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  CachedFilesCompanion toCompanion(bool nullToAbsent) {
    return CachedFilesCompanion(
      accountId: Value(accountId),
      id: Value(id),
      dirId: dirId == null && nullToAbsent
          ? const Value.absent()
          : Value(dirId),
      encryptedName: Value(encryptedName),
      decryptedName: decryptedName == null && nullToAbsent
          ? const Value.absent()
          : Value(decryptedName),
      encryptedKey: encryptedKey == null && nullToAbsent
          ? const Value.absent()
          : Value(encryptedKey),
      encryptedThumbnail: encryptedThumbnail == null && nullToAbsent
          ? const Value.absent()
          : Value(encryptedThumbnail),
      mime: Value(mime),
      size: size == null && nullToAbsent ? const Value.absent() : Value(size),
      chunks: chunks == null && nullToAbsent
          ? const Value.absent()
          : Value(chunks),
      chunksStored: chunksStored == null && nullToAbsent
          ? const Value.absent()
          : Value(chunksStored),
      cipher: Value(cipher),
      fileModifiedAt: fileModifiedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(fileModifiedAt),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      finishedUploadAt: finishedUploadAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedUploadAt),
      cachePolicy: Value(cachePolicy),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory CachedFile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedFile(
      accountId: serializer.fromJson<String>(json['accountId']),
      id: serializer.fromJson<String>(json['id']),
      dirId: serializer.fromJson<String?>(json['dirId']),
      encryptedName: serializer.fromJson<String>(json['encryptedName']),
      decryptedName: serializer.fromJson<String?>(json['decryptedName']),
      encryptedKey: serializer.fromJson<String?>(json['encryptedKey']),
      encryptedThumbnail: serializer.fromJson<String?>(
        json['encryptedThumbnail'],
      ),
      mime: serializer.fromJson<String>(json['mime']),
      size: serializer.fromJson<int?>(json['size']),
      chunks: serializer.fromJson<int?>(json['chunks']),
      chunksStored: serializer.fromJson<int?>(json['chunksStored']),
      cipher: serializer.fromJson<String>(json['cipher']),
      fileModifiedAt: serializer.fromJson<int?>(json['fileModifiedAt']),
      createdAt: serializer.fromJson<int?>(json['createdAt']),
      finishedUploadAt: serializer.fromJson<int?>(json['finishedUploadAt']),
      cachePolicy: $CachedFilesTable.$convertercachePolicy.fromJson(
        serializer.fromJson<String>(json['cachePolicy']),
      ),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'id': serializer.toJson<String>(id),
      'dirId': serializer.toJson<String?>(dirId),
      'encryptedName': serializer.toJson<String>(encryptedName),
      'decryptedName': serializer.toJson<String?>(decryptedName),
      'encryptedKey': serializer.toJson<String?>(encryptedKey),
      'encryptedThumbnail': serializer.toJson<String?>(encryptedThumbnail),
      'mime': serializer.toJson<String>(mime),
      'size': serializer.toJson<int?>(size),
      'chunks': serializer.toJson<int?>(chunks),
      'chunksStored': serializer.toJson<int?>(chunksStored),
      'cipher': serializer.toJson<String>(cipher),
      'fileModifiedAt': serializer.toJson<int?>(fileModifiedAt),
      'createdAt': serializer.toJson<int?>(createdAt),
      'finishedUploadAt': serializer.toJson<int?>(finishedUploadAt),
      'cachePolicy': serializer.toJson<String>(
        $CachedFilesTable.$convertercachePolicy.toJson(cachePolicy),
      ),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  CachedFile copyWith({
    String? accountId,
    String? id,
    Value<String?> dirId = const Value.absent(),
    String? encryptedName,
    Value<String?> decryptedName = const Value.absent(),
    Value<String?> encryptedKey = const Value.absent(),
    Value<String?> encryptedThumbnail = const Value.absent(),
    String? mime,
    Value<int?> size = const Value.absent(),
    Value<int?> chunks = const Value.absent(),
    Value<int?> chunksStored = const Value.absent(),
    String? cipher,
    Value<int?> fileModifiedAt = const Value.absent(),
    Value<int?> createdAt = const Value.absent(),
    Value<int?> finishedUploadAt = const Value.absent(),
    CachePolicyType? cachePolicy,
    Value<DateTime?> syncedAt = const Value.absent(),
  }) => CachedFile(
    accountId: accountId ?? this.accountId,
    id: id ?? this.id,
    dirId: dirId.present ? dirId.value : this.dirId,
    encryptedName: encryptedName ?? this.encryptedName,
    decryptedName: decryptedName.present
        ? decryptedName.value
        : this.decryptedName,
    encryptedKey: encryptedKey.present ? encryptedKey.value : this.encryptedKey,
    encryptedThumbnail: encryptedThumbnail.present
        ? encryptedThumbnail.value
        : this.encryptedThumbnail,
    mime: mime ?? this.mime,
    size: size.present ? size.value : this.size,
    chunks: chunks.present ? chunks.value : this.chunks,
    chunksStored: chunksStored.present ? chunksStored.value : this.chunksStored,
    cipher: cipher ?? this.cipher,
    fileModifiedAt: fileModifiedAt.present
        ? fileModifiedAt.value
        : this.fileModifiedAt,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    finishedUploadAt: finishedUploadAt.present
        ? finishedUploadAt.value
        : this.finishedUploadAt,
    cachePolicy: cachePolicy ?? this.cachePolicy,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  CachedFile copyWithCompanion(CachedFilesCompanion data) {
    return CachedFile(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      id: data.id.present ? data.id.value : this.id,
      dirId: data.dirId.present ? data.dirId.value : this.dirId,
      encryptedName: data.encryptedName.present
          ? data.encryptedName.value
          : this.encryptedName,
      decryptedName: data.decryptedName.present
          ? data.decryptedName.value
          : this.decryptedName,
      encryptedKey: data.encryptedKey.present
          ? data.encryptedKey.value
          : this.encryptedKey,
      encryptedThumbnail: data.encryptedThumbnail.present
          ? data.encryptedThumbnail.value
          : this.encryptedThumbnail,
      mime: data.mime.present ? data.mime.value : this.mime,
      size: data.size.present ? data.size.value : this.size,
      chunks: data.chunks.present ? data.chunks.value : this.chunks,
      chunksStored: data.chunksStored.present
          ? data.chunksStored.value
          : this.chunksStored,
      cipher: data.cipher.present ? data.cipher.value : this.cipher,
      fileModifiedAt: data.fileModifiedAt.present
          ? data.fileModifiedAt.value
          : this.fileModifiedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      finishedUploadAt: data.finishedUploadAt.present
          ? data.finishedUploadAt.value
          : this.finishedUploadAt,
      cachePolicy: data.cachePolicy.present
          ? data.cachePolicy.value
          : this.cachePolicy,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedFile(')
          ..write('accountId: $accountId, ')
          ..write('id: $id, ')
          ..write('dirId: $dirId, ')
          ..write('encryptedName: $encryptedName, ')
          ..write('decryptedName: $decryptedName, ')
          ..write('encryptedKey: $encryptedKey, ')
          ..write('encryptedThumbnail: $encryptedThumbnail, ')
          ..write('mime: $mime, ')
          ..write('size: $size, ')
          ..write('chunks: $chunks, ')
          ..write('chunksStored: $chunksStored, ')
          ..write('cipher: $cipher, ')
          ..write('fileModifiedAt: $fileModifiedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('finishedUploadAt: $finishedUploadAt, ')
          ..write('cachePolicy: $cachePolicy, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    accountId,
    id,
    dirId,
    encryptedName,
    decryptedName,
    encryptedKey,
    encryptedThumbnail,
    mime,
    size,
    chunks,
    chunksStored,
    cipher,
    fileModifiedAt,
    createdAt,
    finishedUploadAt,
    cachePolicy,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedFile &&
          other.accountId == this.accountId &&
          other.id == this.id &&
          other.dirId == this.dirId &&
          other.encryptedName == this.encryptedName &&
          other.decryptedName == this.decryptedName &&
          other.encryptedKey == this.encryptedKey &&
          other.encryptedThumbnail == this.encryptedThumbnail &&
          other.mime == this.mime &&
          other.size == this.size &&
          other.chunks == this.chunks &&
          other.chunksStored == this.chunksStored &&
          other.cipher == this.cipher &&
          other.fileModifiedAt == this.fileModifiedAt &&
          other.createdAt == this.createdAt &&
          other.finishedUploadAt == this.finishedUploadAt &&
          other.cachePolicy == this.cachePolicy &&
          other.syncedAt == this.syncedAt);
}

class CachedFilesCompanion extends UpdateCompanion<CachedFile> {
  final Value<String> accountId;
  final Value<String> id;
  final Value<String?> dirId;
  final Value<String> encryptedName;
  final Value<String?> decryptedName;
  final Value<String?> encryptedKey;
  final Value<String?> encryptedThumbnail;
  final Value<String> mime;
  final Value<int?> size;
  final Value<int?> chunks;
  final Value<int?> chunksStored;
  final Value<String> cipher;
  final Value<int?> fileModifiedAt;
  final Value<int?> createdAt;
  final Value<int?> finishedUploadAt;
  final Value<CachePolicyType> cachePolicy;
  final Value<DateTime?> syncedAt;
  final Value<int> rowid;
  const CachedFilesCompanion({
    this.accountId = const Value.absent(),
    this.id = const Value.absent(),
    this.dirId = const Value.absent(),
    this.encryptedName = const Value.absent(),
    this.decryptedName = const Value.absent(),
    this.encryptedKey = const Value.absent(),
    this.encryptedThumbnail = const Value.absent(),
    this.mime = const Value.absent(),
    this.size = const Value.absent(),
    this.chunks = const Value.absent(),
    this.chunksStored = const Value.absent(),
    this.cipher = const Value.absent(),
    this.fileModifiedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.finishedUploadAt = const Value.absent(),
    this.cachePolicy = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedFilesCompanion.insert({
    required String accountId,
    required String id,
    this.dirId = const Value.absent(),
    required String encryptedName,
    this.decryptedName = const Value.absent(),
    this.encryptedKey = const Value.absent(),
    this.encryptedThumbnail = const Value.absent(),
    required String mime,
    this.size = const Value.absent(),
    this.chunks = const Value.absent(),
    this.chunksStored = const Value.absent(),
    this.cipher = const Value.absent(),
    this.fileModifiedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.finishedUploadAt = const Value.absent(),
    this.cachePolicy = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       id = Value(id),
       encryptedName = Value(encryptedName),
       mime = Value(mime);
  static Insertable<CachedFile> custom({
    Expression<String>? accountId,
    Expression<String>? id,
    Expression<String>? dirId,
    Expression<String>? encryptedName,
    Expression<String>? decryptedName,
    Expression<String>? encryptedKey,
    Expression<String>? encryptedThumbnail,
    Expression<String>? mime,
    Expression<int>? size,
    Expression<int>? chunks,
    Expression<int>? chunksStored,
    Expression<String>? cipher,
    Expression<int>? fileModifiedAt,
    Expression<int>? createdAt,
    Expression<int>? finishedUploadAt,
    Expression<String>? cachePolicy,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (id != null) 'id': id,
      if (dirId != null) 'dir_id': dirId,
      if (encryptedName != null) 'encrypted_name': encryptedName,
      if (decryptedName != null) 'decrypted_name': decryptedName,
      if (encryptedKey != null) 'encrypted_key': encryptedKey,
      if (encryptedThumbnail != null) 'encrypted_thumbnail': encryptedThumbnail,
      if (mime != null) 'mime': mime,
      if (size != null) 'size': size,
      if (chunks != null) 'chunks': chunks,
      if (chunksStored != null) 'chunks_stored': chunksStored,
      if (cipher != null) 'cipher': cipher,
      if (fileModifiedAt != null) 'file_modified_at': fileModifiedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (finishedUploadAt != null) 'finished_upload_at': finishedUploadAt,
      if (cachePolicy != null) 'cache_policy': cachePolicy,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedFilesCompanion copyWith({
    Value<String>? accountId,
    Value<String>? id,
    Value<String?>? dirId,
    Value<String>? encryptedName,
    Value<String?>? decryptedName,
    Value<String?>? encryptedKey,
    Value<String?>? encryptedThumbnail,
    Value<String>? mime,
    Value<int?>? size,
    Value<int?>? chunks,
    Value<int?>? chunksStored,
    Value<String>? cipher,
    Value<int?>? fileModifiedAt,
    Value<int?>? createdAt,
    Value<int?>? finishedUploadAt,
    Value<CachePolicyType>? cachePolicy,
    Value<DateTime?>? syncedAt,
    Value<int>? rowid,
  }) {
    return CachedFilesCompanion(
      accountId: accountId ?? this.accountId,
      id: id ?? this.id,
      dirId: dirId ?? this.dirId,
      encryptedName: encryptedName ?? this.encryptedName,
      decryptedName: decryptedName ?? this.decryptedName,
      encryptedKey: encryptedKey ?? this.encryptedKey,
      encryptedThumbnail: encryptedThumbnail ?? this.encryptedThumbnail,
      mime: mime ?? this.mime,
      size: size ?? this.size,
      chunks: chunks ?? this.chunks,
      chunksStored: chunksStored ?? this.chunksStored,
      cipher: cipher ?? this.cipher,
      fileModifiedAt: fileModifiedAt ?? this.fileModifiedAt,
      createdAt: createdAt ?? this.createdAt,
      finishedUploadAt: finishedUploadAt ?? this.finishedUploadAt,
      cachePolicy: cachePolicy ?? this.cachePolicy,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (dirId.present) {
      map['dir_id'] = Variable<String>(dirId.value);
    }
    if (encryptedName.present) {
      map['encrypted_name'] = Variable<String>(encryptedName.value);
    }
    if (decryptedName.present) {
      map['decrypted_name'] = Variable<String>(
        $CachedFilesTable.$converterdecryptedName.toSql(decryptedName.value),
      );
    }
    if (encryptedKey.present) {
      map['encrypted_key'] = Variable<String>(encryptedKey.value);
    }
    if (encryptedThumbnail.present) {
      map['encrypted_thumbnail'] = Variable<String>(encryptedThumbnail.value);
    }
    if (mime.present) {
      map['mime'] = Variable<String>(mime.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (chunks.present) {
      map['chunks'] = Variable<int>(chunks.value);
    }
    if (chunksStored.present) {
      map['chunks_stored'] = Variable<int>(chunksStored.value);
    }
    if (cipher.present) {
      map['cipher'] = Variable<String>(cipher.value);
    }
    if (fileModifiedAt.present) {
      map['file_modified_at'] = Variable<int>(fileModifiedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (finishedUploadAt.present) {
      map['finished_upload_at'] = Variable<int>(finishedUploadAt.value);
    }
    if (cachePolicy.present) {
      map['cache_policy'] = Variable<String>(
        $CachedFilesTable.$convertercachePolicy.toSql(cachePolicy.value),
      );
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedFilesCompanion(')
          ..write('accountId: $accountId, ')
          ..write('id: $id, ')
          ..write('dirId: $dirId, ')
          ..write('encryptedName: $encryptedName, ')
          ..write('decryptedName: $decryptedName, ')
          ..write('encryptedKey: $encryptedKey, ')
          ..write('encryptedThumbnail: $encryptedThumbnail, ')
          ..write('mime: $mime, ')
          ..write('size: $size, ')
          ..write('chunks: $chunks, ')
          ..write('chunksStored: $chunksStored, ')
          ..write('cipher: $cipher, ')
          ..write('fileModifiedAt: $fileModifiedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('finishedUploadAt: $finishedUploadAt, ')
          ..write('cachePolicy: $cachePolicy, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OfflineFilesTable extends OfflineFiles
    with TableInfo<$OfflineFilesTable, OfflineFile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OfflineFilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileIdMeta = const VerificationMeta('fileId');
  @override
  late final GeneratedColumn<String> fileId = GeneratedColumn<String>(
    'file_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeOnDiskMeta = const VerificationMeta(
    'sizeOnDisk',
  );
  @override
  late final GeneratedColumn<int> sizeOnDisk = GeneratedColumn<int>(
    'size_on_disk',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pinnedMeta = const VerificationMeta('pinned');
  @override
  late final GeneratedColumn<bool> pinned = GeneratedColumn<bool>(
    'pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _downloadedAtMeta = const VerificationMeta(
    'downloadedAt',
  );
  @override
  late final GeneratedColumn<DateTime> downloadedAt = GeneratedColumn<DateTime>(
    'downloaded_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _lastAccessedAtMeta = const VerificationMeta(
    'lastAccessedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAccessedAt =
      GeneratedColumn<DateTime>(
        'last_accessed_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
        defaultValue: currentDateAndTime,
      );
  @override
  List<GeneratedColumn> get $columns => [
    accountId,
    fileId,
    localPath,
    sizeOnDisk,
    pinned,
    downloadedAt,
    lastAccessedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'offline_files';
  @override
  VerificationContext validateIntegrity(
    Insertable<OfflineFile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('file_id')) {
      context.handle(
        _fileIdMeta,
        fileId.isAcceptableOrUnknown(data['file_id']!, _fileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_fileIdMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    } else if (isInserting) {
      context.missing(_localPathMeta);
    }
    if (data.containsKey('size_on_disk')) {
      context.handle(
        _sizeOnDiskMeta,
        sizeOnDisk.isAcceptableOrUnknown(
          data['size_on_disk']!,
          _sizeOnDiskMeta,
        ),
      );
    }
    if (data.containsKey('pinned')) {
      context.handle(
        _pinnedMeta,
        pinned.isAcceptableOrUnknown(data['pinned']!, _pinnedMeta),
      );
    }
    if (data.containsKey('downloaded_at')) {
      context.handle(
        _downloadedAtMeta,
        downloadedAt.isAcceptableOrUnknown(
          data['downloaded_at']!,
          _downloadedAtMeta,
        ),
      );
    }
    if (data.containsKey('last_accessed_at')) {
      context.handle(
        _lastAccessedAtMeta,
        lastAccessedAt.isAcceptableOrUnknown(
          data['last_accessed_at']!,
          _lastAccessedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId, fileId};
  @override
  OfflineFile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OfflineFile(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      fileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_id'],
      )!,
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      )!,
      sizeOnDisk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_on_disk'],
      )!,
      pinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pinned'],
      )!,
      downloadedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}downloaded_at'],
      )!,
      lastAccessedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_accessed_at'],
      )!,
    );
  }

  @override
  $OfflineFilesTable createAlias(String alias) {
    return $OfflineFilesTable(attachedDatabase, alias);
  }
}

class OfflineFile extends DataClass implements Insertable<OfflineFile> {
  final String accountId;
  final String fileId;

  /// Path to the encrypted blob on disk.
  final String localPath;

  /// Size of the encrypted file on disk (bytes). Used for cache size tracking.
  final int sizeOnDisk;

  /// Whether the user explicitly pinned this file for offline access.
  /// Pinned files are never auto-evicted; auto-cached files use LRU eviction.
  final bool pinned;
  final DateTime downloadedAt;

  /// Last time this cached file was accessed (read/decrypted). Used for
  /// LRU eviction of auto-cached (non-pinned) files.
  final DateTime lastAccessedAt;
  const OfflineFile({
    required this.accountId,
    required this.fileId,
    required this.localPath,
    required this.sizeOnDisk,
    required this.pinned,
    required this.downloadedAt,
    required this.lastAccessedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    map['file_id'] = Variable<String>(fileId);
    map['local_path'] = Variable<String>(localPath);
    map['size_on_disk'] = Variable<int>(sizeOnDisk);
    map['pinned'] = Variable<bool>(pinned);
    map['downloaded_at'] = Variable<DateTime>(downloadedAt);
    map['last_accessed_at'] = Variable<DateTime>(lastAccessedAt);
    return map;
  }

  OfflineFilesCompanion toCompanion(bool nullToAbsent) {
    return OfflineFilesCompanion(
      accountId: Value(accountId),
      fileId: Value(fileId),
      localPath: Value(localPath),
      sizeOnDisk: Value(sizeOnDisk),
      pinned: Value(pinned),
      downloadedAt: Value(downloadedAt),
      lastAccessedAt: Value(lastAccessedAt),
    );
  }

  factory OfflineFile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OfflineFile(
      accountId: serializer.fromJson<String>(json['accountId']),
      fileId: serializer.fromJson<String>(json['fileId']),
      localPath: serializer.fromJson<String>(json['localPath']),
      sizeOnDisk: serializer.fromJson<int>(json['sizeOnDisk']),
      pinned: serializer.fromJson<bool>(json['pinned']),
      downloadedAt: serializer.fromJson<DateTime>(json['downloadedAt']),
      lastAccessedAt: serializer.fromJson<DateTime>(json['lastAccessedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'fileId': serializer.toJson<String>(fileId),
      'localPath': serializer.toJson<String>(localPath),
      'sizeOnDisk': serializer.toJson<int>(sizeOnDisk),
      'pinned': serializer.toJson<bool>(pinned),
      'downloadedAt': serializer.toJson<DateTime>(downloadedAt),
      'lastAccessedAt': serializer.toJson<DateTime>(lastAccessedAt),
    };
  }

  OfflineFile copyWith({
    String? accountId,
    String? fileId,
    String? localPath,
    int? sizeOnDisk,
    bool? pinned,
    DateTime? downloadedAt,
    DateTime? lastAccessedAt,
  }) => OfflineFile(
    accountId: accountId ?? this.accountId,
    fileId: fileId ?? this.fileId,
    localPath: localPath ?? this.localPath,
    sizeOnDisk: sizeOnDisk ?? this.sizeOnDisk,
    pinned: pinned ?? this.pinned,
    downloadedAt: downloadedAt ?? this.downloadedAt,
    lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
  );
  OfflineFile copyWithCompanion(OfflineFilesCompanion data) {
    return OfflineFile(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      fileId: data.fileId.present ? data.fileId.value : this.fileId,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      sizeOnDisk: data.sizeOnDisk.present
          ? data.sizeOnDisk.value
          : this.sizeOnDisk,
      pinned: data.pinned.present ? data.pinned.value : this.pinned,
      downloadedAt: data.downloadedAt.present
          ? data.downloadedAt.value
          : this.downloadedAt,
      lastAccessedAt: data.lastAccessedAt.present
          ? data.lastAccessedAt.value
          : this.lastAccessedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OfflineFile(')
          ..write('accountId: $accountId, ')
          ..write('fileId: $fileId, ')
          ..write('localPath: $localPath, ')
          ..write('sizeOnDisk: $sizeOnDisk, ')
          ..write('pinned: $pinned, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('lastAccessedAt: $lastAccessedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    accountId,
    fileId,
    localPath,
    sizeOnDisk,
    pinned,
    downloadedAt,
    lastAccessedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OfflineFile &&
          other.accountId == this.accountId &&
          other.fileId == this.fileId &&
          other.localPath == this.localPath &&
          other.sizeOnDisk == this.sizeOnDisk &&
          other.pinned == this.pinned &&
          other.downloadedAt == this.downloadedAt &&
          other.lastAccessedAt == this.lastAccessedAt);
}

class OfflineFilesCompanion extends UpdateCompanion<OfflineFile> {
  final Value<String> accountId;
  final Value<String> fileId;
  final Value<String> localPath;
  final Value<int> sizeOnDisk;
  final Value<bool> pinned;
  final Value<DateTime> downloadedAt;
  final Value<DateTime> lastAccessedAt;
  final Value<int> rowid;
  const OfflineFilesCompanion({
    this.accountId = const Value.absent(),
    this.fileId = const Value.absent(),
    this.localPath = const Value.absent(),
    this.sizeOnDisk = const Value.absent(),
    this.pinned = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.lastAccessedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OfflineFilesCompanion.insert({
    required String accountId,
    required String fileId,
    required String localPath,
    this.sizeOnDisk = const Value.absent(),
    this.pinned = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.lastAccessedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       fileId = Value(fileId),
       localPath = Value(localPath);
  static Insertable<OfflineFile> custom({
    Expression<String>? accountId,
    Expression<String>? fileId,
    Expression<String>? localPath,
    Expression<int>? sizeOnDisk,
    Expression<bool>? pinned,
    Expression<DateTime>? downloadedAt,
    Expression<DateTime>? lastAccessedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (fileId != null) 'file_id': fileId,
      if (localPath != null) 'local_path': localPath,
      if (sizeOnDisk != null) 'size_on_disk': sizeOnDisk,
      if (pinned != null) 'pinned': pinned,
      if (downloadedAt != null) 'downloaded_at': downloadedAt,
      if (lastAccessedAt != null) 'last_accessed_at': lastAccessedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OfflineFilesCompanion copyWith({
    Value<String>? accountId,
    Value<String>? fileId,
    Value<String>? localPath,
    Value<int>? sizeOnDisk,
    Value<bool>? pinned,
    Value<DateTime>? downloadedAt,
    Value<DateTime>? lastAccessedAt,
    Value<int>? rowid,
  }) {
    return OfflineFilesCompanion(
      accountId: accountId ?? this.accountId,
      fileId: fileId ?? this.fileId,
      localPath: localPath ?? this.localPath,
      sizeOnDisk: sizeOnDisk ?? this.sizeOnDisk,
      pinned: pinned ?? this.pinned,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (fileId.present) {
      map['file_id'] = Variable<String>(fileId.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (sizeOnDisk.present) {
      map['size_on_disk'] = Variable<int>(sizeOnDisk.value);
    }
    if (pinned.present) {
      map['pinned'] = Variable<bool>(pinned.value);
    }
    if (downloadedAt.present) {
      map['downloaded_at'] = Variable<DateTime>(downloadedAt.value);
    }
    if (lastAccessedAt.present) {
      map['last_accessed_at'] = Variable<DateTime>(lastAccessedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OfflineFilesCompanion(')
          ..write('accountId: $accountId, ')
          ..write('fileId: $fileId, ')
          ..write('localPath: $localPath, ')
          ..write('sizeOnDisk: $sizeOnDisk, ')
          ..write('pinned: $pinned, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('lastAccessedAt: $lastAccessedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingUploadsTable extends PendingUploads
    with TableInfo<$PendingUploadsTable, PendingUpload> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingUploadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetDirIdMeta = const VerificationMeta(
    'targetDirId',
  );
  @override
  late final GeneratedColumn<String> targetDirId = GeneratedColumn<String>(
    'target_dir_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextRetryAtMeta = const VerificationMeta(
    'nextRetryAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextRetryAt = GeneratedColumn<DateTime>(
    'next_retry_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    localPath,
    targetDirId,
    status,
    retryCount,
    nextRetryAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_uploads';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingUpload> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    } else if (isInserting) {
      context.missing(_localPathMeta);
    }
    if (data.containsKey('target_dir_id')) {
      context.handle(
        _targetDirIdMeta,
        targetDirId.isAcceptableOrUnknown(
          data['target_dir_id']!,
          _targetDirIdMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('next_retry_at')) {
      context.handle(
        _nextRetryAtMeta,
        nextRetryAt.isAcceptableOrUnknown(
          data['next_retry_at']!,
          _nextRetryAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingUpload map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingUpload(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      )!,
      targetDirId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_dir_id'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      nextRetryAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_retry_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PendingUploadsTable createAlias(String alias) {
    return $PendingUploadsTable(attachedDatabase, alias);
  }
}

class PendingUpload extends DataClass implements Insertable<PendingUpload> {
  final int id;
  final String accountId;
  final String localPath;
  final String? targetDirId;
  final String status;
  final int retryCount;
  final DateTime? nextRetryAt;
  final DateTime createdAt;
  const PendingUpload({
    required this.id,
    required this.accountId,
    required this.localPath,
    this.targetDirId,
    required this.status,
    required this.retryCount,
    this.nextRetryAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['account_id'] = Variable<String>(accountId);
    map['local_path'] = Variable<String>(localPath);
    if (!nullToAbsent || targetDirId != null) {
      map['target_dir_id'] = Variable<String>(targetDirId);
    }
    map['status'] = Variable<String>(status);
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || nextRetryAt != null) {
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PendingUploadsCompanion toCompanion(bool nullToAbsent) {
    return PendingUploadsCompanion(
      id: Value(id),
      accountId: Value(accountId),
      localPath: Value(localPath),
      targetDirId: targetDirId == null && nullToAbsent
          ? const Value.absent()
          : Value(targetDirId),
      status: Value(status),
      retryCount: Value(retryCount),
      nextRetryAt: nextRetryAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextRetryAt),
      createdAt: Value(createdAt),
    );
  }

  factory PendingUpload.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingUpload(
      id: serializer.fromJson<int>(json['id']),
      accountId: serializer.fromJson<String>(json['accountId']),
      localPath: serializer.fromJson<String>(json['localPath']),
      targetDirId: serializer.fromJson<String?>(json['targetDirId']),
      status: serializer.fromJson<String>(json['status']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      nextRetryAt: serializer.fromJson<DateTime?>(json['nextRetryAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'accountId': serializer.toJson<String>(accountId),
      'localPath': serializer.toJson<String>(localPath),
      'targetDirId': serializer.toJson<String?>(targetDirId),
      'status': serializer.toJson<String>(status),
      'retryCount': serializer.toJson<int>(retryCount),
      'nextRetryAt': serializer.toJson<DateTime?>(nextRetryAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PendingUpload copyWith({
    int? id,
    String? accountId,
    String? localPath,
    Value<String?> targetDirId = const Value.absent(),
    String? status,
    int? retryCount,
    Value<DateTime?> nextRetryAt = const Value.absent(),
    DateTime? createdAt,
  }) => PendingUpload(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    localPath: localPath ?? this.localPath,
    targetDirId: targetDirId.present ? targetDirId.value : this.targetDirId,
    status: status ?? this.status,
    retryCount: retryCount ?? this.retryCount,
    nextRetryAt: nextRetryAt.present ? nextRetryAt.value : this.nextRetryAt,
    createdAt: createdAt ?? this.createdAt,
  );
  PendingUpload copyWithCompanion(PendingUploadsCompanion data) {
    return PendingUpload(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      targetDirId: data.targetDirId.present
          ? data.targetDirId.value
          : this.targetDirId,
      status: data.status.present ? data.status.value : this.status,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      nextRetryAt: data.nextRetryAt.present
          ? data.nextRetryAt.value
          : this.nextRetryAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingUpload(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('localPath: $localPath, ')
          ..write('targetDirId: $targetDirId, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    localPath,
    targetDirId,
    status,
    retryCount,
    nextRetryAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingUpload &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.localPath == this.localPath &&
          other.targetDirId == this.targetDirId &&
          other.status == this.status &&
          other.retryCount == this.retryCount &&
          other.nextRetryAt == this.nextRetryAt &&
          other.createdAt == this.createdAt);
}

class PendingUploadsCompanion extends UpdateCompanion<PendingUpload> {
  final Value<int> id;
  final Value<String> accountId;
  final Value<String> localPath;
  final Value<String?> targetDirId;
  final Value<String> status;
  final Value<int> retryCount;
  final Value<DateTime?> nextRetryAt;
  final Value<DateTime> createdAt;
  const PendingUploadsCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.localPath = const Value.absent(),
    this.targetDirId = const Value.absent(),
    this.status = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PendingUploadsCompanion.insert({
    this.id = const Value.absent(),
    required String accountId,
    required String localPath,
    this.targetDirId = const Value.absent(),
    this.status = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : accountId = Value(accountId),
       localPath = Value(localPath);
  static Insertable<PendingUpload> custom({
    Expression<int>? id,
    Expression<String>? accountId,
    Expression<String>? localPath,
    Expression<String>? targetDirId,
    Expression<String>? status,
    Expression<int>? retryCount,
    Expression<DateTime>? nextRetryAt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (localPath != null) 'local_path': localPath,
      if (targetDirId != null) 'target_dir_id': targetDirId,
      if (status != null) 'status': status,
      if (retryCount != null) 'retry_count': retryCount,
      if (nextRetryAt != null) 'next_retry_at': nextRetryAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  PendingUploadsCompanion copyWith({
    Value<int>? id,
    Value<String>? accountId,
    Value<String>? localPath,
    Value<String?>? targetDirId,
    Value<String>? status,
    Value<int>? retryCount,
    Value<DateTime?>? nextRetryAt,
    Value<DateTime>? createdAt,
  }) {
    return PendingUploadsCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      localPath: localPath ?? this.localPath,
      targetDirId: targetDirId ?? this.targetDirId,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (targetDirId.present) {
      map['target_dir_id'] = Variable<String>(targetDirId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (nextRetryAt.present) {
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingUploadsCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('localPath: $localPath, ')
          ..write('targetDirId: $targetDirId, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $McpSettingsTable extends McpSettings
    with TableInfo<$McpSettingsTable, McpSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $McpSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _portMeta = const VerificationMeta('port');
  @override
  late final GeneratedColumn<int> port = GeneratedColumn<int>(
    'port',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(19548),
  );
  static const VerificationMeta _bearerTokenMeta = const VerificationMeta(
    'bearerToken',
  );
  @override
  late final GeneratedColumn<String> bearerToken = GeneratedColumn<String>(
    'bearer_token',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _allowReadOnlyWhileLockedMeta =
      const VerificationMeta('allowReadOnlyWhileLocked');
  @override
  late final GeneratedColumn<bool> allowReadOnlyWhileLocked =
      GeneratedColumn<bool>(
        'allow_read_only_while_locked',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("allow_read_only_while_locked" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _rateLimitRpsMeta = const VerificationMeta(
    'rateLimitRps',
  );
  @override
  late final GeneratedColumn<int> rateLimitRps = GeneratedColumn<int>(
    'rate_limit_rps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(5),
  );
  static const VerificationMeta _rateLimitBurstMeta = const VerificationMeta(
    'rateLimitBurst',
  );
  @override
  late final GeneratedColumn<int> rateLimitBurst = GeneratedColumn<int>(
    'rate_limit_burst',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(20),
  );
  static const VerificationMeta _auditRetentionDaysMeta =
      const VerificationMeta('auditRetentionDays');
  @override
  late final GeneratedColumn<int> auditRetentionDays = GeneratedColumn<int>(
    'audit_retention_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(30),
  );
  static const VerificationMeta _lastAuditCleanupAtMeta =
      const VerificationMeta('lastAuditCleanupAt');
  @override
  late final GeneratedColumn<DateTime> lastAuditCleanupAt =
      GeneratedColumn<DateTime>(
        'last_audit_cleanup_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    accountId,
    enabled,
    port,
    bearerToken,
    createdAt,
    allowReadOnlyWhileLocked,
    rateLimitRps,
    rateLimitBurst,
    auditRetentionDays,
    lastAuditCleanupAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mcp_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<McpSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('port')) {
      context.handle(
        _portMeta,
        port.isAcceptableOrUnknown(data['port']!, _portMeta),
      );
    }
    if (data.containsKey('bearer_token')) {
      context.handle(
        _bearerTokenMeta,
        bearerToken.isAcceptableOrUnknown(
          data['bearer_token']!,
          _bearerTokenMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('allow_read_only_while_locked')) {
      context.handle(
        _allowReadOnlyWhileLockedMeta,
        allowReadOnlyWhileLocked.isAcceptableOrUnknown(
          data['allow_read_only_while_locked']!,
          _allowReadOnlyWhileLockedMeta,
        ),
      );
    }
    if (data.containsKey('rate_limit_rps')) {
      context.handle(
        _rateLimitRpsMeta,
        rateLimitRps.isAcceptableOrUnknown(
          data['rate_limit_rps']!,
          _rateLimitRpsMeta,
        ),
      );
    }
    if (data.containsKey('rate_limit_burst')) {
      context.handle(
        _rateLimitBurstMeta,
        rateLimitBurst.isAcceptableOrUnknown(
          data['rate_limit_burst']!,
          _rateLimitBurstMeta,
        ),
      );
    }
    if (data.containsKey('audit_retention_days')) {
      context.handle(
        _auditRetentionDaysMeta,
        auditRetentionDays.isAcceptableOrUnknown(
          data['audit_retention_days']!,
          _auditRetentionDaysMeta,
        ),
      );
    }
    if (data.containsKey('last_audit_cleanup_at')) {
      context.handle(
        _lastAuditCleanupAtMeta,
        lastAuditCleanupAt.isAcceptableOrUnknown(
          data['last_audit_cleanup_at']!,
          _lastAuditCleanupAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId};
  @override
  McpSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return McpSetting(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      port: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}port'],
      )!,
      bearerToken: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bearer_token'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      allowReadOnlyWhileLocked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}allow_read_only_while_locked'],
      )!,
      rateLimitRps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rate_limit_rps'],
      )!,
      rateLimitBurst: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rate_limit_burst'],
      )!,
      auditRetentionDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}audit_retention_days'],
      )!,
      lastAuditCleanupAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_audit_cleanup_at'],
      ),
    );
  }

  @override
  $McpSettingsTable createAlias(String alias) {
    return $McpSettingsTable(attachedDatabase, alias);
  }
}

class McpSetting extends DataClass implements Insertable<McpSetting> {
  final String accountId;
  final bool enabled;
  final int port;
  final String bearerToken;
  final DateTime createdAt;

  /// When true, read-only tools (list_files, list_notes, search_files,
  /// storage_stats) remain available while the app is PIN-locked. Crypto-
  /// requiring tools (read_file, write_file, rename, etc.) are always denied
  /// in the locked state regardless of this flag. Defaults to false — deny
  /// all agent access while locked.
  final bool allowReadOnlyWhileLocked;

  /// Token-bucket refill rate in requests/second.
  final int rateLimitRps;

  /// Token-bucket capacity (burst allowance).
  final int rateLimitBurst;

  /// How many days to keep audit-log entries. `0` means "forever". The
  /// cleanup pass in [AppDatabase.maybeRunMcpAuditRetention] respects this
  /// value on app foreground, deleting anything older than the window.
  final int auditRetentionDays;

  /// Wall-clock time of the most recent retention pass. Null means "never".
  /// Used to debounce the cleanup so we only rescan once per 24 hours even
  /// if the user foregrounds the app repeatedly.
  final DateTime? lastAuditCleanupAt;
  const McpSetting({
    required this.accountId,
    required this.enabled,
    required this.port,
    required this.bearerToken,
    required this.createdAt,
    required this.allowReadOnlyWhileLocked,
    required this.rateLimitRps,
    required this.rateLimitBurst,
    required this.auditRetentionDays,
    this.lastAuditCleanupAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    map['enabled'] = Variable<bool>(enabled);
    map['port'] = Variable<int>(port);
    map['bearer_token'] = Variable<String>(bearerToken);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['allow_read_only_while_locked'] = Variable<bool>(
      allowReadOnlyWhileLocked,
    );
    map['rate_limit_rps'] = Variable<int>(rateLimitRps);
    map['rate_limit_burst'] = Variable<int>(rateLimitBurst);
    map['audit_retention_days'] = Variable<int>(auditRetentionDays);
    if (!nullToAbsent || lastAuditCleanupAt != null) {
      map['last_audit_cleanup_at'] = Variable<DateTime>(lastAuditCleanupAt);
    }
    return map;
  }

  McpSettingsCompanion toCompanion(bool nullToAbsent) {
    return McpSettingsCompanion(
      accountId: Value(accountId),
      enabled: Value(enabled),
      port: Value(port),
      bearerToken: Value(bearerToken),
      createdAt: Value(createdAt),
      allowReadOnlyWhileLocked: Value(allowReadOnlyWhileLocked),
      rateLimitRps: Value(rateLimitRps),
      rateLimitBurst: Value(rateLimitBurst),
      auditRetentionDays: Value(auditRetentionDays),
      lastAuditCleanupAt: lastAuditCleanupAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAuditCleanupAt),
    );
  }

  factory McpSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return McpSetting(
      accountId: serializer.fromJson<String>(json['accountId']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      port: serializer.fromJson<int>(json['port']),
      bearerToken: serializer.fromJson<String>(json['bearerToken']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      allowReadOnlyWhileLocked: serializer.fromJson<bool>(
        json['allowReadOnlyWhileLocked'],
      ),
      rateLimitRps: serializer.fromJson<int>(json['rateLimitRps']),
      rateLimitBurst: serializer.fromJson<int>(json['rateLimitBurst']),
      auditRetentionDays: serializer.fromJson<int>(json['auditRetentionDays']),
      lastAuditCleanupAt: serializer.fromJson<DateTime?>(
        json['lastAuditCleanupAt'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'enabled': serializer.toJson<bool>(enabled),
      'port': serializer.toJson<int>(port),
      'bearerToken': serializer.toJson<String>(bearerToken),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'allowReadOnlyWhileLocked': serializer.toJson<bool>(
        allowReadOnlyWhileLocked,
      ),
      'rateLimitRps': serializer.toJson<int>(rateLimitRps),
      'rateLimitBurst': serializer.toJson<int>(rateLimitBurst),
      'auditRetentionDays': serializer.toJson<int>(auditRetentionDays),
      'lastAuditCleanupAt': serializer.toJson<DateTime?>(lastAuditCleanupAt),
    };
  }

  McpSetting copyWith({
    String? accountId,
    bool? enabled,
    int? port,
    String? bearerToken,
    DateTime? createdAt,
    bool? allowReadOnlyWhileLocked,
    int? rateLimitRps,
    int? rateLimitBurst,
    int? auditRetentionDays,
    Value<DateTime?> lastAuditCleanupAt = const Value.absent(),
  }) => McpSetting(
    accountId: accountId ?? this.accountId,
    enabled: enabled ?? this.enabled,
    port: port ?? this.port,
    bearerToken: bearerToken ?? this.bearerToken,
    createdAt: createdAt ?? this.createdAt,
    allowReadOnlyWhileLocked:
        allowReadOnlyWhileLocked ?? this.allowReadOnlyWhileLocked,
    rateLimitRps: rateLimitRps ?? this.rateLimitRps,
    rateLimitBurst: rateLimitBurst ?? this.rateLimitBurst,
    auditRetentionDays: auditRetentionDays ?? this.auditRetentionDays,
    lastAuditCleanupAt: lastAuditCleanupAt.present
        ? lastAuditCleanupAt.value
        : this.lastAuditCleanupAt,
  );
  McpSetting copyWithCompanion(McpSettingsCompanion data) {
    return McpSetting(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      port: data.port.present ? data.port.value : this.port,
      bearerToken: data.bearerToken.present
          ? data.bearerToken.value
          : this.bearerToken,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      allowReadOnlyWhileLocked: data.allowReadOnlyWhileLocked.present
          ? data.allowReadOnlyWhileLocked.value
          : this.allowReadOnlyWhileLocked,
      rateLimitRps: data.rateLimitRps.present
          ? data.rateLimitRps.value
          : this.rateLimitRps,
      rateLimitBurst: data.rateLimitBurst.present
          ? data.rateLimitBurst.value
          : this.rateLimitBurst,
      auditRetentionDays: data.auditRetentionDays.present
          ? data.auditRetentionDays.value
          : this.auditRetentionDays,
      lastAuditCleanupAt: data.lastAuditCleanupAt.present
          ? data.lastAuditCleanupAt.value
          : this.lastAuditCleanupAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('McpSetting(')
          ..write('accountId: $accountId, ')
          ..write('enabled: $enabled, ')
          ..write('port: $port, ')
          ..write('bearerToken: $bearerToken, ')
          ..write('createdAt: $createdAt, ')
          ..write('allowReadOnlyWhileLocked: $allowReadOnlyWhileLocked, ')
          ..write('rateLimitRps: $rateLimitRps, ')
          ..write('rateLimitBurst: $rateLimitBurst, ')
          ..write('auditRetentionDays: $auditRetentionDays, ')
          ..write('lastAuditCleanupAt: $lastAuditCleanupAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    accountId,
    enabled,
    port,
    bearerToken,
    createdAt,
    allowReadOnlyWhileLocked,
    rateLimitRps,
    rateLimitBurst,
    auditRetentionDays,
    lastAuditCleanupAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is McpSetting &&
          other.accountId == this.accountId &&
          other.enabled == this.enabled &&
          other.port == this.port &&
          other.bearerToken == this.bearerToken &&
          other.createdAt == this.createdAt &&
          other.allowReadOnlyWhileLocked == this.allowReadOnlyWhileLocked &&
          other.rateLimitRps == this.rateLimitRps &&
          other.rateLimitBurst == this.rateLimitBurst &&
          other.auditRetentionDays == this.auditRetentionDays &&
          other.lastAuditCleanupAt == this.lastAuditCleanupAt);
}

class McpSettingsCompanion extends UpdateCompanion<McpSetting> {
  final Value<String> accountId;
  final Value<bool> enabled;
  final Value<int> port;
  final Value<String> bearerToken;
  final Value<DateTime> createdAt;
  final Value<bool> allowReadOnlyWhileLocked;
  final Value<int> rateLimitRps;
  final Value<int> rateLimitBurst;
  final Value<int> auditRetentionDays;
  final Value<DateTime?> lastAuditCleanupAt;
  final Value<int> rowid;
  const McpSettingsCompanion({
    this.accountId = const Value.absent(),
    this.enabled = const Value.absent(),
    this.port = const Value.absent(),
    this.bearerToken = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.allowReadOnlyWhileLocked = const Value.absent(),
    this.rateLimitRps = const Value.absent(),
    this.rateLimitBurst = const Value.absent(),
    this.auditRetentionDays = const Value.absent(),
    this.lastAuditCleanupAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  McpSettingsCompanion.insert({
    required String accountId,
    this.enabled = const Value.absent(),
    this.port = const Value.absent(),
    this.bearerToken = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.allowReadOnlyWhileLocked = const Value.absent(),
    this.rateLimitRps = const Value.absent(),
    this.rateLimitBurst = const Value.absent(),
    this.auditRetentionDays = const Value.absent(),
    this.lastAuditCleanupAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId);
  static Insertable<McpSetting> custom({
    Expression<String>? accountId,
    Expression<bool>? enabled,
    Expression<int>? port,
    Expression<String>? bearerToken,
    Expression<DateTime>? createdAt,
    Expression<bool>? allowReadOnlyWhileLocked,
    Expression<int>? rateLimitRps,
    Expression<int>? rateLimitBurst,
    Expression<int>? auditRetentionDays,
    Expression<DateTime>? lastAuditCleanupAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (enabled != null) 'enabled': enabled,
      if (port != null) 'port': port,
      if (bearerToken != null) 'bearer_token': bearerToken,
      if (createdAt != null) 'created_at': createdAt,
      if (allowReadOnlyWhileLocked != null)
        'allow_read_only_while_locked': allowReadOnlyWhileLocked,
      if (rateLimitRps != null) 'rate_limit_rps': rateLimitRps,
      if (rateLimitBurst != null) 'rate_limit_burst': rateLimitBurst,
      if (auditRetentionDays != null)
        'audit_retention_days': auditRetentionDays,
      if (lastAuditCleanupAt != null)
        'last_audit_cleanup_at': lastAuditCleanupAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  McpSettingsCompanion copyWith({
    Value<String>? accountId,
    Value<bool>? enabled,
    Value<int>? port,
    Value<String>? bearerToken,
    Value<DateTime>? createdAt,
    Value<bool>? allowReadOnlyWhileLocked,
    Value<int>? rateLimitRps,
    Value<int>? rateLimitBurst,
    Value<int>? auditRetentionDays,
    Value<DateTime?>? lastAuditCleanupAt,
    Value<int>? rowid,
  }) {
    return McpSettingsCompanion(
      accountId: accountId ?? this.accountId,
      enabled: enabled ?? this.enabled,
      port: port ?? this.port,
      bearerToken: bearerToken ?? this.bearerToken,
      createdAt: createdAt ?? this.createdAt,
      allowReadOnlyWhileLocked:
          allowReadOnlyWhileLocked ?? this.allowReadOnlyWhileLocked,
      rateLimitRps: rateLimitRps ?? this.rateLimitRps,
      rateLimitBurst: rateLimitBurst ?? this.rateLimitBurst,
      auditRetentionDays: auditRetentionDays ?? this.auditRetentionDays,
      lastAuditCleanupAt: lastAuditCleanupAt ?? this.lastAuditCleanupAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (port.present) {
      map['port'] = Variable<int>(port.value);
    }
    if (bearerToken.present) {
      map['bearer_token'] = Variable<String>(bearerToken.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (allowReadOnlyWhileLocked.present) {
      map['allow_read_only_while_locked'] = Variable<bool>(
        allowReadOnlyWhileLocked.value,
      );
    }
    if (rateLimitRps.present) {
      map['rate_limit_rps'] = Variable<int>(rateLimitRps.value);
    }
    if (rateLimitBurst.present) {
      map['rate_limit_burst'] = Variable<int>(rateLimitBurst.value);
    }
    if (auditRetentionDays.present) {
      map['audit_retention_days'] = Variable<int>(auditRetentionDays.value);
    }
    if (lastAuditCleanupAt.present) {
      map['last_audit_cleanup_at'] = Variable<DateTime>(
        lastAuditCleanupAt.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('McpSettingsCompanion(')
          ..write('accountId: $accountId, ')
          ..write('enabled: $enabled, ')
          ..write('port: $port, ')
          ..write('bearerToken: $bearerToken, ')
          ..write('createdAt: $createdAt, ')
          ..write('allowReadOnlyWhileLocked: $allowReadOnlyWhileLocked, ')
          ..write('rateLimitRps: $rateLimitRps, ')
          ..write('rateLimitBurst: $rateLimitBurst, ')
          ..write('auditRetentionDays: $auditRetentionDays, ')
          ..write('lastAuditCleanupAt: $lastAuditCleanupAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $McpAuditLogTable extends McpAuditLog
    with TableInfo<$McpAuditLogTable, McpAuditLogData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $McpAuditLogTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _toolNameMeta = const VerificationMeta(
    'toolName',
  );
  @override
  late final GeneratedColumn<String> toolName = GeneratedColumn<String>(
    'tool_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paramsHashMeta = const VerificationMeta(
    'paramsHash',
  );
  @override
  late final GeneratedColumn<String> paramsHash = GeneratedColumn<String>(
    'params_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resultStatusMeta = const VerificationMeta(
    'resultStatus',
  );
  @override
  late final GeneratedColumn<String> resultStatus = GeneratedColumn<String>(
    'result_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    timestamp,
    sessionId,
    accountId,
    toolName,
    paramsHash,
    resultStatus,
    errorMessage,
    durationMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mcp_audit_log';
  @override
  VerificationContext validateIntegrity(
    Insertable<McpAuditLogData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    }
    if (data.containsKey('tool_name')) {
      context.handle(
        _toolNameMeta,
        toolName.isAcceptableOrUnknown(data['tool_name']!, _toolNameMeta),
      );
    } else if (isInserting) {
      context.missing(_toolNameMeta);
    }
    if (data.containsKey('params_hash')) {
      context.handle(
        _paramsHashMeta,
        paramsHash.isAcceptableOrUnknown(data['params_hash']!, _paramsHashMeta),
      );
    } else if (isInserting) {
      context.missing(_paramsHashMeta);
    }
    if (data.containsKey('result_status')) {
      context.handle(
        _resultStatusMeta,
        resultStatus.isAcceptableOrUnknown(
          data['result_status']!,
          _resultStatusMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_resultStatusMeta);
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  McpAuditLogData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return McpAuditLogData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      ),
      toolName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tool_name'],
      )!,
      paramsHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}params_hash'],
      )!,
      resultStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result_status'],
      )!,
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
    );
  }

  @override
  $McpAuditLogTable createAlias(String alias) {
    return $McpAuditLogTable(attachedDatabase, alias);
  }
}

class McpAuditLogData extends DataClass implements Insertable<McpAuditLogData> {
  final int id;
  final DateTime timestamp;

  /// SHA256 of the MCP session ID (never the session ID itself).
  final String sessionId;
  final String? accountId;
  final String toolName;

  /// SHA256 of the canonical JSON encoding of the tool params. Fixed width,
  /// no plaintext leakage. Empty string if params were absent.
  final String paramsHash;

  /// 'ok' | 'error' | 'denied'. 'denied' is reserved for future authz checks.
  final String resultStatus;
  final String? errorMessage;
  final int durationMs;
  const McpAuditLogData({
    required this.id,
    required this.timestamp,
    required this.sessionId,
    this.accountId,
    required this.toolName,
    required this.paramsHash,
    required this.resultStatus,
    this.errorMessage,
    required this.durationMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['session_id'] = Variable<String>(sessionId);
    if (!nullToAbsent || accountId != null) {
      map['account_id'] = Variable<String>(accountId);
    }
    map['tool_name'] = Variable<String>(toolName);
    map['params_hash'] = Variable<String>(paramsHash);
    map['result_status'] = Variable<String>(resultStatus);
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    map['duration_ms'] = Variable<int>(durationMs);
    return map;
  }

  McpAuditLogCompanion toCompanion(bool nullToAbsent) {
    return McpAuditLogCompanion(
      id: Value(id),
      timestamp: Value(timestamp),
      sessionId: Value(sessionId),
      accountId: accountId == null && nullToAbsent
          ? const Value.absent()
          : Value(accountId),
      toolName: Value(toolName),
      paramsHash: Value(paramsHash),
      resultStatus: Value(resultStatus),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      durationMs: Value(durationMs),
    );
  }

  factory McpAuditLogData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return McpAuditLogData(
      id: serializer.fromJson<int>(json['id']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      accountId: serializer.fromJson<String?>(json['accountId']),
      toolName: serializer.fromJson<String>(json['toolName']),
      paramsHash: serializer.fromJson<String>(json['paramsHash']),
      resultStatus: serializer.fromJson<String>(json['resultStatus']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'sessionId': serializer.toJson<String>(sessionId),
      'accountId': serializer.toJson<String?>(accountId),
      'toolName': serializer.toJson<String>(toolName),
      'paramsHash': serializer.toJson<String>(paramsHash),
      'resultStatus': serializer.toJson<String>(resultStatus),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'durationMs': serializer.toJson<int>(durationMs),
    };
  }

  McpAuditLogData copyWith({
    int? id,
    DateTime? timestamp,
    String? sessionId,
    Value<String?> accountId = const Value.absent(),
    String? toolName,
    String? paramsHash,
    String? resultStatus,
    Value<String?> errorMessage = const Value.absent(),
    int? durationMs,
  }) => McpAuditLogData(
    id: id ?? this.id,
    timestamp: timestamp ?? this.timestamp,
    sessionId: sessionId ?? this.sessionId,
    accountId: accountId.present ? accountId.value : this.accountId,
    toolName: toolName ?? this.toolName,
    paramsHash: paramsHash ?? this.paramsHash,
    resultStatus: resultStatus ?? this.resultStatus,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    durationMs: durationMs ?? this.durationMs,
  );
  McpAuditLogData copyWithCompanion(McpAuditLogCompanion data) {
    return McpAuditLogData(
      id: data.id.present ? data.id.value : this.id,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      toolName: data.toolName.present ? data.toolName.value : this.toolName,
      paramsHash: data.paramsHash.present
          ? data.paramsHash.value
          : this.paramsHash,
      resultStatus: data.resultStatus.present
          ? data.resultStatus.value
          : this.resultStatus,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('McpAuditLogData(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('sessionId: $sessionId, ')
          ..write('accountId: $accountId, ')
          ..write('toolName: $toolName, ')
          ..write('paramsHash: $paramsHash, ')
          ..write('resultStatus: $resultStatus, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('durationMs: $durationMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    timestamp,
    sessionId,
    accountId,
    toolName,
    paramsHash,
    resultStatus,
    errorMessage,
    durationMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is McpAuditLogData &&
          other.id == this.id &&
          other.timestamp == this.timestamp &&
          other.sessionId == this.sessionId &&
          other.accountId == this.accountId &&
          other.toolName == this.toolName &&
          other.paramsHash == this.paramsHash &&
          other.resultStatus == this.resultStatus &&
          other.errorMessage == this.errorMessage &&
          other.durationMs == this.durationMs);
}

class McpAuditLogCompanion extends UpdateCompanion<McpAuditLogData> {
  final Value<int> id;
  final Value<DateTime> timestamp;
  final Value<String> sessionId;
  final Value<String?> accountId;
  final Value<String> toolName;
  final Value<String> paramsHash;
  final Value<String> resultStatus;
  final Value<String?> errorMessage;
  final Value<int> durationMs;
  const McpAuditLogCompanion({
    this.id = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.toolName = const Value.absent(),
    this.paramsHash = const Value.absent(),
    this.resultStatus = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.durationMs = const Value.absent(),
  });
  McpAuditLogCompanion.insert({
    this.id = const Value.absent(),
    required DateTime timestamp,
    required String sessionId,
    this.accountId = const Value.absent(),
    required String toolName,
    required String paramsHash,
    required String resultStatus,
    this.errorMessage = const Value.absent(),
    required int durationMs,
  }) : timestamp = Value(timestamp),
       sessionId = Value(sessionId),
       toolName = Value(toolName),
       paramsHash = Value(paramsHash),
       resultStatus = Value(resultStatus),
       durationMs = Value(durationMs);
  static Insertable<McpAuditLogData> custom({
    Expression<int>? id,
    Expression<DateTime>? timestamp,
    Expression<String>? sessionId,
    Expression<String>? accountId,
    Expression<String>? toolName,
    Expression<String>? paramsHash,
    Expression<String>? resultStatus,
    Expression<String>? errorMessage,
    Expression<int>? durationMs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (timestamp != null) 'timestamp': timestamp,
      if (sessionId != null) 'session_id': sessionId,
      if (accountId != null) 'account_id': accountId,
      if (toolName != null) 'tool_name': toolName,
      if (paramsHash != null) 'params_hash': paramsHash,
      if (resultStatus != null) 'result_status': resultStatus,
      if (errorMessage != null) 'error_message': errorMessage,
      if (durationMs != null) 'duration_ms': durationMs,
    });
  }

  McpAuditLogCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? timestamp,
    Value<String>? sessionId,
    Value<String?>? accountId,
    Value<String>? toolName,
    Value<String>? paramsHash,
    Value<String>? resultStatus,
    Value<String?>? errorMessage,
    Value<int>? durationMs,
  }) {
    return McpAuditLogCompanion(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      sessionId: sessionId ?? this.sessionId,
      accountId: accountId ?? this.accountId,
      toolName: toolName ?? this.toolName,
      paramsHash: paramsHash ?? this.paramsHash,
      resultStatus: resultStatus ?? this.resultStatus,
      errorMessage: errorMessage ?? this.errorMessage,
      durationMs: durationMs ?? this.durationMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (toolName.present) {
      map['tool_name'] = Variable<String>(toolName.value);
    }
    if (paramsHash.present) {
      map['params_hash'] = Variable<String>(paramsHash.value);
    }
    if (resultStatus.present) {
      map['result_status'] = Variable<String>(resultStatus.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('McpAuditLogCompanion(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('sessionId: $sessionId, ')
          ..write('accountId: $accountId, ')
          ..write('toolName: $toolName, ')
          ..write('paramsHash: $paramsHash, ')
          ..write('resultStatus: $resultStatus, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('durationMs: $durationMs')
          ..write(')'))
        .toString();
  }
}

class $TrustedFingerprintsTable extends TrustedFingerprints
    with TableInfo<$TrustedFingerprintsTable, TrustedFingerprint> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrustedFingerprintsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerUserIdMeta = const VerificationMeta(
    'ownerUserId',
  );
  @override
  late final GeneratedColumn<String> ownerUserId = GeneratedColumn<String>(
    'owner_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fingerprintMeta = const VerificationMeta(
    'fingerprint',
  );
  @override
  late final GeneratedColumn<String> fingerprint = GeneratedColumn<String>(
    'fingerprint',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastVerifiedAtMeta = const VerificationMeta(
    'lastVerifiedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastVerifiedAt =
      GeneratedColumn<DateTime>(
        'last_verified_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _verificationMethodMeta =
      const VerificationMeta('verificationMethod');
  @override
  late final GeneratedColumn<String> verificationMethod =
      GeneratedColumn<String>(
        'verification_method',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('tofu'),
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    ownerUserId,
    userId,
    fingerprint,
    email,
    lastVerifiedAt,
    verificationMethod,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trusted_fingerprints';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrustedFingerprint> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_user_id')) {
      context.handle(
        _ownerUserIdMeta,
        ownerUserId.isAcceptableOrUnknown(
          data['owner_user_id']!,
          _ownerUserIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownerUserIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('fingerprint')) {
      context.handle(
        _fingerprintMeta,
        fingerprint.isAcceptableOrUnknown(
          data['fingerprint']!,
          _fingerprintMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fingerprintMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    }
    if (data.containsKey('last_verified_at')) {
      context.handle(
        _lastVerifiedAtMeta,
        lastVerifiedAt.isAcceptableOrUnknown(
          data['last_verified_at']!,
          _lastVerifiedAtMeta,
        ),
      );
    }
    if (data.containsKey('verification_method')) {
      context.handle(
        _verificationMethodMeta,
        verificationMethod.isAcceptableOrUnknown(
          data['verification_method']!,
          _verificationMethodMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerUserId, userId};
  @override
  TrustedFingerprint map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrustedFingerprint(
      ownerUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_user_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      fingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fingerprint'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      ),
      lastVerifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_verified_at'],
      ),
      verificationMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}verification_method'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TrustedFingerprintsTable createAlias(String alias) {
    return $TrustedFingerprintsTable(attachedDatabase, alias);
  }
}

class TrustedFingerprint extends DataClass
    implements Insertable<TrustedFingerprint> {
  final String ownerUserId;
  final String userId;

  /// The peer's `sha256(hex(modulus))` fingerprint, hex-encoded.
  final String fingerprint;

  /// The peer's email as last seen at discovery or share time. Feeds the
  /// recipient-suggestion list; already server-visible metadata, so caching
  /// it locally adds no exposure. Null on rows recorded before the column
  /// existed, backfilled on the next successful lookup of that peer.
  final String? email;

  /// When the user explicitly confirmed the fingerprint out of band. Null for
  /// a row that was only ever recorded on first sight.
  final DateTime? lastVerifiedAt;

  /// How the row got here: 'tofu' (recorded on first sight) or 'manual' (the
  /// user confirmed it out of band).
  final String verificationMethod;
  final DateTime createdAt;
  const TrustedFingerprint({
    required this.ownerUserId,
    required this.userId,
    required this.fingerprint,
    this.email,
    this.lastVerifiedAt,
    required this.verificationMethod,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_user_id'] = Variable<String>(ownerUserId);
    map['user_id'] = Variable<String>(userId);
    map['fingerprint'] = Variable<String>(fingerprint);
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || lastVerifiedAt != null) {
      map['last_verified_at'] = Variable<DateTime>(lastVerifiedAt);
    }
    map['verification_method'] = Variable<String>(verificationMethod);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TrustedFingerprintsCompanion toCompanion(bool nullToAbsent) {
    return TrustedFingerprintsCompanion(
      ownerUserId: Value(ownerUserId),
      userId: Value(userId),
      fingerprint: Value(fingerprint),
      email: email == null && nullToAbsent
          ? const Value.absent()
          : Value(email),
      lastVerifiedAt: lastVerifiedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastVerifiedAt),
      verificationMethod: Value(verificationMethod),
      createdAt: Value(createdAt),
    );
  }

  factory TrustedFingerprint.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrustedFingerprint(
      ownerUserId: serializer.fromJson<String>(json['ownerUserId']),
      userId: serializer.fromJson<String>(json['userId']),
      fingerprint: serializer.fromJson<String>(json['fingerprint']),
      email: serializer.fromJson<String?>(json['email']),
      lastVerifiedAt: serializer.fromJson<DateTime?>(json['lastVerifiedAt']),
      verificationMethod: serializer.fromJson<String>(
        json['verificationMethod'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerUserId': serializer.toJson<String>(ownerUserId),
      'userId': serializer.toJson<String>(userId),
      'fingerprint': serializer.toJson<String>(fingerprint),
      'email': serializer.toJson<String?>(email),
      'lastVerifiedAt': serializer.toJson<DateTime?>(lastVerifiedAt),
      'verificationMethod': serializer.toJson<String>(verificationMethod),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TrustedFingerprint copyWith({
    String? ownerUserId,
    String? userId,
    String? fingerprint,
    Value<String?> email = const Value.absent(),
    Value<DateTime?> lastVerifiedAt = const Value.absent(),
    String? verificationMethod,
    DateTime? createdAt,
  }) => TrustedFingerprint(
    ownerUserId: ownerUserId ?? this.ownerUserId,
    userId: userId ?? this.userId,
    fingerprint: fingerprint ?? this.fingerprint,
    email: email.present ? email.value : this.email,
    lastVerifiedAt: lastVerifiedAt.present
        ? lastVerifiedAt.value
        : this.lastVerifiedAt,
    verificationMethod: verificationMethod ?? this.verificationMethod,
    createdAt: createdAt ?? this.createdAt,
  );
  TrustedFingerprint copyWithCompanion(TrustedFingerprintsCompanion data) {
    return TrustedFingerprint(
      ownerUserId: data.ownerUserId.present
          ? data.ownerUserId.value
          : this.ownerUserId,
      userId: data.userId.present ? data.userId.value : this.userId,
      fingerprint: data.fingerprint.present
          ? data.fingerprint.value
          : this.fingerprint,
      email: data.email.present ? data.email.value : this.email,
      lastVerifiedAt: data.lastVerifiedAt.present
          ? data.lastVerifiedAt.value
          : this.lastVerifiedAt,
      verificationMethod: data.verificationMethod.present
          ? data.verificationMethod.value
          : this.verificationMethod,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrustedFingerprint(')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('userId: $userId, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('email: $email, ')
          ..write('lastVerifiedAt: $lastVerifiedAt, ')
          ..write('verificationMethod: $verificationMethod, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    ownerUserId,
    userId,
    fingerprint,
    email,
    lastVerifiedAt,
    verificationMethod,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrustedFingerprint &&
          other.ownerUserId == this.ownerUserId &&
          other.userId == this.userId &&
          other.fingerprint == this.fingerprint &&
          other.email == this.email &&
          other.lastVerifiedAt == this.lastVerifiedAt &&
          other.verificationMethod == this.verificationMethod &&
          other.createdAt == this.createdAt);
}

class TrustedFingerprintsCompanion extends UpdateCompanion<TrustedFingerprint> {
  final Value<String> ownerUserId;
  final Value<String> userId;
  final Value<String> fingerprint;
  final Value<String?> email;
  final Value<DateTime?> lastVerifiedAt;
  final Value<String> verificationMethod;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const TrustedFingerprintsCompanion({
    this.ownerUserId = const Value.absent(),
    this.userId = const Value.absent(),
    this.fingerprint = const Value.absent(),
    this.email = const Value.absent(),
    this.lastVerifiedAt = const Value.absent(),
    this.verificationMethod = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TrustedFingerprintsCompanion.insert({
    required String ownerUserId,
    required String userId,
    required String fingerprint,
    this.email = const Value.absent(),
    this.lastVerifiedAt = const Value.absent(),
    this.verificationMethod = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : ownerUserId = Value(ownerUserId),
       userId = Value(userId),
       fingerprint = Value(fingerprint);
  static Insertable<TrustedFingerprint> custom({
    Expression<String>? ownerUserId,
    Expression<String>? userId,
    Expression<String>? fingerprint,
    Expression<String>? email,
    Expression<DateTime>? lastVerifiedAt,
    Expression<String>? verificationMethod,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerUserId != null) 'owner_user_id': ownerUserId,
      if (userId != null) 'user_id': userId,
      if (fingerprint != null) 'fingerprint': fingerprint,
      if (email != null) 'email': email,
      if (lastVerifiedAt != null) 'last_verified_at': lastVerifiedAt,
      if (verificationMethod != null) 'verification_method': verificationMethod,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TrustedFingerprintsCompanion copyWith({
    Value<String>? ownerUserId,
    Value<String>? userId,
    Value<String>? fingerprint,
    Value<String?>? email,
    Value<DateTime?>? lastVerifiedAt,
    Value<String>? verificationMethod,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return TrustedFingerprintsCompanion(
      ownerUserId: ownerUserId ?? this.ownerUserId,
      userId: userId ?? this.userId,
      fingerprint: fingerprint ?? this.fingerprint,
      email: email ?? this.email,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
      verificationMethod: verificationMethod ?? this.verificationMethod,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerUserId.present) {
      map['owner_user_id'] = Variable<String>(ownerUserId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (fingerprint.present) {
      map['fingerprint'] = Variable<String>(fingerprint.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (lastVerifiedAt.present) {
      map['last_verified_at'] = Variable<DateTime>(lastVerifiedAt.value);
    }
    if (verificationMethod.present) {
      map['verification_method'] = Variable<String>(verificationMethod.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrustedFingerprintsCompanion(')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('userId: $userId, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('email: $email, ')
          ..write('lastVerifiedAt: $lastVerifiedAt, ')
          ..write('verificationMethod: $verificationMethod, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ServersTable servers = $ServersTable(this);
  late final $AccountsTable accounts = $AccountsTable(this);
  late final $CachedFilesTable cachedFiles = $CachedFilesTable(this);
  late final $OfflineFilesTable offlineFiles = $OfflineFilesTable(this);
  late final $PendingUploadsTable pendingUploads = $PendingUploadsTable(this);
  late final $McpSettingsTable mcpSettings = $McpSettingsTable(this);
  late final $McpAuditLogTable mcpAuditLog = $McpAuditLogTable(this);
  late final $TrustedFingerprintsTable trustedFingerprints =
      $TrustedFingerprintsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    servers,
    accounts,
    cachedFiles,
    offlineFiles,
    pendingUploads,
    mcpSettings,
    mcpAuditLog,
    trustedFingerprints,
  ];
}

typedef $$ServersTableCreateCompanionBuilder =
    ServersCompanion Function({
      required String id,
      required String url,
      required String name,
      Value<bool> trustSelfSignedCerts,
      Value<bool> useHeaderAuth,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$ServersTableUpdateCompanionBuilder =
    ServersCompanion Function({
      Value<String> id,
      Value<String> url,
      Value<String> name,
      Value<bool> trustSelfSignedCerts,
      Value<bool> useHeaderAuth,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$ServersTableReferences
    extends BaseReferences<_$AppDatabase, $ServersTable, Server> {
  $$ServersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$AccountsTable, List<Account>> _accountsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.accounts,
    aliasName: $_aliasNameGenerator(db.servers.id, db.accounts.serverId),
  );

  $$AccountsTableProcessedTableManager get accountsRefs {
    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.serverId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_accountsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ServersTableFilterComposer
    extends Composer<_$AppDatabase, $ServersTable> {
  $$ServersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get trustSelfSignedCerts => $composableBuilder(
    column: $table.trustSelfSignedCerts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get useHeaderAuth => $composableBuilder(
    column: $table.useHeaderAuth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> accountsRefs(
    Expression<bool> Function($$AccountsTableFilterComposer f) f,
  ) {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.serverId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ServersTableOrderingComposer
    extends Composer<_$AppDatabase, $ServersTable> {
  $$ServersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get trustSelfSignedCerts => $composableBuilder(
    column: $table.trustSelfSignedCerts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get useHeaderAuth => $composableBuilder(
    column: $table.useHeaderAuth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ServersTableAnnotationComposer
    extends Composer<_$AppDatabase, $ServersTable> {
  $$ServersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get trustSelfSignedCerts => $composableBuilder(
    column: $table.trustSelfSignedCerts,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get useHeaderAuth => $composableBuilder(
    column: $table.useHeaderAuth,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> accountsRefs<T extends Object>(
    Expression<T> Function($$AccountsTableAnnotationComposer a) f,
  ) {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.serverId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ServersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ServersTable,
          Server,
          $$ServersTableFilterComposer,
          $$ServersTableOrderingComposer,
          $$ServersTableAnnotationComposer,
          $$ServersTableCreateCompanionBuilder,
          $$ServersTableUpdateCompanionBuilder,
          (Server, $$ServersTableReferences),
          Server,
          PrefetchHooks Function({bool accountsRefs})
        > {
  $$ServersTableTableManager(_$AppDatabase db, $ServersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ServersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ServersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ServersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> trustSelfSignedCerts = const Value.absent(),
                Value<bool> useHeaderAuth = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ServersCompanion(
                id: id,
                url: url,
                name: name,
                trustSelfSignedCerts: trustSelfSignedCerts,
                useHeaderAuth: useHeaderAuth,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String url,
                required String name,
                Value<bool> trustSelfSignedCerts = const Value.absent(),
                Value<bool> useHeaderAuth = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ServersCompanion.insert(
                id: id,
                url: url,
                name: name,
                trustSelfSignedCerts: trustSelfSignedCerts,
                useHeaderAuth: useHeaderAuth,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ServersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({accountsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (accountsRefs) db.accounts],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (accountsRefs)
                    await $_getPrefetchedData<Server, $ServersTable, Account>(
                      currentTable: table,
                      referencedTable: $$ServersTableReferences
                          ._accountsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ServersTableReferences(db, table, p0).accountsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.serverId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ServersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ServersTable,
      Server,
      $$ServersTableFilterComposer,
      $$ServersTableOrderingComposer,
      $$ServersTableAnnotationComposer,
      $$ServersTableCreateCompanionBuilder,
      $$ServersTableUpdateCompanionBuilder,
      (Server, $$ServersTableReferences),
      Server,
      PrefetchHooks Function({bool accountsRefs})
    >;
typedef $$AccountsTableCreateCompanionBuilder =
    AccountsCompanion Function({
      required String id,
      required String serverId,
      required String userId,
      required String email,
      Value<String?> fingerprint,
      Value<String?> publicKey,
      Value<String?> wrappingPublicKey,
      Value<String?> encryptedPrivateKey,
      Value<String?> pinEncryptedPrivateKey,
      Value<String?> biometricPin,
      Value<int?> quota,
      Value<String?> role,
      Value<bool> isActive,
      Value<DateTime> createdAt,
      Value<DateTime?> lastUsedAt,
      Value<int?> cacheLimitBytes,
      Value<String?> headerJwt,
      Value<String?> headerRefreshToken,
      Value<int> rowid,
    });
typedef $$AccountsTableUpdateCompanionBuilder =
    AccountsCompanion Function({
      Value<String> id,
      Value<String> serverId,
      Value<String> userId,
      Value<String> email,
      Value<String?> fingerprint,
      Value<String?> publicKey,
      Value<String?> wrappingPublicKey,
      Value<String?> encryptedPrivateKey,
      Value<String?> pinEncryptedPrivateKey,
      Value<String?> biometricPin,
      Value<int?> quota,
      Value<String?> role,
      Value<bool> isActive,
      Value<DateTime> createdAt,
      Value<DateTime?> lastUsedAt,
      Value<int?> cacheLimitBytes,
      Value<String?> headerJwt,
      Value<String?> headerRefreshToken,
      Value<int> rowid,
    });

final class $$AccountsTableReferences
    extends BaseReferences<_$AppDatabase, $AccountsTable, Account> {
  $$AccountsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ServersTable _serverIdTable(_$AppDatabase db) => db.servers
      .createAlias($_aliasNameGenerator(db.accounts.serverId, db.servers.id));

  $$ServersTableProcessedTableManager get serverId {
    final $_column = $_itemColumn<String>('server_id')!;

    final manager = $$ServersTableTableManager(
      $_db,
      $_db.servers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_serverIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$CachedFilesTable, List<CachedFile>>
  _cachedFilesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.cachedFiles,
    aliasName: $_aliasNameGenerator(db.accounts.id, db.cachedFiles.accountId),
  );

  $$CachedFilesTableProcessedTableManager get cachedFilesRefs {
    final manager = $$CachedFilesTableTableManager(
      $_db,
      $_db.cachedFiles,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_cachedFilesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AccountsTableFilterComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get publicKey => $composableBuilder(
    column: $table.publicKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wrappingPublicKey => $composableBuilder(
    column: $table.wrappingPublicKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encryptedPrivateKey => $composableBuilder(
    column: $table.encryptedPrivateKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pinEncryptedPrivateKey => $composableBuilder(
    column: $table.pinEncryptedPrivateKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get biometricPin => $composableBuilder(
    column: $table.biometricPin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quota => $composableBuilder(
    column: $table.quota,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cacheLimitBytes => $composableBuilder(
    column: $table.cacheLimitBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get headerJwt => $composableBuilder(
    column: $table.headerJwt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<String?, String, String>
  get headerRefreshToken => $composableBuilder(
    column: $table.headerRefreshToken,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  $$ServersTableFilterComposer get serverId {
    final $$ServersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.serverId,
      referencedTable: $db.servers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ServersTableFilterComposer(
            $db: $db,
            $table: $db.servers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> cachedFilesRefs(
    Expression<bool> Function($$CachedFilesTableFilterComposer f) f,
  ) {
    final $$CachedFilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cachedFiles,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CachedFilesTableFilterComposer(
            $db: $db,
            $table: $db.cachedFiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get publicKey => $composableBuilder(
    column: $table.publicKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wrappingPublicKey => $composableBuilder(
    column: $table.wrappingPublicKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptedPrivateKey => $composableBuilder(
    column: $table.encryptedPrivateKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pinEncryptedPrivateKey => $composableBuilder(
    column: $table.pinEncryptedPrivateKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get biometricPin => $composableBuilder(
    column: $table.biometricPin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quota => $composableBuilder(
    column: $table.quota,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cacheLimitBytes => $composableBuilder(
    column: $table.cacheLimitBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get headerJwt => $composableBuilder(
    column: $table.headerJwt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get headerRefreshToken => $composableBuilder(
    column: $table.headerRefreshToken,
    builder: (column) => ColumnOrderings(column),
  );

  $$ServersTableOrderingComposer get serverId {
    final $$ServersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.serverId,
      referencedTable: $db.servers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ServersTableOrderingComposer(
            $db: $db,
            $table: $db.servers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<String> get publicKey =>
      $composableBuilder(column: $table.publicKey, builder: (column) => column);

  GeneratedColumn<String> get wrappingPublicKey => $composableBuilder(
    column: $table.wrappingPublicKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get encryptedPrivateKey => $composableBuilder(
    column: $table.encryptedPrivateKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pinEncryptedPrivateKey => $composableBuilder(
    column: $table.pinEncryptedPrivateKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get biometricPin => $composableBuilder(
    column: $table.biometricPin,
    builder: (column) => column,
  );

  GeneratedColumn<int> get quota =>
      $composableBuilder(column: $table.quota, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cacheLimitBytes => $composableBuilder(
    column: $table.cacheLimitBytes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get headerJwt =>
      $composableBuilder(column: $table.headerJwt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<String?, String> get headerRefreshToken =>
      $composableBuilder(
        column: $table.headerRefreshToken,
        builder: (column) => column,
      );

  $$ServersTableAnnotationComposer get serverId {
    final $$ServersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.serverId,
      referencedTable: $db.servers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ServersTableAnnotationComposer(
            $db: $db,
            $table: $db.servers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> cachedFilesRefs<T extends Object>(
    Expression<T> Function($$CachedFilesTableAnnotationComposer a) f,
  ) {
    final $$CachedFilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cachedFiles,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CachedFilesTableAnnotationComposer(
            $db: $db,
            $table: $db.cachedFiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AccountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AccountsTable,
          Account,
          $$AccountsTableFilterComposer,
          $$AccountsTableOrderingComposer,
          $$AccountsTableAnnotationComposer,
          $$AccountsTableCreateCompanionBuilder,
          $$AccountsTableUpdateCompanionBuilder,
          (Account, $$AccountsTableReferences),
          Account,
          PrefetchHooks Function({bool serverId, bool cachedFilesRefs})
        > {
  $$AccountsTableTableManager(_$AppDatabase db, $AccountsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> serverId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> email = const Value.absent(),
                Value<String?> fingerprint = const Value.absent(),
                Value<String?> publicKey = const Value.absent(),
                Value<String?> wrappingPublicKey = const Value.absent(),
                Value<String?> encryptedPrivateKey = const Value.absent(),
                Value<String?> pinEncryptedPrivateKey = const Value.absent(),
                Value<String?> biometricPin = const Value.absent(),
                Value<int?> quota = const Value.absent(),
                Value<String?> role = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> lastUsedAt = const Value.absent(),
                Value<int?> cacheLimitBytes = const Value.absent(),
                Value<String?> headerJwt = const Value.absent(),
                Value<String?> headerRefreshToken = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion(
                id: id,
                serverId: serverId,
                userId: userId,
                email: email,
                fingerprint: fingerprint,
                publicKey: publicKey,
                wrappingPublicKey: wrappingPublicKey,
                encryptedPrivateKey: encryptedPrivateKey,
                pinEncryptedPrivateKey: pinEncryptedPrivateKey,
                biometricPin: biometricPin,
                quota: quota,
                role: role,
                isActive: isActive,
                createdAt: createdAt,
                lastUsedAt: lastUsedAt,
                cacheLimitBytes: cacheLimitBytes,
                headerJwt: headerJwt,
                headerRefreshToken: headerRefreshToken,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String serverId,
                required String userId,
                required String email,
                Value<String?> fingerprint = const Value.absent(),
                Value<String?> publicKey = const Value.absent(),
                Value<String?> wrappingPublicKey = const Value.absent(),
                Value<String?> encryptedPrivateKey = const Value.absent(),
                Value<String?> pinEncryptedPrivateKey = const Value.absent(),
                Value<String?> biometricPin = const Value.absent(),
                Value<int?> quota = const Value.absent(),
                Value<String?> role = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> lastUsedAt = const Value.absent(),
                Value<int?> cacheLimitBytes = const Value.absent(),
                Value<String?> headerJwt = const Value.absent(),
                Value<String?> headerRefreshToken = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion.insert(
                id: id,
                serverId: serverId,
                userId: userId,
                email: email,
                fingerprint: fingerprint,
                publicKey: publicKey,
                wrappingPublicKey: wrappingPublicKey,
                encryptedPrivateKey: encryptedPrivateKey,
                pinEncryptedPrivateKey: pinEncryptedPrivateKey,
                biometricPin: biometricPin,
                quota: quota,
                role: role,
                isActive: isActive,
                createdAt: createdAt,
                lastUsedAt: lastUsedAt,
                cacheLimitBytes: cacheLimitBytes,
                headerJwt: headerJwt,
                headerRefreshToken: headerRefreshToken,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AccountsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({serverId = false, cachedFilesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (cachedFilesRefs) db.cachedFiles],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (serverId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.serverId,
                                referencedTable: $$AccountsTableReferences
                                    ._serverIdTable(db),
                                referencedColumn: $$AccountsTableReferences
                                    ._serverIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (cachedFilesRefs)
                    await $_getPrefetchedData<
                      Account,
                      $AccountsTable,
                      CachedFile
                    >(
                      currentTable: table,
                      referencedTable: $$AccountsTableReferences
                          ._cachedFilesRefsTable(db),
                      managerFromTypedResult: (p0) => $$AccountsTableReferences(
                        db,
                        table,
                        p0,
                      ).cachedFilesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.accountId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$AccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AccountsTable,
      Account,
      $$AccountsTableFilterComposer,
      $$AccountsTableOrderingComposer,
      $$AccountsTableAnnotationComposer,
      $$AccountsTableCreateCompanionBuilder,
      $$AccountsTableUpdateCompanionBuilder,
      (Account, $$AccountsTableReferences),
      Account,
      PrefetchHooks Function({bool serverId, bool cachedFilesRefs})
    >;
typedef $$CachedFilesTableCreateCompanionBuilder =
    CachedFilesCompanion Function({
      required String accountId,
      required String id,
      Value<String?> dirId,
      required String encryptedName,
      Value<String?> decryptedName,
      Value<String?> encryptedKey,
      Value<String?> encryptedThumbnail,
      required String mime,
      Value<int?> size,
      Value<int?> chunks,
      Value<int?> chunksStored,
      Value<String> cipher,
      Value<int?> fileModifiedAt,
      Value<int?> createdAt,
      Value<int?> finishedUploadAt,
      Value<CachePolicyType> cachePolicy,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });
typedef $$CachedFilesTableUpdateCompanionBuilder =
    CachedFilesCompanion Function({
      Value<String> accountId,
      Value<String> id,
      Value<String?> dirId,
      Value<String> encryptedName,
      Value<String?> decryptedName,
      Value<String?> encryptedKey,
      Value<String?> encryptedThumbnail,
      Value<String> mime,
      Value<int?> size,
      Value<int?> chunks,
      Value<int?> chunksStored,
      Value<String> cipher,
      Value<int?> fileModifiedAt,
      Value<int?> createdAt,
      Value<int?> finishedUploadAt,
      Value<CachePolicyType> cachePolicy,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });

final class $$CachedFilesTableReferences
    extends BaseReferences<_$AppDatabase, $CachedFilesTable, CachedFile> {
  $$CachedFilesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AccountsTable _accountIdTable(_$AppDatabase db) =>
      db.accounts.createAlias(
        $_aliasNameGenerator(db.cachedFiles.accountId, db.accounts.id),
      );

  $$AccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<String>('account_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CachedFilesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedFilesTable> {
  $$CachedFilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dirId => $composableBuilder(
    column: $table.dirId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encryptedName => $composableBuilder(
    column: $table.encryptedName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<String?, String, String> get decryptedName =>
      $composableBuilder(
        column: $table.decryptedName,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get encryptedKey => $composableBuilder(
    column: $table.encryptedKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encryptedThumbnail => $composableBuilder(
    column: $table.encryptedThumbnail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chunks => $composableBuilder(
    column: $table.chunks,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chunksStored => $composableBuilder(
    column: $table.chunksStored,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cipher => $composableBuilder(
    column: $table.cipher,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileModifiedAt => $composableBuilder(
    column: $table.fileModifiedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get finishedUploadAt => $composableBuilder(
    column: $table.finishedUploadAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<CachePolicyType, CachePolicyType, String>
  get cachePolicy => $composableBuilder(
    column: $table.cachePolicy,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CachedFilesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedFilesTable> {
  $$CachedFilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dirId => $composableBuilder(
    column: $table.dirId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptedName => $composableBuilder(
    column: $table.encryptedName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get decryptedName => $composableBuilder(
    column: $table.decryptedName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptedKey => $composableBuilder(
    column: $table.encryptedKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptedThumbnail => $composableBuilder(
    column: $table.encryptedThumbnail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chunks => $composableBuilder(
    column: $table.chunks,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chunksStored => $composableBuilder(
    column: $table.chunksStored,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cipher => $composableBuilder(
    column: $table.cipher,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileModifiedAt => $composableBuilder(
    column: $table.fileModifiedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get finishedUploadAt => $composableBuilder(
    column: $table.finishedUploadAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cachePolicy => $composableBuilder(
    column: $table.cachePolicy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CachedFilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedFilesTable> {
  $$CachedFilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get dirId =>
      $composableBuilder(column: $table.dirId, builder: (column) => column);

  GeneratedColumn<String> get encryptedName => $composableBuilder(
    column: $table.encryptedName,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<String?, String> get decryptedName =>
      $composableBuilder(
        column: $table.decryptedName,
        builder: (column) => column,
      );

  GeneratedColumn<String> get encryptedKey => $composableBuilder(
    column: $table.encryptedKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get encryptedThumbnail => $composableBuilder(
    column: $table.encryptedThumbnail,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mime =>
      $composableBuilder(column: $table.mime, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<int> get chunks =>
      $composableBuilder(column: $table.chunks, builder: (column) => column);

  GeneratedColumn<int> get chunksStored => $composableBuilder(
    column: $table.chunksStored,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cipher =>
      $composableBuilder(column: $table.cipher, builder: (column) => column);

  GeneratedColumn<int> get fileModifiedAt => $composableBuilder(
    column: $table.fileModifiedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get finishedUploadAt => $composableBuilder(
    column: $table.finishedUploadAt,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<CachePolicyType, String> get cachePolicy =>
      $composableBuilder(
        column: $table.cachePolicy,
        builder: (column) => column,
      );

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CachedFilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedFilesTable,
          CachedFile,
          $$CachedFilesTableFilterComposer,
          $$CachedFilesTableOrderingComposer,
          $$CachedFilesTableAnnotationComposer,
          $$CachedFilesTableCreateCompanionBuilder,
          $$CachedFilesTableUpdateCompanionBuilder,
          (CachedFile, $$CachedFilesTableReferences),
          CachedFile,
          PrefetchHooks Function({bool accountId})
        > {
  $$CachedFilesTableTableManager(_$AppDatabase db, $CachedFilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedFilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedFilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedFilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String?> dirId = const Value.absent(),
                Value<String> encryptedName = const Value.absent(),
                Value<String?> decryptedName = const Value.absent(),
                Value<String?> encryptedKey = const Value.absent(),
                Value<String?> encryptedThumbnail = const Value.absent(),
                Value<String> mime = const Value.absent(),
                Value<int?> size = const Value.absent(),
                Value<int?> chunks = const Value.absent(),
                Value<int?> chunksStored = const Value.absent(),
                Value<String> cipher = const Value.absent(),
                Value<int?> fileModifiedAt = const Value.absent(),
                Value<int?> createdAt = const Value.absent(),
                Value<int?> finishedUploadAt = const Value.absent(),
                Value<CachePolicyType> cachePolicy = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedFilesCompanion(
                accountId: accountId,
                id: id,
                dirId: dirId,
                encryptedName: encryptedName,
                decryptedName: decryptedName,
                encryptedKey: encryptedKey,
                encryptedThumbnail: encryptedThumbnail,
                mime: mime,
                size: size,
                chunks: chunks,
                chunksStored: chunksStored,
                cipher: cipher,
                fileModifiedAt: fileModifiedAt,
                createdAt: createdAt,
                finishedUploadAt: finishedUploadAt,
                cachePolicy: cachePolicy,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                required String id,
                Value<String?> dirId = const Value.absent(),
                required String encryptedName,
                Value<String?> decryptedName = const Value.absent(),
                Value<String?> encryptedKey = const Value.absent(),
                Value<String?> encryptedThumbnail = const Value.absent(),
                required String mime,
                Value<int?> size = const Value.absent(),
                Value<int?> chunks = const Value.absent(),
                Value<int?> chunksStored = const Value.absent(),
                Value<String> cipher = const Value.absent(),
                Value<int?> fileModifiedAt = const Value.absent(),
                Value<int?> createdAt = const Value.absent(),
                Value<int?> finishedUploadAt = const Value.absent(),
                Value<CachePolicyType> cachePolicy = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedFilesCompanion.insert(
                accountId: accountId,
                id: id,
                dirId: dirId,
                encryptedName: encryptedName,
                decryptedName: decryptedName,
                encryptedKey: encryptedKey,
                encryptedThumbnail: encryptedThumbnail,
                mime: mime,
                size: size,
                chunks: chunks,
                chunksStored: chunksStored,
                cipher: cipher,
                fileModifiedAt: fileModifiedAt,
                createdAt: createdAt,
                finishedUploadAt: finishedUploadAt,
                cachePolicy: cachePolicy,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CachedFilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({accountId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (accountId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.accountId,
                                referencedTable: $$CachedFilesTableReferences
                                    ._accountIdTable(db),
                                referencedColumn: $$CachedFilesTableReferences
                                    ._accountIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CachedFilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedFilesTable,
      CachedFile,
      $$CachedFilesTableFilterComposer,
      $$CachedFilesTableOrderingComposer,
      $$CachedFilesTableAnnotationComposer,
      $$CachedFilesTableCreateCompanionBuilder,
      $$CachedFilesTableUpdateCompanionBuilder,
      (CachedFile, $$CachedFilesTableReferences),
      CachedFile,
      PrefetchHooks Function({bool accountId})
    >;
typedef $$OfflineFilesTableCreateCompanionBuilder =
    OfflineFilesCompanion Function({
      required String accountId,
      required String fileId,
      required String localPath,
      Value<int> sizeOnDisk,
      Value<bool> pinned,
      Value<DateTime> downloadedAt,
      Value<DateTime> lastAccessedAt,
      Value<int> rowid,
    });
typedef $$OfflineFilesTableUpdateCompanionBuilder =
    OfflineFilesCompanion Function({
      Value<String> accountId,
      Value<String> fileId,
      Value<String> localPath,
      Value<int> sizeOnDisk,
      Value<bool> pinned,
      Value<DateTime> downloadedAt,
      Value<DateTime> lastAccessedAt,
      Value<int> rowid,
    });

class $$OfflineFilesTableFilterComposer
    extends Composer<_$AppDatabase, $OfflineFilesTable> {
  $$OfflineFilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileId => $composableBuilder(
    column: $table.fileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeOnDisk => $composableBuilder(
    column: $table.sizeOnDisk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OfflineFilesTableOrderingComposer
    extends Composer<_$AppDatabase, $OfflineFilesTable> {
  $$OfflineFilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileId => $composableBuilder(
    column: $table.fileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeOnDisk => $composableBuilder(
    column: $table.sizeOnDisk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OfflineFilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $OfflineFilesTable> {
  $$OfflineFilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get fileId =>
      $composableBuilder(column: $table.fileId, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<int> get sizeOnDisk => $composableBuilder(
    column: $table.sizeOnDisk,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get pinned =>
      $composableBuilder(column: $table.pinned, builder: (column) => column);

  GeneratedColumn<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => column,
  );
}

class $$OfflineFilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OfflineFilesTable,
          OfflineFile,
          $$OfflineFilesTableFilterComposer,
          $$OfflineFilesTableOrderingComposer,
          $$OfflineFilesTableAnnotationComposer,
          $$OfflineFilesTableCreateCompanionBuilder,
          $$OfflineFilesTableUpdateCompanionBuilder,
          (
            OfflineFile,
            BaseReferences<_$AppDatabase, $OfflineFilesTable, OfflineFile>,
          ),
          OfflineFile,
          PrefetchHooks Function()
        > {
  $$OfflineFilesTableTableManager(_$AppDatabase db, $OfflineFilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OfflineFilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OfflineFilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OfflineFilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<String> fileId = const Value.absent(),
                Value<String> localPath = const Value.absent(),
                Value<int> sizeOnDisk = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<DateTime> downloadedAt = const Value.absent(),
                Value<DateTime> lastAccessedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OfflineFilesCompanion(
                accountId: accountId,
                fileId: fileId,
                localPath: localPath,
                sizeOnDisk: sizeOnDisk,
                pinned: pinned,
                downloadedAt: downloadedAt,
                lastAccessedAt: lastAccessedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                required String fileId,
                required String localPath,
                Value<int> sizeOnDisk = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<DateTime> downloadedAt = const Value.absent(),
                Value<DateTime> lastAccessedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OfflineFilesCompanion.insert(
                accountId: accountId,
                fileId: fileId,
                localPath: localPath,
                sizeOnDisk: sizeOnDisk,
                pinned: pinned,
                downloadedAt: downloadedAt,
                lastAccessedAt: lastAccessedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OfflineFilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OfflineFilesTable,
      OfflineFile,
      $$OfflineFilesTableFilterComposer,
      $$OfflineFilesTableOrderingComposer,
      $$OfflineFilesTableAnnotationComposer,
      $$OfflineFilesTableCreateCompanionBuilder,
      $$OfflineFilesTableUpdateCompanionBuilder,
      (
        OfflineFile,
        BaseReferences<_$AppDatabase, $OfflineFilesTable, OfflineFile>,
      ),
      OfflineFile,
      PrefetchHooks Function()
    >;
typedef $$PendingUploadsTableCreateCompanionBuilder =
    PendingUploadsCompanion Function({
      Value<int> id,
      required String accountId,
      required String localPath,
      Value<String?> targetDirId,
      Value<String> status,
      Value<int> retryCount,
      Value<DateTime?> nextRetryAt,
      Value<DateTime> createdAt,
    });
typedef $$PendingUploadsTableUpdateCompanionBuilder =
    PendingUploadsCompanion Function({
      Value<int> id,
      Value<String> accountId,
      Value<String> localPath,
      Value<String?> targetDirId,
      Value<String> status,
      Value<int> retryCount,
      Value<DateTime?> nextRetryAt,
      Value<DateTime> createdAt,
    });

class $$PendingUploadsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingUploadsTable> {
  $$PendingUploadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetDirId => $composableBuilder(
    column: $table.targetDirId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingUploadsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingUploadsTable> {
  $$PendingUploadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetDirId => $composableBuilder(
    column: $table.targetDirId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingUploadsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingUploadsTable> {
  $$PendingUploadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get targetDirId => $composableBuilder(
    column: $table.targetDirId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PendingUploadsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingUploadsTable,
          PendingUpload,
          $$PendingUploadsTableFilterComposer,
          $$PendingUploadsTableOrderingComposer,
          $$PendingUploadsTableAnnotationComposer,
          $$PendingUploadsTableCreateCompanionBuilder,
          $$PendingUploadsTableUpdateCompanionBuilder,
          (
            PendingUpload,
            BaseReferences<_$AppDatabase, $PendingUploadsTable, PendingUpload>,
          ),
          PendingUpload,
          PrefetchHooks Function()
        > {
  $$PendingUploadsTableTableManager(
    _$AppDatabase db,
    $PendingUploadsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingUploadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingUploadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingUploadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> localPath = const Value.absent(),
                Value<String?> targetDirId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<DateTime?> nextRetryAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => PendingUploadsCompanion(
                id: id,
                accountId: accountId,
                localPath: localPath,
                targetDirId: targetDirId,
                status: status,
                retryCount: retryCount,
                nextRetryAt: nextRetryAt,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String accountId,
                required String localPath,
                Value<String?> targetDirId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<DateTime?> nextRetryAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => PendingUploadsCompanion.insert(
                id: id,
                accountId: accountId,
                localPath: localPath,
                targetDirId: targetDirId,
                status: status,
                retryCount: retryCount,
                nextRetryAt: nextRetryAt,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingUploadsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingUploadsTable,
      PendingUpload,
      $$PendingUploadsTableFilterComposer,
      $$PendingUploadsTableOrderingComposer,
      $$PendingUploadsTableAnnotationComposer,
      $$PendingUploadsTableCreateCompanionBuilder,
      $$PendingUploadsTableUpdateCompanionBuilder,
      (
        PendingUpload,
        BaseReferences<_$AppDatabase, $PendingUploadsTable, PendingUpload>,
      ),
      PendingUpload,
      PrefetchHooks Function()
    >;
typedef $$McpSettingsTableCreateCompanionBuilder =
    McpSettingsCompanion Function({
      required String accountId,
      Value<bool> enabled,
      Value<int> port,
      Value<String> bearerToken,
      Value<DateTime> createdAt,
      Value<bool> allowReadOnlyWhileLocked,
      Value<int> rateLimitRps,
      Value<int> rateLimitBurst,
      Value<int> auditRetentionDays,
      Value<DateTime?> lastAuditCleanupAt,
      Value<int> rowid,
    });
typedef $$McpSettingsTableUpdateCompanionBuilder =
    McpSettingsCompanion Function({
      Value<String> accountId,
      Value<bool> enabled,
      Value<int> port,
      Value<String> bearerToken,
      Value<DateTime> createdAt,
      Value<bool> allowReadOnlyWhileLocked,
      Value<int> rateLimitRps,
      Value<int> rateLimitBurst,
      Value<int> auditRetentionDays,
      Value<DateTime?> lastAuditCleanupAt,
      Value<int> rowid,
    });

class $$McpSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $McpSettingsTable> {
  $$McpSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get port => $composableBuilder(
    column: $table.port,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bearerToken => $composableBuilder(
    column: $table.bearerToken,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get allowReadOnlyWhileLocked => $composableBuilder(
    column: $table.allowReadOnlyWhileLocked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rateLimitRps => $composableBuilder(
    column: $table.rateLimitRps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rateLimitBurst => $composableBuilder(
    column: $table.rateLimitBurst,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get auditRetentionDays => $composableBuilder(
    column: $table.auditRetentionDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAuditCleanupAt => $composableBuilder(
    column: $table.lastAuditCleanupAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$McpSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $McpSettingsTable> {
  $$McpSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get port => $composableBuilder(
    column: $table.port,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bearerToken => $composableBuilder(
    column: $table.bearerToken,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get allowReadOnlyWhileLocked => $composableBuilder(
    column: $table.allowReadOnlyWhileLocked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rateLimitRps => $composableBuilder(
    column: $table.rateLimitRps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rateLimitBurst => $composableBuilder(
    column: $table.rateLimitBurst,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get auditRetentionDays => $composableBuilder(
    column: $table.auditRetentionDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAuditCleanupAt => $composableBuilder(
    column: $table.lastAuditCleanupAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$McpSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $McpSettingsTable> {
  $$McpSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<int> get port =>
      $composableBuilder(column: $table.port, builder: (column) => column);

  GeneratedColumn<String> get bearerToken => $composableBuilder(
    column: $table.bearerToken,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get allowReadOnlyWhileLocked => $composableBuilder(
    column: $table.allowReadOnlyWhileLocked,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rateLimitRps => $composableBuilder(
    column: $table.rateLimitRps,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rateLimitBurst => $composableBuilder(
    column: $table.rateLimitBurst,
    builder: (column) => column,
  );

  GeneratedColumn<int> get auditRetentionDays => $composableBuilder(
    column: $table.auditRetentionDays,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastAuditCleanupAt => $composableBuilder(
    column: $table.lastAuditCleanupAt,
    builder: (column) => column,
  );
}

class $$McpSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $McpSettingsTable,
          McpSetting,
          $$McpSettingsTableFilterComposer,
          $$McpSettingsTableOrderingComposer,
          $$McpSettingsTableAnnotationComposer,
          $$McpSettingsTableCreateCompanionBuilder,
          $$McpSettingsTableUpdateCompanionBuilder,
          (
            McpSetting,
            BaseReferences<_$AppDatabase, $McpSettingsTable, McpSetting>,
          ),
          McpSetting,
          PrefetchHooks Function()
        > {
  $$McpSettingsTableTableManager(_$AppDatabase db, $McpSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$McpSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$McpSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$McpSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> port = const Value.absent(),
                Value<String> bearerToken = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<bool> allowReadOnlyWhileLocked = const Value.absent(),
                Value<int> rateLimitRps = const Value.absent(),
                Value<int> rateLimitBurst = const Value.absent(),
                Value<int> auditRetentionDays = const Value.absent(),
                Value<DateTime?> lastAuditCleanupAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => McpSettingsCompanion(
                accountId: accountId,
                enabled: enabled,
                port: port,
                bearerToken: bearerToken,
                createdAt: createdAt,
                allowReadOnlyWhileLocked: allowReadOnlyWhileLocked,
                rateLimitRps: rateLimitRps,
                rateLimitBurst: rateLimitBurst,
                auditRetentionDays: auditRetentionDays,
                lastAuditCleanupAt: lastAuditCleanupAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                Value<bool> enabled = const Value.absent(),
                Value<int> port = const Value.absent(),
                Value<String> bearerToken = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<bool> allowReadOnlyWhileLocked = const Value.absent(),
                Value<int> rateLimitRps = const Value.absent(),
                Value<int> rateLimitBurst = const Value.absent(),
                Value<int> auditRetentionDays = const Value.absent(),
                Value<DateTime?> lastAuditCleanupAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => McpSettingsCompanion.insert(
                accountId: accountId,
                enabled: enabled,
                port: port,
                bearerToken: bearerToken,
                createdAt: createdAt,
                allowReadOnlyWhileLocked: allowReadOnlyWhileLocked,
                rateLimitRps: rateLimitRps,
                rateLimitBurst: rateLimitBurst,
                auditRetentionDays: auditRetentionDays,
                lastAuditCleanupAt: lastAuditCleanupAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$McpSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $McpSettingsTable,
      McpSetting,
      $$McpSettingsTableFilterComposer,
      $$McpSettingsTableOrderingComposer,
      $$McpSettingsTableAnnotationComposer,
      $$McpSettingsTableCreateCompanionBuilder,
      $$McpSettingsTableUpdateCompanionBuilder,
      (
        McpSetting,
        BaseReferences<_$AppDatabase, $McpSettingsTable, McpSetting>,
      ),
      McpSetting,
      PrefetchHooks Function()
    >;
typedef $$McpAuditLogTableCreateCompanionBuilder =
    McpAuditLogCompanion Function({
      Value<int> id,
      required DateTime timestamp,
      required String sessionId,
      Value<String?> accountId,
      required String toolName,
      required String paramsHash,
      required String resultStatus,
      Value<String?> errorMessage,
      required int durationMs,
    });
typedef $$McpAuditLogTableUpdateCompanionBuilder =
    McpAuditLogCompanion Function({
      Value<int> id,
      Value<DateTime> timestamp,
      Value<String> sessionId,
      Value<String?> accountId,
      Value<String> toolName,
      Value<String> paramsHash,
      Value<String> resultStatus,
      Value<String?> errorMessage,
      Value<int> durationMs,
    });

class $$McpAuditLogTableFilterComposer
    extends Composer<_$AppDatabase, $McpAuditLogTable> {
  $$McpAuditLogTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toolName => $composableBuilder(
    column: $table.toolName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paramsHash => $composableBuilder(
    column: $table.paramsHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resultStatus => $composableBuilder(
    column: $table.resultStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$McpAuditLogTableOrderingComposer
    extends Composer<_$AppDatabase, $McpAuditLogTable> {
  $$McpAuditLogTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toolName => $composableBuilder(
    column: $table.toolName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paramsHash => $composableBuilder(
    column: $table.paramsHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resultStatus => $composableBuilder(
    column: $table.resultStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$McpAuditLogTableAnnotationComposer
    extends Composer<_$AppDatabase, $McpAuditLogTable> {
  $$McpAuditLogTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get toolName =>
      $composableBuilder(column: $table.toolName, builder: (column) => column);

  GeneratedColumn<String> get paramsHash => $composableBuilder(
    column: $table.paramsHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resultStatus => $composableBuilder(
    column: $table.resultStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );
}

class $$McpAuditLogTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $McpAuditLogTable,
          McpAuditLogData,
          $$McpAuditLogTableFilterComposer,
          $$McpAuditLogTableOrderingComposer,
          $$McpAuditLogTableAnnotationComposer,
          $$McpAuditLogTableCreateCompanionBuilder,
          $$McpAuditLogTableUpdateCompanionBuilder,
          (
            McpAuditLogData,
            BaseReferences<_$AppDatabase, $McpAuditLogTable, McpAuditLogData>,
          ),
          McpAuditLogData,
          PrefetchHooks Function()
        > {
  $$McpAuditLogTableTableManager(_$AppDatabase db, $McpAuditLogTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$McpAuditLogTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$McpAuditLogTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$McpAuditLogTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String?> accountId = const Value.absent(),
                Value<String> toolName = const Value.absent(),
                Value<String> paramsHash = const Value.absent(),
                Value<String> resultStatus = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
              }) => McpAuditLogCompanion(
                id: id,
                timestamp: timestamp,
                sessionId: sessionId,
                accountId: accountId,
                toolName: toolName,
                paramsHash: paramsHash,
                resultStatus: resultStatus,
                errorMessage: errorMessage,
                durationMs: durationMs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime timestamp,
                required String sessionId,
                Value<String?> accountId = const Value.absent(),
                required String toolName,
                required String paramsHash,
                required String resultStatus,
                Value<String?> errorMessage = const Value.absent(),
                required int durationMs,
              }) => McpAuditLogCompanion.insert(
                id: id,
                timestamp: timestamp,
                sessionId: sessionId,
                accountId: accountId,
                toolName: toolName,
                paramsHash: paramsHash,
                resultStatus: resultStatus,
                errorMessage: errorMessage,
                durationMs: durationMs,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$McpAuditLogTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $McpAuditLogTable,
      McpAuditLogData,
      $$McpAuditLogTableFilterComposer,
      $$McpAuditLogTableOrderingComposer,
      $$McpAuditLogTableAnnotationComposer,
      $$McpAuditLogTableCreateCompanionBuilder,
      $$McpAuditLogTableUpdateCompanionBuilder,
      (
        McpAuditLogData,
        BaseReferences<_$AppDatabase, $McpAuditLogTable, McpAuditLogData>,
      ),
      McpAuditLogData,
      PrefetchHooks Function()
    >;
typedef $$TrustedFingerprintsTableCreateCompanionBuilder =
    TrustedFingerprintsCompanion Function({
      required String ownerUserId,
      required String userId,
      required String fingerprint,
      Value<String?> email,
      Value<DateTime?> lastVerifiedAt,
      Value<String> verificationMethod,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$TrustedFingerprintsTableUpdateCompanionBuilder =
    TrustedFingerprintsCompanion Function({
      Value<String> ownerUserId,
      Value<String> userId,
      Value<String> fingerprint,
      Value<String?> email,
      Value<DateTime?> lastVerifiedAt,
      Value<String> verificationMethod,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$TrustedFingerprintsTableFilterComposer
    extends Composer<_$AppDatabase, $TrustedFingerprintsTable> {
  $$TrustedFingerprintsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastVerifiedAt => $composableBuilder(
    column: $table.lastVerifiedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get verificationMethod => $composableBuilder(
    column: $table.verificationMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TrustedFingerprintsTableOrderingComposer
    extends Composer<_$AppDatabase, $TrustedFingerprintsTable> {
  $$TrustedFingerprintsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastVerifiedAt => $composableBuilder(
    column: $table.lastVerifiedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get verificationMethod => $composableBuilder(
    column: $table.verificationMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TrustedFingerprintsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TrustedFingerprintsTable> {
  $$TrustedFingerprintsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<DateTime> get lastVerifiedAt => $composableBuilder(
    column: $table.lastVerifiedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get verificationMethod => $composableBuilder(
    column: $table.verificationMethod,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$TrustedFingerprintsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TrustedFingerprintsTable,
          TrustedFingerprint,
          $$TrustedFingerprintsTableFilterComposer,
          $$TrustedFingerprintsTableOrderingComposer,
          $$TrustedFingerprintsTableAnnotationComposer,
          $$TrustedFingerprintsTableCreateCompanionBuilder,
          $$TrustedFingerprintsTableUpdateCompanionBuilder,
          (
            TrustedFingerprint,
            BaseReferences<
              _$AppDatabase,
              $TrustedFingerprintsTable,
              TrustedFingerprint
            >,
          ),
          TrustedFingerprint,
          PrefetchHooks Function()
        > {
  $$TrustedFingerprintsTableTableManager(
    _$AppDatabase db,
    $TrustedFingerprintsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrustedFingerprintsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrustedFingerprintsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$TrustedFingerprintsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> ownerUserId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> fingerprint = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<DateTime?> lastVerifiedAt = const Value.absent(),
                Value<String> verificationMethod = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrustedFingerprintsCompanion(
                ownerUserId: ownerUserId,
                userId: userId,
                fingerprint: fingerprint,
                email: email,
                lastVerifiedAt: lastVerifiedAt,
                verificationMethod: verificationMethod,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ownerUserId,
                required String userId,
                required String fingerprint,
                Value<String?> email = const Value.absent(),
                Value<DateTime?> lastVerifiedAt = const Value.absent(),
                Value<String> verificationMethod = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrustedFingerprintsCompanion.insert(
                ownerUserId: ownerUserId,
                userId: userId,
                fingerprint: fingerprint,
                email: email,
                lastVerifiedAt: lastVerifiedAt,
                verificationMethod: verificationMethod,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TrustedFingerprintsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TrustedFingerprintsTable,
      TrustedFingerprint,
      $$TrustedFingerprintsTableFilterComposer,
      $$TrustedFingerprintsTableOrderingComposer,
      $$TrustedFingerprintsTableAnnotationComposer,
      $$TrustedFingerprintsTableCreateCompanionBuilder,
      $$TrustedFingerprintsTableUpdateCompanionBuilder,
      (
        TrustedFingerprint,
        BaseReferences<
          _$AppDatabase,
          $TrustedFingerprintsTable,
          TrustedFingerprint
        >,
      ),
      TrustedFingerprint,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ServersTableTableManager get servers =>
      $$ServersTableTableManager(_db, _db.servers);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db, _db.accounts);
  $$CachedFilesTableTableManager get cachedFiles =>
      $$CachedFilesTableTableManager(_db, _db.cachedFiles);
  $$OfflineFilesTableTableManager get offlineFiles =>
      $$OfflineFilesTableTableManager(_db, _db.offlineFiles);
  $$PendingUploadsTableTableManager get pendingUploads =>
      $$PendingUploadsTableTableManager(_db, _db.pendingUploads);
  $$McpSettingsTableTableManager get mcpSettings =>
      $$McpSettingsTableTableManager(_db, _db.mcpSettings);
  $$McpAuditLogTableTableManager get mcpAuditLog =>
      $$McpAuditLogTableTableManager(_db, _db.mcpAuditLog);
  $$TrustedFingerprintsTableTableManager get trustedFingerprints =>
      $$TrustedFingerprintsTableTableManager(_db, _db.trustedFingerprints);
}
