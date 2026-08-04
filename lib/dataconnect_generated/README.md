# dataconnect_generated SDK

## Installation
```sh
flutter pub get firebase_data_connect
flutterfire configure
```
For more information, see [Flutter for Firebase installation documentation](https://firebase.google.com/docs/data-connect/flutter-sdk#use-core).

## Data Connect instance
Each connector creates a static class, with an instance of the `DataConnect` class that can be used to connect to your Data Connect backend and call operations.

### Connecting to the emulator

```dart
String host = 'localhost'; // or your host name
int port = 9399; // or your port number
ExampleConnector.instance.dataConnect.useDataConnectEmulator(host, port);
```

You can also call queries and mutations by using the connector class.
## Queries

### GetUser
#### Required Arguments
```dart
// No required arguments
ExampleConnector.instance.getUser().execute();
```



#### Return Type
`execute()` returns a `QueryResult<GetUserData, void>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

/// Result of a query request. Created to hold extra variables in the future.
class QueryResult<Data, Variables> extends OperationResult<Data, Variables> {
  QueryResult(super.dataConnect, super.data, super.ref);
}

final result = await ExampleConnector.instance.getUser();
GetUserData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
final ref = ExampleConnector.instance.getUser().ref();
ref.execute();

ref.subscribe(...);
```


### ListUsers
#### Required Arguments
```dart
// No required arguments
ExampleConnector.instance.listUsers().execute();
```



#### Return Type
`execute()` returns a `QueryResult<ListUsersData, void>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

/// Result of a query request. Created to hold extra variables in the future.
class QueryResult<Data, Variables> extends OperationResult<Data, Variables> {
  QueryResult(super.dataConnect, super.data, super.ref);
}

final result = await ExampleConnector.instance.listUsers();
ListUsersData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
final ref = ExampleConnector.instance.listUsers().ref();
ref.execute();

ref.subscribe(...);
```


### GetEquipment
#### Required Arguments
```dart
String id = ...;
ExampleConnector.instance.getEquipment(
  id: id,
).execute();
```



#### Return Type
`execute()` returns a `QueryResult<GetEquipmentData, GetEquipmentVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

/// Result of a query request. Created to hold extra variables in the future.
class QueryResult<Data, Variables> extends OperationResult<Data, Variables> {
  QueryResult(super.dataConnect, super.data, super.ref);
}

final result = await ExampleConnector.instance.getEquipment(
  id: id,
);
GetEquipmentData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String id = ...;

final ref = ExampleConnector.instance.getEquipment(
  id: id,
).ref();
ref.execute();

ref.subscribe(...);
```


### ListEquipments
#### Required Arguments
```dart
// No required arguments
ExampleConnector.instance.listEquipments().execute();
```



#### Return Type
`execute()` returns a `QueryResult<ListEquipmentsData, void>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

/// Result of a query request. Created to hold extra variables in the future.
class QueryResult<Data, Variables> extends OperationResult<Data, Variables> {
  QueryResult(super.dataConnect, super.data, super.ref);
}

final result = await ExampleConnector.instance.listEquipments();
ListEquipmentsData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
final ref = ExampleConnector.instance.listEquipments().ref();
ref.execute();

ref.subscribe(...);
```


### GetSpecification
#### Required Arguments
```dart
String id = ...;
ExampleConnector.instance.getSpecification(
  id: id,
).execute();
```



#### Return Type
`execute()` returns a `QueryResult<GetSpecificationData, GetSpecificationVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

/// Result of a query request. Created to hold extra variables in the future.
class QueryResult<Data, Variables> extends OperationResult<Data, Variables> {
  QueryResult(super.dataConnect, super.data, super.ref);
}

final result = await ExampleConnector.instance.getSpecification(
  id: id,
);
GetSpecificationData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String id = ...;

final ref = ExampleConnector.instance.getSpecification(
  id: id,
).ref();
ref.execute();

ref.subscribe(...);
```


### ListSpecifications
#### Required Arguments
```dart
// No required arguments
ExampleConnector.instance.listSpecifications().execute();
```



#### Return Type
`execute()` returns a `QueryResult<ListSpecificationsData, void>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

/// Result of a query request. Created to hold extra variables in the future.
class QueryResult<Data, Variables> extends OperationResult<Data, Variables> {
  QueryResult(super.dataConnect, super.data, super.ref);
}

final result = await ExampleConnector.instance.listSpecifications();
ListSpecificationsData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
final ref = ExampleConnector.instance.listSpecifications().ref();
ref.execute();

ref.subscribe(...);
```


### GetOrder
#### Required Arguments
```dart
String id = ...;
ExampleConnector.instance.getOrder(
  id: id,
).execute();
```



#### Return Type
`execute()` returns a `QueryResult<GetOrderData, GetOrderVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

/// Result of a query request. Created to hold extra variables in the future.
class QueryResult<Data, Variables> extends OperationResult<Data, Variables> {
  QueryResult(super.dataConnect, super.data, super.ref);
}

final result = await ExampleConnector.instance.getOrder(
  id: id,
);
GetOrderData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String id = ...;

final ref = ExampleConnector.instance.getOrder(
  id: id,
).ref();
ref.execute();

ref.subscribe(...);
```


### ListMyOrders
#### Required Arguments
```dart
// No required arguments
ExampleConnector.instance.listMyOrders().execute();
```



#### Return Type
`execute()` returns a `QueryResult<ListMyOrdersData, void>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

/// Result of a query request. Created to hold extra variables in the future.
class QueryResult<Data, Variables> extends OperationResult<Data, Variables> {
  QueryResult(super.dataConnect, super.data, super.ref);
}

final result = await ExampleConnector.instance.listMyOrders();
ListMyOrdersData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
final ref = ExampleConnector.instance.listMyOrders().ref();
ref.execute();

ref.subscribe(...);
```


### GetEquipmentMessages
#### Required Arguments
```dart
String equipmentId = ...;
ExampleConnector.instance.getEquipmentMessages(
  equipmentId: equipmentId,
).execute();
```



#### Return Type
`execute()` returns a `QueryResult<GetEquipmentMessagesData, GetEquipmentMessagesVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

/// Result of a query request. Created to hold extra variables in the future.
class QueryResult<Data, Variables> extends OperationResult<Data, Variables> {
  QueryResult(super.dataConnect, super.data, super.ref);
}

final result = await ExampleConnector.instance.getEquipmentMessages(
  equipmentId: equipmentId,
);
GetEquipmentMessagesData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String equipmentId = ...;

final ref = ExampleConnector.instance.getEquipmentMessages(
  equipmentId: equipmentId,
).ref();
ref.execute();

ref.subscribe(...);
```

## Mutations

### CreateUser
#### Required Arguments
```dart
String companyName = ...;
String email = ...;
String userRole = ...;
ExampleConnector.instance.createUser(
  companyName: companyName,
  email: email,
  userRole: userRole,
).execute();
```

#### Optional Arguments
We return a builder for each query. For CreateUser, we created `CreateUserBuilder`. For queries and mutations with optional parameters, we return a builder class.
The builder pattern allows Data Connect to distinguish between fields that haven't been set and fields that have been set to null. A field can be set by calling its respective setter method like below:
```dart
class CreateUserVariablesBuilder {
  ...
   CreateUserVariablesBuilder phoneNumber(String? t) {
   _phoneNumber.value = t;
   return this;
  }
  CreateUserVariablesBuilder rating(double? t) {
   _rating.value = t;
   return this;
  }

  ...
}
ExampleConnector.instance.createUser(
  companyName: companyName,
  email: email,
  userRole: userRole,
)
.phoneNumber(phoneNumber)
.rating(rating)
.execute();
```

#### Return Type
`execute()` returns a `OperationResult<CreateUserData, CreateUserVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.createUser(
  companyName: companyName,
  email: email,
  userRole: userRole,
);
CreateUserData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String companyName = ...;
String email = ...;
String userRole = ...;

final ref = ExampleConnector.instance.createUser(
  companyName: companyName,
  email: email,
  userRole: userRole,
).ref();
ref.execute();
```


### UpdateUser
#### Required Arguments
```dart
// No required arguments
ExampleConnector.instance.updateUser().execute();
```

#### Optional Arguments
We return a builder for each query. For UpdateUser, we created `UpdateUserBuilder`. For queries and mutations with optional parameters, we return a builder class.
The builder pattern allows Data Connect to distinguish between fields that haven't been set and fields that have been set to null. A field can be set by calling its respective setter method like below:
```dart
class UpdateUserVariablesBuilder {
  ...
 
  UpdateUserVariablesBuilder companyName(String? t) {
   _companyName.value = t;
   return this;
  }
  UpdateUserVariablesBuilder phoneNumber(String? t) {
   _phoneNumber.value = t;
   return this;
  }

  ...
}
ExampleConnector.instance.updateUser()
.companyName(companyName)
.phoneNumber(phoneNumber)
.execute();
```

#### Return Type
`execute()` returns a `OperationResult<UpdateUserData, UpdateUserVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.updateUser();
UpdateUserData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
final ref = ExampleConnector.instance.updateUser().ref();
ref.execute();
```


### DeleteUser
#### Required Arguments
```dart
// No required arguments
ExampleConnector.instance.deleteUser().execute();
```



#### Return Type
`execute()` returns a `OperationResult<DeleteUserData, void>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.deleteUser();
DeleteUserData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
final ref = ExampleConnector.instance.deleteUser().ref();
ref.execute();
```


### CreateEquipment
#### Required Arguments
```dart
String title = ...;
String category = ...;
double price = ...;
String status = ...;
ExampleConnector.instance.createEquipment(
  title: title,
  category: category,
  price: price,
  status: status,
).execute();
```

#### Optional Arguments
We return a builder for each query. For CreateEquipment, we created `CreateEquipmentBuilder`. For queries and mutations with optional parameters, we return a builder class.
The builder pattern allows Data Connect to distinguish between fields that haven't been set and fields that have been set to null. A field can be set by calling its respective setter method like below:
```dart
class CreateEquipmentVariablesBuilder {
  ...
   CreateEquipmentVariablesBuilder description(String? t) {
   _description.value = t;
   return this;
  }
  CreateEquipmentVariablesBuilder location(String? t) {
   _location.value = t;
   return this;
  }

  ...
}
ExampleConnector.instance.createEquipment(
  title: title,
  category: category,
  price: price,
  status: status,
)
.description(description)
.location(location)
.execute();
```

#### Return Type
`execute()` returns a `OperationResult<CreateEquipmentData, CreateEquipmentVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.createEquipment(
  title: title,
  category: category,
  price: price,
  status: status,
);
CreateEquipmentData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String title = ...;
String category = ...;
double price = ...;
String status = ...;

final ref = ExampleConnector.instance.createEquipment(
  title: title,
  category: category,
  price: price,
  status: status,
).ref();
ref.execute();
```


### UpdateEquipment
#### Required Arguments
```dart
String id = ...;
ExampleConnector.instance.updateEquipment(
  id: id,
).execute();
```

#### Optional Arguments
We return a builder for each query. For UpdateEquipment, we created `UpdateEquipmentBuilder`. For queries and mutations with optional parameters, we return a builder class.
The builder pattern allows Data Connect to distinguish between fields that haven't been set and fields that have been set to null. A field can be set by calling its respective setter method like below:
```dart
class UpdateEquipmentVariablesBuilder {
  ...
   UpdateEquipmentVariablesBuilder price(double? t) {
   _price.value = t;
   return this;
  }

  ...
}
ExampleConnector.instance.updateEquipment(
  id: id,
)
.price(price)
.execute();
```

#### Return Type
`execute()` returns a `OperationResult<UpdateEquipmentData, UpdateEquipmentVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.updateEquipment(
  id: id,
);
UpdateEquipmentData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String id = ...;

final ref = ExampleConnector.instance.updateEquipment(
  id: id,
).ref();
ref.execute();
```


### DeleteEquipment
#### Required Arguments
```dart
String id = ...;
ExampleConnector.instance.deleteEquipment(
  id: id,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<DeleteEquipmentData, DeleteEquipmentVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.deleteEquipment(
  id: id,
);
DeleteEquipmentData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String id = ...;

final ref = ExampleConnector.instance.deleteEquipment(
  id: id,
).ref();
ref.execute();
```


### CreateSpecification
#### Required Arguments
```dart
double outerDiameter = ...;
double wallThickness = ...;
String grade = ...;
String threadType = ...;
String equipmentId = ...;
ExampleConnector.instance.createSpecification(
  outerDiameter: outerDiameter,
  wallThickness: wallThickness,
  grade: grade,
  threadType: threadType,
  equipmentId: equipmentId,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<CreateSpecificationData, CreateSpecificationVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.createSpecification(
  outerDiameter: outerDiameter,
  wallThickness: wallThickness,
  grade: grade,
  threadType: threadType,
  equipmentId: equipmentId,
);
CreateSpecificationData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
double outerDiameter = ...;
double wallThickness = ...;
String grade = ...;
String threadType = ...;
String equipmentId = ...;

final ref = ExampleConnector.instance.createSpecification(
  outerDiameter: outerDiameter,
  wallThickness: wallThickness,
  grade: grade,
  threadType: threadType,
  equipmentId: equipmentId,
).ref();
ref.execute();
```


### UpdateSpecification
#### Required Arguments
```dart
String id = ...;
ExampleConnector.instance.updateSpecification(
  id: id,
).execute();
```

#### Optional Arguments
We return a builder for each query. For UpdateSpecification, we created `UpdateSpecificationBuilder`. For queries and mutations with optional parameters, we return a builder class.
The builder pattern allows Data Connect to distinguish between fields that haven't been set and fields that have been set to null. A field can be set by calling its respective setter method like below:
```dart
class UpdateSpecificationVariablesBuilder {
  ...
   UpdateSpecificationVariablesBuilder wallThickness(double? t) {
   _wallThickness.value = t;
   return this;
  }

  ...
}
ExampleConnector.instance.updateSpecification(
  id: id,
)
.wallThickness(wallThickness)
.execute();
```

#### Return Type
`execute()` returns a `OperationResult<UpdateSpecificationData, UpdateSpecificationVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.updateSpecification(
  id: id,
);
UpdateSpecificationData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String id = ...;

final ref = ExampleConnector.instance.updateSpecification(
  id: id,
).ref();
ref.execute();
```


### DeleteSpecification
#### Required Arguments
```dart
String id = ...;
ExampleConnector.instance.deleteSpecification(
  id: id,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<DeleteSpecificationData, DeleteSpecificationVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.deleteSpecification(
  id: id,
);
DeleteSpecificationData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String id = ...;

final ref = ExampleConnector.instance.deleteSpecification(
  id: id,
).ref();
ref.execute();
```


### CreateOrder
#### Required Arguments
```dart
double totalPrice = ...;
String status = ...;
String equipmentId = ...;
ExampleConnector.instance.createOrder(
  totalPrice: totalPrice,
  status: status,
  equipmentId: equipmentId,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<CreateOrderData, CreateOrderVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.createOrder(
  totalPrice: totalPrice,
  status: status,
  equipmentId: equipmentId,
);
CreateOrderData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
double totalPrice = ...;
String status = ...;
String equipmentId = ...;

final ref = ExampleConnector.instance.createOrder(
  totalPrice: totalPrice,
  status: status,
  equipmentId: equipmentId,
).ref();
ref.execute();
```


### UpdateOrder
#### Required Arguments
```dart
String id = ...;
String status = ...;
ExampleConnector.instance.updateOrder(
  id: id,
  status: status,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<UpdateOrderData, UpdateOrderVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.updateOrder(
  id: id,
  status: status,
);
UpdateOrderData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String id = ...;
String status = ...;

final ref = ExampleConnector.instance.updateOrder(
  id: id,
  status: status,
).ref();
ref.execute();
```


### DeleteOrder
#### Required Arguments
```dart
String id = ...;
ExampleConnector.instance.deleteOrder(
  id: id,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<DeleteOrderData, DeleteOrderVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.deleteOrder(
  id: id,
);
DeleteOrderData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String id = ...;

final ref = ExampleConnector.instance.deleteOrder(
  id: id,
).ref();
ref.execute();
```


### SendMessage
#### Required Arguments
```dart
String content = ...;
String equipmentId = ...;
ExampleConnector.instance.sendMessage(
  content: content,
  equipmentId: equipmentId,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<SendMessageData, SendMessageVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.sendMessage(
  content: content,
  equipmentId: equipmentId,
);
SendMessageData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String content = ...;
String equipmentId = ...;

final ref = ExampleConnector.instance.sendMessage(
  content: content,
  equipmentId: equipmentId,
).ref();
ref.execute();
```


### DeleteMessage
#### Required Arguments
```dart
String id = ...;
ExampleConnector.instance.deleteMessage(
  id: id,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<DeleteMessageData, DeleteMessageVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.deleteMessage(
  id: id,
);
DeleteMessageData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String id = ...;

final ref = ExampleConnector.instance.deleteMessage(
  id: id,
).ref();
ref.execute();
```

