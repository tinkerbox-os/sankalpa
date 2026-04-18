// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'manifestation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Manifestation _$ManifestationFromJson(Map<String, dynamic> json) {
  return _Manifestation.fromJson(json);
}

/// @nodoc
mixin _$Manifestation {
  String get id => throw _privateConstructorUsedError;
  String get text => throw _privateConstructorUsedError;
  @JsonKey(name: 'user_id')
  String get userId => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'category_id')
  String? get categoryId => throw _privateConstructorUsedError;
  @JsonKey(name: 'sort_order')
  int get sortOrder => throw _privateConstructorUsedError;
  ManifestationStatus get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'backdrop_type')
  BackdropType get backdropType => throw _privateConstructorUsedError;
  @JsonKey(name: 'theme_id')
  String get themeId => throw _privateConstructorUsedError;
  @JsonKey(name: 'image_url')
  String? get imageUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'image_prompt')
  String? get imagePrompt => throw _privateConstructorUsedError;
  @JsonKey(name: 'image_style')
  String? get imageStyle => throw _privateConstructorUsedError;
  @JsonKey(name: 'text_variant')
  TextVariant get textVariant => throw _privateConstructorUsedError;
  @JsonKey(name: 'voice_url')
  String? get voiceUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'sound_id')
  String? get soundId => throw _privateConstructorUsedError;
  @JsonKey(name: 'manifested_at')
  DateTime? get manifestedAt => throw _privateConstructorUsedError;

  /// Serializes this Manifestation to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Manifestation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ManifestationCopyWith<Manifestation> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ManifestationCopyWith<$Res> {
  factory $ManifestationCopyWith(
    Manifestation value,
    $Res Function(Manifestation) then,
  ) = _$ManifestationCopyWithImpl<$Res, Manifestation>;
  @useResult
  $Res call({
    String id,
    String text,
    @JsonKey(name: 'user_id') String userId,
    @JsonKey(name: 'created_at') DateTime createdAt,
    @JsonKey(name: 'updated_at') DateTime updatedAt,
    @JsonKey(name: 'category_id') String? categoryId,
    @JsonKey(name: 'sort_order') int sortOrder,
    ManifestationStatus status,
    @JsonKey(name: 'backdrop_type') BackdropType backdropType,
    @JsonKey(name: 'theme_id') String themeId,
    @JsonKey(name: 'image_url') String? imageUrl,
    @JsonKey(name: 'image_prompt') String? imagePrompt,
    @JsonKey(name: 'image_style') String? imageStyle,
    @JsonKey(name: 'text_variant') TextVariant textVariant,
    @JsonKey(name: 'voice_url') String? voiceUrl,
    @JsonKey(name: 'sound_id') String? soundId,
    @JsonKey(name: 'manifested_at') DateTime? manifestedAt,
  });
}

/// @nodoc
class _$ManifestationCopyWithImpl<$Res, $Val extends Manifestation>
    implements $ManifestationCopyWith<$Res> {
  _$ManifestationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Manifestation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? text = null,
    Object? userId = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? categoryId = freezed,
    Object? sortOrder = null,
    Object? status = null,
    Object? backdropType = null,
    Object? themeId = null,
    Object? imageUrl = freezed,
    Object? imagePrompt = freezed,
    Object? imageStyle = freezed,
    Object? textVariant = null,
    Object? voiceUrl = freezed,
    Object? soundId = freezed,
    Object? manifestedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            text:
                null == text
                    ? _value.text
                    : text // ignore: cast_nullable_to_non_nullable
                        as String,
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
            categoryId:
                freezed == categoryId
                    ? _value.categoryId
                    : categoryId // ignore: cast_nullable_to_non_nullable
                        as String?,
            sortOrder:
                null == sortOrder
                    ? _value.sortOrder
                    : sortOrder // ignore: cast_nullable_to_non_nullable
                        as int,
            status:
                null == status
                    ? _value.status
                    : status // ignore: cast_nullable_to_non_nullable
                        as ManifestationStatus,
            backdropType:
                null == backdropType
                    ? _value.backdropType
                    : backdropType // ignore: cast_nullable_to_non_nullable
                        as BackdropType,
            themeId:
                null == themeId
                    ? _value.themeId
                    : themeId // ignore: cast_nullable_to_non_nullable
                        as String,
            imageUrl:
                freezed == imageUrl
                    ? _value.imageUrl
                    : imageUrl // ignore: cast_nullable_to_non_nullable
                        as String?,
            imagePrompt:
                freezed == imagePrompt
                    ? _value.imagePrompt
                    : imagePrompt // ignore: cast_nullable_to_non_nullable
                        as String?,
            imageStyle:
                freezed == imageStyle
                    ? _value.imageStyle
                    : imageStyle // ignore: cast_nullable_to_non_nullable
                        as String?,
            textVariant:
                null == textVariant
                    ? _value.textVariant
                    : textVariant // ignore: cast_nullable_to_non_nullable
                        as TextVariant,
            voiceUrl:
                freezed == voiceUrl
                    ? _value.voiceUrl
                    : voiceUrl // ignore: cast_nullable_to_non_nullable
                        as String?,
            soundId:
                freezed == soundId
                    ? _value.soundId
                    : soundId // ignore: cast_nullable_to_non_nullable
                        as String?,
            manifestedAt:
                freezed == manifestedAt
                    ? _value.manifestedAt
                    : manifestedAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ManifestationImplCopyWith<$Res>
    implements $ManifestationCopyWith<$Res> {
  factory _$$ManifestationImplCopyWith(
    _$ManifestationImpl value,
    $Res Function(_$ManifestationImpl) then,
  ) = __$$ManifestationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String text,
    @JsonKey(name: 'user_id') String userId,
    @JsonKey(name: 'created_at') DateTime createdAt,
    @JsonKey(name: 'updated_at') DateTime updatedAt,
    @JsonKey(name: 'category_id') String? categoryId,
    @JsonKey(name: 'sort_order') int sortOrder,
    ManifestationStatus status,
    @JsonKey(name: 'backdrop_type') BackdropType backdropType,
    @JsonKey(name: 'theme_id') String themeId,
    @JsonKey(name: 'image_url') String? imageUrl,
    @JsonKey(name: 'image_prompt') String? imagePrompt,
    @JsonKey(name: 'image_style') String? imageStyle,
    @JsonKey(name: 'text_variant') TextVariant textVariant,
    @JsonKey(name: 'voice_url') String? voiceUrl,
    @JsonKey(name: 'sound_id') String? soundId,
    @JsonKey(name: 'manifested_at') DateTime? manifestedAt,
  });
}

/// @nodoc
class __$$ManifestationImplCopyWithImpl<$Res>
    extends _$ManifestationCopyWithImpl<$Res, _$ManifestationImpl>
    implements _$$ManifestationImplCopyWith<$Res> {
  __$$ManifestationImplCopyWithImpl(
    _$ManifestationImpl _value,
    $Res Function(_$ManifestationImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Manifestation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? text = null,
    Object? userId = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? categoryId = freezed,
    Object? sortOrder = null,
    Object? status = null,
    Object? backdropType = null,
    Object? themeId = null,
    Object? imageUrl = freezed,
    Object? imagePrompt = freezed,
    Object? imageStyle = freezed,
    Object? textVariant = null,
    Object? voiceUrl = freezed,
    Object? soundId = freezed,
    Object? manifestedAt = freezed,
  }) {
    return _then(
      _$ManifestationImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        text:
            null == text
                ? _value.text
                : text // ignore: cast_nullable_to_non_nullable
                    as String,
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
        categoryId:
            freezed == categoryId
                ? _value.categoryId
                : categoryId // ignore: cast_nullable_to_non_nullable
                    as String?,
        sortOrder:
            null == sortOrder
                ? _value.sortOrder
                : sortOrder // ignore: cast_nullable_to_non_nullable
                    as int,
        status:
            null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                    as ManifestationStatus,
        backdropType:
            null == backdropType
                ? _value.backdropType
                : backdropType // ignore: cast_nullable_to_non_nullable
                    as BackdropType,
        themeId:
            null == themeId
                ? _value.themeId
                : themeId // ignore: cast_nullable_to_non_nullable
                    as String,
        imageUrl:
            freezed == imageUrl
                ? _value.imageUrl
                : imageUrl // ignore: cast_nullable_to_non_nullable
                    as String?,
        imagePrompt:
            freezed == imagePrompt
                ? _value.imagePrompt
                : imagePrompt // ignore: cast_nullable_to_non_nullable
                    as String?,
        imageStyle:
            freezed == imageStyle
                ? _value.imageStyle
                : imageStyle // ignore: cast_nullable_to_non_nullable
                    as String?,
        textVariant:
            null == textVariant
                ? _value.textVariant
                : textVariant // ignore: cast_nullable_to_non_nullable
                    as TextVariant,
        voiceUrl:
            freezed == voiceUrl
                ? _value.voiceUrl
                : voiceUrl // ignore: cast_nullable_to_non_nullable
                    as String?,
        soundId:
            freezed == soundId
                ? _value.soundId
                : soundId // ignore: cast_nullable_to_non_nullable
                    as String?,
        manifestedAt:
            freezed == manifestedAt
                ? _value.manifestedAt
                : manifestedAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ManifestationImpl implements _Manifestation {
  const _$ManifestationImpl({
    required this.id,
    required this.text,
    @JsonKey(name: 'user_id') required this.userId,
    @JsonKey(name: 'created_at') required this.createdAt,
    @JsonKey(name: 'updated_at') required this.updatedAt,
    @JsonKey(name: 'category_id') this.categoryId,
    @JsonKey(name: 'sort_order') this.sortOrder = 0,
    this.status = ManifestationStatus.active,
    @JsonKey(name: 'backdrop_type') this.backdropType = BackdropType.theme,
    @JsonKey(name: 'theme_id') this.themeId = 'chocolate',
    @JsonKey(name: 'image_url') this.imageUrl,
    @JsonKey(name: 'image_prompt') this.imagePrompt,
    @JsonKey(name: 'image_style') this.imageStyle,
    @JsonKey(name: 'text_variant') this.textVariant = TextVariant.regular,
    @JsonKey(name: 'voice_url') this.voiceUrl,
    @JsonKey(name: 'sound_id') this.soundId,
    @JsonKey(name: 'manifested_at') this.manifestedAt,
  });

  factory _$ManifestationImpl.fromJson(Map<String, dynamic> json) =>
      _$$ManifestationImplFromJson(json);

  @override
  final String id;
  @override
  final String text;
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
  @JsonKey(name: 'category_id')
  final String? categoryId;
  @override
  @JsonKey(name: 'sort_order')
  final int sortOrder;
  @override
  @JsonKey()
  final ManifestationStatus status;
  @override
  @JsonKey(name: 'backdrop_type')
  final BackdropType backdropType;
  @override
  @JsonKey(name: 'theme_id')
  final String themeId;
  @override
  @JsonKey(name: 'image_url')
  final String? imageUrl;
  @override
  @JsonKey(name: 'image_prompt')
  final String? imagePrompt;
  @override
  @JsonKey(name: 'image_style')
  final String? imageStyle;
  @override
  @JsonKey(name: 'text_variant')
  final TextVariant textVariant;
  @override
  @JsonKey(name: 'voice_url')
  final String? voiceUrl;
  @override
  @JsonKey(name: 'sound_id')
  final String? soundId;
  @override
  @JsonKey(name: 'manifested_at')
  final DateTime? manifestedAt;

  @override
  String toString() {
    return 'Manifestation(id: $id, text: $text, userId: $userId, createdAt: $createdAt, updatedAt: $updatedAt, categoryId: $categoryId, sortOrder: $sortOrder, status: $status, backdropType: $backdropType, themeId: $themeId, imageUrl: $imageUrl, imagePrompt: $imagePrompt, imageStyle: $imageStyle, textVariant: $textVariant, voiceUrl: $voiceUrl, soundId: $soundId, manifestedAt: $manifestedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ManifestationImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.text, text) || other.text == text) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId) &&
            (identical(other.sortOrder, sortOrder) ||
                other.sortOrder == sortOrder) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.backdropType, backdropType) ||
                other.backdropType == backdropType) &&
            (identical(other.themeId, themeId) || other.themeId == themeId) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.imagePrompt, imagePrompt) ||
                other.imagePrompt == imagePrompt) &&
            (identical(other.imageStyle, imageStyle) ||
                other.imageStyle == imageStyle) &&
            (identical(other.textVariant, textVariant) ||
                other.textVariant == textVariant) &&
            (identical(other.voiceUrl, voiceUrl) ||
                other.voiceUrl == voiceUrl) &&
            (identical(other.soundId, soundId) || other.soundId == soundId) &&
            (identical(other.manifestedAt, manifestedAt) ||
                other.manifestedAt == manifestedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    text,
    userId,
    createdAt,
    updatedAt,
    categoryId,
    sortOrder,
    status,
    backdropType,
    themeId,
    imageUrl,
    imagePrompt,
    imageStyle,
    textVariant,
    voiceUrl,
    soundId,
    manifestedAt,
  );

  /// Create a copy of Manifestation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ManifestationImplCopyWith<_$ManifestationImpl> get copyWith =>
      __$$ManifestationImplCopyWithImpl<_$ManifestationImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ManifestationImplToJson(this);
  }
}

abstract class _Manifestation implements Manifestation {
  const factory _Manifestation({
    required final String id,
    required final String text,
    @JsonKey(name: 'user_id') required final String userId,
    @JsonKey(name: 'created_at') required final DateTime createdAt,
    @JsonKey(name: 'updated_at') required final DateTime updatedAt,
    @JsonKey(name: 'category_id') final String? categoryId,
    @JsonKey(name: 'sort_order') final int sortOrder,
    final ManifestationStatus status,
    @JsonKey(name: 'backdrop_type') final BackdropType backdropType,
    @JsonKey(name: 'theme_id') final String themeId,
    @JsonKey(name: 'image_url') final String? imageUrl,
    @JsonKey(name: 'image_prompt') final String? imagePrompt,
    @JsonKey(name: 'image_style') final String? imageStyle,
    @JsonKey(name: 'text_variant') final TextVariant textVariant,
    @JsonKey(name: 'voice_url') final String? voiceUrl,
    @JsonKey(name: 'sound_id') final String? soundId,
    @JsonKey(name: 'manifested_at') final DateTime? manifestedAt,
  }) = _$ManifestationImpl;

  factory _Manifestation.fromJson(Map<String, dynamic> json) =
      _$ManifestationImpl.fromJson;

  @override
  String get id;
  @override
  String get text;
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
  @JsonKey(name: 'category_id')
  String? get categoryId;
  @override
  @JsonKey(name: 'sort_order')
  int get sortOrder;
  @override
  ManifestationStatus get status;
  @override
  @JsonKey(name: 'backdrop_type')
  BackdropType get backdropType;
  @override
  @JsonKey(name: 'theme_id')
  String get themeId;
  @override
  @JsonKey(name: 'image_url')
  String? get imageUrl;
  @override
  @JsonKey(name: 'image_prompt')
  String? get imagePrompt;
  @override
  @JsonKey(name: 'image_style')
  String? get imageStyle;
  @override
  @JsonKey(name: 'text_variant')
  TextVariant get textVariant;
  @override
  @JsonKey(name: 'voice_url')
  String? get voiceUrl;
  @override
  @JsonKey(name: 'sound_id')
  String? get soundId;
  @override
  @JsonKey(name: 'manifested_at')
  DateTime? get manifestedAt;

  /// Create a copy of Manifestation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ManifestationImplCopyWith<_$ManifestationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
