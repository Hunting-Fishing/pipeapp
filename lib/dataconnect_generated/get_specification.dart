part of 'generated.dart';

class GetSpecificationVariablesBuilder {
  String id;

  final FirebaseDataConnect _dataConnect;
  GetSpecificationVariablesBuilder(this._dataConnect, {required  this.id,});
  Deserializer<GetSpecificationData> dataDeserializer = (dynamic json)  => GetSpecificationData.fromJson(jsonDecode(json));
  Serializer<GetSpecificationVariables> varsSerializer = (GetSpecificationVariables vars) => jsonEncode(vars.toJson());
  Future<QueryResult<GetSpecificationData, GetSpecificationVariables>> execute({QueryFetchPolicy fetchPolicy = QueryFetchPolicy.preferCache}) {
    return ref().execute(fetchPolicy: fetchPolicy);
  }

  QueryRef<GetSpecificationData, GetSpecificationVariables> ref() {
    GetSpecificationVariables vars= GetSpecificationVariables(id: id,);
    return _dataConnect.query("GetSpecification", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class GetSpecificationSpecification {
  final String grade;
  final double outerDiameter;
  GetSpecificationSpecification.fromJson(dynamic json):
  
  grade = nativeFromJson<String>(json['grade']),
  outerDiameter = nativeFromJson<double>(json['outerDiameter']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetSpecificationSpecification otherTyped = other as GetSpecificationSpecification;
    return grade == otherTyped.grade && 
    outerDiameter == otherTyped.outerDiameter;
    
  }
  @override
  int get hashCode => Object.hashAll([grade.hashCode, outerDiameter.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['grade'] = nativeToJson<String>(grade);
    json['outerDiameter'] = nativeToJson<double>(outerDiameter);
    return json;
  }

  GetSpecificationSpecification({
    required this.grade,
    required this.outerDiameter,
  });
}

@immutable
class GetSpecificationData {
  final GetSpecificationSpecification? specification;
  GetSpecificationData.fromJson(dynamic json):
  
  specification = json['specification'] == null ? null : GetSpecificationSpecification.fromJson(json['specification']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetSpecificationData otherTyped = other as GetSpecificationData;
    return specification == otherTyped.specification;
    
  }
  @override
  int get hashCode => specification.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (specification != null) {
      json['specification'] = specification!.toJson();
    }
    return json;
  }

  GetSpecificationData({
    this.specification,
  });
}

@immutable
class GetSpecificationVariables {
  final String id;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  GetSpecificationVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetSpecificationVariables otherTyped = other as GetSpecificationVariables;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  GetSpecificationVariables({
    required this.id,
  });
}

