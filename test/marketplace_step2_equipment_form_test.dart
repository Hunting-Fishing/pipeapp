import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pipe_app/core/design/pipe_buyer_theme.dart';
import 'package:pipe_app/marketplace/marketplace_equipment_catalog.dart';
import 'package:pipe_app/marketplace/marketplace_equipment_step2_section.dart';
import 'package:pipe_app/marketplace/marketplace_serial_decoder.dart';

class _Step2TestHarness extends StatefulWidget {
  const _Step2TestHarness({
    required this.catalog,
    required this.serialDecoder,
    required this.formKey,
    this.category = 'Heavy Equipment',
    required this.serialController,
    required this.customBrandController,
    required this.manualYearController,
    required this.manualModelController,
    required this.engineController,
    required this.hoursController,
    required this.attachmentsController,
    this.onStateUpdated,
  });

  final EquipmentCatalog catalog;
  final MarketplaceSerialDecoder serialDecoder;
  final GlobalKey<FormState> formKey;
  final String category;
  final TextEditingController serialController;
  final TextEditingController customBrandController;
  final TextEditingController manualYearController;
  final TextEditingController manualModelController;
  final TextEditingController engineController;
  final TextEditingController hoursController;
  final TextEditingController attachmentsController;
  final ValueChanged<EquipmentSpecSelection>? onStateUpdated;

  @override
  State<_Step2TestHarness> createState() => _Step2TestHarnessState();
}

class _Step2TestHarnessState extends State<_Step2TestHarness> {
  String? selectedBrand;
  int? selectedYear;
  String? selectedModel;
  String operatingStatus = 'Operational';
  String maintenanceHistory = 'Full documented history';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: PipeBuyerTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: widget.formKey,
            child: MarketplaceEquipmentStep2Section(
              category: widget.category,
              productType: null,
              catalog: widget.catalog,
              serialDecoder: widget.serialDecoder,
              requiredSpecs: true,
              selectedBrand: selectedBrand,
              selectedYear: selectedYear,
              selectedModel: selectedModel,
              operatingStatus: operatingStatus,
              maintenanceHistory: maintenanceHistory,
              serialNumberController: widget.serialController,
              customBrandController: widget.customBrandController,
              manualYearController: widget.manualYearController,
              manualModelController: widget.manualModelController,
              engineDetailsController: widget.engineController,
              machineHoursController: widget.hoursController,
              attachmentsController: widget.attachmentsController,
              onSelectionChanged: (selection) {
                setState(() {
                  selectedBrand = selection.brand;
                  selectedYear = selection.year;
                  selectedModel = selection.model;
                });
                widget.onStateUpdated?.call(selection);
              },
              onOperatingStatusChanged: (next) {
                setState(() => operatingStatus = next);
              },
              onMaintenanceHistoryChanged: (next) {
                setState(() => maintenanceHistory = next);
              },
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  late EquipmentCatalog catalog;

  setUpAll(() async {
    EquipmentCatalog.clearCacheForTesting();
    catalog = await EquipmentCatalog.loadFromAsset(
      useCache: false,
      jsonLoader: (path) => File(path).readAsString(),
    );
  });

  group('MarketplaceEquipmentStep2Section layout, filtering & auto-fill', () {
    testWidgets(
        'renders exact requested Step 2 vertical field order and VIN/PIN note',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final formKey = GlobalKey<FormState>();
      final serialCtrl = TextEditingController();
      final customBrandCtrl = TextEditingController();
      final manualYearCtrl = TextEditingController();
      final manualModelCtrl = TextEditingController();
      final engineCtrl = TextEditingController();
      final hoursCtrl = TextEditingController();
      final attachCtrl = TextEditingController();
      addTearDown(() {
        serialCtrl.dispose();
        customBrandCtrl.dispose();
        manualYearCtrl.dispose();
        manualModelCtrl.dispose();
        engineCtrl.dispose();
        hoursCtrl.dispose();
        attachCtrl.dispose();
      });

      final decoder = MarketplaceSerialDecoder(
        httpClient: MockClient((_) async => http.Response('{}', 500)),
      );
      addTearDown(decoder.dispose);

      await tester.pumpWidget(
        _Step2TestHarness(
          catalog: catalog,
          serialDecoder: decoder,
          formKey: formKey,
          serialController: serialCtrl,
          customBrandController: customBrandCtrl,
          manualYearController: manualYearCtrl,
          manualModelController: manualModelCtrl,
          engineController: engineCtrl,
          hoursController: hoursCtrl,
          attachmentsController: attachCtrl,
        ),
      );
      await tester.pumpAndSettle();

      // Verify explanatory VIN / PIN auto-fill note is present.
      expect(
          find.byKey(const Key('step2_serial_autofill_note')), findsOneWidget);
      expect(
        find.textContaining('Attempt auto-fill with VIN # or equipment PIN'),
        findsOneWidget,
      );

      final serialDy =
          tester.getTopLeft(find.byKey(const Key('step2_serial_pin_field'))).dy;
      final searchDy = tester
          .getTopLeft(find.byKey(const Key('step2_catalog_quick_search_field')))
          .dy;
      final brandDy = tester
          .getTopLeft(find.byKey(const Key('step2_brand_select_field')))
          .dy;
      final yearDy = tester
          .getTopLeft(find.byKey(const Key('step2_year_select_field')))
          .dy;
      final modelDy = tester
          .getTopLeft(find.byKey(const Key('step2_model_select_field')))
          .dy;
      final engineDy = tester
          .getTopLeft(find.byKey(const Key('step2_engine_powertrain_field')))
          .dy;
      final hoursDy = tester
          .getTopLeft(find.byKey(const Key('step2_machine_hours_field')))
          .dy;

      // 1. Serial / PIN is FIRST (above Brand)
      expect(serialDy, lessThan(searchDy));
      expect(searchDy, lessThan(brandDy));
      // 2. Model Year is ABOVE Model
      expect(brandDy, lessThan(yearDy));
      expect(yearDy, lessThan(modelDy));
      // 3. Engine / Powertrain Details is ABOVE Machine Hours
      expect(modelDy, lessThan(engineDy));
      expect(engineDy, lessThan(hoursDy));
    });

    testWidgets('auto-fills Make, Model Year, Model & Engine from VIN/PIN',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final formKey = GlobalKey<FormState>();
      final serialCtrl = TextEditingController();
      final customBrandCtrl = TextEditingController();
      final manualYearCtrl = TextEditingController();
      final manualModelCtrl = TextEditingController();
      final engineCtrl = TextEditingController();
      final hoursCtrl = TextEditingController();
      final attachCtrl = TextEditingController();
      addTearDown(() {
        serialCtrl.dispose();
        customBrandCtrl.dispose();
        manualYearCtrl.dispose();
        manualModelCtrl.dispose();
        engineCtrl.dispose();
        hoursCtrl.dispose();
        attachCtrl.dispose();
      });

      final decoder = MarketplaceSerialDecoder(
        httpClient: MockClient((_) async {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'Results': <Map<String, dynamic>>[
                <String, dynamic>{
                  'ErrorCode': '0',
                  'Make': 'PETERBILT',
                  'Model': '389',
                  'ModelYear': '2021',
                  'VehicleType': 'TRUCK',
                  'BodyClass': 'Truck-Tractor',
                  'EngineManufacturer': 'Cummins',
                  'EngineModel': 'X15',
                  'DisplacementL': '14.9',
                  'EngineHP': '565',
                  'FuelTypePrimary': 'Diesel',
                },
              ],
            }),
            200,
          );
        }),
      );
      addTearDown(decoder.dispose);

      EquipmentSpecSelection? latestSelection;
      await tester.pumpWidget(
        _Step2TestHarness(
          catalog: catalog,
          serialDecoder: decoder,
          formKey: formKey,
          category: 'Transport & Hauling',
          serialController: serialCtrl,
          customBrandController: customBrandCtrl,
          manualYearController: manualYearCtrl,
          manualModelController: manualModelCtrl,
          engineController: engineCtrl,
          hoursController: hoursCtrl,
          attachmentsController: attachCtrl,
          onStateUpdated: (sel) => latestSelection = sel,
        ),
      );

      await tester.enterText(
        find.byKey(const Key('step2_serial_pin_field')),
        '1XPXD49XXMD123456',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('step2_serial_autofill_button')));
      await tester.pumpAndSettle();

      expect(latestSelection, isNotNull);
      expect(latestSelection!.brand, 'Peterbilt');
      expect(latestSelection!.year, 2021);
      expect(latestSelection!.model, '389');
      expect(engineCtrl.text, contains('Cummins'));
      expect(
          find.byKey(const Key('step2_serial_decode_banner')), findsOneWidget);
    });

    testWidgets(
        'enforces year-bounded model picker (2020–2026 T76 excluded in 2019, shown in 2022)',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final formKey = GlobalKey<FormState>();
      final serialCtrl = TextEditingController();
      final customBrandCtrl = TextEditingController();
      final manualYearCtrl = TextEditingController();
      final manualModelCtrl = TextEditingController();
      final engineCtrl = TextEditingController();
      final hoursCtrl = TextEditingController();
      final attachCtrl = TextEditingController();
      addTearDown(() {
        serialCtrl.dispose();
        customBrandCtrl.dispose();
        manualYearCtrl.dispose();
        manualModelCtrl.dispose();
        engineCtrl.dispose();
        hoursCtrl.dispose();
        attachCtrl.dispose();
      });

      final decoder = MarketplaceSerialDecoder(
        httpClient: MockClient((_) async => http.Response('{}', 500)),
      );
      addTearDown(decoder.dispose);

      await tester.pumpWidget(
        _Step2TestHarness(
          catalog: catalog,
          serialDecoder: decoder,
          formKey: formKey,
          serialController: serialCtrl,
          customBrandController: customBrandCtrl,
          manualYearController: manualYearCtrl,
          manualModelController: manualModelCtrl,
          engineController: engineCtrl,
          hoursController: hoursCtrl,
          attachmentsController: attachCtrl,
        ),
      );
      await tester.pumpAndSettle();

      // 1. Open Brand picker, search 'Bobcat', and select it.
      await tester.tap(find.byKey(const Key('step2_brand_select_trigger')));
      await tester.pumpAndSettle();
      final modalSearch = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(modalSearch, 'Bobcat');
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byType(ListView),
        matching: find.text('Bobcat'),
      ));
      await tester.pumpAndSettle();

      // 2. Open Model Year picker, search '2019', and select 2019.
      await tester.tap(find.byKey(const Key('step2_year_select_trigger')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(TextField),
        ),
        '2019',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byType(ListView),
        matching: find.text('2019'),
      ));
      await tester.pumpAndSettle();

      // 3. Open Model picker for 2019 and search 'T76' (2020–2026 only) -> NOT listed!
      await tester.tap(find.byKey(const Key('step2_model_select_trigger')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(TextField),
        ),
        'T76',
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(ListView), matching: find.text('T76')),
        findsNothing,
      );
      // Close dialog
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      // 4. Change Model Year to 2022 -> now T76 IS listed and selectable!
      await tester.tap(find.byKey(const Key('step2_year_select_trigger')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(TextField),
        ),
        '2022',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byType(ListView),
        matching: find.text('2022'),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('step2_model_select_trigger')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(TextField),
        ),
        'T76',
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(ListView), matching: find.text('T76')),
        findsOneWidget,
      );
      await tester.tap(find.descendant(
        of: find.byType(ListView),
        matching: find.text('T76'),
      ));
      await tester.pumpAndSettle();

      // Auto-populated Bobcat D24 engine details!
      expect(engineCtrl.text, contains('D24'));
    });

    testWidgets(
        'supports multi-engine selector via Step 2 Quick-Search & manual fallback for uncovered OEMs',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final formKey = GlobalKey<FormState>();
      final serialCtrl = TextEditingController();
      final customBrandCtrl = TextEditingController();
      final manualYearCtrl = TextEditingController();
      final manualModelCtrl = TextEditingController();
      final engineCtrl = TextEditingController();
      final hoursCtrl = TextEditingController();
      final attachCtrl = TextEditingController();
      addTearDown(() {
        serialCtrl.dispose();
        customBrandCtrl.dispose();
        manualYearCtrl.dispose();
        manualModelCtrl.dispose();
        engineCtrl.dispose();
        hoursCtrl.dispose();
        attachCtrl.dispose();
      });

      final decoder = MarketplaceSerialDecoder(
        httpClient: MockClient((_) async => http.Response('{}', 500)),
      );
      addTearDown(decoder.dispose);

      await tester.pumpWidget(
        _Step2TestHarness(
          catalog: catalog,
          serialDecoder: decoder,
          formKey: formKey,
          category: 'Transport & Hauling',
          serialController: serialCtrl,
          customBrandController: customBrandCtrl,
          manualYearController: manualYearCtrl,
          manualModelController: manualModelCtrl,
          engineController: engineCtrl,
          hoursController: hoursCtrl,
          attachmentsController: attachCtrl,
        ),
      );
      await tester.pumpAndSettle();

      // 1. Use Step 2 Quick-Search bar to select '2020 Peterbilt 389'
      await tester.enterText(
        find.byKey(const Key('step2_catalog_quick_search_field')),
        '2020 Peterbilt 389',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('step2_catalog_quick_search_results')),
        findsOneWidget,
      );
      await tester.tap(find.descendant(
        of: find.byKey(const Key('step2_catalog_quick_search_results')),
        matching: find.text('Peterbilt 389'),
      ));
      await tester.pumpAndSettle();

      // Multi-engine configuration selector renders for 2020 Peterbilt 389!
      expect(
        find.text('Engine / powertrain configuration'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('step2_engine_config_trigger')));
      await tester.pumpAndSettle();
      // Select PACCAR MX-13 option from the modal
      await tester.tap(find.descendant(
        of: find.byType(ListView),
        matching: find.textContaining('MX-13').first,
      ));
      await tester.pumpAndSettle();
      expect(engineCtrl.text, contains('MX-13'));

      // 2. Switch Brand to uncovered trailer OEM 'Trail King' -> requires manual Year & Model #
      await tester.tap(find.byKey(const Key('step2_brand_select_trigger')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(TextField),
        ),
        'Trail King',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byType(ListView),
        matching: find.text('Trail King'),
      ));
      await tester.pumpAndSettle();

      expect(
          find.byKey(const Key('step2_manual_entry_notice')), findsOneWidget);
      expect(find.byKey(const Key('step2_manual_year_field')), findsOneWidget);
      expect(find.byKey(const Key('step2_manual_model_field')), findsOneWidget);

      // Required validation fails when manual year & model are empty
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('step2_manual_year_field')),
        '2021',
      );
      await tester.enterText(
        find.byKey(const Key('step2_manual_model_field')),
        'TK110HDG',
      );
      await tester.pump();
      expect(formKey.currentState!.validate(), isTrue);
    });
  });
}
