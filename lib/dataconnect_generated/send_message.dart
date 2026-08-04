part of 'generated.dart';

class SendMessageVariablesBuilder {
  String content;
  String equipmentId;

  final FirebaseDataConnect _dataConnect;
  SendMessageVariablesBuilder(this._dataConnect, {required  this.content,required  this.equipmentId,});
  Deserializer<SendMessageData> dataDeserializer = (dynamic json)  => SendMessageData.fromJson(jsonDecode(json));
  Serializer<SendMessageVariables> varsSerializer = (SendMessageVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<SendMessageData, SendMessageVariables>> execute() {
    return ref().execute();
  }

  MutationRef<SendMessageData, SendMessageVariables> ref() {
    SendMessageVariables vars= SendMessageVariables(content: content,equipmentId: equipmentId,);
    return _dataConnect.mutation("SendMessage", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class SendMessageMessageInsert {
  final String id;
  SendMessageMessageInsert.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final SendMessageMessageInsert otherTyped = other as SendMessageMessageInsert;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  SendMessageMessageInsert({
    required this.id,
  });
}

@immutable
class SendMessageData {
  final SendMessageMessageInsert message_insert;
  SendMessageData.fromJson(dynamic json):
  
  message_insert = SendMessageMessageInsert.fromJson(json['message_insert']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final SendMessageData otherTyped = other as SendMessageData;
    return message_insert == otherTyped.message_insert;
    
  }
  @override
  int get hashCode => message_insert.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['message_insert'] = message_insert.toJson();
    return json;
  }

  SendMessageData({
    required this.message_insert,
  });
}

@immutable
class SendMessageVariables {
  final String content;
  final String equipmentId;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  SendMessageVariables.fromJson(Map<String, dynamic> json):
  
  content = nativeFromJson<String>(json['content']),
  equipmentId = nativeFromJson<String>(json['equipmentId']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final SendMessageVariables otherTyped = other as SendMessageVariables;
    return content == otherTyped.content && 
    equipmentId == otherTyped.equipmentId;
    
  }
  @override
  int get hashCode => Object.hashAll([content.hashCode, equipmentId.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['content'] = nativeToJson<String>(content);
    json['equipmentId'] = nativeToJson<String>(equipmentId);
    return json;
  }

  SendMessageVariables({
    required this.content,
    required this.equipmentId,
  });
}

