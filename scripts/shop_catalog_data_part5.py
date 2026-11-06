"""Compact industrial product matrices for Categories 6-8 (Lighting, Inspection, Ranch/Pipe)."""

def _build_part5():
    d = {}
    # 6. JOBSITE LIGHTING, POWER & STORAGE (115: 20,19,19,19,19,19)
    d["Cordless Tower, Magnetic & Flood Lights"] = [
        (brand, f"{brand} {item}", "Night-Shift LED", f"Impact-rated jobsite {item.lower()} lighting up bellholes, pipe racks, and service bays.", "IP54+ weather/dust seal | High-CRI neutral LED | Drop-tested lens")
        for brand, item in [
            ("Milwaukee", "2131-20 M18 ROCKET Dual-Power 2,500-Lumen Telescoping Tripod Tower Light"),
            ("Milwaukee", "2136-20 M18 ROCKET 6,000-Lumen Dual-Pack Tower Light / Charger"),
            ("Milwaukee", "2366-20 M18 ROVER 4,000-Lumen AC/DC Dual-Power Flood Light"),
            ("Milwaukee", "2125-20 M12 Underbody Magnetic Articulating Service-Truck Light"),
            ("Milwaukee", "2128-22 M12 ROVER Service & Repair USB Magnetic Flood Light (2-Pack)"),
            ("Milwaukee", "2363-20 M18 700-Lumen 360-Deg Hanging Jobsite Lantern w/ USB Port"),
            ("DEWALT", "DCL079B 20V MAX 3,000-Lumen Telescoping Cordless Tripod Light"),
            ("DEWALT", "DCL077B 12V/20V MAX Compact 2,000-Lumen Task Flood Light"),
            ("DEWALT", "DCL043 20V MAX 1,000-Lumen Long-Distance Spot / Flood Pistol Worklight"),
            ("Makita", "DML811 18V LXT / AC Corded 3,000-Lumen Hybrid Flood Light"),
            ("Lind Equipment", "Beacon360 Blaze 13,000-Lumen 360-Deg Cast-Aluminum Area Light"),
            ("Wobblelight", "Self-Righting 360-Deg Jobsite Area Work Light (5,000+ Lumens)"),
            ("Southwire", "100-Ft Heavy-Duty 10,000-Lumen Linkable Overhead LED String Jobsite Lights"),
            ("Southwire", "50-Ft Commercial Cage-Protected Linkable Temporary String Work Lights"),
            ("Rigid Industries", "D-Series PRO Flood Diffused 12V/24V Service-Body Work Light Pair"),
            ("Buyers Products", "5-Inch Square 4,050-Lumen 12V–24V Die-Cast Aluminum Crane/Bed Flood Lamps (4-Pack)"),
            ("Braun / Astro", "52SL Dual-Sided 1,000-Lumen Wireless-Charging Magnetic Slim Folding Bar Light"),
            ("Husky / Snap-on", "10,000-Lumen Dual-Head Corded Telescoping Aluminum Tripod Floodlight"),
            ("Streamlight", "44945 Super Siege 1,100-Lumen Waterproof Rechargeable Scene Lantern"),
        ]
    ]

    d["Intrinsically Safe Flashlights & Headlamps"] = [
        (brand, f"{brand} {item}", "Class I Div 1 IS", f"UL/CSA Class I Division 1 intrinsically safe {item.lower()} certified for gas/oil zones.", "Class I, Div 1 Groups A-D | IP67/IP68 waterproof | Hard-hat compatible")
        for brand, item in [
            ("Streamlight", "90540 Survivor LED Right-Angle Class I Div 1 Clip-On Rig Lantern (Orange)"),
            ("Streamlight", "90952 Survivor X USB/Alkaline Low-Profile Right-Angle Intrinsically Safe Light"),
            ("Streamlight", "68750 Dualie 3AA Spot + Downward-Flood Intrinsically Safe Flashlight (Yellow)"),
            ("Streamlight", "68780 Dualie 3AA Red-Laser Pointer + LED Inspection Intrinsically Safe Light"),
            ("Streamlight", "68202 ProPolymer 4AA Waterproof Non-Conductive Haz-Loc Flashlight"),
            ("Streamlight", "61601 Double Clutch USB/AAA Hard-Hat Rubber-Strap Headlamp"),
            ("Streamlight", "61052 Septor 7-LED Intrinsically Safe Hard-Hat Strap Headlamp"),
            ("Streamlight", "75458 Stinger DS LED HL Rechargeable Aluminum Mechanic Shop Flashlight"),
            ("Streamlight", "66604 MicroStream USB Pocket Inspection Penlight (Coyote/Black)"),
            ("Nightstick", "XPP-5422GMX Dual-Light Spot/Flood + Dual-Magnet Intrinsically Safe Flashlight"),
            ("Nightstick", "XPP-5462GX Low-Profile Dual-Light Class I Div 1 Hard-Hat Headlamp"),
            ("Nightstick", "NSP-1174 4AA Intrinsically Safe Right-Angle Chest/Pocket Work Light"),
            ("Nightstick", "XPR-5568GX Rechargeable Intrinsically Safe Dual-Light Hard-Hat Headlamp"),
            ("Pelican", "3315Z0 ATEX Zone 0 / Class I Div 1 Ultra-Compact Safety Yellow LED Light"),
            ("Pelican", "2765Z0 Class I Div 1 Downcast + Main-Beam Hard-Hat Safety Headlamp"),
            ("Pelican", "3415MZ0 Intrinsically Safe Right-Angle Articulating-Head Magnetic Light"),
            ("Pelican", "9415Z0 4-LED High-Output Handheld Class I Div 1 Tank & Lease Lantern"),
            ("Klein Tools", "56062 Rechargeable Auto-Off Hard-Hat Front/Back Mount LED Work Headlamp"),
            ("Tracerline", "OPTI-PRO UV Cordless Violet-LED Hydraulic, Oil & AC Dye Leak Flashlight"),
        ]
    ]

    d["Generators, Power Stations & Spider Boxes"] = [
        (brand, f"{brand} {item}", "Clean Jobsite Power", f"Reliable temporary jobsite power {item.lower()} running grinders, chargers, and crew trailers.", "OSHA GFCI protected | Pure-sine / AVR output | Cold-start ready")
        for brand, item in [
            ("Honda Power", "EU2200i Companion 2,200-Watt Super-Quiet Portable Inverter Generator w/ CO-Minder"),
            ("Honda Power", "EU3200i 3,200-Watt Fuel-Injected Bluetooth Portable Inverter Generator"),
            ("Generac", "GP6500 6,500-Watt COsense Jobsite Portable Gas Generator w/ Electric Start"),
            ("Westinghouse", "WGen9500DFc 12,500/9,500-Watt Dual-Fuel (Gas/Propane) Remote-Start Generator"),
            ("Champion Power", "4,500-Watt Dual-Fuel Enclosed Quiet RV/Trailer Ready Inverter Generator"),
            ("Milwaukee", "MXF002-2XC MX FUEL CARRY-ON 3600W/1800W Pure-Sine Battery Power Station"),
            ("EcoFlow", "DELTA Pro 3,600Wh LiFePO4 Portable Jobsite & Service-Truck Power Station"),
            ("Jackery", "Explorer 2000 Plus Expandable LiFePO4 Heavy-Duty Field Office Power Station"),
            ("CEP / Southwire", "50-Amp 125/250V CS6365 Temporary Power Spider Distribution Box (6 GFCI 20A + 30A)"),
            ("Southwire", "50-Amp Heavy-Duty Steel Roll-Cage Temporary Jobsite Spider Power Box"),
            ("CEP", "6-Ft 50-Amp 6/4 SOOW California-Standard Twist-Lock Spider-Box Feeder Cord"),
            ("Yellow Jacket", "2883 2-Ft 12/3 SJTW Heavy-Duty Inline GFCI 3-Outlet Power Block Adapter"),
            ("Southwire", "14880002 ShockShield Manual-Reset Plug-In 15A/20A OSHA Jobsite GFCI Adapter"),
            ("Reliance Controls", "Pro/Tran2 30-Amp 10-Circuit Manual Transfer Switch Kit for Shop/Office"),
            ("Generac / Reliance", "50-Amp NEMA SS2-50P Weatherproof Twist-Lock Generator Power Inlet Box"),
            ("Renogy / Victron", "2000W 12V DC to 120V AC Pure-Sine-Wave Service-Truck Hardwire Power Inverter"),
            ("Honda / GenTent", "All-Weather Running Generator Storm Canopy Cover"),
            ("Reliance Controls", "THP108 Digital Generator Wattage & Load Balancing Meter"),
            ("No-Spill / Midwest", "5-Gallon Push-Button Thumb-Control CARB/EPA Generator Fuel Can (2-Pack)"),
        ]
    ]

    d["Heavy Cold-Weather Cords & Welding Adapters"] = [
        (brand, f"{brand} {item}", "-50C Sub-Zero Cord", f"Heavy copper {item.lower()} staying flexible in sub-zero winter lease conditions.", "100% pure copper | Lighted power ends | Oil & arctic jacket")
        for brand, item in [
            ("Southwire", "Polar/Solar 10/3 SJTW 50-Ft -50C Sub-Zero All-Weather Lighted Extension Cord"),
            ("Southwire", "Polar/Solar 10/3 SJTW 100-Ft High-Load Grinder & Compressor Extension Cord"),
            ("Southwire", "Polar/Solar 12/3 SJTW 50-Ft Cold-Weather Blue TPE Jobsite Extension Cord"),
            ("Southwire", "Polar/Solar 12/3 SJTW 100-Ft Cold-Weather Lighted-End Extension Cord"),
            ("Yellow Jacket", "2885 12/3 SJTW 50-Ft Heavy-Duty 3-Outlet Lighted Power-Block Extension Cord"),
            ("Coleman Cable", "10/3 SOOW 50-Ft Black EPDM Rubber Oil/Spark-Resistant Industrial Shop Cord"),
            ("Iron Box / Parkworld", "8/3 AWG 50-Amp NEMA 6-50P to 6-50R Heavy-Duty 50-Ft Welder Extension Cord"),
            ("Parkworld", "6/3 AWG 50-Amp NEMA 6-50 Heavy 25-Ft MIG/Stick/Plasma Welder Extension Cord"),
            ("Parkworld", "NEMA 14-50P (Generator/RV 50A) to 6-50R (240V Welder) Molded Pigtail Adapter"),
            ("Parkworld", "NEMA L14-30P Twist-Lock Generator Plug to 4x 5-20R Household Breaker Breakout Cord"),
            ("AC Works", "NEMA L14-30P 30A 4-Prong Generator Plug to 6-50R 240V Welder Adapter"),
            ("Reliance / Champion", "30-Amp L14-30 10/4 SJTW 25-Ft Twist-Lock Generator Power Cord"),
            ("Reliance / Champion", "50-Amp 6/3+8/1 STW 25-Ft Heavy Generator-to-Spider/Transfer Cord"),
            ("Coxreels", "PC13-5012-A Industrial Spring-Rewind 12/3 x 50-Ft Steel Cord Reel w/ Quad Box"),
            ("Reelcraft", "L4545 12/3 45-Ft Heavy Shop Ceiling/Truck-Mount Retractable Triple-Tap Cord Reel"),
            ("Hubbell Wiring", "HBL5366C & HBL5369C Industrial Black/White Nylon 20A Cord Replacement Ends (4-Set)"),
            ("Hubbell Wiring", "HBL2711 Twist-Lock NEMA L14-30P & L14-30C Heavy-Duty Locking Plug/Connector Pair"),
            ("Checkers Linebacker", "5-Channel Heavy Polyurethane Drive-Over Semi-Truck Cable & Hose Protector Ramp"),
            ("Wrap-It", "Super-Stretch Ballistic Nylon Hook-and-Loop Welding Lead & Cord Carrier Straps (8-Pack)"),
        ]
    ]

    d["Jobsite Gang Boxes, Truck Chests & Cases"] = [
        (brand, f"{brand} {item}", "Bolt-Cutter Proof", f"Heavy steel or watertight polymer {item.lower()} securing high-value tools on yards and trucks.", "Recessed lock housing | Weather-stripped lid | Forklift/bed ready")
        for brand, item in [
            ("Crescent JOBOX", "60-Inch Heavy-Duty 14-Ga Steel Site-Vault Jobsite Chest (24\" x 60\")"),
            ("Crescent JOBOX", "60-Inch Site-Vault Slope-Front Piano Gang Box w/ Built-In Shelving & Cord Pass-Thru"),
            ("Crescent JOBOX", "Field Office Heavy-Duty Steel Mobile Plan-Table & Lockable Blueprint Cabinet"),
            ("KNAACK", "Model 42 / 48-Inch Classic Tan 16-Gauge Steel Watchman IV Lockable Gang Box"),
            ("KNAACK", "Model 89 Storagemaster 60-Inch Piano-Style Welder & Pipefitter Gang Box"),
            ("Weather Guard", "127-5-02 Saddle Box Matte-Black Aluminum Full-Size Pickup Crossover Toolbox"),
            ("Weather Guard", "Lo-Side Matte-Black Aluminum Bed-Rail Truck Side Box (Driver/Passenger)"),
            ("Buyers Products", "36\" x 18\" x 18\" Gloss-Black Diamond-Tread Steel Underbody Flatbed Truck Box"),
            ("Buyers Products", "48\" x 18\" x 18\" Barn-Door Stainless-Latch Flatbed Underbody Rigging Box"),
            ("Buyers Products", "Top-Mount 72-Inch Steel Service-Body Bed-Rail Mechanics Compartment Box"),
            ("Pelican", "1510 Carry-On IP67 Watertight Crushproof Instrument & Gauge Case w/ Pick-N-Pluck Foam"),
            ("Pelican", "1615 Air Lightweight Wheeled Watertight Calibration & NDT Equipment Case"),
            ("Pelican", "1650 Large Wheeled Crushproof Heavy Tool & Analyzer Case w/ Foam"),
            ("Pelican", "Vault V700 Takedown Heavy Polymer Weatherproof Long-Level & Torque-Wrench Case"),
            ("Apache / Condition 1", "4800 Weatherproof IP65 Hard Gauge & Laser Case w/ Customizable Foam"),
            ("Master Lock", "ProSeries 6271 Hidden-Shackle Solid Die-Cast Puck Padlock + Hasp (Keyed Alike Pair)"),
            ("Master Lock", "Magnum M930XDLH Solid-Body Boron-Carbide Shackle Gang-Box Padlocks (Keyed Alike 4-Pack)"),
            ("ABUS", "Granit 37RK/70 Maximum-Security Alloy-Steel Shrouded Gang-Box Padlock"),
        ]
    ]

    d["Two-Way Radios, Coolers & Jobsite Heaters"] = [
        (brand, f"{brand} {item}", "Crew Welfare & Comms", f"All-season field crew {item.lower()} keeping crane signals crisp and crews hydrated/warm.", "Jobsite ruggedized | Extreme heat/cold ready | Field tested")
        for brand, item in [
            ("Motorola Solutions", "RMU2080d 2-Watt 8-Channel UHF Military-Spec Jobsite & Crane Two-Way Radio"),
            ("Motorola Solutions", "CLS1410 / DLR1060 Digital 900MHz Interference-Free Yard Two-Way Radio (2-Pack)"),
            ("Midland", "GXT1000VP4 36-Mile 50-Channel Waterproof GMRS Handheld Crew Radios (Pair + Drop-In Charger)"),
            ("Midland", "MXT275 MicroMobile 15-Watt GMRS Pickup & Haul-Truck Cab Radio Kit w/ Magnetic Antenna"),
            ("Motorola / Klein", "Heavy-Duty IP54 Noise-Canceling Shoulder Speaker Microphone for Hard-Hat Crews"),
            ("Igloo Industrial", "5-Gallon High-Vis Yellow/Red Heavy-Duty Insulated Drinking Water Cooler"),
            ("Igloo Industrial", "10-Gallon Crew-Size Seat-Top Insulated Jobsite Water Jug + Cup Dispenser"),
            ("Buyers Products", "Lockable Heavy-Duty Steel Flatbed/Service-Truck 5-Gallon Water Cooler Rack"),
            ("YETI", "Tundra 65 Rotomolded Bear-Proof Heavy Ice Retention Crew Truck Cooler"),
            ("Stanley", "Classic Legendary 2.0-Quart Vacuum-Insulated Hammered-Green Steel Thermos"),
            ("Sqwincher", "Zero-Sugar Industrial Electrolyte Freezer Pops & Stick Packs Variety Box (100-Ct)"),
            ("Mr. Heater", "MH60QFAV 60,000-BTU Forced-Air Propane Jobsite & Shop Torpedo Heater"),
            ("Mr. Heater", "MH125KTR 125,000-BTU Multi-Fuel Kerosene/Diesel Thermostatic Shop Torpedo Heater"),
            ("Mr. Heater", "Big Buddy MH18B 18,000-BTU Indoor-Safe Crew-Shack & Tent Propane Heater"),
            ("Maxx Air", "BF24TF 24-Inch Tilting High-Velocity Direct-Drive Steel Shop Drum Fan (4,000 CFM)"),
            ("Maxx Air", "36-Inch Belt-Drive Heavy-Duty Fab-Shop Barrel Circulation Fan"),
            ("Allegro Industries", "9533-15 8-Inch Confined-Space Manhole Axial Ventilation Blower + 15-Ft Ducting"),
            ("Rite in the Rain", "All-Weather Waterproof Hard-Cover Pipe-Tally & Field Engineering Notebook (3-Pack)"),
            ("King Canopy / Eurmax", "10' x 10' Commercial Pop-Up Flame-Retardant Welder & Ditch Shade Canopy"),
        ]
    ]

    # 7. INSPECTION, GAUGES & PIPE TESTING (110: 19,19,18,18,18,18)
    d["Ultrasonic Wall Thickness & NDT Kits"] = [
        (brand, f"{brand} {item}", "OCTG & Line Pipe NDT", f"Non-destructive inspection {item.lower()} verifying steel wall thickness, pits, and weld soundness.", "NIST calibration ready | Steel/OCTG preset | Padded field case")
        for brand, item in [
            ("Dakota Ultrasonics", "ZX-1 Digital Dual-Element Ultrasonic Steel & Pipe Corrosion Wall-Thickness Gauge"),
            ("Dakota Ultrasonics", "ZX-6 DL Data-Logging A-Scan/Thickness Ultrasonic Pipe & Tank Gauge"),
            ("REED Instruments", "R9000 Data-Logging Ultrasonic Thickness Gauge w/ 5MHz Transducer Probe"),
            ("Phase II", "UTG-2900Thru-Coat Ultrasonic Wall-Thickness Gauge (Reads Through Paint/Epoxy)"),
            ("Echo / NDT Supply", "5MHz Dual-Element Potted-Cable Replacement Ultrasonic Pipe Probe (3/8\" Tip)"),
            ("NDT Supply", "High-Temperature Ultrasonic Probe (Up to 650F Hot Process Pipe Inspection)"),
            ("NDT Supply", "1018 Carbon Steel 5-Step Calibration Test Block (0.100\", 0.200\", 0.300\", 0.400\", 0.500\")"),
            ("Echo Ultrasonics", "Soundsafe / Ultragel II Industrial Ultrasonic Couplant Gel (12-Oz Bottle, 4-Pack)"),
            ("Parker Research", "B-300 Contour AC Articulating-Leg Magnetic-Particle Crack-Detection Yoke Kit"),
            ("Magnaflux", "Y-2 AC Electromagnetic Yoke Kit w/ Grey & Red Dry Mag-Particle Powders"),
            ("Magnaflux", "SK-816 Spotcheck Solvent-Removable Red Dye Penetrant Weld Crack NDT Kit (8-Can Case)"),
            ("Magnaflux", "Zyglo Blacklight UV-A Fluorescent Penetrant Crack Inspection Kit"),
            ("DeFelsko", "PosiTector 6000 FS1 Ferrous Dry-Film Coating & Fusion-Bond Epoxy Mil Gauge"),
            ("Elcometer", "456 Ferrous Digital Paint & Pipeline Coating Thickness Gauge"),
            ("Elcometer / Tinker-Rasor", "Wet-Sponge & High-Voltage Pipeline Holiday Coating Pinhole Detector"),
            ("W.R. Thorpe", "Pit-Depth & Corrosion Evaluation Stainless Dial/Digital Pipe Pitting Gauge"),
            ("Phase II", "PHT-1800 Portable Leeb Rebound Steel & Weld-HAZ Hardness Tester"),
            ("Carson / Bausch", "10x Illuminated Scale Loupe Magnifier for Inspecting Weld Toe Cracks & Pits"),
        ]
    ]

    d["Liquid-Filled Pressure Gauges & Hydrotest"] = [
        (brand, f"{brand} {item}", "316SS / Hydrotest", f"Process-grade {item.lower()} built for hydrostatic spool tests, wellheads, and manifolds.", "ASME B40.100 accuracy | 316SS wetted parts | Vibration-damped glycerin")
        for brand, item in [
            ("Ashcroft", "1009 Duralife 4.5-Inch All-316SS Lower-Mount 1/2\" NPT Pressure Gauge (0–1,000 PSI)"),
            ("Ashcroft", "1009 Duralife 4.5-Inch 316SS Glycerin-Filled Pressure Gauge (0–3,000 PSI)"),
            ("Ashcroft", "1009 Duralife 4.5-Inch 316SS High-Pressure Wellhead Gauge (0–5,000 PSI)"),
            ("Winters Instruments", "PFQ Series 2.5-Inch 304SS/316SS Liquid-Filled 1/4\" NPT Gauge (0–100 PSI)"),
            ("Winters Instruments", "PFQ Series 2.5-Inch 316SS Liquid-Filled 1/4\" NPT Gauge (0–300 PSI)"),
            ("Winters Instruments", "PFQ Series 2.5-Inch 316SS Liquid-Filled 1/4\" NPT Gauge (0–600 PSI)"),
            ("Winters Instruments", "PFQ Series 4-Inch 316SS 1/2\" NPT Hydrotest Gauge (0–1,500 PSI)"),
            ("Winters Instruments", "PFQ Series 4-Inch 316SS 1/2\" NPT High-Pressure Gauge (0–10,000 PSI)"),
            ("Fluke Calibration", "700G08 Precision Digital Reference Test Pressure Gauge (0–1,000 PSI, 0.05% FS)"),
            ("Ralston Instruments", "QTHP-0000 5,000 PSI Quick-test Hydraulic Hand Calibration Pump Kit"),
            ("Ralston Instruments", "Quick-test 6-Ft Zero-Volume 6,900 PSI Brass/SS Microbore Test Hose + NPT Adapters"),
            ("RIDGID", "50072 Model 1450 Manual Hydraulic Hydrostatic Line-Pipe Pressure Test Pump (725 PSI)"),
            ("Rothenberger", "RP50-S 870-PSI Dual-Valve Steel Reservoir Manual Hydrostatic Pipe Test Pump"),
            ("Wheeler-Rex", "36355 Electric 115V Piston Hydrostatic Pipeline Pressure Test Pump (Up to 1,000 PSI)"),
            ("Cherne Industries", "Gripper Mechanical End-of-Pipe Cast-Iron Hydro/Air Test Plugs (2\", 3\", 4\", 6\" Set)"),
            ("Cherne Industries", "I-Series Pneumatic Inflatable Rubber Multi-Size Pipeline Blocking Test Plug (4\"–8\")"),
            ("Palmer / Barton", "8-Inch Circular Paper Mechanical Pressure & Temperature Hydrotest Chart Recorder"),
            ("Winters Instruments", "SSN535 1/2\" NPT 316SS Sintered Porous-Element Pressure-Spike Gauge Snubber"),
            ("Noshok", "302-Series 1/2\" Male-to-Female 316SS 2-Valve Block-and-Bleed Instrument Manifold"),
        ]
    ]

    d["Pipe Calipers, Tally Tapes & Thread Gauges"] = [
        (brand, f"{brand} {item}", "Pipe Tally & QA", f"Precision dimensional {item.lower()} verifying OD, wall schedule, weld fillets, and API threads.", "Laser-etched graduations | Shop oil resistant | Yard & ditch proven")
        for brand, item in [
            ("Mitutoyo", "500-197-30 Absolute Digimatic 0–8\" Hardened Stainless Digital Caliper"),
            ("Mitutoyo", "500-193-30 Absolute Digimatic 0–12\" Heavy-Duty Large-OD Digital Caliper"),
            ("Mitutoyo", "293-340-30 IP65 Coolant-Proof 0–1\" Digital Outside Wall/Plate Micrometer"),
            ("Starrett", "73B-12 12-Inch Yankee Spring-Joint Outside Pipe OD Transfer Caliper"),
            ("Mathey / Pipe Pit", "Direct-Reading Pocket Brass/Steel Pipe Wall & Schedule Caliper (1/2\" to 12\" IPS)"),
            ("Lufkin", "PHV1410CMEN 100-Ft Hi-Vis Orange Fiberglass Decimal-Foot & Inch Pipe Tally Tape"),
            ("Lufkin", "200-Ft Heavy Open-Reel Steel & Nylon-Clad Pipeline Right-of-Way Measuring Tape"),
            ("US Tape", "Spencer Pro-Tape 50-Ft Logger/Pipeliner Auto-Rewind Decimal-Foot Hip Tally Tape"),
            ("Lufkin", "CN1290SF590 33-Ft Crude-Oil Tank Innage/Outage Plumb-Bob Grounding Gauging Tape"),
            ("Milwaukee", "48-22-0325 25-Ft Wide-Blade Magnetic-Hook Heavy-Duty Pipefitter Tape Measure (2-Pack)"),
            ("Starrett", "C33H-12-4R 12-Inch Cast-Iron 4-Piece Combination Square, Protractor & Center-Head Set"),
            ("GAL Gage", "CAT #4 Stainless Bridge-Cam AWS Weld Bevel, Undercut, Throat & Fillet Inspection Gauge"),
            ("GAL Gage", "7-Piece Fillet Weld Set + V-WAC Single-Weld Undercut & Pit Gauge Kit"),
            ("Starrett / Mitutoyo", "51-Blade SAE (4–84 TPI) & NPT 60-Deg Screw/Pipe Thread Pitch Leaf Gauge"),
            ("API / Vermont", "1/2\", 3/4\", 1\", 1-1/2\" & 2\" NPT L1 Tapered Pipe Thread Ring & Plug Inspection Gauge Set"),
            ("Markal", "B Paintstik Solid Real-Paint Weather/UV-Proof Pipe Tally Markers (White/Yellow 12-Box)"),
            ("Markal", "Flat Soapstone Holders + 144-Gross Natural White Welder Cut-Line Soapstone Refills"),
        ]
    ]

    d["Borescopes, Sewer Cameras & Pipe Locators"] = [
        (brand, f"{brand} {item}", "Internal & Buried", f"Internal visual and underground locating {item.lower()} inspecting weld roots and buried iron.", "IP67 waterproof probe | High-lux LED | Jobsite carry case")
        for brand, item in [
            ("RIDGID", "55898 micro CA-350 12V Digital Handheld Inspection Borescope Camera w/ 17mm Head"),
            ("Teslong", "TD500 Dual-Lens Articulating 210-Deg Tip 5-Inch IPS HD Industrial Weld-Root Endoscope"),
            ("DEPSTECH", "DS520 5-Inch IPS Triple-Lens Split-Screen 16.5-Ft Semi-Rigid Pipe Inspection Borescope"),
            ("RIDGID", "SeeSnake Compact2 / M40 100-Ft Self-Leveling Color Pipeline Push Camera Reel + Monitor"),
            ("Vevor / Sanyipace", "165-Ft 9-Inch DVR Self-Leveling Sewer & Casing Pipe Camera w/ 512Hz Sonde Transmitter"),
            ("RIDGID", "21893 SeekTech SR-20 Underground Utility, Buried Steel Line-Pipe & Sonde Locator"),
            ("RIDGID", "21898 SeekTech ST-305 5-Watt Multi-Frequency Line Transmitter w/ Inductive Clamp"),
            ("Schonstedt", "GA-52Cx HeliFlux Magnetic Ferromagnetic Valve-Box, Casing & Marker Locator"),
            ("Schonstedt", "SPOT One-Hand Ultralight Magnetic Buried-Iron & Survey-Pin Locator Stick"),
            ("Klein Tools", "ET450 Advanced Circuit Breaker, Conduit & Energized/Non-Energized Wire Tracer Kit"),
            ("Jameson", "Good Buddy II 3/8-Inch x 300-Ft Fiberglass Conduit & Pipe-Sleeve Duct Rodder on Stand"),
            ("Klein Tools", "56334 240-Ft Heavy-Duty 1/4-Inch Wide Steel Conduit Pulling Fish Tape"),
            ("Greenlee", "392-ft / 6,500-Lb Tensile Polyester Conduit & Casing Measuring Pull Tape (3,000-Ft Reel)"),
            ("Bosch", "GLM165-40 Blaze Pro 165-Ft Outdoor Backlit Laser Distance & Tally Measurer"),
            ("Leica Geosystems", "DISTO X4 IP65 Outdoor Pointfinder Camera 500-Ft Laser Pipe-Yard Distance Meter"),
            ("Keson", "RR318N 4-Ft Heavy-Duty Dual-Wheel Decimal-Foot Right-of-Way Measuring Wheel"),
            ("General Tools", "Telescoping Lighted LED Stainless Inspection Mirror Set for Backside Pipe Roots"),
            ("Presco", "1,000-Pack 21-Inch Wire-Staff Glo-Orange/Red/Yellow Underground Utility Marking Flags"),
        ]
    ]

    d["Thermal Imagers, Pyrometers & Leak Detectors"] = [
        (brand, f"{brand} {item}", "Preheat & Leak QA", f"Non-contact thermal and acoustic {item.lower()} checking weld preheat, bearings, and gas leaks.", "NIST-grade sensor | Rugged drop-tested | Instant digital readout")
        for brand, item in [
            ("FLIR", "E6 Pro / E5-XT Wi-Fi Handheld Infrared Thermal Imaging Camera (-4F to 1022F)"),
            ("FLIR", "C5 Compact Pocket Wi-Fi Thermal Camera + MSX Visual Inspection Imager"),
            ("Fluke", "TiS20+ MAX 9Hz Industrial Handheld Thermal Imager for Bearings, Panels & Steam Traps"),
            ("Fluke", "62 MAX+ Dual-Laser IP54 Dust/Waterproof Infrared Thermometer (-22F to 1202F)"),
            ("Fluke", "568 Contact K-Type + Non-Contact High-Temp Laser Pyrometer (Up to 1472F Weld Preheat)"),
            ("Fluke", "52 II Dual-Input Digital K-Type Thermocouple Thermometer + Surface Pipe Probe"),
            ("Tempil", "Tempilstik Weld Preheat & Interpass Temperature Indicator Kit (150F, 200F, 250F, 300F, 350F, 400F, 500F)"),
            ("Tempil", "Tempilstik Stainless & Chrome-Moly High-Heat Stick Set (450F, 550F, 650F, 750F)"),
            ("INFICON", "Whisper Ultrasonic Compressed-Air, Vacuum & Pressure-Piping Gas Leak Detector"),
            ("UE Systems / Reed", "R9100 Ultrasonic Transmitter & Receiver Acoustic Flange/Valve Leak Kit"),
            ("SENSIT / UEi", "CD100A Combustible Natural Gas, Methane & Propane Gooseneck Sniffer Leak Detector"),
            ("RIDGID", "36163 Model micro CD-100 Combustible Hydrocarbon Gas Leak Detector"),
            ("Nu-Calgon", "Big Blu Micro-Bubble Sub-Zero High-Viscosity Flange & Thread Gas Leak Solution (1-Gal)"),
            ("Fluke", "971 Temperature & Relative Dew-Point Humidity Meter (Before Pipe Epoxy Coating)"),
            ("REED Instruments", "LM-8000 / R4500 Vane Anemometer for Confined-Space Ventilation Airflow Checks"),
            ("Extech", "407730 Digital 40–130 dB OSHA Compressor & Jobsite Sound-Level Decibel Meter"),
            ("Fluke", "805 FC Vibration Meter for Checking Pump, Motor & Compressor Bearing Health"),
            ("Cooper-Atkins", "Bi-Metal Stainless 1/2\" NPT Back-Connect Industrial Pipe Thermowell Thermometer (50–500F)"),
        ]
    ]

    d["Rotary Lasers, Digital Levels & Multimeters"] = [
        (brand, f"{brand} {item}", "CAT IV / Grade Spec", f"Precision alignment and CAT IV electrical {item.lower()} for pipe grade, flanges, and skids.", "IP54+ jobsite sealed | Magnetic/tripod ready | True-RMS / Self-leveling")
        for brand, item in [
            ("Topcon", "RL-H5A Horizontal Self-Leveling 2,600-Ft Range Rotary Grade Laser + Receiver, Tripod & Rod"),
            ("Bosch", "GRL2000-40HK Exterior 2,000-Ft Self-Leveling Rotary Laser Complete Trenching Kit"),
            ("DEWALT", "DW089LG 12V MAX 3 x 360-Deg Green-Beam Cross-Line Pipe-Rack Plumb & Layout Laser"),
            ("Bosch", "GPL100-50G 5-Point Green-Beam Self-Leveling Pipe Plumb-Up/Down Dot Laser"),
            ("Stabila", "25100 Type 80M / 96M 10-Inch Heavy Die-Cast Rare-Earth Magnetic Torpedo Level"),
            ("Stabila", "37424 & 37448 Type 196-2 24-Inch & 48-Inch Heavy-Duty Ribbed Box-Beam Level Pair"),
            ("Empire Level", "em95.10 True Blue 10-Inch Billet-Aluminum Rare-Earth Pipefitter V-Groove Torpedo Level"),
            ("Klein Tools", "935DAG Digital Electronic Angle Gauge & Magnetic V-Groove Miter Protractor Cube"),
            ("Mitutoyo", "950-317 Pro 360 Digital Machined-Aluminum 360-Deg Bevel & Slope Level"),
            ("Starrett", "98-12 12-Inch Precision Machinists Ground Cast-Iron Base Cross-Test Skid Level"),
            ("Fluke", "87V Industrial True-RMS Digital Multimeter w/ Temp Probe (CAT III 1000V / CAT IV 600V)"),
            ("Fluke", "117 Electricians True-RMS Multimeter w/ LoZ Ghost-Voltage Elimination"),
            ("Fluke", "376 FC 1000A True-RMS AC/DC Wireless Clamp Meter w/ iFlex Flexible 2500A Pipe/Bus Coil"),
            ("Fluke", "1507 1000V Digital Insulation Resistance Megohmmeter for Submersible Pumps & Motors"),
            ("Fluke", "T6-1000 Open-Jaw FieldSense Voltage & Continuity Electrical Tester"),
            ("Fluke", "9040 3-Phase Motor & Pump Rotation Direction Indicator"),
            ("Fluke", "1AC-A1-II VoltAlert Non-Contact 90–1000V AC Pocket Voltage Detector (2-Pack)"),
            ("Klein Tools", "RT250 GFCI Spider-Box & Outlet Wiring LCD Fault Receptacle Tester"),
        ]
    ]

    # 8. FARM, RANCH & PIPE FENCING GEAR (110: 19,19,18,18,18,18)
    d["Pipe Fence Coping, Saddles & Notchers"] = [
        (brand, f"{brand} {item}", "Drill-Stem Pipe Fab", f"Oilfield tubing and drill-stem fence {item.lower()} speeding up corral and H-brace coping.", "Fits 2-3/8\", 2-7/8\" & 4-1/2\" | Clean weld-ready saddles | Heavy ranch steel")
        for brand, item in [
            ("Woodward Fab / JD2", "Heavy-Duty Hole-Saw Tubing & Drill-Stem Pipe Saddle Notcher Jig (3/4\" to 3\" OD)"),
            ("Baileigh / Rogue", "0-to-60 Degree Angle-Adjusting Heavy Pipe & Corral-Rail Coping Notcher"),
            ("PipeMaster", "P-T238 & P-T278 Contour-Pin Transfer Template Pair for 2-3/8\" & 2-7/8\" Oilfield Tubing"),
            ("EZ-Cope / SaddleGuide", "3-Piece Steel Slip-Over Torch/Plasma Saddle Cutting Guides (2-3/8\", 2-7/8\" & 4-1/2\" OD)"),
            ("EZ-Cope / SaddleGuide", "30-Deg & 45-Deg Corner H-Brace Angled Pipe Coping Saddle Guide Set (2-3/8\" & 2-7/8\")"),
            ("LENOX", "2-3/8\" & 2-7/8\" T3 Speed-Slot Bi-Metal Pipe Coping Hole Saw + Heavy Hex Arbor Kit"),
            ("Milwaukee", "Hole Dozer w/ Carbide Teeth 2-3/8\" & 2-7/8\" Drill-Stem Pipe Coping Hole Saw Pair"),
            ("Ranch Fab Select", "2-3/8\" OD Domed Weld-On Steel Oilfield Pipe Fence Post Caps (50-Pack)"),
            ("Ranch Fab Select", "2-7/8\" OD Domed Weld-On Steel Oilfield Tubing Post Caps (50-Pack)"),
            ("Ranch Fab Select", "3-1/2\" OD Domed Weld-On Steel Drill-Pipe Corner Post Caps (25-Pack)"),
            ("Ranch Fab Select", "4-1/2\" OD Heavy Domed Weld-On Casing Gate-Post Caps (20-Pack)"),
            ("Ranch Fab Select", "Pre-Cut Weld-On 2-3/8\"-to-2-7/8\" Stamped Steel Fence Rail Clips / Saddles (100-Pack)"),
            ("Ranch Fab Select", "Weld-On Continuous Top-Rail Expansion Sleeve Couplers for 2-3/8\" Pipe (20-Pack)"),
            ("Ranch Fab Select", "Magnetic Corral Rail Equal-Spacing Layout Jig Set (5-Rail & 6-Rail Working Pens)"),
            ("Ranch Fab Select", "Self-Centering V-Block Drill Guide for Boring Sucker-Rod & Cable Holes Through Pipe Posts"),
            ("Ranch Fab Select", "Weld-On 3/8\" Eyelets & Cable-Pass-Thru Ferrules for 5-Strand Oilfield Cable Corrals (50-Pack)"),
            ("Hougen / Evolution", "9/16\" & 11/16\" Carbide-Tipped Cutter Set for Drilling Hardened Work-Hardened Drill Stem"),
            ("Rust-Oleum Professional", " Rusty-Metal Primer & Gloss Black/Safety-Yellow Oil-Based Pipe Fence Enamel (2-Gal Pack)"),
            ("Lenco / Strong Hand", "Magnetic V-Pad Ground Clamp & 90-Deg Corner Tacking Clamp for Round Pipe Rails"),
        ]
    ]

    d["Weld-On Hinges, Latches & Gate Hardware"] = [
        (brand, f"{brand} {item}", "Heavy Corral Gate", f"Ranch-grade steel {item.lower()} built to hang 16-ft drill-stem pipe gates without sagging.", "Uncoated weldable steel | Grease-zerk pivot | Cattle-proof latch")
        for brand, item in [
            ("Ranch Fab Select", "5-Inch Heavy Weld-On Steel Barrel Gate Hinges w/ Ball Bearing & Grease Zerk (4-Pairs)"),
            ("Ranch Fab Select", "8-Inch Extra-Heavy 2,000-Lb Weld-On Barrel Hinges for 20-Ft Double Entrance Pipe Gates"),
            ("Ranch Fab Select", "3/4\" x 8\" Adjustable Threaded J-Bolt Weld-On Pipe Gate Hinge Set (4-Pack)"),
            ("Ranch Fab Select", "1\" x 10\" Heavy Bull-Pen Threaded J-Bolt & Weld-Tab Gate Hinges (2-Pair)"),
            ("Wrap-Around Hinge", "Clamp-On / Weld-On 2-7/8\" & 4-1/2\" Round Pipe Post Female/Male Pintle Gate Hinges"),
            ("Kiwi / Wedge-Loc", "Heavy-Duty Two-Way Horseback-Friendly Slam-Shut Livestock Pipe Gate Latch"),
            ("Ranch Fab Select", "Weld-On Spring-Loaded Plunger Pin Corral & Crowding-Tub Gate Latch (2-Pack)"),
            ("Ranch Fab Select", "Weld-On Slotted Flat-Bar Safety Chain Gate Latch w/ Proof-Coil Chain (4-Pack)"),
            ("SpeeCo", "One-Handed Two-Way Lockable Galvanized/Steel Pasture Tube Gate Latch (2-Pack)"),
            ("Ranch Fab Select", "36-Inch Heavy 5/8\" Solid-Steel Weld-On Double-Gate Cane Drop Rod Bolt"),
            ("SpeeCo", "Spring-Loaded Flat-Free 8-Inch Tire Gate Support Wheel for Heavy Sagging Gates"),
            ("Buyers Products", "Spring-Loaded Heavy Swivel Caster Gate Wheel (600-Lb Cap. for Gravel Entrances)"),
            ("Behlen Country", "12-Ft Heavy-Duty 6-Rail 16-Gauge Powder-Coated Steel Pasture & Corral Tube Gate"),
            ("Behlen Country", "16-Ft Heavy Bull-Rated 6-Bar Galvanized Ranch Entrance Gate"),
            ("Ranch Fab Select", "Weld-On Cattle-Guard Pipe Saddle Cleats & Cleanout Wing Brackets Kit"),
            ("Ranch Fab Select", "Weld-On Overhead Arch Ranch-Entrance Sign Hanger Brackets & Turnbuckles"),
            ("Ghost / Mighty Mule", "Heavy Padlockable Steel Pin-Box Security Shroud for Remote Lease & Ranch Gates"),
            ("Master Lock", "Weather-Tough Shrouded Laminated Daisy-Chain Lease-Road Multi-Lock Gate Bar"),
        ]
    ]

    d["Gas Post Drivers, Augers & T-Post Tools"] = [
        (brand, f"{brand} {item}", "Fence Line Speed", f"Time-saving post installation {item.lower()} conquering caliche, clay, and rocky pasture lines.", "Saves crew backs | Heavy forged/4-stroke build | Field serviceable")
        for brand, item in [
            ("Redi-Driver", "Boss Classic Honda GX35 4-Stroke Gas T-Post & 2-7/8\" Pipe Post Driver"),
            ("Titan Post Drivers", "PGD3200X Commercial 3-1/4\" Large-Barrel Honda GX35 Pipe & Wood Post Driver"),
            ("Echo / Earthquake", "2-Man 52cc/63cc Heavy-Duty Gas Earth Auger Powerhead w/ 8\" & 12\" Fishtail Bits"),
            ("Premier / Lowe", "9-Inch Heavy-Duty Carbide-Tooth Rock & Caliche Skid-Steer Hex Post-Hole Auger Bit"),
            ("Premier / Lowe", "12-Inch Heavy-Duty Skid-Steer / 3-Point Tractor Corner-Post Earth Auger Bit"),
            ("SpeeCo", "Heavy-Duty 22-Lb Weighted Closed-Tube Steel Manual T-Post Driver w/ Wide Handles"),
            ("T-Post Puller Pro", "36-Inch Heavy Lever-Action Steel T-Post & Ground-Rod Jack Puller"),
            ("Brush Grubber", "Chain-Jaw Tractor/Skid-Steer Bucket Pull-Out T-Post & Pipe Stub Extractor"),
            ("Seymour Midwest", "69-Inch 17-Lb Solid Hex-Steel San Angelo Chisel & Point Caliche Digging Rock Bar"),
            ("Seymour Midwest", "72-Inch Forged-Head Post-Hole Tamper & Pencil Digging Bar"),
            ("Seymour Structron", "Hercules Fiberglass-Handle Heavy Steel-Blade Clamshell Post-Hole Digger"),
            ("Fiskars / Corona", "All-Steel Welded-Shaft Offset-Handle Heavy Clay Clamshell Post-Hole Digger"),
            ("Johnson / Kapro", "Magnetic & Strap-On 2-Sided Corner Plumb Pipe-Post & T-Post Level (4-Pack)"),
            ("Keson / Marshalltown", "500-Ft Braided Fluorescent-Orange Nylon Mason & Fence-Line String Reels (4-Pack)"),
            ("Quikrete / Sika", "Sika Post Fix Two-Part Expanding Structural Polyurethane Fence-Post Foam (6-Pack)"),
            ("Dutton-Lainson", "Heavy-Duty Forged Fence Pliers (Hammer, Staple Puller, Wire Splicer & Double Cutter)"),
            ("KNIPEX / Channellock", "Channellock 85 10-1/2\" USA High-Carbon Fence Tool Pliers"),
        ]
    ]

    d["Solar Fence Chargers, Wire & Strainers"] = [
        (brand, f"{brand} {item}", "High-Tensile & Solar", f"Low-impedance electric and high-tensile wire {item.lower()} keeping cattle and predators contained.", "UV & rust protected | Low-impedance pulse | Multi-mile pasture spec")
        for brand, item in [
            ("Gallagher", "S40 / S100 Portable Lithium Solar Livestock Electric Fence Charger (Up to 30–60 Miles)"),
            ("Gallagher", "MBS400 Multi-Power (110V AC / 12V Battery / Solar) 80-Mile Ranch Fence Energizer"),
            ("Speedrite", "3000 / 6000i Unigizer 6-Joule Low-Impedance Ranch Mains/Battery Energizer"),
            ("Parmak", "Magnum 12 Solar-Pak 12-Volt American-Made 30-Mile Pasture Fence Charger"),
            ("Gallagher", "SmartFix Digital Electric-Fence Fault-Finder & Directional Current Voltmeter"),
            ("Bekaert / OK Brand", "12.5-Gauge Class 3 Galvanized High-Tensile Smooth Pasture Wire (4,000-Ft Coil)"),
            ("Gaucho / Bekaert", "15.5-Gauge High-Tensile Class 3 4-Point Barbed Wire (1,320-Ft 1/4-Mile Spool)"),
            ("Gallagher", "Turbo Wire 9-Strand Mixed-Metal Ultra-Conductive Portable Cross-Fencing Spool (1,312-Ft)"),
            ("Gallagher", "Geared 3:1 Heavy Galvanized Reel w/ Insulated Carry Hook for Portable Grazing"),
            ("Dare / Gallagher", "Cast-Aluminum Heavy-Duty Inline Ratchet High-Tensile Wire Strainers (25-Pack) + Handle"),
            ("Dutton-Lainson", "Goldenrod 400 / 415 Original Lever-Action Barbed & Smooth Wire Fence Stretcher-Splicer"),
            ("Texas Fence Fixer", "Original Chain-Grab Single-Person Barbed-Wire Repair & Tightening Tool"),
            ("Gripple", "Plus Medium/Large Push-Fit High-Tensile & Barbed-Wire Splice Joiners (40-Pack) + Torq Tool"),
            ("Zareba / Dare", "Wrap-Around Clamp-On Porcelain/HDPE Electric Insulators for 2-3/8\" & 2-7/8\" Pipe Posts (50-Pack)"),
            ("Zareba", "Snug-Fitting Yellow High-Density Polyethylene T-Post Pin-Lock Insulators (100-Bag)"),
            ("Bekaert", "1-3/4\" Class 3 Hot-Dip Galvanized Double-Barb Wood-Post Fence Staples (8-Lb Bucket)"),
            ("Preformed Line", "Dead-End Guy-Wire Grip & 3/8\" 7-Strand Galvanized Oilfield Corral Cable Clamps"),
            ("Gallagher", "3-Rod 6-Ft Galvanized Ground-Rod, Clamp & Lightning-Diverter Earthing Kit"),
        ]
    ]

    d["Stock Tank Valves, Waterers & Ag Pumps"] = [
        (brand, f"{brand} {item}", "Stock Water & Ag", f"Freeze-resistant and high-flow {item.lower()} keeping livestock troughs and water trailers full.", "Livestock-proof housing | High-GPM fill | Corrosion proof")
        for brand, item in [
            ("Jobe Valves", "Rojo / Topaz 3/4\" & 1\" Differential High-Flow Submersible Stock-Tank Float Valve"),
            ("Hudson Valve", "1-Inch Compact Unbreakable No-Float-Arm Anti-Siphon Cattle Tank Valve (2-Pack)"),
            ("Dare / Little Giant", "Heavy-Duty Cast-Aluminum Clamp-On Stock-Tank Float Valve (300 GPH)"),
            ("Behlen / Rubbermaid", "1-1/2\" & 1-1/4\" Universal Poly & Galvanized Stock-Tank Bulkhead Drain Plug Kit (4-Pack)"),
            ("Farm Innovators", "C-250 1,500-Watt Cast-Aluminum Submersible Thermostatic Sinking Tank De-Icer"),
            ("API / Allied Precision", "1,500-Watt Floating/Sinking Drain-Plug Mount Cord-Protected Stock-Tank Heater"),
            ("Ritchie / Miraco", "OmniFount 200 Insulated Automatic Freeze-Resistant Stainless/Poly Cattle Waterer"),
            ("Nelson / Little Giant", "Automatic Cast-Iron / Stainless Push-Paddle Pasture Horse & Cattle Bowl"),
            ("Honda Power", "WB20XT4 2-Inch 164-GPM GX120 Commercial Gas Water Transfer Pump"),
            ("Pacer Pumps", "S-Series 2-Inch Lightweight Glass-Polyester Chemical, Saltwater & Ag Transfer Pump (GX160)"),
            ("Champion / Predator", "3-Inch 260-GPM Semi-Trash Gas Engine Pond & Frac-Pit Water Transfer Pump"),
            ("Wayne / Zoeller", "1/2-HP Cast-Iron Submersible Utility & Cellar Sump Dewatering Pump"),
            ("Apache Hose", "2-Inch x 20-Ft Green PVC Helix Suction Hose + 2\" x 50-Ft Blue Lay-Flat Discharge Kit w/ Camlocks"),
            ("Dixon Valve", "2-Inch Plated-Steel Round-Hole Suction Hose Strainer Basket + Brass Foot Check Valve"),
            ("DELAVAN / Remco", "PowerFLO 12V DC 5.3-GPM 60-PSI Demand Diaphragm Ag Sprayer & Water Pump"),
            ("TeeJet", "Boomless Brass Broadcast Pasture Fence-Row Spray Nozzle + Inline Strainer"),
            ("Simmons", "800SB 3/4\" Lead-Free Frost-Proof Yard Hydrant Head & Plunger Repair Assembly"),
            ("Banjo", "2-Inch Polypropylene Male/Female Camlock Couplers for Nurse & Fertilizer Tanks (4-Set)"),
        ]
    ]

    d["Livestock Chute, Trailer & Ranch Hardware"] = [
        (brand, f"{brand} {item}", "Ranch & Stock Trailer", f"Heavy gooseneck, tractor, and working-pen {item.lower()} built for daily ranch operations.", "Heavy forged steel | Weatherproof powder coat | Ranch tested")
        for brand, item in [
            ("Bulldog", "BX1 2-5/16\" 30,000-Lb Round Adjustable Gooseneck Stock & Flatbed Trailer Coupler"),
            ("Bulldog", "12,000-Lb Heavy-Duty Square Side-Wind Spring-Return Drop-Leg Trailer Jack"),
            ("B&W Trailer Hitches", "Tow & Stow 2.5-Inch Shank Tri-Ball Adjustable Drop Receiver Hitch (18,000-Lb)"),
            ("Curt Manufacturing", "Forged Pintle Hook & 2-5/16\" Ball Combination Hitch (16,000-Lb Equipment Trailer)"),
            ("Tekonsha", "Prodigy P3 Proportional Electric 1-to-4 Axle Stock & Flatbed Trailer Brake Controller"),
            ("Hopkins", "Engager Breakaway Switch & Rechargeable 12V Trailer Emergency Brake Battery Box Kit"),
            ("Buyers Products", "Weld-On Heavy 3/8\" Steel Rub-Rail Stake Pockets for Flatbed & Hay Trailers (8-Pack)"),
            ("SpeeCo", "Category 1 Heavy-Duty 3-Point Tractor Quick Hitch w/ Adapter Bushings"),
            ("SpeeCo", "310-Piece Tractor Lynch-Pin, Hitch-Pin, PTO-Lock & Hairpin Cotter Master Shop Assortment"),
            ("Weasler / Eurocardan", "Series 4 1-3/8\" 6-Spline Tractor PTO Driveline Shaft w/ Friction Slip Clutch"),
            ("Priefert / Arrowquip", "Heavy Rubber Squeeze-Chute Floor Cleat Mat & Ratchet Crowding-Alley Backup Latch"),
            ("Hot-Shot", "The Green One 36-Inch Sealed-Motor Rechargeable Waterproof Livestock Prod"),
            ("Tru-Test / Gallagher", "2,000-kg Waterproof Squeeze-Chute & Alley Platform Livestock Load-Bar Scale Kit"),
            ("FIMCO Industries", "60-Gallon 12V High-Flo UTV/Pickup-Bed Boomless Pasture & Fence-Line Sprayer"),
            ("Chapin", "4-Gallon Viton-Seal Backpack Diesel/Herbicide Brush & Mesquite Fence-Line Sprayer"),
            ("Mighty Mule", "MM371W Heavy-Duty 16-Ft Single-Swing Automatic Ranch Gate Opener + 10W Solar Panel"),
            ("Ghost Controls", "TDS2XP Heavy-Duty Dual-Gate Solar Automatic Ranch Pipe-Gate Opener Bundle"),
            ("rotopaX / Kolpin", "UTV/Ranch-Truck Lockable Chainsaw Scabbard & Long-Tool Bed Rack Mount"),
        ]
    ]
    return d

SUBCATEGORY_CATALOG_PART5 = _build_part5()
