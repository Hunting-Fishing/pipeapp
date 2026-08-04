part of 'generated.dart';

class UpdateEquipmentVariablesBuilder {
  String id;
  Optional<double> _price = Optional.optional(nativeFromJson, nativeToJson);

  final FirebaseDataConnect _dataConnect;  UpdateEquipmentVariablesBuilder price(double? t) {
   _price.value = t;
   return this;
  }

  UpdateEquipmentVariablesBuilder(this._dataConnect, {required  this.id,});
  Deserializer<UpdateEquipmentData> dataDeserializer = (dynamic json)  => UpdateEquipmentData.fromJson(jsonDecode(json));
  Serializer<UpdateEquipmentVariables> varsSerializer = (UpdateEquipmentVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<UpdateEquipmentData, UpdateEquipmentVariables>> execute() {
    return ref().execute();
  }

  MutationRef<UpdateEquipmentData, UpdateEquipmentVariables> ref() {
    UpdateEquipmentVariables vars= UpdateEquipmentVariables(id: id,price: _price,);
    return _dataConnect.mutation("UpdateEquipment", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class UpdateEquipmentEquipmentUpdate {
  final String id;
  UpdateEquipmentEquipmentUpdate.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateEquipmentEquipmentUpdate otherTyped = other as UpdateEquipmentEquipmentUpdate;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  UpdateEquipmentEquipmentUpdate({
    required this.id,
  });
}

@immutable
class UpdateEquipmentData {
  final UpdateEquipmentEquipmentUpdate? equipment_update;
  UpdateEquipmentData.fromJson(dynamic json):
  
  equipment_update = json['equipment_update'] == null ? null : UpdateEquipmentEquipmentUpdate.fromJson(json['equipment_update']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateEquipmentData otherTyped = other as UpdateEquipmentData;
    return equipment_update == otherTyped.equipment_update;
    
  }
  @override
  int get hashCode => equipment_update.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (equipment_update != null) {
      json['equipment_update'] = equipment_update!.toJson();
    }
    return json;
  }

  UpdateEquipmentData({
    this.equipment_update,
  });
}

@immutable
class UpdateEquipmentVariables {
  final String id;
  late final Optional<double>price;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  UpdateEquipmentVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']) {
  
  
  
    price = Optional.optional(nativeFromJson, nativeToJson);
    price.value = json['price'] == null ? null : nativeFromJson<double>(json['price']);
  
  }
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateEquipmentVariables otherTyped = other as UpdateEquipmentVariables;
    return id == otherTyped.id && 
    price == otherTyped.price;
    
  }
  @override
  int get hashCode => Object.hashAll([id.hashCode, price.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    if(price.state == OptionalState.set) {
      json['price'] = price.toJson();
    }
    return json;
  }

  UpdateEquipmentVariables({
    required this.id,
    required this.price,
  });
}

