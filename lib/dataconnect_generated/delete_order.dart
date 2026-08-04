part of 'generated.dart';

class DeleteOrderVariablesBuilder {
  String id;

  final FirebaseDataConnect _dataConnect;
  DeleteOrderVariablesBuilder(this._dataConnect, {required  this.id,});
  Deserializer<DeleteOrderData> dataDeserializer = (dynamic json)  => DeleteOrderData.fromJson(jsonDecode(json));
  Serializer<DeleteOrderVariables> varsSerializer = (DeleteOrderVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<DeleteOrderData, DeleteOrderVariables>> execute() {
    return ref().execute();
  }

  MutationRef<DeleteOrderData, DeleteOrderVariables> ref() {
    DeleteOrderVariables vars= DeleteOrderVariables(id: id,);
    return _dataConnect.mutation("DeleteOrder", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class DeleteOrderOrderDelete {
  final String id;
  DeleteOrderOrderDelete.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteOrderOrderDelete otherTyped = other as DeleteOrderOrderDelete;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  DeleteOrderOrderDelete({
    required this.id,
  });
}

@immutable
class DeleteOrderData {
  final DeleteOrderOrderDelete? order_delete;
  DeleteOrderData.fromJson(dynamic json):
  
  order_delete = json['order_delete'] == null ? null : DeleteOrderOrderDelete.fromJson(json['order_delete']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteOrderData otherTyped = other as DeleteOrderData;
    return order_delete == otherTyped.order_delete;
    
  }
  @override
  int get hashCode => order_delete.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (order_delete != null) {
      json['order_delete'] = order_delete!.toJson();
    }
    return json;
  }

  DeleteOrderData({
    this.order_delete,
  });
}

@immutable
class DeleteOrderVariables {
  final String id;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  DeleteOrderVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteOrderVariables otherTyped = other as DeleteOrderVariables;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  DeleteOrderVariables({
    required this.id,
  });
}

