part of 'generated.dart';

class GetEquipmentMessagesVariablesBuilder {
  String equipmentId;

  final FirebaseDataConnect _dataConnect;
  GetEquipmentMessagesVariablesBuilder(this._dataConnect, {required  this.equipmentId,});
  Deserializer<GetEquipmentMessagesData> dataDeserializer = (dynamic json)  => GetEquipmentMessagesData.fromJson(jsonDecode(json));
  Serializer<GetEquipmentMessagesVariables> varsSerializer = (GetEquipmentMessagesVariables vars) => jsonEncode(vars.toJson());
  Future<QueryResult<GetEquipmentMessagesData, GetEquipmentMessagesVariables>> execute({QueryFetchPolicy fetchPolicy = QueryFetchPolicy.preferCache}) {
    return ref().execute(fetchPolicy: fetchPolicy);
  }

  QueryRef<GetEquipmentMessagesData, GetEquipmentMessagesVariables> ref() {
    GetEquipmentMessagesVariables vars= GetEquipmentMessagesVariables(equipmentId: equipmentId,);
    return _dataConnect.query("GetEquipmentMessages", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class GetEquipmentMessagesMessages {
  final String content;
  final GetEquipmentMessagesMessagesSender sender;
  GetEquipmentMessagesMessages.fromJson(dynamic json):
  
  content = nativeFromJson<String>(json['content']),
  sender = GetEquipmentMessagesMessagesSender.fromJson(json['sender']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetEquipmentMessagesMessages otherTyped = other as GetEquipmentMessagesMessages;
    return content == otherTyped.content && 
    sender == otherTyped.sender;
    
  }
  @override
  int get hashCode => Object.hashAll([content.hashCode, sender.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['content'] = nativeToJson<String>(content);
    json['sender'] = sender.toJson();
    return json;
  }

  GetEquipmentMessagesMessages({
    required this.content,
    required this.sender,
  });
}

@immutable
class GetEquipmentMessagesMessagesSender {
  final String companyName;
  GetEquipmentMessagesMessagesSender.fromJson(dynamic json):
  
  companyName = nativeFromJson<String>(json['companyName']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetEquipmentMessagesMessagesSender otherTyped = other as GetEquipmentMessagesMessagesSender;
    return companyName == otherTyped.companyName;
    
  }
  @override
  int get hashCode => companyName.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['companyName'] = nativeToJson<String>(companyName);
    return json;
  }

  GetEquipmentMessagesMessagesSender({
    required this.companyName,
  });
}

@immutable
class GetEquipmentMessagesData {
  final List<GetEquipmentMessagesMessages> messages;
  GetEquipmentMessagesData.fromJson(dynamic json):
  
  messages = (json['messages'] as List<dynamic>)
        .map((e) => GetEquipmentMessagesMessages.fromJson(e))
        .toList();
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetEquipmentMessagesData otherTyped = other as GetEquipmentMessagesData;
    return messages == otherTyped.messages;
    
  }
  @override
  int get hashCode => messages.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['messages'] = messages.map((e) => e.toJson()).toList();
    return json;
  }

  GetEquipmentMessagesData({
    required this.messages,
  });
}

@immutable
class GetEquipmentMessagesVariables {
  final String equipmentId;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  GetEquipmentMessagesVariables.fromJson(Map<String, dynamic> json):
  
  equipmentId = nativeFromJson<String>(json['equipmentId']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetEquipmentMessagesVariables otherTyped = other as GetEquipmentMessagesVariables;
    return equipmentId == otherTyped.equipmentId;
    
  }
  @override
  int get hashCode => equipmentId.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['equipmentId'] = nativeToJson<String>(equipmentId);
    return json;
  }

  GetEquipmentMessagesVariables({
    required this.equipmentId,
  });
}

