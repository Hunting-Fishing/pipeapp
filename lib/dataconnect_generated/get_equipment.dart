part of 'generated.dart';

class GetEquipmentVariablesBuilder {
  String id;

  final FirebaseDataConnect _dataConnect;
  GetEquipmentVariablesBuilder(this._dataConnect, {required  this.id,});
  Deserializer<GetEquipmentData> dataDeserializer = (dynamic json)  => GetEquipmentData.fromJson(jsonDecode(json));
  Serializer<GetEquipmentVariables> varsSerializer = (GetEquipmentVariables vars) => jsonEncode(vars.toJson());
  Future<QueryResult<GetEquipmentData, GetEquipmentVariables>> execute({QueryFetchPolicy fetchPolicy = QueryFetchPolicy.preferCache}) {
    return ref().execute(fetchPolicy: fetchPolicy);
  }

  QueryRef<GetEquipmentData, GetEquipmentVariables> ref() {
    GetEquipmentVariables vars= GetEquipmentVariables(id: id,);
    return _dataConnect.query("GetEquipment", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class GetEquipmentEquipment {
  final String title;
  final double price;
  final GetEquipmentEquipmentSeller seller;
  GetEquipmentEquipment.fromJson(dynamic json):
  
  title = nativeFromJson<String>(json['title']),
  price = nativeFromJson<double>(json['price']),
  seller = GetEquipmentEquipmentSeller.fromJson(json['seller']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetEquipmentEquipment otherTyped = other as GetEquipmentEquipment;
    return title == otherTyped.title && 
    price == otherTyped.price && 
    seller == otherTyped.seller;
    
  }
  @override
  int get hashCode => Object.hashAll([title.hashCode, price.hashCode, seller.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['title'] = nativeToJson<String>(title);
    json['price'] = nativeToJson<double>(price);
    json['seller'] = seller.toJson();
    return json;
  }

  GetEquipmentEquipment({
    required this.title,
    required this.price,
    required this.seller,
  });
}

@immutable
class GetEquipmentEquipmentSeller {
  final String companyName;
  GetEquipmentEquipmentSeller.fromJson(dynamic json):
  
  companyName = nativeFromJson<String>(json['companyName']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetEquipmentEquipmentSeller otherTyped = other as GetEquipmentEquipmentSeller;
    return companyName == otherTyped.companyName;
    
  }
  @override
  int get hashCode => companyName.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['companyName'] = nativeToJson<String>(companyName);
    return json;
  }

  GetEquipmentEquipmentSeller({
    required this.companyName,
  });
}

@immutable
class GetEquipmentData {
  final GetEquipmentEquipment? equipment;
  GetEquipmentData.fromJson(dynamic json):
  
  equipment = json['equipment'] == null ? null : GetEquipmentEquipment.fromJson(json['equipment']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetEquipmentData otherTyped = other as GetEquipmentData;
    return equipment == otherTyped.equipment;
    
  }
  @override
  int get hashCode => equipment.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (equipment != null) {
      json['equipment'] = equipment!.toJson();
    }
    return json;
  }

  GetEquipmentData({
    this.equipment,
  });
}

@immutable
class GetEquipmentVariables {
  final String id;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  GetEquipmentVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetEquipmentVariables otherTyped = other as GetEquipmentVariables;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  GetEquipmentVariables({
    required this.id,
  });
}

