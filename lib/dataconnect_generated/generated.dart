library dataconnect_generated;
import 'package:firebase_data_connect/firebase_data_connect.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

part 'create_user.dart';

part 'update_user.dart';

part 'delete_user.dart';

part 'get_user.dart';

part 'list_users.dart';

part 'create_equipment.dart';

part 'update_equipment.dart';

part 'delete_equipment.dart';

part 'get_equipment.dart';

part 'list_equipments.dart';

part 'create_specification.dart';

part 'update_specification.dart';

part 'delete_specification.dart';

part 'get_specification.dart';

part 'list_specifications.dart';

part 'create_order.dart';

part 'update_order.dart';

part 'delete_order.dart';

part 'get_order.dart';

part 'list_my_orders.dart';

part 'send_message.dart';

part 'delete_message.dart';

part 'get_equipment_messages.dart';







class ExampleConnector {
  
  
  CreateUserVariablesBuilder createUser ({required String companyName, required String email, required String userRole, }) {
    return CreateUserVariablesBuilder(dataConnect, companyName: companyName,email: email,userRole: userRole,);
  }
  
  
  UpdateUserVariablesBuilder updateUser () {
    return UpdateUserVariablesBuilder(dataConnect, );
  }
  
  
  DeleteUserVariablesBuilder deleteUser () {
    return DeleteUserVariablesBuilder(dataConnect, );
  }
  
  
  GetUserVariablesBuilder getUser () {
    return GetUserVariablesBuilder(dataConnect, );
  }
  
  
  ListUsersVariablesBuilder listUsers () {
    return ListUsersVariablesBuilder(dataConnect, );
  }
  
  
  CreateEquipmentVariablesBuilder createEquipment ({required String title, required String category, required double price, required String status, }) {
    return CreateEquipmentVariablesBuilder(dataConnect, title: title,category: category,price: price,status: status,);
  }
  
  
  UpdateEquipmentVariablesBuilder updateEquipment ({required String id, }) {
    return UpdateEquipmentVariablesBuilder(dataConnect, id: id,);
  }
  
  
  DeleteEquipmentVariablesBuilder deleteEquipment ({required String id, }) {
    return DeleteEquipmentVariablesBuilder(dataConnect, id: id,);
  }
  
  
  GetEquipmentVariablesBuilder getEquipment ({required String id, }) {
    return GetEquipmentVariablesBuilder(dataConnect, id: id,);
  }
  
  
  ListEquipmentsVariablesBuilder listEquipments () {
    return ListEquipmentsVariablesBuilder(dataConnect, );
  }
  
  
  CreateSpecificationVariablesBuilder createSpecification ({required double outerDiameter, required double wallThickness, required String grade, required String threadType, required String equipmentId, }) {
    return CreateSpecificationVariablesBuilder(dataConnect, outerDiameter: outerDiameter,wallThickness: wallThickness,grade: grade,threadType: threadType,equipmentId: equipmentId,);
  }
  
  
  UpdateSpecificationVariablesBuilder updateSpecification ({required String id, }) {
    return UpdateSpecificationVariablesBuilder(dataConnect, id: id,);
  }
  
  
  DeleteSpecificationVariablesBuilder deleteSpecification ({required String id, }) {
    return DeleteSpecificationVariablesBuilder(dataConnect, id: id,);
  }
  
  
  GetSpecificationVariablesBuilder getSpecification ({required String id, }) {
    return GetSpecificationVariablesBuilder(dataConnect, id: id,);
  }
  
  
  ListSpecificationsVariablesBuilder listSpecifications () {
    return ListSpecificationsVariablesBuilder(dataConnect, );
  }
  
  
  CreateOrderVariablesBuilder createOrder ({required double totalPrice, required String status, required String equipmentId, }) {
    return CreateOrderVariablesBuilder(dataConnect, totalPrice: totalPrice,status: status,equipmentId: equipmentId,);
  }
  
  
  UpdateOrderVariablesBuilder updateOrder ({required String id, required String status, }) {
    return UpdateOrderVariablesBuilder(dataConnect, id: id,status: status,);
  }
  
  
  DeleteOrderVariablesBuilder deleteOrder ({required String id, }) {
    return DeleteOrderVariablesBuilder(dataConnect, id: id,);
  }
  
  
  GetOrderVariablesBuilder getOrder ({required String id, }) {
    return GetOrderVariablesBuilder(dataConnect, id: id,);
  }
  
  
  ListMyOrdersVariablesBuilder listMyOrders () {
    return ListMyOrdersVariablesBuilder(dataConnect, );
  }
  
  
  SendMessageVariablesBuilder sendMessage ({required String content, required String equipmentId, }) {
    return SendMessageVariablesBuilder(dataConnect, content: content,equipmentId: equipmentId,);
  }
  
  
  DeleteMessageVariablesBuilder deleteMessage ({required String id, }) {
    return DeleteMessageVariablesBuilder(dataConnect, id: id,);
  }
  
  
  GetEquipmentMessagesVariablesBuilder getEquipmentMessages ({required String equipmentId, }) {
    return GetEquipmentMessagesVariablesBuilder(dataConnect, equipmentId: equipmentId,);
  }
  

  static ConnectorConfig connectorConfig = ConnectorConfig(
    'us-east4',
    'example',
    'pipe-app-1w4gyj',
  );

  ExampleConnector({required this.dataConnect});
  static ExampleConnector get instance {
    
    CacheSettings cacheSettings = CacheSettings(
      maxAge: Duration(milliseconds:0),
      storage: CacheStorage.persistent,
    );
    
    return ExampleConnector(
        dataConnect: FirebaseDataConnect.instanceFor(
            connectorConfig: connectorConfig,
            
            cacheSettings: cacheSettings,
            
            sdkType: CallerSDKType.generated));
  }

  FirebaseDataConnect dataConnect;
}
