// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class InvoiceA4Struct extends FFFirebaseStruct {
  InvoiceA4Struct({
    String? itemsName,
    double? itemsQty,
    double? itemBonus,
    double? itemGrossaAmount,
    double? itemsDiscountPer,
    double? itemsDiscountValue,
    double? itemsTaxPer,
    double? itemsTaxAmount,
    double? itemsTotal,
    double? itemsPriceList,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _itemsName = itemsName,
        _itemsQty = itemsQty,
        _itemBonus = itemBonus,
        _itemGrossaAmount = itemGrossaAmount,
        _itemsDiscountPer = itemsDiscountPer,
        _itemsDiscountValue = itemsDiscountValue,
        _itemsTaxPer = itemsTaxPer,
        _itemsTaxAmount = itemsTaxAmount,
        _itemsTotal = itemsTotal,
        _itemsPriceList = itemsPriceList,
        super(firestoreUtilData);

  // "itemsName" field.
  String? _itemsName;
  String get itemsName => _itemsName ?? 'na';
  set itemsName(String? val) => _itemsName = val;

  bool hasItemsName() => _itemsName != null;

  // "itemsQty" field.
  double? _itemsQty;
  double get itemsQty => _itemsQty ?? 0.0;
  set itemsQty(double? val) => _itemsQty = val;

  void incrementItemsQty(double amount) => itemsQty = itemsQty + amount;

  bool hasItemsQty() => _itemsQty != null;

  // "ItemBonus" field.
  double? _itemBonus;
  double get itemBonus => _itemBonus ?? 0.0;
  set itemBonus(double? val) => _itemBonus = val;

  void incrementItemBonus(double amount) => itemBonus = itemBonus + amount;

  bool hasItemBonus() => _itemBonus != null;

  // "ItemGrossaAmount" field.
  double? _itemGrossaAmount;
  double get itemGrossaAmount => _itemGrossaAmount ?? 0.0;
  set itemGrossaAmount(double? val) => _itemGrossaAmount = val;

  void incrementItemGrossaAmount(double amount) =>
      itemGrossaAmount = itemGrossaAmount + amount;

  bool hasItemGrossaAmount() => _itemGrossaAmount != null;

  // "itemsDiscountPer" field.
  double? _itemsDiscountPer;
  double get itemsDiscountPer => _itemsDiscountPer ?? 0.0;
  set itemsDiscountPer(double? val) => _itemsDiscountPer = val;

  void incrementItemsDiscountPer(double amount) =>
      itemsDiscountPer = itemsDiscountPer + amount;

  bool hasItemsDiscountPer() => _itemsDiscountPer != null;

  // "itemsDiscountValue" field.
  double? _itemsDiscountValue;
  double get itemsDiscountValue => _itemsDiscountValue ?? 0.0;
  set itemsDiscountValue(double? val) => _itemsDiscountValue = val;

  void incrementItemsDiscountValue(double amount) =>
      itemsDiscountValue = itemsDiscountValue + amount;

  bool hasItemsDiscountValue() => _itemsDiscountValue != null;

  // "itemsTaxPer" field.
  double? _itemsTaxPer;
  double get itemsTaxPer => _itemsTaxPer ?? 0.0;
  set itemsTaxPer(double? val) => _itemsTaxPer = val;

  void incrementItemsTaxPer(double amount) =>
      itemsTaxPer = itemsTaxPer + amount;

  bool hasItemsTaxPer() => _itemsTaxPer != null;

  // "itemsTaxAmount" field.
  double? _itemsTaxAmount;
  double get itemsTaxAmount => _itemsTaxAmount ?? 0.0;
  set itemsTaxAmount(double? val) => _itemsTaxAmount = val;

  void incrementItemsTaxAmount(double amount) =>
      itemsTaxAmount = itemsTaxAmount + amount;

  bool hasItemsTaxAmount() => _itemsTaxAmount != null;

  // "itemsTotal" field.
  double? _itemsTotal;
  double get itemsTotal => _itemsTotal ?? 0.0;
  set itemsTotal(double? val) => _itemsTotal = val;

  void incrementItemsTotal(double amount) => itemsTotal = itemsTotal + amount;

  bool hasItemsTotal() => _itemsTotal != null;

  // "itemsPriceList" field.
  double? _itemsPriceList;
  double get itemsPriceList => _itemsPriceList ?? 0.0;
  set itemsPriceList(double? val) => _itemsPriceList = val;

  void incrementItemsPriceList(double amount) =>
      itemsPriceList = itemsPriceList + amount;

  bool hasItemsPriceList() => _itemsPriceList != null;

  static InvoiceA4Struct fromMap(Map<String, dynamic> data) => InvoiceA4Struct(
        itemsName: data['itemsName'] as String?,
        itemsQty: castToType<double>(data['itemsQty']),
        itemBonus: castToType<double>(data['ItemBonus']),
        itemGrossaAmount: castToType<double>(data['ItemGrossaAmount']),
        itemsDiscountPer: castToType<double>(data['itemsDiscountPer']),
        itemsDiscountValue: castToType<double>(data['itemsDiscountValue']),
        itemsTaxPer: castToType<double>(data['itemsTaxPer']),
        itemsTaxAmount: castToType<double>(data['itemsTaxAmount']),
        itemsTotal: castToType<double>(data['itemsTotal']),
        itemsPriceList: castToType<double>(data['itemsPriceList']),
      );

  static InvoiceA4Struct? maybeFromMap(dynamic data) => data is Map
      ? InvoiceA4Struct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'itemsName': _itemsName,
        'itemsQty': _itemsQty,
        'ItemBonus': _itemBonus,
        'ItemGrossaAmount': _itemGrossaAmount,
        'itemsDiscountPer': _itemsDiscountPer,
        'itemsDiscountValue': _itemsDiscountValue,
        'itemsTaxPer': _itemsTaxPer,
        'itemsTaxAmount': _itemsTaxAmount,
        'itemsTotal': _itemsTotal,
        'itemsPriceList': _itemsPriceList,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'itemsName': serializeParam(
          _itemsName,
          ParamType.string,
        ),
        'itemsQty': serializeParam(
          _itemsQty,
          ParamType.double,
        ),
        'ItemBonus': serializeParam(
          _itemBonus,
          ParamType.double,
        ),
        'ItemGrossaAmount': serializeParam(
          _itemGrossaAmount,
          ParamType.double,
        ),
        'itemsDiscountPer': serializeParam(
          _itemsDiscountPer,
          ParamType.double,
        ),
        'itemsDiscountValue': serializeParam(
          _itemsDiscountValue,
          ParamType.double,
        ),
        'itemsTaxPer': serializeParam(
          _itemsTaxPer,
          ParamType.double,
        ),
        'itemsTaxAmount': serializeParam(
          _itemsTaxAmount,
          ParamType.double,
        ),
        'itemsTotal': serializeParam(
          _itemsTotal,
          ParamType.double,
        ),
        'itemsPriceList': serializeParam(
          _itemsPriceList,
          ParamType.double,
        ),
      }.withoutNulls;

  static InvoiceA4Struct fromSerializableMap(Map<String, dynamic> data) =>
      InvoiceA4Struct(
        itemsName: deserializeParam(
          data['itemsName'],
          ParamType.string,
          false,
        ),
        itemsQty: deserializeParam(
          data['itemsQty'],
          ParamType.double,
          false,
        ),
        itemBonus: deserializeParam(
          data['ItemBonus'],
          ParamType.double,
          false,
        ),
        itemGrossaAmount: deserializeParam(
          data['ItemGrossaAmount'],
          ParamType.double,
          false,
        ),
        itemsDiscountPer: deserializeParam(
          data['itemsDiscountPer'],
          ParamType.double,
          false,
        ),
        itemsDiscountValue: deserializeParam(
          data['itemsDiscountValue'],
          ParamType.double,
          false,
        ),
        itemsTaxPer: deserializeParam(
          data['itemsTaxPer'],
          ParamType.double,
          false,
        ),
        itemsTaxAmount: deserializeParam(
          data['itemsTaxAmount'],
          ParamType.double,
          false,
        ),
        itemsTotal: deserializeParam(
          data['itemsTotal'],
          ParamType.double,
          false,
        ),
        itemsPriceList: deserializeParam(
          data['itemsPriceList'],
          ParamType.double,
          false,
        ),
      );

  @override
  String toString() => 'InvoiceA4Struct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is InvoiceA4Struct &&
        itemsName == other.itemsName &&
        itemsQty == other.itemsQty &&
        itemBonus == other.itemBonus &&
        itemGrossaAmount == other.itemGrossaAmount &&
        itemsDiscountPer == other.itemsDiscountPer &&
        itemsDiscountValue == other.itemsDiscountValue &&
        itemsTaxPer == other.itemsTaxPer &&
        itemsTaxAmount == other.itemsTaxAmount &&
        itemsTotal == other.itemsTotal &&
        itemsPriceList == other.itemsPriceList;
  }

  @override
  int get hashCode => const ListEquality().hash([
        itemsName,
        itemsQty,
        itemBonus,
        itemGrossaAmount,
        itemsDiscountPer,
        itemsDiscountValue,
        itemsTaxPer,
        itemsTaxAmount,
        itemsTotal,
        itemsPriceList
      ]);
}

InvoiceA4Struct createInvoiceA4Struct({
  String? itemsName,
  double? itemsQty,
  double? itemBonus,
  double? itemGrossaAmount,
  double? itemsDiscountPer,
  double? itemsDiscountValue,
  double? itemsTaxPer,
  double? itemsTaxAmount,
  double? itemsTotal,
  double? itemsPriceList,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    InvoiceA4Struct(
      itemsName: itemsName,
      itemsQty: itemsQty,
      itemBonus: itemBonus,
      itemGrossaAmount: itemGrossaAmount,
      itemsDiscountPer: itemsDiscountPer,
      itemsDiscountValue: itemsDiscountValue,
      itemsTaxPer: itemsTaxPer,
      itemsTaxAmount: itemsTaxAmount,
      itemsTotal: itemsTotal,
      itemsPriceList: itemsPriceList,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

InvoiceA4Struct? updateInvoiceA4Struct(
  InvoiceA4Struct? invoiceA4, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    invoiceA4
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addInvoiceA4StructData(
  Map<String, dynamic> firestoreData,
  InvoiceA4Struct? invoiceA4,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (invoiceA4 == null) {
    return;
  }
  if (invoiceA4.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && invoiceA4.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final invoiceA4Data = getInvoiceA4FirestoreData(invoiceA4, forFieldValue);
  final nestedData = invoiceA4Data.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = invoiceA4.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getInvoiceA4FirestoreData(
  InvoiceA4Struct? invoiceA4, [
  bool forFieldValue = false,
]) {
  if (invoiceA4 == null) {
    return {};
  }
  final firestoreData = mapToFirestore(invoiceA4.toMap());

  // Add any Firestore field values
  mapToFirestore(invoiceA4.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getInvoiceA4ListFirestoreData(
  List<InvoiceA4Struct>? invoiceA4s,
) =>
    invoiceA4s?.map((e) => getInvoiceA4FirestoreData(e, true)).toList() ?? [];
