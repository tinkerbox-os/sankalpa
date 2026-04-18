// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'soundscape.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Soundscape _$SoundscapeFromJson(Map<String, dynamic> json) {
  return _Soundscape.fromJson(json);
}

/// @nodoc
mixin _$Soundscape {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get url => throw _privateConstructorUsedError;
  SoundscapeKind get kind => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_system')
  bool get isSystem => throw _privateConstructorUsedError;
  @JsonKey(name: 'user_id')
  String? get userId => throw _privateConstructorUsedError;

  /// Serializes this Soundscape to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Soundscape
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SoundscapeCopyWith<Soundscape> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SoundscapeCopyWith<$Res> {
  factory $SoundscapeCopyWith(
    Soundscape value,
    $Res Function(Soundscape) then,
  ) = _$SoundscapeCopyWithImpl<$Res, Soundscape>;
  @useResult
  $Res call({
    String id,
    String name,
    String url,
    SoundscapeKind kind,
    @JsonKey(name: 'is_system') bool isSystem,
    @JsonKey(name: 'user_id') String? userId,
  });
}

/// @nodoc
class _$SoundscapeCopyWithImpl<$Res, $Val extends Soundscape>
    implements $SoundscapeCopyWith<$Res> {
  _$SoundscapeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Soundscape
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? url = null,
    Object? kind = null,
    Object? isSystem = null,
    Object? userId = freezed,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            name:
                null == name
                    ? _value.name
                    : name // ignore: cast_nullable_to_non_nullable
                        as String,
            url:
                null == url
                    ? _value.url
                    : url // ignore: cast_nullable_to_non_nullable
                        as String,
            kind:
                null == kind
                    ? _value.kind
                    : kind // ignore: cast_nullable_to_non_nullable
                        as SoundscapeKind,
            isSystem:
                null == isSystem
                    ? _value.isSystem
                    : isSystem // ignore: cast_nullable_to_non_nullable
                        as bool,
            userId:
                freezed == userId
                    ? _value.userId
                    : userId // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SoundscapeImplCopyWith<$Res>
    implements $SoundscapeCopyWith<$Res> {
  factory _$$SoundscapeImplCopyWith(
    _$SoundscapeImpl value,
    $Res Function(_$SoundscapeImpl) then,
  ) = __$$SoundscapeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    String url,
    SoundscapeKind kind,
    @JsonKey(name: 'is_system') bool isSystem,
    @JsonKey(name: 'user_id') String? userId,
  });
}

/// @nodoc
class __$$SoundscapeImplCopyWithImpl<$Res>
    extends _$SoundscapeCopyWithImpl<$Res, _$SoundscapeImpl>
    implements _$$SoundscapeImplCopyWith<$Res> {
  __$$SoundscapeImplCopyWithImpl(
    _$SoundscapeImpl _value,
    $Res Function(_$SoundscapeImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Soundscape
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? url = null,
    Object? kind = null,
    Object? isSystem = null,
    Object? userId = freezed,
  }) {
    return _then(
      _$SoundscapeImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        name:
            null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                    as String,
        url:
            null == url
                ? _value.url
                : url // ignore: cast_nullable_to_non_nullable
                    as String,
        kind:
            null == kind
                ? _value.kind
                : kind // ignore: cast_nullable_to_non_nullable
                    as SoundscapeKind,
        isSystem:
            null == isSystem
                ? _value.isSystem
                : isSystem // ignore: cast_nullable_to_non_nullable
                    as bool,
        userId:
            freezed == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SoundscapeImpl implements _Soundscape {
  const _$SoundscapeImpl({
    required this.id,
    required this.name,
    required this.url,
    required this.kind,
    @JsonKey(name: 'is_system') this.isSystem = false,
    @JsonKey(name: 'user_id') this.userId,
  });

  factory _$SoundscapeImpl.fromJson(Map<String, dynamic> json) =>
      _$$SoundscapeImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String url;
  @override
  final SoundscapeKind kind;
  @override
  @JsonKey(name: 'is_system')
  final bool isSystem;
  @override
  @JsonKey(name: 'user_id')
  final String? userId;

  @override
  String toString() {
    return 'Soundscape(id: $id, name: $name, url: $url, kind: $kind, isSystem: $isSystem, userId: $userId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SoundscapeImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.kind, kind) || other.kind == kind) &&
            (identical(other.isSystem, isSystem) ||
                other.isSystem == isSystem) &&
            (identical(other.userId, userId) || other.userId == userId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, name, url, kind, isSystem, userId);

  /// Create a copy of Soundscape
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SoundscapeImplCopyWith<_$SoundscapeImpl> get copyWith =>
      __$$SoundscapeImplCopyWithImpl<_$SoundscapeImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SoundscapeImplToJson(this);
  }
}

abstract class _Soundscape implements Soundscape {
  const factory _Soundscape({
    required final String id,
    required final String name,
    required final String url,
    required final SoundscapeKind kind,
    @JsonKey(name: 'is_system') final bool isSystem,
    @JsonKey(name: 'user_id') final String? userId,
  }) = _$SoundscapeImpl;

  factory _Soundscape.fromJson(Map<String, dynamic> json) =
      _$SoundscapeImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get url;
  @override
  SoundscapeKind get kind;
  @override
  @JsonKey(name: 'is_system')
  bool get isSystem;
  @override
  @JsonKey(name: 'user_id')
  String? get userId;

  /// Create a copy of Soundscape
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SoundscapeImplCopyWith<_$SoundscapeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
