import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Central resolver for the industrial illustration package.
///
/// These assets are intentionally used as category artwork and placeholders.
/// Compact navigation, form, status, and action icons should remain Material
/// icons so they stay legible and theme-aware at small sizes.
abstract final class IndustrialIconAssets {
  static const _root = 'assets/images/industrial_icons';

  static const pipeBundle =
      '$_root/02-pipes-and-valves/01-pipe-bundle-large.svg';
  static const pipeBundleSmall =
      '$_root/02-pipes-and-valves/02-pipe-bundle-small.svg';
  static const gateValve =
      '$_root/02-pipes-and-valves/03-industrial-gate-valve.svg';
  static const pipeFlange = '$_root/02-pipes-and-valves/04-pipe-flange.svg';
  static const pipeElbow = '$_root/02-pipes-and-valves/05-pipe-elbow.svg';
  static const pipeCoupling = '$_root/02-pipes-and-valves/06-pipe-coupling.svg';
  static const pipeRack = '$_root/02-pipes-and-valves/08-pipe-rack.svg';

  static const fuelTank =
      '$_root/03-fuel-and-fluid-equipment/01-fuel-storage-tank.svg';
  static const fuelTanker =
      '$_root/03-fuel-and-fluid-equipment/02-fuel-tanker-truck.svg';
  static const verticalTank =
      '$_root/03-fuel-and-fluid-equipment/03-vertical-storage-tank.svg';
  static const industrialPump =
      '$_root/03-fuel-and-fluid-equipment/05-industrial-pump.svg';
  static const hoseReel = '$_root/03-fuel-and-fluid-equipment/06-hose-reel.svg';
  static const ibcTote = '$_root/03-fuel-and-fluid-equipment/07-ibc-tote.svg';
  static const oilDrum = '$_root/03-fuel-and-fluid-equipment/08-oil-drum.svg';

  static const portableOffice =
      '$_root/01-modular-buildings/02-portable-office-side.svg';
  static const stackedModular =
      '$_root/01-modular-buildings/03-stacked-modular-units.svg';
  static const mobileOffice =
      '$_root/01-modular-buildings/05-mobile-office-trailer.svg';
  static const portableGarage =
      '$_root/01-modular-buildings/07-portable-garage.svg';
  static const guardBooth = '$_root/01-modular-buildings/08-guard-booth.svg';

  static const warehouse = '$_root/04-site-buildings/04-warehouse-building.svg';
  static const serviceGarage = '$_root/04-site-buildings/05-service-garage.svg';
  static const industrialOffice =
      '$_root/04-site-buildings/07-industrial-office-building.svg';
  static const guardGate = '$_root/04-site-buildings/08-guard-house-gate.svg';

  static const semiTruck = '$_root/05-commercial-vehicles/01-semi-truck.svg';
  static const flatbedTrailer =
      '$_root/05-commercial-vehicles/02-flatbed-trailer.svg';
  static const craneTruck = '$_root/05-commercial-vehicles/03-crane-truck.svg';
  static const pickupFlatbed =
      '$_root/05-commercial-vehicles/04-pickup-flatbed-truck.svg';
  static const vacuumTruck =
      '$_root/05-commercial-vehicles/05-vacuum-truck.svg';
  static const towTruck = '$_root/05-commercial-vehicles/07-tow-truck.svg';
  static const boxTruck = '$_root/05-commercial-vehicles/08-box-truck.svg';

  static const locationPin =
      '$_root/06-sites-and-logistics/01-map-location-pin.svg';
  static const industrialSite =
      '$_root/06-sites-and-logistics/02-industrial-facility-site.svg';
  static const drillingSite =
      '$_root/06-sites-and-logistics/03-drilling-rig-site.svg';
  static const routeMap = '$_root/06-sites-and-logistics/04-route-map.svg';
  static const warehouseLocation =
      '$_root/06-sites-and-logistics/05-warehouse-location.svg';
  static const fencedYard = '$_root/06-sites-and-logistics/06-fenced-yard.svg';
  static const gpsNavigation =
      '$_root/06-sites-and-logistics/07-gps-navigation.svg';
  static const storageYard =
      '$_root/06-sites-and-logistics/08-storage-yard.svg';

  static const pumpjack = '$_root/07-oil-and-gas-equipment/01-pumpjack.svg';
  static const drillingRig =
      '$_root/07-oil-and-gas-equipment/02-drilling-rig.svg';
  static const pressureVessel =
      '$_root/07-oil-and-gas-equipment/03-pressure-vessel.svg';
  static const compressorSkid =
      '$_root/07-oil-and-gas-equipment/04-compressor-skid.svg';
  static const generator =
      '$_root/07-oil-and-gas-equipment/05-generator-units.svg';
  static const flareStack =
      '$_root/07-oil-and-gas-equipment/06-flare-stack.svg';
  static const refinery =
      '$_root/07-oil-and-gas-equipment/07-refinery-towers.svg';
  static const valveManifold =
      '$_root/07-oil-and-gas-equipment/08-valve-manifold.svg';

  static const safetyShield =
      '$_root/08-safety-and-security/01-safety-shield.svg';
  static const workerId = '$_root/08-safety-and-security/02-worker-id-card.svg';
  static const securePayment =
      '$_root/08-safety-and-security/03-secure-payment-box.svg';
  static const warningDocument =
      '$_root/08-safety-and-security/04-warning-document.svg';
  static const inspection =
      '$_root/08-safety-and-security/05-inspection-checklist.svg';
  static const hardhat = '$_root/08-safety-and-security/06-safety-hardhat.svg';
  static const securityCamera =
      '$_root/08-safety-and-security/07-security-camera.svg';
  static const emergencyBeacon =
      '$_root/08-safety-and-security/08-emergency-beacon.svg';

  static const dashboard =
      '$_root/09-software-and-administration/01-monitoring-dashboard.svg';
  static const messages =
      '$_root/09-software-and-administration/02-messages-chat.svg';
  static const bookingCalendar =
      '$_root/09-software-and-administration/03-booking-calendar.svg';
  static const maintenance =
      '$_root/09-software-and-administration/04-maintenance-tools.svg';
  static const inventory =
      '$_root/09-software-and-administration/05-inventory-shelves.svg';
  static const rentalCalendar =
      '$_root/09-software-and-administration/06-rental-calendar.svg';
  static const customerReview =
      '$_root/09-software-and-administration/07-customer-review.svg';
  static const complianceGavel =
      '$_root/09-software-and-administration/08-compliance-gavel.svg';

  static const crawlerExcavator =
      '$_root/10-heavy-equipment/01-crawler-excavator.svg';
  static const miniExcavator =
      '$_root/10-heavy-equipment/02-mini-excavator.svg';
  static const wheelLoader = '$_root/10-heavy-equipment/03-wheel-loader.svg';
  static const skidSteer = '$_root/10-heavy-equipment/04-skid-steer-loader.svg';
  static const bulldozer = '$_root/10-heavy-equipment/05-bulldozer.svg';
  static const motorGrader = '$_root/10-heavy-equipment/06-motor-grader.svg';
  static const warehouseForklift =
      '$_root/10-heavy-equipment/07-warehouse-forklift.svg';
  static const telehandler =
      '$_root/10-heavy-equipment/08-rough-terrain-telehandler.svg';

  static const lowboyTrailer =
      '$_root/11-heavy-haul-and-escort/01-lowboy-trailer.svg';
  static const detachableGooseneck =
      '$_root/11-heavy-haul-and-escort/02-detachable-gooseneck-lowboy.svg';
  static const stepDeckTrailer =
      '$_root/11-heavy-haul-and-escort/03-step-deck-trailer.svg';
  static const extendableStepDeck =
      '$_root/11-heavy-haul-and-escort/04-extendable-step-deck.svg';
  static const pilotCar = '$_root/11-heavy-haul-and-escort/05-pilot-car.svg';
  static const escortPickup =
      '$_root/11-heavy-haul-and-escort/06-escort-pickup-truck.svg';

  static const farmTractor = '$_root/12-farm-and-ranch/01-farm-tractor.svg';
  static const combineHarvester =
      '$_root/12-farm-and-ranch/02-combine-harvester.svg';
  static const roundBaler = '$_root/12-farm-and-ranch/03-round-baler.svg';
  static const seedDrill = '$_root/12-farm-and-ranch/04-seed-drill.svg';
  static const livestockTrailer =
      '$_root/12-farm-and-ranch/05-livestock-trailer.svg';
  static const squeezeChute =
      '$_root/12-farm-and-ranch/06-cattle-squeeze-chute.svg';
  static const stockWaterTank =
      '$_root/12-farm-and-ranch/07-stock-water-tank.svg';
  static const ranchGate = '$_root/12-farm-and-ranch/08-ranch-gate.svg';
  static const hayBale = '$_root/12-farm-and-ranch/09-round-hay-bale.svg';
  static const manureSpreader =
      '$_root/12-farm-and-ranch/10-manure-spreader.svg';

  static const drillPipe = '$_root/13-oilfield-tubulars/01-drill-pipe.svg';
  static const heavyweightDrillPipe =
      '$_root/13-oilfield-tubulars/02-heavyweight-drill-pipe.svg';
  static const drillCollar = '$_root/13-oilfield-tubulars/03-drill-collar.svg';
  static const casing = '$_root/13-oilfield-tubulars/04-casing.svg';
  static const liner = '$_root/13-oilfield-tubulars/05-liner.svg';
  static const productionTubing =
      '$_root/13-oilfield-tubulars/06-production-tubing.svg';
  static const coiledTubing =
      '$_root/13-oilfield-tubulars/07-coiled-tubing-reel.svg';
  static const suckerRod = '$_root/13-oilfield-tubulars/08-sucker-rod.svg';
  static const ponyRod = '$_root/13-oilfield-tubulars/09-pony-rod.svg';
  static const polishedRod = '$_root/13-oilfield-tubulars/10-polished-rod.svg';
  static const pupJoint = '$_root/13-oilfield-tubulars/11-pup-joint.svg';
  static const tubularCoupling =
      '$_root/13-oilfield-tubulars/12-tubular-coupling.svg';

  static const annularBop =
      '$_root/14-drilling-and-well-control/01-annular-bop.svg';
  static const ramBop = '$_root/14-drilling-and-well-control/02-ram-bop.svg';
  static const bopStack =
      '$_root/14-drilling-and-well-control/03-bop-stack.svg';
  static const shaleShaker =
      '$_root/14-drilling-and-well-control/04-shale-shaker.svg';
  static const triconeBit =
      '$_root/14-drilling-and-well-control/05-tricone-drill-bit.svg';
  static const pdcBit =
      '$_root/14-drilling-and-well-control/06-pdc-drill-bit.svg';
  static const cementingUnit =
      '$_root/14-drilling-and-well-control/07-cementing-unit.svg';
  static const cementBulkTrailer =
      '$_root/14-drilling-and-well-control/08-cement-bulk-trailer.svg';
  static const cementHead =
      '$_root/14-drilling-and-well-control/09-cement-head.svg';
  static const mudPump = '$_root/14-drilling-and-well-control/10-mud-pump.svg';

  static const wantedEquipment =
      '$_root/15-marketplace-and-dispatch/01-wanted-equipment-ad.svg';
  static const wantedParts =
      '$_root/15-marketplace-and-dispatch/02-wanted-parts-ad.svg';
  static const buyerRfq = '$_root/15-marketplace-and-dispatch/03-buyer-rfq.svg';
  static const dispatchLoadBoard =
      '$_root/15-marketplace-and-dispatch/04-dispatch-load-board.svg';
  static const carrierBidding =
      '$_root/15-marketplace-and-dispatch/05-carrier-bidding.svg';
  static const bidComparison =
      '$_root/15-marketplace-and-dispatch/06-bid-comparison.svg';
  static const awardedLoad =
      '$_root/15-marketplace-and-dispatch/07-awarded-load.svg';
  static const liveTruckTracking =
      '$_root/15-marketplace-and-dispatch/08-live-truck-tracking.svg';
  static const urgentDispatch =
      '$_root/15-marketplace-and-dispatch/09-urgent-dispatch.svg';
  static const multiStopRoute =
      '$_root/15-marketplace-and-dispatch/10-multi-stop-route.svg';

  static const wellhead = '$_root/16-oil-and-gas-equipment/01-wellhead.svg';
  static const separator = '$_root/16-oil-and-gas-equipment/02-separator.svg';
  static const heaterTreater =
      '$_root/16-oil-and-gas-equipment/03-heater-treater.svg';
  static const rodPump = '$_root/16-oil-and-gas-equipment/04-rod-pump.svg';
  static const topDrive = '$_root/16-oil-and-gas-equipment/05-top-drive.svg';
  static const managedPressureDrilling =
      '$_root/16-oil-and-gas-equipment/06-managed-pressure-drilling-package.svg';
  static const standaloneDerrick =
      '$_root/16-oil-and-gas-equipment/07-standalone-derrick.svg';
  static const kellyBar = '$_root/16-oil-and-gas-equipment/08-kelly-bar.svg';
  static const fishingTools =
      '$_root/16-oil-and-gas-equipment/09-fishing-tools.svg';
  static const oilGasMudTank =
      '$_root/16-oil-and-gas-equipment/10-mud-tank.svg';
  static const mobileCompressor =
      '$_root/16-oil-and-gas-equipment/11-mobile-compressor.svg';
  static const wellServiceUnit =
      '$_root/16-oil-and-gas-equipment/12-well-service-unit.svg';
  static const coilTubingServiceTruck =
      '$_root/16-oil-and-gas-equipment/13-coil-tubing-service-truck.svg';

  static const drillStem = '$_root/17-pipe-and-materials/01-drill-stem.svg';
  static const linePipe = '$_root/17-pipe-and-materials/02-line-pipe.svg';
  static const octgBundle = '$_root/17-pipe-and-materials/03-octg-bundle.svg';
  static const culvert = '$_root/17-pipe-and-materials/04-culvert.svg';
  static const fittingsAssortment =
      '$_root/17-pipe-and-materials/05-generic-fittings-assortment.svg';
  static const steelPlate = '$_root/17-pipe-and-materials/06-steel-plate.svg';
  static const pipeNipples = '$_root/17-pipe-and-materials/07-pipe-nipples.svg';
  static const pipeReducers =
      '$_root/17-pipe-and-materials/08-pipe-reducers.svg';
  static const pipeTees = '$_root/17-pipe-and-materials/09-pipe-tees.svg';
  static const pipeCaps = '$_root/17-pipe-and-materials/10-pipe-caps.svg';
  static const pipeThreadingEquipment =
      '$_root/17-pipe-and-materials/11-pipe-threading-equipment.svg';
  static const pipeInspectionEquipment =
      '$_root/17-pipe-and-materials/12-pipe-inspection-equipment.svg';
  static const linedPipe =
      '$_root/17-pipe-and-materials/13-pipe-coating-lined-pipe.svg';

  static const cattlePanel =
      '$_root/18-farm-ranch-listings/01-cattle-panel.svg';
  static const bisonPanel =
      '$_root/18-farm-ranch-listings/02-buffalo-bison-panel.svg';
  static const windbreakPanel =
      '$_root/18-farm-ranch-listings/03-windbreak-panel.svg';
  static const fencePost = '$_root/18-farm-ranch-listings/04-fence-post.svg';
  static const continuousFence =
      '$_root/18-farm-ranch-listings/05-continuous-fence.svg';
  static const cattleFeeder =
      '$_root/18-farm-ranch-listings/06-cattle-feeder.svg';
  static const baleFeeder = '$_root/18-farm-ranch-listings/07-bale-feeder.svg';
  static const corralPanel =
      '$_root/18-farm-ranch-listings/08-corral-panel.svg';
  static const livestockShelter =
      '$_root/18-farm-ranch-listings/09-livestock-shelter.svg';
  static const customPipeFabrication =
      '$_root/18-farm-ranch-listings/10-custom-pipe-fabrication.svg';
  static const portableLivestockShelter =
      '$_root/18-farm-ranch-listings/11-portable-livestock-shelter.svg';

  static const fracTank = '$_root/19-tanks-and-containers/01-frac-tank.svg';
  static const chemicalTank =
      '$_root/19-tanks-and-containers/02-chemical-tank.svg';
  static const propaneTank =
      '$_root/19-tanks-and-containers/03-propane-tank.svg';
  static const vaultTank = '$_root/19-tanks-and-containers/04-vault-tank.svg';
  static const tankSkid = '$_root/19-tanks-and-containers/05-tank-skid.svg';
  static const waterTank = '$_root/19-tanks-and-containers/06-water-tank.svg';
  static const tankMudTank = '$_root/19-tanks-and-containers/07-mud-tank.svg';
  static const containmentTank =
      '$_root/19-tanks-and-containers/08-portable-containment-tank.svg';
  static const openTopTank =
      '$_root/19-tanks-and-containers/09-open-top-tank.svg';
  static const doubleWallFuelTank =
      '$_root/19-tanks-and-containers/10-double-wall-fuel-tank.svg';

  static const rollOffTruck =
      '$_root/20-transport-and-dispatch-equipment/01-roll-off-truck.svg';
  static const winchTruck =
      '$_root/20-transport-and-dispatch-equipment/02-winch-truck.svg';
  static const waterTruck =
      '$_root/20-transport-and-dispatch-equipment/03-water-truck.svg';
  static const hotshotGooseneck =
      '$_root/20-transport-and-dispatch-equipment/04-hotshot-gooseneck.svg';
  static const pipeHaulingTruck =
      '$_root/20-transport-and-dispatch-equipment/05-pipe-hauling-truck-trailer.svg';
  static const oversizeLoad =
      '$_root/20-transport-and-dispatch-equipment/06-oversize-load-combination.svg';
  static const oilfieldServiceTruck =
      '$_root/20-transport-and-dispatch-equipment/07-oilfield-service-truck.svg';
  static const routeSurveyVehicle =
      '$_root/20-transport-and-dispatch-equipment/08-route-survey-vehicle.svg';
  static const trafficControlVehicle =
      '$_root/20-transport-and-dispatch-equipment/09-traffic-control-vehicle.svg';
  static const hazmatCarrier =
      '$_root/20-transport-and-dispatch-equipment/10-hazmat-carrier.svg';
  static const poleTrailer =
      '$_root/20-transport-and-dispatch-equipment/11-pole-trailer.svg';
  static const multiAxleTrailer =
      '$_root/20-transport-and-dispatch-equipment/12-multi-axle-heavy-haul-trailer.svg';
  static const jeepBooster =
      '$_root/20-transport-and-dispatch-equipment/13-jeep-booster-combination.svg';
  static const specializedBedTruck =
      '$_root/20-transport-and-dispatch-equipment/14-specialized-bed-truck.svg';

  static const crewShack = '$_root/21-portable-buildings/01-crew-shack.svg';
  static const lunchroom = '$_root/21-portable-buildings/02-lunchroom.svg';
  static const bathroomUnit =
      '$_root/21-portable-buildings/03-bathroom-unit.svg';
  static const storageUnit = '$_root/21-portable-buildings/04-storage-unit.svg';
  static const containerOffice =
      '$_root/21-portable-buildings/05-container-office.svg';
  static const portableBuildingLivestockShelter =
      '$_root/21-portable-buildings/06-livestock-shelter.svg';
  static const changeRoom = '$_root/21-portable-buildings/07-change-room.svg';
  static const sleeperUnit = '$_root/21-portable-buildings/08-sleeper-unit.svg';
  static const firstAidBuilding =
      '$_root/21-portable-buildings/09-first-aid-building.svg';
  static const portableWorkshop =
      '$_root/21-portable-buildings/10-portable-workshop.svg';

  static const lightTower = '$_root/22-site-support/01-light-tower.svg';
  static const weldingMachine = '$_root/22-site-support/02-welding-machine.svg';
  static const scissorLift = '$_root/22-site-support/03-scissor-lift.svg';
  static const boomLift = '$_root/22-site-support/04-boom-lift.svg';
  static const materialCage = '$_root/22-site-support/05-material-cage.svg';
  static const spillKit = '$_root/22-site-support/06-spill-kit.svg';
  static const mobileAirCompressor =
      '$_root/22-site-support/07-mobile-air-compressor.svg';
  static const portableHeater = '$_root/22-site-support/08-portable-heater.svg';
  static const temporaryPower =
      '$_root/22-site-support/09-temporary-power-distribution.svg';
  static const waterPumpTrailer =
      '$_root/22-site-support/10-water-pump-trailer.svg';
  static const mobileGeneratorTrailer =
      '$_root/22-site-support/11-mobile-generator-trailer.svg';

  static const leaseLand = '$_root/23-sites-and-property/01-lease-land.svg';
  static const pipelineCorridor =
      '$_root/23-sites-and-property/02-pipeline-corridor.svg';
  static const batterySite = '$_root/23-sites-and-property/03-battery-site.svg';
  static const industrialRealEstate =
      '$_root/23-sites-and-property/04-industrial-real-estate.svg';
  static const accessRoadEntrance =
      '$_root/23-sites-and-property/05-access-road-entrance.svg';
  static const laydownYard = '$_root/23-sites-and-property/06-laydown-yard.svg';
  static const railSiding = '$_root/23-sites-and-property/07-rail-siding.svg';
  static const loadingFacility =
      '$_root/23-sites-and-property/08-loading-facility.svg';
  static const gravelPit = '$_root/23-sites-and-property/09-gravel-pit.svg';
  static const farmRanchYard =
      '$_root/23-sites-and-property/10-farm-ranch-yard.svg';

  static const forSaleListing =
      '$_root/24-marketplace-workflows/01-for-sale-listing.svg';
  static const browseMarketplace =
      '$_root/24-marketplace-workflows/02-browse-marketplace.svg';
  static const sellCreateListing =
      '$_root/24-marketplace-workflows/03-sell-create-listing.svg';
  static const makeOffer = '$_root/24-marketplace-workflows/04-make-offer.svg';
  static const counteroffer =
      '$_root/24-marketplace-workflows/05-counteroffer.svg';
  static const offerAccepted =
      '$_root/24-marketplace-workflows/06-offer-accepted.svg';
  static const offerDeclined =
      '$_root/24-marketplace-workflows/07-offer-declined.svg';
  static const offerArchived =
      '$_root/24-marketplace-workflows/08-offer-archived.svg';
  static const negotiationHistory =
      '$_root/24-marketplace-workflows/09-negotiation-history.svg';
  static const savedWatchlist =
      '$_root/24-marketplace-workflows/10-saved-watchlist.svg';
  static const auctionReserve =
      '$_root/24-marketplace-workflows/11-auction-reserve.svg';
  static const buyItNow = '$_root/24-marketplace-workflows/12-buy-it-now.svg';
  static const auctionCountdown =
      '$_root/24-marketplace-workflows/13-auction-countdown.svg';
  static const bidHistory =
      '$_root/24-marketplace-workflows/14-bid-history.svg';
  static const winningBidder =
      '$_root/24-marketplace-workflows/15-winning-bidder.svg';
  static const truckingQuote =
      '$_root/24-marketplace-workflows/16-trucking-quote.svg';
  static const freightEstimate =
      '$_root/24-marketplace-workflows/17-freight-estimate.svg';
  static const weighScale =
      '$_root/24-marketplace-workflows/18-weigh-scale.svg';
  static const borderCrossing =
      '$_root/24-marketplace-workflows/19-border-crossing.svg';
  static const savedRouteLane =
      '$_root/24-marketplace-workflows/20-saved-route-lane.svg';
  static const sellerPublicProfile =
      '$_root/24-marketplace-workflows/21-seller-public-profile.svg';
  static const businessProfile =
      '$_root/24-marketplace-workflows/22-business-profile.svg';
  static const verificationScore =
      '$_root/24-marketplace-workflows/23-verification-score.svg';
  static const notificationCentre =
      '$_root/24-marketplace-workflows/24-notification-centre.svg';

  static const reportListing =
      '$_root/25-reporting-and-administration/01-report-listing.svg';
  static const reportMessage =
      '$_root/25-reporting-and-administration/02-report-message.svg';
  static const evidenceAttachment =
      '$_root/25-reporting-and-administration/03-evidence-attachment.svg';
  static const duplicateListing =
      '$_root/25-reporting-and-administration/04-duplicate-listing.svg';
  static const duplicatePhoto =
      '$_root/25-reporting-and-administration/05-duplicate-photo.svg';
  static const fraudScam =
      '$_root/25-reporting-and-administration/06-fraud-scam.svg';
  static const hatefulContent =
      '$_root/25-reporting-and-administration/07-racist-hateful-content.svg';
  static const abusiveContent =
      '$_root/25-reporting-and-administration/08-vulgar-abusive-content.svg';
  static const harassmentThreats =
      '$_root/25-reporting-and-administration/09-harassment-threats.svg';
  static const prohibitedItem =
      '$_root/25-reporting-and-administration/10-prohibited-item.svg';
  static const misleadingDescription =
      '$_root/25-reporting-and-administration/11-misleading-description.svg';
  static const aiModeration =
      '$_root/25-reporting-and-administration/12-ai-moderation.svg';
  static const adminReviewQueue =
      '$_root/25-reporting-and-administration/13-admin-review-queue.svg';
  static const resolvedReport =
      '$_root/25-reporting-and-administration/14-resolved-report.svg';
  static const rejectedReport =
      '$_root/25-reporting-and-administration/15-rejected-report.svg';

  /// Resolves the small, controlled list of Dispatch fleet types.
  ///
  /// This is intentionally separate from [forLabel] because "tractor" means
  /// a highway tractor inside Dispatch but usually means farm equipment in
  /// the Marketplace catalog.
  static String? forVehicleType(String? value) {
    final type = value?.trim().toLowerCase() ?? '';
    return switch (type) {
      'truck' || 'tractor' || 'highway tractor' => semiTruck,
      'pickup' || 'pickup truck' => pickupFlatbed,
      'hotshot' || 'hotshot truck' => hotshotGooseneck,
      'pilot truck' || 'pilot / escort' || 'escort truck' => escortPickup,
      'flat deck' || 'flatbed' => flatbedTrailer,
      'step deck' || 'drop deck' => stepDeckTrailer,
      'lowboy' => lowboyTrailer,
      'winch truck' => winchTruck,
      _ => forLabel(value),
    };
  }

  static String? forLabel(String? value) {
    final label = value?.trim().toLowerCase() ?? '';
    if (label.isEmpty) return null;

    if (label == 'pipe, tubing & materials') return pipeBundle;

    if (label == 'browse' ||
        _containsAny(label, ['browse marketplace', 'browse listings'])) {
      return browseMarketplace;
    }
    if (label == 'sell' ||
        _containsAny(label, ['sell/create listing', 'create listing'])) {
      return sellCreateListing;
    }
    if (_containsAny(label, ['for sale listing', 'marketplace listing'])) {
      return forSaleListing;
    }
    if (_containsAny(label, ['counteroffer', 'counter offer'])) {
      return counteroffer;
    }
    if (_containsAny(label, ['offer accepted', 'accepted offer'])) {
      return offerAccepted;
    }
    if (_containsAny(label, ['offer declined', 'declined offer'])) {
      return offerDeclined;
    }
    if (_containsAny(label, ['offer archived', 'archived offer'])) {
      return offerArchived;
    }
    if (_containsAny(label, ['negotiation history', 'offer history'])) {
      return negotiationHistory;
    }
    if (_containsAny(label, ['make an offer', 'make offer'])) return makeOffer;
    if (_containsAny(
        label, ['saved watchlist', 'saved listings', 'watchlist'])) {
      return savedWatchlist;
    }
    if (_containsAny(label, ['auction reserve', 'reserve bid'])) {
      return auctionReserve;
    }
    if (_containsAny(label, ['buy it now'])) return buyItNow;
    if (_containsAny(label, ['auction countdown', 'auction timer'])) {
      return auctionCountdown;
    }
    if (_containsAny(label, ['bid history', 'bidding history'])) {
      return bidHistory;
    }
    if (_containsAny(label, ['winning bidder', 'auction winner'])) {
      return winningBidder;
    }
    if (_containsAny(label, ['trucking quote', 'carrier quote'])) {
      return truckingQuote;
    }
    if (_containsAny(label, ['freight estimate', 'shipping estimate'])) {
      return freightEstimate;
    }
    if (_containsAny(label, ['weigh scale', 'weigh station'])) {
      return weighScale;
    }
    if (_containsAny(label, ['border crossing'])) return borderCrossing;
    if (_containsAny(label, ['saved route', 'saved lane'])) {
      return savedRouteLane;
    }
    if (_containsAny(label, ['seller public profile', 'public profile'])) {
      return sellerPublicProfile;
    }
    if (_containsAny(label, ['business profile'])) return businessProfile;
    if (_containsAny(label, ['verification score', 'profile verification'])) {
      return verificationScore;
    }
    if (_containsAny(label, ['notification centre', 'notification center'])) {
      return notificationCentre;
    }

    if (_containsAny(label, ['report listing'])) return reportListing;
    if (_containsAny(label, ['report message'])) return reportMessage;
    if (_containsAny(label, ['evidence attachment', 'attach evidence'])) {
      return evidenceAttachment;
    }
    if (_containsAny(label, ['duplicate listing'])) return duplicateListing;
    if (_containsAny(label,
        ['duplicate photo', 'same photo', 'reused photo', 'photos reused'])) {
      return duplicatePhoto;
    }
    if (_containsAny(label, ['fraud', 'scam'])) return fraudScam;
    if (_containsAny(label, ['racist', 'hateful', 'hate speech'])) {
      return hatefulContent;
    }
    if (_containsAny(
        label, ['vulgar', 'abusive content', 'offensive language'])) {
      return abusiveContent;
    }
    if (_containsAny(label, ['harassment', 'threat'])) return harassmentThreats;
    if (_containsAny(label, ['prohibited item', 'prohibited or unsafe'])) {
      return prohibitedItem;
    }
    if (_containsAny(
        label, ['misleading description', 'misleading information'])) {
      return misleadingDescription;
    }
    if (_containsAny(label, ['ai moderation', 'automated moderation'])) {
      return aiModeration;
    }
    if (_containsAny(label, ['admin review queue', 'review queue'])) {
      return adminReviewQueue;
    }
    if (_containsAny(label, ['resolved report'])) return resolvedReport;
    if (_containsAny(label, ['rejected report'])) return rejectedReport;

    if (_containsAny(label, ['managed pressure drilling', 'mpd package'])) {
      return managedPressureDrilling;
    }
    if (_containsAny(label, ['standalone derrick'])) return standaloneDerrick;
    if (_containsAny(label, ['well service unit'])) return wellServiceUnit;
    if (_containsAny(label, ['coil tubing service truck'])) {
      return coilTubingServiceTruck;
    }
    if (_containsAny(label, ['mobile air compressor'])) {
      return mobileAirCompressor;
    }
    if (_containsAny(label, ['mobile compressor'])) return mobileCompressor;
    if (_containsAny(label, ['heater treater'])) return heaterTreater;
    if (_containsAny(label, ['rod pump'])) return rodPump;
    if (_containsAny(label, ['top drive'])) return topDrive;
    if (_containsAny(label, ['kelly bar'])) return kellyBar;
    if (_containsAny(label, ['fishing tools'])) return fishingTools;
    if (_containsAny(label, ['mud tank'])) return oilGasMudTank;
    if (_containsAny(label, ['wellhead'])) return wellhead;
    if (_containsAny(label, ['separator'])) return separator;

    if (_containsAny(label, ['pipe coating', 'lined pipe'])) return linedPipe;
    if (_containsAny(label, ['pipe inspection equipment'])) {
      return pipeInspectionEquipment;
    }
    if (_containsAny(label, ['pipe threading equipment'])) {
      return pipeThreadingEquipment;
    }
    if (_containsAny(label, ['pipe nipples', 'pipe nipple'])) {
      return pipeNipples;
    }
    if (_containsAny(label, ['pipe reducers', 'pipe reducer'])) {
      return pipeReducers;
    }
    if (_containsAny(label, ['pipe tees', 'pipe tee'])) return pipeTees;
    if (_containsAny(label, ['pipe caps', 'pipe cap'])) return pipeCaps;
    if (_containsAny(label, ['generic fittings', 'fittings assortment'])) {
      return fittingsAssortment;
    }
    if (_containsAny(label, ['drill stem'])) return drillStem;
    if (_containsAny(label, ['line pipe'])) return linePipe;
    if (_containsAny(label, ['octg'])) return octgBundle;
    if (_containsAny(label, ['culvert'])) return culvert;
    if (_containsAny(label, ['steel plate'])) return steelPlate;

    if (_containsAny(label, ['buffalo', 'bison panel'])) return bisonPanel;
    if (_containsAny(label, ['windbreak panel'])) return windbreakPanel;
    if (_containsAny(label, ['continuous fence'])) return continuousFence;
    if (_containsAny(label, ['cattle feeder'])) return cattleFeeder;
    if (_containsAny(label, ['bale feeder'])) return baleFeeder;
    if (_containsAny(label, ['corral panel'])) return corralPanel;
    if (_containsAny(label, ['cattle panel'])) return cattlePanel;
    if (_containsAny(label, ['fence post'])) return fencePost;
    if (_containsAny(label, ['custom pipe fabrication'])) {
      return customPipeFabrication;
    }
    if (_containsAny(label, ['portable livestock shelter'])) {
      return portableLivestockShelter;
    }
    if (_containsAny(label, ['livestock shelter'])) return livestockShelter;

    if (_containsAny(label, ['double wall fuel tank'])) {
      return doubleWallFuelTank;
    }
    if (_containsAny(label, ['portable containment tank'])) {
      return containmentTank;
    }
    if (_containsAny(label, ['open top tank'])) return openTopTank;
    if (_containsAny(label, ['frac tank'])) return fracTank;
    if (_containsAny(label, ['chemical tank'])) return chemicalTank;
    if (_containsAny(label, ['propane tank'])) return propaneTank;
    if (_containsAny(label, ['vault tank'])) return vaultTank;
    if (_containsAny(label, ['tank skid'])) return tankSkid;
    if (_containsAny(label, ['water tank'])) return waterTank;

    if (_containsAny(label, ['pipe hauling truck', 'pipe hauling'])) {
      return pipeHaulingTruck;
    }
    if (_containsAny(label, ['hotshot gooseneck', 'hotshot truck'])) {
      return hotshotGooseneck;
    }
    if (_containsAny(label, ['oversize load'])) return oversizeLoad;
    if (_containsAny(label, ['oilfield service truck'])) {
      return oilfieldServiceTruck;
    }
    if (_containsAny(label, ['route survey'])) return routeSurveyVehicle;
    if (_containsAny(label, ['traffic control'])) return trafficControlVehicle;
    if (_containsAny(label, ['hazmat'])) return hazmatCarrier;
    if (_containsAny(label, ['multi axle', 'multi-axle'])) {
      return multiAxleTrailer;
    }
    if (_containsAny(label, ['jeep booster', 'jeep and booster'])) {
      return jeepBooster;
    }
    if (_containsAny(label, ['specialized bed truck', 'bed truck'])) {
      return specializedBedTruck;
    }
    if (_containsAny(label, ['roll off truck', 'roll-off truck'])) {
      return rollOffTruck;
    }
    if (_containsAny(label, ['winch truck'])) return winchTruck;
    if (_containsAny(label, ['water truck'])) return waterTruck;
    if (_containsAny(label, ['pole trailer'])) return poleTrailer;

    if (_containsAny(label, ['first aid building'])) return firstAidBuilding;
    if (_containsAny(label, ['portable workshop'])) return portableWorkshop;
    if (_containsAny(label, ['container office'])) return containerOffice;
    if (_containsAny(label, ['bathroom unit'])) return bathroomUnit;
    if (_containsAny(label, ['storage unit'])) return storageUnit;
    if (_containsAny(label, ['change room'])) return changeRoom;
    if (_containsAny(label, ['sleeper unit'])) return sleeperUnit;
    if (_containsAny(label, ['crew shack'])) return crewShack;
    if (_containsAny(label, ['lunchroom'])) return lunchroom;

    if (_containsAny(label, ['temporary power'])) return temporaryPower;
    if (_containsAny(label, ['water pump trailer'])) return waterPumpTrailer;
    if (_containsAny(label, ['mobile generator trailer'])) {
      return mobileGeneratorTrailer;
    }
    if (_containsAny(label, ['welding machine'])) return weldingMachine;
    if (_containsAny(label, ['scissor lift'])) return scissorLift;
    if (_containsAny(label, ['boom lift'])) return boomLift;
    if (_containsAny(label, ['material cage'])) return materialCage;
    if (_containsAny(label, ['spill kit'])) return spillKit;
    if (_containsAny(label, ['portable heater'])) return portableHeater;
    if (_containsAny(label, ['light tower'])) return lightTower;

    if (_containsAny(label, ['access road entrance'])) {
      return accessRoadEntrance;
    }
    if (_containsAny(label, ['industrial real estate'])) {
      return industrialRealEstate;
    }
    if (_containsAny(label, ['commercial property', 'business for sale'])) {
      return industrialOffice;
    }
    if (_containsAny(label, ['farm & ranch land', 'farm and ranch land'])) {
      return farmRanchYard;
    }
    if (_containsAny(label, [
      'oil & gas lease',
      'oil and gas lease',
      'mineral rights',
      'surface rights'
    ])) {
      return leaseLand;
    }
    if (label == 'pipeline' ||
        _containsAny(label, ['pipeline corridor', 'pipeline right of way'])) {
      return pipelineCorridor;
    }
    if (_containsAny(label, ['farm ranch yard', 'farm or ranch yard'])) {
      return farmRanchYard;
    }
    if (_containsAny(label, ['loading facility'])) return loadingFacility;
    if (_containsAny(label, ['laydown yard'])) return laydownYard;
    if (_containsAny(label, ['battery site'])) return batterySite;
    if (_containsAny(label, ['lease land'])) return leaseLand;
    if (_containsAny(label, ['rail siding'])) return railSiding;
    if (_containsAny(label, ['gravel pit'])) return gravelPit;

    if (_containsAny(label, ['wanted part', 'parts wanted'])) {
      return wantedParts;
    }
    if (_containsAny(label, ['wanted', 'seeking equipment'])) {
      return wantedEquipment;
    }
    if (_containsAny(label, ['request for quote', 'buyer rfq', 'rfq'])) {
      return buyerRfq;
    }
    if (_containsAny(label, ['dispatch load board', 'load board'])) {
      return dispatchLoadBoard;
    }
    if (_containsAny(label, ['carrier bidding', 'carrier bid'])) {
      return carrierBidding;
    }
    if (_containsAny(label, ['bid comparison', 'compare bids'])) {
      return bidComparison;
    }
    if (_containsAny(label, ['awarded load', 'load awarded'])) {
      return awardedLoad;
    }
    if (_containsAny(label, ['live truck tracking', 'truck tracking'])) {
      return liveTruckTracking;
    }
    if (_containsAny(label, ['urgent dispatch', 'urgent load'])) {
      return urgentDispatch;
    }
    if (_containsAny(label, ['multi-stop', 'multiple stop'])) {
      return multiStopRoute;
    }

    if (_containsAny(label, ['message', 'conversation', 'chat'])) {
      return messages;
    }
    if (_containsAny(label, ['auction', 'bid', 'gavel'])) {
      return complianceGavel;
    }
    if (_containsAny(label, ['dispatch dashboard', 'monitoring dashboard'])) {
      return dashboard;
    }
    if (_containsAny(label, ['inspection', 'checklist', 'recertification'])) {
      return inspection;
    }
    if (_containsAny(label, ['verification', 'verified', 'safety shield'])) {
      return safetyShield;
    }
    if (_containsAny(label, ['warning', 'report', 'compliance document'])) {
      return warningDocument;
    }
    if (_containsAny(label, ['calendar', 'booking', 'schedule'])) {
      return bookingCalendar;
    }

    // Equipment artwork represents reusable equipment families, never an
    // individual manufacturer or model. A CAT 320 and any other excavator,
    // for example, intentionally resolve to the same excavator illustration.
    if (_containsAny(label, ['mini excavator'])) return miniExcavator;
    if (_containsAny(label, ['crawler excavator', 'excavator'])) {
      return crawlerExcavator;
    }
    if (_containsAny(label, ['backhoe'])) return crawlerExcavator;
    if (_containsAny(
        label, ['skid steer', 'compact track loader', 'compact loader'])) {
      return skidSteer;
    }
    if (_containsAny(label, ['wheel loader', 'front end loader', 'loader'])) {
      return wheelLoader;
    }
    if (_containsAny(label, ['mobile crane', 'crawler crane', 'crane'])) {
      return craneTruck;
    }
    if (_containsAny(label, ['compactor', 'road roller', 'soil roller'])) {
      return bulldozer;
    }
    if (_containsAny(label, ['stock water tank'])) return stockWaterTank;
    if (_containsAny(label, ['mud pump'])) return mudPump;
    if (_containsAny(label, ['cement bulk trailer'])) return cementBulkTrailer;
    if (_containsAny(label, ['annular bop'])) return annularBop;
    if (_containsAny(label, ['ram bop'])) return ramBop;
    if (_containsAny(label, ['bop stack', 'blowout preventer', 'bop'])) {
      return bopStack;
    }
    if (_containsAny(label, ['pdc bit', 'pdc drill bit'])) return pdcBit;
    if (_containsAny(label, ['tricone bit', 'tricone drill bit'])) {
      return triconeBit;
    }
    if (_containsAny(label, ['drill bit'])) return triconeBit;

    if (_containsAny(
        label, ['heavyweight drill pipe', 'heavy weight drill pipe'])) {
      return heavyweightDrillPipe;
    }
    if (_containsAny(label, ['drill pipe'])) return drillPipe;
    if (_containsAny(label, ['drill stem'])) return drillPipe;
    if (_containsAny(label, ['drill collar'])) return drillCollar;
    if (_containsAny(label, ['coiled tubing'])) return coiledTubing;
    if (_containsAny(label, ['production tubing', 'tubing'])) {
      return productionTubing;
    }
    if (_containsAny(label, ['sucker rod'])) return suckerRod;
    if (_containsAny(label, ['pony rod'])) return ponyRod;
    if (_containsAny(label, ['polished rod'])) return polishedRod;
    if (_containsAny(label, ['pup joint'])) return pupJoint;
    if (_containsAny(label, ['tubular coupling'])) return tubularCoupling;
    if (_containsAny(label, ['casing'])) return casing;
    if (_containsAny(label, ['liner'])) return liner;
    if (_containsAny(label, ['flange'])) return pipeFlange;
    if (_containsAny(label, ['elbow'])) return pipeElbow;
    if (_containsAny(label, ['coupling', 'fitting'])) return pipeCoupling;
    if (_containsAny(label, ['valve', 'wellhead', 'manifold'])) {
      return valveManifold;
    }
    if (_containsAny(label, ['pipe rack'])) return pipeRack;
    if (_containsAny(label, [
      'pipe',
      'casing',
      'tubing',
      'sucker rod',
      'octg',
      'culvert',
      'steel plate'
    ])) {
      return pipeBundle;
    }

    if (_containsAny(label, ['ibc', 'tote'])) return ibcTote;
    if (_containsAny(label, ['fuel tank', 'frac tank', 'tank skid'])) {
      return fuelTank;
    }
    if (_containsAny(label, ['water tank', 'chemical tank', 'propane tank'])) {
      return verticalTank;
    }
    if (_containsAny(label, ['tank', 'container'])) return fuelTank;
    if (_containsAny(label, ['pump'])) return industrialPump;
    if (_containsAny(label, ['hose reel'])) return hoseReel;

    if (_containsAny(label, ['detachable gooseneck', 'rgn trailer'])) {
      return detachableGooseneck;
    }
    if (_containsAny(label, ['extendable step deck'])) {
      return extendableStepDeck;
    }
    if (_containsAny(label, ['step deck', 'drop deck'])) return stepDeckTrailer;
    if (_containsAny(label, ['lowboy'])) return lowboyTrailer;
    if (_containsAny(label, ['pilot car'])) return pilotCar;
    if (_containsAny(label, ['escort pickup', 'escort truck'])) {
      return escortPickup;
    }
    if (_containsAny(label, ['vacuum truck'])) return vacuumTruck;
    if (_containsAny(label, ['fuel tanker', 'water truck'])) return fuelTanker;
    if (_containsAny(label, ['crane truck', 'picker'])) return craneTruck;
    if (_containsAny(label, ['pilot truck', 'hotshot'])) {
      return escortPickup;
    }
    if (_containsAny(label, ['flatbed'])) {
      return flatbedTrailer;
    }
    if (_containsAny(
        label, ['semi truck', 'transport', 'hauling', 'freight'])) {
      return semiTruck;
    }

    if (_containsAny(label, ['guard shack', 'guard booth'])) return guardBooth;
    if (_containsAny(label, ['garage', 'tool room'])) return portableGarage;
    if (_containsAny(label, ['modular building'])) return stackedModular;
    if (_containsAny(label, [
      'portable office',
      'crew shack',
      'lunchroom',
      'bathroom unit',
      'container office',
      'portable building'
    ])) {
      return portableOffice;
    }

    if (_containsAny(label, ['bulldozer', 'dozer'])) return bulldozer;
    if (_containsAny(label, ['motor grader', 'grader'])) return motorGrader;
    if (_containsAny(label, ['warehouse forklift', 'forklift'])) {
      return warehouseForklift;
    }
    if (_containsAny(label, ['telehandler'])) return telehandler;
    if (_containsAny(label, ['heavy equipment'])) return crawlerExcavator;

    if (_containsAny(label, ['combine harvester', 'combine'])) {
      return combineHarvester;
    }
    if (_containsAny(label, ['farm tractor', 'tractor'])) return farmTractor;
    if (_containsAny(label, ['round baler', 'baler'])) return roundBaler;
    if (_containsAny(label, ['seed drill'])) return seedDrill;
    if (_containsAny(label, ['livestock trailer'])) return livestockTrailer;
    if (_containsAny(label, ['squeeze chute'])) return squeezeChute;
    if (_containsAny(label, ['ranch gate', 'farm gate'])) return ranchGate;
    if (_containsAny(label, ['hay bale'])) return hayBale;
    if (_containsAny(label, ['manure spreader'])) return manureSpreader;
    if (_containsAny(label, ['farm & ranch', 'farm and ranch'])) {
      return ranchGate;
    }

    if (_containsAny(label, ['shale shaker'])) return shaleShaker;
    if (_containsAny(label, ['tricone bit'])) return triconeBit;
    if (_containsAny(label, ['pdc bit'])) return pdcBit;
    if (_containsAny(label, ['cementing unit'])) return cementingUnit;
    if (_containsAny(label, ['cement head'])) return cementHead;

    if (_containsAny(label, ['pressure vessel', 'separator'])) {
      return pressureVessel;
    }
    if (_containsAny(label, ['air compressor'])) return mobileAirCompressor;
    if (_containsAny(label, ['compressor'])) return compressorSkid;
    if (_containsAny(label, ['generator'])) return generator;
    if (_containsAny(label, ['flare stack'])) return flareStack;
    if (_containsAny(label, ['refinery', 'heater treater'])) return refinery;
    if (_containsAny(label, ['pumpjack'])) return pumpjack;
    if (_containsAny(label, ['drilling rig', 'drill rig', 'derrick'])) {
      return drillingRig;
    }
    if (_containsAny(label, ['oil & gas equipment', 'oilfield & drilling'])) {
      return drillingRig;
    }

    if (_containsAny(label, ['fenced yard', 'gate'])) return fencedYard;
    if (_containsAny(label, ['storage yard'])) return storageYard;
    if (_containsAny(label, ['warehouse'])) return warehouseLocation;
    if (_containsAny(label, ['well site', 'battery site'])) {
      return drillingSite;
    }
    if (_containsAny(label, ['site & property', 'industrial real estate'])) {
      return industrialSite;
    }
    if (_containsAny(label, ['route', 'access road', 'service area'])) {
      return routeMap;
    }
    if (_containsAny(label, ['location', 'destination'])) return locationPin;

    if (_containsAny(label, ['site support'])) return maintenance;
    if (_containsAny(label, ['inventory'])) return inventory;
    return null;
  }

  static bool _containsAny(String label, Iterable<String> values) =>
      values.any(label.contains);
}

class IndustrialAssetIcon extends StatelessWidget {
  const IndustrialAssetIcon({
    super.key,
    this.label,
    this.assetPath,
    required this.size,
    required this.fallback,
    this.borderRadius = 12,
    this.fit = BoxFit.contain,
  });

  final String? label;
  final String? assetPath;
  final double size;
  final Widget fallback;
  final double borderRadius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final path = assetPath ?? IndustrialIconAssets.forLabel(label);
    if (path == null) return fallback;
    return Semantics(
      image: true,
      label: label == null ? 'Industrial category' : '$label illustration',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: SvgPicture.asset(
          path,
          width: size,
          height: size,
          fit: fit,
          placeholderBuilder: (_) => SizedBox.square(
            dimension: size,
            child:
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          errorBuilder: (_, __, ___) => fallback,
        ),
      ),
    );
  }
}

/// Consistent, accessible content for selectable form options.
///
/// Use an industrial asset for catalog/fleet concepts and a familiar Material
/// icon for standard concepts such as email, inspection, or documentation.
class MarketplaceFormOption extends StatelessWidget {
  const MarketplaceFormOption({
    super.key,
    required this.label,
    required this.icon,
    this.assetPath,
    this.subtitle,
    this.iconColor = const Color(0xFF0878E8),
  });

  final String label;
  final IconData icon;
  final String? assetPath;
  final String? subtitle;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox.square(
            dimension: 36,
            child: assetPath == null
                ? DecoratedBox(
                    decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: .09),
                        borderRadius: BorderRadius.circular(9)),
                    child: Icon(icon, size: 21, color: iconColor))
                : IndustrialAssetIcon(
                    label: label,
                    assetPath: assetPath,
                    size: 36,
                    borderRadius: 8,
                    fallback: Icon(icon, size: 21, color: iconColor))),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              maxLines: subtitle == null ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          if (subtitle case final subtitle?)
            Text(subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Color(0xFF66758A))),
        ]))
      ]);
}
