part of 'generated.dart';

class UpdateUserVariablesBuilder {
  Optional<String> _companyName = Optional.optional(nativeFromJson, nativeToJson);
  Optional<String> _phoneNumber = Optional.optional(nativeFromJson, nativeToJson);

  final FirebaseDataConnect _dataConnect;
  UpdateUserVariablesBuilder companyName(String? t) {
   _companyName.value = t;
   return this;
  }
  UpdateUserVariablesBuilder phoneNumber(String? t) {
   _phoneNumber.value = t;
   return this;
  }

  UpdateUserVariablesBuilder(this._dataConnect, );
  Deserializer<UpdateUserData> dataDeserializer = (dynamic json)  => UpdateUserData.fromJson(jsonDecode(json));
  Serializer<UpdateUserVariables> varsSerializer = (UpdateUserVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<UpdateUserData, UpdateUserVariables>> execute() {
    return ref().execute();
  }

  MutationRef<UpdateUserData, UpdateUserVariables> ref() {
    UpdateUserVariables vars= UpdateUserVariables(companyName: _companyName,phoneNumber: _phoneNumber,);
    return _dataConnect.mutation("UpdateUser", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class UpdateUserUserUpdate {
  final String id;
  UpdateUserUserUpdate.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateUserUserUpdate otherTyped = other as UpdateUserUserUpdate;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  UpdateUserUserUpdate({
    required this.id,
  });
}

@immutable
class UpdateUserData {
  final UpdateUserUserUpdate? user_update;
  UpdateUserData.fromJson(dynamic json):
  
  user_update = json['user_update'] == null ? null : UpdateUserUserUpdate.fromJson(json['user_update']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateUserData otherTyped = other as UpdateUserData;
    return user_update == otherTyped.user_update;
    
  }
  @override
  int get hashCode => user_update.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (user_update != null) {
      json['user_update'] = user_update!.toJson();
    }
    return json;
  }

  UpdateUserData({
    this.user_update,
  });
}

@immutable
class UpdateUserVariables {
  late final Optional<String>companyName;
  late final Optional<String>phoneNumber;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  UpdateUserVariables.fromJson(Map<String, dynamic> json) {
  
  
    companyName = Optional.optional(nativeFromJson, nativeToJson);
    companyName.value = json['companyName'] == null ? null : nativeFromJson<String>(json['companyName']);
  
  
    phoneNumber = Optional.optional(nativeFromJson, nativeToJson);
    phoneNumber.value = json['phoneNumber'] == null ? null : nativeFromJson<String>(json['phoneNumber']);
  
  }
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateUserVariables otherTyped = other as UpdateUserVariables;
    return companyName == otherTyped.companyName && 
    phoneNumber == otherTyped.phoneNumber;
    
  }
  @override
  int get hashCode => Object.hashAll([companyName.hashCode, phoneNumber.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if(companyName.state == OptionalState.set) {
      json['companyName'] = companyName.toJson();
    }
    if(phoneNumber.state == OptionalState.set) {
      json['phoneNumber'] = phoneNumber.toJson();
    }
    return json;
  }

  UpdateUserVariables({
    required this.companyName,
    required this.phoneNumber,
  });
}

