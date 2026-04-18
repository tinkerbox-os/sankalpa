// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'manifestation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ManifestationImpl _$$ManifestationImplFromJson(Map<String, dynamic> json) =>
    _$ManifestationImpl(
      id: json['id'] as String,
      text: json['text'] as String,
      userId: json['user_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      categoryId: json['category_id'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      status:
          $enumDecodeNullable(_$ManifestationStatusEnumMap, json['status']) ??
          ManifestationStatus.active,
      backdropType:
          $enumDecodeNullable(_$BackdropTypeEnumMap, json['backdrop_type']) ??
          BackdropType.theme,
      themeId: json['theme_id'] as String? ?? 'chocolate',
      imageUrl: json['image_url'] as String?,
      imagePrompt: json['image_prompt'] as String?,
      imageStyle: json['image_style'] as String?,
      textVariant:
          $enumDecodeNullable(_$TextVariantEnumMap, json['text_variant']) ??
          TextVariant.regular,
      voiceUrl: json['voice_url'] as String?,
      soundId: json['sound_id'] as String?,
      manifestedAt:
          json['manifested_at'] == null
              ? null
              : DateTime.parse(json['manifested_at'] as String),
    );

Map<String, dynamic> _$$ManifestationImplToJson(_$ManifestationImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'text': instance.text,
      'user_id': instance.userId,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'category_id': instance.categoryId,
      'sort_order': instance.sortOrder,
      'status': _$ManifestationStatusEnumMap[instance.status]!,
      'backdrop_type': _$BackdropTypeEnumMap[instance.backdropType]!,
      'theme_id': instance.themeId,
      'image_url': instance.imageUrl,
      'image_prompt': instance.imagePrompt,
      'image_style': instance.imageStyle,
      'text_variant': _$TextVariantEnumMap[instance.textVariant]!,
      'voice_url': instance.voiceUrl,
      'sound_id': instance.soundId,
      'manifested_at': instance.manifestedAt?.toIso8601String(),
    };

const _$ManifestationStatusEnumMap = {
  ManifestationStatus.active: 'active',
  ManifestationStatus.manifested: 'manifested',
  ManifestationStatus.archived: 'archived',
};

const _$BackdropTypeEnumMap = {
  BackdropType.theme: 'theme',
  BackdropType.image: 'image',
};

const _$TextVariantEnumMap = {
  TextVariant.regular: 'regular',
  TextVariant.italic: 'italic',
};
