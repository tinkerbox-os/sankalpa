// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_profile.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

UserSettings _$UserSettingsFromJson(Map<String, dynamic> json) {
  return _UserSettings.fromJson(json);
}

/// @nodoc
mixin _$UserSettings {
  @JsonKey(name: 'sound_enabled')
  bool get soundEnabled => throw _privateConstructorUsedError;
  @JsonKey(name: 'default_soundscape_id')
  String? get defaultSoundscapeId => throw _privateConstructorUsedError;
  @JsonKey(name: 'app_theme')
  AppTheme get appTheme => throw _privateConstructorUsedError;
  @JsonKey(name: 'reminder_times')
  List<String> get reminderTimes => throw _privateConstructorUsedError;
  @JsonKey(name: 'week_starts_on')
  String get weekStartsOn => throw _privateConstructorUsedError;
  @JsonKey(name: 'imported_seed')
  bool get importedSeed => throw _privateConstructorUsedError;

  /// Serializes this UserSettings to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of UserSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UserSettingsCopyWith<UserSettings> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserSettingsCopyWith<$Res> {
  factory $UserSettingsCopyWith(
    UserSettings value,
    $Res Function(UserSettings) then,
  ) = _$UserSettingsCopyWithImpl<$Res, UserSettings>;
  @useResult
  $Res call({
    @JsonKey(name: 'sound_enabled') bool soundEnabled,
    @JsonKey(name: 'default_soundscape_id') String? defaultSoundscapeId,
    @JsonKey(name: 'app_theme') AppTheme appTheme,
    @JsonKey(name: 'reminder_times') List<String> reminderTimes,
    @JsonKey(name: 'week_starts_on') String weekStartsOn,
    @JsonKey(name: 'imported_seed') bool importedSeed,
  });
}

/// @nodoc
class _$UserSettingsCopyWithImpl<$Res, $Val extends UserSettings>
    implements $UserSettingsCopyWith<$Res> {
  _$UserSettingsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UserSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? soundEnabled = null,
    Object? defaultSoundscapeId = freezed,
    Object? appTheme = null,
    Object? reminderTimes = null,
    Object? weekStartsOn = null,
    Object? importedSeed = null,
  }) {
    return _then(
      _value.copyWith(
            soundEnabled:
                null == soundEnabled
                    ? _value.soundEnabled
                    : soundEnabled // ignore: cast_nullable_to_non_nullable
                        as bool,
            defaultSoundscapeId:
                freezed == defaultSoundscapeId
                    ? _value.defaultSoundscapeId
                    : defaultSoundscapeId // ignore: cast_nullable_to_non_nullable
                        as String?,
            appTheme:
                null == appTheme
                    ? _value.appTheme
                    : appTheme // ignore: cast_nullable_to_non_nullable
                        as AppTheme,
            reminderTimes:
                null == reminderTimes
                    ? _value.reminderTimes
                    : reminderTimes // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            weekStartsOn:
                null == weekStartsOn
                    ? _value.weekStartsOn
                    : weekStartsOn // ignore: cast_nullable_to_non_nullable
                        as String,
            importedSeed:
                null == importedSeed
                    ? _value.importedSeed
                    : importedSeed // ignore: cast_nullable_to_non_nullable
                        as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$UserSettingsImplCopyWith<$Res>
    implements $UserSettingsCopyWith<$Res> {
  factory _$$UserSettingsImplCopyWith(
    _$UserSettingsImpl value,
    $Res Function(_$UserSettingsImpl) then,
  ) = __$$UserSettingsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'sound_enabled') bool soundEnabled,
    @JsonKey(name: 'default_soundscape_id') String? defaultSoundscapeId,
    @JsonKey(name: 'app_theme') AppTheme appTheme,
    @JsonKey(name: 'reminder_times') List<String> reminderTimes,
    @JsonKey(name: 'week_starts_on') String weekStartsOn,
    @JsonKey(name: 'imported_seed') bool importedSeed,
  });
}

/// @nodoc
class __$$UserSettingsImplCopyWithImpl<$Res>
    extends _$UserSettingsCopyWithImpl<$Res, _$UserSettingsImpl>
    implements _$$UserSettingsImplCopyWith<$Res> {
  __$$UserSettingsImplCopyWithImpl(
    _$UserSettingsImpl _value,
    $Res Function(_$UserSettingsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of UserSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? soundEnabled = null,
    Object? defaultSoundscapeId = freezed,
    Object? appTheme = null,
    Object? reminderTimes = null,
    Object? weekStartsOn = null,
    Object? importedSeed = null,
  }) {
    return _then(
      _$UserSettingsImpl(
        soundEnabled:
            null == soundEnabled
                ? _value.soundEnabled
                : soundEnabled // ignore: cast_nullable_to_non_nullable
                    as bool,
        defaultSoundscapeId:
            freezed == defaultSoundscapeId
                ? _value.defaultSoundscapeId
                : defaultSoundscapeId // ignore: cast_nullable_to_non_nullable
                    as String?,
        appTheme:
            null == appTheme
                ? _value.appTheme
                : appTheme // ignore: cast_nullable_to_non_nullable
                    as AppTheme,
        reminderTimes:
            null == reminderTimes
                ? _value._reminderTimes
                : reminderTimes // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        weekStartsOn:
            null == weekStartsOn
                ? _value.weekStartsOn
                : weekStartsOn // ignore: cast_nullable_to_non_nullable
                    as String,
        importedSeed:
            null == importedSeed
                ? _value.importedSeed
                : importedSeed // ignore: cast_nullable_to_non_nullable
                    as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$UserSettingsImpl implements _UserSettings {
  const _$UserSettingsImpl({
    @JsonKey(name: 'sound_enabled') this.soundEnabled = true,
    @JsonKey(name: 'default_soundscape_id') this.defaultSoundscapeId,
    @JsonKey(name: 'app_theme') this.appTheme = AppTheme.cream,
    @JsonKey(name: 'reminder_times')
    final List<String> reminderTimes = const <String>[],
    @JsonKey(name: 'week_starts_on') this.weekStartsOn = 'monday',
    @JsonKey(name: 'imported_seed') this.importedSeed = false,
  }) : _reminderTimes = reminderTimes;

  factory _$UserSettingsImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserSettingsImplFromJson(json);

  @override
  @JsonKey(name: 'sound_enabled')
  final bool soundEnabled;
  @override
  @JsonKey(name: 'default_soundscape_id')
  final String? defaultSoundscapeId;
  @override
  @JsonKey(name: 'app_theme')
  final AppTheme appTheme;
  final List<String> _reminderTimes;
  @override
  @JsonKey(name: 'reminder_times')
  List<String> get reminderTimes {
    if (_reminderTimes is EqualUnmodifiableListView) return _reminderTimes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_reminderTimes);
  }

  @override
  @JsonKey(name: 'week_starts_on')
  final String weekStartsOn;
  @override
  @JsonKey(name: 'imported_seed')
  final bool importedSeed;

  @override
  String toString() {
    return 'UserSettings(soundEnabled: $soundEnabled, defaultSoundscapeId: $defaultSoundscapeId, appTheme: $appTheme, reminderTimes: $reminderTimes, weekStartsOn: $weekStartsOn, importedSeed: $importedSeed)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserSettingsImpl &&
            (identical(other.soundEnabled, soundEnabled) ||
                other.soundEnabled == soundEnabled) &&
            (identical(other.defaultSoundscapeId, defaultSoundscapeId) ||
                other.defaultSoundscapeId == defaultSoundscapeId) &&
            (identical(other.appTheme, appTheme) ||
                other.appTheme == appTheme) &&
            const DeepCollectionEquality().equals(
              other._reminderTimes,
              _reminderTimes,
            ) &&
            (identical(other.weekStartsOn, weekStartsOn) ||
                other.weekStartsOn == weekStartsOn) &&
            (identical(other.importedSeed, importedSeed) ||
                other.importedSeed == importedSeed));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    soundEnabled,
    defaultSoundscapeId,
    appTheme,
    const DeepCollectionEquality().hash(_reminderTimes),
    weekStartsOn,
    importedSeed,
  );

  /// Create a copy of UserSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UserSettingsImplCopyWith<_$UserSettingsImpl> get copyWith =>
      __$$UserSettingsImplCopyWithImpl<_$UserSettingsImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UserSettingsImplToJson(this);
  }
}

abstract class _UserSettings implements UserSettings {
  const factory _UserSettings({
    @JsonKey(name: 'sound_enabled') final bool soundEnabled,
    @JsonKey(name: 'default_soundscape_id') final String? defaultSoundscapeId,
    @JsonKey(name: 'app_theme') final AppTheme appTheme,
    @JsonKey(name: 'reminder_times') final List<String> reminderTimes,
    @JsonKey(name: 'week_starts_on') final String weekStartsOn,
    @JsonKey(name: 'imported_seed') final bool importedSeed,
  }) = _$UserSettingsImpl;

  factory _UserSettings.fromJson(Map<String, dynamic> json) =
      _$UserSettingsImpl.fromJson;

  @override
  @JsonKey(name: 'sound_enabled')
  bool get soundEnabled;
  @override
  @JsonKey(name: 'default_soundscape_id')
  String? get defaultSoundscapeId;
  @override
  @JsonKey(name: 'app_theme')
  AppTheme get appTheme;
  @override
  @JsonKey(name: 'reminder_times')
  List<String> get reminderTimes;
  @override
  @JsonKey(name: 'week_starts_on')
  String get weekStartsOn;
  @override
  @JsonKey(name: 'imported_seed')
  bool get importedSeed;

  /// Create a copy of UserSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserSettingsImplCopyWith<_$UserSettingsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

UserProfile _$UserProfileFromJson(Map<String, dynamic> json) {
  return _UserProfile.fromJson(json);
}

/// @nodoc
mixin _$UserProfile {
  UserSettings get settings => throw _privateConstructorUsedError;
  @JsonKey(name: 'user_id')
  String get userId => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'display_name')
  String? get displayName => throw _privateConstructorUsedError;

  /// Serializes this UserProfile to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of UserProfile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UserProfileCopyWith<UserProfile> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserProfileCopyWith<$Res> {
  factory $UserProfileCopyWith(
    UserProfile value,
    $Res Function(UserProfile) then,
  ) = _$UserProfileCopyWithImpl<$Res, UserProfile>;
  @useResult
  $Res call({
    UserSettings settings,
    @JsonKey(name: 'user_id') String userId,
    @JsonKey(name: 'created_at') DateTime createdAt,
    @JsonKey(name: 'updated_at') DateTime updatedAt,
    @JsonKey(name: 'display_name') String? displayName,
  });

  $UserSettingsCopyWith<$Res> get settings;
}

/// @nodoc
class _$UserProfileCopyWithImpl<$Res, $Val extends UserProfile>
    implements $UserProfileCopyWith<$Res> {
  _$UserProfileCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UserProfile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? settings = null,
    Object? userId = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? displayName = freezed,
  }) {
    return _then(
      _value.copyWith(
            settings:
                null == settings
                    ? _value.settings
                    : settings // ignore: cast_nullable_to_non_nullable
                        as UserSettings,
            userId:
                null == userId
                    ? _value.userId
                    : userId // ignore: cast_nullable_to_non_nullable
                        as String,
            createdAt:
                null == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as DateTime,
            updatedAt:
                null == updatedAt
                    ? _value.updatedAt
                    : updatedAt // ignore: cast_nullable_to_non_nullable
                        as DateTime,
            displayName:
                freezed == displayName
                    ? _value.displayName
                    : displayName // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }

  /// Create a copy of UserProfile
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UserSettingsCopyWith<$Res> get settings {
    return $UserSettingsCopyWith<$Res>(_value.settings, (value) {
      return _then(_value.copyWith(settings: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$UserProfileImplCopyWith<$Res>
    implements $UserProfileCopyWith<$Res> {
  factory _$$UserProfileImplCopyWith(
    _$UserProfileImpl value,
    $Res Function(_$UserProfileImpl) then,
  ) = __$$UserProfileImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    UserSettings settings,
    @JsonKey(name: 'user_id') String userId,
    @JsonKey(name: 'created_at') DateTime createdAt,
    @JsonKey(name: 'updated_at') DateTime updatedAt,
    @JsonKey(name: 'display_name') String? displayName,
  });

  @override
  $UserSettingsCopyWith<$Res> get settings;
}

/// @nodoc
class __$$UserProfileImplCopyWithImpl<$Res>
    extends _$UserProfileCopyWithImpl<$Res, _$UserProfileImpl>
    implements _$$UserProfileImplCopyWith<$Res> {
  __$$UserProfileImplCopyWithImpl(
    _$UserProfileImpl _value,
    $Res Function(_$UserProfileImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of UserProfile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? settings = null,
    Object? userId = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? displayName = freezed,
  }) {
    return _then(
      _$UserProfileImpl(
        settings:
            null == settings
                ? _value.settings
                : settings // ignore: cast_nullable_to_non_nullable
                    as UserSettings,
        userId:
            null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                    as String,
        createdAt:
            null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as DateTime,
        updatedAt:
            null == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                    as DateTime,
        displayName:
            freezed == displayName
                ? _value.displayName
                : displayName // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$UserProfileImpl implements _UserProfile {
  const _$UserProfileImpl({
    required this.settings,
    @JsonKey(name: 'user_id') required this.userId,
    @JsonKey(name: 'created_at') required this.createdAt,
    @JsonKey(name: 'updated_at') required this.updatedAt,
    @JsonKey(name: 'display_name') this.displayName,
  });

  factory _$UserProfileImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserProfileImplFromJson(json);

  @override
  final UserSettings settings;
  @override
  @JsonKey(name: 'user_id')
  final String userId;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;
  @override
  @JsonKey(name: 'display_name')
  final String? displayName;

  @override
  String toString() {
    return 'UserProfile(settings: $settings, userId: $userId, createdAt: $createdAt, updatedAt: $updatedAt, displayName: $displayName)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserProfileImpl &&
            (identical(other.settings, settings) ||
                other.settings == settings) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    settings,
    userId,
    createdAt,
    updatedAt,
    displayName,
  );

  /// Create a copy of UserProfile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UserProfileImplCopyWith<_$UserProfileImpl> get copyWith =>
      __$$UserProfileImplCopyWithImpl<_$UserProfileImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UserProfileImplToJson(this);
  }
}

abstract class _UserProfile implements UserProfile {
  const factory _UserProfile({
    required final UserSettings settings,
    @JsonKey(name: 'user_id') required final String userId,
    @JsonKey(name: 'created_at') required final DateTime createdAt,
    @JsonKey(name: 'updated_at') required final DateTime updatedAt,
    @JsonKey(name: 'display_name') final String? displayName,
  }) = _$UserProfileImpl;

  factory _UserProfile.fromJson(Map<String, dynamic> json) =
      _$UserProfileImpl.fromJson;

  @override
  UserSettings get settings;
  @override
  @JsonKey(name: 'user_id')
  String get userId;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @override
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt;
  @override
  @JsonKey(name: 'display_name')
  String? get displayName;

  /// Create a copy of UserProfile
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserProfileImplCopyWith<_$UserProfileImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
