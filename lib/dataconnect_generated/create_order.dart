part of 'generated.dart';

class CreateOrderVariablesBuilder {
  double totalPrice;
  String status;
  String equipmentId;

  final FirebaseDataConnect _dataConnect;
  CreateOrderVariablesBuilder(this._dataConnect, {required  this.totalPrice,required  this.status,required  this.equipmentId,});
  Deserializer<CreateOrderData> dataDeserializer = (dynamic json)  => CreateOrderData.fromJson(jsonDecode(json));
  Serializer<CreateOrderVariables> varsSerializer = (CreateOrderVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<CreateOrderData, CreateOrderVariables>> execute() {
    return ref().execute();
  }

  MutationRef<CreateOrderData, CreateOrderVariables> ref() {
    CreateOrderVariables vars= CreateOrderVariables(totalPrice: totalPrice,status: status,equipmentId: equipmentId,);
    return _dataConnect.mutation("CreateOrder", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class CreateOrderOrderInsert {
  final String id;
  CreateOrderOrderInsert.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateOrderOrderInsert otherTyped = other as CreateOrderOrderInsert;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  CreateOrderOrderInsert({
    required this.id,
  });
}

@immutable
class CreateOrderData {
  final CreateOrderOrderInsert order_insert;
  CreateOrderData.fromJson(dynamic json):
  
  order_insert = CreateOrderOrderInsert.fromJson(json['order_insert']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateOrderData otherTyped = other as CreateOrderData;
    return order_insert == otherTyped.order_insert;
    
  }
  @override
  int get hashCode => order_insert.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['order_insert'] = order_insert.toJson();
    return json;
  }

  CreateOrderData({
    required this.order_insert,
  });
}

@immutable
class CreateOrderVariables {
  final double totalPrice;
  final String status;
  final String equipmentId;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  CreateOrderVariables.fromJson(Map<String, dynamic> json):
  
  totalPrice = nativeFromJson<double>(json['totalPrice']),
  status = nativeFromJson<String>(json['status']),
  equipmentId = nativeFromJson<String>(json['equipmentId']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateOrderVariables otherTyped = other as CreateOrderVariables;
    return totalPrice == otherTyped.totalPrice && 
    status == otherTyped.status && 
    equipmentId == otherTyped.equipmentId;
    
  }
  @override
  int get hashCode => Object.hashAll([totalPrice.hashCode, status.hashCode, equipmentId.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['totalPrice'] = nativeToJson<double>(totalPrice);
    json['status'] = nativeToJson<String>(status);
    json['equipmentId'] = nativeToJson<String>(equipmentId);
    return json;
  }

  CreateOrderVariables({
    required this.totalPrice,
    required this.status,
    required this.equipmentId,
  });
}

