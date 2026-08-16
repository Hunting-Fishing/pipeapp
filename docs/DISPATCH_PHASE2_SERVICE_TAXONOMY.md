# Pipe Buyer Dispatch Phase 2 - Service Taxonomy and Capability Model

**Master plan:** `docs/DISPATCH_NETWORK_MASTER_PLAN.md`  
**Phase:** 2 of 7  
**Official overall progress entering phase:** 33%  
**Phase 2 starting score:** 2/10  
**Phase 2 target after acceptance:** 10/10  
**Overall target after acceptance:** 41%  
**Rule:** Phase 3 is blocked until the Phase 2 engineering and browser acceptance gates are green.

---

## 1. Purpose

Dispatch must stop depending on free-text service names before company profiles, the Yellow Pages directory, matching, and standalone service requests are built.

Phase 2 introduces a stable machine-readable taxonomy while preserving all current `dispatch_carriers` and vehicle service labels for compatibility.

No Firestore migration occurs in this phase.

---

## 2. Stable top-level categories

The taxonomy defines four stable categories:

1. `transportation` - Transportation
2. `pilotOversizeSupport` - Pilot & Oversize Support
3. `craneLifting` - Crane & Lifting
4. `industrialFieldServices` - Oilfield & Industrial Field Services

Each service has:

- a stable lowercase machine code;
- a public display label;
- a category;
- a subcategory code and display label;
- structured capability field codes;
- optional legacy labels for compatibility;
- an optional Directory-featured flag.

Display labels may change later without changing stored service codes.

---

## 3. Required service coverage

### Transportation

Includes flat deck, step deck, lowboy/lowbed, winch truck, hotshot, pipe hauling, heavy-equipment hauling, general freight, local haul, long distance, oversize/overweight, and dangerous-goods/hazmat transport.

### Pilot & Oversize Support

Includes pilot/escort vehicle, lead car, chase car, high-pole car, route survey, traffic control, and permit assistance.

### Crane & Lifting

Includes picker truck, crane truck, mobile crane, knuckle boom, telehandler, forklift, and rigging.

### Oilfield & Industrial Field Services

Includes grading, road maintenance, snow removal, water truck, vacuum truck, hydrovac, mobile mechanic, mobile welding, mobile tire service, fuel/lube service, towing/recovery, equipment servicing, field labour, and site support.

---

## 4. Structured capability model

The taxonomy separates service identity from capabilities.

Examples:

- `max_payload` with canonical kilograms and accepted kg/lb/metric-tonne/US-ton inputs;
- `deck_length` and `deck_width` with canonical metres and accepted metre/foot inputs;
- `high_pole_capable`, `lead_car_capable`, `chase_car_capable`;
- `jurisdictions_served`;
- `rated_lift_capacity` and `maximum_reach`;
- `rigging_available`, `operator_included`;
- `water_capacity`, `vacuum_capacity`;
- `availability_24_7`, `emergency_callout`, `remote_site_capable`;
- `cross_border_capable`, `dangerous_goods_capable`;
- `service_radius`.

Numeric fields define canonical units so matching and future international display conversion are deterministic.

---

## 5. Legacy compatibility

Current Dispatch vehicle/service tags remain valid.

`DispatchServiceTaxonomy.fromLegacyLabel()` bridges existing labels including:

- Flat deck;
- Step deck;
- Lowboy;
- Winch;
- Hotshot;
- Pipe hauling;
- Heavy equipment;
- Oversize load;
- General freight;
- Oilfield service;
- Picker / crane;
- Towing / recovery;
- Local haul;
- Long distance;
- Pilot / escort;
- Route survey;
- Traffic control;
- Hazmat qualified.

This phase does not rewrite existing production documents.

---

## 6. Directory integration

The Phase 1 Directory foundation now reads its featured service chips and four public service groups from the taxonomy instead of maintaining a second hard-coded preview list.

The Directory is still not represented as a finished search engine. Company records, filters, map pins, and public directory projections remain Phase 3 and Phase 4 work.

---

## 7. Acceptance evidence

Engineering gate must prove:

- taxonomy and capability codes are unique stable machine keys;
- every service belongs to a declared category and subcategory;
- every referenced capability field exists;
- numeric capacity fields define canonical and accepted units;
- all required service families exist;
- all current legacy labels resolve to stable codes;
- Directory featured services span pilot, heavy haul, crane, hotshot, grading, and mobile mechanic;
- public taxonomy labels contain no obsolete Auction/bid marketplace terminology;
- strict analyzer passes for taxonomy, Dispatch navigation, and the integrated Dispatch page;
- Phase 1 navigation widget tests remain green.

Browser acceptance must verify:

1. Open Dispatch -> Directory.
2. The Directory shows `Service taxonomy active`.
3. Featured service chips include Pilot / Escort Vehicle, Lowboy / Lowbed, Picker Truck, Hotshot, Grading, and Mobile Mechanic.
4. The four service groups display without overflow at desktop width.
5. The same Directory section remains usable at a narrow/mobile width.
6. Existing provider Pilot/escort equipment remains available below the taxonomy for registered providers.

Only after these checks pass may Phase 2 be marked:

```text
Phase 2: 10/10 GREEN
Overall: 41/100 = 41%
Next permitted phase: Phase 3 - provider and company profile system
```

---

## 8. Change-control boundary

- No Firestore schema migration in Phase 2.
- Do not rewrite legacy provider documents just to adopt stable service codes.
- New provider/company documents introduced in Phase 3 will store stable service codes and structured capability maps.
- Any later label rename must preserve the existing stable service code.
