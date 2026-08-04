part of 'generated.dart';

class DeleteSpecificationVariablesBuilder {
  String id;

  final FirebaseDataConnect _dataConnect;
  DeleteSpecificationVariablesBuilder(this._dataConnect, {required  this.id,});
  Deserializer<DeleteSpecificationData> dataDeserializer = (dynamic json)  => DeleteSpecificationData.fromJson(jsonDecode(json));
  Serializer<DeleteSpecificationVariables> varsSerializer = (DeleteSpecificationVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<DeleteSpecificationData, DeleteSpecificationVariables>> execute() {
    return ref().execute();
  }

  MutationRef<DeleteSpecificationData, DeleteSpecificationVariables> ref() {
    DeleteSpecificationVariables vars= DeleteSpecificationVariables(id: id,);
    return _dataConnect.mutation("DeleteSpecification", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class DeleteSpecificationSpecificationDelete {
  final String id;
  DeleteSpecificationSpecificationDelete.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteSpecificationSpecificationDelete otherTyped = other as DeleteSpecificationSpecificationDelete;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  DeleteSpecificationSpecificationDelete({
    required this.id,
  });
}

@immutable
class DeleteSpecificationData {
  final DeleteSpecificationSpecificationDelete? specification_delete;
  DeleteSpecificationData.fromJson(dynamic json):
  
  specification_delete = json['specification_delete'] == null ? null : DeleteSpecificationSpecificationDelete.fromJson(json['specification_delete']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteSpecificationData otherTyped = other as DeleteSpecificationData;
    return specification_delete == otherTyped.specification_delete;
    
  }
  @override
  int get hashCode => specification_delete.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (specification_delete != null) {
      json['specification_delete'] = specification_delete!.toJson();
    }
    return json;
  }

  DeleteSpecificationData({
    this.specification_delete,
  });
}

@immutable
class DeleteSpecificationVariables {
  final String id;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  DeleteSpecificationVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteSpecificationVariables otherTyped = other as DeleteSpecificationVariables;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  DeleteSpecificationVariables({
    required this.id,
  });
}

