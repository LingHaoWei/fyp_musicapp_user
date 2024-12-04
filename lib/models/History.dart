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

/** This is an auto generated class representing the History type in your schema. */
class History extends amplify_core.Model {
  static const classType = const _HistoryModelType();
  final String id;
  final String? _songID;
  final String? _userID;
  final amplify_core.TemporalDateTime? _createdAt;
  final amplify_core.TemporalDateTime? _updatedAt;

  @override
  getInstanceType() => classType;

  @Deprecated(
      '[getId] is being deprecated in favor of custom primary key feature. Use getter [modelIdentifier] to get model identifier.')
  @override
  String getId() => id;

  HistoryModelIdentifier get modelIdentifier {
    return HistoryModelIdentifier(id: id);
  }

  String? get songID {
    return _songID;
  }

  String? get userID {
    return _userID;
  }

  amplify_core.TemporalDateTime? get createdAt {
    return _createdAt;
  }

  amplify_core.TemporalDateTime? get updatedAt {
    return _updatedAt;
  }

  const History._internal(
      {required this.id, songID, userID, createdAt, updatedAt})
      : _songID = songID,
        _userID = userID,
        _createdAt = createdAt,
        _updatedAt = updatedAt;

  factory History({String? id, String? songID, String? userID}) {
    return History._internal(
        id: id == null ? amplify_core.UUID.getUUID() : id,
        songID: songID,
        userID: userID);
  }

  bool equals(Object other) {
    return this == other;
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is History &&
        id == other.id &&
        _songID == other._songID &&
        _userID == other._userID;
  }

  @override
  int get hashCode => toString().hashCode;

  @override
  String toString() {
    var buffer = new StringBuffer();

    buffer.write("History {");
    buffer.write("id=" + "$id" + ", ");
    buffer.write("songID=" + "$_songID" + ", ");
    buffer.write("userID=" + "$_userID" + ", ");
    buffer.write("createdAt=" +
        (_createdAt != null ? _createdAt.format() : "null") +
        ", ");
    buffer.write(
        "updatedAt=" + (_updatedAt != null ? _updatedAt.format() : "null"));
    buffer.write("}");

    return buffer.toString();
  }

  History copyWith({String? songID, String? userID}) {
    return History._internal(
        id: id, songID: songID ?? this.songID, userID: userID ?? this.userID);
  }

  History copyWithModelFieldValues(
      {ModelFieldValue<String?>? songID, ModelFieldValue<String?>? userID}) {
    return History._internal(
        id: id,
        songID: songID == null ? this.songID : songID.value,
        userID: userID == null ? this.userID : userID.value);
  }

  History.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        _songID = json['songID'],
        _userID = json['userID'],
        _createdAt = json['createdAt'] != null
            ? amplify_core.TemporalDateTime.fromString(json['createdAt'])
            : null,
        _updatedAt = json['updatedAt'] != null
            ? amplify_core.TemporalDateTime.fromString(json['updatedAt'])
            : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'songID': _songID,
        'userID': _userID,
        'createdAt': _createdAt?.format(),
        'updatedAt': _updatedAt?.format()
      };

  Map<String, Object?> toMap() => {
        'id': id,
        'songID': _songID,
        'userID': _userID,
        'createdAt': _createdAt,
        'updatedAt': _updatedAt
      };

  static final amplify_core.QueryModelIdentifier<HistoryModelIdentifier>
      MODEL_IDENTIFIER =
      amplify_core.QueryModelIdentifier<HistoryModelIdentifier>();
  static final ID = amplify_core.QueryField(fieldName: "id");
  static final SONGID = amplify_core.QueryField(fieldName: "songID");
  static final USERID = amplify_core.QueryField(fieldName: "userID");
  static var schema = amplify_core.Model.defineSchema(
      define: (amplify_core.ModelSchemaDefinition modelSchemaDefinition) {
    modelSchemaDefinition.name = "History";
    modelSchemaDefinition.pluralName = "Histories";

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
        key: History.SONGID,
        isRequired: false,
        ofType: amplify_core.ModelFieldType(
            amplify_core.ModelFieldTypeEnum.string)));

    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
        key: History.USERID,
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

class _HistoryModelType extends amplify_core.ModelType<History> {
  const _HistoryModelType();

  @override
  History fromJson(Map<String, dynamic> jsonData) {
    return History.fromJson(jsonData);
  }

  @override
  String modelName() {
    return 'History';
  }
}

/**
 * This is an auto generated class representing the model identifier
 * of [History] in your schema.
 */
class HistoryModelIdentifier implements amplify_core.ModelIdentifier<History> {
  final String id;

  /** Create an instance of HistoryModelIdentifier using [id] the primary key. */
  const HistoryModelIdentifier({required this.id});

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
  String toString() => 'HistoryModelIdentifier(id: $id)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is HistoryModelIdentifier && id == other.id;
  }

  @override
  int get hashCode => id.hashCode;
}
