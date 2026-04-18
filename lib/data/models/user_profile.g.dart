// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserSettingsImpl _$$UserSettingsImplFromJson(Map<String, dynamic> json) =>
    _$UserSettingsImpl(
      soundEnabled: json['sound_enabled'] as bool? ?? true,
      defaultSoundscapeId: json['default_soundscape_id'] as String?,
      appTheme:
          $enumDecodeNullable(_$AppThemeEnumMap, json['app_theme']) ??
          AppTheme.cream,
      reminderTimes:
          (json['reminder_times'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      weekStartsOn: json['week_starts_on'] as String? ?? 'monday',
      importedSeed: json['imported_seed'] as bool? ?? false,
    );

Map<String, dynamic> _$$UserSettingsImplToJson(_$UserSettingsImpl instance) =>
    <String, dynamic>{
      'sound_enabled': instance.soundEnabled,
      'default_soundscape_id': instance.defaultSoundscapeId,
      'app_theme': _$AppThemeEnumMap[instance.appTheme]!,
      'reminder_times': instance.reminderTimes,
      'week_starts_on': instance.weekStartsOn,
      'imported_seed': instance.importedSeed,
    };

const _$AppThemeEnumMap = {
  AppTheme.cream: 'cream',
  AppTheme.chocolate: 'chocolate',
};

_$UserProfileImpl _$$UserProfileImplFromJson(Map<String, dynamic> json) =>
    _$UserProfileImpl(
      settings: UserSettings.fromJson(json['settings'] as Map<String, dynamic>),
      userId: json['user_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      displayName: json['display_name'] as String?,
    );

Map<String, dynamic> _$$UserProfileImplToJson(_$UserProfileImpl instance) =>
    <String, dynamic>{
      'settings': instance.settings,
      'user_id': instance.userId,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'display_name': instance.displayName,
    };
