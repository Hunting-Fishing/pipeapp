part of 'generated.dart';

class DeleteMessageVariablesBuilder {
  String id;

  final FirebaseDataConnect _dataConnect;
  DeleteMessageVariablesBuilder(this._dataConnect, {required  this.id,});
  Deserializer<DeleteMessageData> dataDeserializer = (dynamic json)  => DeleteMessageData.fromJson(jsonDecode(json));
  Serializer<DeleteMessageVariables> varsSerializer = (DeleteMessageVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<DeleteMessageData, DeleteMessageVariables>> execute() {
    return ref().execute();
  }

  MutationRef<DeleteMessageData, DeleteMessageVariables> ref() {
    DeleteMessageVariables vars= DeleteMessageVariables(id: id,);
    return _dataConnect.mutation("DeleteMessage", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class DeleteMessageMessageDelete {
  final String id;
  DeleteMessageMessageDelete.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteMessageMessageDelete otherTyped = other as DeleteMessageMessageDelete;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  DeleteMessageMessageDelete({
    required this.id,
  });
}

@immutable
class DeleteMessageData {
  final DeleteMessageMessageDelete? message_delete;
  DeleteMessageData.fromJson(dynamic json):
  
  message_delete = json['message_delete'] == null ? null : DeleteMessageMessageDelete.fromJson(json['message_delete']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteMessageData otherTyped = other as DeleteMessageData;
    return message_delete == otherTyped.message_delete;
    
  }
  @override
  int get hashCode => message_delete.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (message_delete != null) {
      json['message_delete'] = message_delete!.toJson();
    }
    return json;
  }

  DeleteMessageData({
    this.message_delete,
  });
}

@immutable
class DeleteMessageVariables {
  final String id;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  DeleteMessageVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteMessageVariables otherTyped = other as DeleteMessageVariables;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  DeleteMessageVariables({
    required this.id,
  });
}

