part of 'generated.dart';

class UpdateSpecificationVariablesBuilder {
  String id;
  Optional<double> _wallThickness = Optional.optional(nativeFromJson, nativeToJson);

  final FirebaseDataConnect _dataConnect;  UpdateSpecificationVariablesBuilder wallThickness(double? t) {
   _wallThickness.value = t;
   return this;
  }

  UpdateSpecificationVariablesBuilder(this._dataConnect, {required  this.id,});
  Deserializer<UpdateSpecificationData> dataDeserializer = (dynamic json)  => UpdateSpecificationData.fromJson(jsonDecode(json));
  Serializer<UpdateSpecificationVariables> varsSerializer = (UpdateSpecificationVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<UpdateSpecificationData, UpdateSpecificationVariables>> execute() {
    return ref().execute();
  }

  MutationRef<UpdateSpecificationData, UpdateSpecificationVariables> ref() {
    UpdateSpecificationVariables vars= UpdateSpecificationVariables(id: id,wallThickness: _wallThickness,);
    return _dataConnect.mutation("UpdateSpecification", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class UpdateSpecificationSpecificationUpdate {
  final String id;
  UpdateSpecificationSpecificationUpdate.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateSpecificationSpecificationUpdate otherTyped = other as UpdateSpecificationSpecificationUpdate;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  UpdateSpecificationSpecificationUpdate({
    required this.id,
  });
}

@immutable
class UpdateSpecificationData {
  final UpdateSpecificationSpecificationUpdate? specification_update;
  UpdateSpecificationData.fromJson(dynamic json):
  
  specification_update = json['specification_update'] == null ? null : UpdateSpecificationSpecificationUpdate.fromJson(json['specification_update']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateSpecificationData otherTyped = other as UpdateSpecificationData;
    return specification_update == otherTyped.specification_update;
    
  }
  @override
  int get hashCode => specification_update.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (specification_update != null) {
      json['specification_update'] = specification_update!.toJson();
    }
    return json;
  }

  UpdateSpecificationData({
    this.specification_update,
  });
}

@immutable
class UpdateSpecificationVariables {
  final String id;
  late final Optional<double>wallThickness;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  UpdateSpecificationVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']) {
  
  
  
    wallThickness = Optional.optional(nativeFromJson, nativeToJson);
    wallThickness.value = json['wallThickness'] == null ? null : nativeFromJson<double>(json['wallThickness']);
  
  }
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateSpecificationVariables otherTyped = other as UpdateSpecificationVariables;
    return id == otherTyped.id && 
    wallThickness == otherTyped.wallThickness;
    
  }
  @override
  int get hashCode => Object.hashAll([id.hashCode, wallThickness.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    if(wallThickness.state == OptionalState.set) {
      json['wallThickness'] = wallThickness.toJson();
    }
    return json;
  }

  UpdateSpecificationVariables({
    required this.id,
    required this.wallThickness,
  });
}

