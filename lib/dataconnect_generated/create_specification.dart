part of 'generated.dart';

class CreateSpecificationVariablesBuilder {
  double outerDiameter;
  double wallThickness;
  String grade;
  String threadType;
  String equipmentId;

  final FirebaseDataConnect _dataConnect;
  CreateSpecificationVariablesBuilder(this._dataConnect, {required  this.outerDiameter,required  this.wallThickness,required  this.grade,required  this.threadType,required  this.equipmentId,});
  Deserializer<CreateSpecificationData> dataDeserializer = (dynamic json)  => CreateSpecificationData.fromJson(jsonDecode(json));
  Serializer<CreateSpecificationVariables> varsSerializer = (CreateSpecificationVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<CreateSpecificationData, CreateSpecificationVariables>> execute() {
    return ref().execute();
  }

  MutationRef<CreateSpecificationData, CreateSpecificationVariables> ref() {
    CreateSpecificationVariables vars= CreateSpecificationVariables(outerDiameter: outerDiameter,wallThickness: wallThickness,grade: grade,threadType: threadType,equipmentId: equipmentId,);
    return _dataConnect.mutation("CreateSpecification", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class CreateSpecificationSpecificationInsert {
  final String id;
  CreateSpecificationSpecificationInsert.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateSpecificationSpecificationInsert otherTyped = other as CreateSpecificationSpecificationInsert;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  CreateSpecificationSpecificationInsert({
    required this.id,
  });
}

@immutable
class CreateSpecificationData {
  final CreateSpecificationSpecificationInsert specification_insert;
  CreateSpecificationData.fromJson(dynamic json):
  
  specification_insert = CreateSpecificationSpecificationInsert.fromJson(json['specification_insert']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateSpecificationData otherTyped = other as CreateSpecificationData;
    return specification_insert == otherTyped.specification_insert;
    
  }
  @override
  int get hashCode => specification_insert.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['specification_insert'] = specification_insert.toJson();
    return json;
  }

  CreateSpecificationData({
    required this.specification_insert,
  });
}

@immutable
class CreateSpecificationVariables {
  final double outerDiameter;
  final double wallThickness;
  final String grade;
  final String threadType;
  final String equipmentId;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  CreateSpecificationVariables.fromJson(Map<String, dynamic> json):
  
  outerDiameter = nativeFromJson<double>(json['outerDiameter']),
  wallThickness = nativeFromJson<double>(json['wallThickness']),
  grade = nativeFromJson<String>(json['grade']),
  threadType = nativeFromJson<String>(json['threadType']),
  equipmentId = nativeFromJson<String>(json['equipmentId']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateSpecificationVariables otherTyped = other as CreateSpecificationVariables;
    return outerDiameter == otherTyped.outerDiameter && 
    wallThickness == otherTyped.wallThickness && 
    grade == otherTyped.grade && 
    threadType == otherTyped.threadType && 
    equipmentId == otherTyped.equipmentId;
    
  }
  @override
  int get hashCode => Object.hashAll([outerDiameter.hashCode, wallThickness.hashCode, grade.hashCode, threadType.hashCode, equipmentId.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['outerDiameter'] = nativeToJson<double>(outerDiameter);
    json['wallThickness'] = nativeToJson<double>(wallThickness);
    json['grade'] = nativeToJson<String>(grade);
    json['threadType'] = nativeToJson<String>(threadType);
    json['equipmentId'] = nativeToJson<String>(equipmentId);
    return json;
  }

  CreateSpecificationVariables({
    required this.outerDiameter,
    required this.wallThickness,
    required this.grade,
    required this.threadType,
    required this.equipmentId,
  });
}

