part of 'generated.dart';

class UpdateOrderVariablesBuilder {
  String id;
  String status;

  final FirebaseDataConnect _dataConnect;
  UpdateOrderVariablesBuilder(this._dataConnect, {required  this.id,required  this.status,});
  Deserializer<UpdateOrderData> dataDeserializer = (dynamic json)  => UpdateOrderData.fromJson(jsonDecode(json));
  Serializer<UpdateOrderVariables> varsSerializer = (UpdateOrderVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<UpdateOrderData, UpdateOrderVariables>> execute() {
    return ref().execute();
  }

  MutationRef<UpdateOrderData, UpdateOrderVariables> ref() {
    UpdateOrderVariables vars= UpdateOrderVariables(id: id,status: status,);
    return _dataConnect.mutation("UpdateOrder", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class UpdateOrderOrderUpdate {
  final String id;
  UpdateOrderOrderUpdate.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateOrderOrderUpdate otherTyped = other as UpdateOrderOrderUpdate;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  UpdateOrderOrderUpdate({
    required this.id,
  });
}

@immutable
class UpdateOrderData {
  final UpdateOrderOrderUpdate? order_update;
  UpdateOrderData.fromJson(dynamic json):
  
  order_update = json['order_update'] == null ? null : UpdateOrderOrderUpdate.fromJson(json['order_update']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateOrderData otherTyped = other as UpdateOrderData;
    return order_update == otherTyped.order_update;
    
  }
  @override
  int get hashCode => order_update.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (order_update != null) {
      json['order_update'] = order_update!.toJson();
    }
    return json;
  }

  UpdateOrderData({
    this.order_update,
  });
}

@immutable
class UpdateOrderVariables {
  final String id;
  final String status;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  UpdateOrderVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']),
  status = nativeFromJson<String>(json['status']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateOrderVariables otherTyped = other as UpdateOrderVariables;
    return id == otherTyped.id && 
    status == otherTyped.status;
    
  }
  @override
  int get hashCode => Object.hashAll([id.hashCode, status.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    json['status'] = nativeToJson<String>(status);
    return json;
  }

  UpdateOrderVariables({
    required this.id,
    required this.status,
  });
}

