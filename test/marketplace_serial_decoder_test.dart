import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pipe_app/marketplace/marketplace_equipment_catalog.dart';
import 'package:pipe_app/marketplace/marketplace_serial_decoder.dart';

void main() {
  late EquipmentCatalog catalog;

  setUpAll(() async {
    EquipmentCatalog.clearCacheForTesting();
    catalog = await EquipmentCatalog.loadFromAsset(
      useCache: false,
      jsonLoader: (path) => File(path).readAsString(),
    );
  });

  group('MarketplaceSerialDecoder hybrid VIN + OEM PIN decoding', () {
    test('validates ISO 3779 / FMVSS 115 Mod-11 check digit accurately', () {
      expect(
        MarketplaceSerialDecoder.hasValidNorthAmericanVinCheckDigit(
          '1XPXD49XXMD123456',
        ),
        isTrue,
      );
      expect(
        MarketplaceSerialDecoder.hasValidNorthAmericanVinCheckDigit(
          '1XPXD49X1MD123456',
        ),
        isFalse,
      );
    });

    test('decodes 17-char highway truck VIN via NHTSA vPIC and caches result',
        () async {
      var httpCalls = 0;
      final mockClient = MockClient((request) async {
        httpCalls++;
        expect(
          request.url.toString(),
          contains('vpic.nhtsa.dot.gov/api/vehicles/DecodeVinValuesExtended/'),
        );
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
      });

      final decoder = MarketplaceSerialDecoder(httpClient: mockClient);
      addTearDown(decoder.dispose);

      final result = await decoder.decode(
        '1XPXD49XXMD123456',
        categoryContext: 'Transport & Hauling',
        catalog: catalog,
      );

      expect(result.source, SerialDecodeSource.nhtsaVpic);
      expect(result.confidence, SerialDecodeConfidence.high);
      expect(result.manufacturer, 'Peterbilt');
      expect(result.matchedCatalogModel, '389');
      expect(result.modelYear, 2021);
      expect(result.engineSummary, contains('Cummins'));
      expect(result.engineSummary, contains('X15'));
      expect(httpCalls, 1);

      // Second call hits LRU cache with zero additional HTTP calls.
      final cached = await decoder.decode(
        '1XP-XD49X-XMD123456',
        categoryContext: 'Transport & Hauling',
        catalog: catalog,
      );
      expect(cached.manufacturer, 'Peterbilt');
      expect(httpCalls, 1);
    });

    test('blocks NHTSA WMI collisions for John Deere & Komatsu 17-char PINs',
        () async {
      var vpicCalled = false;
      final mockClient = MockClient((_) async {
        vpicCalled = true;
        // Simulate NHTSA vPIC false collision ("STOUGHTON TRAILERS" for 1DW).
        return http.Response(
          jsonEncode(<String, dynamic>{
            'Results': <Map<String, dynamic>>[
              <String, dynamic>{
                'ErrorCode': '0',
                'Make': 'STOUGHTON TRAILERS',
                'Model': 'Z-Plate',
                'ModelYear': '2020',
                'VehicleType': 'TRAILER',
              },
            ],
          }),
          200,
        );
      });

      final decoder = MarketplaceSerialDecoder(httpClient: mockClient);
      addTearDown(decoder.dispose);

      // 1DW = John Deere Davenport Works (644K Loader, Pos 10 'L' = 2020)
      final deereLoader = await decoder.decode(
        '1DW644KZJLF704512',
        categoryContext: 'Heavy Equipment',
        catalog: catalog,
      );
      expect(vpicCalled, isFalse);
      expect(deereLoader.source, SerialDecodeSource.isoEquipmentPin);
      expect(deereLoader.manufacturer, 'John Deere');
      expect(deereLoader.effectiveModel, '644K');
      expect(deereLoader.modelYear, 2020);

      // 1T0 = John Deere Dubuque Works (333G CTL, Pos 10 'M' = 2021)
      final deereCtl = await decoder.decode(
        '1T0333GMKMF398123',
        categoryContext: 'Heavy Equipment',
        catalog: catalog,
      );
      expect(vpicCalled, isFalse);
      expect(deereCtl.manufacturer, 'John Deere');
      expect(deereCtl.effectiveModel, '333G');
      expect(deereCtl.modelYear, 2021);

      // KMT = Komatsu 17-char PIN (never Genesis / Hyundai!)
      final komatsuExc = await decoder.decode(
        'KMTPC210LC5012345',
        categoryContext: 'Heavy Equipment',
        catalog: catalog,
      );
      expect(vpicCalled, isFalse);
      expect(komatsuExc.manufacturer, 'Komatsu');
    });

    test('decodes Caterpillar 17-char PIN without hallucinating a false year',
        () async {
      final decoder = MarketplaceSerialDecoder(
        httpClient: MockClient((_) async => http.Response('{}', 500)),
      );
      addTearDown(decoder.dispose);

      // CAT PINs place serial prefix letters at Position 10 — NEVER an ISO year!
      final catResult = await decoder.decode(
        'CAT0320DCFTL09460',
        categoryContext: 'Heavy Equipment',
        catalog: catalog,
      );

      expect(catResult.manufacturer, 'Caterpillar');
      expect(catResult.matchedCatalogModel, '320D');
      expect(catResult.modelYear, isNull);
      expect(catResult.hasAnyDecodedField, isTrue);
    });

    test(
        'decodes JCB Position-8 year, Kubota JKU PIN, and CNH 9-char Wichita serial',
        () async {
      final decoder = MarketplaceSerialDecoder(
        httpClient: MockClient((_) async => http.Response('{}', 500)),
      );
      addTearDown(decoder.dispose);

      // JCB encodes ISO year at Position 8 ('L' = 2020), while Pos 10 'E' is engine!
      final jcb = await decoder.decode(
        'SLP3CXTLSE1234567',
        categoryContext: 'Heavy Equipment',
        catalog: catalog,
      );
      expect(jcb.manufacturer, 'JCB');
      expect(jcb.effectiveModel, '3CX');
      expect(jcb.modelYear, 2020);

      // Kubota Japan JKU PIN (Position 10 '0' -> no year hallucination, maps K0404 -> KX040-4)
      final kubota = await decoder.decode(
        'JKUK0404P01H12345',
        categoryContext: 'Heavy Equipment',
        catalog: catalog,
      );
      expect(kubota.manufacturer, 'Kubota');
      expect(kubota.matchedCatalogModel, 'KX040-4');
      expect(kubota.modelYear, isNull);

      // Case / New Holland 9-char Wichita skid steer serial: N + 'L' (2020) + M + 6 digits
      final cnhWichita = await decoder.decode(
        'NLM458912',
        categoryContext: 'Heavy Equipment',
        catalog: catalog,
        currentBrand: 'Case',
      );
      expect(cnhWichita.source, SerialDecodeSource.legacyEquipmentSerial);
      expect(cnhWichita.manufacturer, 'Case');
      expect(cnhWichita.modelYear, 2020);
    });

    test('flags invalid check-digit typo on highway-style 17-char VIN',
        () async {
      final mockClient = MockClient((_) async {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'Results': <Map<String, dynamic>>[
              <String, dynamic>{
                'ErrorCode': '1',
                'Make': '',
                'Model': '',
                'ModelYear': '',
              },
            ],
          }),
          200,
        );
      });
      final decoder = MarketplaceSerialDecoder(httpClient: mockClient);
      addTearDown(decoder.dispose);

      final typoVin = await decoder.decode(
        '1XPXD49X1MD123456',
        categoryContext: 'Transport & Hauling',
        catalog: catalog,
      );
      expect(typoVin.confidence, SerialDecodeConfidence.none);
      expect(typoVin.source, SerialDecodeSource.invalidCheckDigit);
    });
  });
}
