part of 'generated.dart';

class ListEquipmentsVariablesBuilder {
  
  final FirebaseDataConnect _dataConnect;
  ListEquipmentsVariablesBuilder(this._dataConnect, );
  Deserializer<ListEquipmentsData> dataDeserializer = (dynamic json)  => ListEquipmentsData.fromJson(jsonDecode(json));
  
  Future<QueryResult<ListEquipmentsData, void>> execute({QueryFetchPolicy fetchPolicy = QueryFetchPolicy.preferCache}) {
    return ref().execute(fetchPolicy: fetchPolicy);
  }

  QueryRef<ListEquipmentsData, void> ref() {
    
    return _dataConnect.query("ListEquipments", dataDeserializer, emptySerializer, null);
  }
}

@immutable
class ListEquipmentsEquipments {
  final String title;
  final String category;
  ListEquipmentsEquipments.fromJson(dynamic json):
  
  title = nativeFromJson<String>(json['title']),
  category = nativeFromJson<String>(json['category']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListEquipmentsEquipments otherTyped = other as ListEquipmentsEquipments;
    return title == otherTyped.title && 
    category == otherTyped.category;
    
  }
  @override
  int get hashCode => Object.hashAll([title.hashCode, category.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['title'] = nativeToJson<String>(title);
    json['category'] = nativeToJson<String>(category);
    return json;
  }

  ListEquipmentsEquipments({
    required this.title,
    required this.category,
  });
}

@immutable
class ListEquipmentsData {
  final List<ListEquipmentsEquipments> equipments;
  ListEquipmentsData.fromJson(dynamic json):
  
  equipments = (json['equipments'] as List<dynamic>)
        .map((e) => ListEquipmentsEquipments.fromJson(e))
        .toList();
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListEquipmentsData otherTyped = other as ListEquipmentsData;
    return equipments == otherTyped.equipments;
    
  }
  @override
  int get hashCode => equipments.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['equipments'] = equipments.map((e) => e.toJson()).toList();
    return json;
  }

  ListEquipmentsData({
    required this.equipments,
  });
}

