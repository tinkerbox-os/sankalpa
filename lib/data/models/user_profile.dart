import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_profile.freezed.dart';
part 'user_profile.g.dart';

enum AppTheme {
  @JsonValue('cream')
  cream,
  @JsonValue('chocolate')
  chocolate,
}

@freezed
class UserSettings with _$UserSettings {
  const factory UserSettings({
    @Default(true) @JsonKey(name: 'sound_enabled') bool soundEnabled,
    @JsonKey(name: 'default_soundscape_id') String? defaultSoundscapeId,
    @Default(AppTheme.cream) @JsonKey(name: 'app_theme') AppTheme appTheme,
    @Default(<String>[]) @JsonKey(name: 'reminder_times')
    List<String> reminderTimes,
    @Default('monday') @JsonKey(name: 'week_starts_on') String weekStartsOn,
    @Default(false) @JsonKey(name: 'imported_seed') bool importedSeed,
  }) = _UserSettings;

  factory UserSettings.fromJson(Map<String, dynamic> json) =>
      _$UserSettingsFromJson(json);
}

@freezed
class UserProfile with _$UserProfile {
  const factory UserProfile({
    required UserSettings settings,
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
    @JsonKey(name: 'display_name') String? displayName,
  }) = _UserProfile;

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);
}
