"""Part 6 catalog expansion: Flashlights, Bi-Directional OBD2 Scanners, Tool Storage, Tool Accessories & Pro/Budget Hand Tools (bringing catalog to 1,500 items across 52 subcategories)."""

from __future__ import annotations

# Verified Amazon ASIN lookup for flagship items so they open direct /dp/<ASIN> product pages
VERIFIED_ASINS: dict[str, tuple[str, str]] = {
    "ridgid-36-aluminum-pipe-wrench": ("B0000224JH", "$245.99"),
    "ridgid-460-tristand-chain-vise": ("B001P3056K", "$414.50"),
    "pb-0025-ridgid-31090-model-810-10-inch-aluminum-straight-pipe-wr": ("B004FCJHNA", "$60.14"),
    "pb-0026-ridgid-31095-model-814-14-inch-aluminum-straight-pipe-wr": ("B0000224JE", "$51.99"),
    "pb-0027-ridgid-31100-model-818-18-inch-aluminum-straight-pipe-wr": ("B0000224JF", "$79.97"),
    "pb-0028-ridgid-31105-model-824-24-inch-aluminum-straight-pipe-wr": ("B0000224JG", "$119.99"),
    "pb-0029-ridgid-31115-model-848-48-inch-aluminum-straight-pipe-wr": ("B0000224JI", "$429.99"),
    "pb-0030-ridgid-31020-model-14-14-inch-heavy-duty-cast-iron-strai": ("B0000224J8", "$51.99"),
    "lincoln-viking-3350-welding-helmet": ("B07XZG78M1", "$532.33"),
    "flange-wizard-two-hole-pins-level": ("B00IORD4O0", "$67.75"),
    "milwaukee-m18-fuel-high-torque-impact": ("B094RDL3QR", "$279.90"),
    "milwaukee-m18-fuel-deep-cut-bandsaw": ("B00LBHJ688", "$399.00"),
    "milwaukee-m18-braking-grinder": ("B09RX4R3TR", "$122.55"),
    "dewalt-impact-socket-set-1-2": ("B01IFSX9M4", "$65.99"),
    "dot-grade-70-transport-chain-4pack": ("B083GBSFP4", "$139.85"),
    "ratchet-load-binders-9200-wll": ("B0G3PBBBJY", "$113.00"),
    "crosby-screw-pin-anchor-shackles": ("B005648RGY", "$55.40"),
    "bw-clip4-multi-gas-detector-h2s": ("B0H15MGT9H", "$489.00"),
    "carhartt-fr-henley-work-shirt": ("B00B4RN6YU", "$68.00"),
    "ansi-a6-oilfield-impact-rigger-gloves": ("B0774WVGFZ", "$25.49"),
    "dot-truck-oil-spill-containment-kit": ("B0FF6WR8CC", "$159.95"),
    "fill-rite-12v-15gpm-fuel-transfer-pump": ("B00B5RDWD4", "$399.00"),
    "milwaukee-m18-cordless-grease-gun": ("B00CMV6DT2", "$239.00"),
    "noco-boost-pro-commercial-jump-starter": ("B015TKSSB8", "$299.95"),
    "milwaukee-m18-rover-magnetic-floodlight": ("B0DMBQ5H8X", "$129.00"),
    "crescent-jobox-48-steel-gang-box": ("B084Y6M494", "$789.00"),
    "ultrasonic-pipe-wall-thickness-gauge": ("B09HTXKJPB", "$149.00"),
    "mitutoyo-stainless-digital-pipe-caliper": ("B00INL0BTS", "$148.00"),
    "gas-powered-pipe-tpost-driver": ("B0DH1BNQYL", "$289.00"),
    "weld-on-steel-barrel-gate-hinges": ("B0GWQBFKBK", "$44.95"),
}

NEW_SUBCATEGORIES_CATALOG: dict[str, list[tuple[str, str, str, str, str]]] = {
    "EDC, Tactical, Magnetic & Rechargeable Flashlights": [
        ("Streamlight", "Streamlight 78101 Stinger 2020 2,000-Lumen Rechargeable Aluminium Duty Flashlight", "Pro Grade • 2,000 lm", "Dual-switch 2,000-lumen aluminum work and inspection flashlight with mode selector and piggyback charger compatibility.", "2,000 lumens high / 24-hr low runtime | Aircraft aluminum body w/ anti-roll grip | IPX7 waterproof & 2m impact rated"),
        ("Streamlight", "Streamlight 66320 MacroStream USB 500-Lumen Compact Rechargeable Pocket EDC Flashlight", "Pro EDC Pick", "Pocket-clip 500-lumen USB rechargeable machined aluminum flashlight for pipefitters, inspectors, and mechanics.", "500 lumens / 90m beam distance | Slide-sleeve protected USB charge port | Removable two-way hat & pocket clip"),
        ("Streamlight", "Streamlight 88810 Wedge 1,000-Lumen Slim Everyday Carry USB-C Rechargeable Flashlight", "Pro Grade • Slim EDC", "Ultra-thin flat-profile aluminum pocket flashlight with rotary thumb switch and 1,000-lumen THRO burst mode.", "1,000-lumen THRO mode / 300-lumen constant | Deep-carry pocket profile | Waterproof USB-C charging port"),
        ("Streamlight", "Streamlight 88812 Wedge XT 500-Lumen Ultra-Compact Tactical Tail-Switch USB-C Flashlight", "Pro Grade • Compact", "Tactical tail-switch version of the Streamlight Wedge with five-LED battery status indicator.", "500 lumens high / 50 lumens low | Anodized aluminum housing | IPX7 waterproof to 1m"),
        ("Streamlight", "Streamlight 74751 Strion LED HL 615-Lumen Rechargeable High-Lumen Mechanics Flashlight", "Pro Shop Standard", "High-lumen rechargeable duty flashlight with clamp-style AC/12V DC smart charger holder for service trucks.", "615 lumens / 219m beam | Borofloat high-temp glass lens | Piggyback truck charger compatible"),
        ("Streamlight", "Streamlight 88065 ProTac HL-X 1,000-Lumen Multi-Fuel USB Rechargeable Tactical Flashlight", "Pro Grade • Multi-Fuel", "TEN-TAP programmable 1,000-lumen tactical inspection flashlight accepting SL-B26 USB battery pack or CR123A cells.", "1,000 lumens / 330m beam | TEN-TAP programmable high/strobe/low | IP68 dust-tight & waterproof"),
        ("Streamlight", "Streamlight 88094 ProTac 90X USB 1,000-Lumen Right-Angle Multi-Fuel Work Flashlight", "Pro Hands-Free", "90-degree right-angle head clips onto FR coveralls, harness straps, or tool belts for hands-free wellhead inspection.", "1,000 lumens right-angle beam | Clips toMOLLE, pocket, or harness | Includes USB rechargeable SL-B26 pack"),
        ("Streamlight", "Streamlight 61500 Septor 7-LED Industrial Hardhat Headlamp w/ Elastic & Rubber Straps", "Pro Hardhat Light", "90-degree tilting 7-LED flood headlamp with rubber hardhat grip strap for night rig-ups.", "Wide flood beam for close pipe work | Includes rubber hardhat & cloth straps | Lightweight water-resistant Polymer"),
        ("Fenix", "Fenix PD36R Pro 2,800-Lumen Dual-Tail-Switch USB-C Rechargeable Tactical Flashlight", "Pro Grade • 2,800 lm", "Heavy-duty 2,800-lumen 21700 Li-ion tactical flashlight with 380m throw for lease-road and tank battery inspection.", "2,800 lumens max / 380m throw | Includes 5,000mAh 21700 battery | IP68 submersible 2m & A6061-T6 aluminum"),
        ("Fenix", "Fenix TK20R V2.0 3,000-Lumen Long-Range Rechargeable Industrial Patrol Flashlight", "Pro Grade • 475m Throw", "Internal waterproof USB-C port and dual-spring battery shock absorption for high-vibration service trucks.", "3,000 lumens / 475m long-range beam | Dual tactical tail switches | Hidden inner-thread waterproof USB-C"),
        ("Fenix", "Fenix HM65R-T V2.0 1,600-Lumen Magnesium Alloy Dual-Beam Rechargeable Headlamp", "Pro Magnesium Body", "Featherweight CNC magnesium housing with independent warm-white and cool-white spotlight/floodlight LEDs.", "1,600 lumens combined spot & flood | Ultralight magnesium alloy chassis | BOA-style single-hand headband dial"),
        ("Fenix", "Fenix E35R 3,100-Lumen Compact Magnetic-Tail USB-C EDC Inspection Flashlight", "Pro Magnetic Tail", "4.7-inch pocket flashlight packing 3,100 lumens and a flat magnetic tailcap for sticking to steel pipe and beams.", "3,100 lumens / 260m beam | Strong magnetic base for hands-free work | 5,000mAh 21700 battery included"),
        ("Olight", "Olight Arkfeld Pro 1,300-Lumen Flat EDC Flashlight w/ 365nm UV Leak Detector & Green Pointer", "Pro 3-in-1 Inspector", "Flat pocket inspection light combining a 1,300-lumen white work beam, 900mW 365nm UV dye detector, and class 3R green laser pointer.", "1,300 lm white LED + 365nm UV + Green Laser | Point out overhead pipe runs & UV dye leaks | Magnetic MCC charging cable"),
        ("Olight", "Olight Seeker 4 Pro 4,600-Lumen High-Output Floodlight Flashlight w/ USB-C Charging Holster", "Pro Grade • 4,600 lm", "Rotary stepless dimming dial and 4,600-lumen flood beam with vehicle-mountable charging holster.", "4,600 lumens / 260m flood throw | Stepless rotary brightness dial | Includes vertical truck-mount holster"),
        ("Olight", "Olight Warrior 3S 2,300-Lumen Tactical Proximity-Sensor Rechargeable Duty Flashlight", "Pro Grade • 300m Throw", "TIR optic lens delivering a balanced 2,300-lumen hotspot with 4-level battery & brightness indicators.", "2,300 lumens / 300m beam | Smart proximity downshift protection | Magnetic tail switch + pocket clip"),
        ("Olight", "Olight Baton 4 Premium Edition 1,300-Lumen Micro EDC Flashlight w/ 190-Day Wireless Charging Case", "Pro Micro EDC", "Thumb-sized 1,300-lumen magnetic-base flashlight housed in a 5,000mAh USB-C power-bank charging case.", "1,300 lumens in 2.48-inch body | Charging case gives 5x full recharges | Doubles as emergency phone power bank"),
        ("Olight", "Olight Perun 2 Mini 1,100-Lumen Right-Angle Magnetic Rechargeable Headlamp & Pocket Light", "Pro Right-Angle", "Compact 90-degree magnetic work light and headlamp with red and white LEDs for night mechanics.", "1,100 lumens white + red night-vision mode | Magnetic base sticks to truck hoods | Quick-release silikon headband"),
        ("Nitecore", "Nitecore EDC27 UHi 3,100-Lumen Ultra-Slim Flat Stainless-Steel OLED Display Pocket Flashlight", "Pro OLED Readout", "High-strength PVD titanium-coated stainless steel flat flashlight with real-time OLED voltage and runtime display.", "3,100 lumens TurboStrobe / 305m beam | OLED screen shows remaining runtime | Carbon-fiber composite frame"),
        ("Nitecore", "Nitecore HC65 UHE 2,000-Lumen Triple-Output USB-C Rechargeable Metal Hardhat Headlamp", "Pro Triple-Output", "8-core UHE matrix optics with primary white beam, high-CRI reading floodlight, and red auxiliary light.", "2,000 lumens / 222m beam | Includes 4,000mAh 18650 Li-ion battery | IP68 & 2m impact resistant"),
        ("Pelican", "Pelican 7600 Tactical 900-Lumen Multi-Color (White/Red/Green) USB Rechargeable Police & Rig Flashlight", "Pro Multi-Color", "Combines 900-lumen white inspection beam with dedicated red and green traffic-wand signaling LEDs.", "900 lumens white + red/green signaling | Type III hard anodized finish | IPX8 submersible"),
        ("Coast", "Coast XP11R 2,100-Lumen Slide-Focus Rechargeable-Dual-Power LED Flashlight", "Budget Line • Value Pick", "Slide-focus spot-to-flood optical beam running on included ZITHION-X USB-C battery or 3x AAA alkalines.", "2,100 lumens Turbo / PURE BEAM slide focus | Dual-Power rechargeable or AAA | Budget-friendly lifetime warranty"),
        ("Coast", "Coast Polysteel 600R 710-Lumen Crush-Proof Stainless-Core Polymer Rechargeable Flashlight", "Budget Line • Crushproof", " Fiberglass-reinforced polymer jacket over a welded stainless-steel core built to survive service-truck rollovers.", "710 lumens twist-focus beam | Crushproof, drop-proof & IP54 stormproof | Value industrial workhorse"),
        ("Coast", "Coast HX5R 340-Lumen Slide-Focus USB Rechargeable Pocket Hat-Clip Inspection Flashlight", "Budget Line • Pocket Value", "Affordable two-way clip pocket flashlight with one-handed slide focus for daily inspection checklists.", "340 lumens / 170m spot beam | Integrated flip-cap USB charging | High-value crew hand-out light"),
        ("Astro Pneumatic", "Astro Pneumatic 52SL 500x2-Lumen Dual-Sided Folding Magnetic Wireless-Charging LED Work Light", "Budget Line • Mechanic Pick", "Dual-sided 1,000-lumen folding COB mechanic light with neodymium swivel base magnet and USB-C charging.", "Dual 500-lumen front/back COB arrays | 180° folding magnetic base + top light | Dimmer switch holds any output level"),
        ("Astro Pneumatic", "Astro Pneumatic 65SL 650-Lumen Slim Rechargeable Magnetic Inspection Light w/ Top Torch", "Budget Line • Slim Cob", "Ultra-thin blade inspection light reaches between radiator cores, engine blocks, and valve manifolds.", "650-lumen stepless dimmer COB bar | 20-lb pull magnetic swivel base | High-capacity 3,350mAh Li-ion"),
        ("NEIKO", "NEIKO 40339A 1,000-Lumen Rechargeable Tactical LED Flashlight 2-Pack w/ Zoom Focus", "Budget Line • 2-Pack Value", "Value 2-pack of 1,000-lumen zoomable aluminum flashlights with USB charging for gloveboxes and toolboxes.", "1,000 lumens per light (2-Pack) | 5 light modes + adjustable zoom bezel | Budget Line crew value pack"),
        ("NEIKO", "NEIKO 40347A Cordless Rechargeable Underhood & Magnetic COB LED Mechanics Work Light Bar", "Budget Line • Underhood", "Padded telescoping hooks and magnetic swivel ends for lighting engine bays and electrical cabinets.", "1,200-lumen wide-angle COB LED bar | Extends from 47\" to 77\" hoods | Budget-friendly shop essential"),
        ("WORKPRO", "WORKPRO Rechargeable Magnetic COB LED Folding Work Light & Inspection Flashlight (2-Pack)", "Budget Line • 2-Pack", "360-degree rotating head with magnetic tail and hanging hook for field mechanics and apprentices.", "700 lumens per light (2-Pack) | Magnetic base + 360° swivel body | USB-C cable included"),
        ("DURATECH", "DURATECH 1,200-Lumen Heavy-Duty Aluminum Rechargeable Zoomable Work Flashlight & Penlight Kit", "Budget Line • Combo Kit", "Pairs a full-size 1,200-lumen rechargeable flashlight with a 300-lumen magnetic pocket penlight.", "2-Light combo: 1,200 lm main + 300 lm penlight | IPX4 water-resistant aluminum | Best value apprentice kit"),
        ("VEVOR", "VEVOR 10,000-Lumen Dual-Head Telescoping Tripod LED Jobsite Work Light w/ Weatherproof Cord", "Budget Line • Jobsite Flood", "Detachable dual-head die-cast aluminum LED floodlight on a 70-inch folding steel tripod stand.", "10,000 lumens 5000K daylight output | IP65 waterproof tempered glass heads | Budget Line jobsite floodlight"),
    ],
    "Bi-Directional OBD2 Readers & Diagnostic Scanners": [
        ("Autel", "Autel MaxiCOM MK808S Bi-Directional OBD2 Diagnostic Scanner Tablet (3,000+ Active Tests & 28+ Services)", "Pro Grade • Shop Bestseller", "7-inch touchscreen bi-directional diagnostic tablet performing active solenoid/injector/fuel-pump tests and all-system OEM diagnostics.", "Full Bi-Directional Active Test control | 28+ resets (Oil, EPB, BMS, DPF, SAS, Injector) | Android 11 quad-core w/ AutoVIN"),
        ("Autel", "Autel MaxiCOM MK808BT Pro Wireless Bluetooth Bi-Directional OBD2 Scanner w/ FCA AutoAuth", "Pro Grade • Wireless BT", "Wireless VCI Mini Bluetooth range up to 33 ft so mechanics can actuate relays and clutches from under the hood.", "Wireless Bluetooth VCI + Bi-Directional control | Supports FCA AutoAuth (Chrysler/Ram/Jeep) | Battery & charging system test ready"),
        ("Autel", "Autel MaxiCheck MX900 8-Inch Bi-Directional All-System Scanner w/ CAN-FD & DoIP Protocol Support", "Pro Grade • CAN-FD / DoIP", "High-resolution 8-inch shop scanner supporting 2020–2026 CAN-FD and DoIP vehicles plus 40+ service maintenance functions.", "3,000+ Bi-Directional component tests | Native CAN-FD & DoIP protocol coverage | Pre & Post PDF diagnostic report printing"),
        ("Autel", "Autel MaxiSys MS906 Pro 8-Inch Advanced Bi-Directional Diagnostic & ECU Coding Scanner Tablet", "Pro Grade • ECU Coding", "Master-technician wireless diagnostic platform with online ECU coding, parameterization, and guided VAG functions.", "Advanced ECU Coding + Bi-Directional tests | MaxiVCI V200 wireless CAN-FD/DoIP interface | 11,000mAh 10-hour shop battery"),
        ("Autel", "Autel MaxiTPMS TS508WF Wi-Fi TPMS Relearn, Programming & OBD2 Tire Pressure Diagnostic Tool", "Pro TPMS Standard", "Activates, reads, and OBD2-relearns 99% of OEM TPMS sensors and programs Autel MX-Sensors in seconds.", "OBD2 TPMS relearn + MX-Sensor programming | Wi-Fi lifetime software updates | Reads tire pressure, temp & battery state"),
        ("Launch", "Launch X431 CRP919E BT Wireless Bi-Directional OBD2 Scanner w/ ECU Coding, CAN-FD & DoIP", "Pro Grade • ECU Coding", "DBScar VII Bluetooth VCI scanner with full bi-directional active tests, online ECU coding, and 35+ reset services.", "Full Bi-Directional actuator control + ECU Coding | Native CAN-FD & DoIP w/o adapters | 7-inch Gorilla Glass tablet"),
        ("Launch", "Launch X431 PRO3S+ Elite 10.1-Inch Commercial & Passenger Bi-Directional Diagnostic Workstation", "Pro Grade • 12V & 24V Ready", "Flagship 10.1-inch master shop diagnostic system with topology module mapping and optional HD truck expansion.", "Color-coded CAN-bus Topology Mapping | J2534 reprogramming & guided diagnostics | Supports 150+ global vehicle makes"),
        ("Launch", "Launch Creader Elite 2.0 BBA / FGC Full-System Bi-Directional OBD2 Code Reader & Service Tool", "Budget Line • Bi-Directional", "Pocket-sized touchscreen bi-directional scanner delivering active solenoid/window/pump tests at an entry-level price.", "Full Bi-Directional Active Tests under $160 | All-system code read/clear + live data graphs | Lifetime free Wi-Fi updates"),
        ("Topdon", "Topdon Phoenix Lite 2 8-Inch Pro Bi-Directional Diagnostic Scanner w/ Online ECU Coding & 34+ Resets", "Pro Grade • 2-Yr Updates", "Heavy-duty armored 8-inch shop tablet with wireless MDCI VCI, bi-directional actuation, and 2 years of free updates.", "Full Bi-Directional tests + ECU coding | 34+ maintenance services (DPF, Injector, AdBlue) | 12,600mAh all-day battery"),
        ("Topdon", "Topdon Phoenix Lite 3 CAN-FD Bi-Directional Diagnostic Scanner w/ Topology Mapping", "Pro Grade • Topology Map", "Visual module tree topology display showing every vehicle ECU fault status on one screen with 1-tap active testing.", "Visual ECU Network Topology Map | Bi-Directional control + CAN-FD support | Wireless VCI w/ FCA AutoAuth"),
        ("Topdon", "Topdon ArtiDiag900 Lite Wireless Bi-Directional All-System OBD2 Scanner (8-Inch Tablet)", "Budget Line • Shop Value", "Full-system bi-directional tablet with 8 maintenance resets and Bluetooth VCI designed for independent fleet shops.", "Bi-Directional subsystem & component tests | Bluetooth 5.0 wireless OBD2 dongle | Zero-subscription core diagnostics"),
        ("Topdon", "Topdon TopScan Pro Pocket Bluetooth Bi-Directional OBD2 Scanner & IMMO Key Tool (iOS & Android)", "Budget Line • Pocket BT", "Turns any smartphone or tablet into a bi-directional diagnostic tool with 13 reset services and cylinder power balance tests.", "Pocket Bluetooth Bi-Directional Active Tests | 13 reset services (DPF, Injector, Throttle, EPB) | Built-in repair data library & DTC guide"),
        ("XTOOL", "XTOOL D7S 7-Inch Bi-Directional OBD2 Scanner w/ 36+ Resets, ECU Coding & 3-Year Free Updates", "Budget Line • 3-Yr Free Updates", "Best-value shop diagnostic tablet offering 4,000+ active tests, CAN-FD, and 3 years of included software updates.", "Full Bi-Directional control + 36+ reset services | Includes 3 Years of Free Wi-Fi Updates | 4-in-1 live data graphing & recording"),
        ("XTOOL", "XTOOL D8S 8-Inch Bi-Directional Diagnostic Scanner w/ Topology Mapping & PMI Module Programming", "Pro Grade • Topology & PMI", "8-inch shop tablet with visual CAN topology mapping, Ford/Lincoln/Mazda offline PMI, and ECU coding.", "Module Topology Map + Offline PMI Coding | 38+ service functions + 3-Yr updates | High-speed quad-core processor"),
        ("XTOOL", "XTOOL A30M Wireless Bluetooth All-System Bi-Directional OBD2 Code Reader (Lifetime Free Updates)", "Budget Line • No Subscription", "Cordless Bluetooth VCI dongle pairing with iOS/Android for full bi-directional active tests and 21 service resets with zero annual fees.", "Lifetime Free Updates — $0 annual fee | Bi-Directional tests + 21 maintenance resets | Built-in pin-inspection LED flashlight"),
        ("ANCEL", "ANCEL HD3600 Heavy-Duty Diesel Truck & Equipment Scanner (Full DPF Regen + J1939/J1708 + 12V/24V OBD2)", "Pro Diesel Truck & Equipment", "Dedicated commercial truck and yellow-iron diagnostic tablet for Cummins, Caterpillar, Detroit, Paccar, Mack, Volvo, and Isuzu.", "OEM-level Forced DPF Regeneration & ARD reset | Includes 6-Pin, 9-Pin Deutsch, CAT-9 & 16-Pin cables | Covers Class 4-8 trucks, excavators & pickups"),
        ("ANCEL", "ANCEL HD3400 Heavy-Duty Semi-Truck & Construction Equipment DPF Regen & All-System Scanner", "Budget Line • Diesel DPF", "Cost-effective heavy-duty truck scanner performing stationary DPF regen, speed-limit look-up, and cylinder cutout references.", "Cummins, Paccar, Detroit, Mack, Volvo, CAT DPF | Lifetime free updates for heavy trucks | Plug-and-play 6-pin/9-pin/16-pin kit"),
        ("ANCEL", "ANCEL FX6000 All-System Bi-Directional OBD2 Diagnostic Tablet w/ Injector Coding & 25+ Resets", "Budget Line • All-System", " Ruggedized 6-inch touch diagnostic scanner with physical shortcut buttons for greasy shop hands.", "Bi-Directional actuator tests + 25 resets | Injector coding, ABS bleed, DPF & BMS | Includes hard blow-molded carry case"),
        ("ANCEL", "ANCEL AD410 Enhanced OBD2 Code Reader w/ Live O2 Sensor, EVAP Test & I/M Smog Readiness", "Budget Line • Under $45", "Glovebox plug-and-play OBD2 engine code reader with one-click I/M readiness key and built-in DTC lookup library.", "Reads & clears check-engine codes in seconds | Live data stream graphing + freeze frame | No batteries required — powered by OBD2 port"),
        ("Foxwell", "Foxwell NT809BT Wireless Bluetooth Bi-Directional Diagnostic Tablet (30+ Resets & 3-Yr Free Updates)", "Budget Line • Wireless Value", "7-inch wireless bi-directional diagnostic scanner with ABS auto-bleed, injector coding, and DPF regeneration.", "Full Bi-Directional Active Tests + 30+ Resets | Wireless Bluetooth VCI w/ 3-Yr free updates | One-touch VIN recognition"),
        ("Foxwell", "Foxwell NT630 Plus ABS & SRS Airbag Bi-Directional Scanner w/ Automated Brake Bleed", "Budget Line • ABS/SRS Spec", "Dedicated brake and safety-system scanner capable of cycling ABS solenoids to bleed trapped air from brake lines.", "Cycles ABS pump & valves for solo brake bleeding | Reads/clears ABS, SRS Airbag & SAS faults | Lifetime free online updates"),
        ("Innova", "Innova 5610 OEM-Level Bi-Directional OBD2 Handheld Scanner (Active Tests, Special Functions & ABS Bleed)", "Pro Grade • US Engineered", "ASE-certified handheld bi-directional scanner with physical keypad, active solenoid tests, and RepairSolutions2 app.", "Full Bi-Directional active tests without a tablet | Zero subscription — lifetime free updates | Covers US, Asian & European pickup fleets"),
        ("BlueDriver", "BlueDriver Bluetooth Pro OBD2 Scan Tool for iPhone & Android (All-System ABS/SRS/Transmission + Smog)", "Pro Grade • #1 Bluetooth", "Professional Bluetooth OBD2 sensor matched against a database of 40+ million verified ASE repair fixes.", "Reads OEM enhanced ABS, Airbag & Transmission codes | Live data graphing + Smog check readiness | No subscription fees or in-app charges"),
        ("OTOFIX", "OTOFIX D1 Lite Wireless Bi-Directional Diagnostic Tablet (Powered by Autel Cloud Diagnostics)", "Budget Line • Autel Engine", "Sleek 7-inch wireless bi-directional scanner running Autel diagnostic architecture with 38+ service resets.", "Full Bi-Directional control + 38+ resets | CAN-FD native support + AutoVIN | 2 Years of free software updates"),
        ("Thinkcar", "Thinkcar Thinkdiag 2 CAN-FD Bi-Directional Bluetooth OBD2 Dongle w/ 16 Reset Functions & Active Tests", "Budget Line • CAN-FD Dongle", "Compact OBD2 extension-cable interface supporting 2020+ GM/Ford CAN-FD protocols, ECU coding, and active tests.", "Supports CAN-FD protocol + Bi-Directional tests | Includes heavy-duty braided OBD2 extension cable | 16 maintenance reset functions"),
        ("Lisle", "Lisle 56810 Relay Pro 12V/24V Automotive & Heavy-Duty Truck Relay Circuit Diagnostic Tester", "Pro Fleet Relay Tester", "Tests 4-pin and 5-pin 12V/24V relays off the truck by applying a real load and cycling the internal contacts.", "Tests 12V & 24V relays under actual load | Detects pitted contacts & weak coils instantly | Essential companion to OBD2 scanners"),
        ("OTC", "OTC 3183 12V/24V Digital Heavy-Duty Battery, Starting & Charging System Analyzer w/ Printer", "Pro Fleet Battery Tester", "Tests 100–1700 CCA batteries, 12V/24V starters, and alternators on commercial trucks with removable leads.", "100-1700 CCA test range (AGM, Gel, Flooded) | 12V & 24V commercial diesel charging tests | Built-in thermal receipt printer for work orders"),
        ("Topdon", "Topdon BT200 12V/24V Automotive & Truck Battery Load, Cranking & Alternator Ripple Tester", "Budget Line • Battery Tester", "Color-screen 100–2000 CCA battery and 12V/24V charging analyzer with reverse-polarity protection.", "Tests 12V batteries (100-2000 CCA) & 24V cranking | 99.5% accuracy w/ spark-free copper clamps | Budget Line service truck staple"),
        ("Autel", "Autel PowerScan PS100 12V/24V Electrical Circuit Probe Tester, Power Injector & Short Finder", "Pro Circuit Probe", "All-in-one 12V/24V circuit tester that injects power or ground to activate cooling fans, fuel pumps, and trailer lights directly.", "Activates components w/ positive or ground tip | Instant voltage, polarity, continuity & frequency | 20-ft lead + 20-ft extension reaches trailer taillights"),
        ("VEVOR", "VEVOR Automotive Smoke Machine EVAP Vacuum, Turbo Boost & Intake Pipe Leak Detector w/ Built-In Air Pump", "Budget Line • Smoke Tester", "Pinpoints EVAP, turbo intercooler, exhaust, and vacuum hose leaks in minutes using built-in compressor and pressure gauge.", "Built-in air pump — no shop air required | Dual flowmeter & pressure gauge for micro-leaks | Budget Line diagnostic time-saver"),
    ],
}

NEW_SUBCATEGORIES_CATALOG.update({
    "Tool Storage: Boxes, Modular Systems, Bags & Organizers": [
        ("Milwaukee", "Milwaukee 48-22-8426 PACKOUT 22-Inch Modular Rolling Tool Box w/ 250-Lb Industrial Load Capacity", "Pro Grade • PACKOUT Base", "Impact-resistant polymer rolling base box with 9-inch all-terrain wheels and industrial telescoping extension handle.", "250-lb weight capacity / IP65 weather seal | Metal-reinforced corners & locking point | Connects with all Milwaukee PACKOUT components"),
        ("Milwaukee", "Milwaukee 48-22-8443 PACKOUT 3-Drawer Modular Tool Box w/ Locking Security Bar", "Pro Grade • 3-Drawer", "Front-opening ball-bearing 3-drawer PACKOUT unit allowing tool access without unstacking upper boxes on the service truck.", "50-lb weight capacity per ball-bearing drawer | Padlockable steel security bar keeps drawers shut in transit | Includes quick-adjust drawer dividers"),
        ("Milwaukee", "Milwaukee 48-22-8444 PACKOUT 4-Drawer Modular Mechanics Tool Box w/ Quick-Adjust Dividers", "Pro Grade • 4-Drawer", "Four slim steel-slide drawers engineered for sockets, wrenches, pliers, and diagnostic leads in mobile service vans.", "50-lb rated metal ball-bearing slides | Impact-resistant polymers & locking bar | Customizable small-parts drawer dividers"),
        ("Milwaukee", "Milwaukee 48-22-8432 PACKOUT 11-Compartment Deep IP65 Small Parts & Fitting Organizer", "Pro Grade • IP65 Organizer", "Clear polycarbonate lid locks bins in place so hydraulic fittings, flange bolts, and terminals never migrate between compartments.", "50-lb capacity w/ 6 quick-adjust dividers | No-travel bin seal prevents small part mixing | IP65 rain & jobsite dust protection"),
        ("Milwaukee", "Milwaukee 48-22-8201 PACKOUT 15-Inch Structured Ballistic Nylon Tech & Electrician Tool Tote", "Pro Grade • PACKOUT Tote", "1680D ballistic material open tote with hard molded PACKOUT locking base and 50+ vertical hand-tool pockets.", "Locks directly onto any PACKOUT lid | Tear-resistant 1680D & 1800D ballistic nylon | Padded shoulder strap + steel tape clip"),
        ("Milwaukee", "Milwaukee 48-22-8300 PACKOUT 48-Pocket Jobsite Tech Backpack w/ Hard Molded Locking Base", "Pro Grade • Tech Backpack", "Hardshell impact base snaps onto rolling PACKOUT stacks while holding laptops, OBD2 tablets, meters, and hand tools.", "48 pockets including protected tablet sleeve | Impact-resistant polymer PACKOUT base | Load-bearing harness w/ sternum strap"),
        ("DEWALT", "DEWALT DWST08450 ToughSystem 2.0 22-Inch Modular Rolling Toolbox w/ Patented Auto-Connect Latches", "Pro Grade • ToughSystem 2.0", "250-lb capacity modular rolling chest with 8-inch rough-terrain wheels and one-touch side latches.", "20% larger storage volume vs Gen 1 | IP65 dust & water jet sealed lid | Detachable telescoping handle fits under tonneau covers"),
        ("DEWALT", "DEWALT DWST08320 ToughSystem 2.0 Double-Drawer Modular Mechanics Unit", "Pro Grade • Dual Drawer", "Deep ball-bearing twin drawers for organizing cordless grinders, impact wrenches, and socket sets on the truck.", "Smooth metal ball-bearing drawer slides | One-hand auto-stacking side latches | Bi-material carry handles"),
        ("DEWALT", "DEWALT DWST17820 TSTAK Deep Mobile Rolling Tool Storage Tower (3-Piece Stack)", "Pro Grade • Mobile Stack", "Compact rolling modular stack combining a deep wheeled chest, medium toolbox, and clear-lid organizer.", "Telescoping aluminum handle & 7\" wheels | Heavy-duty metal latches & rust-resistant pins | Ideal for plant maintenance & electrical crews"),
        ("Klein Tools", "Klein Tools 54802MB MODbox Rolling Toolbox w/ 10-Inch Solid Rubber Wheels & One-Hand Release", "Pro Grade • Klein MODbox", "Electrician and lineman modular rolling base featuring 10-inch solid rubber wheels and built-in side rail attachment tracks.", "250-lb rating w/ 10\" flat-free wheels | Fully removable handle fits under truck bed covers | IP65 weather seal & steel-reinforced lock eye"),
        ("Klein Tools", "Klein Tools 55421BP-14 Tradesman Pro 39-Pocket Organizer Tech Backpack w/ Molded Bottom", "Pro Grade • 39-Pocket", "High-visibility orange interior 1680d ballistic weave backpack with hard waterproof molded bottom and hard-case meter pocket.", "39 pockets for insulated drivers, pliers & meters | Fully molded waterproof bottom | Hard front pocket protects safety glasses & gauges"),
        ("Veto Pro Pac", "Veto Pro Pac TECH-MCT Compact Tall 44-Pocket Service Technician Tool Bag", "Pro Grade • 5-Yr Warranty", "Industry-benchmark vertical tool storage bag with polypropylene waterproof base and patented center panel stabilization.", "44 vertical interior & exterior tool pockets | 3mm injection-molded waterproof polypropylene base | Zero-Down-Time 5-Year Warranty"),
        ("Veto Pro Pac", "Veto Pro Pac TECH PAC MC Blackout Service & Diagnostic Backpack", "Pro Grade • Master Tech", "Thermoformed EVA back padding and dual-bay vertical tool storage holding 50+ hand tools plus a diagnostic tablet.", "Quick-release metal locking hook | Waterproof base & YKK oversized zippers | Built for pipeline instrumentation & HVAC/fleet techs"),
        ("Crescent JOBOX", "Crescent JOBOX 60-Inch Heavy-Duty Steel Site-Vault Security Piano-Box Jobsite Chest", "Pro Grade • Site-Vault", "16-gauge reinforced steel jobsite vault with 3-point Grip-Rite locking system and recessed padlock housing.", "Site-Vault security system deters crowbar prying | Built-in 4-way forklift skids | Heavy-duty gas springs lift lid smoothly"),
        ("Weather Guard", "Weather Guard 117-5-02 Defender Aluminum Full-Size Saddle Truck Bed Crossover Toolbox (Gloss Black)", "Pro Grade • Truck Saddle", " Diamond-plate aluminum truck bed crossover box with tamper-resistant push-button locks and automotive weather stripping.", "Fits full-size pickup beds (F-150/250/350, Ram, Silverado) | Dual gas struts & 90-degree lid opening | Extreme protection against rain & road dust"),
        ("RIDGID", "RIDGID Pro Gear System Gen 2.0 3-Piece Modular Rolling Tool Box Cart Tower", "Budget Line • Best Modular Value", "Heavy-duty 3-piece rolling modular storage stack with 9-inch wheels, metal latches, and IP65 water/dust seal at half the cost.", "Includes 22\" Rolling Cart, Medium Toolbox & Organizer | High-impact resin w/ steel latches | Wall-mount bracket compatible"),
        ("CRAFTSMAN", "CRAFTSMAN VERSASTACK 30-Gallon 3-In-1 Rolling Modular Workshop & Truck Tool Tower", "Budget Line • 3-In-1 Tower", "Snap-together 3-box rolling tool tower with 7-inch wheels, small-parts top organizer, and rust-resistant latches.", "3-Piece stack: rolling bin + toolbox + organizer | Telescoping metal handle folds flat | Budget Line favorite for mobile mechanics"),
        ("Husky", "Husky 18-Inch 600D Water-Resistant Wide-Mouth Rolling Tool Bag Tote w/ Telescoping Handle", "Budget Line • Rolling Bag", "Internal steel frame wide-mouth rolling tool bag with 28 pockets and ball-bearing inline skate wheels.", "200-lb load capacity w/ telescoping pull handle | Spun-poly water-resistant fabric | Fits 1/2\" impact wrenches, grinders & socket cases"),
        ("WORKPRO", "WORKPRO 16-Inch Wide-Mouth Heavy-Duty Water-Proof Molded-Base Canvas Tool Storage Bag (41-Pocket)", "Budget Line • Top Value Bag", "Abrasion-resistant 600D polyester tool bag with waterproof hard molded base and wide internal metal-frame opening.", "41 pockets + 8 tool loops | Waterproof hard molded bottom | Under-$40 crew favorite"),
        ("WORKPRO", "WORKPRO 20-Inch Heavy-Duty Contractor Tool Tote Bag w/ Pull-Out Small Parts Organizer Trays", "Budget Line • Tote + Trays", "Combines a top hand-tool compartment with three slide-out clear hardware organizer cases in the lower bay.", "Includes 3 removable small-parts organizer boxes | Padded handle & adjustable shoulder strap | Great for fasteners, fuses & terminals"),
        ("HORUSDY", "HORUSDY 6-Piece Magnetic SAE & Metric Socket Organizer Tray Set (Holds 143 Sockets — 1/4\", 3/8\", 1/2\")", "Budget Line • 143-Socket Set", "Color-coded red SAE and blue Metric magnetic socket holders with soft rubberized base that never scratches tool chest drawers.", "Holds 143 shallow & deep sockets (1/4\", 3/8\", 1/2\") | Powerful ferrite magnetic base holds upside down | Laser-marked size labels on every post"),
        ("HORUSDY", "HORUSDY 4-Piece Magnetic Wrench Organizer Rack Set (Holds 48 SAE & Metric Wrenches)", "Budget Line • 48-Wrench Rack", "Rare-earth magnetic wrench rails keeping 1/4\"–1-1/16\" and 6mm–24mm combination wrenches flat in shallow toolbox drawers.", "Holds 48 wrenches (24 SAE + 24 Metric) | Only 1-1/4\" tall for low-profile drawers | Non-marring magnetic backing"),
        ("NEIKO", "NEIKO 03966A Heavy-Duty Aluminum Rail Magnetic Socket Organizer Set (1/4\", 3/8\", 1/2\" Drive — 80 Clips)", "Budget Line • Aluminum Rails", "Anodized aluminum magnetic rails with 360-degree swivel spring-loaded ball-bearing clips that stick to service truck doors.", "3 Aluminum magnetic rails w/ 80 spring-ball clips | Swivel clips let you read socket sizes from any angle | Mounts vertically on steel walls or lids"),
        ("ARES", "ARES 60054 Plier & Hand Tool Wire Rack Drawer Organizer (15-Slot Non-Slip Coated Steel)", "Budget Line • Plier Rack", "Vinyl-dipped steel wire rack standing 15 pliers, cutters, and vise-grips upright so you can fit 3x more tools per drawer.", "15 slots (10 standard + 5 wide-handle slots) | PVC coating protects insulated handles | Fits standard 3-inch deep mechanics drawers"),
        ("VEVOR", "VEVOR 3-Tier Heavy-Duty Steel Rolling Mechanics Service Cart (450-Lb Capacity w/ Locking Drawer & Pegboard)", "Budget Line • 450-Lb Shop Cart", "Cold-rolled steel 3-shelf rolling tool cart with lockable top drawer, side pegboard hooks, and 4-inch swivel casters.", "450-lb total load capacity | Lockable ball-bearing drawer for scanners & torque wrenches | Silent 360° PU casters w/ 2 brakes"),
        ("VEVOR", "VEVOR 5-Drawer Rolling Tool Chest & Detachable Top Toolbox Combo (2-in-1 Steel Mechanics Cabinet)", "Budget Line • 5-Drawer Chest", "Powder-coated steel 2-in-1 rolling tool cabinet with EVA drawer liners, central key lock, and removable 4-drawer top chest.", "Detachable top chest fits inside bottom cabinet | EVA foam anti-slip liners in every drawer | High-value garage & shop storage"),
        ("Ernst Manufacturing", "Ernst Manufacturing 8450 Socket Boss 18-Inch 3-Rail Twist-Lock Universal Socket Tray (Made in USA)", "Pro Grade • Twist-Lock", "Quarter-turn Twist-Lock clips keep sockets locked tightly onto the tray even when tossed into a service truck bed.", "Holds 57 sockets across 1/4\", 3/8\" & 1/2\" drive | Push-button removable rails | Fuel & solvent resistant — Made in USA"),
        ("Tekton", "Tekton 20-Tool Modular Slotted Wrench Organizer Set (Polypropylene Drawer Trays for 4mm–38mm)", "Budget Line • Modular Trays", "Interlocking two-tone modular wrench organizer slots engineered to hold thin and thick beam wrenches upright.", "Expandable modular snap-together design | Includes adhesive size label sheets (SAE & Metric) | Made in USA"),
        ("Sunex", "Sunex 8003BK Heavy-Duty Fully Welded Locking Steel Service Cart w/ Flip-Top Pry Bar Side Slots", "Pro Grade • Welded Service Cart", "Commercial shop cart with gas-strut locking top bay, deep sliding drawers, and dedicated side slots for long pry bars and extensions.", "350-lb capacity w/ 4\"x2\" heavy lockable casters | Dedicated side pass-throughs for 36\" pry bars | Full-width chrome push handle"),
        ("Pelican", "Pelican 1510 Carry-On Waterproof Crushproof Equipment & Diagnostic Instrument Case w/ Pick-N-Pluck Foam", "Pro Grade • IP67 Crushproof", "MIL-SPEC watertight rolling hard case with stainless steel padlock protectors for ultrasonic NDT gauges, thermal cameras, and OBD2 tablets.", "IP67 watertight, crushproof & dustproof | Customizable Pick-N-Pluck cubed foam | Retractable extension handle & polyurethane wheels"),
    ],
    "Tool Accessories: Bits, Blades, Abrasives & Hole Saws": [
        ("Milwaukee", "Milwaukee 48-32-4082 Shockwave Impact Duty 100-Piece Driver Bit, Nut Driver & Titanium Drill Bit Set", "Pro Grade • 100-Pc Shockwave", "Wear Guard Tip laser-hardened impact driver bits and Custom Alloy76 steel engineered for up to 50x longer life in high-torque impact drivers.", "100-Piece set in PACKOUT-compatible case | Shockzone geometry absorbs peak torque spikes | Includes Torx, Phillips, Square, Hex & magnetic nut drivers"),
        ("Milwaukee", "Milwaukee 48-00-5262 The Torch w/ NITRUS CARBIDE 9-Inch 7-TPI Cast-Iron & Thick Pipe Reciprocating Sawzall Blades (5-Pack)", "Pro Grade • NITRUS Carbide", "Fastest-cutting cast-iron, ductile iron, and schedule 80 black pipe reciprocating blade delivering 3x life over standard carbide teeth.", "9-inch 7-TPI NITRUS Carbide teeth | Cuts cast iron, stainless & thick schedule 80 pipe | Extra-thick 0.060\" blade body prevents whip"),
        ("Milwaukee", "Milwaukee 48-39-0511 44-7/8\" 14-TPI Extreme Metal Bi-Metal Deep-Cut Portable Band Saw Blades (3-Pack)", "Pro Grade • Deep-Cut Bandsaw", "Matrix II high-speed steel teeth with 8% cobalt for clean, burr-free cold cuts on unistrut, conduit, angle iron, and pipe.", "44-7/8\" x 1/2\" x 0.020\" deep-cut size | Cuts 5/32\" to 3/16\" wall structural steel & pipe | Fits Milwaukee, DeWalt & Makita 5\" deep-cut bandsaws"),
        ("Milwaukee", "Milwaukee 49-22-4185 Hole Dozer 28-Piece Bi-Metal All-Purpose Plumber & Electrician Hole Saw Kit", "Pro Grade • 28-Pc Hole Dozer", "Rip Guard tooth form backed by a limited lifetime tooth-break warranty and all-access slots for fast plug ejection.", "28-Piece kit (3/4\" up to 4-3/4\" hole saws) | Thermoset coating cuts 20% faster | PACKOUT-compatible hard organizer case"),
        ("Milwaukee", "Milwaukee 48-89-2332 Red Helix 29-Piece Cobalt Drill Bit Set (1/16\" to 1/2\" in 1/64\" Increments)", "Pro Grade • M35 Cobalt", "135-degree split point and Variable Helix flute geometry for drilling hard stainless steel, cast iron, and Grade 8 bolts.", "29-Piece 1/16\"–1/2\" M35 5% Cobalt index | Quad Edge tip stays cooler & prevents walking | 3-Flat Secure-Grip shanks"),
        ("Milwaukee", "Milwaukee 48-11-1881 M18 REDLITHIUM FORGE XC8.0 High-Output Battery Pack (HD12.0 Power in Smaller Size)", "Pro Grade • FORGE XC8.0", "Tabless cell architecture delivering HD12.0 power in a lighter footprint with 35-minute supercharge to 80%.", "Delivers 12.0Ah power in an 8.0Ah size | Cool-Cycle active air cooling capable | Resistant to jobsite oils, greases & solvents"),
        ("DEWALT", "DEWALT DWA2T40IR FlexTorq 100-Piece Impact Driver Bit & Socket Adapter Set in ToughCase+", "Pro Grade • 100-Pc FlexTorq", "CNC-machined bit tips and Extended FlexTorq Zone transfer optimal torque in heavy structural fastening.", "100-Piece impact bit & nut setter assortment | Connectable ToughCase+ clear-lid box | Magnetic screw lock sleeve included"),
        ("DEWALT", "DEWALT DCB609-2 20V/60V MAX FLEXVOLT 9.0Ah Lithium-Ion Battery 2-Pack", "Pro Grade • FLEXVOLT 9.0Ah", "Automatically switches voltage between 20V MAX (9.0Ah) and 60V MAX (3.0Ah) tools with LED fuel gauge.", "180 Watt-hours per pack (2-Pack) | Runs 20V MAX impacts & 60V MAX pipe grinders | Potted electronics resist moisture & dust"),
        ("Diablo", "Diablo DS0908CF5 Steel Demon 9-Inch 8-TPI Carbide-Tipped Thick Metal Reciprocating Saw Blades (5-Pack)", "Pro Grade • Steel Demon", "TiCo Hi-Density Carbide teeth cut 3/16\" to 9/16\" wall steel pipe, high-strength alloys, and cast iron with 50x life over bi-metal.", "9-inch 8-TPI TiCo Carbide teeth (5-Pack) | Perma-SHIELD non-stick heat coating | 1-inch oversized demolition body for straight pipe cuts"),
        ("Diablo", "Diablo Steel Demon 4-1/2\" x 0.040\" x 7/8\" Type 1 Thin Kerf Metal & Stainless Cut-Off Discs (25-Pack)", "Pro Grade • 25-Pk Cut-Off", "Premium aluminum-oxide grain thin-kerf wheels for fast, low-burr pipe, rebar, and sheet metal cutting on 4-1/2\" angle grinders.", "25-Pack 4-1/2\" x 0.040\" ultra-thin kerf | Fully reinforced for handheld grinder safety | 13,280 max RPM rated"),
        ("Diablo", "Diablo 4-1/2\" x 7/8\" 40-Grit Zirconia Type 29 Conical Steel & Weld Grinding Flap Discs (10-Pack)", "Pro Grade • 10-Pk Flap Discs", "Self-sharpening zirconium grain removes weld beads and bevels pipe edges 10x faster than standard grinding wheels.", "10-Pack 40-Grit Type 29 angled flap discs | Cushioned grinding action reduces vibration | Fits all 4-1/2\" 7/8\"-arbor grinders"),
        ("Lenox", "Lenox 1213299EG 9-Inch 14-TPI Lazar Gold Power Arc Heavy Metal Reciprocating Saw Blades (25-Pack)", "Pro Grade • 25-Pk Bi-Metal", "T2 technology and titanium-nitride edge coating dissipate heat when cutting structural steel, pipe, and conduit.", "25-Pack 9\" 14-TPI heavy metal blades | Curved Power Arc profile cuts 2x faster | Made in USA from global materials"),
        ("Norseman", "Norseman 44170 Super Premium 29-Piece M7 Hi-Molybdenum Mechanics Length Drill Bit Index (Made in USA)", "Pro Grade • Made in USA", "Sturdy mechanics-length bits with 135-degree split point and 3-flats on the shank to eliminate chuck slippage in portable drills.", "29-Piece 1/16\"–1/2\" by 64ths in waterproof case | Shorter mechanics length resists breakage | Made in St. Paul, Minnesota, USA"),
        ("LockNLube", "LockNLube LNL111 Original Locking Grease Gun Coupler (Rated to 10,000 PSI — No More Mess)", "Pro Grade • 10,000 PSI Lock", "Four hardened spring-steel jaws lock securely onto any Zerk fitting and release with a thumb lever—even under pressure.", "Rated to 10,000 PSI without leaking or popping off | Fits all 1/8\" NPT manual, air & cordless grease guns | Includes rebuild kit (seal & 4 jaws)"),
        ("Milton", "Milton S-221 M-Style 1/4\" NPT Solid Brass Industrial Air Hose Quick-Connect Coupler & Plug Kit (12-Piece)", "Pro Grade • Brass Air Kit", "Buna-N seal solid brass M-Style KWIK-CHANGE couplers and case-hardened steel plugs rated to 300 PSI and 40 SCFM.", "12-Piece 1/4\" NPT female/male coupler & plug kit | Industry-standard M-Style interchange | Made in USA heritage quality"),
        ("Fluke", "Fluke TL175 TwistGuard Double-Insulated Silicone Multimeter Test Leads w/ Adjustable Tip Length", "Pro Grade • CAT IV 600V", "Patented TwistGuard extendable tip shroud reduces exposed metal from 19mm to 4mm for safer live panel testing.", "CAT III 1000V / CAT IV 600V safety rated | WearGuard double-layer silicone shows inner color if nicked | Remains flexible in sub-zero oilfield cold"),
        ("NEIKO", "NEIKO 10194A Titanium Step Drill Bit Set (5-Piece Unibit High-Speed Steel — 50 Step Sizes from 1/8\" to 1-3/8\")", "Budget Line • 50-Size Step Bits", "Two-flute titanium-nitride coated HSS step bits for drilling clean holes in electrical junction boxes, sheet metal, and truck frames.", "5 Step bits covering 50 hole sizes (1/8\"–1-3/8\") | Tri-flatted shanks prevent drill chuck slip | Aluminum storage case included"),
        ("NEIKO", "NEIKO 10647A 1/4-Inch Shank Double-Cut Tungsten Carbide Rotary Die Grinder Burr Set (8-Piece)", "Budget Line • Carbide Burrs", "Solid YG8 tungsten carbide double-cut burrs for porting, weld prep, gouging out root passes, and deburring pipe IDs.", "8-Piece shapes: cylindrical, ball, tree & cone | 1/4\" shank fits all pneumatic & cordless die grinders | Cuts hardened steel up to HRC70"),
        ("NEIKO", "NEIKO 00249A 1/2-Inch Drive Impact Extension Bar, Universal Joint & Socket Adapter Set (9-Piece Cr-Mo)", "Budget Line • Impact Adapters", "Drop-forged chrome-molybdenum steel 3\", 5\", 10\", and 15\" impact extensions plus pinless swivel universal joint and step adapters.", "Includes 3\", 5\", 10\" & 15\" 1/2\" impact extensions | 3/8\"-to-1/2\" & 1/2\"-to-3/4\" impact adapters | Laser-etched Cr-Mo phosphate finish"),
        ("WORKPRO", "WORKPRO 22-Piece Bi-Metal Hole Saw Kit (3/4\" to 5\" Sizes w/ Mandrels, Pilot Drills & Heavy Case)", "Budget Line • 22-Pc Hole Saw", "M42 8%-cobalt bi-metal hole saws covering 13 common plumbing and electrical sizes at a fraction of single-saw retail prices.", "13 Hole saws from 3/4\" up to 5\" diameter | Includes 2 arbors, 4 pilot drills & hex key | High-value shop & service truck kit"),
        ("WORKPRO", "WORKPRO 40-Piece 4-1/2\" Angle Grinder Flap Disc & Thin Metal Cut-Off Wheel Master Assortment Pack", "Budget Line • 40-Pc Abrasives", "Bulk shop pack combining 10 zirconia flap discs (40/60/80/120 grit) and 30 thin-kerf metal cutting wheels.", "10 Zirconia T29 flap discs + 30 cut-off wheels | Fits all standard 4-1/2\" x 7/8\" angle grinders | Lowest cost per disc for fab shops"),
        ("HORUSDY", "HORUSDY 32-Piece Master Hex Bit Allen Socket Set (SAE & Metric — 1/4\", 3/8\", 1/2\" Drive S2 Alloy Steel)", "Budget Line • 32-Pc Allen Sockets", "Heat-treated S2 tool-steel hex bit sockets with chrome-vanadium drive bases for machinery cap screws and hydraulic valves.", "16 SAE (5/64\"–3/4\") + 16 Metric (2mm–19mm) | Precision chamfered S2 steel bit tips | Blow-molded organizer case"),
        ("HORUSDY", "HORUSDY 20-Piece Impact Magnetic Nut Driver Set (Long 6-Inch Reach SAE & Metric 1/4\" Hex Shank)", "Budget Line • 6\" Nut Drivers", "6-inch extended-reach Cr-V impact nut setters with recessed rare-earth magnets for self-tapping metal building screws.", "8 SAE + 8 Metric 6-inch magnetic nut drivers | Includes 3 impact socket adapters & bit holder | Black phosphate anti-rust coating"),
        ("HORUSDY", "HORUSDY 10-Piece Damaged Bolt, Rounded Lug Nut & Broken Stud Impact Extractor Socket Set", "Budget Line • Bolt Extractors", "Reverse spiral plum-blossom internal threads bite harder the more you turn to remove rusted or rounded flange nuts.", "Covers 9mm to 19mm rounded bolts & nuts | 3/8\" square drive impact-rated Cr-Mo steel | Includes knockout drift pin"),
        ("Capri Tools", "Capri Tools 30-Piece Master Star / Torx, Tamper-Proof Torx & External E-Torx Socket Set", "Budget Line • Master Torx", "S2 steel Torx and E-Torx sockets required for late-model pickup beds, brake calipers, seat bolts, and diesel sensors.", "Torx T8–T60, Tamper T10–T55 & E-Torx E4–E20 | Exceeds ASME torque standards | Heavy-duty hinged storage case"),
        ("Astro Pneumatic", "Astro Pneumatic 9477 7-Piece 3/8-Inch Drive Nano Pinless Impact Universal Swivel Socket Adapter Set", "Pro Grade • Pinless Swivel", "6-sided pinless hex swivel joint handles 40% more torque than traditional pinned U-joints without shearing pins.", "Covers 1/4\", 3/8\" & 1/2\" drive pinless swivels | Ultra-compact Nano profile fits tight manifolds | Lifetime warranty forged Cr-Mo"),
        ("Lisle", "Lisle 70500 Tap Socket Set (8-Piece Magnetic Square-Drive Sockets for Restricted-Space Thread Tapping)", "Pro Grade • Tap Sockets", "Fits all number and fractional MCTI standard taps up to 1/2\" plus 1/8\" NPT pipe taps where a T-handle will not clear.", "8-Piece set fits #0 to 1/2\" & metric taps | Turns taps with any 1/4\" or 3/8\" ratchet & extension | Made in USA"),
        ("VEVOR", "VEVOR 11-Piece Weldon-Shank HSS Annular Cutter Set for Magnetic Drills (7/16\" to 1-1/16\" x 1\" Depth)", "Budget Line • Mag Drill Cutters", "M2AL high-speed steel annular slugger bits with 3/4-inch Weldon shank and pilot pins for fast structural steel beam drilling.", "11 Cutters (7/16\"–1-1/16\") + 2 pilot pins | Fits Hougen, Milwaukee, DeWalt & VEVOR mag drills | Foam-lined portable metal case"),
        ("YesWelder", "YesWelder 4-Pack 50-Lb Pull Multi-Angle Arrow Welding Magnet Holder & Fit-Up Squares (45°/90°/135°)", "Budget Line • 4-Pk Weld Magnets", "Heavy riveted steel plates and powerful ferrite magnets hold pipe brackets, gussets, and square tubing hands-free for tacking.", "4-Pack 50-lb holding force welding magnets | Holds workpieces at 45°, 90° & 135° angles | Under-$25 fabrication table staple"),
        ("Benchmark Abrasives", "Benchmark Abrasives 10-Pack 4-1/2\" Knot Wire Wheel & Twisted Cup Brush Assortment (5/8\"-11 Threaded Arbor)", "Budget Line • 10-Pk Wire Wheels", "Carbon steel knotted stringer-bead wire wheels and cup brushes for cleaning pipe weld root passes, rust, and mill scale.", "5 Stringer-bead wheels + 5 knotted cup brushes | Standard 5/8\"-11 threaded arbor for 4-1/2\" grinders | Balanced to eliminate hand numbness"),
    ],
})

# Additional items per existing category to expand the catalog from 1,000 + 120 = 1,120 up to 1,500 items
# with balanced Pro Grade ("Good Quality") and Budget Line ("Value") options across every subcategory!
EXTRA_PRO_AND_BUDGET_TEMPLATES: list[tuple[str, str, str, str, str, str]] = [
    # (category_code,brand,title_pattern,badge,desc,specs)
    # 1. Pipefitting, Welding & Fab (Pro & Budget)
    ("pipe_welding_fab", "RIDGID", "RIDGID Heavy-Duty Offset Pipe Wrench for Tight Overhead Rack & Wall Clearances", "Pro Grade • Offset Jaw", "Parallel-to-handle hook jaw opening gives easy entry into tight pipe racks, manifold headers, and ditch walls.", "Forged alloy steel offset head | Ductile-iron I-beam housing | Self-cleaning full-floating hook jaw"),
    ("pipe_welding_fab", "VEVOR", "VEVOR Aluminum Straight Pipe Wrench Set (14\", 18\", 24\" 3-Piece Oilfield & Plumbing Kit)", "Budget Line • 3-Wrench Kit", "40% lighter aluminum alloy 3-wrench combo covering 1/2-inch through 3-inch threaded iron pipe at an unbeatable shop price.", "Includes 14\", 18\" & 24\" aluminum pipe wrenches | Drop-forged Cr-V replaceable jaws | Best value truck spare set"),
    ("pipe_welding_fab", "Miller", "Miller Digital Infinity Black Ops Auto-Darkening Welding Helmet w/ ClearLight 2.0 Lens", "Pro Grade • 13.4 Sq In", "Largest viewing area in the Miller lineup with 4 arc sensors and true-color ClearLight 2.0 optics for pipe TIG/Stick.", "13.4 sq. in. viewing lens | Weld, Cut, Grind & X-Mode electromagnetic sensing | Gen IV headgear eliminates pressure points"),
    ("pipe_welding_fab", "YesWelder", "YesWelder LYG-M800H True-Color Large-View Solar Auto-Darkening Welding Hood (4 Arc Sensors)", "Budget Line • 1/1/1/1 Optical", "Panoramic 3.93\" x 3.66\" true-color auto-darkening viewing screen with 4 sensors and replacement outer/inner lenses.", "1/1/1/1 optical clarity at a budget price | Cheater magnifying lens compatible | TIG, MIG, Stick & Plasma Grind modes"),
    ("pipe_welding_fab", "Knipex", "Knipex 81 11 250 Siphon & Cannon Plug Fine-Adjustment Pipe Connector Pliers (10-Inch)", "Pro Grade • Made in Germany", "25-position box-joint fine adjustment grips plastic and metal pipe unions, cannon plugs, and hydraulic fittings up to 3-5/32\".", "Forged German chrome-vanadium electric steel | Serrated jaws grip round pipe & coupling nuts | Non-slip plastic-coated handles"),
    ("pipe_welding_fab", "DURATECH", "DURATECH 3-Piece Heavy-Duty Cast-Iron Pipe Wrench Set (10\", 14\", 18\" w/ Roll Pouch)", "Budget Line • 3-Pc Cast Iron", "Heat-treated ductile cast-iron housings and drop-forged Cr-Mo jaws for shop maintenance and farm pipe repairs.", "Includes 10\", 14\" & 18\" straight pipe wrenches | Black anti-rust jaw finish | Canvas storage roll included"),
    # 2. Power & Hand Tools (Pro & Budget)
    ("power_hand_tools", "Knipex", "Knipex 87 01 250 & 87 01 180 Cobra Water Pump Pliers Set (7-1/4\" & 10\" Push-Button Grip)", "Pro Grade • German Cobra", "Push-button self-locking teeth hardened to 61 HRC bite round pipe and hex nuts without slipping under full body weight.", "Self-locking on pipes & nuts — no hand squeeze needed | 61 HRC induction-hardened gripping teeth | Pinch guard prevents finger blood blisters"),
    ("power_hand_tools", "Knipex", "Knipex 86 03 250 Pliers Wrench 10-Inch Smooth Parallel-Jaw Wrench & Plier in One Tool", "Pro Grade • Zero Backlash", "Smooth parallel jaws replace a full set of metric and imperial open-end wrenches up to 2 inches without marring chrome or brass.", "10:1 lever transmission crushing grip force | Zero-backlash parallel jaws never round brass valves | Push-button 19-step fast sizing"),
    ("power_hand_tools", "Wera", "Wera Kraftform Plus 6-Piece Lasertip Slotted & Phillips Chiseldriver Screwdriver Set w/ Rack", "Pro Grade • Lasertip Grip", "Microscopic laser-etched bit grooves literally bite into screw heads to prevent cam-out, paired with pound-thru hex bolster shafts.", "Lasertip anti-cam-out tip technology | Pound-thru full-tang shaft + impact cap | Hex bolster accepts open-end wrench for extra torque"),
    ("power_hand_tools", "Wright Tool", "Wright Tool 958 18-Piece 12-Point Full-Polish Alloy Steel SAE Combination Wrench Set (Made in USA)", "Pro Grade • WrightGrip 2.0", "Patented WrightGrip 2.0 anti-slip open-end serrations place more steel in high-stress zones for 80% higher torque before spreading.", "Covers 1/4\" through 1-1/4\" SAE sizes | Forged in Barberton, Ohio from 4140 US steel | Includes heavy denim roll pouch"),
    ("power_hand_tools", "Tekton", "Tekton 3/8-Inch Drive 6-Point Socket & 90-Tooth Ratchet Master Set (74-Piece, 1/4\"–1\" & 6–24mm)", "Budget Line • Zero-Skip Set", "Complete no-skip standard and deep 6-point socket set with 90-tooth quick-release ratchet, breaker bar, and extensions.", "74-Piece zero-skip SAE & Metric coverage | 6-point geometry grips flat sides of fasteners | Lifetime no-hassle photo replacement warranty"),
    ("power_hand_tools", "GearWrench", "GearWrench 20-Piece 72-Tooth 12-Point SAE & Metric Ratcheting Combination Wrench Set", "Budget Line • 5° Swing Arc", "72-tooth ratcheting box end needs only 5 degrees of swing arc to turn bolts inside cramped engine bays and skid frames.", "10 SAE (1/4\"–3/4\") + 10 Metric (6mm–18mm) | Off-corner loading reduces fastener rounding | Slim head fits where sockets cannot"),
    ("power_hand_tools", "Sunex", "Sunex 2569 1/2-Inch Drive Master Metric Impact Socket Set (43-Piece Standard & Deep, 9mm–30mm Cr-Mo)", "Budget Line • Cr-Mo Impact", "Forged chrome-molybdenum alloy steel impact sockets with radius-corner design and dual laser-etched/roll-stamped size markings.", "43-Piece 9mm–30mm standard & deep + swivel joint | Dual laser-etched & stamped permanent markings | Meets ANSI standards w/ lifetime warranty"),
    ("power_hand_tools", "WORKPRO", "WORKPRO 7-Piece Pliers Set (Slip Joint, Long Nose, Diagonal Cutter, Linesman, Groove Joint & Locking)", "Budget Line • 7-Pc Plier Kit", "Drop-forged carbon steel pliers with hardened cutting edges and tri-color comfort grips for shop benches and field trucks.", "Includes 10\" groove joint, 8\" linesman, needle nose & vise-grip | Induction-hardened wire cutting blades | Under-$35 complete plier drawer starter"),
    ("power_hand_tools", "LEXIVON", "LEXIVON 1/2-Inch Drive Click Torque Wrench (10–150 Ft-Lb / 13.6–203.5 Nm Dual-Range Pre-Calibrated)", "Budget Line • +/- 4% Certified", "Electro-black rust-resistant barrel with high-contrast yellow scale and individual serial-numbered calibration certificate.", "10 to 150 ft-lb range w/ reversible Cr-V ratchet head | Ships w/ ISO-6789 calibration certificate | Hard blow-molded storage case"),
    # 3. Rigging, Chains & Cargo Control (Pro & Budget)
    ("rigging_hauling_cargo", "Crosby", "Crosby S-209T Forged Alloy Bolt-Type Anchor Shackle w/ Cotter Pin for Permanent Overhead Lifting", "Pro Grade • ASME B30.26", "Bolt, nut, and cotter pin retention prevents accidental pin rotation on crane blocks, spreader bars, and permanent rigging.", "Quenched & tempered alloy steel pin | Stamped w/ WLL, Crosby name & PIC code | Hot-dip galvanized corrosion protection"),
    ("rigging_hauling_cargo", "Mytee Products", "Mytee Products 4-Pack 4\" x 30' Winch Straps w/ Flat Hooks for Flatbed & Pipe Hauling Trailers (5,400 Lb WLL)", "Budget Line • 4-Pk Flatbed", "Resin-coated polyester webbing with black powder-coated steel flat hooks and defender clip for standard flatbed rub rails.", "5,400 lb WLL / 16,200 lb break strength per strap | DOT & WSTDA tagged compliant | Weather & UV-resistant webbing"),
    ("rigging_hauling_cargo", "VEVOR", "VEVOR 3/4-Ton & 1.5-Ton Lever Chain Hoist Come-Along Ratchet Puller w/ 10-Ft G80 Manganese Chain", "Budget Line • G80 Come-Along", "Weston double-pawl brake and 360-degree forged swivel hooks for pulling pipe into alignment and tensioning loads.", "Grade 80 galvanized alloy load chain | Guided-type leading chain device prevents jamming | Compact one-hand free-chaining mode"),
    # 4. FR Workwear, PPE & Gas Detection (Pro & Budget)
    ("ppe_fr_safety", "MSA", "MSA V-Gard Iconic White Slotted Full-Brim Oilfield Hard Hat w/ Fas-Trac III Ratchet Suspension", "Pro Grade • ANSI Type I Class E", "High-density polyethylene shell with UV inhibitor and flush rear ratchet knob that eliminates neck-base irritation.", "ANSI/ISEA Z89.1 Type I, Class E (20,000V) & CSA Z94.1 | Flush-contour Fas-Trac III sweatband suspension | Slotted for face shields & earmuffs"),
    ("ppe_fr_safety", "Pyramex", "Pyramex Ztek ANSI Z87.1+ Anti-Fog Scratch-Resistant Wrap-Around Safety Glasses (12-Pair Crew Box)", "Budget Line • 12-Pair Box", "Panoramic single-lens wraparound polycarbonate eyewear with non-slip rubber temple tips and 99% UVA/B/C protection.", "12-Pair crew dispenser box | ANSI Z87.1+ high-velocity impact certified | Under $2 per pair for guests & crews"),
    ("ppe_fr_safety", "Ergodyne", "Ergodyne Skullerz 8945F(x) Universal Bump Cap Insert w/ Extra Venting for Baseball Caps", "Budget Line • Cap Insert", "Lightweight polypropylene shell with foam pad slips inside any company baseball cap to guard against low pipe racks and valves.", "Fits inside any standard baseball hat | Trim-to-fit height & 360° airflow vents | Protects against overhead pipe bumps & scrapes"),
    # 5. Fleet, Hydraulics & Field Service (Pro & Budget)
    ("hydraulics_fleet_shop", "Autel", "Autel MaxiCheck Pro ABS, SRS, EPB, SAS,BMS & DPF Service Diagnostic Scan Tool", "Pro Grade • Fleet Service", "Dedicated service-bay diagnostic scanner for brake bleeding, steering angle calibration, battery registration, and diesel DPF.", "Opens electronic rear brake calipers for pad changes | Cycles ABS solenoids to bleed brake fluid | Reads live sensor data graphs"),
    ("hydraulics_fleet_shop", "XTOOL", "XTOOL IP616 5-Inch Bi-Directional OBD2 Scanner w/ 31+ Reset Services, CAN-FD & Lifetime Free Updates", "Budget Line • Lifetime Free", "Compact touchscreen bi-directional diagnostic scanner with CAN-FD support and zero annual subscription renewal costs.", "Full Bi-Directional Active Tests + 31 Resets | Lifetime Free Wi-Fi Software Updates | AutoVIN + 8-in-1 live data graphing"),
    ("hydraulics_fleet_shop", "Enerpac", "Enerpac RC-106 10-Ton 6.13-Inch Stroke Single-Acting Alloy Steel General Purpose Hydraulic Cylinder", "Pro Grade • 10,000 PSI", "Baked enamel finish, Golden Ring bearing design, and CR-400 high-flow female coupler for heavy structural jacking and rigging.", "10-Ton capacity / 6.13\" stroke @ 10,000 PSI | Collar threads, plunger threads & base mounting holes | Hardened removable grooved saddle"),
    ("hydraulics_fleet_shop", "VEVOR", "VEVOR 10-Ton Low-Profile Hydraulic Ram Cylinder + CP-180 Manual Hydraulic Hand Pump Kit", "Budget Line • Ram + Pump Kit", "Complete 10,000 PSI portable hydraulic jacking kit with 2-inch stroke low-clearance ram, pressure hose, and hand pump.", "Includes 10-Ton ram + manual hydraulic pump | Fits 3.5-inch tight machinery clearances | Dust cap & ZG3/8\" quick coupler"),
    # 6. Jobsite Lighting, Flashlights, Power & Storage (Pro & Budget)
    ("lighting_power_jobsite", "Streamlight", "Streamlight 33202 Dualie 3AA 245-Lumen Intrinsically Safe Class I Div 1 Dual-Beam Spot/Flood Flashlight", "Pro Grade • Class I Div 1", "Shines both ahead and downward simultaneously to eliminate slip-and-trip hazards on dark stairways and tank catwalks.", "UL Class I, Div 1 Hazardous Location certified | Simultaneous 245-lumen spot + downward flood | Integrated magnet & hands-free belt clip"),
    ("lighting_power_jobsite", "Fenix", "Fenix LD30R 1,700-Lumen Compact USB-C Rechargeable Tactical EDC & Inspection Flashlight", "Pro Grade • 1,700 lm EDC", "4.76-inch aluminum flashlight with two-way body clip, tail tactical switch, and battery level indicator LED.", "1,700 lumens / 267m beam distance | Includes 3,400mAh 18650 rechargeable battery | IP68 waterproof & dustproof"),
    ("lighting_power_jobsite", "Coast", "Coast G450 1,630-Lumen Twist-Focus Alkaline Industrial Aluminum Flashlight (6x AA Included)", "Budget Line • 1,630 lm Value", "No charging required—runs on 6 standard AA batteries with PURE BEAM twist focus from wide floodlight to 250m spot beam.", "1,630 lumens high / 29-hr low runtime | Seamless spot-to-flood twist focus | Rugged machined aluminum chassis"),
    # 7. Inspection, Gauges & Pipe Testing (Pro & Budget)
    ("measuring_inspection", "Fluke", "Fluke 117 Electricians True-RMS Digital Multimeter w/ VoltAlert Non-Contact Voltage Detection", "Pro Grade • Fluke 117", "AutoVolt low-impedance input prevents false ghost-voltage readings on long conduit runs and control cabinets.", "CAT III 600V safety rated True-RMS accuracy | Built-in VoltAlert non-contact voltage sensor | Large white LED backlight for dark panels"),
    ("measuring_inspection", "Klein Tools", "Klein Tools MM420 Auto-Ranging True-RMS Digital Multimeter (600V AC/DC, Temp, Capacitance & Microamps)", "Pro Grade • 2m Drop Rated", "Tough rubber-booted TRMS meter measuring AC/DC voltage, resistance, Type-K thermocouple temperature, and flame-rod microamps.", "CAT III 600V rated & 6.6-ft drop tested | Includes thermocouple temp probe & test leads | High-visibility reverse-contrast display"),
    ("measuring_inspection", "iGaging", "iGaging EZ Cal IP54 Splash-Proof Fractional/Inch/Metric Stainless Digital Caliper (0–6\" Large LCD)", "Budget Line • Fractional LCD", "Displays instant 1/64\" fractional inches, decimals, and millimeters on an extra-large screen for fast pipe OD/ID checks.", "Reads Inch, Metric & 1/64\" Fractions | IP54 oil & splash water resistant | Hardened stainless steel frame w/ case"),
    ("measuring_inspection", "KAIWEETS", "KAIWEETS HT206D True-RMS 600A AC/DC Digital Clamp Meter w/ Inrush Current, NCV & Flashlight", "Budget Line • AC/DC Clamp", "Measures both AC and DC amperage up to 600A on 12V/24V truck starter cables, welding leads, and 480V 3-phase motors.", "Measures DC & AC Current without breaking circuit | Built-in jaw work flashlight & NCV alarm | Includes zippered hard case & thermocouple"),
    # 8. Farm, Ranch & Pipe Fencing Gear (Pro & Budget)
    ("ranch_fencing_ag", "Gallagher", "Gallagher S40 Lithium Solar Electric Fence Charger (Powers up to 25 Miles / 80 Acres of Pasture Fence)", "Pro Grade • Lithium Solar", "Internal lithium iron phosphate battery and smart solar management deliver reliable livestock control through 21 overcast days.", "0.4 Stored Joules — covers up to 25 miles | Drop-tested waterproof enclosure w/ lightning diverter | 3-Year Gallagher warranty"),
    ("ranch_fencing_ag", "VEVOR", "VEVOR 52CC 2-Stroke Gas Powered T-Post & Pipe Fence Driver (1,700W Pile Driver w/ 3 Driving Heads)", "Budget Line • 3 Socket Heads", "Portable 2-stroke gas post pounder with 55mm, 70mm, and 100mm driving barrels for T-posts, ground rods, and 2-3/8\" fence pipe.", "55J impact energy @ 1,350 BPM | Includes 3 adapter sleeves + rolling hard case | Saves hours vs manual hand post pounders"),
]


BUDGET_BRANDS_LOWER = {
    "vevor",
    "neiko",
    "workpro",
    "duratech",
    "horusdy",
    "lexivon",
    "capri tools",
    "ares",
    "sunex",
    "grey pneumatic",
    "tekton",
    "astro pneumatic",
    "lisle",
    "otc",
    "irwin",
    "coast",
    "braun",
    "ancel",
    "foxwell",
    "xtool",
    "innova",
    "thinkcar",
    "otofix",
    "yeswelder",
    "titanium",
    "vulcan",
    "mega cargo control",
    "kje",
    "mytee products",
    "boxertool",
    "ergodyne",
    "pyramex",
    "radians",
    "sellstrom",
    "jackson safety",
    "igaging",
    "fowler",
    "rexbeti",
    "craftsman",
    "stanley",
    "husky",
    "kobalt",
    "pittsburgh",
    "u.s. general",
    "ingco",
    "total tools",
    "wen",
    "kaiweets",
    "benchmark abrasives",
}

SUBCATEGORY_PRO_BUDGET_EXPANSIONS: dict[str, list[tuple[str, str, str, str, str]]] = {
    "EDC, Tactical, Magnetic & Rechargeable Flashlights": [
        ("Streamlight", "Streamlight 66604 MicroStream USB 250-Lumen Coyote Pocket Penlight Flashlight", "Pro Grade • Pocket USB", "Ultra-compact USB rechargeable aluminum penlight that slips into a shirt pocket or hat brim.", "250 lumens high / 50 lumens low | Machined aluminum w/ two-way hat clip | IPX4 water resistant"),
        ("Streamlight", "Streamlight 88061 ProTac 2L-X 500-Lumen Dual-Fuel Tactical Aluminum Duty Flashlight", "Pro Grade • Dual-Fuel", "Runs on either two CR123A lithium cells or one Streamlight SL-B26 rechargeable USB battery.", "500 lumens / 165m beam | TEN-TAP programmable switch | Anodized aircraft aluminum"),
        ("Streamlight", "Streamlight 44910 Waypoint 300 1,000-Lumen Rechargeable Pistol-Grip Spotlight (Floats on Water)", "Pro Grade • 1,039m Spot", "Long-range pistol-grip searchlight throwing a 1,039-meter beam across pipeline ROWs, ponds, and lease yards.", "1,000 lumens / 1,039m long-range beam | IPX8 waterproof & floats if dropped in water | Integrated folding stand for hands-free scene lighting"),
        ("Fenix", "Fenix PD36R V2.0 1,700-Lumen 18W Fast-Charge USB-C Tactical Inspection Flashlight", "Pro Grade • 18W Fast Charge", "Upgraded 396m throw tactical flashlight with 18W USB-C fast charging and two-way body clip.", "1,700 lumens / 396m throw | 5-level output + instant strobe | 5,000mAh 21700 battery included"),
        ("Fenix", "Fenix HM70R 1,600-Lumen 21700 All-Metal High-Capacity Industrial Rechargeable Headlamp", "Pro Grade • 100-Hr Runtime", "Powered by a 21700 5,000mAh battery for multi-shift winter turnaround and night-shift rig work.", "1,600 lumens spot + high-CRI neutral flood + red | Hidden waterproof USB-C port | All-metal A6061-T6 impact housing"),
        ("Olight", "Olight Arkfeld Ultra 1,400-Lumen O-Aluminum Flat EDC Flashlight w/ UV Leak Light & Green Laser", "Pro Grade • O-Aluminum", "Proprietary scratch-resistant O-Aluminum alloy housing with 1,400-lumen work light, 365nm UV, and green pointer.", "1,400 lumens white + 900mW UV + Green Laser | Anti-scratch glass lens | Battery level micro-LED bar"),
        ("Olight", "Olight Marauder Mini 7,000-Lumen RGB Search & Floodlight Rechargeable Field Lantern", "Pro Grade • 7,000 lm", "Toggle switch flips instantly between a 600-meter narrow searchlight pencil beam and a 7,000-lumen wide floodlight.", "7,000-lumen flood + 600m throw spotlight | Built-in Red, Green & Blue LEDs | Silicone-wrapped thermal grip"),
        ("Nitecore", "Nitecore EDC25 3,000-Lumen Ultra-Thin Flat Tactical Pocket Flashlight w/ Dual Tail Switches", "Pro Grade • 14mm Thin", "Only 14mm thick to ride flat alongside a folding knife or caliper in front work pants pockets.", "3,000 lumens / 300m beam | Dual-stage customizable tail buttons | USB-C built-in charging"),
        ("Coast", "Coast G32 465-Lumen Pure-Beam Twist Focus Alkaline Penlight Inspection Flashlight", "Budget Line • 2x AA Value", "Slim 2x AA aluminum penlight with twist focus from edge-to-edge flood circle to long-range spot.", "465 lumens / 134m beam | Runs on 2 standard AA batteries | Heavy-duty steel pocket clip"),
        ("WORKPRO", "WORKPRO 500-Lumen Rechargeable Aluminium Penlight & Magnetic Pivoting Inspection Light (2-Pack)", "Budget Line • 2-Pk Penlight", "Slim machined aluminum USB-C penlights with 180-degree swiveling magnetic clip and bottom magnet.", "500 lumens COB + top spotlight (2-Pack) | Dual magnets on clip & base | Budget Line mechanic pocket staple"),
    ],
    "Bi-Directional OBD2 Readers & Diagnostic Scanners": [
        ("Autel", "Autel MaxiCOM MK900 8-Inch Bi-Directional All-System OBD2 Scanner (40+ Resets, CAN-FD & DoIP)", "Pro Grade • MK900 Series", "Upgraded 8-inch quad-core diagnostic tablet with 3,000+ active tests, Pre/Post scan reports, and AutoAuth.", "3,000+ Bi-Directional Active Tests | 40+ service resets + CAN-FD/DoIP | 7,700mAh battery & Wi-Fi printing"),
        ("Autel", "Autel MaxiCOM MK900-BT Wireless Bluetooth Bi-Directional Scanner w/ MaxiVCI V150 Dongle", "Pro Grade • Wireless MK900", "Cordless Bluetooth V150 VCI gives 33-ft freedom around service bays while running active component tests.", "Wireless CAN-FD & DoIP VCI included | Full Bi-Directional solenoid & actuator control | Supports battery tester & videoscope add-ons"),
        ("Autel", "Autel AutoLink AL539B OBD2 Code Reader + 12V Digital Multimeter & Starting/Charging Circuit Tester", "Pro Grade • 3-in-1 Meter", "Combines an OBD2 check-engine scanner, digital AVOmeter multimeter, and 12V battery/alternator load tester.", "Reads all 10 modes of OBD2 + ABS/Airbag | Built-in voltmeter, ohmmeter & amp probe | Tests cranking & charging ripple"),
        ("Launch", "Launch X431 CRP919X 7-Inch Bi-Directional Diagnostic Scanner w/ ECU Coding & 35+ Services", "Pro Grade • Wired CAN-FD", "Direct high-speed OBD2 cable connection with full bi-directional active testing, online ECU coding, and 2-Yr updates.", "Full Bi-Directional control + ECU Coding | Native CAN-FD & DoIP high-speed transfer | 6,100mAh battery & 64GB memory"),
        ("Topdon", "Topdon ArtiDiag800 BT 2 Wireless Bluetooth Bi-Directional OBD2 Scanner (28+ Resets & Lifetime Free Info)", "Budget Line • Wireless BT", "6-inch wireless touchscreen scanner with Bluetooth 5.0 VCI and full bi-directional active test capability.", "Full Bi-Directional actuator control | 28 maintenance resets (DPF, Oil, EPB, BMS) | One-click AutoVIN & DTC repair guide"),
        ("Topdon", "Topdon ArtiDiag600S 5-Inch Four-System (Engine/Transmission/ABS/SRS) OBD2 Scanner w/ 9 Resets", "Budget Line • 9 Resets + Free Updates", "Reads and clears Engine, Transmission, ABS, and Airbag codes plus DPF regen, Oil, Brake, BMS, and Throttle resets.", "4-System diagnostics + 9 common resets | CAN-FD compatible + Lifetime Free Updates | Best value fleet pickup code reader"),
        ("XTOOL", "XTOOL IP819 7-Inch Bi-Directional OBD2 Diagnostic Tablet w/ Key Programming, ECU Coding & 3-Yr Updates", "Budget Line • 3-Yr Updates", "Rugged shop tablet offering 4,000+ bi-directional tests, PMI/ECU coding, and 3 years of free updates.", "Full Bi-Directional tests + 31+ resets | Includes 3 Years of Free Wi-Fi Updates | Covers 140+ US, Asian & Euro brands"),
        ("ANCEL", "ANCEL HD3200 Heavy-Duty Commercial Truck & Pickup 2-in-1 Diesel DPF Regen & OBD2 Scanner", "Budget Line • Truck + Pickup", "Diagnoses both Class 4–8 heavy-duty diesel trucks (J1939/J1708) and 12V passenger pickups with forced DPF regeneration.", "Forced DPF Regen for Cummins, Caterpillar, Detroit, Paccar & Isuzu | Includes 6-Pin, 9-Pin & 16-Pin adapters | Lifetime free Wi-Fi updates"),
        ("ANCEL", "ANCEL BD310 2-in-1 Handheld & Bluetooth Bi-Mode OBD2 Scanner w/ Magnetic Vent Mount", "Budget Line • Dual Handheld/BT", "Works both as a standalone wired handheld color screen AND as a wireless Bluetooth performance gauge display.", "Dual-mode: Wired Handheld or Bluetooth App | Battery voltage test + trip fuel monitor | Magnetic pod mounts on dash"),
        ("Foxwell", "Foxwell NT710 Single-Make Pro Bi-Directional All-System OBD2 Scanner (Ford / GM / Dodge / Toyota / Honda)", "Budget Line • OE-Level Make", "Factory-level bi-directional active tests, module coding, and all-system resets tailored to your fleet's primary truck brand.", "Full Bi-Directional tests + 30+ special functions | Lifetime free updates for primary vehicle brand | 5.5-inch touchscreen w/ Wi-Fi"),
    ],
    "Tool Storage: Boxes, Modular Systems, Bags & Organizers": [
        ("Milwaukee", "Milwaukee 48-22-8429 PACKOUT XL Tool Box (100-Lb Capacity Weather-Sealed Heavy Equipment Case)", "Pro Grade • PACKOUT XL", "Extra-deep modular PACKOUT chest built to hold 9-inch angle grinders, deep-cut bandsaws, and bulky welding leads.", "100-lb weight capacity / IP65 weather seal | Interior removable hand-tool tray | Metal-reinforced corners & locking point"),
        ("Milwaukee", "Milwaukee 48-22-8440 PACKOUT Modular Tool Crate (50-Lb Stackable Open-Top Bin)", "Pro Grade • PACKOUT Crate", "Impact-resistant stackable crate that locks into the top OR bottom of any PACKOUT stack for hoses, chains, and cords.", "50-lb weight capacity / 1,872 cu. in. volume | Weep holes prevent water pooling | Rear hanging cleats mount to PACKOUT wall plates"),
        ("Milwaukee", "Milwaukee 48-22-8445 PACKOUT Modular Front-Opening Cabinet w/ Flip-Up Door", "Pro Grade • Wall/Stack Cabinet", "Front flip-up door lets you grab power tools or chemical cans whether stacked on a rolling cart or hung on service-van walls.", "50-lb capacity / locks onto wall plates or boxes | Quick-access flip-up door slides inside housing | Impact-resistant polymer body"),
        ("DEWALT", "DEWALT DWST08035 ToughSystem 2.0 Compact Deep Small-Parts Organizer w/ 6 Removable Cups", "Pro Grade • IP65 Cups", "Double-level removable organizer cups with clear polycarbonate lid and auto-connect side latches.", "IP65 dust & water seal | 6 deep removable double-layer cups | Connects to all ToughSystem 2.0 boxes"),
        ("Klein Tools", "Klein Tools 54803MB MODbox 2-Drawer Modular Locking Toolbox w/ Ball-Bearing Slides", "Pro Grade • MODbox Drawers", "Two deep steel-slide drawers with removable dividers and integrated side accessory rails for hardhat and level mounts.", "Ball-bearing slides w/ steel locking bar | Side rails accept MODbox pouches & magnetic strips | One-hand release latch"),
        ("Veto Pro Pac", "Veto Pro Pac TP-XXL Extra-Large Closable Service & Meter Diagnostic Tool Pouch", "Pro Grade • Closable Pouch", "Stands upright on grated catwalks with 47 pockets and a padded tablet/multimeter rear compartment.", "47 pockets + padded meter/tablet bay | Waterproof polypropylene base | 5-Year Zero-Downtime warranty"),
        ("HORUSDY", "HORUSDY 80-Clip Heavy-Duty Molded ABS Socket Organizer Tray w/ Carry Handle (1/4\", 3/8\", 1/2\" Drive)", "Budget Line • 80-Socket Tray", "Portable grab-and-go socket board holding 26x 1/4\", 30x 3/8\", and 24x 1/2\" sockets with spring-loaded steel ball detents.", "Holds 80 sockets securely upright or inverted | Spring-loaded ball bearings grip worn sockets | Under-$18 toolbox upgrade"),
        ("WORKPRO", "WORKPRO 24-Inch Heavy-Duty Wide-Mouth Water-Resistant Duffel Tool Bag w/ Waterproof Molded Base", "Budget Line • 24\" Rig Bag", "Oversized 24-inch equipment bag large enough for 24-inch pipe wrenches, cordless bandsaws, and full socket cases.", "1680D water-resistant fabric + molded hard base | Dual steel zippers accept security padlock | Padded shoulder strap"),
        ("NEIKO", "NEIKO 03968A 2-Pack Magnetic Tool Holder Bar Strip (18-Inch & 24-Inch 30-Lb Pull Per Inch Wall Mount)", "Budget Line • Magnetic Bars", "Heavy-duty magnetic bars bolt inside service truck doors or over shop benches to hold wrenches, hammers, and pliers.", "Includes 18\" & 24\" magnetic steel bars | Holds wrenches, impacts, screwdrivers & drill bits | Mounting brackets & screws included"),
        ("VEVOR", "VEVOR 48-Inch Aluminum Diamond-Plate Underbody Truck & Flatbed Trailer Storage Box w/ T-Handle Lock", "Budget Line • Underbody Box", "Corrosion-resistant tread-plate aluminum underbody box with overhanging rain lip and stainless T-handle compression lock.", "48\" x 18\" x 18\" flatbed underbody mount | Rubber weather seal keeps chains & straps dry | Includes 2 keys & drop-down door cables"),
    ],
    "Tool Accessories: Bits, Blades, Abrasives & Hole Saws": [
        ("Milwaukee", "Milwaukee 48-89-4631 Titanium Shockwave Impact Duty 23-Piece Red Helix Drill Bit Set", "Pro Grade • Titanium Impact", "1/4-inch hex shank titanium drill bits chuck directly into impact drivers or 3-jaw drill chucks with 5x life over black oxide.", "23-Piece 1/16\" to 1/2\" 1/4\"-hex shank index | Variable Helix flute ejects hot chips fast | 135° split point starts on curved pipe without walking"),
        ("Milwaukee", "Milwaukee 48-00-5026 The Ax w/ Carbide Teeth 9-Inch 5-TPI Nail-Embedded Wood & Demolition Sawzall Blades (5-Pack)", "Pro Grade • Carbide Ax", "Cuts through timber cribbing, skids, bolts, and hardened screws with 50x longer life than standard bi-metal blades.", "9-inch 5-TPI Carbide teeth (5-Pack) | Fang Tip for fast plunge cutting | Nail Guard prevents tooth rip-out"),
        ("DEWALT", "DEWALT DWA1790IR 3-Piece 1/4\" Hex to 1/4\", 3/8\" & 1/2\" Square Impact Socket Adapter Set", "Pro Grade • Impact Adapters", "Turns any 1/4-inch hex impact driver into a rapid socket runner with Torsion Zone shock absorption.", "Includes 1/4\", 3/8\" & 1/2\" square socket adapters | Black oxide corrosion-resistant finish | Chamfered square drive corners"),
        ("Diablo", "Diablo DS0914BF5 Steel Demon 9-Inch 14/18-TPI Bi-Metal Medium Metal & Pipe Reciprocating Blades (5-Pack)", "Pro Grade • Dual-Tooth Pipe", "Double-tooth geometry with Ultra-Hardened cutting edge rated for 1/16\" to 5/16\" wall conduit, tubing, and strut.", "9-inch 14/18 variable TPI (5-Pack) | Perma-SHIELD non-stick coating | Up to 5x life in schedule 40 pipe"),
        ("Lenox", "Lenox 1787565 9-Piece Bi-Metal Electrician & Plumber Speed-Slot Hole Saw Kit (7/8\" to 2-1/2\")", "Pro Grade • Speed-Slot", "Staircase Speed-Slot side cutout lets you pop stuck metal or wood plugs out in seconds with a standard screwdriver.", "Covers 1/2\" through 2\" conduit knockout sizes | T3 technology cuts 50% faster | Heavy-duty latched case"),
        ("LockNLube", "LockNLube LNL120 Grease Gun 90-Degree Right-Angle Coupler Adapter for Recessed Pin & U-Joint Zerks", "Pro Grade • 90° Zerk Access", "Snaps directly into any LockNLube coupler to reach recessed U-joint, loader pin, and kingpin grease fittings.", "3-jaw push-on 90-degree low-profile head | Carbon steel construction w/ Viton O-ring | Includes snap-in Zerk collar"),
        ("NEIKO", "NEIKO 10048A 5-Piece Left-Hand Cobalt Drill Bit & Spiral Screw Extractor Bolt Remover Set", "Budget Line • Left-Hand Cobalt", "Left-hand M35 cobalt drill bits often spin broken manifold studs out on their own before you even insert the spiral flute extractor.", "5 Left-hand M35 cobalt bits + 5 alloy extractors | Removes broken 3/16\" to 9/16\" bolts & studs | Metal index storage case"),
        ("WORKPRO", "WORKPRO 10-Piece 4-1/2\" Diamond Masonry, Concrete, Ductile Iron & Tile Cutting Wheel Set", "Budget Line • 10-Pk Diamond", "Segmented, turbo, and continuous-rim sintered diamond blades for cutting concrete pads, brick, and cast pipe.", "10-Piece 4-1/2\" x 7/8\" dry/wet diamond blades | 13,300 RPM heat-treated spring steel cores | Includes 5/8\" reducer rings"),
        ("HORUSDY", "HORUSDY 24-Piece Master Impact Socket Adapter, Swivel Joint, Bit Holder & Magnetic Extension Set", "Budget Line • 24-Pc Master", "Complete Cr-V and Cr-Mo adapter drawer kit with 360° rotatable socket adapters, 105° right-angle drill attachment, and extensions.", "Includes 105° right-angle tight-spot drill adapter | 1/4\", 3/8\" & 1/2\" rigid & 360° swivel impact adapters | Color-coded rings for instant size ID"),
        ("VEVOR", "VEVOR 3/8-Inch x 50-Ft Retractable Enclosed Auto-Rewind Hybrid Polymer Air Hose Reel (300 PSI)", "Budget Line • 50-Ft Air Reel", "180-degree swivel wall/ceiling bracket and all-weather hybrid polymer air hose that stays flexible down to -4°F.", "3/8\" x 50' 300 PSI hybrid polymer hose + 5' lead | Auto-ratchet lock at any length | 1/4\" NPT solid brass fittings"),
    ],
}


# Subcategory-specific Pro Grade and Budget Line expansion pairs so every subcategory
# has rich Good Quality (Pro Grade) and Budget Line (Value) options up to 1,500+ total items.
SUBCATEGORY_PRO_BUDGET_PAIRS: dict[str, tuple[tuple[str, str, str], tuple[str, str, str]]] = {
    "Pipe Wrenches, Chain Tongs & Vises": (
        ("RIDGID", "Heavy-Duty Pipe & Chain Wrench Series", "Forged alloy jaws | Ductile-iron I-beam handle | Pipefitter lifetime grade"),
        ("VEVOR", "Value Aluminum & Cast Pipe Wrench Series", "Heat-treated Cr-V steel jaws | Budget-friendly shop & truck spare | High-leverage handle"),
    ),
    "Pipe Cutting, Threading & Beveling": (
        ("RIDGID", "Pro Pipe Cutter, Reamer & NPT Threading Series", "Hardened alloy cutter wheel | Fast clean burr-free pipe cuts | Industrial field spec"),
        ("VEVOR", "Value Ratcheting Pipe Threader & Cutter Kit", "Includes NPT die heads & ratcheting handle | Budget Line shop pipe threading | Hard carry case"),
    ),
    "Pipe Alignment, Jacks & Fit-Up Tools": (
        ("Sumner", "Pro V-Head Pipe Jack Stand & Fit-Up Clamp Series", "2,500-lb to 4,500-lb rated V-head | Quick-action lock washer & fine jack screw | ASME fab shop standard"),
        ("VEVOR", "Budget Line Folding V-Head Pipe Stand (2,500 Lb Capacity, 28\"–52\")", "Heavy steel tripod folding legs | Chrome-plated acme lead screw | High-value welding stand"),
    ),
    "Welding Machines, Leads & Torches": (
        ("Lincoln Electric", "Pro Pipeline & Fabrication Welder / Hood Series", "4C / ClearLight optical clarity | Heavy duty-cycle output | Pipeline rig ready"),
        ("YesWelder", "Budget Line Multi-Process MIG/Stick/TIG Inverter & True-Color Hood", "Dual-voltage 110V/220V IGBT inverter | High-value shop & farm welder | Digital amp readout"),
    ),
    "Welding Rods, Wire & Abrasives": (
        ("Lincoln Electric", "Excalibur 7018 / Fleetweld 5P+ & Diablo Flap Disc Pro Pack", "Hermetically sealed low-hydrogen rod can | X-ray quality pipe welds | High-zirconia weld grinding"),
        ("Hobart", "Budget Line Welding Electrode, Flux-Core Wire & Flap Disc Shop Pack", "All-position carbon steel welding | Low spatter & easy slag peel | Value maintenance pack"),
    ),
    "Valves, Pipe Fittings, Flanges & Sealants": (
        ("Swagelok", "Pro 316 Stainless High-Pressure Ball Valve & Instrumentation Fitting", "Rated to 6,000 PSI WOG | Blowout-proof stem & PTFE seats | NACE sour-gas service ready"),
        ("NEIKO", "Budget Line Brass/Stainless NPT Pipe Plug, Nipple & PTFE Sealant Assortment", "Precision NPT tapered threads | Oil, water & air rated | Organized shop hardware case"),
    ),
    "Cordless Impact Wrenches & Socket Sets": (
        ("Milwaukee", "M18 FUEL Brushless High-Torque Cordless Impact & Cr-Mo Socket Kit", "POWERSTATE brushless motor | REDLINK PLUS intelligence | Laser-etched impact sockets"),
        ("NEIKO", "Budget Line Master Cr-Mo Deep Impact Socket & Ratchet Driver Kit", "Drop-forged Chrome-Molybdenum steel | High-contrast laser size markings | Blow-molded truck case"),
    ),
    "Angle Grinders, Bandsaws & Mag Drills": (
        ("DEWALT", "Pro Brushless Paddle-Switch Angle Grinder & Deep-Cut Portable Bandsaw", "Kickback Brake electronic clutch | E-Switch Protection | Schedule 40/80 pipe cutting"),
        ("VEVOR", "Budget Line Magnetic Drill Press & Variable-Speed Metal Cutting Saw", "2,920-lbf电磁 holding force | Includes Weldon annular cutters | Best value structural drill"),
    ),
    "Heavy Wrenches, Ratchets & Torque Tools": (
        ("Wright Tool", "Pro Full-Polish Alloy SAE/Metric Combination Wrench & Digital Torque Series", "Patented anti-slip open-end serrations | +/- 2% certified torque accuracy | Forged industrial steel"),
        ("Tekton", "Budget Line 90-Tooth Ratchet, Breaker Bar & Combination Wrench Set", "Zero-skip size coverage | 4-degree ratcheting swing arc | Lifetime hassle-free replacement"),
    ),
    "Pliers, Hammers, Spuds & Pry Bars": (
        ("Knipex", "Pro Cobra Water Pump Pliers, Pliers Wrench & Estwing Hammer Series", "61 HRC induction-hardened teeth | Self-locking box joint | Forged one-piece steel"),
        ("WORKPRO", "Budget Line Chrome-Vanadium Pliers, Dead-Blow Hammer & Pry Bar Set", "Bi-material non-slip comfort grips | Strike-cap pry bars | Best value service truck hand tools"),
    ),
    "Mechanics, Electrician & Tap/Die Kits": (
        ("Klein Tools", "Pro Insulated 1000V VDE Electrician & Master Tap/Die Set", "Individually tested to 10,000V / VDE certified | CNC ground alloy taps & dies | Made for utility & plant pros"),
        ("HORUSDY", "Budget Line 110-Piece Master SAE/Metric Tap & Die + Mechanics Tool Kit", "Bearing-steel tapered & plug taps | Ratcheting T-handle wrench | Complete thread-repair case"),
    ),
    "Cordless Batteries, Chargers & Packout": (
        ("Milwaukee", "M18 REDLITHIUM High-Output Battery, Super Charger & PACKOUT Mount", "Runs 50% cooler under heavy load | Onboard LED fuel gauge | Multi-bay rapid sequential charging"),
        ("DEWALT", "Value 20V MAX Battery Starter Kit & Wall-Mount Power Tool Charging Rack", "Includes charger & high-capacity Li-ion pack | Heavy steel cordless drill hanger | 3-Year warranty"),
    ),
    "Tool Storage: Boxes, Modular Systems, Bags & Organizers": (
        ("Milwaukee", "PACKOUT Modular Rolling Tool Box, Drawer Unit & Ballistic Tech Bag", "IP65 weather seal & metal corners | Ball-bearing locking drawers | Interlocks across full PACKOUT stack"),
        ("HORUSDY", "Budget Line Magnetic Socket Organizer Trays, Wrench Racks & Wide-Mouth Bag", "Rubberized magnetic base won't scratch drawers | Holds SAE & Metric sockets upright | High-value shop storage"),
    ),
    "Tool Accessories: Bits, Blades, Abrasives & Hole Saws": (
        ("Milwaukee", "Shockwave Impact Bit, NITRUS Carbide Torch Blade & Cobalt Drill Set", "Laser-hardened Wear Guard tips | Carbide teeth cut cast iron & thick pipe | Custom Alloy76 steel"),
        ("NEIKO", "Budget Line Titanium Step Drill Bits, Carbide Rotary Burrs & Hole Saw Kit", "135° split-point fast starts | YG8 double-cut tungsten carbide | Best value consumable pack"),
    ),
    "Shackles, Hooks, Swivels & Hardware": (
        ("Crosby", "G-209 / G-2130 Quenched & Tempered Forged Alloy Anchor Shackle & Clevis Hook", "Stamped WLL & PIC traceability code | Hot-dip galvanized fatigue rated | Meets ASME B30.26"),
        ("Mytee Products", "Budget Line Forged Grade 70/80 Clevis Grab Hook & Screw-Pin Shackle Pack", "WLL stamped on every body | Zinc-chromate corrosion finish | Value flatbed hardware"),
    ),
    "Web Slings, Round Slings & Wire Chokers": (
        ("Lift-All", "Pro Tuflex Endless Polyester Round Sling & 2-Ply Eye-to-Eye Web Sling", "Color-coded WLL capacity jacket | Double-wall abrasion cover | Sewn leather-protected load tag"),
        ("VEVOR", "Budget Line 4-Pack 2\" x 20' 2-Ply Polyester Lifting Web Straps & Choker Slings", "6,200-lb vertical / 12,400-lb basket WLL | Reinforced wrapped lifting eyes | Value crane & backhoe sling pack"),
    ),
    "Chain Hoists, Lever Pullers & Clamps": (
        ("Sumner", "Pro Industrial Lever Chain Hoist, Manual Chain Fall & Vertical Plate Clamp", "Dual-pawl Weston load brake | Grade 100 alloy load chain | 360° forged safety-latch hooks"),
        ("VEVOR", "Budget Line 1.5-Ton & 3-Ton Lever Chain Come-Along Hoist & Beam Trolley", "G80 galvanized manganese chain | One-hand free-wheel positioning | Budget Line rigging hoist"),
    ),
    "Grade 70/100 Chains & Load Binders": (
        ("Vulcan", "Pro DOT Grade 70 / Grade 100 Transport Binder Chain & Forged Ratchet Binder", "NACM & FMCSA/DOT stamped every link | 4:1 design factor verified | Recoil-free ratcheting gear"),
        ("KJE", "Budget Line 4-Pack 3/8\" x 20' G70 Transport Chains & Ratchet Load Binders", "6,600-lb WLL chains + 9,200-lb WLL binders | Yellow zinc dichromate plating | Hotshot trailer value bundle"),
    ),
    "Flatbed Winch Straps, Tarps & Stakes": (
        ("Vulcan", "Pro 4\" x 30' Heavy-Duty Flatbed Winch Strap, Corner Protectors & Lumber Tarp", "5,400-lb WLL resin-coated webbing | 18-oz waterproof vinyl D-ring tarp | Meets CVSA tie-down rules"),
        ("Mytee Products", "Budget Line 10-Pack 4\" x 30' Flatbed Winch Straps & Edge Protector Pack", "5,400-lb WLL w/ flat hooks | Includes plastic vee-board corner guards | Fleet replacement value pack"),
    ),
    "Oversize Load Banners, Beacons & Safety": (
        ("Federal Signal", "Pro SAE Class 1 Magnetic Amber LED Strobe Beacon & Mesh Oversize Load Kit", "SAE J845 Class 1 daylight visibility | 90-lb neodymium roof magnet | Heavy brass-grommet mesh banner"),
        ("Mytee Products", "Budget Line Complete Pilot Car & Wide-Load 18\" Flag, Banner & LED Beacon Kit", "Includes 2 reversible Oversize banners + 4 red/orange flags | Magnetic wire-loop frame mounts | DOT compliant"),
    ),
    "FR Shirts, Coveralls & Winter Outerwear": (
        ("Carhartt", "Pro Flame-Resistant Force NFPA 2112 / CAT 2 Henley, Coverall & Duck Parka", "UL-classified NFPA 2112 & NFPA 70E CAT 2 | Exterior compliance labels | FastDry sweat-wicking FR cotton"),
        ("Rasco FR", "Budget Line NFPA 2112 CAT 2 Lightweight FR Work Shirt & Deluxe Coverall", "ATPV 8.5 cal/cm² arc & flash-fire rated | Pre-washed 7.5-oz FR cotton | Best value crew FR uniform"),
    ),
    "Pipeline & Oilfield Safety Work Boots": (
        ("Ariat", "Pro WorkHog Waterproof Composite-Toe Metatarsal Oilfield Wellington Pull-On Boot", "ASTM F2413 I/75 C/75 EH + PR puncture resistant | Duratread oil/acid-slip outsole | ATS Max stability shank"),
        ("Timberland PRO", "Budget Line Pit Boss 6-Inch Steel-Toe EH Slip-Resistant Leather Work Boot", "ASTM F2412/2413 steel safety toe | Electrical Hazard (EH) protection | Padded top collar comfort"),
    ),
    "Hard Hats, Welding Shields & Safety Glasses": (
        ("MSA", "V-Gard Full-Brim Class E Slotted Hard Hat & skullgard High-Heat Phenolic Helmet", "ANSI/ISEA Z89.1 Class E 20,000V | Fas-Trac III ratchet suspension | Radiant-heat rated up to 350°F"),
        ("Pyramex", "Budget Line ANSI Z89.1 4-Point Ratchet Full-Brim Hard Hat & Z87+ Anti-Fog Eyewear", "High-density polyethylene shell | Replaceable brow sweatband | Crew-pack value pricing"),
    ),
    "ANSI Impact, Rigging & Cut Gloves": (
        ("HexArmor", "Pro Rig Lizard 2090X / Chrome Series ANSI A6 Cut & Level 2 TPR Impact Rigger Glove", "ANSI/ISEA 138 Level 2 dorsal TPR armor | SuperFabric / A6 cut-resistant palm | Hi-vis oil-grip sandy nitrile"),
        ("Radians", "Budget Line ANSI Cut A4 & TPR Back-of-Hand Impact Oilfield Mechanics Gloves", "Full finger & metacarpal TPR impact bumpers | Reinforced thumb saddle | Affordable multi-pair crew pack"),
    ),
    "H2S / 4-Gas Monitors & Respiratory": (
        ("BW Technologies", "Pro GasAlertMicroClip XL 4-Gas (H2S/CO/O2/LEL) & BW Clip 2-Year H2S Monitor", "IP68 intrinsically safe Class I Div 1 | IntelliFlash green compliance LED | 95 dB alarm + vibration"),
        ("3M", "Value 6000/7500 Series Half-Face Silicone Respirator & Organic Vapor / P100 Cartridges", "NIOSH-approved OV/AG/P100 particulate filtration | Cool Flow exhalation valve | Soft silicone face seal"),
    ),
    "Fall Protection, Spill Kits & First Aid": (
        ("3M", "DBI-SALA ExoFit Dual-Leg SRL Fall Arrest Harness & 50-Gal OSHA Truck Spill Kit", "ANSI Z359.11 aluminum dorsal D-ring | Quick-connect tongue buckles | Absorbs oil, diesel & hydraulic fluid"),
        ("Ergodyne", "Budget Line Squids Tool Lanyards, 5-Point Harness & 20-Gal Zippered Truck Spill Kit", "OSHA/ANSI compliant 5-point adjustment | Fits behind service-truck seat | High-visibility orange bag"),
    ),
    "Diesel Transfer Pumps, Meters & Filters": (
        ("Fill-Rite", "Pro FR1210H / FR4210H 12V 15–20 GPM Cast-Iron Diesel Transfer Pump & Digital Meter", " thermally protected 12V DC motor | Cast-iron rotary vane housing | Auto-shutoff nozzle & 10-micron filter"),
        ("VEVOR", "Budget Line 12V 15 GPM Portable Diesel & Kerosene Fuel Transfer Pump Kit w/ Auto Nozzle", "Self-priming copper-wound 12V pump | Includes 13' delivery hose, suction hose & meter | Slip-tank value kit"),
    ),
    "Grease Guns, Hose Reels & Lubrication": (
        ("Milwaukee", "M18 2-Speed 10,000 PSI Cordless Grease Gun & LockNLube Locking Coupler Combo", "10,000 PSI max operating pressure | Preset grease counter dial | 48\" flexible high-pressure whip hose"),
        ("NEIKO", "Budget Line Heavy-Duty Pistol-Grip 7,000 PSI Manual & Air-Operated Grease Gun Kit", "Includes 18\" flex hose + rigid steel extension | Air-bleeder valve eliminates air pockets | Under-$35 truck spare"),
    ),
    "Hydraulic Jacks, Rams, Pumps & Couplers": (
        ("Enerpac", "Pro 10,000 PSI Single-Acting Alloy Hydraulic Ram Cylinder & Two-Speed Hand Pump", "CR-400 high-flow quick coupler | Baked enamel corrosion finish | Collar & plunger mounting threads"),
        ("VEVOR", "Budget Line 20-Ton / 30-Ton Hollow & Low-Profile Hydraulic Jack Cylinder + Hand Pump", "10,000 PSI two-stage manual pump | Fits tight equipment undercarriages | Complete hose & gauge kit"),
    ),
    "Service Truck Compressors & Air Tools": (
        ("Ingersoll Rand", "Pro 2135QXPA 1/2\" & 2850MAX 1\" Pneumatic Truck Impact Wrench & Air Compressor", "1,100 to 2,100 ft-lbs nut-busting air torque | Feather-touch trigger & titanium hammer case | Fleet tire bay standard"),
        ("Astro Pneumatic", "Budget Line Onyx 1/2\" Stubby 650 Ft-Lb Air Impact Wrench & Air Die Grinder Kit", "Jumbo hammer mechanism in 4.3\" stubby body | Fits inside brake caliper brackets | High-value pneumatic tool"),
    ),
    "12V/24V Jump Packs, Chargers & HD Scanners": (
        ("NOCO", "Boost Pro GB150 3,000A 12V & GB251+ 24V Commercial Diesel Lithium Jump Starter", "Starts up to 9.0L+ gas & 7.0L+ diesel engines | Spark-proof & reverse-polarity protected | Built-in digital voltmeter"),
        ("Topdon", "Budget Line JS2000 / JS3000 12V 2,500A Peak Lithium Jump Starter & Power Bank", "35 jump starts on a single charge | Boost button revives dead 0V batteries | IP64 ruggedized case"),
    ),
    "Bi-Directional OBD2 Readers & Diagnostic Scanners": (
        ("Autel", "MaxiCOM / MaxiSys Bi-Directional Active-Test OBD2 & Heavy-Duty Diagnostic Tablet", "3,000+ Bi-Directional solenoid & actuator tests | 35+ service resets + CAN-FD/DoIP | AutoVIN & Pre/Post scan PDF"),
        ("XTOOL", "Budget Line Bi-Directional Control OBD2 Scanner w/ Multi-Year Free Wi-Fi Updates", "Full Bi-Directional active tests at a value price | DPF, Injector, ABS bleed, EPB & BMS resets | No mandatory subscription"),
    ),
    "Tire Service, Mud Flaps & Shop Consumables": (
        ("Milton", "Pro S-506 Dual-Head Chuck Service-Truck Tire Inflator Gauge & Bead Seater", "Calibrated 10–160 PSI solid brass movement | 15\" EPDM hose + replaceable gauge cartridge | Made in USA"),
        ("Astro Pneumatic", "Budget Line 3018 Digital 0.1-PSI Resolution Tire Inflator w/ Stainless Braided Hose", "Backlit LCD reads PSI, Bar & kPa | 21\" stainless braided hose + dual AAA battery life | Shop bay favorite"),
    ),
    "Cordless Tower, Magnetic & Flood Lights": (
        ("Milwaukee", "M18 ROVER Magnetic Folding Floodlight & Dual-Power Rocket Tower Light", "TRUEVIEW high-definition color-accurate LEDs | Rare-earth magnets grip steel I-beams | Impact-resistant polycarbonate lens"),
        ("Astro Pneumatic", "Budget Line Rechargeable Magnetic COB LED Folding Mechanics Work Light", "Stepless dimming dial up to 1,000 lumens | 180° swiveling magnetic base | USB-C fast charging"),
    ),
    "Intrinsically Safe Flashlights & Headlamps": (
        ("Streamlight", "Survivor / Dualie Class I Div 1 Intrinsically Safe Right-Angle & Hardhat Light", "UL Class I, Div 1 Groups C,D Hazardous Location | Smoke-piercing spot + downward walk flood | Spring steel coverall clip"),
        ("Nightstick", "Budget Line Class I Div 1 Intrinsically Safe 3AA Dual-Light Flashlight & Headlamp", "cULus, ATEX & IECEx Zone 0 certified | Dual spot + flood beams | High-visibility green/yellow polymer"),
    ),
    "EDC, Tactical, Magnetic & Rechargeable Flashlights": (
        ("Streamlight", "Stinger / Wedge / ProTac & Fenix PD36R Pro Rechargeable Aluminum Duty Flashlight", "1,000 to 2,800 lumens high-intensity output | USB-C rechargeable Li-ion battery | IP68 waterproof aircraft aluminum"),
        ("Coast", "Budget Line Rechargeable & Dual-Power Slide-Focus Tactical & Magnetic Work Flashlight", "Spot-to-flood optical focus bezel | Runs on rechargeable pack or alkaline batteries | Lifetime warranty value"),
    ),
    "Generators, Power Stations & Spider Boxes": (
        ("Honda", "Pro EU2200i / EU3200i Super-Quiet Fuel-Injected Inverter Generator & CEP Spider Box", "Clean pure-sine power for computers & chargers | Eco-Throttle fuel saver | OSHA GFCI 50A spider distribution"),
        ("VEVOR", "Budget Line 50-Amp Temporary Jobsite Power Distribution Spider Box w/ 6x 20A GFCI Outlets", "NEMA 3R rainproof powder-coated steel | 6x 20A GFCI + Twist-Lock breakers | Portable jobsite power hub"),
    ),
    "Heavy Cold-Weather Cords & Welding Adapters": (
        ("Southwire", "Pro Coleman Cable 10/3 SJTW -58°F Arctic Extreme Cold-Weather Lighted Extension Cord", "Remains flexible down to -58°F (-50°C) | Lighted power-check female receptacle | 10-AWG pure copper carries full 15A/20A"),
        ("VEVOR", "Budget Line 25-Ft / 50-Ft 10/3 SJOOW Heavy-Duty Welder & Generator Extension Cord", "Pure copper conductors w/ oil-resistant CPE jacket | NEMA 6-50P to 6-50R or L14-30 twist-lock | High-value shop lead"),
    ),
    "Jobsite Gang Boxes, Truck Chests & Cases": (
        ("Crescent JOBOX", "Pro Site-Vault 48\" / 60\" Heavy-Duty 16-Gauge Steel Jobsite Gang Box & Pelican Case", "Recessed 3-point padlock security housing | 4-way forklift skids & EZ-Loader casters | Rain-channel lid overhang"),
        ("VEVOR", "Budget Line Aluminum Diamond-Plate Truck Bed Crossover & Flatbed Underbody Tool Box", "Rustproof tread-plate aluminum | Stainless locking T-handle w/ weather seal | Fits pickups & equipment trailers"),
    ),
    "Two-Way Radios, Coolers & Jobsite Heaters": (
        ("Midland", "Pro GXT1000VP4 50-Channel Waterproof GMRS Two-Way Radio Pair & Igloo 5-Gal Cooler", "JIS4 waterproof rating & NOAA weather alert | Whisper mode + SOS siren | Drop-in desktop truck charger"),
        ("DEWALT", "Value DXH12B / Mr. Heater Portable Propane Radiant Jobsite & Ice-Shack Heater", "Runs on 1-lb cylinders or 20-lb tank hose | Low-oxygen ODS & tip-over safety shutoff | Instant winter cab/tent warmth"),
    ),
    "Ultrasonic Wall Thickness & NDT Kits": (
        ("Dakota Ultrasonics", "Pro ZX-3 / ZX-6 Dual-Element Corrosion & Thru-Paint Ultrasonic Wall Thickness Gauge", "Measures remaining pipe wall through painted coatings | 0.025\" to 20\" steel thickness range | NIST calibration trace"),
        ("VEVOR", "Budget Line Digital Ultrasonic Pipe Wall Thickness Gauge (0.04\"–11.8\" Steel/PVC/Aluminum)", "5MHz probe + built-in 4mm calibration block | Stores 500 readings w/ high/low alarm | Includes couplant gel & case"),
    ),
    "Liquid-Filled Pressure Gauges & Hydrotest": (
        ("Ashcroft", "Pro 316 Stainless Glycerin-Filled 0–5,000 / 10,000 PSI Pipeline Hydrotest Pressure Gauge", "1/4\" or 1/2\" lower NPT 316SS wetted parts | Glycerin fill damps pump pulsation | ASME B40.100 Grade 1A (+/- 1%)"),
        ("CARBO Instruments", "Budget Line 2-1/2\" & 4\" Stainless Case Liquid-Filled Pressure Gauge (1/4\" NPT Lower Mount)", "Polycarbonate lens & glycerin vibration damping | Dual PSI / Bar scale | Economical manifold replacement gauge"),
    ),
    "Pipe Calipers, Tally Tapes & Thread Gauges": (
        ("Mitutoyo", "Pro 500-196-30 Absolute AOS Digital Caliper & Lufkin Oil-Gauging Plumb-Bob Derrick Tape", "ABSOLUTE electromagnetic linear encoder | Hardened stainless jaws (0–6\" / 0–8\" / 0–12\") | Zero-reset anywhere on beam"),
        ("iGaging", "Budget Line IP54 Splash-Proof Fractional/Inch/Metric Digital Caliper & Pipe Pit-Depth Gauge", "Displays 1/64\" fractions, inches & mm | Stainless frame w/ thumb roller | Under-$45 inspection kit"),
    ),
    "Borescopes, Sewer Cameras & Pipe Locators": (
        ("RIDGID", "Pro SeeSnake microCA-350 Inspection Camera & SeekTech Underground Pipe/Cable Locator", "12V rechargeable recording monitor | Waterproof aluminum camera head + sapphire lens | Locates energized & passive lines"),
        ("DEPSTECH", "Budget Line Dual-Lens 1080P Industrial Endoscope Borescope w/ 5\" IPS Screen & 16.5-Ft Semi-Rigid Snake", "Front + Side view split-screen 1080P camera | IP67 waterproof 7.9mm probe fits spark-plug holes | No phone or Wi-Fi required"),
    ),
    "Thermal Imagers, Pyrometers & Leak Detectors": (
        ("FLIR", "Pro TG267 / E5 Pro MSX Thermal Imaging Camera & Ultrasonic Acoustic Gas Leak Detector", "MSX image enhancement overlays visual component labels | Bullseye laser pointer + Type-K thermocouple | Spots hot bearings & steam traps"),
        ("TOPDON", "Budget Line TC004 / TC001 Handheld 256x192 IR Resolution Thermal Imaging Camera", "High-res 256x192 IR sensor + 12-hour battery | Auto hot/cold spot tracking + PC analysis | Best value electrical & pipe thermal camera"),
    ),
    "Rotary Lasers, Digital Levels & Multimeters": (
        ("Fluke", "Pro 87V / 117 Industrial True-RMS Multimeter & Klein Digital Magnetic Angle Torpedo Level", "CAT III 1000V / CAT IV 600V lifetime accuracy | Rare-earth V-groove magnet grips conduit & pipe | Audible 0° & 90° level tone"),
        ("KAIWEETS", "Budget Line True-RMS 6000-Count Auto-Ranging Digital Multimeter & Self-Leveling Green Cross-Line Laser", "Measures AC/DC V, Amps, Capacitance & Temp | 4x brighter Osram green laser beams | Includes magnetic L-bracket & case"),
    ),
    "Pipe Fence Coping, Saddles & Notchers": (
        ("Hougen", "Pro Heavy-Duty Tubing & Pipe Notcher (Copes 3/4\" to 3\" Schedule 40 Drill-Stem Fence Pipe)", "Needle roller bearings & 1\" hardened spindle | Adjusts 0° to 60° for saddle & corner joints | Mounts to drill press or hand drill"),
        ("VEVOR", "Budget Line Pipe & Tube Notcher for 3/4\" to 3\" OD Pipe + Magnetic Pipe Cutting Saddle Guide Set", "Cuts clean 0°–50° saddle copes w/ standard hole saws | Heavy steel frame bolts to bench or vise | Ranch fencing time-saver"),
    ),
    "Weld-On Hinges, Latches & Gate Hardware": (
        ("Skidril", "Pro Heavy-Duty Greaseable Weld-On Steel Barrel Hinges & Gravity Bull-Proof Pasture Gate Latch", "Machined carbon steel w/ Zerk grease fitting | 900-lb+ gate leaf capacity | Padlockable from both sides of horse/cattle gate"),
        ("VEVOR", "Budget Line 4-Pair Heavy-Duty Weld-On Barrel Gate Hinges & Two-Way Slam Latch Hardware Kit", "Low-carbon weldable steel barrels | Ball-bearing pivot for sag-free 16' pipe gates | Value corral hardware pack"),
    ),
    "Gas Post Drivers, Augers & T-Post Tools": (
        ("Skidril", "Pro G20X Honda 4-Stroke Gas Powered Post Driver & Heavy Lever T-Post Puller Jack", "Genuine Honda GX35 4-stroke engine — no fuel mixing | Drives T-posts, ground rods & 2-3/8\" pipe | High-leverage cam jaw puller"),
        ("VEVOR", "Budget Line 52CC 2-Stroke Gas T-Post & Pipe Pile Driver w/ 3 Barrel Adapters & Rolling Case", "1,700W engine delivers 55J @ 1,350 BPM | Includes 55mm, 70mm & 100mm driving heads | Drives a T-post in 15 seconds"),
    ),
    "Solar Fence Chargers, Wire & Strainers": (
        ("Gallagher", "Pro Lithium Solar Electric Fence Energizer, Digital Fault Finder & Geared Reels", "Internal lithium battery + smart solar panel | Digital current/voltage fault arrow finder | Livestock control up to 30 miles"),
        ("Parmak", "Budget Line Solar-Pak 6V / 12V American-Made Solar Electric Fence Charger & Insulator Pack", "Weatherproof steel case + built-in performance meter | Includes 6V gel battery | Dependable pasture perimeter power"),
    ),
    "Stock Tank Valves, Waterers & Ag Pumps": (
        ("Jobe Valves", "Pro Topaz 1\"–1-1/4\" High-Flow Differential Float Valve & Ritchie Automatic Heated Stock Waterer", "200 GPM high-flow non-corrosive float valve | Mounts above or below water line | Freeze-resistant livestock trough valve"),
        ("Rubbermaid Commercial", "Budget Line All-Brass 300-GPM Heavy-Duty Stock Tank Float Valve & Submersible De-Icer", "Cast bronze body w/ adjustable float arm | Clamps onto any steel, poly or concrete trough | Keeps winter stock water open"),
    ),
    "Livestock Chute, Trailer & Ranch Hardware": (
        ("B&W Trailer Hitches", "Pro Turnoverball Gooseneck Hitch & Tow & Stow Adjustable Tri-Ball Receiver Hitch (Made in USA)", "30,000-lb GTW / 7,500-lb VTW rated | Stows under bumper when not towing | Solid machined stainless pins"),
        ("CURT", "Budget Line Heavy-Duty Forged Pintle Hook, 2-5/16\" Gooseneck Coupler & 12,000-Lb Drop-Leg Trailer Jack", "Square-tube 12,000-lb side-wind drop-leg jack | Weld-on or bolt-on trailer tongue mount | Black powder-coat finish"),
    ),
}


def infer_quality_tier(brand: str, title: str, badge: str) -> str:
    b = brand.strip().lower()
    if b in BUDGET_BRANDS_LOWER:
        return "budget_line"
    combined = f"{title} {badge}".lower()
    if any(k in combined for k in ("budget line", "value", "shop saver", "economy")):
        return "budget_line"
    return "pro_grade"
