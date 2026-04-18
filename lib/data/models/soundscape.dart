import 'package:freezed_annotation/freezed_annotation.dart';

part 'soundscape.freezed.dart';
part 'soundscape.g.dart';

enum SoundscapeKind {
  @JsonValue('solfeggio')
  solfeggio,
  @JsonValue('nature')
  nature,
  @JsonValue('music')
  music,
}

@freezed
class Soundscape with _$Soundscape {
  const factory Soundscape({
    required String id,
    required String name,
    required String url,
    required SoundscapeKind kind,
    @JsonKey(name: 'is_system') @Default(false) bool isSystem,
    @JsonKey(name: 'user_id') String? userId,
  }) = _Soundscape;

  factory Soundscape.fromJson(Map<String, dynamic> json) =>
      _$SoundscapeFromJson(json);
}
