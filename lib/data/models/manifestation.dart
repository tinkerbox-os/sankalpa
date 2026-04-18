import 'package:freezed_annotation/freezed_annotation.dart';

part 'manifestation.freezed.dart';
part 'manifestation.g.dart';

enum ManifestationStatus {
  @JsonValue('active')
  active,
  @JsonValue('manifested')
  manifested,
  @JsonValue('archived')
  archived,
}

enum BackdropType {
  @JsonValue('theme')
  theme,
  @JsonValue('image')
  image,
}

enum TextVariant {
  @JsonValue('regular')
  regular,
  @JsonValue('italic')
  italic,
}

@freezed
class Manifestation with _$Manifestation {
  const factory Manifestation({
    required String id,
    required String text,
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
    @JsonKey(name: 'category_id') String? categoryId,
    @Default(0) @JsonKey(name: 'sort_order') int sortOrder,
    @Default(ManifestationStatus.active) ManifestationStatus status,
    @Default(BackdropType.theme) @JsonKey(name: 'backdrop_type')
    BackdropType backdropType,
    @Default('chocolate') @JsonKey(name: 'theme_id') String themeId,
    @JsonKey(name: 'image_url') String? imageUrl,
    @JsonKey(name: 'image_prompt') String? imagePrompt,
    @JsonKey(name: 'image_style') String? imageStyle,
    @Default(TextVariant.regular) @JsonKey(name: 'text_variant')
    TextVariant textVariant,
    @JsonKey(name: 'voice_url') String? voiceUrl,
    @JsonKey(name: 'sound_id') String? soundId,
    @JsonKey(name: 'manifested_at') DateTime? manifestedAt,
  }) = _Manifestation;

  factory Manifestation.fromJson(Map<String, dynamic> json) =>
      _$ManifestationFromJson(json);
}
