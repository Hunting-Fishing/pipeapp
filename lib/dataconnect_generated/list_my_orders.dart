part of 'generated.dart';

class ListMyOrdersVariablesBuilder {
  
  final FirebaseDataConnect _dataConnect;
  ListMyOrdersVariablesBuilder(this._dataConnect, );
  Deserializer<ListMyOrdersData> dataDeserializer = (dynamic json)  => ListMyOrdersData.fromJson(jsonDecode(json));
  
  Future<QueryResult<ListMyOrdersData, void>> execute({QueryFetchPolicy fetchPolicy = QueryFetchPolicy.preferCache}) {
    return ref().execute(fetchPolicy: fetchPolicy);
  }

  QueryRef<ListMyOrdersData, void> ref() {
    
    return _dataConnect.query("ListMyOrders", dataDeserializer, emptySerializer, null);
  }
}

@immutable
class ListMyOrdersOrders {
  final double totalPrice;
  final String status;
  ListMyOrdersOrders.fromJson(dynamic json):
  
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

    final ListMyOrdersOrders otherTyped = other as ListMyOrdersOrders;
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

  ListMyOrdersOrders({
    required this.totalPrice,
    required this.status,
  });
}

@immutable
class ListMyOrdersData {
  final List<ListMyOrdersOrders> orders;
  ListMyOrdersData.fromJson(dynamic json):
  
  orders = (json['orders'] as List<dynamic>)
        .map((e) => ListMyOrdersOrders.fromJson(e))
        .toList();
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListMyOrdersData otherTyped = other as ListMyOrdersData;
    return orders == otherTyped.orders;
    
  }
  @override
  int get hashCode => orders.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['orders'] = orders.map((e) => e.toJson()).toList();
    return json;
  }

  ListMyOrdersData({
    required this.orders,
  });
}

