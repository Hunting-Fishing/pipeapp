"use strict";

const {initializeApp, deleteApp} = require("firebase-admin/app");
const {FieldValue, GeoPoint, getFirestore} = require("firebase-admin/firestore");
const {createDispatchDirectoryProjection} = require("../dispatch_directory_projection");

function localHost(value, label) {
  const normalized = String(value || "").trim();
  if (!/^(127\.0\.0\.1|localhost):\d+$/.test(normalized)) {
    throw new Error(`${label} must point to a local emulator. Refusing: ${normalized}`);
  }
  return normalized;
}

process.env.FIRESTORE_EMULATOR_HOST = localHost(
    process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:18080",
    "FIRESTORE_EMULATOR_HOST",
);

const projectId = process.env.GCLOUD_PROJECT ||
    process.env.GOOGLE_CLOUD_PROJECT ||
    "flutter-flow-pipe";
const app = initializeApp({projectId}, `dispatch-directory-visual-${Date.now()}`);
const db = getFirestore(app);

function area({label, latitude, longitude, radiusKm, regionKeys, placeKeys}) {
  return {
    homeLocation: {
      label,
      point: new GeoPoint(latitude, longitude),
      precision: "approximate_1km",
      source: "service_area_center",
    },
    serviceArea: {
      schemaVersion: 1,
      mode: "radius",
      centerLabel: label,
      center: new GeoPoint(latitude, longitude),
      radiusKm,
      countryCodes: ["CA"],
      regionKeys,
      placeKeys,
      places: [],
    },
  };
}

const fixtures = [
  {
    id: "visual-carrier",
    profile: {
      operatingName: "Northline Heavy Haul",
      businessType: "corporation",
      description:
        "Heavy haul, lowboy, pipe hauling and specialized equipment transport across Western Canada.",
      website: "https://www.pipebuyer.com",
      serviceCodes: [
        "transport_lowboy",
        "transport_pipe_hauling",
        "transport_heavy_equipment",
        "pilot_escort_vehicle",
      ],
      serviceAreaLabel: "Edmonton and Western Canada",
      availability: "available_now",
      emergencyCallout: false,
      remoteSiteCapable: true,
      profileCompleteness: 100,
      ...area({
        label: "Edmonton, Alberta",
        latitude: 53.5461,
        longitude: -113.4938,
        radiusKm: 900,
        regionKeys: ["CA-AB", "CA-BC", "CA-SK"],
        placeKeys: ["edmonton-ab", "grande-prairie-ab", "dawson-creek-bc"],
      }),
    },
  },
  {
    id: "directory-pilot-peace-country",
    profile: {
      operatingName: "Peace Country Pilot & Escort",
      businessType: "owner_operator",
      description:
        "Pilot, chase, lead-car, high-pole and route survey support for oversize moves in the Peace Country.",
      website: "",
      serviceCodes: [
        "pilot_escort_vehicle",
        "pilot_lead_car",
        "pilot_chase_car",
        "pilot_high_pole",
        "pilot_route_survey",
      ],
      serviceAreaLabel: "Fort St. John, Dawson Creek and Peace Country",
      availability: "available_today",
      emergencyCallout: true,
      remoteSiteCapable: true,
      profileCompleteness: 92,
      ...area({
        label: "Fort St. John, British Columbia",
        latitude: 56.2465,
        longitude: -120.8476,
        radiusKm: 450,
        regionKeys: ["CA-BC", "CA-AB"],
        placeKeys: ["fort-st-john-bc", "dawson-creek-bc", "peace-river-ab"],
      }),
    },
  },
  {
    id: "directory-picker-grande-prairie",
    profile: {
      operatingName: "Grande Prairie Picker & Crane",
      businessType: "corporation",
      description:
        "Picker truck and mobile crane support for oilfield equipment, site construction and plant maintenance.",
      website: "",
      serviceCodes: ["crane_picker_truck", "crane_mobile_crane"],
      serviceAreaLabel: "Grande Prairie and northwest Alberta",
      availability: "available_this_week",
      emergencyCallout: true,
      remoteSiteCapable: true,
      profileCompleteness: 95,
      ...area({
        label: "Grande Prairie, Alberta",
        latitude: 55.1707,
        longitude: -118.7947,
        radiusKm: 350,
        regionKeys: ["CA-AB", "CA-BC"],
        placeKeys: ["grande-prairie-ab", "dawson-creek-bc"],
      }),
    },
  },
  {
    id: "directory-grading-dawson-creek",
    profile: {
      operatingName: "Dawson Creek Road & Site Services",
      businessType: "corporation",
      description:
        "Grading and site-road maintenance support for industrial yards, leases and remote access roads.",
      website: "",
      serviceCodes: ["field_grading"],
      serviceAreaLabel: "Dawson Creek and northeast British Columbia",
      availability: "available_now",
      emergencyCallout: false,
      remoteSiteCapable: true,
      profileCompleteness: 88,
      ...area({
        label: "Dawson Creek, British Columbia",
        latitude: 55.7596,
        longitude: -120.2377,
        radiusKm: 300,
        regionKeys: ["CA-BC"],
        placeKeys: ["dawson-creek-bc", "fort-st-john-bc"],
      }),
    },
  },
  {
    id: "directory-hotshot-prairie",
    profile: {
      operatingName: "Prairie Hotshot Services",
      businessType: "owner_operator",
      description:
        "Expedited hotshot and general freight for parts, tools and field equipment throughout northern Alberta.",
      website: "",
      serviceCodes: ["transport_hotshot", "transport_general_freight"],
      serviceAreaLabel: "Grande Prairie and northern Alberta",
      availability: "available_today",
      emergencyCallout: true,
      remoteSiteCapable: true,
      profileCompleteness: 90,
      ...area({
        label: "Grande Prairie, Alberta",
        latitude: 55.1707,
        longitude: -118.7947,
        radiusKm: 500,
        regionKeys: ["CA-AB"],
        placeKeys: ["grande-prairie-ab", "peace-river-ab", "whitecourt-ab"],
      }),
    },
  },
  {
    id: "directory-mobile-mechanic-fsj",
    profile: {
      operatingName: "Northern Mobile Mechanical",
      businessType: "sole_proprietorship",
      description:
        "Mobile mechanic and service-truck support for heavy equipment, trucks and field assets at remote sites.",
      website: "",
      serviceCodes: ["field_mobile_mechanic"],
      serviceAreaLabel: "Fort St. John and northeast British Columbia",
      availability: "available_now",
      emergencyCallout: true,
      remoteSiteCapable: true,
      profileCompleteness: 91,
      ...area({
        label: "Fort St. John, British Columbia",
        latitude: 56.2465,
        longitude: -120.8476,
        radiusKm: 350,
        regionKeys: ["CA-BC"],
        placeKeys: ["fort-st-john-bc", "dawson-creek-bc"],
      }),
    },
  },
];

async function main() {
  const firestoreAccessor = () => db;
  firestoreAccessor.FieldValue = FieldValue;
  const projection = createDispatchDirectoryProjection({
    firestore: firestoreAccessor,
  });

  for (const fixture of fixtures) {
    await db.collection("public_business_profiles").doc(fixture.id).set({
      publicName: fixture.profile.operatingName,
      description: fixture.profile.description,
      website: fixture.profile.website,
      serviceAreaLabel: fixture.profile.serviceAreaLabel,
      dispatchProfile: fixture.profile,
      visualSandbox: true,
    }, {merge: true});
    await db.collection("dispatch_carriers").doc(fixture.id).set({
      status: "active",
      availableForHire: true,
      visualSandbox: true,
    }, {merge: true});
    const result = await projection.syncCompany(fixture.id);
    if (!result.published) {
      throw new Error(`Directory fixture ${fixture.id} did not publish: ${result.reason}`);
    }
  }

  const snapshot = await db.collection("dispatch_directory_entries").get();
  const ids = new Set(snapshot.docs.map((document) => document.id));
  for (const fixture of fixtures) {
    if (!ids.has(fixture.id)) {
      throw new Error(`Directory fixture missing after projection: ${fixture.id}`);
    }
  }

  console.log(`Dispatch Directory visual fixtures ready: ${fixtures.length}`);
}

main()
    .then(() => deleteApp(app))
    .catch(async (error) => {
      console.error(error);
      await deleteApp(app).catch(() => {});
      process.exitCode = 1;
    });
