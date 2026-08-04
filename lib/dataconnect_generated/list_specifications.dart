part of 'generated.dart';

class ListSpecificationsVariablesBuilder {
  
  final FirebaseDataConnect _dataConnect;
  ListSpecificationsVariablesBuilder(this._dataConnect, );
  Deserializer<ListSpecificationsData> dataDeserializer = (dynamic json)  => ListSpecificationsData.fromJson(jsonDecode(json));
  
  Future<QueryResult<ListSpecificationsData, void>> execute({QueryFetchPolicy fetchPolicy = QueryFetchPolicy.preferCache}) {
    return ref().execute(fetchPolicy: fetchPolicy);
  }

  QueryRef<ListSpecificationsData, void> ref() {
    
    return _dataConnect.query("ListSpecifications", dataDeserializer, emptySerializer, null);
  }
}

@immutable
class ListSpecificationsSpecifications {
  final String grade;
  final String threadType;
  ListSpecificationsSpecifications.fromJson(dynamic json):
  
  grade = nativeFromJson<String>(json['grade']),
  threadType = nativeFromJson<String>(json['threadType']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListSpecificationsSpecifications otherTyped = other as ListSpecificationsSpecifications;
    return grade == otherTyped.grade && 
    threadType == otherTyped.threadType;
    
  }
  @override
  int get hashCode => Object.hashAll([grade.hashCode, threadType.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['grade'] = nativeToJson<String>(grade);
    json['threadType'] = nativeToJson<String>(threadType);
    return json;
  }

  ListSpecificationsSpecifications({
    required this.grade,
    required this.threadType,
  });
}

@immutable
class ListSpecificationsData {
  final List<ListSpecificationsSpecifications> specifications;
  ListSpecificationsData.fromJson(dynamic json):
  
  specifications = (json['specifications'] as List<dynamic>)
        .map((e) => ListSpecificationsSpecifications.fromJson(e))
        .toList();
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListSpecificationsData otherTyped = other as ListSpecificationsData;
    return specifications == otherTyped.specifications;
    
  }
  @override
  int get hashCode => specifications.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['specifications'] = specifications.map((e) => e.toJson()).toList();
    return json;
  }

  ListSpecificationsData({
    required this.specifications,
  });
}

