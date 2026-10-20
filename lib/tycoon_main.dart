import 'package:flutter/material.dart';
import 'package:oil_gas_tycoon/oil_gas_tycoon.dart';

/// Runs the game within the Pipeapp checkout without marketplace services.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OilGasTycoonApp());
}
