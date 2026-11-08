// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tone_database.dart';

// ignore_for_file: type=lint
class $ArtistsTable extends Artists with TableInfo<$ArtistsTable, Artist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ArtistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _normalizedNameMeta = const VerificationMeta(
    'normalizedName',
  );
  @override
  late final GeneratedColumn<String> normalizedName = GeneratedColumn<String>(
    'normalized_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, normalizedName];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'artists';
  @override
  VerificationContext validateIntegrity(
    Insertable<Artist> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('normalized_name')) {
      context.handle(
        _normalizedNameMeta,
        normalizedName.isAcceptableOrUnknown(
          data['normalized_name']!,
          _normalizedNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_normalizedNameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Artist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Artist(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      normalizedName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_name'],
      )!,
    );
  }

  @override
  $ArtistsTable createAlias(String alias) {
    return $ArtistsTable(attachedDatabase, alias);
  }
}

class Artist extends DataClass implements Insertable<Artist> {
  final String id;
  final String name;
  final String normalizedName;
  const Artist({
    required this.id,
    required this.name,
    required this.normalizedName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['normalized_name'] = Variable<String>(normalizedName);
    return map;
  }

  ArtistsCompanion toCompanion(bool nullToAbsent) {
    return ArtistsCompanion(
      id: Value(id),
      name: Value(name),
      normalizedName: Value(normalizedName),
    );
  }

  factory Artist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Artist(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      normalizedName: serializer.fromJson<String>(json['normalizedName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'normalizedName': serializer.toJson<String>(normalizedName),
    };
  }

  Artist copyWith({String? id, String? name, String? normalizedName}) => Artist(
    id: id ?? this.id,
    name: name ?? this.name,
    normalizedName: normalizedName ?? this.normalizedName,
  );
  Artist copyWithCompanion(ArtistsCompanion data) {
    return Artist(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      normalizedName: data.normalizedName.present
          ? data.normalizedName.value
          : this.normalizedName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Artist(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, normalizedName);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Artist &&
          other.id == this.id &&
          other.name == this.name &&
          other.normalizedName == this.normalizedName);
}

class ArtistsCompanion extends UpdateCompanion<Artist> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> normalizedName;
  final Value<int> rowid;
  const ArtistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.normalizedName = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ArtistsCompanion.insert({
    required String id,
    required String name,
    required String normalizedName,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       normalizedName = Value(normalizedName);
  static Insertable<Artist> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? normalizedName,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (normalizedName != null) 'normalized_name': normalizedName,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ArtistsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? normalizedName,
    Value<int>? rowid,
  }) {
    return ArtistsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (normalizedName.present) {
      map['normalized_name'] = Variable<String>(normalizedName.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ArtistsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AlbumsTable extends Albums with TableInfo<$AlbumsTable, Album> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AlbumsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistIdMeta = const VerificationMeta(
    'artistId',
  );
  @override
  late final GeneratedColumn<String> artistId = GeneratedColumn<String>(
    'artist_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES artists (id)',
    ),
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _artworkUriMeta = const VerificationMeta(
    'artworkUri',
  );
  @override
  late final GeneratedColumn<String> artworkUri = GeneratedColumn<String>(
    'artwork_uri',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, title, artistId, year, artworkUri];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'albums';
  @override
  VerificationContext validateIntegrity(
    Insertable<Album> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist_id')) {
      context.handle(
        _artistIdMeta,
        artistId.isAcceptableOrUnknown(data['artist_id']!, _artistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_artistIdMeta);
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('artwork_uri')) {
      context.handle(
        _artworkUriMeta,
        artworkUri.isAcceptableOrUnknown(data['artwork_uri']!, _artworkUriMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Album map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Album(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      artistId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist_id'],
      )!,
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      artworkUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artwork_uri'],
      ),
    );
  }

  @override
  $AlbumsTable createAlias(String alias) {
    return $AlbumsTable(attachedDatabase, alias);
  }
}

class Album extends DataClass implements Insertable<Album> {
  final String id;
  final String title;
  final String artistId;
  final int? year;
  final String? artworkUri;
  const Album({
    required this.id,
    required this.title,
    required this.artistId,
    this.year,
    this.artworkUri,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['artist_id'] = Variable<String>(artistId);
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || artworkUri != null) {
      map['artwork_uri'] = Variable<String>(artworkUri);
    }
    return map;
  }

  AlbumsCompanion toCompanion(bool nullToAbsent) {
    return AlbumsCompanion(
      id: Value(id),
      title: Value(title),
      artistId: Value(artistId),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      artworkUri: artworkUri == null && nullToAbsent
          ? const Value.absent()
          : Value(artworkUri),
    );
  }

  factory Album.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Album(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      artistId: serializer.fromJson<String>(json['artistId']),
      year: serializer.fromJson<int?>(json['year']),
      artworkUri: serializer.fromJson<String?>(json['artworkUri']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'artistId': serializer.toJson<String>(artistId),
      'year': serializer.toJson<int?>(year),
      'artworkUri': serializer.toJson<String?>(artworkUri),
    };
  }

  Album copyWith({
    String? id,
    String? title,
    String? artistId,
    Value<int?> year = const Value.absent(),
    Value<String?> artworkUri = const Value.absent(),
  }) => Album(
    id: id ?? this.id,
    title: title ?? this.title,
    artistId: artistId ?? this.artistId,
    year: year.present ? year.value : this.year,
    artworkUri: artworkUri.present ? artworkUri.value : this.artworkUri,
  );
  Album copyWithCompanion(AlbumsCompanion data) {
    return Album(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      artistId: data.artistId.present ? data.artistId.value : this.artistId,
      year: data.year.present ? data.year.value : this.year,
      artworkUri: data.artworkUri.present
          ? data.artworkUri.value
          : this.artworkUri,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Album(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('artistId: $artistId, ')
          ..write('year: $year, ')
          ..write('artworkUri: $artworkUri')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, artistId, year, artworkUri);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Album &&
          other.id == this.id &&
          other.title == this.title &&
          other.artistId == this.artistId &&
          other.year == this.year &&
          other.artworkUri == this.artworkUri);
}

class AlbumsCompanion extends UpdateCompanion<Album> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> artistId;
  final Value<int?> year;
  final Value<String?> artworkUri;
  final Value<int> rowid;
  const AlbumsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.artistId = const Value.absent(),
    this.year = const Value.absent(),
    this.artworkUri = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AlbumsCompanion.insert({
    required String id,
    required String title,
    required String artistId,
    this.year = const Value.absent(),
    this.artworkUri = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       artistId = Value(artistId);
  static Insertable<Album> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? artistId,
    Expression<int>? year,
    Expression<String>? artworkUri,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (artistId != null) 'artist_id': artistId,
      if (year != null) 'year': year,
      if (artworkUri != null) 'artwork_uri': artworkUri,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AlbumsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? artistId,
    Value<int?>? year,
    Value<String?>? artworkUri,
    Value<int>? rowid,
  }) {
    return AlbumsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      artistId: artistId ?? this.artistId,
      year: year ?? this.year,
      artworkUri: artworkUri ?? this.artworkUri,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artistId.present) {
      map['artist_id'] = Variable<String>(artistId.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (artworkUri.present) {
      map['artwork_uri'] = Variable<String>(artworkUri.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AlbumsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('artistId: $artistId, ')
          ..write('year: $year, ')
          ..write('artworkUri: $artworkUri, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LibraryTracksTable extends LibraryTracks
    with TableInfo<$LibraryTracksTable, LibraryTrack> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibraryTracksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceNameMeta = const VerificationMeta(
    'sourceName',
  );
  @override
  late final GeneratedColumn<String> sourceName = GeneratedColumn<String>(
    'source_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
    'artist',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _albumMeta = const VerificationMeta('album');
  @override
  late final GeneratedColumn<String> album = GeneratedColumn<String>(
    'album',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistIdMeta = const VerificationMeta(
    'artistId',
  );
  @override
  late final GeneratedColumn<String> artistId = GeneratedColumn<String>(
    'artist_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES artists (id)',
    ),
  );
  static const VerificationMeta _albumIdMeta = const VerificationMeta(
    'albumId',
  );
  @override
  late final GeneratedColumn<String> albumId = GeneratedColumn<String>(
    'album_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES albums (id)',
    ),
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _artworkUriMeta = const VerificationMeta(
    'artworkUri',
  );
  @override
  late final GeneratedColumn<String> artworkUri = GeneratedColumn<String>(
    'artwork_uri',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trackNumberMeta = const VerificationMeta(
    'trackNumber',
  );
  @override
  late final GeneratedColumn<int> trackNumber = GeneratedColumn<int>(
    'track_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _genreMeta = const VerificationMeta('genre');
  @override
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
    'genre',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bpmMeta = const VerificationMeta('bpm');
  @override
  late final GeneratedColumn<double> bpm = GeneratedColumn<double>(
    'bpm',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDeviceMediaMeta = const VerificationMeta(
    'isDeviceMedia',
  );
  @override
  late final GeneratedColumn<bool> isDeviceMedia = GeneratedColumn<bool>(
    'is_device_media',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_device_media" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sourceFolderUriMeta = const VerificationMeta(
    'sourceFolderUri',
  );
  @override
  late final GeneratedColumn<String> sourceFolderUri = GeneratedColumn<String>(
    'source_folder_uri',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lyricsUriMeta = const VerificationMeta(
    'lyricsUri',
  );
  @override
  late final GeneratedColumn<String> lyricsUri = GeneratedColumn<String>(
    'lyrics_uri',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceProviderMeta = const VerificationMeta(
    'sourceProvider',
  );
  @override
  late final GeneratedColumn<String> sourceProvider = GeneratedColumn<String>(
    'source_provider',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _providerTrackIdMeta = const VerificationMeta(
    'providerTrackId',
  );
  @override
  late final GeneratedColumn<String> providerTrackId = GeneratedColumn<String>(
    'provider_track_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _licenseUrlMeta = const VerificationMeta(
    'licenseUrl',
  );
  @override
  late final GeneratedColumn<String> licenseUrl = GeneratedColumn<String>(
    'license_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metadataReviewedMeta = const VerificationMeta(
    'metadataReviewed',
  );
  @override
  late final GeneratedColumn<bool> metadataReviewed = GeneratedColumn<bool>(
    'metadata_reviewed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("metadata_reviewed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isAvailableMeta = const VerificationMeta(
    'isAvailable',
  );
  @override
  late final GeneratedColumn<bool> isAvailable = GeneratedColumn<bool>(
    'is_available',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_available" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSeenAtMeta = const VerificationMeta(
    'lastSeenAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSeenAt = GeneratedColumn<DateTime>(
    'last_seen_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fileSizeBytesMeta = const VerificationMeta(
    'fileSizeBytes',
  );
  @override
  late final GeneratedColumn<int> fileSizeBytes = GeneratedColumn<int>(
    'file_size_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fileModifiedAtMeta = const VerificationMeta(
    'fileModifiedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fileModifiedAt =
      GeneratedColumn<DateTime>(
        'file_modified_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    path,
    sourceName,
    title,
    artist,
    album,
    artistId,
    albumId,
    durationMs,
    artworkUri,
    year,
    trackNumber,
    genre,
    bpm,
    isDeviceMedia,
    sourceFolderUri,
    lyricsUri,
    sourceProvider,
    providerTrackId,
    licenseUrl,
    metadataReviewed,
    isAvailable,
    position,
    lastSeenAt,
    fileSizeBytes,
    fileModifiedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_tracks';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibraryTrack> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('source_name')) {
      context.handle(
        _sourceNameMeta,
        sourceName.isAcceptableOrUnknown(data['source_name']!, _sourceNameMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(
        _artistMeta,
        artist.isAcceptableOrUnknown(data['artist']!, _artistMeta),
      );
    } else if (isInserting) {
      context.missing(_artistMeta);
    }
    if (data.containsKey('album')) {
      context.handle(
        _albumMeta,
        album.isAcceptableOrUnknown(data['album']!, _albumMeta),
      );
    } else if (isInserting) {
      context.missing(_albumMeta);
    }
    if (data.containsKey('artist_id')) {
      context.handle(
        _artistIdMeta,
        artistId.isAcceptableOrUnknown(data['artist_id']!, _artistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_artistIdMeta);
    }
    if (data.containsKey('album_id')) {
      context.handle(
        _albumIdMeta,
        albumId.isAcceptableOrUnknown(data['album_id']!, _albumIdMeta),
      );
    } else if (isInserting) {
      context.missing(_albumIdMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('artwork_uri')) {
      context.handle(
        _artworkUriMeta,
        artworkUri.isAcceptableOrUnknown(data['artwork_uri']!, _artworkUriMeta),
      );
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('track_number')) {
      context.handle(
        _trackNumberMeta,
        trackNumber.isAcceptableOrUnknown(
          data['track_number']!,
          _trackNumberMeta,
        ),
      );
    }
    if (data.containsKey('genre')) {
      context.handle(
        _genreMeta,
        genre.isAcceptableOrUnknown(data['genre']!, _genreMeta),
      );
    }
    if (data.containsKey('bpm')) {
      context.handle(
        _bpmMeta,
        bpm.isAcceptableOrUnknown(data['bpm']!, _bpmMeta),
      );
    }
    if (data.containsKey('is_device_media')) {
      context.handle(
        _isDeviceMediaMeta,
        isDeviceMedia.isAcceptableOrUnknown(
          data['is_device_media']!,
          _isDeviceMediaMeta,
        ),
      );
    }
    if (data.containsKey('source_folder_uri')) {
      context.handle(
        _sourceFolderUriMeta,
        sourceFolderUri.isAcceptableOrUnknown(
          data['source_folder_uri']!,
          _sourceFolderUriMeta,
        ),
      );
    }
    if (data.containsKey('lyrics_uri')) {
      context.handle(
        _lyricsUriMeta,
        lyricsUri.isAcceptableOrUnknown(data['lyrics_uri']!, _lyricsUriMeta),
      );
    }
    if (data.containsKey('source_provider')) {
      context.handle(
        _sourceProviderMeta,
        sourceProvider.isAcceptableOrUnknown(
          data['source_provider']!,
          _sourceProviderMeta,
        ),
      );
    }
    if (data.containsKey('provider_track_id')) {
      context.handle(
        _providerTrackIdMeta,
        providerTrackId.isAcceptableOrUnknown(
          data['provider_track_id']!,
          _providerTrackIdMeta,
        ),
      );
    }
    if (data.containsKey('license_url')) {
      context.handle(
        _licenseUrlMeta,
        licenseUrl.isAcceptableOrUnknown(data['license_url']!, _licenseUrlMeta),
      );
    }
    if (data.containsKey('metadata_reviewed')) {
      context.handle(
        _metadataReviewedMeta,
        metadataReviewed.isAcceptableOrUnknown(
          data['metadata_reviewed']!,
          _metadataReviewedMeta,
        ),
      );
    }
    if (data.containsKey('is_available')) {
      context.handle(
        _isAvailableMeta,
        isAvailable.isAcceptableOrUnknown(
          data['is_available']!,
          _isAvailableMeta,
        ),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
        _lastSeenAtMeta,
        lastSeenAt.isAcceptableOrUnknown(
          data['last_seen_at']!,
          _lastSeenAtMeta,
        ),
      );
    }
    if (data.containsKey('file_size_bytes')) {
      context.handle(
        _fileSizeBytesMeta,
        fileSizeBytes.isAcceptableOrUnknown(
          data['file_size_bytes']!,
          _fileSizeBytesMeta,
        ),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LibraryTrack map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibraryTrack(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      sourceName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_name'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      artist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist'],
      )!,
      album: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album'],
      )!,
      artistId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist_id'],
      )!,
      albumId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_id'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      artworkUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artwork_uri'],
      ),
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      trackNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_number'],
      ),
      genre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genre'],
      ),
      bpm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}bpm'],
      ),
      isDeviceMedia: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_device_media'],
      )!,
      sourceFolderUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_folder_uri'],
      ),
      lyricsUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lyrics_uri'],
      ),
      sourceProvider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_provider'],
      ),
      providerTrackId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_track_id'],
      ),
      licenseUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}license_url'],
      ),
      metadataReviewed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}metadata_reviewed'],
      )!,
      isAvailable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_available'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      lastSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_seen_at'],
      ),
      fileSizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_size_bytes'],
      ),
      fileModifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}file_modified_at'],
      ),
    );
  }

  @override
  $LibraryTracksTable createAlias(String alias) {
    return $LibraryTracksTable(attachedDatabase, alias);
  }
}

class LibraryTrack extends DataClass implements Insertable<LibraryTrack> {
  final String id;
  final String path;
  final String? sourceName;
  final String title;
  final String artist;
  final String album;
  final String artistId;
  final String albumId;
  final int? durationMs;
  final String? artworkUri;
  final int? year;
  final int? trackNumber;
  final String? genre;
  final double? bpm;
  final bool isDeviceMedia;
  final String? sourceFolderUri;
  final String? lyricsUri;
  final String? sourceProvider;
  final String? providerTrackId;
  final String? licenseUrl;
  final bool metadataReviewed;
  final bool isAvailable;
  final int position;
  final DateTime? lastSeenAt;
  final int? fileSizeBytes;
  final DateTime? fileModifiedAt;
  const LibraryTrack({
    required this.id,
    required this.path,
    this.sourceName,
    required this.title,
    required this.artist,
    required this.album,
    required this.artistId,
    required this.albumId,
    this.durationMs,
    this.artworkUri,
    this.year,
    this.trackNumber,
    this.genre,
    this.bpm,
    required this.isDeviceMedia,
    this.sourceFolderUri,
    this.lyricsUri,
    this.sourceProvider,
    this.providerTrackId,
    this.licenseUrl,
    required this.metadataReviewed,
    required this.isAvailable,
    required this.position,
    this.lastSeenAt,
    this.fileSizeBytes,
    this.fileModifiedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['path'] = Variable<String>(path);
    if (!nullToAbsent || sourceName != null) {
      map['source_name'] = Variable<String>(sourceName);
    }
    map['title'] = Variable<String>(title);
    map['artist'] = Variable<String>(artist);
    map['album'] = Variable<String>(album);
    map['artist_id'] = Variable<String>(artistId);
    map['album_id'] = Variable<String>(albumId);
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    if (!nullToAbsent || artworkUri != null) {
      map['artwork_uri'] = Variable<String>(artworkUri);
    }
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || trackNumber != null) {
      map['track_number'] = Variable<int>(trackNumber);
    }
    if (!nullToAbsent || genre != null) {
      map['genre'] = Variable<String>(genre);
    }
    if (!nullToAbsent || bpm != null) {
      map['bpm'] = Variable<double>(bpm);
    }
    map['is_device_media'] = Variable<bool>(isDeviceMedia);
    if (!nullToAbsent || sourceFolderUri != null) {
      map['source_folder_uri'] = Variable<String>(sourceFolderUri);
    }
    if (!nullToAbsent || lyricsUri != null) {
      map['lyrics_uri'] = Variable<String>(lyricsUri);
    }
    if (!nullToAbsent || sourceProvider != null) {
      map['source_provider'] = Variable<String>(sourceProvider);
    }
    if (!nullToAbsent || providerTrackId != null) {
      map['provider_track_id'] = Variable<String>(providerTrackId);
    }
    if (!nullToAbsent || licenseUrl != null) {
      map['license_url'] = Variable<String>(licenseUrl);
    }
    map['metadata_reviewed'] = Variable<bool>(metadataReviewed);
    map['is_available'] = Variable<bool>(isAvailable);
    map['position'] = Variable<int>(position);
    if (!nullToAbsent || lastSeenAt != null) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt);
    }
    if (!nullToAbsent || fileSizeBytes != null) {
      map['file_size_bytes'] = Variable<int>(fileSizeBytes);
    }
    if (!nullToAbsent || fileModifiedAt != null) {
      map['file_modified_at'] = Variable<DateTime>(fileModifiedAt);
    }
    return map;
  }

  LibraryTracksCompanion toCompanion(bool nullToAbsent) {
    return LibraryTracksCompanion(
      id: Value(id),
      path: Value(path),
      sourceName: sourceName == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceName),
      title: Value(title),
      artist: Value(artist),
      album: Value(album),
      artistId: Value(artistId),
      albumId: Value(albumId),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      artworkUri: artworkUri == null && nullToAbsent
          ? const Value.absent()
          : Value(artworkUri),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      trackNumber: trackNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(trackNumber),
      genre: genre == null && nullToAbsent
          ? const Value.absent()
          : Value(genre),
      bpm: bpm == null && nullToAbsent ? const Value.absent() : Value(bpm),
      isDeviceMedia: Value(isDeviceMedia),
      sourceFolderUri: sourceFolderUri == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceFolderUri),
      lyricsUri: lyricsUri == null && nullToAbsent
          ? const Value.absent()
          : Value(lyricsUri),
      sourceProvider: sourceProvider == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceProvider),
      providerTrackId: providerTrackId == null && nullToAbsent
          ? const Value.absent()
          : Value(providerTrackId),
      licenseUrl: licenseUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(licenseUrl),
      metadataReviewed: Value(metadataReviewed),
      isAvailable: Value(isAvailable),
      position: Value(position),
      lastSeenAt: lastSeenAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSeenAt),
      fileSizeBytes: fileSizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(fileSizeBytes),
      fileModifiedAt: fileModifiedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(fileModifiedAt),
    );
  }

  factory LibraryTrack.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibraryTrack(
      id: serializer.fromJson<String>(json['id']),
      path: serializer.fromJson<String>(json['path']),
      sourceName: serializer.fromJson<String?>(json['sourceName']),
      title: serializer.fromJson<String>(json['title']),
      artist: serializer.fromJson<String>(json['artist']),
      album: serializer.fromJson<String>(json['album']),
      artistId: serializer.fromJson<String>(json['artistId']),
      albumId: serializer.fromJson<String>(json['albumId']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      artworkUri: serializer.fromJson<String?>(json['artworkUri']),
      year: serializer.fromJson<int?>(json['year']),
      trackNumber: serializer.fromJson<int?>(json['trackNumber']),
      genre: serializer.fromJson<String?>(json['genre']),
      bpm: serializer.fromJson<double?>(json['bpm']),
      isDeviceMedia: serializer.fromJson<bool>(json['isDeviceMedia']),
      sourceFolderUri: serializer.fromJson<String?>(json['sourceFolderUri']),
      lyricsUri: serializer.fromJson<String?>(json['lyricsUri']),
      sourceProvider: serializer.fromJson<String?>(json['sourceProvider']),
      providerTrackId: serializer.fromJson<String?>(json['providerTrackId']),
      licenseUrl: serializer.fromJson<String?>(json['licenseUrl']),
      metadataReviewed: serializer.fromJson<bool>(json['metadataReviewed']),
      isAvailable: serializer.fromJson<bool>(json['isAvailable']),
      position: serializer.fromJson<int>(json['position']),
      lastSeenAt: serializer.fromJson<DateTime?>(json['lastSeenAt']),
      fileSizeBytes: serializer.fromJson<int?>(json['fileSizeBytes']),
      fileModifiedAt: serializer.fromJson<DateTime?>(json['fileModifiedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'path': serializer.toJson<String>(path),
      'sourceName': serializer.toJson<String?>(sourceName),
      'title': serializer.toJson<String>(title),
      'artist': serializer.toJson<String>(artist),
      'album': serializer.toJson<String>(album),
      'artistId': serializer.toJson<String>(artistId),
      'albumId': serializer.toJson<String>(albumId),
      'durationMs': serializer.toJson<int?>(durationMs),
      'artworkUri': serializer.toJson<String?>(artworkUri),
      'year': serializer.toJson<int?>(year),
      'trackNumber': serializer.toJson<int?>(trackNumber),
      'genre': serializer.toJson<String?>(genre),
      'bpm': serializer.toJson<double?>(bpm),
      'isDeviceMedia': serializer.toJson<bool>(isDeviceMedia),
      'sourceFolderUri': serializer.toJson<String?>(sourceFolderUri),
      'lyricsUri': serializer.toJson<String?>(lyricsUri),
      'sourceProvider': serializer.toJson<String?>(sourceProvider),
      'providerTrackId': serializer.toJson<String?>(providerTrackId),
      'licenseUrl': serializer.toJson<String?>(licenseUrl),
      'metadataReviewed': serializer.toJson<bool>(metadataReviewed),
      'isAvailable': serializer.toJson<bool>(isAvailable),
      'position': serializer.toJson<int>(position),
      'lastSeenAt': serializer.toJson<DateTime?>(lastSeenAt),
      'fileSizeBytes': serializer.toJson<int?>(fileSizeBytes),
      'fileModifiedAt': serializer.toJson<DateTime?>(fileModifiedAt),
    };
  }

  LibraryTrack copyWith({
    String? id,
    String? path,
    Value<String?> sourceName = const Value.absent(),
    String? title,
    String? artist,
    String? album,
    String? artistId,
    String? albumId,
    Value<int?> durationMs = const Value.absent(),
    Value<String?> artworkUri = const Value.absent(),
    Value<int?> year = const Value.absent(),
    Value<int?> trackNumber = const Value.absent(),
    Value<String?> genre = const Value.absent(),
    Value<double?> bpm = const Value.absent(),
    bool? isDeviceMedia,
    Value<String?> sourceFolderUri = const Value.absent(),
    Value<String?> lyricsUri = const Value.absent(),
    Value<String?> sourceProvider = const Value.absent(),
    Value<String?> providerTrackId = const Value.absent(),
    Value<String?> licenseUrl = const Value.absent(),
    bool? metadataReviewed,
    bool? isAvailable,
    int? position,
    Value<DateTime?> lastSeenAt = const Value.absent(),
    Value<int?> fileSizeBytes = const Value.absent(),
    Value<DateTime?> fileModifiedAt = const Value.absent(),
  }) => LibraryTrack(
    id: id ?? this.id,
    path: path ?? this.path,
    sourceName: sourceName.present ? sourceName.value : this.sourceName,
    title: title ?? this.title,
    artist: artist ?? this.artist,
    album: album ?? this.album,
    artistId: artistId ?? this.artistId,
    albumId: albumId ?? this.albumId,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    artworkUri: artworkUri.present ? artworkUri.value : this.artworkUri,
    year: year.present ? year.value : this.year,
    trackNumber: trackNumber.present ? trackNumber.value : this.trackNumber,
    genre: genre.present ? genre.value : this.genre,
    bpm: bpm.present ? bpm.value : this.bpm,
    isDeviceMedia: isDeviceMedia ?? this.isDeviceMedia,
    sourceFolderUri: sourceFolderUri.present
        ? sourceFolderUri.value
        : this.sourceFolderUri,
    lyricsUri: lyricsUri.present ? lyricsUri.value : this.lyricsUri,
    sourceProvider: sourceProvider.present
        ? sourceProvider.value
        : this.sourceProvider,
    providerTrackId: providerTrackId.present
        ? providerTrackId.value
        : this.providerTrackId,
    licenseUrl: licenseUrl.present ? licenseUrl.value : this.licenseUrl,
    metadataReviewed: metadataReviewed ?? this.metadataReviewed,
    isAvailable: isAvailable ?? this.isAvailable,
    position: position ?? this.position,
    lastSeenAt: lastSeenAt.present ? lastSeenAt.value : this.lastSeenAt,
    fileSizeBytes: fileSizeBytes.present
        ? fileSizeBytes.value
        : this.fileSizeBytes,
    fileModifiedAt: fileModifiedAt.present
        ? fileModifiedAt.value
        : this.fileModifiedAt,
  );
  LibraryTrack copyWithCompanion(LibraryTracksCompanion data) {
    return LibraryTrack(
      id: data.id.present ? data.id.value : this.id,
      path: data.path.present ? data.path.value : this.path,
      sourceName: data.sourceName.present
          ? data.sourceName.value
          : this.sourceName,
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
      album: data.album.present ? data.album.value : this.album,
      artistId: data.artistId.present ? data.artistId.value : this.artistId,
      albumId: data.albumId.present ? data.albumId.value : this.albumId,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      artworkUri: data.artworkUri.present
          ? data.artworkUri.value
          : this.artworkUri,
      year: data.year.present ? data.year.value : this.year,
      trackNumber: data.trackNumber.present
          ? data.trackNumber.value
          : this.trackNumber,
      genre: data.genre.present ? data.genre.value : this.genre,
      bpm: data.bpm.present ? data.bpm.value : this.bpm,
      isDeviceMedia: data.isDeviceMedia.present
          ? data.isDeviceMedia.value
          : this.isDeviceMedia,
      sourceFolderUri: data.sourceFolderUri.present
          ? data.sourceFolderUri.value
          : this.sourceFolderUri,
      lyricsUri: data.lyricsUri.present ? data.lyricsUri.value : this.lyricsUri,
      sourceProvider: data.sourceProvider.present
          ? data.sourceProvider.value
          : this.sourceProvider,
      providerTrackId: data.providerTrackId.present
          ? data.providerTrackId.value
          : this.providerTrackId,
      licenseUrl: data.licenseUrl.present
          ? data.licenseUrl.value
          : this.licenseUrl,
      metadataReviewed: data.metadataReviewed.present
          ? data.metadataReviewed.value
          : this.metadataReviewed,
      isAvailable: data.isAvailable.present
          ? data.isAvailable.value
          : this.isAvailable,
      position: data.position.present ? data.position.value : this.position,
      lastSeenAt: data.lastSeenAt.present
          ? data.lastSeenAt.value
          : this.lastSeenAt,
      fileSizeBytes: data.fileSizeBytes.present
          ? data.fileSizeBytes.value
          : this.fileSizeBytes,
      fileModifiedAt: data.fileModifiedAt.present
          ? data.fileModifiedAt.value
          : this.fileModifiedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibraryTrack(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('sourceName: $sourceName, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('artistId: $artistId, ')
          ..write('albumId: $albumId, ')
          ..write('durationMs: $durationMs, ')
          ..write('artworkUri: $artworkUri, ')
          ..write('year: $year, ')
          ..write('trackNumber: $trackNumber, ')
          ..write('genre: $genre, ')
          ..write('bpm: $bpm, ')
          ..write('isDeviceMedia: $isDeviceMedia, ')
          ..write('sourceFolderUri: $sourceFolderUri, ')
          ..write('lyricsUri: $lyricsUri, ')
          ..write('sourceProvider: $sourceProvider, ')
          ..write('providerTrackId: $providerTrackId, ')
          ..write('licenseUrl: $licenseUrl, ')
          ..write('metadataReviewed: $metadataReviewed, ')
          ..write('isAvailable: $isAvailable, ')
          ..write('position: $position, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('fileSizeBytes: $fileSizeBytes, ')
          ..write('fileModifiedAt: $fileModifiedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    path,
    sourceName,
    title,
    artist,
    album,
    artistId,
    albumId,
    durationMs,
    artworkUri,
    year,
    trackNumber,
    genre,
    bpm,
    isDeviceMedia,
    sourceFolderUri,
    lyricsUri,
    sourceProvider,
    providerTrackId,
    licenseUrl,
    metadataReviewed,
    isAvailable,
    position,
    lastSeenAt,
    fileSizeBytes,
    fileModifiedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibraryTrack &&
          other.id == this.id &&
          other.path == this.path &&
          other.sourceName == this.sourceName &&
          other.title == this.title &&
          other.artist == this.artist &&
          other.album == this.album &&
          other.artistId == this.artistId &&
          other.albumId == this.albumId &&
          other.durationMs == this.durationMs &&
          other.artworkUri == this.artworkUri &&
          other.year == this.year &&
          other.trackNumber == this.trackNumber &&
          other.genre == this.genre &&
          other.bpm == this.bpm &&
          other.isDeviceMedia == this.isDeviceMedia &&
          other.sourceFolderUri == this.sourceFolderUri &&
          other.lyricsUri == this.lyricsUri &&
          other.sourceProvider == this.sourceProvider &&
          other.providerTrackId == this.providerTrackId &&
          other.licenseUrl == this.licenseUrl &&
          other.metadataReviewed == this.metadataReviewed &&
          other.isAvailable == this.isAvailable &&
          other.position == this.position &&
          other.lastSeenAt == this.lastSeenAt &&
          other.fileSizeBytes == this.fileSizeBytes &&
          other.fileModifiedAt == this.fileModifiedAt);
}

class LibraryTracksCompanion extends UpdateCompanion<LibraryTrack> {
  final Value<String> id;
  final Value<String> path;
  final Value<String?> sourceName;
  final Value<String> title;
  final Value<String> artist;
  final Value<String> album;
  final Value<String> artistId;
  final Value<String> albumId;
  final Value<int?> durationMs;
  final Value<String?> artworkUri;
  final Value<int?> year;
  final Value<int?> trackNumber;
  final Value<String?> genre;
  final Value<double?> bpm;
  final Value<bool> isDeviceMedia;
  final Value<String?> sourceFolderUri;
  final Value<String?> lyricsUri;
  final Value<String?> sourceProvider;
  final Value<String?> providerTrackId;
  final Value<String?> licenseUrl;
  final Value<bool> metadataReviewed;
  final Value<bool> isAvailable;
  final Value<int> position;
  final Value<DateTime?> lastSeenAt;
  final Value<int?> fileSizeBytes;
  final Value<DateTime?> fileModifiedAt;
  final Value<int> rowid;
  const LibraryTracksCompanion({
    this.id = const Value.absent(),
    this.path = const Value.absent(),
    this.sourceName = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.artistId = const Value.absent(),
    this.albumId = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.artworkUri = const Value.absent(),
    this.year = const Value.absent(),
    this.trackNumber = const Value.absent(),
    this.genre = const Value.absent(),
    this.bpm = const Value.absent(),
    this.isDeviceMedia = const Value.absent(),
    this.sourceFolderUri = const Value.absent(),
    this.lyricsUri = const Value.absent(),
    this.sourceProvider = const Value.absent(),
    this.providerTrackId = const Value.absent(),
    this.licenseUrl = const Value.absent(),
    this.metadataReviewed = const Value.absent(),
    this.isAvailable = const Value.absent(),
    this.position = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.fileSizeBytes = const Value.absent(),
    this.fileModifiedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LibraryTracksCompanion.insert({
    required String id,
    required String path,
    this.sourceName = const Value.absent(),
    required String title,
    required String artist,
    required String album,
    required String artistId,
    required String albumId,
    this.durationMs = const Value.absent(),
    this.artworkUri = const Value.absent(),
    this.year = const Value.absent(),
    this.trackNumber = const Value.absent(),
    this.genre = const Value.absent(),
    this.bpm = const Value.absent(),
    this.isDeviceMedia = const Value.absent(),
    this.sourceFolderUri = const Value.absent(),
    this.lyricsUri = const Value.absent(),
    this.sourceProvider = const Value.absent(),
    this.providerTrackId = const Value.absent(),
    this.licenseUrl = const Value.absent(),
    this.metadataReviewed = const Value.absent(),
    this.isAvailable = const Value.absent(),
    required int position,
    this.lastSeenAt = const Value.absent(),
    this.fileSizeBytes = const Value.absent(),
    this.fileModifiedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       path = Value(path),
       title = Value(title),
       artist = Value(artist),
       album = Value(album),
       artistId = Value(artistId),
       albumId = Value(albumId),
       position = Value(position);
  static Insertable<LibraryTrack> custom({
    Expression<String>? id,
    Expression<String>? path,
    Expression<String>? sourceName,
    Expression<String>? title,
    Expression<String>? artist,
    Expression<String>? album,
    Expression<String>? artistId,
    Expression<String>? albumId,
    Expression<int>? durationMs,
    Expression<String>? artworkUri,
    Expression<int>? year,
    Expression<int>? trackNumber,
    Expression<String>? genre,
    Expression<double>? bpm,
    Expression<bool>? isDeviceMedia,
    Expression<String>? sourceFolderUri,
    Expression<String>? lyricsUri,
    Expression<String>? sourceProvider,
    Expression<String>? providerTrackId,
    Expression<String>? licenseUrl,
    Expression<bool>? metadataReviewed,
    Expression<bool>? isAvailable,
    Expression<int>? position,
    Expression<DateTime>? lastSeenAt,
    Expression<int>? fileSizeBytes,
    Expression<DateTime>? fileModifiedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (path != null) 'path': path,
      if (sourceName != null) 'source_name': sourceName,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (album != null) 'album': album,
      if (artistId != null) 'artist_id': artistId,
      if (albumId != null) 'album_id': albumId,
      if (durationMs != null) 'duration_ms': durationMs,
      if (artworkUri != null) 'artwork_uri': artworkUri,
      if (year != null) 'year': year,
      if (trackNumber != null) 'track_number': trackNumber,
      if (genre != null) 'genre': genre,
      if (bpm != null) 'bpm': bpm,
      if (isDeviceMedia != null) 'is_device_media': isDeviceMedia,
      if (sourceFolderUri != null) 'source_folder_uri': sourceFolderUri,
      if (lyricsUri != null) 'lyrics_uri': lyricsUri,
      if (sourceProvider != null) 'source_provider': sourceProvider,
      if (providerTrackId != null) 'provider_track_id': providerTrackId,
      if (licenseUrl != null) 'license_url': licenseUrl,
      if (metadataReviewed != null) 'metadata_reviewed': metadataReviewed,
      if (isAvailable != null) 'is_available': isAvailable,
      if (position != null) 'position': position,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (fileSizeBytes != null) 'file_size_bytes': fileSizeBytes,
      if (fileModifiedAt != null) 'file_modified_at': fileModifiedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LibraryTracksCompanion copyWith({
    Value<String>? id,
    Value<String>? path,
    Value<String?>? sourceName,
    Value<String>? title,
    Value<String>? artist,
    Value<String>? album,
    Value<String>? artistId,
    Value<String>? albumId,
    Value<int?>? durationMs,
    Value<String?>? artworkUri,
    Value<int?>? year,
    Value<int?>? trackNumber,
    Value<String?>? genre,
    Value<double?>? bpm,
    Value<bool>? isDeviceMedia,
    Value<String?>? sourceFolderUri,
    Value<String?>? lyricsUri,
    Value<String?>? sourceProvider,
    Value<String?>? providerTrackId,
    Value<String?>? licenseUrl,
    Value<bool>? metadataReviewed,
    Value<bool>? isAvailable,
    Value<int>? position,
    Value<DateTime?>? lastSeenAt,
    Value<int?>? fileSizeBytes,
    Value<DateTime?>? fileModifiedAt,
    Value<int>? rowid,
  }) {
    return LibraryTracksCompanion(
      id: id ?? this.id,
      path: path ?? this.path,
      sourceName: sourceName ?? this.sourceName,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      artistId: artistId ?? this.artistId,
      albumId: albumId ?? this.albumId,
      durationMs: durationMs ?? this.durationMs,
      artworkUri: artworkUri ?? this.artworkUri,
      year: year ?? this.year,
      trackNumber: trackNumber ?? this.trackNumber,
      genre: genre ?? this.genre,
      bpm: bpm ?? this.bpm,
      isDeviceMedia: isDeviceMedia ?? this.isDeviceMedia,
      sourceFolderUri: sourceFolderUri ?? this.sourceFolderUri,
      lyricsUri: lyricsUri ?? this.lyricsUri,
      sourceProvider: sourceProvider ?? this.sourceProvider,
      providerTrackId: providerTrackId ?? this.providerTrackId,
      licenseUrl: licenseUrl ?? this.licenseUrl,
      metadataReviewed: metadataReviewed ?? this.metadataReviewed,
      isAvailable: isAvailable ?? this.isAvailable,
      position: position ?? this.position,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      fileModifiedAt: fileModifiedAt ?? this.fileModifiedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (sourceName.present) {
      map['source_name'] = Variable<String>(sourceName.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (album.present) {
      map['album'] = Variable<String>(album.value);
    }
    if (artistId.present) {
      map['artist_id'] = Variable<String>(artistId.value);
    }
    if (albumId.present) {
      map['album_id'] = Variable<String>(albumId.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (artworkUri.present) {
      map['artwork_uri'] = Variable<String>(artworkUri.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (trackNumber.present) {
      map['track_number'] = Variable<int>(trackNumber.value);
    }
    if (genre.present) {
      map['genre'] = Variable<String>(genre.value);
    }
    if (bpm.present) {
      map['bpm'] = Variable<double>(bpm.value);
    }
    if (isDeviceMedia.present) {
      map['is_device_media'] = Variable<bool>(isDeviceMedia.value);
    }
    if (sourceFolderUri.present) {
      map['source_folder_uri'] = Variable<String>(sourceFolderUri.value);
    }
    if (lyricsUri.present) {
      map['lyrics_uri'] = Variable<String>(lyricsUri.value);
    }
    if (sourceProvider.present) {
      map['source_provider'] = Variable<String>(sourceProvider.value);
    }
    if (providerTrackId.present) {
      map['provider_track_id'] = Variable<String>(providerTrackId.value);
    }
    if (licenseUrl.present) {
      map['license_url'] = Variable<String>(licenseUrl.value);
    }
    if (metadataReviewed.present) {
      map['metadata_reviewed'] = Variable<bool>(metadataReviewed.value);
    }
    if (isAvailable.present) {
      map['is_available'] = Variable<bool>(isAvailable.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt.value);
    }
    if (fileSizeBytes.present) {
      map['file_size_bytes'] = Variable<int>(fileSizeBytes.value);
    }
    if (fileModifiedAt.present) {
      map['file_modified_at'] = Variable<DateTime>(fileModifiedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibraryTracksCompanion(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('sourceName: $sourceName, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('artistId: $artistId, ')
          ..write('albumId: $albumId, ')
          ..write('durationMs: $durationMs, ')
          ..write('artworkUri: $artworkUri, ')
          ..write('year: $year, ')
          ..write('trackNumber: $trackNumber, ')
          ..write('genre: $genre, ')
          ..write('bpm: $bpm, ')
          ..write('isDeviceMedia: $isDeviceMedia, ')
          ..write('sourceFolderUri: $sourceFolderUri, ')
          ..write('lyricsUri: $lyricsUri, ')
          ..write('sourceProvider: $sourceProvider, ')
          ..write('providerTrackId: $providerTrackId, ')
          ..write('licenseUrl: $licenseUrl, ')
          ..write('metadataReviewed: $metadataReviewed, ')
          ..write('isAvailable: $isAvailable, ')
          ..write('position: $position, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('fileSizeBytes: $fileSizeBytes, ')
          ..write('fileModifiedAt: $fileModifiedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LibraryFoldersTable extends LibraryFolders
    with TableInfo<$LibraryFoldersTable, LibraryFolder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibraryFoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uriMeta = const VerificationMeta('uri');
  @override
  late final GeneratedColumn<String> uri = GeneratedColumn<String>(
    'uri',
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
  static const VerificationMeta _grantedAtMeta = const VerificationMeta(
    'grantedAt',
  );
  @override
  late final GeneratedColumn<DateTime> grantedAt = GeneratedColumn<DateTime>(
    'granted_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [uri, name, grantedAt, position];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibraryFolder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('uri')) {
      context.handle(
        _uriMeta,
        uri.isAcceptableOrUnknown(data['uri']!, _uriMeta),
      );
    } else if (isInserting) {
      context.missing(_uriMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('granted_at')) {
      context.handle(
        _grantedAtMeta,
        grantedAt.isAcceptableOrUnknown(data['granted_at']!, _grantedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_grantedAtMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uri};
  @override
  LibraryFolder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibraryFolder(
      uri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uri'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      grantedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}granted_at'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $LibraryFoldersTable createAlias(String alias) {
    return $LibraryFoldersTable(attachedDatabase, alias);
  }
}

class LibraryFolder extends DataClass implements Insertable<LibraryFolder> {
  final String uri;
  final String name;
  final DateTime grantedAt;
  final int position;
  const LibraryFolder({
    required this.uri,
    required this.name,
    required this.grantedAt,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uri'] = Variable<String>(uri);
    map['name'] = Variable<String>(name);
    map['granted_at'] = Variable<DateTime>(grantedAt);
    map['position'] = Variable<int>(position);
    return map;
  }

  LibraryFoldersCompanion toCompanion(bool nullToAbsent) {
    return LibraryFoldersCompanion(
      uri: Value(uri),
      name: Value(name),
      grantedAt: Value(grantedAt),
      position: Value(position),
    );
  }

  factory LibraryFolder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibraryFolder(
      uri: serializer.fromJson<String>(json['uri']),
      name: serializer.fromJson<String>(json['name']),
      grantedAt: serializer.fromJson<DateTime>(json['grantedAt']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uri': serializer.toJson<String>(uri),
      'name': serializer.toJson<String>(name),
      'grantedAt': serializer.toJson<DateTime>(grantedAt),
      'position': serializer.toJson<int>(position),
    };
  }

  LibraryFolder copyWith({
    String? uri,
    String? name,
    DateTime? grantedAt,
    int? position,
  }) => LibraryFolder(
    uri: uri ?? this.uri,
    name: name ?? this.name,
    grantedAt: grantedAt ?? this.grantedAt,
    position: position ?? this.position,
  );
  LibraryFolder copyWithCompanion(LibraryFoldersCompanion data) {
    return LibraryFolder(
      uri: data.uri.present ? data.uri.value : this.uri,
      name: data.name.present ? data.name.value : this.name,
      grantedAt: data.grantedAt.present ? data.grantedAt.value : this.grantedAt,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibraryFolder(')
          ..write('uri: $uri, ')
          ..write('name: $name, ')
          ..write('grantedAt: $grantedAt, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(uri, name, grantedAt, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibraryFolder &&
          other.uri == this.uri &&
          other.name == this.name &&
          other.grantedAt == this.grantedAt &&
          other.position == this.position);
}

class LibraryFoldersCompanion extends UpdateCompanion<LibraryFolder> {
  final Value<String> uri;
  final Value<String> name;
  final Value<DateTime> grantedAt;
  final Value<int> position;
  final Value<int> rowid;
  const LibraryFoldersCompanion({
    this.uri = const Value.absent(),
    this.name = const Value.absent(),
    this.grantedAt = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LibraryFoldersCompanion.insert({
    required String uri,
    required String name,
    required DateTime grantedAt,
    required int position,
    this.rowid = const Value.absent(),
  }) : uri = Value(uri),
       name = Value(name),
       grantedAt = Value(grantedAt),
       position = Value(position);
  static Insertable<LibraryFolder> custom({
    Expression<String>? uri,
    Expression<String>? name,
    Expression<DateTime>? grantedAt,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uri != null) 'uri': uri,
      if (name != null) 'name': name,
      if (grantedAt != null) 'granted_at': grantedAt,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LibraryFoldersCompanion copyWith({
    Value<String>? uri,
    Value<String>? name,
    Value<DateTime>? grantedAt,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return LibraryFoldersCompanion(
      uri: uri ?? this.uri,
      name: name ?? this.name,
      grantedAt: grantedAt ?? this.grantedAt,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uri.present) {
      map['uri'] = Variable<String>(uri.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (grantedAt.present) {
      map['granted_at'] = Variable<DateTime>(grantedAt.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibraryFoldersCompanion(')
          ..write('uri: $uri, ')
          ..write('name: $name, ')
          ..write('grantedAt: $grantedAt, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaylistsTable extends Playlists
    with TableInfo<$PlaylistsTable, Playlist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, createdAt, position];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlists';
  @override
  VerificationContext validateIntegrity(
    Insertable<Playlist> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Playlist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Playlist(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $PlaylistsTable createAlias(String alias) {
    return $PlaylistsTable(attachedDatabase, alias);
  }
}

class Playlist extends DataClass implements Insertable<Playlist> {
  final String id;
  final String name;
  final DateTime createdAt;
  final int position;
  const Playlist({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['position'] = Variable<int>(position);
    return map;
  }

  PlaylistsCompanion toCompanion(bool nullToAbsent) {
    return PlaylistsCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
      position: Value(position),
    );
  }

  factory Playlist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Playlist(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'position': serializer.toJson<int>(position),
    };
  }

  Playlist copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    int? position,
  }) => Playlist(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
    position: position ?? this.position,
  );
  Playlist copyWithCompanion(PlaylistsCompanion data) {
    return Playlist(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Playlist(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Playlist &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt &&
          other.position == this.position);
}

class PlaylistsCompanion extends UpdateCompanion<Playlist> {
  final Value<String> id;
  final Value<String> name;
  final Value<DateTime> createdAt;
  final Value<int> position;
  final Value<int> rowid;
  const PlaylistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaylistsCompanion.insert({
    required String id,
    required String name,
    required DateTime createdAt,
    required int position,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt),
       position = Value(position);
  static Insertable<Playlist> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaylistsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<DateTime>? createdAt,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return PlaylistsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaylistTracksTable extends PlaylistTracks
    with TableInfo<$PlaylistTracksTable, PlaylistTrack> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistTracksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<String> playlistId = GeneratedColumn<String>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playlists (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<String> trackId = GeneratedColumn<String>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES library_tracks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [playlistId, trackId, position];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlist_tracks';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaylistTrack> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {playlistId, trackId};
  @override
  PlaylistTrack map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistTrack(
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}playlist_id'],
      )!,
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $PlaylistTracksTable createAlias(String alias) {
    return $PlaylistTracksTable(attachedDatabase, alias);
  }
}

class PlaylistTrack extends DataClass implements Insertable<PlaylistTrack> {
  final String playlistId;
  final String trackId;
  final int position;
  const PlaylistTrack({
    required this.playlistId,
    required this.trackId,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['playlist_id'] = Variable<String>(playlistId);
    map['track_id'] = Variable<String>(trackId);
    map['position'] = Variable<int>(position);
    return map;
  }

  PlaylistTracksCompanion toCompanion(bool nullToAbsent) {
    return PlaylistTracksCompanion(
      playlistId: Value(playlistId),
      trackId: Value(trackId),
      position: Value(position),
    );
  }

  factory PlaylistTrack.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistTrack(
      playlistId: serializer.fromJson<String>(json['playlistId']),
      trackId: serializer.fromJson<String>(json['trackId']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'playlistId': serializer.toJson<String>(playlistId),
      'trackId': serializer.toJson<String>(trackId),
      'position': serializer.toJson<int>(position),
    };
  }

  PlaylistTrack copyWith({
    String? playlistId,
    String? trackId,
    int? position,
  }) => PlaylistTrack(
    playlistId: playlistId ?? this.playlistId,
    trackId: trackId ?? this.trackId,
    position: position ?? this.position,
  );
  PlaylistTrack copyWithCompanion(PlaylistTracksCompanion data) {
    return PlaylistTrack(
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistTrack(')
          ..write('playlistId: $playlistId, ')
          ..write('trackId: $trackId, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(playlistId, trackId, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistTrack &&
          other.playlistId == this.playlistId &&
          other.trackId == this.trackId &&
          other.position == this.position);
}

class PlaylistTracksCompanion extends UpdateCompanion<PlaylistTrack> {
  final Value<String> playlistId;
  final Value<String> trackId;
  final Value<int> position;
  final Value<int> rowid;
  const PlaylistTracksCompanion({
    this.playlistId = const Value.absent(),
    this.trackId = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaylistTracksCompanion.insert({
    required String playlistId,
    required String trackId,
    required int position,
    this.rowid = const Value.absent(),
  }) : playlistId = Value(playlistId),
       trackId = Value(trackId),
       position = Value(position);
  static Insertable<PlaylistTrack> custom({
    Expression<String>? playlistId,
    Expression<String>? trackId,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (playlistId != null) 'playlist_id': playlistId,
      if (trackId != null) 'track_id': trackId,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaylistTracksCompanion copyWith({
    Value<String>? playlistId,
    Value<String>? trackId,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return PlaylistTracksCompanion(
      playlistId: playlistId ?? this.playlistId,
      trackId: trackId ?? this.trackId,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (playlistId.present) {
      map['playlist_id'] = Variable<String>(playlistId.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<String>(trackId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistTracksCompanion(')
          ..write('playlistId: $playlistId, ')
          ..write('trackId: $trackId, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FavoritesTable extends Favorites
    with TableInfo<$FavoritesTable, Favorite> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoritesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<String> trackId = GeneratedColumn<String>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES library_tracks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [trackId, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorites';
  @override
  VerificationContext validateIntegrity(
    Insertable<Favorite> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {trackId};
  @override
  Favorite map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Favorite(
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_id'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $FavoritesTable createAlias(String alias) {
    return $FavoritesTable(attachedDatabase, alias);
  }
}

class Favorite extends DataClass implements Insertable<Favorite> {
  final String trackId;
  final DateTime addedAt;
  const Favorite({required this.trackId, required this.addedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['track_id'] = Variable<String>(trackId);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  FavoritesCompanion toCompanion(bool nullToAbsent) {
    return FavoritesCompanion(trackId: Value(trackId), addedAt: Value(addedAt));
  }

  factory Favorite.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Favorite(
      trackId: serializer.fromJson<String>(json['trackId']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trackId': serializer.toJson<String>(trackId),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  Favorite copyWith({String? trackId, DateTime? addedAt}) => Favorite(
    trackId: trackId ?? this.trackId,
    addedAt: addedAt ?? this.addedAt,
  );
  Favorite copyWithCompanion(FavoritesCompanion data) {
    return Favorite(
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Favorite(')
          ..write('trackId: $trackId, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(trackId, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Favorite &&
          other.trackId == this.trackId &&
          other.addedAt == this.addedAt);
}

class FavoritesCompanion extends UpdateCompanion<Favorite> {
  final Value<String> trackId;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const FavoritesCompanion({
    this.trackId = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FavoritesCompanion.insert({
    required String trackId,
    required DateTime addedAt,
    this.rowid = const Value.absent(),
  }) : trackId = Value(trackId),
       addedAt = Value(addedAt);
  static Insertable<Favorite> custom({
    Expression<String>? trackId,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (trackId != null) 'track_id': trackId,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FavoritesCompanion copyWith({
    Value<String>? trackId,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return FavoritesCompanion(
      trackId: trackId ?? this.trackId,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (trackId.present) {
      map['track_id'] = Variable<String>(trackId.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoritesCompanion(')
          ..write('trackId: $trackId, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExcludedTracksTable extends ExcludedTracks
    with TableInfo<$ExcludedTracksTable, ExcludedTrack> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExcludedTracksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<String> trackId = GeneratedColumn<String>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES library_tracks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _excludedAtMeta = const VerificationMeta(
    'excludedAt',
  );
  @override
  late final GeneratedColumn<DateTime> excludedAt = GeneratedColumn<DateTime>(
    'excluded_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [trackId, excludedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'excluded_tracks';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExcludedTrack> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('excluded_at')) {
      context.handle(
        _excludedAtMeta,
        excludedAt.isAcceptableOrUnknown(data['excluded_at']!, _excludedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_excludedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {trackId};
  @override
  ExcludedTrack map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExcludedTrack(
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_id'],
      )!,
      excludedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}excluded_at'],
      )!,
    );
  }

  @override
  $ExcludedTracksTable createAlias(String alias) {
    return $ExcludedTracksTable(attachedDatabase, alias);
  }
}

class ExcludedTrack extends DataClass implements Insertable<ExcludedTrack> {
  final String trackId;
  final DateTime excludedAt;
  const ExcludedTrack({required this.trackId, required this.excludedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['track_id'] = Variable<String>(trackId);
    map['excluded_at'] = Variable<DateTime>(excludedAt);
    return map;
  }

  ExcludedTracksCompanion toCompanion(bool nullToAbsent) {
    return ExcludedTracksCompanion(
      trackId: Value(trackId),
      excludedAt: Value(excludedAt),
    );
  }

  factory ExcludedTrack.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExcludedTrack(
      trackId: serializer.fromJson<String>(json['trackId']),
      excludedAt: serializer.fromJson<DateTime>(json['excludedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trackId': serializer.toJson<String>(trackId),
      'excludedAt': serializer.toJson<DateTime>(excludedAt),
    };
  }

  ExcludedTrack copyWith({String? trackId, DateTime? excludedAt}) =>
      ExcludedTrack(
        trackId: trackId ?? this.trackId,
        excludedAt: excludedAt ?? this.excludedAt,
      );
  ExcludedTrack copyWithCompanion(ExcludedTracksCompanion data) {
    return ExcludedTrack(
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      excludedAt: data.excludedAt.present
          ? data.excludedAt.value
          : this.excludedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExcludedTrack(')
          ..write('trackId: $trackId, ')
          ..write('excludedAt: $excludedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(trackId, excludedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExcludedTrack &&
          other.trackId == this.trackId &&
          other.excludedAt == this.excludedAt);
}

class ExcludedTracksCompanion extends UpdateCompanion<ExcludedTrack> {
  final Value<String> trackId;
  final Value<DateTime> excludedAt;
  final Value<int> rowid;
  const ExcludedTracksCompanion({
    this.trackId = const Value.absent(),
    this.excludedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExcludedTracksCompanion.insert({
    required String trackId,
    required DateTime excludedAt,
    this.rowid = const Value.absent(),
  }) : trackId = Value(trackId),
       excludedAt = Value(excludedAt);
  static Insertable<ExcludedTrack> custom({
    Expression<String>? trackId,
    Expression<DateTime>? excludedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (trackId != null) 'track_id': trackId,
      if (excludedAt != null) 'excluded_at': excludedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExcludedTracksCompanion copyWith({
    Value<String>? trackId,
    Value<DateTime>? excludedAt,
    Value<int>? rowid,
  }) {
    return ExcludedTracksCompanion(
      trackId: trackId ?? this.trackId,
      excludedAt: excludedAt ?? this.excludedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (trackId.present) {
      map['track_id'] = Variable<String>(trackId.value);
    }
    if (excludedAt.present) {
      map['excluded_at'] = Variable<DateTime>(excludedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExcludedTracksCompanion(')
          ..write('trackId: $trackId, ')
          ..write('excludedAt: $excludedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaybackQueueEntriesTable extends PlaybackQueueEntries
    with TableInfo<$PlaybackQueueEntriesTable, PlaybackQueueEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaybackQueueEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<String> trackId = GeneratedColumn<String>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [position, trackId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playback_queue_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaybackQueueEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {position};
  @override
  PlaybackQueueEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaybackQueueEntry(
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_id'],
      )!,
    );
  }

  @override
  $PlaybackQueueEntriesTable createAlias(String alias) {
    return $PlaybackQueueEntriesTable(attachedDatabase, alias);
  }
}

class PlaybackQueueEntry extends DataClass
    implements Insertable<PlaybackQueueEntry> {
  final int position;
  final String trackId;
  const PlaybackQueueEntry({required this.position, required this.trackId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['position'] = Variable<int>(position);
    map['track_id'] = Variable<String>(trackId);
    return map;
  }

  PlaybackQueueEntriesCompanion toCompanion(bool nullToAbsent) {
    return PlaybackQueueEntriesCompanion(
      position: Value(position),
      trackId: Value(trackId),
    );
  }

  factory PlaybackQueueEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaybackQueueEntry(
      position: serializer.fromJson<int>(json['position']),
      trackId: serializer.fromJson<String>(json['trackId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'position': serializer.toJson<int>(position),
      'trackId': serializer.toJson<String>(trackId),
    };
  }

  PlaybackQueueEntry copyWith({int? position, String? trackId}) =>
      PlaybackQueueEntry(
        position: position ?? this.position,
        trackId: trackId ?? this.trackId,
      );
  PlaybackQueueEntry copyWithCompanion(PlaybackQueueEntriesCompanion data) {
    return PlaybackQueueEntry(
      position: data.position.present ? data.position.value : this.position,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackQueueEntry(')
          ..write('position: $position, ')
          ..write('trackId: $trackId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(position, trackId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaybackQueueEntry &&
          other.position == this.position &&
          other.trackId == this.trackId);
}

class PlaybackQueueEntriesCompanion
    extends UpdateCompanion<PlaybackQueueEntry> {
  final Value<int> position;
  final Value<String> trackId;
  const PlaybackQueueEntriesCompanion({
    this.position = const Value.absent(),
    this.trackId = const Value.absent(),
  });
  PlaybackQueueEntriesCompanion.insert({
    this.position = const Value.absent(),
    required String trackId,
  }) : trackId = Value(trackId);
  static Insertable<PlaybackQueueEntry> custom({
    Expression<int>? position,
    Expression<String>? trackId,
  }) {
    return RawValuesInsertable({
      if (position != null) 'position': position,
      if (trackId != null) 'track_id': trackId,
    });
  }

  PlaybackQueueEntriesCompanion copyWith({
    Value<int>? position,
    Value<String>? trackId,
  }) {
    return PlaybackQueueEntriesCompanion(
      position: position ?? this.position,
      trackId: trackId ?? this.trackId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<String>(trackId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackQueueEntriesCompanion(')
          ..write('position: $position, ')
          ..write('trackId: $trackId')
          ..write(')'))
        .toString();
  }
}

class $PlaybackStateTable extends PlaybackState
    with TableInfo<$PlaybackStateTable, PlaybackStateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaybackStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _currentTrackIdMeta = const VerificationMeta(
    'currentTrackId',
  );
  @override
  late final GeneratedColumn<String> currentTrackId = GeneratedColumn<String>(
    'current_track_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _positionMsMeta = const VerificationMeta(
    'positionMs',
  );
  @override
  late final GeneratedColumn<int> positionMs = GeneratedColumn<int>(
    'position_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, currentTrackId, positionMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playback_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaybackStateData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('current_track_id')) {
      context.handle(
        _currentTrackIdMeta,
        currentTrackId.isAcceptableOrUnknown(
          data['current_track_id']!,
          _currentTrackIdMeta,
        ),
      );
    }
    if (data.containsKey('position_ms')) {
      context.handle(
        _positionMsMeta,
        positionMs.isAcceptableOrUnknown(data['position_ms']!, _positionMsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlaybackStateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaybackStateData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      currentTrackId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}current_track_id'],
      ),
      positionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_ms'],
      )!,
    );
  }

  @override
  $PlaybackStateTable createAlias(String alias) {
    return $PlaybackStateTable(attachedDatabase, alias);
  }
}

class PlaybackStateData extends DataClass
    implements Insertable<PlaybackStateData> {
  final int id;
  final String? currentTrackId;
  final int positionMs;
  const PlaybackStateData({
    required this.id,
    this.currentTrackId,
    required this.positionMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || currentTrackId != null) {
      map['current_track_id'] = Variable<String>(currentTrackId);
    }
    map['position_ms'] = Variable<int>(positionMs);
    return map;
  }

  PlaybackStateCompanion toCompanion(bool nullToAbsent) {
    return PlaybackStateCompanion(
      id: Value(id),
      currentTrackId: currentTrackId == null && nullToAbsent
          ? const Value.absent()
          : Value(currentTrackId),
      positionMs: Value(positionMs),
    );
  }

  factory PlaybackStateData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaybackStateData(
      id: serializer.fromJson<int>(json['id']),
      currentTrackId: serializer.fromJson<String?>(json['currentTrackId']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'currentTrackId': serializer.toJson<String?>(currentTrackId),
      'positionMs': serializer.toJson<int>(positionMs),
    };
  }

  PlaybackStateData copyWith({
    int? id,
    Value<String?> currentTrackId = const Value.absent(),
    int? positionMs,
  }) => PlaybackStateData(
    id: id ?? this.id,
    currentTrackId: currentTrackId.present
        ? currentTrackId.value
        : this.currentTrackId,
    positionMs: positionMs ?? this.positionMs,
  );
  PlaybackStateData copyWithCompanion(PlaybackStateCompanion data) {
    return PlaybackStateData(
      id: data.id.present ? data.id.value : this.id,
      currentTrackId: data.currentTrackId.present
          ? data.currentTrackId.value
          : this.currentTrackId,
      positionMs: data.positionMs.present
          ? data.positionMs.value
          : this.positionMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackStateData(')
          ..write('id: $id, ')
          ..write('currentTrackId: $currentTrackId, ')
          ..write('positionMs: $positionMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, currentTrackId, positionMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaybackStateData &&
          other.id == this.id &&
          other.currentTrackId == this.currentTrackId &&
          other.positionMs == this.positionMs);
}

class PlaybackStateCompanion extends UpdateCompanion<PlaybackStateData> {
  final Value<int> id;
  final Value<String?> currentTrackId;
  final Value<int> positionMs;
  const PlaybackStateCompanion({
    this.id = const Value.absent(),
    this.currentTrackId = const Value.absent(),
    this.positionMs = const Value.absent(),
  });
  PlaybackStateCompanion.insert({
    this.id = const Value.absent(),
    this.currentTrackId = const Value.absent(),
    this.positionMs = const Value.absent(),
  });
  static Insertable<PlaybackStateData> custom({
    Expression<int>? id,
    Expression<String>? currentTrackId,
    Expression<int>? positionMs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (currentTrackId != null) 'current_track_id': currentTrackId,
      if (positionMs != null) 'position_ms': positionMs,
    });
  }

  PlaybackStateCompanion copyWith({
    Value<int>? id,
    Value<String?>? currentTrackId,
    Value<int>? positionMs,
  }) {
    return PlaybackStateCompanion(
      id: id ?? this.id,
      currentTrackId: currentTrackId ?? this.currentTrackId,
      positionMs: positionMs ?? this.positionMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (currentTrackId.present) {
      map['current_track_id'] = Variable<String>(currentTrackId.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackStateCompanion(')
          ..write('id: $id, ')
          ..write('currentTrackId: $currentTrackId, ')
          ..write('positionMs: $positionMs')
          ..write(')'))
        .toString();
  }
}

class $PlaybackHistoryTable extends PlaybackHistory
    with TableInfo<$PlaybackHistoryTable, PlaybackHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaybackHistoryTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<String> trackId = GeneratedColumn<String>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
    'artist',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _albumMeta = const VerificationMeta('album');
  @override
  late final GeneratedColumn<String> album = GeneratedColumn<String>(
    'album',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playedAtMeta = const VerificationMeta(
    'playedAt',
  );
  @override
  late final GeneratedColumn<DateTime> playedAt = GeneratedColumn<DateTime>(
    'played_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _listenedMsMeta = const VerificationMeta(
    'listenedMs',
  );
  @override
  late final GeneratedColumn<int> listenedMs = GeneratedColumn<int>(
    'listened_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    trackId,
    title,
    artist,
    album,
    playedAt,
    listenedMs,
    completed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playback_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaybackHistoryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(
        _artistMeta,
        artist.isAcceptableOrUnknown(data['artist']!, _artistMeta),
      );
    } else if (isInserting) {
      context.missing(_artistMeta);
    }
    if (data.containsKey('album')) {
      context.handle(
        _albumMeta,
        album.isAcceptableOrUnknown(data['album']!, _albumMeta),
      );
    } else if (isInserting) {
      context.missing(_albumMeta);
    }
    if (data.containsKey('played_at')) {
      context.handle(
        _playedAtMeta,
        playedAt.isAcceptableOrUnknown(data['played_at']!, _playedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_playedAtMeta);
    }
    if (data.containsKey('listened_ms')) {
      context.handle(
        _listenedMsMeta,
        listenedMs.isAcceptableOrUnknown(data['listened_ms']!, _listenedMsMeta),
      );
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlaybackHistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaybackHistoryData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      artist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist'],
      )!,
      album: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album'],
      )!,
      playedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}played_at'],
      )!,
      listenedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}listened_ms'],
      )!,
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
      )!,
    );
  }

  @override
  $PlaybackHistoryTable createAlias(String alias) {
    return $PlaybackHistoryTable(attachedDatabase, alias);
  }
}

class PlaybackHistoryData extends DataClass
    implements Insertable<PlaybackHistoryData> {
  final int id;
  final String trackId;
  final String title;
  final String artist;
  final String album;
  final DateTime playedAt;
  final int listenedMs;
  final bool completed;
  const PlaybackHistoryData({
    required this.id,
    required this.trackId,
    required this.title,
    required this.artist,
    required this.album,
    required this.playedAt,
    required this.listenedMs,
    required this.completed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['track_id'] = Variable<String>(trackId);
    map['title'] = Variable<String>(title);
    map['artist'] = Variable<String>(artist);
    map['album'] = Variable<String>(album);
    map['played_at'] = Variable<DateTime>(playedAt);
    map['listened_ms'] = Variable<int>(listenedMs);
    map['completed'] = Variable<bool>(completed);
    return map;
  }

  PlaybackHistoryCompanion toCompanion(bool nullToAbsent) {
    return PlaybackHistoryCompanion(
      id: Value(id),
      trackId: Value(trackId),
      title: Value(title),
      artist: Value(artist),
      album: Value(album),
      playedAt: Value(playedAt),
      listenedMs: Value(listenedMs),
      completed: Value(completed),
    );
  }

  factory PlaybackHistoryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaybackHistoryData(
      id: serializer.fromJson<int>(json['id']),
      trackId: serializer.fromJson<String>(json['trackId']),
      title: serializer.fromJson<String>(json['title']),
      artist: serializer.fromJson<String>(json['artist']),
      album: serializer.fromJson<String>(json['album']),
      playedAt: serializer.fromJson<DateTime>(json['playedAt']),
      listenedMs: serializer.fromJson<int>(json['listenedMs']),
      completed: serializer.fromJson<bool>(json['completed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'trackId': serializer.toJson<String>(trackId),
      'title': serializer.toJson<String>(title),
      'artist': serializer.toJson<String>(artist),
      'album': serializer.toJson<String>(album),
      'playedAt': serializer.toJson<DateTime>(playedAt),
      'listenedMs': serializer.toJson<int>(listenedMs),
      'completed': serializer.toJson<bool>(completed),
    };
  }

  PlaybackHistoryData copyWith({
    int? id,
    String? trackId,
    String? title,
    String? artist,
    String? album,
    DateTime? playedAt,
    int? listenedMs,
    bool? completed,
  }) => PlaybackHistoryData(
    id: id ?? this.id,
    trackId: trackId ?? this.trackId,
    title: title ?? this.title,
    artist: artist ?? this.artist,
    album: album ?? this.album,
    playedAt: playedAt ?? this.playedAt,
    listenedMs: listenedMs ?? this.listenedMs,
    completed: completed ?? this.completed,
  );
  PlaybackHistoryData copyWithCompanion(PlaybackHistoryCompanion data) {
    return PlaybackHistoryData(
      id: data.id.present ? data.id.value : this.id,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
      album: data.album.present ? data.album.value : this.album,
      playedAt: data.playedAt.present ? data.playedAt.value : this.playedAt,
      listenedMs: data.listenedMs.present
          ? data.listenedMs.value
          : this.listenedMs,
      completed: data.completed.present ? data.completed.value : this.completed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackHistoryData(')
          ..write('id: $id, ')
          ..write('trackId: $trackId, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('playedAt: $playedAt, ')
          ..write('listenedMs: $listenedMs, ')
          ..write('completed: $completed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    trackId,
    title,
    artist,
    album,
    playedAt,
    listenedMs,
    completed,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaybackHistoryData &&
          other.id == this.id &&
          other.trackId == this.trackId &&
          other.title == this.title &&
          other.artist == this.artist &&
          other.album == this.album &&
          other.playedAt == this.playedAt &&
          other.listenedMs == this.listenedMs &&
          other.completed == this.completed);
}

class PlaybackHistoryCompanion extends UpdateCompanion<PlaybackHistoryData> {
  final Value<int> id;
  final Value<String> trackId;
  final Value<String> title;
  final Value<String> artist;
  final Value<String> album;
  final Value<DateTime> playedAt;
  final Value<int> listenedMs;
  final Value<bool> completed;
  const PlaybackHistoryCompanion({
    this.id = const Value.absent(),
    this.trackId = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.playedAt = const Value.absent(),
    this.listenedMs = const Value.absent(),
    this.completed = const Value.absent(),
  });
  PlaybackHistoryCompanion.insert({
    this.id = const Value.absent(),
    required String trackId,
    required String title,
    required String artist,
    required String album,
    required DateTime playedAt,
    this.listenedMs = const Value.absent(),
    this.completed = const Value.absent(),
  }) : trackId = Value(trackId),
       title = Value(title),
       artist = Value(artist),
       album = Value(album),
       playedAt = Value(playedAt);
  static Insertable<PlaybackHistoryData> custom({
    Expression<int>? id,
    Expression<String>? trackId,
    Expression<String>? title,
    Expression<String>? artist,
    Expression<String>? album,
    Expression<DateTime>? playedAt,
    Expression<int>? listenedMs,
    Expression<bool>? completed,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trackId != null) 'track_id': trackId,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (album != null) 'album': album,
      if (playedAt != null) 'played_at': playedAt,
      if (listenedMs != null) 'listened_ms': listenedMs,
      if (completed != null) 'completed': completed,
    });
  }

  PlaybackHistoryCompanion copyWith({
    Value<int>? id,
    Value<String>? trackId,
    Value<String>? title,
    Value<String>? artist,
    Value<String>? album,
    Value<DateTime>? playedAt,
    Value<int>? listenedMs,
    Value<bool>? completed,
  }) {
    return PlaybackHistoryCompanion(
      id: id ?? this.id,
      trackId: trackId ?? this.trackId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      playedAt: playedAt ?? this.playedAt,
      listenedMs: listenedMs ?? this.listenedMs,
      completed: completed ?? this.completed,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<String>(trackId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (album.present) {
      map['album'] = Variable<String>(album.value);
    }
    if (playedAt.present) {
      map['played_at'] = Variable<DateTime>(playedAt.value);
    }
    if (listenedMs.present) {
      map['listened_ms'] = Variable<int>(listenedMs.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackHistoryCompanion(')
          ..write('id: $id, ')
          ..write('trackId: $trackId, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('playedAt: $playedAt, ')
          ..write('listenedMs: $listenedMs, ')
          ..write('completed: $completed')
          ..write(')'))
        .toString();
  }
}

class $TrackAnalysisTable extends TrackAnalysis
    with TableInfo<$TrackAnalysisTable, TrackAnalysi> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrackAnalysisTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<String> trackId = GeneratedColumn<String>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES library_tracks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _bpmMeta = const VerificationMeta('bpm');
  @override
  late final GeneratedColumn<double> bpm = GeneratedColumn<double>(
    'bpm',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _musicalKeyMeta = const VerificationMeta(
    'musicalKey',
  );
  @override
  late final GeneratedColumn<String> musicalKey = GeneratedColumn<String>(
    'musical_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _energyMeta = const VerificationMeta('energy');
  @override
  late final GeneratedColumn<double> energy = GeneratedColumn<double>(
    'energy',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _analysisJsonMeta = const VerificationMeta(
    'analysisJson',
  );
  @override
  late final GeneratedColumn<String> analysisJson = GeneratedColumn<String>(
    'analysis_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _analyzedAtMeta = const VerificationMeta(
    'analyzedAt',
  );
  @override
  late final GeneratedColumn<DateTime> analyzedAt = GeneratedColumn<DateTime>(
    'analyzed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    trackId,
    bpm,
    musicalKey,
    energy,
    analysisJson,
    analyzedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'track_analysis';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrackAnalysi> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('bpm')) {
      context.handle(
        _bpmMeta,
        bpm.isAcceptableOrUnknown(data['bpm']!, _bpmMeta),
      );
    }
    if (data.containsKey('musical_key')) {
      context.handle(
        _musicalKeyMeta,
        musicalKey.isAcceptableOrUnknown(data['musical_key']!, _musicalKeyMeta),
      );
    }
    if (data.containsKey('energy')) {
      context.handle(
        _energyMeta,
        energy.isAcceptableOrUnknown(data['energy']!, _energyMeta),
      );
    }
    if (data.containsKey('analysis_json')) {
      context.handle(
        _analysisJsonMeta,
        analysisJson.isAcceptableOrUnknown(
          data['analysis_json']!,
          _analysisJsonMeta,
        ),
      );
    }
    if (data.containsKey('analyzed_at')) {
      context.handle(
        _analyzedAtMeta,
        analyzedAt.isAcceptableOrUnknown(data['analyzed_at']!, _analyzedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_analyzedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {trackId};
  @override
  TrackAnalysi map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrackAnalysi(
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_id'],
      )!,
      bpm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}bpm'],
      ),
      musicalKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}musical_key'],
      ),
      energy: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}energy'],
      ),
      analysisJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}analysis_json'],
      ),
      analyzedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}analyzed_at'],
      )!,
    );
  }

  @override
  $TrackAnalysisTable createAlias(String alias) {
    return $TrackAnalysisTable(attachedDatabase, alias);
  }
}

class TrackAnalysi extends DataClass implements Insertable<TrackAnalysi> {
  final String trackId;
  final double? bpm;
  final String? musicalKey;
  final double? energy;
  final String? analysisJson;
  final DateTime analyzedAt;
  const TrackAnalysi({
    required this.trackId,
    this.bpm,
    this.musicalKey,
    this.energy,
    this.analysisJson,
    required this.analyzedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['track_id'] = Variable<String>(trackId);
    if (!nullToAbsent || bpm != null) {
      map['bpm'] = Variable<double>(bpm);
    }
    if (!nullToAbsent || musicalKey != null) {
      map['musical_key'] = Variable<String>(musicalKey);
    }
    if (!nullToAbsent || energy != null) {
      map['energy'] = Variable<double>(energy);
    }
    if (!nullToAbsent || analysisJson != null) {
      map['analysis_json'] = Variable<String>(analysisJson);
    }
    map['analyzed_at'] = Variable<DateTime>(analyzedAt);
    return map;
  }

  TrackAnalysisCompanion toCompanion(bool nullToAbsent) {
    return TrackAnalysisCompanion(
      trackId: Value(trackId),
      bpm: bpm == null && nullToAbsent ? const Value.absent() : Value(bpm),
      musicalKey: musicalKey == null && nullToAbsent
          ? const Value.absent()
          : Value(musicalKey),
      energy: energy == null && nullToAbsent
          ? const Value.absent()
          : Value(energy),
      analysisJson: analysisJson == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisJson),
      analyzedAt: Value(analyzedAt),
    );
  }

  factory TrackAnalysi.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrackAnalysi(
      trackId: serializer.fromJson<String>(json['trackId']),
      bpm: serializer.fromJson<double?>(json['bpm']),
      musicalKey: serializer.fromJson<String?>(json['musicalKey']),
      energy: serializer.fromJson<double?>(json['energy']),
      analysisJson: serializer.fromJson<String?>(json['analysisJson']),
      analyzedAt: serializer.fromJson<DateTime>(json['analyzedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trackId': serializer.toJson<String>(trackId),
      'bpm': serializer.toJson<double?>(bpm),
      'musicalKey': serializer.toJson<String?>(musicalKey),
      'energy': serializer.toJson<double?>(energy),
      'analysisJson': serializer.toJson<String?>(analysisJson),
      'analyzedAt': serializer.toJson<DateTime>(analyzedAt),
    };
  }

  TrackAnalysi copyWith({
    String? trackId,
    Value<double?> bpm = const Value.absent(),
    Value<String?> musicalKey = const Value.absent(),
    Value<double?> energy = const Value.absent(),
    Value<String?> analysisJson = const Value.absent(),
    DateTime? analyzedAt,
  }) => TrackAnalysi(
    trackId: trackId ?? this.trackId,
    bpm: bpm.present ? bpm.value : this.bpm,
    musicalKey: musicalKey.present ? musicalKey.value : this.musicalKey,
    energy: energy.present ? energy.value : this.energy,
    analysisJson: analysisJson.present ? analysisJson.value : this.analysisJson,
    analyzedAt: analyzedAt ?? this.analyzedAt,
  );
  TrackAnalysi copyWithCompanion(TrackAnalysisCompanion data) {
    return TrackAnalysi(
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      bpm: data.bpm.present ? data.bpm.value : this.bpm,
      musicalKey: data.musicalKey.present
          ? data.musicalKey.value
          : this.musicalKey,
      energy: data.energy.present ? data.energy.value : this.energy,
      analysisJson: data.analysisJson.present
          ? data.analysisJson.value
          : this.analysisJson,
      analyzedAt: data.analyzedAt.present
          ? data.analyzedAt.value
          : this.analyzedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrackAnalysi(')
          ..write('trackId: $trackId, ')
          ..write('bpm: $bpm, ')
          ..write('musicalKey: $musicalKey, ')
          ..write('energy: $energy, ')
          ..write('analysisJson: $analysisJson, ')
          ..write('analyzedAt: $analyzedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(trackId, bpm, musicalKey, energy, analysisJson, analyzedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrackAnalysi &&
          other.trackId == this.trackId &&
          other.bpm == this.bpm &&
          other.musicalKey == this.musicalKey &&
          other.energy == this.energy &&
          other.analysisJson == this.analysisJson &&
          other.analyzedAt == this.analyzedAt);
}

class TrackAnalysisCompanion extends UpdateCompanion<TrackAnalysi> {
  final Value<String> trackId;
  final Value<double?> bpm;
  final Value<String?> musicalKey;
  final Value<double?> energy;
  final Value<String?> analysisJson;
  final Value<DateTime> analyzedAt;
  final Value<int> rowid;
  const TrackAnalysisCompanion({
    this.trackId = const Value.absent(),
    this.bpm = const Value.absent(),
    this.musicalKey = const Value.absent(),
    this.energy = const Value.absent(),
    this.analysisJson = const Value.absent(),
    this.analyzedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TrackAnalysisCompanion.insert({
    required String trackId,
    this.bpm = const Value.absent(),
    this.musicalKey = const Value.absent(),
    this.energy = const Value.absent(),
    this.analysisJson = const Value.absent(),
    required DateTime analyzedAt,
    this.rowid = const Value.absent(),
  }) : trackId = Value(trackId),
       analyzedAt = Value(analyzedAt);
  static Insertable<TrackAnalysi> custom({
    Expression<String>? trackId,
    Expression<double>? bpm,
    Expression<String>? musicalKey,
    Expression<double>? energy,
    Expression<String>? analysisJson,
    Expression<DateTime>? analyzedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (trackId != null) 'track_id': trackId,
      if (bpm != null) 'bpm': bpm,
      if (musicalKey != null) 'musical_key': musicalKey,
      if (energy != null) 'energy': energy,
      if (analysisJson != null) 'analysis_json': analysisJson,
      if (analyzedAt != null) 'analyzed_at': analyzedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TrackAnalysisCompanion copyWith({
    Value<String>? trackId,
    Value<double?>? bpm,
    Value<String?>? musicalKey,
    Value<double?>? energy,
    Value<String?>? analysisJson,
    Value<DateTime>? analyzedAt,
    Value<int>? rowid,
  }) {
    return TrackAnalysisCompanion(
      trackId: trackId ?? this.trackId,
      bpm: bpm ?? this.bpm,
      musicalKey: musicalKey ?? this.musicalKey,
      energy: energy ?? this.energy,
      analysisJson: analysisJson ?? this.analysisJson,
      analyzedAt: analyzedAt ?? this.analyzedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (trackId.present) {
      map['track_id'] = Variable<String>(trackId.value);
    }
    if (bpm.present) {
      map['bpm'] = Variable<double>(bpm.value);
    }
    if (musicalKey.present) {
      map['musical_key'] = Variable<String>(musicalKey.value);
    }
    if (energy.present) {
      map['energy'] = Variable<double>(energy.value);
    }
    if (analysisJson.present) {
      map['analysis_json'] = Variable<String>(analysisJson.value);
    }
    if (analyzedAt.present) {
      map['analyzed_at'] = Variable<DateTime>(analyzedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrackAnalysisCompanion(')
          ..write('trackId: $trackId, ')
          ..write('bpm: $bpm, ')
          ..write('musicalKey: $musicalKey, ')
          ..write('energy: $energy, ')
          ..write('analysisJson: $analysisJson, ')
          ..write('analyzedAt: $analyzedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ArtworkCacheTable extends ArtworkCache
    with TableInfo<$ArtworkCacheTable, ArtworkCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ArtworkCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceUriMeta = const VerificationMeta(
    'sourceUri',
  );
  @override
  late final GeneratedColumn<String> sourceUri = GeneratedColumn<String>(
    'source_uri',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedPathMeta = const VerificationMeta(
    'cachedPath',
  );
  @override
  late final GeneratedColumn<String> cachedPath = GeneratedColumn<String>(
    'cached_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _byteLengthMeta = const VerificationMeta(
    'byteLength',
  );
  @override
  late final GeneratedColumn<int> byteLength = GeneratedColumn<int>(
    'byte_length',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
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
        requiredDuringInsert: true,
      );
  @override
  List<GeneratedColumn> get $columns => [
    sourceUri,
    cachedPath,
    byteLength,
    cachedAt,
    lastAccessedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'artwork_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<ArtworkCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_uri')) {
      context.handle(
        _sourceUriMeta,
        sourceUri.isAcceptableOrUnknown(data['source_uri']!, _sourceUriMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceUriMeta);
    }
    if (data.containsKey('cached_path')) {
      context.handle(
        _cachedPathMeta,
        cachedPath.isAcceptableOrUnknown(data['cached_path']!, _cachedPathMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedPathMeta);
    }
    if (data.containsKey('byte_length')) {
      context.handle(
        _byteLengthMeta,
        byteLength.isAcceptableOrUnknown(data['byte_length']!, _byteLengthMeta),
      );
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    if (data.containsKey('last_accessed_at')) {
      context.handle(
        _lastAccessedAtMeta,
        lastAccessedAt.isAcceptableOrUnknown(
          data['last_accessed_at']!,
          _lastAccessedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastAccessedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sourceUri};
  @override
  ArtworkCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ArtworkCacheData(
      sourceUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_uri'],
      )!,
      cachedPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cached_path'],
      )!,
      byteLength: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}byte_length'],
      ),
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
      lastAccessedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_accessed_at'],
      )!,
    );
  }

  @override
  $ArtworkCacheTable createAlias(String alias) {
    return $ArtworkCacheTable(attachedDatabase, alias);
  }
}

class ArtworkCacheData extends DataClass
    implements Insertable<ArtworkCacheData> {
  final String sourceUri;
  final String cachedPath;
  final int? byteLength;
  final DateTime cachedAt;
  final DateTime lastAccessedAt;
  const ArtworkCacheData({
    required this.sourceUri,
    required this.cachedPath,
    this.byteLength,
    required this.cachedAt,
    required this.lastAccessedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_uri'] = Variable<String>(sourceUri);
    map['cached_path'] = Variable<String>(cachedPath);
    if (!nullToAbsent || byteLength != null) {
      map['byte_length'] = Variable<int>(byteLength);
    }
    map['cached_at'] = Variable<DateTime>(cachedAt);
    map['last_accessed_at'] = Variable<DateTime>(lastAccessedAt);
    return map;
  }

  ArtworkCacheCompanion toCompanion(bool nullToAbsent) {
    return ArtworkCacheCompanion(
      sourceUri: Value(sourceUri),
      cachedPath: Value(cachedPath),
      byteLength: byteLength == null && nullToAbsent
          ? const Value.absent()
          : Value(byteLength),
      cachedAt: Value(cachedAt),
      lastAccessedAt: Value(lastAccessedAt),
    );
  }

  factory ArtworkCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ArtworkCacheData(
      sourceUri: serializer.fromJson<String>(json['sourceUri']),
      cachedPath: serializer.fromJson<String>(json['cachedPath']),
      byteLength: serializer.fromJson<int?>(json['byteLength']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
      lastAccessedAt: serializer.fromJson<DateTime>(json['lastAccessedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceUri': serializer.toJson<String>(sourceUri),
      'cachedPath': serializer.toJson<String>(cachedPath),
      'byteLength': serializer.toJson<int?>(byteLength),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
      'lastAccessedAt': serializer.toJson<DateTime>(lastAccessedAt),
    };
  }

  ArtworkCacheData copyWith({
    String? sourceUri,
    String? cachedPath,
    Value<int?> byteLength = const Value.absent(),
    DateTime? cachedAt,
    DateTime? lastAccessedAt,
  }) => ArtworkCacheData(
    sourceUri: sourceUri ?? this.sourceUri,
    cachedPath: cachedPath ?? this.cachedPath,
    byteLength: byteLength.present ? byteLength.value : this.byteLength,
    cachedAt: cachedAt ?? this.cachedAt,
    lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
  );
  ArtworkCacheData copyWithCompanion(ArtworkCacheCompanion data) {
    return ArtworkCacheData(
      sourceUri: data.sourceUri.present ? data.sourceUri.value : this.sourceUri,
      cachedPath: data.cachedPath.present
          ? data.cachedPath.value
          : this.cachedPath,
      byteLength: data.byteLength.present
          ? data.byteLength.value
          : this.byteLength,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
      lastAccessedAt: data.lastAccessedAt.present
          ? data.lastAccessedAt.value
          : this.lastAccessedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ArtworkCacheData(')
          ..write('sourceUri: $sourceUri, ')
          ..write('cachedPath: $cachedPath, ')
          ..write('byteLength: $byteLength, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('lastAccessedAt: $lastAccessedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(sourceUri, cachedPath, byteLength, cachedAt, lastAccessedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ArtworkCacheData &&
          other.sourceUri == this.sourceUri &&
          other.cachedPath == this.cachedPath &&
          other.byteLength == this.byteLength &&
          other.cachedAt == this.cachedAt &&
          other.lastAccessedAt == this.lastAccessedAt);
}

class ArtworkCacheCompanion extends UpdateCompanion<ArtworkCacheData> {
  final Value<String> sourceUri;
  final Value<String> cachedPath;
  final Value<int?> byteLength;
  final Value<DateTime> cachedAt;
  final Value<DateTime> lastAccessedAt;
  final Value<int> rowid;
  const ArtworkCacheCompanion({
    this.sourceUri = const Value.absent(),
    this.cachedPath = const Value.absent(),
    this.byteLength = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.lastAccessedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ArtworkCacheCompanion.insert({
    required String sourceUri,
    required String cachedPath,
    this.byteLength = const Value.absent(),
    required DateTime cachedAt,
    required DateTime lastAccessedAt,
    this.rowid = const Value.absent(),
  }) : sourceUri = Value(sourceUri),
       cachedPath = Value(cachedPath),
       cachedAt = Value(cachedAt),
       lastAccessedAt = Value(lastAccessedAt);
  static Insertable<ArtworkCacheData> custom({
    Expression<String>? sourceUri,
    Expression<String>? cachedPath,
    Expression<int>? byteLength,
    Expression<DateTime>? cachedAt,
    Expression<DateTime>? lastAccessedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceUri != null) 'source_uri': sourceUri,
      if (cachedPath != null) 'cached_path': cachedPath,
      if (byteLength != null) 'byte_length': byteLength,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (lastAccessedAt != null) 'last_accessed_at': lastAccessedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ArtworkCacheCompanion copyWith({
    Value<String>? sourceUri,
    Value<String>? cachedPath,
    Value<int?>? byteLength,
    Value<DateTime>? cachedAt,
    Value<DateTime>? lastAccessedAt,
    Value<int>? rowid,
  }) {
    return ArtworkCacheCompanion(
      sourceUri: sourceUri ?? this.sourceUri,
      cachedPath: cachedPath ?? this.cachedPath,
      byteLength: byteLength ?? this.byteLength,
      cachedAt: cachedAt ?? this.cachedAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceUri.present) {
      map['source_uri'] = Variable<String>(sourceUri.value);
    }
    if (cachedPath.present) {
      map['cached_path'] = Variable<String>(cachedPath.value);
    }
    if (byteLength.present) {
      map['byte_length'] = Variable<int>(byteLength.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
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
    return (StringBuffer('ArtworkCacheCompanion(')
          ..write('sourceUri: $sourceUri, ')
          ..write('cachedPath: $cachedPath, ')
          ..write('byteLength: $byteLength, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('lastAccessedAt: $lastAccessedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadsTable extends Downloads
    with TableInfo<$DownloadsTable, Download> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<String> trackId = GeneratedColumn<String>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES library_tracks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerTrackIdMeta = const VerificationMeta(
    'providerTrackId',
  );
  @override
  late final GeneratedColumn<String> providerTrackId = GeneratedColumn<String>(
    'provider_track_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _licenseUrlMeta = const VerificationMeta(
    'licenseUrl',
  );
  @override
  late final GeneratedColumn<String> licenseUrl = GeneratedColumn<String>(
    'license_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    trackId,
    provider,
    providerTrackId,
    licenseUrl,
    downloadedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'downloads';
  @override
  VerificationContext validateIntegrity(
    Insertable<Download> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('provider_track_id')) {
      context.handle(
        _providerTrackIdMeta,
        providerTrackId.isAcceptableOrUnknown(
          data['provider_track_id']!,
          _providerTrackIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_providerTrackIdMeta);
    }
    if (data.containsKey('license_url')) {
      context.handle(
        _licenseUrlMeta,
        licenseUrl.isAcceptableOrUnknown(data['license_url']!, _licenseUrlMeta),
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
    } else if (isInserting) {
      context.missing(_downloadedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {trackId};
  @override
  Download map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Download(
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_id'],
      )!,
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      )!,
      providerTrackId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_track_id'],
      )!,
      licenseUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}license_url'],
      ),
      downloadedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}downloaded_at'],
      )!,
    );
  }

  @override
  $DownloadsTable createAlias(String alias) {
    return $DownloadsTable(attachedDatabase, alias);
  }
}

class Download extends DataClass implements Insertable<Download> {
  final String trackId;
  final String provider;
  final String providerTrackId;
  final String? licenseUrl;
  final DateTime downloadedAt;
  const Download({
    required this.trackId,
    required this.provider,
    required this.providerTrackId,
    this.licenseUrl,
    required this.downloadedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['track_id'] = Variable<String>(trackId);
    map['provider'] = Variable<String>(provider);
    map['provider_track_id'] = Variable<String>(providerTrackId);
    if (!nullToAbsent || licenseUrl != null) {
      map['license_url'] = Variable<String>(licenseUrl);
    }
    map['downloaded_at'] = Variable<DateTime>(downloadedAt);
    return map;
  }

  DownloadsCompanion toCompanion(bool nullToAbsent) {
    return DownloadsCompanion(
      trackId: Value(trackId),
      provider: Value(provider),
      providerTrackId: Value(providerTrackId),
      licenseUrl: licenseUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(licenseUrl),
      downloadedAt: Value(downloadedAt),
    );
  }

  factory Download.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Download(
      trackId: serializer.fromJson<String>(json['trackId']),
      provider: serializer.fromJson<String>(json['provider']),
      providerTrackId: serializer.fromJson<String>(json['providerTrackId']),
      licenseUrl: serializer.fromJson<String?>(json['licenseUrl']),
      downloadedAt: serializer.fromJson<DateTime>(json['downloadedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trackId': serializer.toJson<String>(trackId),
      'provider': serializer.toJson<String>(provider),
      'providerTrackId': serializer.toJson<String>(providerTrackId),
      'licenseUrl': serializer.toJson<String?>(licenseUrl),
      'downloadedAt': serializer.toJson<DateTime>(downloadedAt),
    };
  }

  Download copyWith({
    String? trackId,
    String? provider,
    String? providerTrackId,
    Value<String?> licenseUrl = const Value.absent(),
    DateTime? downloadedAt,
  }) => Download(
    trackId: trackId ?? this.trackId,
    provider: provider ?? this.provider,
    providerTrackId: providerTrackId ?? this.providerTrackId,
    licenseUrl: licenseUrl.present ? licenseUrl.value : this.licenseUrl,
    downloadedAt: downloadedAt ?? this.downloadedAt,
  );
  Download copyWithCompanion(DownloadsCompanion data) {
    return Download(
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      provider: data.provider.present ? data.provider.value : this.provider,
      providerTrackId: data.providerTrackId.present
          ? data.providerTrackId.value
          : this.providerTrackId,
      licenseUrl: data.licenseUrl.present
          ? data.licenseUrl.value
          : this.licenseUrl,
      downloadedAt: data.downloadedAt.present
          ? data.downloadedAt.value
          : this.downloadedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Download(')
          ..write('trackId: $trackId, ')
          ..write('provider: $provider, ')
          ..write('providerTrackId: $providerTrackId, ')
          ..write('licenseUrl: $licenseUrl, ')
          ..write('downloadedAt: $downloadedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(trackId, provider, providerTrackId, licenseUrl, downloadedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Download &&
          other.trackId == this.trackId &&
          other.provider == this.provider &&
          other.providerTrackId == this.providerTrackId &&
          other.licenseUrl == this.licenseUrl &&
          other.downloadedAt == this.downloadedAt);
}

class DownloadsCompanion extends UpdateCompanion<Download> {
  final Value<String> trackId;
  final Value<String> provider;
  final Value<String> providerTrackId;
  final Value<String?> licenseUrl;
  final Value<DateTime> downloadedAt;
  final Value<int> rowid;
  const DownloadsCompanion({
    this.trackId = const Value.absent(),
    this.provider = const Value.absent(),
    this.providerTrackId = const Value.absent(),
    this.licenseUrl = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadsCompanion.insert({
    required String trackId,
    required String provider,
    required String providerTrackId,
    this.licenseUrl = const Value.absent(),
    required DateTime downloadedAt,
    this.rowid = const Value.absent(),
  }) : trackId = Value(trackId),
       provider = Value(provider),
       providerTrackId = Value(providerTrackId),
       downloadedAt = Value(downloadedAt);
  static Insertable<Download> custom({
    Expression<String>? trackId,
    Expression<String>? provider,
    Expression<String>? providerTrackId,
    Expression<String>? licenseUrl,
    Expression<DateTime>? downloadedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (trackId != null) 'track_id': trackId,
      if (provider != null) 'provider': provider,
      if (providerTrackId != null) 'provider_track_id': providerTrackId,
      if (licenseUrl != null) 'license_url': licenseUrl,
      if (downloadedAt != null) 'downloaded_at': downloadedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadsCompanion copyWith({
    Value<String>? trackId,
    Value<String>? provider,
    Value<String>? providerTrackId,
    Value<String?>? licenseUrl,
    Value<DateTime>? downloadedAt,
    Value<int>? rowid,
  }) {
    return DownloadsCompanion(
      trackId: trackId ?? this.trackId,
      provider: provider ?? this.provider,
      providerTrackId: providerTrackId ?? this.providerTrackId,
      licenseUrl: licenseUrl ?? this.licenseUrl,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (trackId.present) {
      map['track_id'] = Variable<String>(trackId.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (providerTrackId.present) {
      map['provider_track_id'] = Variable<String>(providerTrackId.value);
    }
    if (licenseUrl.present) {
      map['license_url'] = Variable<String>(licenseUrl.value);
    }
    if (downloadedAt.present) {
      map['downloaded_at'] = Variable<DateTime>(downloadedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadsCompanion(')
          ..write('trackId: $trackId, ')
          ..write('provider: $provider, ')
          ..write('providerTrackId: $providerTrackId, ')
          ..write('licenseUrl: $licenseUrl, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DjSessionsTable extends DjSessions
    with TableInfo<$DjSessionsTable, DjSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DjSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _settingsJsonMeta = const VerificationMeta(
    'settingsJson',
  );
  @override
  late final GeneratedColumn<String> settingsJson = GeneratedColumn<String>(
    'settings_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, startedAt, endedAt, settingsJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dj_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<DjSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('settings_json')) {
      context.handle(
        _settingsJsonMeta,
        settingsJson.isAcceptableOrUnknown(
          data['settings_json']!,
          _settingsJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DjSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DjSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
      settingsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}settings_json'],
      ),
    );
  }

  @override
  $DjSessionsTable createAlias(String alias) {
    return $DjSessionsTable(attachedDatabase, alias);
  }
}

class DjSession extends DataClass implements Insertable<DjSession> {
  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? settingsJson;
  const DjSession({
    required this.id,
    required this.startedAt,
    this.endedAt,
    this.settingsJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    if (!nullToAbsent || settingsJson != null) {
      map['settings_json'] = Variable<String>(settingsJson);
    }
    return map;
  }

  DjSessionsCompanion toCompanion(bool nullToAbsent) {
    return DjSessionsCompanion(
      id: Value(id),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      settingsJson: settingsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(settingsJson),
    );
  }

  factory DjSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DjSession(
      id: serializer.fromJson<String>(json['id']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      settingsJson: serializer.fromJson<String?>(json['settingsJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'settingsJson': serializer.toJson<String?>(settingsJson),
    };
  }

  DjSession copyWith({
    String? id,
    DateTime? startedAt,
    Value<DateTime?> endedAt = const Value.absent(),
    Value<String?> settingsJson = const Value.absent(),
  }) => DjSession(
    id: id ?? this.id,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    settingsJson: settingsJson.present ? settingsJson.value : this.settingsJson,
  );
  DjSession copyWithCompanion(DjSessionsCompanion data) {
    return DjSession(
      id: data.id.present ? data.id.value : this.id,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      settingsJson: data.settingsJson.present
          ? data.settingsJson.value
          : this.settingsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DjSession(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('settingsJson: $settingsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, startedAt, endedAt, settingsJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DjSession &&
          other.id == this.id &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.settingsJson == this.settingsJson);
}

class DjSessionsCompanion extends UpdateCompanion<DjSession> {
  final Value<String> id;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<String?> settingsJson;
  final Value<int> rowid;
  const DjSessionsCompanion({
    this.id = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.settingsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DjSessionsCompanion.insert({
    required String id,
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    this.settingsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       startedAt = Value(startedAt);
  static Insertable<DjSession> custom({
    Expression<String>? id,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<String>? settingsJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (settingsJson != null) 'settings_json': settingsJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DjSessionsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endedAt,
    Value<String?>? settingsJson,
    Value<int>? rowid,
  }) {
    return DjSessionsCompanion(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      settingsJson: settingsJson ?? this.settingsJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (settingsJson.present) {
      map['settings_json'] = Variable<String>(settingsJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DjSessionsCompanion(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('settingsJson: $settingsJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DjSessionEventsTable extends DjSessionEvents
    with TableInfo<$DjSessionEventsTable, DjSessionEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DjSessionEventsTable(this.attachedDatabase, [this._alias]);
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
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES dj_sessions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _eventTypeMeta = const VerificationMeta(
    'eventType',
  );
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
    'event_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<String> trackId = GeneratedColumn<String>(
    'track_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    eventType,
    trackId,
    payloadJson,
    occurredAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dj_session_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<DjSessionEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('event_type')) {
      context.handle(
        _eventTypeMeta,
        eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DjSessionEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DjSessionEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      eventType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_type'],
      )!,
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_id'],
      ),
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      ),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
    );
  }

  @override
  $DjSessionEventsTable createAlias(String alias) {
    return $DjSessionEventsTable(attachedDatabase, alias);
  }
}

class DjSessionEvent extends DataClass implements Insertable<DjSessionEvent> {
  final int id;
  final String sessionId;
  final String eventType;
  final String? trackId;
  final String? payloadJson;
  final DateTime occurredAt;
  const DjSessionEvent({
    required this.id,
    required this.sessionId,
    required this.eventType,
    this.trackId,
    this.payloadJson,
    required this.occurredAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['event_type'] = Variable<String>(eventType);
    if (!nullToAbsent || trackId != null) {
      map['track_id'] = Variable<String>(trackId);
    }
    if (!nullToAbsent || payloadJson != null) {
      map['payload_json'] = Variable<String>(payloadJson);
    }
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    return map;
  }

  DjSessionEventsCompanion toCompanion(bool nullToAbsent) {
    return DjSessionEventsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      eventType: Value(eventType),
      trackId: trackId == null && nullToAbsent
          ? const Value.absent()
          : Value(trackId),
      payloadJson: payloadJson == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadJson),
      occurredAt: Value(occurredAt),
    );
  }

  factory DjSessionEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DjSessionEvent(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      eventType: serializer.fromJson<String>(json['eventType']),
      trackId: serializer.fromJson<String?>(json['trackId']),
      payloadJson: serializer.fromJson<String?>(json['payloadJson']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'eventType': serializer.toJson<String>(eventType),
      'trackId': serializer.toJson<String?>(trackId),
      'payloadJson': serializer.toJson<String?>(payloadJson),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
    };
  }

  DjSessionEvent copyWith({
    int? id,
    String? sessionId,
    String? eventType,
    Value<String?> trackId = const Value.absent(),
    Value<String?> payloadJson = const Value.absent(),
    DateTime? occurredAt,
  }) => DjSessionEvent(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    eventType: eventType ?? this.eventType,
    trackId: trackId.present ? trackId.value : this.trackId,
    payloadJson: payloadJson.present ? payloadJson.value : this.payloadJson,
    occurredAt: occurredAt ?? this.occurredAt,
  );
  DjSessionEvent copyWithCompanion(DjSessionEventsCompanion data) {
    return DjSessionEvent(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DjSessionEvent(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('eventType: $eventType, ')
          ..write('trackId: $trackId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('occurredAt: $occurredAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, sessionId, eventType, trackId, payloadJson, occurredAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DjSessionEvent &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.eventType == this.eventType &&
          other.trackId == this.trackId &&
          other.payloadJson == this.payloadJson &&
          other.occurredAt == this.occurredAt);
}

class DjSessionEventsCompanion extends UpdateCompanion<DjSessionEvent> {
  final Value<int> id;
  final Value<String> sessionId;
  final Value<String> eventType;
  final Value<String?> trackId;
  final Value<String?> payloadJson;
  final Value<DateTime> occurredAt;
  const DjSessionEventsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.eventType = const Value.absent(),
    this.trackId = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.occurredAt = const Value.absent(),
  });
  DjSessionEventsCompanion.insert({
    this.id = const Value.absent(),
    required String sessionId,
    required String eventType,
    this.trackId = const Value.absent(),
    this.payloadJson = const Value.absent(),
    required DateTime occurredAt,
  }) : sessionId = Value(sessionId),
       eventType = Value(eventType),
       occurredAt = Value(occurredAt);
  static Insertable<DjSessionEvent> custom({
    Expression<int>? id,
    Expression<String>? sessionId,
    Expression<String>? eventType,
    Expression<String>? trackId,
    Expression<String>? payloadJson,
    Expression<DateTime>? occurredAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (eventType != null) 'event_type': eventType,
      if (trackId != null) 'track_id': trackId,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (occurredAt != null) 'occurred_at': occurredAt,
    });
  }

  DjSessionEventsCompanion copyWith({
    Value<int>? id,
    Value<String>? sessionId,
    Value<String>? eventType,
    Value<String?>? trackId,
    Value<String?>? payloadJson,
    Value<DateTime>? occurredAt,
  }) {
    return DjSessionEventsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      eventType: eventType ?? this.eventType,
      trackId: trackId ?? this.trackId,
      payloadJson: payloadJson ?? this.payloadJson,
      occurredAt: occurredAt ?? this.occurredAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<String>(trackId.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DjSessionEventsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('eventType: $eventType, ')
          ..write('trackId: $trackId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('occurredAt: $occurredAt')
          ..write(')'))
        .toString();
  }
}

class $UserPreferencesTable extends UserPreferences
    with TableInfo<$UserPreferencesTable, UserPreference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserPreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueJsonMeta = const VerificationMeta(
    'valueJson',
  );
  @override
  late final GeneratedColumn<String> valueJson = GeneratedColumn<String>(
    'value_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, valueJson, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserPreference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value_json')) {
      context.handle(
        _valueJsonMeta,
        valueJson.isAcceptableOrUnknown(data['value_json']!, _valueJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_valueJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  UserPreference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserPreference(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      valueJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $UserPreferencesTable createAlias(String alias) {
    return $UserPreferencesTable(attachedDatabase, alias);
  }
}

class UserPreference extends DataClass implements Insertable<UserPreference> {
  final String key;
  final String valueJson;
  final DateTime updatedAt;
  const UserPreference({
    required this.key,
    required this.valueJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value_json'] = Variable<String>(valueJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  UserPreferencesCompanion toCompanion(bool nullToAbsent) {
    return UserPreferencesCompanion(
      key: Value(key),
      valueJson: Value(valueJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory UserPreference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserPreference(
      key: serializer.fromJson<String>(json['key']),
      valueJson: serializer.fromJson<String>(json['valueJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'valueJson': serializer.toJson<String>(valueJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  UserPreference copyWith({
    String? key,
    String? valueJson,
    DateTime? updatedAt,
  }) => UserPreference(
    key: key ?? this.key,
    valueJson: valueJson ?? this.valueJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  UserPreference copyWithCompanion(UserPreferencesCompanion data) {
    return UserPreference(
      key: data.key.present ? data.key.value : this.key,
      valueJson: data.valueJson.present ? data.valueJson.value : this.valueJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserPreference(')
          ..write('key: $key, ')
          ..write('valueJson: $valueJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, valueJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserPreference &&
          other.key == this.key &&
          other.valueJson == this.valueJson &&
          other.updatedAt == this.updatedAt);
}

class UserPreferencesCompanion extends UpdateCompanion<UserPreference> {
  final Value<String> key;
  final Value<String> valueJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const UserPreferencesCompanion({
    this.key = const Value.absent(),
    this.valueJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserPreferencesCompanion.insert({
    required String key,
    required String valueJson,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       valueJson = Value(valueJson),
       updatedAt = Value(updatedAt);
  static Insertable<UserPreference> custom({
    Expression<String>? key,
    Expression<String>? valueJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (valueJson != null) 'value_json': valueJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserPreferencesCompanion copyWith({
    Value<String>? key,
    Value<String>? valueJson,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return UserPreferencesCompanion(
      key: key ?? this.key,
      valueJson: valueJson ?? this.valueJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (valueJson.present) {
      map['value_json'] = Variable<String>(valueJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserPreferencesCompanion(')
          ..write('key: $key, ')
          ..write('valueJson: $valueJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AudioProfilesTable extends AudioProfiles
    with TableInfo<$AudioProfilesTable, AudioProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AudioProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _settingsJsonMeta = const VerificationMeta(
    'settingsJson',
  );
  @override
  late final GeneratedColumn<String> settingsJson = GeneratedColumn<String>(
    'settings_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, settingsJson, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audio_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<AudioProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('settings_json')) {
      context.handle(
        _settingsJsonMeta,
        settingsJson.isAcceptableOrUnknown(
          data['settings_json']!,
          _settingsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_settingsJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AudioProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AudioProfile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      settingsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}settings_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AudioProfilesTable createAlias(String alias) {
    return $AudioProfilesTable(attachedDatabase, alias);
  }
}

class AudioProfile extends DataClass implements Insertable<AudioProfile> {
  final String id;
  final String name;
  final String settingsJson;
  final DateTime updatedAt;
  const AudioProfile({
    required this.id,
    required this.name,
    required this.settingsJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['settings_json'] = Variable<String>(settingsJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AudioProfilesCompanion toCompanion(bool nullToAbsent) {
    return AudioProfilesCompanion(
      id: Value(id),
      name: Value(name),
      settingsJson: Value(settingsJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory AudioProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AudioProfile(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      settingsJson: serializer.fromJson<String>(json['settingsJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'settingsJson': serializer.toJson<String>(settingsJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AudioProfile copyWith({
    String? id,
    String? name,
    String? settingsJson,
    DateTime? updatedAt,
  }) => AudioProfile(
    id: id ?? this.id,
    name: name ?? this.name,
    settingsJson: settingsJson ?? this.settingsJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AudioProfile copyWithCompanion(AudioProfilesCompanion data) {
    return AudioProfile(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      settingsJson: data.settingsJson.present
          ? data.settingsJson.value
          : this.settingsJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AudioProfile(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('settingsJson: $settingsJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, settingsJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AudioProfile &&
          other.id == this.id &&
          other.name == this.name &&
          other.settingsJson == this.settingsJson &&
          other.updatedAt == this.updatedAt);
}

class AudioProfilesCompanion extends UpdateCompanion<AudioProfile> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> settingsJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AudioProfilesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.settingsJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AudioProfilesCompanion.insert({
    required String id,
    required String name,
    required String settingsJson,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       settingsJson = Value(settingsJson),
       updatedAt = Value(updatedAt);
  static Insertable<AudioProfile> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? settingsJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (settingsJson != null) 'settings_json': settingsJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AudioProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? settingsJson,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return AudioProfilesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      settingsJson: settingsJson ?? this.settingsJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (settingsJson.present) {
      map['settings_json'] = Variable<String>(settingsJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AudioProfilesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('settingsJson: $settingsJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$ToneDatabase extends GeneratedDatabase {
  _$ToneDatabase(QueryExecutor e) : super(e);
  $ToneDatabaseManager get managers => $ToneDatabaseManager(this);
  late final $ArtistsTable artists = $ArtistsTable(this);
  late final $AlbumsTable albums = $AlbumsTable(this);
  late final $LibraryTracksTable libraryTracks = $LibraryTracksTable(this);
  late final $LibraryFoldersTable libraryFolders = $LibraryFoldersTable(this);
  late final $PlaylistsTable playlists = $PlaylistsTable(this);
  late final $PlaylistTracksTable playlistTracks = $PlaylistTracksTable(this);
  late final $FavoritesTable favorites = $FavoritesTable(this);
  late final $ExcludedTracksTable excludedTracks = $ExcludedTracksTable(this);
  late final $PlaybackQueueEntriesTable playbackQueueEntries =
      $PlaybackQueueEntriesTable(this);
  late final $PlaybackStateTable playbackState = $PlaybackStateTable(this);
  late final $PlaybackHistoryTable playbackHistory = $PlaybackHistoryTable(
    this,
  );
  late final $TrackAnalysisTable trackAnalysis = $TrackAnalysisTable(this);
  late final $ArtworkCacheTable artworkCache = $ArtworkCacheTable(this);
  late final $DownloadsTable downloads = $DownloadsTable(this);
  late final $DjSessionsTable djSessions = $DjSessionsTable(this);
  late final $DjSessionEventsTable djSessionEvents = $DjSessionEventsTable(
    this,
  );
  late final $UserPreferencesTable userPreferences = $UserPreferencesTable(
    this,
  );
  late final $AudioProfilesTable audioProfiles = $AudioProfilesTable(this);
  late final Index tracksTitleIdx = Index(
    'tracks_title_idx',
    'CREATE INDEX tracks_title_idx ON library_tracks (title)',
  );
  late final Index tracksArtistIdx = Index(
    'tracks_artist_idx',
    'CREATE INDEX tracks_artist_idx ON library_tracks (artist)',
  );
  late final Index tracksAlbumIdx = Index(
    'tracks_album_idx',
    'CREATE INDEX tracks_album_idx ON library_tracks (album)',
  );
  late final Index tracksAvailabilityIdx = Index(
    'tracks_availability_idx',
    'CREATE INDEX tracks_availability_idx ON library_tracks (is_available)',
  );
  late final Index tracksArtistAlbumIdx = Index(
    'tracks_artist_album_idx',
    'CREATE INDEX tracks_artist_album_idx ON library_tracks (artist_id, album_id)',
  );
  late final Index tracksOrderIdx = Index(
    'tracks_order_idx',
    'CREATE INDEX tracks_order_idx ON library_tracks (position)',
  );
  late final Index playlistsNameIdx = Index(
    'playlists_name_idx',
    'CREATE INDEX playlists_name_idx ON playlists (name)',
  );
  late final Index playlistsOrderIdx = Index(
    'playlists_order_idx',
    'CREATE INDEX playlists_order_idx ON playlists (position)',
  );
  late final Index playlistTracksOrderIdx = Index(
    'playlist_tracks_order_idx',
    'CREATE UNIQUE INDEX playlist_tracks_order_idx ON playlist_tracks (playlist_id, position)',
  );
  late final Index playbackQueueOrderIdx = Index(
    'playback_queue_order_idx',
    'CREATE UNIQUE INDEX playback_queue_order_idx ON playback_queue_entries (position)',
  );
  late final Index playbackHistoryTimeIdx = Index(
    'playback_history_time_idx',
    'CREATE INDEX playback_history_time_idx ON playback_history (played_at)',
  );
  late final Index playbackHistoryTrackIdx = Index(
    'playback_history_track_idx',
    'CREATE INDEX playback_history_track_idx ON playback_history (track_id, played_at)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    artists,
    albums,
    libraryTracks,
    libraryFolders,
    playlists,
    playlistTracks,
    favorites,
    excludedTracks,
    playbackQueueEntries,
    playbackState,
    playbackHistory,
    trackAnalysis,
    artworkCache,
    downloads,
    djSessions,
    djSessionEvents,
    userPreferences,
    audioProfiles,
    tracksTitleIdx,
    tracksArtistIdx,
    tracksAlbumIdx,
    tracksAvailabilityIdx,
    tracksArtistAlbumIdx,
    tracksOrderIdx,
    playlistsNameIdx,
    playlistsOrderIdx,
    playlistTracksOrderIdx,
    playbackQueueOrderIdx,
    playbackHistoryTimeIdx,
    playbackHistoryTrackIdx,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'playlists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('playlist_tracks', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'library_tracks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('playlist_tracks', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'library_tracks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('favorites', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'library_tracks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('excluded_tracks', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'library_tracks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('track_analysis', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'library_tracks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('downloads', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'dj_sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('dj_session_events', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$ArtistsTableCreateCompanionBuilder = ArtistsCompanion Function({
  required String id,
  required String name,
  required String normalizedName,
  Value<int> rowid,
});
typedef $$ArtistsTableUpdateCompanionBuilder = ArtistsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> normalizedName,
  Value<int> rowid,
});

final class $$ArtistsTableReferences
    extends BaseReferences<_$ToneDatabase, $ArtistsTable, Artist> {
  $$ArtistsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$AlbumsTable, List<Album>> _albumsRefsTable(
    _$ToneDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.albums,
    aliasName: 'artists__id__albums__artist_id',
  );

  $$AlbumsTableProcessedTableManager get albumsRefs {
    final manager = $$AlbumsTableTableManager(
      $_db,
      $_db.albums,
    ).filter((f) => f.artistId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_albumsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LibraryTracksTable, List<LibraryTrack>>
  _libraryTracksRefsTable(_$ToneDatabase db) => MultiTypedResultKey.fromTable(
    db.libraryTracks,
    aliasName: 'artists__id__library_tracks__artist_id',
  );

  $$LibraryTracksTableProcessedTableManager get libraryTracksRefs {
    final manager = $$LibraryTracksTableTableManager(
      $_db,
      $_db.libraryTracks,
    ).filter((f) => f.artistId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_libraryTracksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ArtistsTableFilterComposer
    extends Composer<_$ToneDatabase, $ArtistsTable> {
  $$ArtistsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> albumsRefs(
    Expression<bool> Function($$AlbumsTableFilterComposer f) f,
  ) {
    final $$AlbumsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.albums,
      getReferencedColumn: (t) => t.artistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlbumsTableFilterComposer(
            $db: $db,
            $table: $db.albums,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> libraryTracksRefs(
    Expression<bool> Function($$LibraryTracksTableFilterComposer f) f,
  ) {
    final $$LibraryTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.libraryTracks,
      getReferencedColumn: (t) => t.artistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryTracksTableFilterComposer(
            $db: $db,
            $table: $db.libraryTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ArtistsTableOrderingComposer
    extends Composer<_$ToneDatabase, $ArtistsTable> {
  $$ArtistsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ArtistsTableAnnotationComposer
    extends Composer<_$ToneDatabase, $ArtistsTable> {
  $$ArtistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => column,
  );

  Expression<T> albumsRefs<T extends Object>(
    Expression<T> Function($$AlbumsTableAnnotationComposer a) f,
  ) {
    final $$AlbumsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.albums,
      getReferencedColumn: (t) => t.artistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlbumsTableAnnotationComposer(
            $db: $db,
            $table: $db.albums,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> libraryTracksRefs<T extends Object>(
    Expression<T> Function($$LibraryTracksTableAnnotationComposer a) f,
  ) {
    final $$LibraryTracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.libraryTracks,
      getReferencedColumn: (t) => t.artistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryTracksTableAnnotationComposer(
            $db: $db,
            $table: $db.libraryTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ArtistsTableTableManager
    extends
        RootTableManager<
          _$ToneDatabase,
          $ArtistsTable,
          Artist,
          $$ArtistsTableFilterComposer,
          $$ArtistsTableOrderingComposer,
          $$ArtistsTableAnnotationComposer,
          $$ArtistsTableCreateCompanionBuilder,
          $$ArtistsTableUpdateCompanionBuilder,
          (Artist, $$ArtistsTableReferences),
          Artist,
          PrefetchHooks Function({bool albumsRefs, bool libraryTracksRefs})
        > {
  $$ArtistsTableTableManager(_$ToneDatabase db, $ArtistsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ArtistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ArtistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ArtistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> normalizedName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ArtistsCompanion(
                id: id,
                name: name,
                normalizedName: normalizedName,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String normalizedName,
                Value<int> rowid = const Value.absent(),
              }) => ArtistsCompanion.insert(
                id: id,
                name: name,
                normalizedName: normalizedName,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ArtistsTable, Artist>(table),
                  $$ArtistsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({albumsRefs = false, libraryTracksRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (albumsRefs) db.albums,
                    if (libraryTracksRefs) db.libraryTracks,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (albumsRefs)
                        await $_getPrefetchedDataByColumns<
                          Artist,
                          $ArtistsTable,
                          Album,
                          $AlbumsTable
                        >(
                          currentTable: table,
                          referencedTable: $$ArtistsTableReferences
                              ._albumsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ArtistsTableReferences(
                                db,
                                table,
                                p0,
                              ).albumsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'artist_id',
                          typedResults: items,
                        ),
                      if (libraryTracksRefs)
                        await $_getPrefetchedDataByColumns<
                          Artist,
                          $ArtistsTable,
                          LibraryTrack,
                          $LibraryTracksTable
                        >(
                          currentTable: table,
                          referencedTable: $$ArtistsTableReferences
                              ._libraryTracksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ArtistsTableReferences(
                                db,
                                table,
                                p0,
                              ).libraryTracksRefs,
                          currentColumn: 'id',
                          referencedColumn: 'artist_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ArtistsTableProcessedTableManager =
    ProcessedTableManager<
      _$ToneDatabase,
      $ArtistsTable,
      Artist,
      $$ArtistsTableFilterComposer,
      $$ArtistsTableOrderingComposer,
      $$ArtistsTableAnnotationComposer,
      $$ArtistsTableCreateCompanionBuilder,
      $$ArtistsTableUpdateCompanionBuilder,
      (Artist, $$ArtistsTableReferences),
      Artist,
      PrefetchHooks Function({bool albumsRefs, bool libraryTracksRefs})
    >;
typedef $$AlbumsTableCreateCompanionBuilder = AlbumsCompanion Function({
  required String id,
  required String title,
  required String artistId,
  Value<int?> year,
  Value<String?> artworkUri,
  Value<int> rowid,
});
typedef $$AlbumsTableUpdateCompanionBuilder = AlbumsCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<String> artistId,
  Value<int?> year,
  Value<String?> artworkUri,
  Value<int> rowid,
});

final class $$AlbumsTableReferences
    extends BaseReferences<_$ToneDatabase, $AlbumsTable, Album> {
  $$AlbumsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ArtistsTable _artistIdTable(_$ToneDatabase db) =>
      db.artists.createAlias('albums__artist_id__artists__id');

  $$ArtistsTableProcessedTableManager get artistId {
    final $_column = $_itemColumn<String>('artist_id')!;

    final manager = $$ArtistsTableTableManager(
      $_db,
      $_db.artists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_artistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$LibraryTracksTable, List<LibraryTrack>>
  _libraryTracksRefsTable(_$ToneDatabase db) => MultiTypedResultKey.fromTable(
    db.libraryTracks,
    aliasName: 'albums__id__library_tracks__album_id',
  );

  $$LibraryTracksTableProcessedTableManager get libraryTracksRefs {
    final manager = $$LibraryTracksTableTableManager(
      $_db,
      $_db.libraryTracks,
    ).filter((f) => f.albumId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_libraryTracksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AlbumsTableFilterComposer
    extends Composer<_$ToneDatabase, $AlbumsTable> {
  $$AlbumsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artworkUri => $composableBuilder(
    column: $table.artworkUri,
    builder: (column) => ColumnFilters(column),
  );

  $$ArtistsTableFilterComposer get artistId {
    final $$ArtistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.artistId,
      referencedTable: $db.artists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArtistsTableFilterComposer(
            $db: $db,
            $table: $db.artists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> libraryTracksRefs(
    Expression<bool> Function($$LibraryTracksTableFilterComposer f) f,
  ) {
    final $$LibraryTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.libraryTracks,
      getReferencedColumn: (t) => t.albumId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryTracksTableFilterComposer(
            $db: $db,
            $table: $db.libraryTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AlbumsTableOrderingComposer
    extends Composer<_$ToneDatabase, $AlbumsTable> {
  $$AlbumsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artworkUri => $composableBuilder(
    column: $table.artworkUri,
    builder: (column) => ColumnOrderings(column),
  );

  $$ArtistsTableOrderingComposer get artistId {
    final $$ArtistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.artistId,
      referencedTable: $db.artists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArtistsTableOrderingComposer(
            $db: $db,
            $table: $db.artists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AlbumsTableAnnotationComposer
    extends Composer<_$ToneDatabase, $AlbumsTable> {
  $$AlbumsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get artworkUri => $composableBuilder(
    column: $table.artworkUri,
    builder: (column) => column,
  );

  $$ArtistsTableAnnotationComposer get artistId {
    final $$ArtistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.artistId,
      referencedTable: $db.artists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArtistsTableAnnotationComposer(
            $db: $db,
            $table: $db.artists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> libraryTracksRefs<T extends Object>(
    Expression<T> Function($$LibraryTracksTableAnnotationComposer a) f,
  ) {
    final $$LibraryTracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.libraryTracks,
      getReferencedColumn: (t) => t.albumId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryTracksTableAnnotationComposer(
            $db: $db,
            $table: $db.libraryTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AlbumsTableTableManager
    extends
        RootTableManager<
          _$ToneDatabase,
          $AlbumsTable,
          Album,
          $$AlbumsTableFilterComposer,
          $$AlbumsTableOrderingComposer,
          $$AlbumsTableAnnotationComposer,
          $$AlbumsTableCreateCompanionBuilder,
          $$AlbumsTableUpdateCompanionBuilder,
          (Album, $$AlbumsTableReferences),
          Album,
          PrefetchHooks Function({bool artistId, bool libraryTracksRefs})
        > {
  $$AlbumsTableTableManager(_$ToneDatabase db, $AlbumsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AlbumsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AlbumsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AlbumsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> artistId = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> artworkUri = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AlbumsCompanion(
                id: id,
                title: title,
                artistId: artistId,
                year: year,
                artworkUri: artworkUri,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required String artistId,
                Value<int?> year = const Value.absent(),
                Value<String?> artworkUri = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AlbumsCompanion.insert(
                id: id,
                title: title,
                artistId: artistId,
                year: year,
                artworkUri: artworkUri,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AlbumsTable, Album>(table),
                  $$AlbumsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({artistId = false, libraryTracksRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (libraryTracksRefs) db.libraryTracks,
                  ],
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
                        if (artistId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.artistId,
                            referencedTable: $$AlbumsTableReferences
                                ._artistIdTable(db),
                            referencedColumn: $$AlbumsTableReferences
                                ._artistIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (libraryTracksRefs)
                        await $_getPrefetchedDataByColumns<
                          Album,
                          $AlbumsTable,
                          LibraryTrack,
                          $LibraryTracksTable
                        >(
                          currentTable: table,
                          referencedTable: $$AlbumsTableReferences
                              ._libraryTracksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AlbumsTableReferences(
                                db,
                                table,
                                p0,
                              ).libraryTracksRefs,
                          currentColumn: 'id',
                          referencedColumn: 'album_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$AlbumsTableProcessedTableManager =
    ProcessedTableManager<
      _$ToneDatabase,
      $AlbumsTable,
      Album,
      $$AlbumsTableFilterComposer,
      $$AlbumsTableOrderingComposer,
      $$AlbumsTableAnnotationComposer,
      $$AlbumsTableCreateCompanionBuilder,
      $$AlbumsTableUpdateCompanionBuilder,
      (Album, $$AlbumsTableReferences),
      Album,
      PrefetchHooks Function({bool artistId, bool libraryTracksRefs})
    >;
typedef $$LibraryTracksTableCreateCompanionBuilder =
    LibraryTracksCompanion Function({
      required String id,
      required String path,
      Value<String?> sourceName,
      required String title,
      required String artist,
      required String album,
      required String artistId,
      required String albumId,
      Value<int?> durationMs,
      Value<String?> artworkUri,
      Value<int?> year,
      Value<int?> trackNumber,
      Value<String?> genre,
      Value<double?> bpm,
      Value<bool> isDeviceMedia,
      Value<String?> sourceFolderUri,
      Value<String?> lyricsUri,
      Value<String?> sourceProvider,
      Value<String?> providerTrackId,
      Value<String?> licenseUrl,
      Value<bool> metadataReviewed,
      Value<bool> isAvailable,
      required int position,
      Value<DateTime?> lastSeenAt,
      Value<int?> fileSizeBytes,
      Value<DateTime?> fileModifiedAt,
      Value<int> rowid,
    });
typedef $$LibraryTracksTableUpdateCompanionBuilder =
    LibraryTracksCompanion Function({
      Value<String> id,
      Value<String> path,
      Value<String?> sourceName,
      Value<String> title,
      Value<String> artist,
      Value<String> album,
      Value<String> artistId,
      Value<String> albumId,
      Value<int?> durationMs,
      Value<String?> artworkUri,
      Value<int?> year,
      Value<int?> trackNumber,
      Value<String?> genre,
      Value<double?> bpm,
      Value<bool> isDeviceMedia,
      Value<String?> sourceFolderUri,
      Value<String?> lyricsUri,
      Value<String?> sourceProvider,
      Value<String?> providerTrackId,
      Value<String?> licenseUrl,
      Value<bool> metadataReviewed,
      Value<bool> isAvailable,
      Value<int> position,
      Value<DateTime?> lastSeenAt,
      Value<int?> fileSizeBytes,
      Value<DateTime?> fileModifiedAt,
      Value<int> rowid,
    });

final class $$LibraryTracksTableReferences
    extends BaseReferences<_$ToneDatabase, $LibraryTracksTable, LibraryTrack> {
  $$LibraryTracksTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ArtistsTable _artistIdTable(_$ToneDatabase db) =>
      db.artists.createAlias('library_tracks__artist_id__artists__id');

  $$ArtistsTableProcessedTableManager get artistId {
    final $_column = $_itemColumn<String>('artist_id')!;

    final manager = $$ArtistsTableTableManager(
      $_db,
      $_db.artists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_artistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $AlbumsTable _albumIdTable(_$ToneDatabase db) =>
      db.albums.createAlias('library_tracks__album_id__albums__id');

  $$AlbumsTableProcessedTableManager get albumId {
    final $_column = $_itemColumn<String>('album_id')!;

    final manager = $$AlbumsTableTableManager(
      $_db,
      $_db.albums,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_albumIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$PlaylistTracksTable, List<PlaylistTrack>>
  _playlistTracksRefsTable(_$ToneDatabase db) => MultiTypedResultKey.fromTable(
    db.playlistTracks,
    aliasName: 'library_tracks__id__playlist_tracks__track_id',
  );

  $$PlaylistTracksTableProcessedTableManager get playlistTracksRefs {
    final manager = $$PlaylistTracksTableTableManager(
      $_db,
      $_db.playlistTracks,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_playlistTracksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FavoritesTable, List<Favorite>>
  _favoritesRefsTable(_$ToneDatabase db) => MultiTypedResultKey.fromTable(
    db.favorites,
    aliasName: 'library_tracks__id__favorites__track_id',
  );

  $$FavoritesTableProcessedTableManager get favoritesRefs {
    final manager = $$FavoritesTableTableManager(
      $_db,
      $_db.favorites,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_favoritesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ExcludedTracksTable, List<ExcludedTrack>>
  _excludedTracksRefsTable(_$ToneDatabase db) => MultiTypedResultKey.fromTable(
    db.excludedTracks,
    aliasName: 'library_tracks__id__excluded_tracks__track_id',
  );

  $$ExcludedTracksTableProcessedTableManager get excludedTracksRefs {
    final manager = $$ExcludedTracksTableTableManager(
      $_db,
      $_db.excludedTracks,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_excludedTracksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TrackAnalysisTable, List<TrackAnalysi>>
  _trackAnalysisRefsTable(_$ToneDatabase db) => MultiTypedResultKey.fromTable(
    db.trackAnalysis,
    aliasName: 'library_tracks__id__track_analysis__track_id',
  );

  $$TrackAnalysisTableProcessedTableManager get trackAnalysisRefs {
    final manager = $$TrackAnalysisTableTableManager(
      $_db,
      $_db.trackAnalysis,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_trackAnalysisRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DownloadsTable, List<Download>>
  _downloadsRefsTable(_$ToneDatabase db) => MultiTypedResultKey.fromTable(
    db.downloads,
    aliasName: 'library_tracks__id__downloads__track_id',
  );

  $$DownloadsTableProcessedTableManager get downloadsRefs {
    final manager = $$DownloadsTableTableManager(
      $_db,
      $_db.downloads,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_downloadsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LibraryTracksTableFilterComposer
    extends Composer<_$ToneDatabase, $LibraryTracksTable> {
  $$LibraryTracksTableFilterComposer({
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

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceName => $composableBuilder(
    column: $table.sourceName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artworkUri => $composableBuilder(
    column: $table.artworkUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get trackNumber => $composableBuilder(
    column: $table.trackNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get bpm => $composableBuilder(
    column: $table.bpm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeviceMedia => $composableBuilder(
    column: $table.isDeviceMedia,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceFolderUri => $composableBuilder(
    column: $table.sourceFolderUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lyricsUri => $composableBuilder(
    column: $table.lyricsUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceProvider => $composableBuilder(
    column: $table.sourceProvider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerTrackId => $composableBuilder(
    column: $table.providerTrackId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get licenseUrl => $composableBuilder(
    column: $table.licenseUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get metadataReviewed => $composableBuilder(
    column: $table.metadataReviewed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isAvailable => $composableBuilder(
    column: $table.isAvailable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileSizeBytes => $composableBuilder(
    column: $table.fileSizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fileModifiedAt => $composableBuilder(
    column: $table.fileModifiedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ArtistsTableFilterComposer get artistId {
    final $$ArtistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.artistId,
      referencedTable: $db.artists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArtistsTableFilterComposer(
            $db: $db,
            $table: $db.artists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AlbumsTableFilterComposer get albumId {
    final $$AlbumsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.albumId,
      referencedTable: $db.albums,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlbumsTableFilterComposer(
            $db: $db,
            $table: $db.albums,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> playlistTracksRefs(
    Expression<bool> Function($$PlaylistTracksTableFilterComposer f) f,
  ) {
    final $$PlaylistTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistTracks,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistTracksTableFilterComposer(
            $db: $db,
            $table: $db.playlistTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> favoritesRefs(
    Expression<bool> Function($$FavoritesTableFilterComposer f) f,
  ) {
    final $$FavoritesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.favorites,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoritesTableFilterComposer(
            $db: $db,
            $table: $db.favorites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> excludedTracksRefs(
    Expression<bool> Function($$ExcludedTracksTableFilterComposer f) f,
  ) {
    final $$ExcludedTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.excludedTracks,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExcludedTracksTableFilterComposer(
            $db: $db,
            $table: $db.excludedTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> trackAnalysisRefs(
    Expression<bool> Function($$TrackAnalysisTableFilterComposer f) f,
  ) {
    final $$TrackAnalysisTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.trackAnalysis,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrackAnalysisTableFilterComposer(
            $db: $db,
            $table: $db.trackAnalysis,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> downloadsRefs(
    Expression<bool> Function($$DownloadsTableFilterComposer f) f,
  ) {
    final $$DownloadsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.downloads,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadsTableFilterComposer(
            $db: $db,
            $table: $db.downloads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LibraryTracksTableOrderingComposer
    extends Composer<_$ToneDatabase, $LibraryTracksTable> {
  $$LibraryTracksTableOrderingComposer({
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

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceName => $composableBuilder(
    column: $table.sourceName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artworkUri => $composableBuilder(
    column: $table.artworkUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get trackNumber => $composableBuilder(
    column: $table.trackNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get bpm => $composableBuilder(
    column: $table.bpm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeviceMedia => $composableBuilder(
    column: $table.isDeviceMedia,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceFolderUri => $composableBuilder(
    column: $table.sourceFolderUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lyricsUri => $composableBuilder(
    column: $table.lyricsUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceProvider => $composableBuilder(
    column: $table.sourceProvider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerTrackId => $composableBuilder(
    column: $table.providerTrackId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get licenseUrl => $composableBuilder(
    column: $table.licenseUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get metadataReviewed => $composableBuilder(
    column: $table.metadataReviewed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isAvailable => $composableBuilder(
    column: $table.isAvailable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileSizeBytes => $composableBuilder(
    column: $table.fileSizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fileModifiedAt => $composableBuilder(
    column: $table.fileModifiedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ArtistsTableOrderingComposer get artistId {
    final $$ArtistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.artistId,
      referencedTable: $db.artists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArtistsTableOrderingComposer(
            $db: $db,
            $table: $db.artists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AlbumsTableOrderingComposer get albumId {
    final $$AlbumsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.albumId,
      referencedTable: $db.albums,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlbumsTableOrderingComposer(
            $db: $db,
            $table: $db.albums,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LibraryTracksTableAnnotationComposer
    extends Composer<_$ToneDatabase, $LibraryTracksTable> {
  $$LibraryTracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get sourceName => $composableBuilder(
    column: $table.sourceName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get album =>
      $composableBuilder(column: $table.album, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get artworkUri => $composableBuilder(
    column: $table.artworkUri,
    builder: (column) => column,
  );

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<int> get trackNumber => $composableBuilder(
    column: $table.trackNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get genre =>
      $composableBuilder(column: $table.genre, builder: (column) => column);

  GeneratedColumn<double> get bpm =>
      $composableBuilder(column: $table.bpm, builder: (column) => column);

  GeneratedColumn<bool> get isDeviceMedia => $composableBuilder(
    column: $table.isDeviceMedia,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceFolderUri => $composableBuilder(
    column: $table.sourceFolderUri,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lyricsUri =>
      $composableBuilder(column: $table.lyricsUri, builder: (column) => column);

  GeneratedColumn<String> get sourceProvider => $composableBuilder(
    column: $table.sourceProvider,
    builder: (column) => column,
  );

  GeneratedColumn<String> get providerTrackId => $composableBuilder(
    column: $table.providerTrackId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get licenseUrl => $composableBuilder(
    column: $table.licenseUrl,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get metadataReviewed => $composableBuilder(
    column: $table.metadataReviewed,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isAvailable => $composableBuilder(
    column: $table.isAvailable,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fileSizeBytes => $composableBuilder(
    column: $table.fileSizeBytes,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get fileModifiedAt => $composableBuilder(
    column: $table.fileModifiedAt,
    builder: (column) => column,
  );

  $$ArtistsTableAnnotationComposer get artistId {
    final $$ArtistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.artistId,
      referencedTable: $db.artists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArtistsTableAnnotationComposer(
            $db: $db,
            $table: $db.artists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AlbumsTableAnnotationComposer get albumId {
    final $$AlbumsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.albumId,
      referencedTable: $db.albums,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlbumsTableAnnotationComposer(
            $db: $db,
            $table: $db.albums,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> playlistTracksRefs<T extends Object>(
    Expression<T> Function($$PlaylistTracksTableAnnotationComposer a) f,
  ) {
    final $$PlaylistTracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistTracks,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistTracksTableAnnotationComposer(
            $db: $db,
            $table: $db.playlistTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> favoritesRefs<T extends Object>(
    Expression<T> Function($$FavoritesTableAnnotationComposer a) f,
  ) {
    final $$FavoritesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.favorites,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoritesTableAnnotationComposer(
            $db: $db,
            $table: $db.favorites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> excludedTracksRefs<T extends Object>(
    Expression<T> Function($$ExcludedTracksTableAnnotationComposer a) f,
  ) {
    final $$ExcludedTracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.excludedTracks,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExcludedTracksTableAnnotationComposer(
            $db: $db,
            $table: $db.excludedTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> trackAnalysisRefs<T extends Object>(
    Expression<T> Function($$TrackAnalysisTableAnnotationComposer a) f,
  ) {
    final $$TrackAnalysisTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.trackAnalysis,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrackAnalysisTableAnnotationComposer(
            $db: $db,
            $table: $db.trackAnalysis,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> downloadsRefs<T extends Object>(
    Expression<T> Function($$DownloadsTableAnnotationComposer a) f,
  ) {
    final $$DownloadsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.downloads,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadsTableAnnotationComposer(
            $db: $db,
            $table: $db.downloads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LibraryTracksTableTableManager
    extends
        RootTableManager<
          _$ToneDatabase,
          $LibraryTracksTable,
          LibraryTrack,
          $$LibraryTracksTableFilterComposer,
          $$LibraryTracksTableOrderingComposer,
          $$LibraryTracksTableAnnotationComposer,
          $$LibraryTracksTableCreateCompanionBuilder,
          $$LibraryTracksTableUpdateCompanionBuilder,
          (LibraryTrack, $$LibraryTracksTableReferences),
          LibraryTrack,
          PrefetchHooks Function({
            bool artistId,
            bool albumId,
            bool playlistTracksRefs,
            bool favoritesRefs,
            bool excludedTracksRefs,
            bool trackAnalysisRefs,
            bool downloadsRefs,
          })
        > {
  $$LibraryTracksTableTableManager(_$ToneDatabase db, $LibraryTracksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibraryTracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibraryTracksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LibraryTracksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String?> sourceName = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> artist = const Value.absent(),
                Value<String> album = const Value.absent(),
                Value<String> artistId = const Value.absent(),
                Value<String> albumId = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<String?> artworkUri = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<int?> trackNumber = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<double?> bpm = const Value.absent(),
                Value<bool> isDeviceMedia = const Value.absent(),
                Value<String?> sourceFolderUri = const Value.absent(),
                Value<String?> lyricsUri = const Value.absent(),
                Value<String?> sourceProvider = const Value.absent(),
                Value<String?> providerTrackId = const Value.absent(),
                Value<String?> licenseUrl = const Value.absent(),
                Value<bool> metadataReviewed = const Value.absent(),
                Value<bool> isAvailable = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<DateTime?> lastSeenAt = const Value.absent(),
                Value<int?> fileSizeBytes = const Value.absent(),
                Value<DateTime?> fileModifiedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibraryTracksCompanion(
                id: id,
                path: path,
                sourceName: sourceName,
                title: title,
                artist: artist,
                album: album,
                artistId: artistId,
                albumId: albumId,
                durationMs: durationMs,
                artworkUri: artworkUri,
                year: year,
                trackNumber: trackNumber,
                genre: genre,
                bpm: bpm,
                isDeviceMedia: isDeviceMedia,
                sourceFolderUri: sourceFolderUri,
                lyricsUri: lyricsUri,
                sourceProvider: sourceProvider,
                providerTrackId: providerTrackId,
                licenseUrl: licenseUrl,
                metadataReviewed: metadataReviewed,
                isAvailable: isAvailable,
                position: position,
                lastSeenAt: lastSeenAt,
                fileSizeBytes: fileSizeBytes,
                fileModifiedAt: fileModifiedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String path,
                Value<String?> sourceName = const Value.absent(),
                required String title,
                required String artist,
                required String album,
                required String artistId,
                required String albumId,
                Value<int?> durationMs = const Value.absent(),
                Value<String?> artworkUri = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<int?> trackNumber = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<double?> bpm = const Value.absent(),
                Value<bool> isDeviceMedia = const Value.absent(),
                Value<String?> sourceFolderUri = const Value.absent(),
                Value<String?> lyricsUri = const Value.absent(),
                Value<String?> sourceProvider = const Value.absent(),
                Value<String?> providerTrackId = const Value.absent(),
                Value<String?> licenseUrl = const Value.absent(),
                Value<bool> metadataReviewed = const Value.absent(),
                Value<bool> isAvailable = const Value.absent(),
                required int position,
                Value<DateTime?> lastSeenAt = const Value.absent(),
                Value<int?> fileSizeBytes = const Value.absent(),
                Value<DateTime?> fileModifiedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibraryTracksCompanion.insert(
                id: id,
                path: path,
                sourceName: sourceName,
                title: title,
                artist: artist,
                album: album,
                artistId: artistId,
                albumId: albumId,
                durationMs: durationMs,
                artworkUri: artworkUri,
                year: year,
                trackNumber: trackNumber,
                genre: genre,
                bpm: bpm,
                isDeviceMedia: isDeviceMedia,
                sourceFolderUri: sourceFolderUri,
                lyricsUri: lyricsUri,
                sourceProvider: sourceProvider,
                providerTrackId: providerTrackId,
                licenseUrl: licenseUrl,
                metadataReviewed: metadataReviewed,
                isAvailable: isAvailable,
                position: position,
                lastSeenAt: lastSeenAt,
                fileSizeBytes: fileSizeBytes,
                fileModifiedAt: fileModifiedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LibraryTracksTable, LibraryTrack>(table),
                  $$LibraryTracksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                artistId = false,
                albumId = false,
                playlistTracksRefs = false,
                favoritesRefs = false,
                excludedTracksRefs = false,
                trackAnalysisRefs = false,
                downloadsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (playlistTracksRefs) db.playlistTracks,
                    if (favoritesRefs) db.favorites,
                    if (excludedTracksRefs) db.excludedTracks,
                    if (trackAnalysisRefs) db.trackAnalysis,
                    if (downloadsRefs) db.downloads,
                  ],
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
                        if (artistId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.artistId,
                            referencedTable: $$LibraryTracksTableReferences
                                ._artistIdTable(db),
                            referencedColumn: $$LibraryTracksTableReferences
                                ._artistIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (albumId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.albumId,
                            referencedTable: $$LibraryTracksTableReferences
                                ._albumIdTable(db),
                            referencedColumn: $$LibraryTracksTableReferences
                                ._albumIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (playlistTracksRefs)
                        await $_getPrefetchedDataByColumns<
                          LibraryTrack,
                          $LibraryTracksTable,
                          PlaylistTrack,
                          $PlaylistTracksTable
                        >(
                          currentTable: table,
                          referencedTable: $$LibraryTracksTableReferences
                              ._playlistTracksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LibraryTracksTableReferences(
                                db,
                                table,
                                p0,
                              ).playlistTracksRefs,
                          currentColumn: 'id',
                          referencedColumn: 'track_id',
                          typedResults: items,
                        ),
                      if (favoritesRefs)
                        await $_getPrefetchedDataByColumns<
                          LibraryTrack,
                          $LibraryTracksTable,
                          Favorite,
                          $FavoritesTable
                        >(
                          currentTable: table,
                          referencedTable: $$LibraryTracksTableReferences
                              ._favoritesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LibraryTracksTableReferences(
                                db,
                                table,
                                p0,
                              ).favoritesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'track_id',
                          typedResults: items,
                        ),
                      if (excludedTracksRefs)
                        await $_getPrefetchedDataByColumns<
                          LibraryTrack,
                          $LibraryTracksTable,
                          ExcludedTrack,
                          $ExcludedTracksTable
                        >(
                          currentTable: table,
                          referencedTable: $$LibraryTracksTableReferences
                              ._excludedTracksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LibraryTracksTableReferences(
                                db,
                                table,
                                p0,
                              ).excludedTracksRefs,
                          currentColumn: 'id',
                          referencedColumn: 'track_id',
                          typedResults: items,
                        ),
                      if (trackAnalysisRefs)
                        await $_getPrefetchedDataByColumns<
                          LibraryTrack,
                          $LibraryTracksTable,
                          TrackAnalysi,
                          $TrackAnalysisTable
                        >(
                          currentTable: table,
                          referencedTable: $$LibraryTracksTableReferences
                              ._trackAnalysisRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LibraryTracksTableReferences(
                                db,
                                table,
                                p0,
                              ).trackAnalysisRefs,
                          currentColumn: 'id',
                          referencedColumn: 'track_id',
                          typedResults: items,
                        ),
                      if (downloadsRefs)
                        await $_getPrefetchedDataByColumns<
                          LibraryTrack,
                          $LibraryTracksTable,
                          Download,
                          $DownloadsTable
                        >(
                          currentTable: table,
                          referencedTable: $$LibraryTracksTableReferences
                              ._downloadsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LibraryTracksTableReferences(
                                db,
                                table,
                                p0,
                              ).downloadsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'track_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$LibraryTracksTableProcessedTableManager =
    ProcessedTableManager<
      _$ToneDatabase,
      $LibraryTracksTable,
      LibraryTrack,
      $$LibraryTracksTableFilterComposer,
      $$LibraryTracksTableOrderingComposer,
      $$LibraryTracksTableAnnotationComposer,
      $$LibraryTracksTableCreateCompanionBuilder,
      $$LibraryTracksTableUpdateCompanionBuilder,
      (LibraryTrack, $$LibraryTracksTableReferences),
      LibraryTrack,
      PrefetchHooks Function({
        bool artistId,
        bool albumId,
        bool playlistTracksRefs,
        bool favoritesRefs,
        bool excludedTracksRefs,
        bool trackAnalysisRefs,
        bool downloadsRefs,
      })
    >;
typedef $$LibraryFoldersTableCreateCompanionBuilder =
    LibraryFoldersCompanion Function({
      required String uri,
      required String name,
      required DateTime grantedAt,
      required int position,
      Value<int> rowid,
    });
typedef $$LibraryFoldersTableUpdateCompanionBuilder =
    LibraryFoldersCompanion Function({
      Value<String> uri,
      Value<String> name,
      Value<DateTime> grantedAt,
      Value<int> position,
      Value<int> rowid,
    });

class $$LibraryFoldersTableFilterComposer
    extends Composer<_$ToneDatabase, $LibraryFoldersTable> {
  $$LibraryFoldersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uri => $composableBuilder(
    column: $table.uri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get grantedAt => $composableBuilder(
    column: $table.grantedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LibraryFoldersTableOrderingComposer
    extends Composer<_$ToneDatabase, $LibraryFoldersTable> {
  $$LibraryFoldersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uri => $composableBuilder(
    column: $table.uri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get grantedAt => $composableBuilder(
    column: $table.grantedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LibraryFoldersTableAnnotationComposer
    extends Composer<_$ToneDatabase, $LibraryFoldersTable> {
  $$LibraryFoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uri =>
      $composableBuilder(column: $table.uri, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get grantedAt =>
      $composableBuilder(column: $table.grantedAt, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);
}

class $$LibraryFoldersTableTableManager
    extends
        RootTableManager<
          _$ToneDatabase,
          $LibraryFoldersTable,
          LibraryFolder,
          $$LibraryFoldersTableFilterComposer,
          $$LibraryFoldersTableOrderingComposer,
          $$LibraryFoldersTableAnnotationComposer,
          $$LibraryFoldersTableCreateCompanionBuilder,
          $$LibraryFoldersTableUpdateCompanionBuilder,
          (
            LibraryFolder,
            BaseReferences<_$ToneDatabase, $LibraryFoldersTable, LibraryFolder>,
          ),
          LibraryFolder,
          PrefetchHooks Function()
        > {
  $$LibraryFoldersTableTableManager(
    _$ToneDatabase db,
    $LibraryFoldersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibraryFoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibraryFoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LibraryFoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uri = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> grantedAt = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibraryFoldersCompanion(
                uri: uri,
                name: name,
                grantedAt: grantedAt,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uri,
                required String name,
                required DateTime grantedAt,
                required int position,
                Value<int> rowid = const Value.absent(),
              }) => LibraryFoldersCompanion.insert(
                uri: uri,
                name: name,
                grantedAt: grantedAt,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LibraryFoldersTable, LibraryFolder>(table),
                  BaseReferences<
                    _$ToneDatabase,
                    $LibraryFoldersTable,
                    LibraryFolder
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LibraryFoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$ToneDatabase,
      $LibraryFoldersTable,
      LibraryFolder,
      $$LibraryFoldersTableFilterComposer,
      $$LibraryFoldersTableOrderingComposer,
      $$LibraryFoldersTableAnnotationComposer,
      $$LibraryFoldersTableCreateCompanionBuilder,
      $$LibraryFoldersTableUpdateCompanionBuilder,
      (
        LibraryFolder,
        BaseReferences<_$ToneDatabase, $LibraryFoldersTable, LibraryFolder>,
      ),
      LibraryFolder,
      PrefetchHooks Function()
    >;
typedef $$PlaylistsTableCreateCompanionBuilder = PlaylistsCompanion Function({
  required String id,
  required String name,
  required DateTime createdAt,
  required int position,
  Value<int> rowid,
});
typedef $$PlaylistsTableUpdateCompanionBuilder = PlaylistsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<DateTime> createdAt,
  Value<int> position,
  Value<int> rowid,
});

final class $$PlaylistsTableReferences
    extends BaseReferences<_$ToneDatabase, $PlaylistsTable, Playlist> {
  $$PlaylistsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PlaylistTracksTable, List<PlaylistTrack>>
  _playlistTracksRefsTable(_$ToneDatabase db) => MultiTypedResultKey.fromTable(
    db.playlistTracks,
    aliasName: 'playlists__id__playlist_tracks__playlist_id',
  );

  $$PlaylistTracksTableProcessedTableManager get playlistTracksRefs {
    final manager = $$PlaylistTracksTableTableManager(
      $_db,
      $_db.playlistTracks,
    ).filter((f) => f.playlistId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_playlistTracksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PlaylistsTableFilterComposer
    extends Composer<_$ToneDatabase, $PlaylistsTable> {
  $$PlaylistsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> playlistTracksRefs(
    Expression<bool> Function($$PlaylistTracksTableFilterComposer f) f,
  ) {
    final $$PlaylistTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistTracks,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistTracksTableFilterComposer(
            $db: $db,
            $table: $db.playlistTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlaylistsTableOrderingComposer
    extends Composer<_$ToneDatabase, $PlaylistsTable> {
  $$PlaylistsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaylistsTableAnnotationComposer
    extends Composer<_$ToneDatabase, $PlaylistsTable> {
  $$PlaylistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  Expression<T> playlistTracksRefs<T extends Object>(
    Expression<T> Function($$PlaylistTracksTableAnnotationComposer a) f,
  ) {
    final $$PlaylistTracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistTracks,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistTracksTableAnnotationComposer(
            $db: $db,
            $table: $db.playlistTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlaylistsTableTableManager
    extends
        RootTableManager<
          _$ToneDatabase,
          $PlaylistsTable,
          Playlist,
          $$PlaylistsTableFilterComposer,
          $$PlaylistsTableOrderingComposer,
          $$PlaylistsTableAnnotationComposer,
          $$PlaylistsTableCreateCompanionBuilder,
          $$PlaylistsTableUpdateCompanionBuilder,
          (Playlist, $$PlaylistsTableReferences),
          Playlist,
          PrefetchHooks Function({bool playlistTracksRefs})
        > {
  $$PlaylistsTableTableManager(_$ToneDatabase db, $PlaylistsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaylistsCompanion(
                id: id,
                name: name,
                createdAt: createdAt,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required DateTime createdAt,
                required int position,
                Value<int> rowid = const Value.absent(),
              }) => PlaylistsCompanion.insert(
                id: id,
                name: name,
                createdAt: createdAt,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaylistsTable, Playlist>(table),
                  $$PlaylistsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistTracksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (playlistTracksRefs) db.playlistTracks,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (playlistTracksRefs)
                    await $_getPrefetchedDataByColumns<
                      Playlist,
                      $PlaylistsTable,
                      PlaylistTrack,
                      $PlaylistTracksTable
                    >(
                      currentTable: table,
                      referencedTable: $$PlaylistsTableReferences
                          ._playlistTracksRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$PlaylistsTableReferences(
                            db,
                            table,
                            p0,
                          ).playlistTracksRefs,
                      currentColumn: 'id',
                      referencedColumn: 'playlist_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PlaylistsTableProcessedTableManager =
    ProcessedTableManager<
      _$ToneDatabase,
      $PlaylistsTable,
      Playlist,
      $$PlaylistsTableFilterComposer,
      $$PlaylistsTableOrderingComposer,
      $$PlaylistsTableAnnotationComposer,
      $$PlaylistsTableCreateCompanionBuilder,
      $$PlaylistsTableUpdateCompanionBuilder,
      (Playlist, $$PlaylistsTableReferences),
      Playlist,
      PrefetchHooks Function({bool playlistTracksRefs})
    >;
typedef $$PlaylistTracksTableCreateCompanionBuilder =
    PlaylistTracksCompanion Function({
      required String playlistId,
      required String trackId,
      required int position,
      Value<int> rowid,
    });
typedef $$PlaylistTracksTableUpdateCompanionBuilder =
    PlaylistTracksCompanion Function({
      Value<String> playlistId,
      Value<String> trackId,
      Value<int> position,
      Value<int> rowid,
    });

final class $$PlaylistTracksTableReferences
    extends
        BaseReferences<_$ToneDatabase, $PlaylistTracksTable, PlaylistTrack> {
  $$PlaylistTracksTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlaylistsTable _playlistIdTable(_$ToneDatabase db) =>
      db.playlists.createAlias('playlist_tracks__playlist_id__playlists__id');

  $$PlaylistsTableProcessedTableManager get playlistId {
    final $_column = $_itemColumn<String>('playlist_id')!;

    final manager = $$PlaylistsTableTableManager(
      $_db,
      $_db.playlists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $LibraryTracksTable _trackIdTable(_$ToneDatabase db) => db
      .libraryTracks
      .createAlias('playlist_tracks__track_id__library_tracks__id');

  $$LibraryTracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<String>('track_id')!;

    final manager = $$LibraryTracksTableTableManager(
      $_db,
      $_db.libraryTracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PlaylistTracksTableFilterComposer
    extends Composer<_$ToneDatabase, $PlaylistTracksTable> {
  $$PlaylistTracksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  $$PlaylistsTableFilterComposer get playlistId {
    final $$PlaylistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableFilterComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LibraryTracksTableFilterComposer get trackId {
    final $$LibraryTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.libraryTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryTracksTableFilterComposer(
            $db: $db,
            $table: $db.libraryTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistTracksTableOrderingComposer
    extends Composer<_$ToneDatabase, $PlaylistTracksTable> {
  $$PlaylistTracksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlaylistsTableOrderingComposer get playlistId {
    final $$PlaylistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableOrderingComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LibraryTracksTableOrderingComposer get trackId {
    final $$LibraryTracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.libraryTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryTracksTableOrderingComposer(
            $db: $db,
            $table: $db.libraryTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistTracksTableAnnotationComposer
    extends Composer<_$ToneDatabase, $PlaylistTracksTable> {
  $$PlaylistTracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  $$PlaylistsTableAnnotationComposer get playlistId {
    final $$PlaylistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LibraryTracksTableAnnotationComposer get trackId {
    final $$LibraryTracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.libraryTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryTracksTableAnnotationComposer(
            $db: $db,
            $table: $db.libraryTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistTracksTableTableManager
    extends
        RootTableManager<
          _$ToneDatabase,
          $PlaylistTracksTable,
          PlaylistTrack,
          $$PlaylistTracksTableFilterComposer,
          $$PlaylistTracksTableOrderingComposer,
          $$PlaylistTracksTableAnnotationComposer,
          $$PlaylistTracksTableCreateCompanionBuilder,
          $$PlaylistTracksTableUpdateCompanionBuilder,
          (PlaylistTrack, $$PlaylistTracksTableReferences),
          PlaylistTrack,
          PrefetchHooks Function({bool playlistId, bool trackId})
        > {
  $$PlaylistTracksTableTableManager(
    _$ToneDatabase db,
    $PlaylistTracksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistTracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistTracksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistTracksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> playlistId = const Value.absent(),
                Value<String> trackId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaylistTracksCompanion(
                playlistId: playlistId,
                trackId: trackId,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String playlistId,
                required String trackId,
                required int position,
                Value<int> rowid = const Value.absent(),
              }) => PlaylistTracksCompanion.insert(
                playlistId: playlistId,
                trackId: trackId,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaylistTracksTable, PlaylistTrack>(table),
                  $$PlaylistTracksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistId = false, trackId = false}) {
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
                    if (playlistId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.playlistId,
                        referencedTable: $$PlaylistTracksTableReferences
                            ._playlistIdTable(db),
                        referencedColumn: $$PlaylistTracksTableReferences
                            ._playlistIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (trackId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.trackId,
                        referencedTable: $$PlaylistTracksTableReferences
                            ._trackIdTable(db),
                        referencedColumn: $$PlaylistTracksTableReferences
                            ._trackIdTable(db)
                            .id,
                      ) as T;
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

typedef $$PlaylistTracksTableProcessedTableManager =
    ProcessedTableManager<
      _$ToneDatabase,
      $PlaylistTracksTable,
      PlaylistTrack,
      $$PlaylistTracksTableFilterComposer,
      $$PlaylistTracksTableOrderingComposer,
      $$PlaylistTracksTableAnnotationComposer,
      $$PlaylistTracksTableCreateCompanionBuilder,
      $$PlaylistTracksTableUpdateCompanionBuilder,
      (PlaylistTrack, $$PlaylistTracksTableReferences),
      PlaylistTrack,
      PrefetchHooks Function({bool playlistId, bool trackId})
    >;
typedef $$FavoritesTableCreateCompanionBuilder = FavoritesCompanion Function({
  required String trackId,
  required DateTime addedAt,
  Value<int> rowid,
});
typedef $$FavoritesTableUpdateCompanionBuilder = FavoritesCompanion Function({
  Value<String> trackId,
  Value<DateTime> addedAt,
  Value<int> rowid,
});

final class $$FavoritesTableReferences
    extends BaseReferences<_$ToneDatabase, $FavoritesTable, Favorite> {
  $$FavoritesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LibraryTracksTable _trackIdTable(_$ToneDatabase db) =>
      db.libraryTracks.createAlias('favorites__track_id__library_tracks__id');

  $$LibraryTracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<String>('track_id')!;

    final manager = $$LibraryTracksTableTableManager(
      $_db,
      $_db.libraryTracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FavoritesTableFilterComposer
    extends Composer<_$ToneDatabase, $FavoritesTable> {
  $$FavoritesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LibraryTracksTableFilterComposer get trackId {
    final $$LibraryTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.libraryTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryTracksTableFilterComposer(
            $db: $db,
            $table: $db.libraryTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FavoritesTableOrderingComposer
    extends Composer<_$ToneDatabase, $FavoritesTable> {
  $$FavoritesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LibraryTracksTableOrderingComposer get trackId {
    final $$LibraryTracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.libraryTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryTracksTableOrderingComposer(
            $db: $db,
            $table: $db.libraryTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FavoritesTableAnnotationComposer
    extends Composer<_$ToneDatabase, $FavoritesTable> {
  $$FavoritesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  $$LibraryTracksTableAnnotationComposer get trackId {
    final $$LibraryTracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.libraryTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryTracksTableAnnotationComposer(
            $db: $db,
            $table: $db.libraryTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FavoritesTableTableManager
    extends
        RootTableManager<
          _$ToneDatabase,
          $FavoritesTable,
          Favorite,
          $$FavoritesTableFilterComposer,
          $$FavoritesTableOrderingComposer,
          $$FavoritesTableAnnotationComposer,
          $$FavoritesTableCreateCompanionBuilder,
          $$FavoritesTableUpdateCompanionBuilder,
          (Favorite, $$FavoritesTableReferences),
          Favorite,
          PrefetchHooks Function({bool trackId})
        > {
  $$FavoritesTableTableManager(_$ToneDatabase db, $FavoritesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavoritesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FavoritesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FavoritesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> trackId = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FavoritesCompanion(
                trackId: trackId,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String trackId,
                required DateTime addedAt,
                Value<int> rowid = const Value.absent(),
              }) => FavoritesCompanion.insert(
                trackId: trackId,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FavoritesTable, Favorite>(table),
                  $$FavoritesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({trackId = false}) {
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
                    if (trackId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.trackId,
                        referencedTable: $$FavoritesTableReferences
                            ._trackIdTable(db),
                        referencedColumn: $$FavoritesTableReferences
                            ._trackIdTable(db)
                            .id,
                      ) as T;
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

typedef $$FavoritesTableProcessedTableManager =
    ProcessedTableManager<
      _$ToneDatabase,
      $FavoritesTable,
      Favorite,
      $$FavoritesTableFilterComposer,
      $$FavoritesTableOrderingComposer,
      $$FavoritesTableAnnotationComposer,
      $$FavoritesTableCreateCompanionBuilder,
      $$FavoritesTableUpdateCompanionBuilder,
      (Favorite, $$FavoritesTableReferences),
      Favorite,
      PrefetchHooks Function({bool trackId})
    >;
typedef $$ExcludedTracksTableCreateCompanionBuilder =
    ExcludedTracksCompanion Function({
      required String trackId,
      required DateTime excludedAt,
      Value<int> rowid,
    });
typedef $$ExcludedTracksTableUpdateCompanionBuilder =
    ExcludedTracksCompanion Function({
      Value<String> trackId,
      Value<DateTime> excludedAt,
      Value<int> rowid,
    });

final class $$ExcludedTracksTableReferences
    extends
        BaseReferences<_$ToneDatabase, $ExcludedTracksTable, ExcludedTrack> {
  $$ExcludedTracksTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LibraryTracksTable _trackIdTable(_$ToneDatabase db) => db
      .libraryTracks
      .createAlias('excluded_tracks__track_id__library_tracks__id');

  $$LibraryTracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<String>('track_id')!;

    final manager = $$LibraryTracksTableTableManager(
      $_db,
      $_db.libraryTracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ExcludedTracksTableFilterComposer
    extends Composer<_$ToneDatabase, $ExcludedTracksTable> {
  $$ExcludedTracksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get excludedAt => $composableBuilder(
    column: $table.excludedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LibraryTracksTableFilterComposer get trackId {
    final $$LibraryTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.libraryTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryTracksTableFilterComposer(
            $db: $db,
            $table: $db.libraryTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExcludedTracksTableOrderingComposer
    extends Composer<_$ToneDatabase, $ExcludedTracksTable> {
  $$ExcludedTracksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get excludedAt => $composableBuilder(
    column: $table.excludedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LibraryTracksTableOrderingComposer get trackId {
    final $$LibraryTracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.libraryTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryTracksTableOrderingComposer(
            $db: $db,
            $table: $db.libraryTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExcludedTracksTableAnnotationComposer
    extends Composer<_$ToneDatabase, $ExcludedTracksTable> {
  $$ExcludedTracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get excludedAt => $composableBuilder(
    column: $table.excludedAt,
    builder: (column) => column,
  );

  $$LibraryTracksTableAnnotationComposer get trackId {
    final $$LibraryTracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.libraryTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryTracksTableAnnotationComposer(
            $db: $db,
            $table: $db.libraryTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExcludedTracksTableTableManager
    extends
        RootTableManager<
          _$ToneDatabase,
          $ExcludedTracksTable,
          ExcludedTrack,
          $$ExcludedTracksTableFilterComposer,
          $$ExcludedTracksTableOrderingComposer,
          $$ExcludedTracksTableAnnotationComposer,
          $$ExcludedTracksTableCreateCompanionBuilder,
          $$ExcludedTracksTableUpdateCompanionBuilder,
          (ExcludedTrack, $$ExcludedTracksTableReferences),
          ExcludedTrack,
          PrefetchHooks Function({bool trackId})
        > {
  $$ExcludedTracksTableTableManager(
    _$ToneDatabase db,
    $ExcludedTracksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExcludedTracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExcludedTracksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExcludedTracksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> trackId = const Value.absent(),
                Value<DateTime> excludedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExcludedTracksCompanion(
                trackId: trackId,
                excludedAt: excludedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String trackId,
                required DateTime excludedAt,
                Value<int> rowid = const Value.absent(),
              }) => ExcludedTracksCompanion.insert(
                trackId: trackId,
                excludedAt: excludedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ExcludedTracksTable, ExcludedTrack>(table),
                  $$ExcludedTracksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({trackId = false}) {
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
                    if (trackId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.trackId,
                        referencedTable: $$ExcludedTracksTableReferences
                            ._trackIdTable(db),
                        referencedColumn: $$ExcludedTracksTableReferences
                            ._trackIdTable(db)
                            .id,
                      ) as T;
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

typedef $$ExcludedTracksTableProcessedTableManager =
    ProcessedTableManager<
      _$ToneDatabase,
      $ExcludedTracksTable,
      ExcludedTrack,
      $$ExcludedTracksTableFilterComposer,
      $$ExcludedTracksTableOrderingComposer,
      $$ExcludedTracksTableAnnotationComposer,
      $$ExcludedTracksTableCreateCompanionBuilder,
      $$ExcludedTracksTableUpdateCompanionBuilder,
      (ExcludedTrack, $$ExcludedTracksTableReferences),
      ExcludedTrack,
      PrefetchHooks Function({bool trackId})
    >;
typedef $$PlaybackQueueEntriesTableCreateCompanionBuilder =
    PlaybackQueueEntriesCompanion Function({
      Value<int> position,
      required String trackId,
    });
typedef $$PlaybackQueueEntriesTableUpdateCompanionBuilder =
    PlaybackQueueEntriesCompanion Function({
      Value<int> position,
      Value<String> trackId,
    });

class $$PlaybackQueueEntriesTableFilterComposer
    extends Composer<_$ToneDatabase, $PlaybackQueueEntriesTable> {
  $$PlaybackQueueEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackId => $composableBuilder(
    column: $table.trackId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlaybackQueueEntriesTableOrderingComposer
    extends Composer<_$ToneDatabase, $PlaybackQueueEntriesTable> {
  $$PlaybackQueueEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackId => $composableBuilder(
    column: $table.trackId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaybackQueueEntriesTableAnnotationComposer
    extends Composer<_$ToneDatabase, $PlaybackQueueEntriesTable> {
  $$PlaybackQueueEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get trackId =>
      $composableBuilder(column: $table.trackId, builder: (column) => column);
}

class $$PlaybackQueueEntriesTableTableManager
    extends
        RootTableManager<
          _$ToneDatabase,
          $PlaybackQueueEntriesTable,
          PlaybackQueueEntry,
          $$PlaybackQueueEntriesTableFilterComposer,
          $$PlaybackQueueEntriesTableOrderingComposer,
          $$PlaybackQueueEntriesTableAnnotationComposer,
          $$PlaybackQueueEntriesTableCreateCompanionBuilder,
          $$PlaybackQueueEntriesTableUpdateCompanionBuilder,
          (
            PlaybackQueueEntry,
            BaseReferences<
              _$ToneDatabase,
              $PlaybackQueueEntriesTable,
              PlaybackQueueEntry
            >,
          ),
          PlaybackQueueEntry,
          PrefetchHooks Function()
        > {
  $$PlaybackQueueEntriesTableTableManager(
    _$ToneDatabase db,
    $PlaybackQueueEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaybackQueueEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaybackQueueEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PlaybackQueueEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> position = const Value.absent(),
                Value<String> trackId = const Value.absent(),
              }) => PlaybackQueueEntriesCompanion(
                position: position,
                trackId: trackId,
              ),
          createCompanionCallback:
              ({
                Value<int> position = const Value.absent(),
                required String trackId,
              }) => PlaybackQueueEntriesCompanion.insert(
                position: position,
                trackId: trackId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaybackQueueEntriesTable, PlaybackQueueEntry>(
                    table,
                  ),
                  BaseReferences<
                    _$ToneDatabase,
                    $PlaybackQueueEntriesTable,
                    PlaybackQueueEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlaybackQueueEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$ToneDatabase,
      $PlaybackQueueEntriesTable,
      PlaybackQueueEntry,
      $$PlaybackQueueEntriesTableFilterComposer,
      $$PlaybackQueueEntriesTableOrderingComposer,
      $$PlaybackQueueEntriesTableAnnotationComposer,
      $$PlaybackQueueEntriesTableCreateCompanionBuilder,
      $$PlaybackQueueEntriesTableUpdateCompanionBuilder,
      (
        PlaybackQueueEntry,
        BaseReferences<
          _$ToneDatabase,
          $PlaybackQueueEntriesTable,
          PlaybackQueueEntry
        >,
      ),
      PlaybackQueueEntry,
      PrefetchHooks Function()
    >;
typedef $$PlaybackStateTableCreateCompanionBuilder =
    PlaybackStateCompanion Function({
      Value<int> id,
      Value<String?> currentTrackId,
      Value<int> positionMs,
    });
typedef $$PlaybackStateTableUpdateCompanionBuilder =
    PlaybackStateCompanion Function({
      Value<int> id,
      Value<String?> currentTrackId,
      Value<int> positionMs,
    });

class $$PlaybackStateTableFilterComposer
    extends Composer<_$ToneDatabase, $PlaybackStateTable> {
  $$PlaybackStateTableFilterComposer({
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

  ColumnFilters<String> get currentTrackId => $composableBuilder(
    column: $table.currentTrackId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlaybackStateTableOrderingComposer
    extends Composer<_$ToneDatabase, $PlaybackStateTable> {
  $$PlaybackStateTableOrderingComposer({
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

  ColumnOrderings<String> get currentTrackId => $composableBuilder(
    column: $table.currentTrackId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaybackStateTableAnnotationComposer
    extends Composer<_$ToneDatabase, $PlaybackStateTable> {
  $$PlaybackStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get currentTrackId => $composableBuilder(
    column: $table.currentTrackId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => column,
  );
}

class $$PlaybackStateTableTableManager
    extends
        RootTableManager<
          _$ToneDatabase,
          $PlaybackStateTable,
          PlaybackStateData,
          $$PlaybackStateTableFilterComposer,
          $$PlaybackStateTableOrderingComposer,
          $$PlaybackStateTableAnnotationComposer,
          $$PlaybackStateTableCreateCompanionBuilder,
          $$PlaybackStateTableUpdateCompanionBuilder,
          (
            PlaybackStateData,
            BaseReferences<
              _$ToneDatabase,
              $PlaybackStateTable,
              PlaybackStateData
            >,
          ),
          PlaybackStateData,
          PrefetchHooks Function()
        > {
  $$PlaybackStateTableTableManager(_$ToneDatabase db, $PlaybackStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaybackStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaybackStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaybackStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> currentTrackId = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
              }) => PlaybackStateCompanion(
                id: id,
                currentTrackId: currentTrackId,
                positionMs: positionMs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> currentTrackId = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
              }) => PlaybackStateCompanion.insert(
                id: id,
                currentTrackId: currentTrackId,
                positionMs: positionMs,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaybackStateTable, PlaybackStateData>(table),
                  BaseReferences<
                    _$ToneDatabase,
                    $PlaybackStateTable,
                    PlaybackStateData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlaybackStateTableProcessedTableManager =
    ProcessedTableManager<
      _$ToneDatabase,
      $PlaybackStateTable,
      PlaybackStateData,
      $$PlaybackStateTableFilterComposer,
      $$PlaybackStateTableOrderingComposer,
      $$PlaybackStateTableAnnotationComposer,
      $$PlaybackStateTableCreateCompanionBuilder,
      $$PlaybackStateTableUpdateCompanionBuilder,
      (
        PlaybackStateData,
        BaseReferences<_$ToneDatabase, $PlaybackStateTable, PlaybackStateData>,
      ),
      PlaybackStateData,
      PrefetchHooks Function()
    >;
typedef $$PlaybackHistoryTableCreateCompanionBuilder =
    PlaybackHistoryCompanion Function({
      Value<int> id,
      required String trackId,
      required String title,
      required String artist,
      required String album,
      required DateTime playedAt,
      Value<int> listenedMs,
      Value<bool> completed,
    });
typedef $$PlaybackHistoryTableUpdateCompanionBuilder =
    PlaybackHistoryCompanion Function({
      Value<int> id,
      Value<String> trackId,
      Value<String> title,
      Value<String> artist,
      Value<String> album,
      Value<DateTime> playedAt,
      Value<int> listenedMs,
      Value<bool> completed,
    });

class $$PlaybackHistoryTableFilterComposer
    extends Composer<_$ToneDatabase, $PlaybackHistoryTable> {
  $$PlaybackHistoryTableFilterComposer({
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

  ColumnFilters<String> get trackId => $composableBuilder(
    column: $table.trackId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get playedAt => $composableBuilder(
    column: $table.playedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get listenedMs => $composableBuilder(
    column: $table.listenedMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlaybackHistoryTableOrderingComposer
    extends Composer<_$ToneDatabase, $PlaybackHistoryTable> {
  $$PlaybackHistoryTableOrderingComposer({
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

  ColumnOrderings<String> get trackId => $composableBuilder(
    column: $table.trackId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get playedAt => $composableBuilder(
    column: $table.playedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get listenedMs => $composableBuilder(
    column: $table.listenedMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaybackHistoryTableAnnotationComposer
    extends Composer<_$ToneDatabase, $PlaybackHistoryTable> {
  $$PlaybackHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get trackId =>
      $composableBuilder(column: $table.trackId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get album =>
      $composableBuilder(column: $table.album, builder: (column) => column);

  GeneratedColumn<DateTime> get playedAt =>
      $composableBuilder(column: $table.playedAt, builder: (column) => column);

  GeneratedColumn<int> get listenedMs => $composableBuilder(
    column: $table.listenedMs,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);
}

class $$PlaybackHistoryTableTableManager
    extends
        RootTableManager<
          _$ToneDatabase,
          $PlaybackHistoryTable,
          PlaybackHistoryData,
          $$PlaybackHistoryTableFilterComposer,
          $$PlaybackHistoryTableOrderingComposer,
          $$PlaybackHistoryTableAnnotationComposer,
          $$PlaybackHistoryTableCreateCompanionBuilder,
          $$PlaybackHistoryTableUpdateCompanionBuilder,
          (
            PlaybackHistoryData,
            BaseReferences<
              _$ToneDatabase,
              $PlaybackHistoryTable,
              PlaybackHistoryData
            >,
          ),
          PlaybackHistoryData,
          PrefetchHooks Function()
        > {
  $$PlaybackHistoryTableTableManager(
    _$ToneDatabase db,
    $PlaybackHistoryTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaybackHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaybackHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaybackHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> trackId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> artist = const Value.absent(),
                Value<String> album = const Value.absent(),
                Value<DateTime> playedAt = const Value.absent(),
                Value<int> listenedMs = const Value.absent(),
                Value<bool> completed = const Value.absent(),
              }) => PlaybackHistoryCompanion(
                id: id,
                trackId: trackId,
                title: title,
                artist: artist,
                album: album,
                playedAt: playedAt,
                listenedMs: listenedMs,
                completed: completed,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String trackId,
                required String title,
                required String artist,
                required String album,
                required DateTime playedAt,
                Value<int> listenedMs = const Value.absent(),
                Value<bool> completed = const Value.absent(),
              }) => PlaybackHistoryCompanion.insert(
                id: id,
                trackId: trackId,
                title: title,
                artist: artist,
                album: album,
                playedAt: playedAt,
                listenedMs: listenedMs,
                completed: completed,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaybackHistoryTable, PlaybackHistoryData>(
                    table,
                  ),
                  BaseReferences<
                    _$ToneDatabase,
                    $PlaybackHistoryTable,
                    PlaybackHistoryData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlaybackHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$ToneDatabase,
      $PlaybackHistoryTable,
      PlaybackHistoryData,
      $$PlaybackHistoryTableFilterComposer,
      $$PlaybackHistoryTableOrderingComposer,
      $$PlaybackHistoryTableAnnotationComposer,
      $$PlaybackHistoryTableCreateCompanionBuilder,
      $$PlaybackHistoryTableUpdateCompanionBuilder,
      (
        PlaybackHistoryData,
        BaseReferences<
          _$ToneDatabase,
          $PlaybackHistoryTable,
          PlaybackHistoryData
        >,
      ),
      PlaybackHistoryData,
      PrefetchHooks Function()
    >;
typedef $$TrackAnalysisTableCreateCompanionBuilder =
    TrackAnalysisCompanion Function({
      required String trackId,
      Value<double?> bpm,
      Value<String?> musicalKey,
      Value<double?> energy,
      Value<String?> analysisJson,
      required DateTime analyzedAt,
      Value<int> rowid,
    });
typedef $$TrackAnalysisTableUpdateCompanionBuilder =
    TrackAnalysisCompanion Function({
      Value<String> trackId,
      Value<double?> bpm,
      Value<String?> musicalKey,
      Value<double?> energy,
      Value<String?> analysisJson,
      Value<DateTime> analyzedAt,
      Value<int> rowid,
    });

final class $$TrackAnalysisTableReferences
    extends BaseReferences<_$ToneDatabase, $TrackAnalysisTable, TrackAnalysi> {
  $$TrackAnalysisTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LibraryTracksTable _trackIdTable(_$ToneDatabase db) => db
      .libraryTracks
      .createAlias('track_analysis__track_id__library_tracks__id');

  $$LibraryTracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<String>('track_id')!;

    final manager = $$LibraryTracksTableTableManager(
      $_db,
      $_db.libraryTracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TrackAnalysisTableFilterComposer
    extends Composer<_$ToneDatabase, $TrackAnalysisTable> {
  $$TrackAnalysisTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<double> get bpm => $composableBuilder(
    column: $table.bpm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get musicalKey => $composableBuilder(
    column: $table.musicalKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get energy => $composableBuilder(
    column: $table.energy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get analysisJson => $composableBuilder(
    column: $table.analysisJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get analyzedAt => $composableBuilder(
    column: $table.analyzedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LibraryTracksTableFilterComposer get trackId {
    final $$LibraryTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.libraryTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryTracksTableFilterComposer(
            $db: $db,
            $table: $db.libraryTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrackAnalysisTableOrderingComposer
    extends Composer<_$ToneDatabase, $TrackAnalysisTable> {
  $$TrackAnalysisTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<double> get bpm => $composableBuilder(
    column: $table.bpm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get musicalKey => $composableBuilder(
    column: $table.musicalKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get energy => $composableBuilder(
    column: $table.energy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get analysisJson => $composableBuilder(
    column: $table.analysisJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get analyzedAt => $composableBuilder(
    column: $table.analyzedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LibraryTracksTableOrderingComposer get trackId {
    final $$LibraryTracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.libraryTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryTracksTableOrderingComposer(
            $db: $db,
            $table: $db.libraryTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrackAnalysisTableAnnotationComposer
    extends Composer<_$ToneDatabase, $TrackAnalysisTable> {
  $$TrackAnalysisTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<double> get bpm =>
      $composableBuilder(column: $table.bpm, builder: (column) => column);

  GeneratedColumn<String> get musicalKey => $composableBuilder(
    column: $table.musicalKey,
    builder: (column) => column,
  );

  GeneratedColumn<double> get energy =>
      $composableBuilder(column: $table.energy, builder: (column) => column);

  GeneratedColumn<String> get analysisJson => $composableBuilder(
    column: $table.analysisJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get analyzedAt => $composableBuilder(
    column: $table.analyzedAt,
    builder: (column) => column,
  );

  $$LibraryTracksTableAnnotationComposer get trackId {
    final $$LibraryTracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.libraryTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryTracksTableAnnotationComposer(
            $db: $db,
            $table: $db.libraryTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrackAnalysisTableTableManager
    extends
        RootTableManager<
          _$ToneDatabase,
          $TrackAnalysisTable,
          TrackAnalysi,
          $$TrackAnalysisTableFilterComposer,
          $$TrackAnalysisTableOrderingComposer,
          $$TrackAnalysisTableAnnotationComposer,
          $$TrackAnalysisTableCreateCompanionBuilder,
          $$TrackAnalysisTableUpdateCompanionBuilder,
          (TrackAnalysi, $$TrackAnalysisTableReferences),
          TrackAnalysi,
          PrefetchHooks Function({bool trackId})
        > {
  $$TrackAnalysisTableTableManager(_$ToneDatabase db, $TrackAnalysisTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrackAnalysisTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrackAnalysisTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrackAnalysisTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> trackId = const Value.absent(),
                Value<double?> bpm = const Value.absent(),
                Value<String?> musicalKey = const Value.absent(),
                Value<double?> energy = const Value.absent(),
                Value<String?> analysisJson = const Value.absent(),
                Value<DateTime> analyzedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrackAnalysisCompanion(
                trackId: trackId,
                bpm: bpm,
                musicalKey: musicalKey,
                energy: energy,
                analysisJson: analysisJson,
                analyzedAt: analyzedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String trackId,
                Value<double?> bpm = const Value.absent(),
                Value<String?> musicalKey = const Value.absent(),
                Value<double?> energy = const Value.absent(),
                Value<String?> analysisJson = const Value.absent(),
                required DateTime analyzedAt,
                Value<int> rowid = const Value.absent(),
              }) => TrackAnalysisCompanion.insert(
                trackId: trackId,
                bpm: bpm,
                musicalKey: musicalKey,
                energy: energy,
                analysisJson: analysisJson,
                analyzedAt: analyzedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TrackAnalysisTable, TrackAnalysi>(table),
                  $$TrackAnalysisTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({trackId = false}) {
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
                    if (trackId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.trackId,
                        referencedTable: $$TrackAnalysisTableReferences
                            ._trackIdTable(db),
                        referencedColumn: $$TrackAnalysisTableReferences
                            ._trackIdTable(db)
                            .id,
                      ) as T;
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

typedef $$TrackAnalysisTableProcessedTableManager =
    ProcessedTableManager<
      _$ToneDatabase,
      $TrackAnalysisTable,
      TrackAnalysi,
      $$TrackAnalysisTableFilterComposer,
      $$TrackAnalysisTableOrderingComposer,
      $$TrackAnalysisTableAnnotationComposer,
      $$TrackAnalysisTableCreateCompanionBuilder,
      $$TrackAnalysisTableUpdateCompanionBuilder,
      (TrackAnalysi, $$TrackAnalysisTableReferences),
      TrackAnalysi,
      PrefetchHooks Function({bool trackId})
    >;
typedef $$ArtworkCacheTableCreateCompanionBuilder =
    ArtworkCacheCompanion Function({
      required String sourceUri,
      required String cachedPath,
      Value<int?> byteLength,
      required DateTime cachedAt,
      required DateTime lastAccessedAt,
      Value<int> rowid,
    });
typedef $$ArtworkCacheTableUpdateCompanionBuilder =
    ArtworkCacheCompanion Function({
      Value<String> sourceUri,
      Value<String> cachedPath,
      Value<int?> byteLength,
      Value<DateTime> cachedAt,
      Value<DateTime> lastAccessedAt,
      Value<int> rowid,
    });

class $$ArtworkCacheTableFilterComposer
    extends Composer<_$ToneDatabase, $ArtworkCacheTable> {
  $$ArtworkCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sourceUri => $composableBuilder(
    column: $table.sourceUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cachedPath => $composableBuilder(
    column: $table.cachedPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get byteLength => $composableBuilder(
    column: $table.byteLength,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ArtworkCacheTableOrderingComposer
    extends Composer<_$ToneDatabase, $ArtworkCacheTable> {
  $$ArtworkCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sourceUri => $composableBuilder(
    column: $table.sourceUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cachedPath => $composableBuilder(
    column: $table.cachedPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get byteLength => $composableBuilder(
    column: $table.byteLength,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ArtworkCacheTableAnnotationComposer
    extends Composer<_$ToneDatabase, $ArtworkCacheTable> {
  $$ArtworkCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sourceUri =>
      $composableBuilder(column: $table.sourceUri, builder: (column) => column);

  GeneratedColumn<String> get cachedPath => $composableBuilder(
    column: $table.cachedPath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get byteLength => $composableBuilder(
    column: $table.byteLength,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => column,
  );
}

class $$ArtworkCacheTableTableManager
    extends
        RootTableManager<
          _$ToneDatabase,
          $ArtworkCacheTable,
          ArtworkCacheData,
          $$ArtworkCacheTableFilterComposer,
          $$ArtworkCacheTableOrderingComposer,
          $$ArtworkCacheTableAnnotationComposer,
          $$ArtworkCacheTableCreateCompanionBuilder,
          $$ArtworkCacheTableUpdateCompanionBuilder,
          (
            ArtworkCacheData,
            BaseReferences<
              _$ToneDatabase,
              $ArtworkCacheTable,
              ArtworkCacheData
            >,
          ),
          ArtworkCacheData,
          PrefetchHooks Function()
        > {
  $$ArtworkCacheTableTableManager(_$ToneDatabase db, $ArtworkCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ArtworkCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ArtworkCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ArtworkCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sourceUri = const Value.absent(),
                Value<String> cachedPath = const Value.absent(),
                Value<int?> byteLength = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<DateTime> lastAccessedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ArtworkCacheCompanion(
                sourceUri: sourceUri,
                cachedPath: cachedPath,
                byteLength: byteLength,
                cachedAt: cachedAt,
                lastAccessedAt: lastAccessedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sourceUri,
                required String cachedPath,
                Value<int?> byteLength = const Value.absent(),
                required DateTime cachedAt,
                required DateTime lastAccessedAt,
                Value<int> rowid = const Value.absent(),
              }) => ArtworkCacheCompanion.insert(
                sourceUri: sourceUri,
                cachedPath: cachedPath,
                byteLength: byteLength,
                cachedAt: cachedAt,
                lastAccessedAt: lastAccessedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ArtworkCacheTable, ArtworkCacheData>(table),
                  BaseReferences<
                    _$ToneDatabase,
                    $ArtworkCacheTable,
                    ArtworkCacheData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ArtworkCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$ToneDatabase,
      $ArtworkCacheTable,
      ArtworkCacheData,
      $$ArtworkCacheTableFilterComposer,
      $$ArtworkCacheTableOrderingComposer,
      $$ArtworkCacheTableAnnotationComposer,
      $$ArtworkCacheTableCreateCompanionBuilder,
      $$ArtworkCacheTableUpdateCompanionBuilder,
      (
        ArtworkCacheData,
        BaseReferences<_$ToneDatabase, $ArtworkCacheTable, ArtworkCacheData>,
      ),
      ArtworkCacheData,
      PrefetchHooks Function()
    >;
typedef $$DownloadsTableCreateCompanionBuilder = DownloadsCompanion Function({
  required String trackId,
  required String provider,
  required String providerTrackId,
  Value<String?> licenseUrl,
  required DateTime downloadedAt,
  Value<int> rowid,
});
typedef $$DownloadsTableUpdateCompanionBuilder = DownloadsCompanion Function({
  Value<String> trackId,
  Value<String> provider,
  Value<String> providerTrackId,
  Value<String?> licenseUrl,
  Value<DateTime> downloadedAt,
  Value<int> rowid,
});

final class $$DownloadsTableReferences
    extends BaseReferences<_$ToneDatabase, $DownloadsTable, Download> {
  $$DownloadsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LibraryTracksTable _trackIdTable(_$ToneDatabase db) =>
      db.libraryTracks.createAlias('downloads__track_id__library_tracks__id');

  $$LibraryTracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<String>('track_id')!;

    final manager = $$LibraryTracksTableTableManager(
      $_db,
      $_db.libraryTracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DownloadsTableFilterComposer
    extends Composer<_$ToneDatabase, $DownloadsTable> {
  $$DownloadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerTrackId => $composableBuilder(
    column: $table.providerTrackId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get licenseUrl => $composableBuilder(
    column: $table.licenseUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LibraryTracksTableFilterComposer get trackId {
    final $$LibraryTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.libraryTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryTracksTableFilterComposer(
            $db: $db,
            $table: $db.libraryTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DownloadsTableOrderingComposer
    extends Composer<_$ToneDatabase, $DownloadsTable> {
  $$DownloadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerTrackId => $composableBuilder(
    column: $table.providerTrackId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get licenseUrl => $composableBuilder(
    column: $table.licenseUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LibraryTracksTableOrderingComposer get trackId {
    final $$LibraryTracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.libraryTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryTracksTableOrderingComposer(
            $db: $db,
            $table: $db.libraryTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DownloadsTableAnnotationComposer
    extends Composer<_$ToneDatabase, $DownloadsTable> {
  $$DownloadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get providerTrackId => $composableBuilder(
    column: $table.providerTrackId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get licenseUrl => $composableBuilder(
    column: $table.licenseUrl,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => column,
  );

  $$LibraryTracksTableAnnotationComposer get trackId {
    final $$LibraryTracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.libraryTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryTracksTableAnnotationComposer(
            $db: $db,
            $table: $db.libraryTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DownloadsTableTableManager
    extends
        RootTableManager<
          _$ToneDatabase,
          $DownloadsTable,
          Download,
          $$DownloadsTableFilterComposer,
          $$DownloadsTableOrderingComposer,
          $$DownloadsTableAnnotationComposer,
          $$DownloadsTableCreateCompanionBuilder,
          $$DownloadsTableUpdateCompanionBuilder,
          (Download, $$DownloadsTableReferences),
          Download,
          PrefetchHooks Function({bool trackId})
        > {
  $$DownloadsTableTableManager(_$ToneDatabase db, $DownloadsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> trackId = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<String> providerTrackId = const Value.absent(),
                Value<String?> licenseUrl = const Value.absent(),
                Value<DateTime> downloadedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadsCompanion(
                trackId: trackId,
                provider: provider,
                providerTrackId: providerTrackId,
                licenseUrl: licenseUrl,
                downloadedAt: downloadedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String trackId,
                required String provider,
                required String providerTrackId,
                Value<String?> licenseUrl = const Value.absent(),
                required DateTime downloadedAt,
                Value<int> rowid = const Value.absent(),
              }) => DownloadsCompanion.insert(
                trackId: trackId,
                provider: provider,
                providerTrackId: providerTrackId,
                licenseUrl: licenseUrl,
                downloadedAt: downloadedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DownloadsTable, Download>(table),
                  $$DownloadsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({trackId = false}) {
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
                    if (trackId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.trackId,
                        referencedTable: $$DownloadsTableReferences
                            ._trackIdTable(db),
                        referencedColumn: $$DownloadsTableReferences
                            ._trackIdTable(db)
                            .id,
                      ) as T;
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

typedef $$DownloadsTableProcessedTableManager =
    ProcessedTableManager<
      _$ToneDatabase,
      $DownloadsTable,
      Download,
      $$DownloadsTableFilterComposer,
      $$DownloadsTableOrderingComposer,
      $$DownloadsTableAnnotationComposer,
      $$DownloadsTableCreateCompanionBuilder,
      $$DownloadsTableUpdateCompanionBuilder,
      (Download, $$DownloadsTableReferences),
      Download,
      PrefetchHooks Function({bool trackId})
    >;
typedef $$DjSessionsTableCreateCompanionBuilder = DjSessionsCompanion Function({
  required String id,
  required DateTime startedAt,
  Value<DateTime?> endedAt,
  Value<String?> settingsJson,
  Value<int> rowid,
});
typedef $$DjSessionsTableUpdateCompanionBuilder = DjSessionsCompanion Function({
  Value<String> id,
  Value<DateTime> startedAt,
  Value<DateTime?> endedAt,
  Value<String?> settingsJson,
  Value<int> rowid,
});

final class $$DjSessionsTableReferences
    extends BaseReferences<_$ToneDatabase, $DjSessionsTable, DjSession> {
  $$DjSessionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$DjSessionEventsTable, List<DjSessionEvent>>
  _djSessionEventsRefsTable(_$ToneDatabase db) => MultiTypedResultKey.fromTable(
    db.djSessionEvents,
    aliasName: 'dj_sessions__id__dj_session_events__session_id',
  );

  $$DjSessionEventsTableProcessedTableManager get djSessionEventsRefs {
    final manager = $$DjSessionEventsTableTableManager(
      $_db,
      $_db.djSessionEvents,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _djSessionEventsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DjSessionsTableFilterComposer
    extends Composer<_$ToneDatabase, $DjSessionsTable> {
  $$DjSessionsTableFilterComposer({
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

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get settingsJson => $composableBuilder(
    column: $table.settingsJson,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> djSessionEventsRefs(
    Expression<bool> Function($$DjSessionEventsTableFilterComposer f) f,
  ) {
    final $$DjSessionEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.djSessionEvents,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DjSessionEventsTableFilterComposer(
            $db: $db,
            $table: $db.djSessionEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DjSessionsTableOrderingComposer
    extends Composer<_$ToneDatabase, $DjSessionsTable> {
  $$DjSessionsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get settingsJson => $composableBuilder(
    column: $table.settingsJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DjSessionsTableAnnotationComposer
    extends Composer<_$ToneDatabase, $DjSessionsTable> {
  $$DjSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<String> get settingsJson => $composableBuilder(
    column: $table.settingsJson,
    builder: (column) => column,
  );

  Expression<T> djSessionEventsRefs<T extends Object>(
    Expression<T> Function($$DjSessionEventsTableAnnotationComposer a) f,
  ) {
    final $$DjSessionEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.djSessionEvents,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DjSessionEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.djSessionEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DjSessionsTableTableManager
    extends
        RootTableManager<
          _$ToneDatabase,
          $DjSessionsTable,
          DjSession,
          $$DjSessionsTableFilterComposer,
          $$DjSessionsTableOrderingComposer,
          $$DjSessionsTableAnnotationComposer,
          $$DjSessionsTableCreateCompanionBuilder,
          $$DjSessionsTableUpdateCompanionBuilder,
          (DjSession, $$DjSessionsTableReferences),
          DjSession,
          PrefetchHooks Function({bool djSessionEventsRefs})
        > {
  $$DjSessionsTableTableManager(_$ToneDatabase db, $DjSessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DjSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DjSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DjSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<String?> settingsJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DjSessionsCompanion(
                id: id,
                startedAt: startedAt,
                endedAt: endedAt,
                settingsJson: settingsJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime startedAt,
                Value<DateTime?> endedAt = const Value.absent(),
                Value<String?> settingsJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DjSessionsCompanion.insert(
                id: id,
                startedAt: startedAt,
                endedAt: endedAt,
                settingsJson: settingsJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DjSessionsTable, DjSession>(table),
                  $$DjSessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({djSessionEventsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (djSessionEventsRefs) db.djSessionEvents,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (djSessionEventsRefs)
                    await $_getPrefetchedDataByColumns<
                      DjSession,
                      $DjSessionsTable,
                      DjSessionEvent,
                      $DjSessionEventsTable
                    >(
                      currentTable: table,
                      referencedTable: $$DjSessionsTableReferences
                          ._djSessionEventsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$DjSessionsTableReferences(
                            db,
                            table,
                            p0,
                          ).djSessionEventsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'session_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$DjSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$ToneDatabase,
      $DjSessionsTable,
      DjSession,
      $$DjSessionsTableFilterComposer,
      $$DjSessionsTableOrderingComposer,
      $$DjSessionsTableAnnotationComposer,
      $$DjSessionsTableCreateCompanionBuilder,
      $$DjSessionsTableUpdateCompanionBuilder,
      (DjSession, $$DjSessionsTableReferences),
      DjSession,
      PrefetchHooks Function({bool djSessionEventsRefs})
    >;
typedef $$DjSessionEventsTableCreateCompanionBuilder =
    DjSessionEventsCompanion Function({
      Value<int> id,
      required String sessionId,
      required String eventType,
      Value<String?> trackId,
      Value<String?> payloadJson,
      required DateTime occurredAt,
    });
typedef $$DjSessionEventsTableUpdateCompanionBuilder =
    DjSessionEventsCompanion Function({
      Value<int> id,
      Value<String> sessionId,
      Value<String> eventType,
      Value<String?> trackId,
      Value<String?> payloadJson,
      Value<DateTime> occurredAt,
    });

final class $$DjSessionEventsTableReferences
    extends
        BaseReferences<_$ToneDatabase, $DjSessionEventsTable, DjSessionEvent> {
  $$DjSessionEventsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DjSessionsTable _sessionIdTable(_$ToneDatabase db) => db.djSessions
      .createAlias('dj_session_events__session_id__dj_sessions__id');

  $$DjSessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$DjSessionsTableTableManager(
      $_db,
      $_db.djSessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DjSessionEventsTableFilterComposer
    extends Composer<_$ToneDatabase, $DjSessionEventsTable> {
  $$DjSessionEventsTableFilterComposer({
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

  ColumnFilters<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackId => $composableBuilder(
    column: $table.trackId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  $$DjSessionsTableFilterComposer get sessionId {
    final $$DjSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.djSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DjSessionsTableFilterComposer(
            $db: $db,
            $table: $db.djSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DjSessionEventsTableOrderingComposer
    extends Composer<_$ToneDatabase, $DjSessionEventsTable> {
  $$DjSessionEventsTableOrderingComposer({
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

  ColumnOrderings<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackId => $composableBuilder(
    column: $table.trackId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$DjSessionsTableOrderingComposer get sessionId {
    final $$DjSessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.djSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DjSessionsTableOrderingComposer(
            $db: $db,
            $table: $db.djSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DjSessionEventsTableAnnotationComposer
    extends Composer<_$ToneDatabase, $DjSessionEventsTable> {
  $$DjSessionEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<String> get trackId =>
      $composableBuilder(column: $table.trackId, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  $$DjSessionsTableAnnotationComposer get sessionId {
    final $$DjSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.djSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DjSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.djSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DjSessionEventsTableTableManager
    extends
        RootTableManager<
          _$ToneDatabase,
          $DjSessionEventsTable,
          DjSessionEvent,
          $$DjSessionEventsTableFilterComposer,
          $$DjSessionEventsTableOrderingComposer,
          $$DjSessionEventsTableAnnotationComposer,
          $$DjSessionEventsTableCreateCompanionBuilder,
          $$DjSessionEventsTableUpdateCompanionBuilder,
          (DjSessionEvent, $$DjSessionEventsTableReferences),
          DjSessionEvent,
          PrefetchHooks Function({bool sessionId})
        > {
  $$DjSessionEventsTableTableManager(
    _$ToneDatabase db,
    $DjSessionEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DjSessionEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DjSessionEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DjSessionEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> eventType = const Value.absent(),
                Value<String?> trackId = const Value.absent(),
                Value<String?> payloadJson = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
              }) => DjSessionEventsCompanion(
                id: id,
                sessionId: sessionId,
                eventType: eventType,
                trackId: trackId,
                payloadJson: payloadJson,
                occurredAt: occurredAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String sessionId,
                required String eventType,
                Value<String?> trackId = const Value.absent(),
                Value<String?> payloadJson = const Value.absent(),
                required DateTime occurredAt,
              }) => DjSessionEventsCompanion.insert(
                id: id,
                sessionId: sessionId,
                eventType: eventType,
                trackId: trackId,
                payloadJson: payloadJson,
                occurredAt: occurredAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DjSessionEventsTable, DjSessionEvent>(table),
                  $$DjSessionEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
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
                    if (sessionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sessionId,
                        referencedTable: $$DjSessionEventsTableReferences
                            ._sessionIdTable(db),
                        referencedColumn: $$DjSessionEventsTableReferences
                            ._sessionIdTable(db)
                            .id,
                      ) as T;
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

typedef $$DjSessionEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$ToneDatabase,
      $DjSessionEventsTable,
      DjSessionEvent,
      $$DjSessionEventsTableFilterComposer,
      $$DjSessionEventsTableOrderingComposer,
      $$DjSessionEventsTableAnnotationComposer,
      $$DjSessionEventsTableCreateCompanionBuilder,
      $$DjSessionEventsTableUpdateCompanionBuilder,
      (DjSessionEvent, $$DjSessionEventsTableReferences),
      DjSessionEvent,
      PrefetchHooks Function({bool sessionId})
    >;
typedef $$UserPreferencesTableCreateCompanionBuilder =
    UserPreferencesCompanion Function({
      required String key,
      required String valueJson,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$UserPreferencesTableUpdateCompanionBuilder =
    UserPreferencesCompanion Function({
      Value<String> key,
      Value<String> valueJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$UserPreferencesTableFilterComposer
    extends Composer<_$ToneDatabase, $UserPreferencesTable> {
  $$UserPreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valueJson => $composableBuilder(
    column: $table.valueJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserPreferencesTableOrderingComposer
    extends Composer<_$ToneDatabase, $UserPreferencesTable> {
  $$UserPreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valueJson => $composableBuilder(
    column: $table.valueJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserPreferencesTableAnnotationComposer
    extends Composer<_$ToneDatabase, $UserPreferencesTable> {
  $$UserPreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get valueJson =>
      $composableBuilder(column: $table.valueJson, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$UserPreferencesTableTableManager
    extends
        RootTableManager<
          _$ToneDatabase,
          $UserPreferencesTable,
          UserPreference,
          $$UserPreferencesTableFilterComposer,
          $$UserPreferencesTableOrderingComposer,
          $$UserPreferencesTableAnnotationComposer,
          $$UserPreferencesTableCreateCompanionBuilder,
          $$UserPreferencesTableUpdateCompanionBuilder,
          (
            UserPreference,
            BaseReferences<
              _$ToneDatabase,
              $UserPreferencesTable,
              UserPreference
            >,
          ),
          UserPreference,
          PrefetchHooks Function()
        > {
  $$UserPreferencesTableTableManager(
    _$ToneDatabase db,
    $UserPreferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserPreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserPreferencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserPreferencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> valueJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserPreferencesCompanion(
                key: key,
                valueJson: valueJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String valueJson,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => UserPreferencesCompanion.insert(
                key: key,
                valueJson: valueJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UserPreferencesTable, UserPreference>(table),
                  BaseReferences<
                    _$ToneDatabase,
                    $UserPreferencesTable,
                    UserPreference
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserPreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$ToneDatabase,
      $UserPreferencesTable,
      UserPreference,
      $$UserPreferencesTableFilterComposer,
      $$UserPreferencesTableOrderingComposer,
      $$UserPreferencesTableAnnotationComposer,
      $$UserPreferencesTableCreateCompanionBuilder,
      $$UserPreferencesTableUpdateCompanionBuilder,
      (
        UserPreference,
        BaseReferences<_$ToneDatabase, $UserPreferencesTable, UserPreference>,
      ),
      UserPreference,
      PrefetchHooks Function()
    >;
typedef $$AudioProfilesTableCreateCompanionBuilder =
    AudioProfilesCompanion Function({
      required String id,
      required String name,
      required String settingsJson,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$AudioProfilesTableUpdateCompanionBuilder =
    AudioProfilesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> settingsJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$AudioProfilesTableFilterComposer
    extends Composer<_$ToneDatabase, $AudioProfilesTable> {
  $$AudioProfilesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get settingsJson => $composableBuilder(
    column: $table.settingsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AudioProfilesTableOrderingComposer
    extends Composer<_$ToneDatabase, $AudioProfilesTable> {
  $$AudioProfilesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get settingsJson => $composableBuilder(
    column: $table.settingsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AudioProfilesTableAnnotationComposer
    extends Composer<_$ToneDatabase, $AudioProfilesTable> {
  $$AudioProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get settingsJson => $composableBuilder(
    column: $table.settingsJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AudioProfilesTableTableManager
    extends
        RootTableManager<
          _$ToneDatabase,
          $AudioProfilesTable,
          AudioProfile,
          $$AudioProfilesTableFilterComposer,
          $$AudioProfilesTableOrderingComposer,
          $$AudioProfilesTableAnnotationComposer,
          $$AudioProfilesTableCreateCompanionBuilder,
          $$AudioProfilesTableUpdateCompanionBuilder,
          (
            AudioProfile,
            BaseReferences<_$ToneDatabase, $AudioProfilesTable, AudioProfile>,
          ),
          AudioProfile,
          PrefetchHooks Function()
        > {
  $$AudioProfilesTableTableManager(_$ToneDatabase db, $AudioProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AudioProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AudioProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AudioProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> settingsJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AudioProfilesCompanion(
                id: id,
                name: name,
                settingsJson: settingsJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String settingsJson,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AudioProfilesCompanion.insert(
                id: id,
                name: name,
                settingsJson: settingsJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AudioProfilesTable, AudioProfile>(table),
                  BaseReferences<
                    _$ToneDatabase,
                    $AudioProfilesTable,
                    AudioProfile
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AudioProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$ToneDatabase,
      $AudioProfilesTable,
      AudioProfile,
      $$AudioProfilesTableFilterComposer,
      $$AudioProfilesTableOrderingComposer,
      $$AudioProfilesTableAnnotationComposer,
      $$AudioProfilesTableCreateCompanionBuilder,
      $$AudioProfilesTableUpdateCompanionBuilder,
      (
        AudioProfile,
        BaseReferences<_$ToneDatabase, $AudioProfilesTable, AudioProfile>,
      ),
      AudioProfile,
      PrefetchHooks Function()
    >;

class $ToneDatabaseManager {
  final _$ToneDatabase _db;
  $ToneDatabaseManager(this._db);
  $$ArtistsTableTableManager get artists =>
      $$ArtistsTableTableManager(_db, _db.artists);
  $$AlbumsTableTableManager get albums =>
      $$AlbumsTableTableManager(_db, _db.albums);
  $$LibraryTracksTableTableManager get libraryTracks =>
      $$LibraryTracksTableTableManager(_db, _db.libraryTracks);
  $$LibraryFoldersTableTableManager get libraryFolders =>
      $$LibraryFoldersTableTableManager(_db, _db.libraryFolders);
  $$PlaylistsTableTableManager get playlists =>
      $$PlaylistsTableTableManager(_db, _db.playlists);
  $$PlaylistTracksTableTableManager get playlistTracks =>
      $$PlaylistTracksTableTableManager(_db, _db.playlistTracks);
  $$FavoritesTableTableManager get favorites =>
      $$FavoritesTableTableManager(_db, _db.favorites);
  $$ExcludedTracksTableTableManager get excludedTracks =>
      $$ExcludedTracksTableTableManager(_db, _db.excludedTracks);
  $$PlaybackQueueEntriesTableTableManager get playbackQueueEntries =>
      $$PlaybackQueueEntriesTableTableManager(_db, _db.playbackQueueEntries);
  $$PlaybackStateTableTableManager get playbackState =>
      $$PlaybackStateTableTableManager(_db, _db.playbackState);
  $$PlaybackHistoryTableTableManager get playbackHistory =>
      $$PlaybackHistoryTableTableManager(_db, _db.playbackHistory);
  $$TrackAnalysisTableTableManager get trackAnalysis =>
      $$TrackAnalysisTableTableManager(_db, _db.trackAnalysis);
  $$ArtworkCacheTableTableManager get artworkCache =>
      $$ArtworkCacheTableTableManager(_db, _db.artworkCache);
  $$DownloadsTableTableManager get downloads =>
      $$DownloadsTableTableManager(_db, _db.downloads);
  $$DjSessionsTableTableManager get djSessions =>
      $$DjSessionsTableTableManager(_db, _db.djSessions);
  $$DjSessionEventsTableTableManager get djSessionEvents =>
      $$DjSessionEventsTableTableManager(_db, _db.djSessionEvents);
  $$UserPreferencesTableTableManager get userPreferences =>
      $$UserPreferencesTableTableManager(_db, _db.userPreferences);
  $$AudioProfilesTableTableManager get audioProfiles =>
      $$AudioProfilesTableTableManager(_db, _db.audioProfiles);
}
