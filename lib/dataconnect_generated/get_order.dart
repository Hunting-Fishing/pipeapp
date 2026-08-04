part of 'generated.dart';

class GetOrderVariablesBuilder {
  String id;

  final FirebaseDataConnect _dataConnect;
  GetOrderVariablesBuilder(this._dataConnect, {required  this.id,});
  Deserializer<GetOrderData> dataDeserializer = (dynamic json)  => GetOrderData.fromJson(jsonDecode(json));
  Serializer<GetOrderVariables> varsSerializer = (GetOrderVariables vars) => jsonEncode(vars.toJson());
  Future<QueryResult<GetOrderData, GetOrderVariables>> execute({QueryFetchPolicy fetchPolicy = QueryFetchPolicy.preferCache}) {
    return ref().execute(fetchPolicy: fetchPolicy);
  }

  QueryRef<GetOrderData, GetOrderVariables> ref() {
    GetOrderVariables vars= GetOrderVariables(id: id,);
    return _dataConnect.query("GetOrder", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class GetOrderOrder {
  final double totalPrice;
  final String status;
  GetOrderOrder.fromJson(dynamic json):
  
  totalPrice = nativeFromJson<double>(json['totalPrice']),
  status = nativeFromJson<String>(json['status']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetOrderOrder otherTyped = other as GetOrderOrder;
    return totalPrice == otherTyped.totalPrice && 
    status == otherTyped.status;
    
  }
  @override
  int get hashCode => Object.hashAll([totalPrice.hashCode, status.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['totalPrice'] = nativeToJson<double>(totalPrice);
    json['status'] = nativeToJson<String>(status);
    return json;
  }

  GetOrderOrder({
    required this.totalPrice,
    required this.status,
  });
}

@immutable
class GetOrderData {
  final GetOrderOrder? order;
  GetOrderData.fromJson(dynamic json):
  
  order = json['order'] == null ? null : GetOrderOrder.fromJson(json['order']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetOrderData otherTyped = other as GetOrderData;
    return order == otherTyped.order;
    
  }
  @override
  int get hashCode => order.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (order != null) {
      json['order'] = order!.toJson();
    }
    return json;
  }

  GetOrderData({
    this.order,
  });
}

@immutable
class GetOrderVariables {
  final String id;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  GetOrderVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetOrderVariables otherTyped = other as GetOrderVariables;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  GetOrderVariables({
    required this.id,
  });
}

