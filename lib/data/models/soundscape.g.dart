// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'soundscape.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SoundscapeImpl _$$SoundscapeImplFromJson(Map<String, dynamic> json) =>
    _$SoundscapeImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      kind: $enumDecode(_$SoundscapeKindEnumMap, json['kind']),
      isSystem: json['is_system'] as bool? ?? false,
      userId: json['user_id'] as String?,
    );

Map<String, dynamic> _$$SoundscapeImplToJson(_$SoundscapeImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'url': instance.url,
      'kind': _$SoundscapeKindEnumMap[instance.kind]!,
      'is_system': instance.isSystem,
      'user_id': instance.userId,
    };

const _$SoundscapeKindEnumMap = {
  SoundscapeKind.solfeggio: 'solfeggio',
  SoundscapeKind.nature: 'nature',
  SoundscapeKind.music: 'music',
};
