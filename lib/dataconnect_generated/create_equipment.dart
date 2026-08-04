part of 'generated.dart';

class CreateEquipmentVariablesBuilder {
  String title;
  String category;
  double price;
  String status;
  Optional<String> _description = Optional.optional(nativeFromJson, nativeToJson);
  Optional<String> _location = Optional.optional(nativeFromJson, nativeToJson);

  final FirebaseDataConnect _dataConnect;  CreateEquipmentVariablesBuilder description(String? t) {
   _description.value = t;
   return this;
  }
  CreateEquipmentVariablesBuilder location(String? t) {
   _location.value = t;
   return this;
  }

  CreateEquipmentVariablesBuilder(this._dataConnect, {required  this.title,required  this.category,required  this.price,required  this.status,});
  Deserializer<CreateEquipmentData> dataDeserializer = (dynamic json)  => CreateEquipmentData.fromJson(jsonDecode(json));
  Serializer<CreateEquipmentVariables> varsSerializer = (CreateEquipmentVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<CreateEquipmentData, CreateEquipmentVariables>> execute() {
    return ref().execute();
  }

  MutationRef<CreateEquipmentData, CreateEquipmentVariables> ref() {
    CreateEquipmentVariables vars= CreateEquipmentVariables(title: title,category: category,price: price,status: status,description: _description,location: _location,);
    return _dataConnect.mutation("CreateEquipment", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class CreateEquipmentEquipmentInsert {
  final String id;
  CreateEquipmentEquipmentInsert.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateEquipmentEquipmentInsert otherTyped = other as CreateEquipmentEquipmentInsert;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  CreateEquipmentEquipmentInsert({
    required this.id,
  });
}

@immutable
class CreateEquipmentData {
  final CreateEquipmentEquipmentInsert equipment_insert;
  CreateEquipmentData.fromJson(dynamic json):
  
  equipment_insert = CreateEquipmentEquipmentInsert.fromJson(json['equipment_insert']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateEquipmentData otherTyped = other as CreateEquipmentData;
    return equipment_insert == otherTyped.equipment_insert;
    
  }
  @override
  int get hashCode => equipment_insert.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['equipment_insert'] = equipment_insert.toJson();
    return json;
  }

  CreateEquipmentData({
    required this.equipment_insert,
  });
}

@immutable
class CreateEquipmentVariables {
  final String title;
  final String category;
  final double price;
  final String status;
  late final Optional<String>description;
  late final Optional<String>location;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  CreateEquipmentVariables.fromJson(Map<String, dynamic> json):
  
  title = nativeFromJson<String>(json['title']),
  category = nativeFromJson<String>(json['category']),
  price = nativeFromJson<double>(json['price']),
  status = nativeFromJson<String>(json['status']) {
  
  
  
  
  
  
    description = Optional.optional(nativeFromJson, nativeToJson);
    description.value = json['description'] == null ? null : nativeFromJson<String>(json['description']);
  
  
    location = Optional.optional(nativeFromJson, nativeToJson);
    location.value = json['location'] == null ? null : nativeFromJson<String>(json['location']);
  
  }
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateEquipmentVariables otherTyped = other as CreateEquipmentVariables;
    return title == otherTyped.title && 
    category == otherTyped.category && 
    price == otherTyped.price && 
    status == otherTyped.status && 
    description == otherTyped.description && 
    location == otherTyped.location;
    
  }
  @override
  int get hashCode => Object.hashAll([title.hashCode, category.hashCode, price.hashCode, status.hashCode, description.hashCode, location.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['title'] = nativeToJson<String>(title);
    json['category'] = nativeToJson<String>(category);
    json['price'] = nativeToJson<double>(price);
    json['status'] = nativeToJson<String>(status);
    if(description.state == OptionalState.set) {
      json['description'] = description.toJson();
    }
    if(location.state == OptionalState.set) {
      json['location'] = location.toJson();
    }
    return json;
  }

  CreateEquipmentVariables({
    required this.title,
    required this.category,
    required this.price,
    required this.status,
    required this.description,
    required this.location,
  });
}

