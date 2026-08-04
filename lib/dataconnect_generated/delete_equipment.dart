part of 'generated.dart';

class DeleteEquipmentVariablesBuilder {
  String id;

  final FirebaseDataConnect _dataConnect;
  DeleteEquipmentVariablesBuilder(this._dataConnect, {required  this.id,});
  Deserializer<DeleteEquipmentData> dataDeserializer = (dynamic json)  => DeleteEquipmentData.fromJson(jsonDecode(json));
  Serializer<DeleteEquipmentVariables> varsSerializer = (DeleteEquipmentVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<DeleteEquipmentData, DeleteEquipmentVariables>> execute() {
    return ref().execute();
  }

  MutationRef<DeleteEquipmentData, DeleteEquipmentVariables> ref() {
    DeleteEquipmentVariables vars= DeleteEquipmentVariables(id: id,);
    return _dataConnect.mutation("DeleteEquipment", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class DeleteEquipmentEquipmentDelete {
  final String id;
  DeleteEquipmentEquipmentDelete.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteEquipmentEquipmentDelete otherTyped = other as DeleteEquipmentEquipmentDelete;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  DeleteEquipmentEquipmentDelete({
    required this.id,
  });
}

@immutable
class DeleteEquipmentData {
  final DeleteEquipmentEquipmentDelete? equipment_delete;
  DeleteEquipmentData.fromJson(dynamic json):
  
  equipment_delete = json['equipment_delete'] == null ? null : DeleteEquipmentEquipmentDelete.fromJson(json['equipment_delete']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteEquipmentData otherTyped = other as DeleteEquipmentData;
    return equipment_delete == otherTyped.equipment_delete;
    
  }
  @override
  int get hashCode => equipment_delete.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (equipment_delete != null) {
      json['equipment_delete'] = equipment_delete!.toJson();
    }
    return json;
  }

  DeleteEquipmentData({
    this.equipment_delete,
  });
}

@immutable
class DeleteEquipmentVariables {
  final String id;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  DeleteEquipmentVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteEquipmentVariables otherTyped = other as DeleteEquipmentVariables;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  DeleteEquipmentVariables({
    required this.id,
  });
}

