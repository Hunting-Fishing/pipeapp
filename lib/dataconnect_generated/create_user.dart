part of 'generated.dart';

class CreateUserVariablesBuilder {
  String companyName;
  String email;
  String userRole;
  Optional<String> _phoneNumber = Optional.optional(nativeFromJson, nativeToJson);
  Optional<double> _rating = Optional.optional(nativeFromJson, nativeToJson);

  final FirebaseDataConnect _dataConnect;  CreateUserVariablesBuilder phoneNumber(String? t) {
   _phoneNumber.value = t;
   return this;
  }
  CreateUserVariablesBuilder rating(double? t) {
   _rating.value = t;
   return this;
  }

  CreateUserVariablesBuilder(this._dataConnect, {required  this.companyName,required  this.email,required  this.userRole,});
  Deserializer<CreateUserData> dataDeserializer = (dynamic json)  => CreateUserData.fromJson(jsonDecode(json));
  Serializer<CreateUserVariables> varsSerializer = (CreateUserVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<CreateUserData, CreateUserVariables>> execute() {
    return ref().execute();
  }

  MutationRef<CreateUserData, CreateUserVariables> ref() {
    CreateUserVariables vars= CreateUserVariables(companyName: companyName,email: email,userRole: userRole,phoneNumber: _phoneNumber,rating: _rating,);
    return _dataConnect.mutation("CreateUser", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class CreateUserUserInsert {
  final String id;
  CreateUserUserInsert.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateUserUserInsert otherTyped = other as CreateUserUserInsert;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  CreateUserUserInsert({
    required this.id,
  });
}

@immutable
class CreateUserData {
  final CreateUserUserInsert user_insert;
  CreateUserData.fromJson(dynamic json):
  
  user_insert = CreateUserUserInsert.fromJson(json['user_insert']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateUserData otherTyped = other as CreateUserData;
    return user_insert == otherTyped.user_insert;
    
  }
  @override
  int get hashCode => user_insert.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['user_insert'] = user_insert.toJson();
    return json;
  }

  CreateUserData({
    required this.user_insert,
  });
}

@immutable
class CreateUserVariables {
  final String companyName;
  final String email;
  final String userRole;
  late final Optional<String>phoneNumber;
  late final Optional<double>rating;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  CreateUserVariables.fromJson(Map<String, dynamic> json):
  
  companyName = nativeFromJson<String>(json['companyName']),
  email = nativeFromJson<String>(json['email']),
  userRole = nativeFromJson<String>(json['userRole']) {
  
  
  
  
  
    phoneNumber = Optional.optional(nativeFromJson, nativeToJson);
    phoneNumber.value = json['phoneNumber'] == null ? null : nativeFromJson<String>(json['phoneNumber']);
  
  
    rating = Optional.optional(nativeFromJson, nativeToJson);
    rating.value = json['rating'] == null ? null : nativeFromJson<double>(json['rating']);
  
  }
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateUserVariables otherTyped = other as CreateUserVariables;
    return companyName == otherTyped.companyName && 
    email == otherTyped.email && 
    userRole == otherTyped.userRole && 
    phoneNumber == otherTyped.phoneNumber && 
    rating == otherTyped.rating;
    
  }
  @override
  int get hashCode => Object.hashAll([companyName.hashCode, email.hashCode, userRole.hashCode, phoneNumber.hashCode, rating.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['companyName'] = nativeToJson<String>(companyName);
    json['email'] = nativeToJson<String>(email);
    json['userRole'] = nativeToJson<String>(userRole);
    if(phoneNumber.state == OptionalState.set) {
      json['phoneNumber'] = phoneNumber.toJson();
    }
    if(rating.state == OptionalState.set) {
      json['rating'] = rating.toJson();
    }
    return json;
  }

  CreateUserVariables({
    required this.companyName,
    required this.email,
    required this.userRole,
    required this.phoneNumber,
    required this.rating,
  });
}

