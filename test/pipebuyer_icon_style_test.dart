import 'package:flutter_test/flutter_test.dart';
import 'package:pipeapp/marketplace/industrial_icon_assets.dart';

void main() {
  group('Pipe Buyer marketplace artwork', () {
    test('top-level marketplace categories use distinct branded artwork', () {
      expect(
        IndustrialIconAssets.forLabel('Heavy Equipment'),
        IndustrialIconAssets.crawlerExcavator,
      );
      expect(
        IndustrialIconAssets.forLabel('Oil & Gas Equipment'),
        IndustrialIconAssets.pumpjack,
      );
      expect(
        IndustrialIconAssets.forLabel('Oilfield & Drilling'),
        IndustrialIconAssets.drillingRig,
      );
      expect(
        IndustrialIconAssets.forLabel('Site Support'),
        IndustrialIconAssets.lightTower,
      );
      expect(
        IndustrialIconAssets.forLabel('Transport & Hauling'),
        IndustrialIconAssets.dumpTruck,
      );
    });

    test('heavy-equipment labels resolve to Pipe Buyer equipment artwork', () {
      expect(IndustrialIconAssets.forLabel('Crawler Excavator'),
          IndustrialIconAssets.crawlerExcavator);
      expect(IndustrialIconAssets.forLabel('Mini Excavator'),
          IndustrialIconAssets.miniExcavator);
      expect(IndustrialIconAssets.forLabel('Wheel Loader'),
          IndustrialIconAssets.wheelLoader);
      expect(IndustrialIconAssets.forLabel('Skid Steer Loader'),
          IndustrialIconAssets.skidSteer);
      expect(IndustrialIconAssets.forLabel('Bulldozer'),
          IndustrialIconAssets.bulldozer);
      expect(IndustrialIconAssets.forLabel('Motor Grader'),
          IndustrialIconAssets.motorGrader);
      expect(IndustrialIconAssets.forLabel('Warehouse Forklift'),
          IndustrialIconAssets.warehouseForklift);
      expect(IndustrialIconAssets.forLabel('Rough Terrain Telehandler'),
          IndustrialIconAssets.telehandler);
    });

    test('supplied hauling artwork has semantic resolver coverage', () {
      expect(IndustrialIconAssets.forLabel('Mobile Crane'),
          IndustrialIconAssets.craneTruck);
      expect(IndustrialIconAssets.forLabel('Lowboy Trailer'),
          IndustrialIconAssets.lowboyTrailer);
      expect(IndustrialIconAssets.forLabel('Dump Truck'),
          IndustrialIconAssets.dumpTruck);
    });
  });
}
