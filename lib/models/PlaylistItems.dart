/*
* Copyright 2021 Amazon.com, Inc. or its affiliates. All Rights Reserved.
*
* Licensed under the Apache License, Version 2.0 (the "License").
* You may not use this file except in compliance with the License.
* A copy of the License is located at
*
*  http://aws.amazon.com/apache2.0
*
* or in the "license" file accompanying this file. This file is distributed
* on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
* express or implied. See the License for the specific language governing
* permissions and limitations under the License.
*/

// NOTE: This file is generated and may not follow lint rules defined in your app
// Generated files can be excluded from analysis in analysis_options.yaml
// For more info, see: https://dart.dev/guides/language/analysis-options#excluding-code-from-analysis

// ignore_for_file: public_member_api_docs, annotate_overrides, dead_code, dead_codepublic_member_api_docs, depend_on_referenced_packages, file_names, library_private_types_in_public_api, no_leading_underscores_for_library_prefixes, no_leading_underscores_for_local_identifiers, non_constant_identifier_names, null_check_on_nullable_type_parameter, override_on_non_overriding_member, prefer_adjacent_string_concatenation, prefer_const_constructors, prefer_if_null_operators, prefer_interpolation_to_compose_strings, slash_for_doc_comments, sort_child_properties_last, unnecessary_const, unnecessary_constructor_name, unnecessary_late, unnecessary_new, unnecessary_null_aware_assignments, unnecessary_nullable_for_final_variable_declarations, unnecessary_string_interpolations, use_build_context_synchronously

import 'ModelProvider.dart';
import 'package:amplify_core/amplify_core.dart' as amplify_core;

/** This is an auto generated class representing the PlaylistItems type in your schema. */
class PlaylistItems extends amplify_core.Model {
  static const classType = const _PlaylistItemsModelType();
  final String id;
  final String? _PlaylistID;
  final String? _SongID;
  final amplify_core.TemporalDateTime? _createdAt;
  final amplify_core.TemporalDateTime? _updatedAt;

  @override
  getInstanceType() => classType;

  @Deprecated(
      '[getId] is being deprecated in favor of custom primary key feature. Use getter [modelIdentifier] to get model identifier.')
  @override
  String getId() => id;

  PlaylistItemsModelIdentifier get modelIdentifier {
    return PlaylistItemsModelIdentifier(id: id);
  }

  String? get PlaylistID {
    return _PlaylistID;
  }

  String? get SongID {
    return _SongID;
  }

  amplify_core.TemporalDateTime? get createdAt {
    return _createdAt;
  }

  amplify_core.TemporalDateTime? get updatedAt {
    return _updatedAt;
  }

  const PlaylistItems._internal(
      {required this.id, PlaylistID, SongID, createdAt, updatedAt})
      : _PlaylistID = PlaylistID,
        _SongID = SongID,
        _createdAt = createdAt,
        _updatedAt = updatedAt;

  factory PlaylistItems({String? id, String? PlaylistID, String? SongID}) {
    return PlaylistItems._internal(
        id: id == null ? amplify_core.UUID.getUUID() : id,
        PlaylistID: PlaylistID,
        SongID: SongID);
  }

  bool equals(Object other) {
    return this == other;
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PlaylistItems &&
        id == other.id &&
        _PlaylistID == other._PlaylistID &&
        _SongID == other._SongID;
  }

  @override
  int get hashCode => toString().hashCode;

  @override
  String toString() {
    var buffer = new StringBuffer();

    buffer.write("PlaylistItems {");
    buffer.write("id=" + "$id" + ", ");
    buffer.write("PlaylistID=" + "$_PlaylistID" + ", ");
    buffer.write("SongID=" + "$_SongID" + ", ");
    buffer.write("createdAt=" +
        (_createdAt != null ? _createdAt.format() : "null") +
        ", ");
    buffer.write(
        "updatedAt=" + (_updatedAt != null ? _updatedAt.format() : "null"));
    buffer.write("}");

    return buffer.toString();
  }

  PlaylistItems copyWith({String? PlaylistID, String? SongID}) {
    return PlaylistItems._internal(
        id: id,
        PlaylistID: PlaylistID ?? this.PlaylistID,
        SongID: SongID ?? this.SongID);
  }

  PlaylistItems copyWithModelFieldValues(
      {ModelFieldValue<String?>? PlaylistID,
      ModelFieldValue<String?>? SongID}) {
    return PlaylistItems._internal(
        id: id,
        PlaylistID: PlaylistID == null ? this.PlaylistID : PlaylistID.value,
        SongID: SongID == null ? this.SongID : SongID.value);
  }

  PlaylistItems.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        _PlaylistID = json['PlaylistID'],
        _SongID = json['SongID'],
        _createdAt = json['createdAt'] != null
            ? amplify_core.TemporalDateTime.fromString(json['createdAt'])
            : null,
        _updatedAt = json['updatedAt'] != null
            ? amplify_core.TemporalDateTime.fromString(json['updatedAt'])
            : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'PlaylistID': _PlaylistID,
        'SongID': _SongID,
        'createdAt': _createdAt?.format(),
        'updatedAt': _updatedAt?.format()
      };

  Map<String, Object?> toMap() => {
        'id': id,
        'PlaylistID': _PlaylistID,
        'SongID': _SongID,
        'createdAt': _createdAt,
        'updatedAt': _updatedAt
      };

  static final amplify_core.QueryModelIdentifier<PlaylistItemsModelIdentifier>
      MODEL_IDENTIFIER =
      amplify_core.QueryModelIdentifier<PlaylistItemsModelIdentifier>();
  static final ID = amplify_core.QueryField(fieldName: "id");
  static final PLAYLISTID = amplify_core.QueryField(fieldName: "PlaylistID");
  static final SONGID = amplify_core.QueryField(fieldName: "SongID");
  static var schema = amplify_core.Model.defineSchema(
      define: (amplify_core.ModelSchemaDefinition modelSchemaDefinition) {
    modelSchemaDefinition.name = "PlaylistItems";
    modelSchemaDefinition.pluralName = "PlaylistItems";

    modelSchemaDefinition.authRules = [
      amplify_core.AuthRule(
          authStrategy: amplify_core.AuthStrategy.PRIVATE,
          operations: const [
            amplify_core.ModelOperation.CREATE,
            amplify_core.ModelOperation.UPDATE,
            amplify_core.ModelOperation.DELETE,
            amplify_core.ModelOperation.READ
          ])
    ];

    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.id());

    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
        key: PlaylistItems.PLAYLISTID,
        isRequired: false,
        ofType: amplify_core.ModelFieldType(
            amplify_core.ModelFieldTypeEnum.string)));

    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
        key: PlaylistItems.SONGID,
        isRequired: false,
        ofType: amplify_core.ModelFieldType(
            amplify_core.ModelFieldTypeEnum.string)));

    modelSchemaDefinition.addField(
        amplify_core.ModelFieldDefinition.nonQueryField(
            fieldName: 'createdAt',
            isRequired: false,
            isReadOnly: true,
            ofType: amplify_core.ModelFieldType(
                amplify_core.ModelFieldTypeEnum.dateTime)));

    modelSchemaDefinition.addField(
        amplify_core.ModelFieldDefinition.nonQueryField(
            fieldName: 'updatedAt',
            isRequired: false,
            isReadOnly: true,
            ofType: amplify_core.ModelFieldType(
                amplify_core.ModelFieldTypeEnum.dateTime)));
  });
}

class _PlaylistItemsModelType extends amplify_core.ModelType<PlaylistItems> {
  const _PlaylistItemsModelType();

  @override
  PlaylistItems fromJson(Map<String, dynamic> jsonData) {
    return PlaylistItems.fromJson(jsonData);
  }

  @override
  String modelName() {
    return 'PlaylistItems';
  }
}

/**
 * This is an auto generated class representing the model identifier
 * of [PlaylistItems] in your schema.
 */
class PlaylistItemsModelIdentifier
    implements amplify_core.ModelIdentifier<PlaylistItems> {
  final String id;

  /** Create an instance of PlaylistItemsModelIdentifier using [id] the primary key. */
  const PlaylistItemsModelIdentifier({required this.id});

  @override
  Map<String, dynamic> serializeAsMap() => (<String, dynamic>{'id': id});

  @override
  List<Map<String, dynamic>> serializeAsList() => serializeAsMap()
      .entries
      .map((entry) => (<String, dynamic>{entry.key: entry.value}))
      .toList();

  @override
  String serializeAsString() => serializeAsMap().values.join('#');

  @override
  String toString() => 'PlaylistItemsModelIdentifier(id: $id)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is PlaylistItemsModelIdentifier && id == other.id;
  }

  @override
  int get hashCode => id.hashCode;
}
