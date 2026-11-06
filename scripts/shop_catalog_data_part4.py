"""Compact industrial product matrices for Categories 4-5 (FR/PPE & Fleet/Hydraulics)."""

def _build_part4():
    d = {}
    # 4. FR WORKWEAR, PPE & GAS DETECTION (125: 21,21,21,21,21,20)
    d["FR Shirts, Coveralls & Winter Outerwear"] = [
        (brand, f"{brand} {item}", "NFPA 2112 CAT 2", f"UL-classified NFPA 2112 / 70E {item.lower()} for oilfield, refinery, and welding crews.", "NFPA 2112 & 70E CAT 2 | Exterior FR patches | Arc & flash-fire rated")
        for brand, item in [
            ("Ariat FR", "Solid Twill Button-Down Long-Sleeve Flame-Resistant Work Shirt"),
            ("Ariat FR", "Air Crew Lightweight Moisture-Wicking CAT 2 Long-Sleeve Henley"),
            ("Ariat FR", "DuraLight Stretch Canvas Flame-Resistant Stackable Straight Work Pants"),
            ("Ariat FR", "M4 Low-Rise Relaxed-Fit Boot-Cut Flame-Resistant Denim Jeans"),
            ("Carhartt FR", "Force Cotton Long-Sleeve Pocket Henley Shirt (CAT 2)"),
            ("Carhartt FR", "Full-Swing Quick-Duck Insulated Flame-Resistant Jacket (CAT 3)"),
            ("Carhartt FR", "Duck Unlined & Quilted Flame-Resistant Bib Overalls"),
            ("Carhartt FR", "Midweight Signature Graphic Pullover FR Hoodie Sweatshirt"),
            ("Bulwark FR", "Deluxe 7-Oz Excel-FR ComforTouch Deluxe Coveralls w/ Reflective Striping"),
            ("Bulwark FR", "9-Oz Insulated Excel-FR Arctic Lease Coveralls (CAT 4)"),
            ("Bulwark FR", "Hi-Vis ANSI Class 3 Type R Flame-Resistant Long-Sleeve Shirt"),
            ("Wrangler Riggs FR", "Flame-Resistant Western Pearl-Snap Twill Work Shirt"),
            ("Wrangler Riggs FR", "Relaxed-Fit Carpenter Flame-Resistant Jeans"),
            ("Black Stallion", "TruGuard 200 9-Oz FR Treated Cotton Pipeline Welding Jacket (30-Inch)"),
            ("Black Stallion", "FN9-30C Split Cowhide Leather Sleeves w/ FR Cotton Body Cape/Jacket"),
            ("Tillman", "Tillman 6230 9-Oz Green FR Cotton Welding Sleeves w/ Elastic Cuffs"),
            ("Ergodyne", "N-Ferno 6882 Dual-Compliant NFPA 70E FR Modacrylic Winter Balaclava"),
            ("Benchmark FR", "Flame-Resistant Multi-Wear Sun & Wind Neck Gaiter (CAT 2)"),
            ("NASCO", "ArcLite Hi-Vis Waterproof Flame-Resistant Arc-Rated Rain Jacket & Bibs"),
            ("Portwest", "Bizflame Hi-Vis Anti-Static FR Insulated Winter Bomber Parka"),
        ]
    ]

    d["Pipeline & Oilfield Safety Work Boots"] = [
        (brand, f"{brand} {item}", "ASTM F2413 Safety", f"Oil- and slip-resistant {item.lower()} built for muddy rig pads, pipe yards, and steel decks.", "ASTM F2413 EH rated | Oil/slip-resistant sole | All-day shank support")
        for brand, item in [
            ("Ariat Work", "WorkHog XT Waterproof Carbon-Toe Pull-On Western Rig Boot"),
            ("Ariat Work", "WorkHog Wide-Square Steel-Toe CSA/ASTM Puncture-Resistant Boot"),
            ("Ariat Work", "Groundbreaker Waterproof Steel-Toe Pull-On Oilfield Boot"),
            ("Ariat Work", "RigTek 8-Inch Waterproof Composite-Toe Lace-Up Oilfield Boot"),
            ("Thorogood", "American Heritage 8-Inch MAXWear Wedge Steel-Toe Moc-Toe Boot (USA)"),
            ("Thorogood", "11-Inch Wellington Waterproof Steel-Toe Pull-On Work Boot"),
            ("Thorogood", "Emperor Toe 8-Inch Composite-Toe Extra-Wide Briar Pitstop Boot"),
            ("Timberland PRO", "Boondock 8-Inch Composite-Toe Waterproof Insulated Rig Boot"),
            ("Timberland PRO", "Pit Boss 6-Inch Steel-Toe Slip-Resistant Shop Work Boot"),
            ("Timberland PRO", "Excavator Super- Boot External Metatarsal Guard Steel-Toe Boot"),
            ("KEEN Utility", "Cincinnati 8-Inch Carbon-Fiber Toe Waterproof Wedge Welder Boot"),
            ("KEEN Utility", "Mt. Vernon 6-Inch Internal Metatarsal Steel-Toe Foundry/Pipe Boot"),
            ("Wolverine", "Floorhand Waterproof 10-Inch Steel-Toe Wellington Pull-On Boot"),
            ("Justin Original Workboots", "Pulley 11-Inch Waterproof Comp-Toe Oilfield Western Boot"),
            ("Dunlop Protective", "Purofort+ Full-Safety Steel-Toe/Midsole Chemical & Mud Rig Knee Boot"),
            ("Muck Boot", "Chore Steel-Toe Waterproof Neoprene Mud & Lease-Pad Tall Work Boot"),
            ("Baffin", "Icebear -50C Cold-Weather Composite-Toe Insulated Arctic Oilfield Boot"),
            ("PEET Dryer", "Original Dual-Boot Overnight Convection Electric Wet-Boot Dryer"),
            ("Darn Tough Vermont", "Steely Boot Full-Cushion Heavy Merino Wool Steel-Toe Socks (3-Pack)"),
            ("KG's Boot Guard", " Brush-On Heavy Urethane Toe-Cap Protector & Kevlar Welding Boot Laces"),
            ("Yaktrax / Ergodyne", "TREX 6300 One-Piece Ice & Packed-Snow Traction Cleats for Work Boots"),
        ]
    ]

    d["Hard Hats, Welding Shields & Safety Glasses"] = [
        (brand, f"{brand} {item}", "ANSI Z89.1 / Z87.1+", f"Jobsite-compliant {item.lower()} protecting eyes, face, and head on industrial sites.", "ANSI Z89.1 / Z87.1+ rated | Ratchet comfort suspension | Field replaceable")
        for brand, item in [
            ("MSA Safety", "V-Gard White Full-Brim Hard Hat w/ Fas-Trac III 4-Point Ratchet"),
            ("MSA Safety", "Skullgard High-Heat Phenolic Full-Brim Welding & Steel-Mill Hard Hat"),
            ("MSA Safety", "Skullgard Slotted Cap-Style Phenolic Hard Hat for Pipeliner Hoods"),
            ("Lift Safety", "DAX 50/50 Carbon-Fiber Reinforced Full-Brim Hard Hat"),
            ("Lift Safety", "DAX Natural Fiber Resin Cap-Style Hard Hat"),
            ("Klein Tools", "60407 Full-Brim Vented Hard Hat w/ Clip-On Rechargeable LED Headlamp"),
            ("3M", "SecureFit H-800 Series Climbing-Style 4-Point Chin-Strap Safety Helmet"),
            ("Fibre-Metal", "Speedy Loop 5000 Hard-Hat Mounting Adapter for Pipeliner Welding Hoods"),
            ("Jackson Safety", "MAXVIEW Premium Ratchet Grinding & Cutting Clear Face Shield (Z87.1+)"),
            ("Uvex by Honeywell", "Bionic Full-Shell Polycarbonate Anti-Fog Grinding Face Shield + Shade 5 Visor"),
            ("Sellstrom", "DP4 Flip-Front Shade 5 Oxy-Fuel Cutting & Brazing Face Shield"),
            ("Kleenguard", "Nemesis ANSI Z87.1+ Anti-Fog Clear Wrap-Around Safety Glasses (12-Pack)"),
            ("Kleenguard", "Nemesis Polarized Smoke Outdoor Glare-Cutting Safety Glasses (3-Pack)"),
            ("Uvex", "Stealth OTG Anti-Fog Chemical Splash & Grinding Dust Safety Goggles"),
            ("3M", "Virtua CCS Foam-Gasket Anti-Fog Dust-Sealing Corded Safety Eyewear (6-Pack)"),
            ("Wiley X", "Saint ANSI Z87.1+ Ballistic Polarized Interchangeable-Lens Safety Glasses"),
            ("DeWalt", "DPG82 Concealer Clear Anti-Fog Dual-Mold Grinding Goggle"),
            ("NoCry / Kleenguard", "Over-The-Glasses (OTG) Anti-Fog & Anti-Scratch Prescription Safety Glasses"),
            ("Ergodyne", "Chill-Its 6660 High-Vis Full-Brim Hard Hat Sun Shade w/ Neck Flap"),
            ("Ergodyne", "N-Ferno 6852 2-Layer Quilted FR Cotton Hard-Hat Winter Liner"),
            ("Chums / Squids", "Breakaway Safety Eyewear Retainer Lanyards & Hard-Hat Chin Straps (6-Pack)"),
        ]
    ]

    d["ANSI Impact, Rigging & Cut Gloves"] = [
        (brand, f"{brand} {item}", "ANSI Cut & Impact", f"Heavy dorsal-armored or heat-insulated {item.lower()} for pipe, chain, and welding crews.", "ANSI/ISEA 138 TPR armor | Cut-resistant palm | Oil-channel grip")
        for brand, item in [
            ("HexArmor", "Rig Lizard 2021X Hi-Vis TPR Impact & SuperFabric Cut-Resistant Rig Gloves"),
            ("HexArmor", "Chrome Series 4026 ANSI Cut A8 Mud-Grip Oilfield Impact Gloves"),
            ("HexArmor", "Rig Lizard Arctic Waterproof Thinsulate Cold-Weather TPR Impact Gloves"),
            ("Ringers Gloves", "R-267 Roughneck Heavy-Duty Breathable Oilfield TPR Impact Rigger Gloves"),
            ("Ringers Gloves", "R-279 Waterproof Insulated Sub-Zero Oilfield Impact Gloves"),
            ("Superior Glove", "Endura 378GOBKL Goatskin Driver Gloves w/ Kevlar Cut Liner & TPR Back"),
            ("Superior Glove", "Clutch Gear Mechanics Waterproof Oil-Bloc TPR Impact Gloves"),
            ("Cestus", "Pro Series HandMax Cut A6 Skid-X Grip Heavy Pipe-Handling Impact Gloves"),
            ("Youngstown Glove", "FR Waterproof Leather Utility & Oilfield Lined Work Gloves (NFPA 70E)"),
            ("Tillman", "Tillman 1414 Pearl/Bourbon Top-Grain Cowhide Drivers Work Gloves (6-Pair Pack)"),
            ("Tillman", "Tillman 750 Premium Top-Grain Elkskin Kevlar-Sewn Pipeline Stick Welding Gloves"),
            ("Tillman", "Tillman 850 Heavy-Duty Lined Elkskin High-Heat Stick & Gouging Gloves"),
            ("Tillman", "Tillman 1338 Top-Grain Goatskin Precision Walk-the-Cup TIG Welding Gloves"),
            ("Black Stallion", "T50 Premium Grain Elkskin CushionCore Pipeline Welding Gloves"),
            ("Black Stallion", "Tigster 25K Kevlar-Stitched Ultra-Supple Goatskin TIG Gloves"),
            ("Black Stallion", "BM88 Pigskin Reinforce-Palm TPR Back-of-Hand Rigging Gloves"),
            ("Ansell", "AlphaTec Sol-Vex 37-185 18-Inch 22-Mil Heavy Chemical & Solvent Nitrile Gauntlets"),
            ("SHOWA", "ATLAS 772 26-Inch Shoulder-Length Chemical, Brine & Oil-Resistant PVC Gloves"),
            ("Mechanix Wear", "M-Pact Hi-Vis Yellow ANSI-138 D3O Palm-Padded Service Mechanic Gloves"),
            ("PIP / MaxiFlex", "MaxiFlex Cut 34-8743 Micro-Foam Nitrile Grip ANSI Cut A2 Shop Gloves (12-Pair)"),
            ("Ergodyne", "Squids 3400 Dual-Clip Dielectric Grabber Belt Glove Holder Clips (6-Pack)"),
        ]
    ]

    d["H2S / 4-Gas Monitors & Respiratory"] = [
        (brand, f"{brand} {item}", "Intrinsically Safe", f"Wellsite and confined-space {item.lower()} engineered for toxic gas and welding fume protection.", "NIOSH / UL Class I Div 1 | Loud/strobe/vibe alarms | Field serviceable")
        for brand, item in [
            ("Honeywell BW", "BW MicroClip X3 Rechargeable 4-Gas Detector (H2S, CO, O2, LEL — 3-Yr Sensor)"),
            ("Honeywell BW", "BW Clip Real-Time 2-Year Maintenance-Free Single-Gas H2S Monitor (10/15 ppm)"),
            ("Honeywell BW", "BW Solo Serviceable Wireless Single-Gas H2S Sour-Gas Personal Monitor"),
            ("MSA Safety", "ALTAIR 4XR Bluetooth Charcoal 4-Gas Detector (LEL, O2, CO, H2S — 4-Yr Warranty)"),
            ("MSA Safety", "ALTAIR 2X Pulse-Check Single-Gas H2S Detector"),
            ("Industrial Scientific", "Ventis MX4 Confined-Space 4-Gas Monitor w/ Motorized Sample Draw Pump"),
            ("Forensics / CalGas", "34L Quad-Mix 4-Gas Calibration Cylinder (H2S 25ppm, CO 100ppm, CH4, O2) + Regulator"),
            ("3M", "6502QL Rugged Comfort Quick-Latch Silicone Half-Facepiece Reusable Respirator"),
            ("3M", "7502 Soft-Seal Silicone Half-Face Welding Respirator (Fits Under Pipeliner Hoods)"),
            ("3M", "6800 Full-Facepiece Reusable Respirator for Tank Cleaning & Chemical Vapors"),
            ("3M", "2097 P100 Particulate & Nuisance Organic-Vapor Pancake Welding Filters (6-Pair)"),
            ("3M", "2297 Advanced Low-Breathing-Resistance P100 Welding Particulate Filters (5-Pair)"),
            ("3M", "60926 Multi-Gas / Organic Vapor / Acid Gas / P100 Combination Cartridges (3-Pair)"),
            ("3M", "60923 Organic Vapor / Acid Gas / H2S-Escape / P100 Respirator Cartridges"),
            ("Miller Electric", "LPR-100 Low-Profile Half-Mask P100 Welding Respirator w/ Hard Case"),
            ("GVS", "Elipse Integra P100 Compact Mask + Integrated Anti-Fog Grinding Goggle"),
            ("3M", "8511 Cool-Flow Exhalation Valve N95 Sanding & Grinding Dust Respirators (10-Box)"),
            ("3M Peltor", "X5A Over-the-Head NRR 31 dB Extreme-Noise Compressor & Rig Hearing Muff"),
            ("3M Peltor", "X4P3E Hard-Hat Cap-Mount NRR 25 dB Slim Earmuffs"),
            ("Howard Leight", "Laser Lite NRR 32 dB Hi-Vis Corded Foam Disposable Earplugs (100-Pair Box)"),
        ]
    ]

    d["Fall Protection, Spill Kits & First Aid"] = [
        (brand, f"{brand} {item}", "OSHA / ANSI Z359", f"Lease-site and elevated-rack {item.lower()} meeting OSHA, DOT, and operator HSE mandates.", "ANSI Z359 / OSHA 1926 | Weather-sealed container | Inspection tag")
        for brand, item in [
            ("3M DBI-SALA", "ExoFit X300 Comfort Vest-Style 5-Point Full-Body Harness w/ Back & Side D-Rings"),
            ("3M DBI-SALA", "Delta No-Tangle Arc-Flash/Welding Nomex Kevlar FR Full-Body Harness"),
            ("Guardian Fall", "Series 3 Padded Tongue-Buckle 5-Point Rigging & Pipe-Rack Harness"),
            ("3M DBI-SALA", "Nano-Lok 6-Ft Twin-Leg 100% Tie-Off Self-Retracting Lifeline (SRL) w/ Rebar Hooks"),
            ("Guardian Fall", "Halo 20-Ft Galvanized Cable Leading-Edge Self-Retracting Lifeline (SRL)"),
            (" Werner / Guardian", "6-Ft Internal Shock-Absorbing Tubular Web Lanyard w/ Forged Snap/Rebar Hooks"),
            ("3M DBI-SALA", "6-Ft Pass-Thru Heavy-Duty Choker I-Beam & Pipe Cross-Arm Anchor Strap"),
            ("FrenchCreek", "7-Ft Aluminum Confined-Space Tank-Entry Tripod w/ 50-Ft Man-Rated Winch"),
            ("New Pig", "20-Gallon Overpack Salvage Drum Universal & Oil Spill Response Kit"),
            ("New Pig", "50-Gallon Wheeled Yard & Tank-Battery Emergency Oil-Only Spill Cart"),
            ("New Pig", "Oil-Only Heavyweight Stat-Mat Absorbent Pads (15\" x 20\" — 100-Pad Bale)"),
            ("Brady / SPC", "5-Inch x 10-Ft Floating Oil-Only Containment Booms (4-Pack for Creek/Lease)"),
            ("Eagle Manufacturing", "2-Drum Low-Profile Polyethylene Secondary Spill Containment Pallet"),
            ("Justrite", "5-Gallon Type II AccuFlow DOT/OSHA Galvanized Red Safety Gas Can w/ Hose"),
            ("Justrite", "5-Gallon Type I Yellow Diesel Flame-Arrester Metal Safety Can"),
            ("First Aid Only", "OSHA/ANSI B308 Class B 50-Person Weatherproof Metal Service-Truck First Aid Kit"),
            ("Honeywell Fendall", "Pure Flow 1000 / Porta Stream II 16-Gallon Gravity Portable Eyewash Station"),
            ("Amerex", "B456 10-Lb ABC Dry-Chemical Commercial Steel Fire Extinguisher + Heavy Vehicle Bracket"),
            ("Amerex", "B402T 5-Lb DOT Truck Cab ABC Fire Extinguisher w/ Strap Bracket (2-Pack)"),
        ]
    ]

    # 5. FLEET, HYDRAULICS & FIELD SERVICE (120: 20 each x 6)
    d["Diesel Transfer Pumps, Meters & Filters"] = [
        (brand, f"{brand} {item}", "Slip-Tank & Fleet", f"Heavy-duty field refueling {item.lower()} for pickup slip tanks, skids, and yellow iron.", "UL/cUL listed motor/body | Diesel & biodiesel compatible | Weather sealed")
        for brand, item in [
            ("Fill-Rite", "FR4210H 12V DC 20-GPM High-Flow Cast-Iron Diesel Transfer Pump w/ Auto Nozzle"),
            ("Fill-Rite", "FR2410H 24V DC 15-GPM Heavy Equipment Fuel Transfer Pump"),
            ("Fill-Rite", "FR700V 115V AC 20-GPM Yard & Skid Tank Stationary Fuel Transfer Pump"),
            ("Fill-Rite", "FR310VN 115/230V AC 35-GPM Bulk Yard High-Flow Fuel Pump"),
            ("Fill-Rite", "RD812NH Rotary Vane Portable 8-GPM 12VClamp-On Mini Diesel Pump"),
            ("Fill-Rite", "SD1102 Manual Dual-Action Piston Drum & Slip-Tank Hand Pump (20 Gal/100 Strokes)"),
            ("GPI", "EZ-8 12V DC 8-GPM Lightweight Aluminum Rotary Gear Fuel Pump"),
            ("GPI", "M-150S-EM 12V DC 15-GPM Gear Fuel Transfer Pump w/ Unleaded/Diesel Nozzle"),
            ("GPI", "PRO20-115AD 115V AC 20-GPM Commercial Yard Fuel Pump"),
            ("Fill-Rite", "807C1 3-Wheel Mechanical Nutating-Disc Fuel Flow Meter (5–20 GPM, 3/4\" NPT)"),
            ("Fill-Rite", "901C1.5 4-Digit Large-Register Mechanical Bulk Fuel Meter (6–40 GPM, 1\"/1.5\")"),
            ("GPI", "01A31GM 01A Aluminum Digital Turbine In-Line Diesel Fuel Meter (3–30 GPM)"),
            ("Fill-Rite", "N075DAU10 3/4-Inch Green Diesel Automatic Shut-Off Fuel Nozzle"),
            ("Fill-Rite", "N100DAU13 1-Inch High-Flow Ultra-Truck Diesel Auto Shut-Off Nozzle"),
            ("Fill-Rite", "S075H1314 & S100H1315 Multi-Plane 360-Deg Arctic Fuel Hose Swivel"),
            ("Goldenrod", "496-3/4 Water-Block Spin-On Diesel Fuel Filter Assembly w/ Clear Bowl"),
            ("Cim-Tek", "70062 Centurion 10-Micron Particulate & Hydrosorb Fuel Filter Kit (1\" NPT)"),
            ("Fill-Rite", "FRH07520 3/4\" x 20-Ft Internal Static-Wire Cold-Weather Fuel Transfer Hose"),
            ("Fill-Rite", "FRH10020 1\" x 20-Ft High-Flow Arctic Static-Wire Fuel Hose"),
        ]
    ]

    d["Grease Guns, Hose Reels & Lubrication"] = [
        (brand, f"{brand} {item}", "10,000 PSI Lube", f"Preventive-maintenance {item.lower()} keeping excavators, fifth wheels, and zerks greased.", "10,000 PSI rated | Heavy steel barrel | Zero-leak seals")
        for brand, item in [
            ("DEWALT", "DCGG571M1 20V MAX Variable-Speed 10,000 PSI Cordless Grease Gun Kit"),
            ("Lincoln Industrial", "1884 PowerLuber 20V Lithium-Ion 2-Speed LCD Cordless Grease Gun Kit"),
            ("Milwaukee", "2446-21XC M12 Cordless Compact 8,000 PSI Grease Gun Kit"),
            ("Alemite", "500-E Heavy-Duty 10,000 PSI Cast-Head Lever Manual Grease Gun"),
            ("Lincoln Industrial", "1134 Heavy-Duty Pistol-Grip One-Hand Grease Gun w/ 18\" Whip Hose"),
            ("LockNLube", "GC81011 Original Locking Grease Coupler (Locks Onto Zerks to 10,000 PSI)"),
            ("LockNLube", "GC81042 XL Extended-Reach Locking Grease Coupler for Recessed Pins"),
            ("LockNLube", "LNL120 Professional 7-Piece Quick-Connect Recessed/90-Deg/Needle Grease Kit"),
            ("Lumax / Astro", "110-Piece SAE & Metric Straight, 45-Deg & 90-Deg Hydraulic Grease Zerk Kit"),
            ("Innovative Products", "IPA 7862 Grease Joint Rejuvenator Tool (Flushes Hardened Dried Pin Channels)"),
            ("Lucas Oil", "Red 'N' Tacky #2 Anti-Seize Heavy-Duty Grease Cartridges (10-Tube Case)"),
            ("Mystik", "JT-6 Hi-Temp #2 Extreme-Pressure Lithium Complex Grease (10-Tube Case)"),
            ("Schaeffers / Valvoline", "5% Moly Heavy-Duty Pin, Bushing & Fifth-Wheel Grease (10-Tube Case)"),
            ("Coxreels", "SH-N-350 Super-Hub Heavy Steel Spring-Rewind 3/8\" x 50' Shop Air/Water Hose Reel"),
            ("Reelcraft", "Series 7000 Heavy-Duty Service-Truck 3/8\" x 35' High-Pressure Grease Hose Reel"),
            ("Lincoln Industrial", "917 Air-Operated 50:1 High-Pressure 5-Gallon Pail Grease Pump Assembly"),
            ("Fill-Rite / Roughneck", "Pneumatic 5:1 Drum Stub Oil Transfer Pump w/ Digital Preset Oil Meter Gun"),
            ("JohnDow Industries", "JDI-20DC 20-Gallon Pressurized Steel Self-Evacuating Portable Waste Oil Drain"),
            ("Lisle", "17942 4.5-Gallon Heavy Black Polyethylene Diesel Truck Oil Drain Pan w/ Spout"),
        ]
    ]

    d["Hydraulic Jacks, Rams, Pumps & Couplers"] = [
        (brand, f"{brand} {item}", "10,000 PSI Hyd", f"High-pressure industrial {item.lower()} for lifting, pressing, and skid-steer plumbing.", "10,000 PSI rated | Hard-chrome plunger | Zero-drip quick connect")
        for brand, item in [
            ("Enerpac", "RC-106 10-Ton 6-Inch Stroke General-Purpose Single-Acting Hydraulic Cylinder"),
            ("Enerpac", "RC-256 25-Ton 6-Inch Stroke Heavy-Duty Hydraulic Lifting Ram"),
            ("Enerpac", "RSM-200 20-Ton Low-Height Flat-Jac Pancake Hydraulic Cylinder (Tight Gaps)"),
            ("Enerpac", "RCH-202 20-Ton Hollow-Plunger Hydraulic Cylinder for Pulling Pins & Studs"),
            ("Enerpac", "P-392 Lightweight Two-Speed High-Pressure Hydraulic Hand Pump (10,000 PSI)"),
            ("Enerpac", "PA-133 Turbo II Air-Over-Hydraulic Foot Treadle Pump (10,000 PSI)"),
            ("Enerpac", "HC-7206 6-Ft Thermo-Plastic 10,000 PSI Hydraulic Hose w/ CH-604 Coupler"),
            ("Enerpac", "GA45GC Gauge-Adaptor & 10,000 PSI Glycerin-Filled Tonnage/PSI Gauge Assembly"),
            ("OTC", "9325A 20-Ton Heavy-Duty Air-Assisted & Manual Hydraulic Truck Bottle Jack"),
            ("ESCO / Sunex", "22-Ton Air/Hydraulic Axle Floor Service Jack for Loaded Semis & Trailers"),
            ("Hi-Lift", "XT-485 48-Inch All-Cast-Iron Extreme Farm, Ranch & Rig Utility Jack"),
            ("Summit Hydraulics", "1/2\" Body x 1/2\" NPT ISO 16028 Flat-Face Skid-Steer Quick Coupler Pair + Caps"),
            ("Summit Hydraulics", "3/4\" Body High-Flow ISO 16028 Flat-Face Skid-Steer Mulcher/Trencher Couplers"),
            ("Parker / Pioneer", "4000-Series 1/2\" NPT Ag Ball/Poppet Hydraulic Quick-Disconnect Coupler Set (2-Pair)"),
            ("Dixon / Enerpac", "3/8\" NPT 10,000 PSI High-Pressure Screw-Together Hydraulic Ram Coupler Set"),
            ("Reliable Aftermarket", "64-Piece JIC 37-Deg Flare Steel Hydraulic Cap & Plug Master Kit (#4 to #16)"),
            ("Reliable Aftermarket", "72-Piece ORFS Flat-Face O-Ring Hydraulic Cap & Plug Service Truck Kit"),
            ("Reliable Aftermarket", "90-Durometer Urethane & Buna Boss O-Ring Kit for SAE Straight-Thread Ports"),
            ("OTC", "1266 Adjustable Gland-Nut Spanner Wrench + 3-Pc U-Cup Rod Seal Twister Install Set"),
            ("Apache / Continental", "1/2\" x 72\" SAE 100R2AT 2-Wire 4,000 PSI Hydraulic Hose Assemblies (2-Pack)"),
        ]
    ]

    d["Service Truck Compressors & Air Tools"] = [
        (brand, f"{brand} {item}", "Service Truck Air", f"Field-ready pneumatic {item.lower()} built for mobile mechanic trucks and fabrication bays.", "300 PSI rated | Cast-iron/alloy build | Cold-weather flexible")
        for brand, item in [
            ("Ingersoll Rand", "2475F14G 30-Gallon 14-HP Honda GX390 Gas-Driven Service-Truck Air Compressor"),
            ("Rolair", "VT25BIG 2.5-HP Wheeled Jobsite Cast-Iron Pump Electric Air Compressor"),
            ("Ingersoll Rand", "285B-6 1-Inch Drive 6-Inch Extended-Anvil Pneumatic Semi-Tire Impact Wrench (1,770 ft-lbs)"),
            ("Ingersoll Rand", "2235TiMAX 1/2-Inch Drive Titanium Pneumatic Impact Wrench (1,350 ft-lbs)"),
            ("Ingersoll Rand", "125 Standard-Duty Pneumatic Needle Scaler (19 Steel Needles for Weld Slag & Scale)"),
            ("Chicago Pneumatic", "CP717 Super-Duty .498-Shank Pneumatic Air Hammer / Rivet Buster Kit"),
            ("Astro Pneumatic", "4980 .498-Shank Thor High-Power Air Hammer + Pickle-Fork/Chisel Bit Set"),
            ("Ingersoll Rand", "3107G Edge Series 1/4\" Heavy-Duty Straight Pneumatic Die Grinder"),
            ("Flexzilla", "Pro 3/8-Inch x 50-Ft Extreme All-Weather (-40F to 140F) Hybrid Polymer Air Hose"),
            ("Goodyear / Continental", "1/2-Inch x 50-Ft USA Black/Red EPDM Rubber 300 PSI Heavy Shop Air Hose"),
            ("Dixon Valve", "Air King 2-Lug Universal Malleable-Iron Jackhammer/Compressor Couplings + Safety Clips"),
            ("Milton Industries", "S-217 14-Piece High-Flow V-Style 1/4\" NPT Brass Coupler & Plug Kit"),
            ("Milton Industries", "1815 1/2-Inch NPT G-Style High-CFM 1\" Impact Wrench Coupler & Plug Set"),
            ("Milton Industries", "S-506 Original Dual-Head Chuck Heavy-Duty Tire Inflator Gauge w/ 15\" Hose"),
            ("AstroAI / Milton", "S-575Pro 250-PSI Digital Pistol-Grip Semi-Truck Dual-Chuck Tire Inflator"),
            ("Milton Industries", "1121-8 1/2-Inch NPT Piggyback Filter/Regulator + Lubricator (FRL) Combo"),
            ("Guardair", "U75XT024AA Ultra-X 24-Inch Extended-Reach OSHA-Compliant Safety Air Blow Gun"),
            ("Milton Industries", "S-148 Lever-Action Rubber-Tip & Venturi Shop Air Blow Gun Trio"),
            ("Viair", "450P-Automatic 100% Duty-Cycle 12V Portable Commercial Truck Tire Air Compressor"),
            (" Tsunami / Motor Guard", "M-60 Sub-Micronic Compressed-Air Plasma-Cutter Water/Oil Coalescing Filter"),
        ]
    ]

    d["12V/24V Jump Packs, Chargers & HD Scanners"] = [
        (brand, f"{brand} {item}", "12V/24V Diesel", f"Commercial diesel electrical {item.lower()} keeping trucks, cranes, and yellow iron starting.", "Reverse-polarity protected | Sub-zero start power | Heavy copper leads")
        for brand, item in [
            ("NOCO", "Boost Max GB250+ 5250-Amp 12V UltraSafe Lithium Jump Starter (Up to 16L Diesel)"),
            ("NOCO", "Boost Max GB500+ 6250-Amp 12V & 24V Commercial Fleet & Excavator Jump Starter"),
            ("Clore Automotive", "Jump-N-Carry JNC1224 3400/1700 Peak Amp 12V/24V AGM Fleet Jump Starter"),
            ("NOCO", "GENIUSPRO25 25-Amp 6V/12V/24V Waterproof Smart Charger & Power Supply"),
            ("Associated Equipment", "6009 70/60-Amp 6/12/24V Heavy-Duty Wheeled Fleet Battery Charger/Starter"),
            ("Quick Cable", "1/0 AWG 25-Ft 800-Amp Commercial Service-Truck Plug-In Booster Jumper Cable Kit"),
            ("Ancel / NEXIQ", "HD3400 / J1939 & J1708 Heavy-Duty Diesel Truck Scanner w/ Forced DPF Regen"),
            ("OTC", "3188 130-Amp Heavy-Duty Inductive 6V/12V Battery & Charging System Load Tester"),
            ("Midtronics / Clore", "SOLAR BA327 Digital 12V/24V Battery & Cranking/Charging Analyzer w/ Printer"),
            ("Power Probe", "PP3CS / Power Probe 3 Master 12V–24V Automotive/Equipment Circuit Tester Kit"),
            ("JRready / Deutsch", "398-Piece Genuine-Style Deutsch DT 2/3/4/6/8/12-Pin Waterproof Connector & Solid-Pin Crimper Kit"),
            ("Wirefy", "540-Piece Marine-Grade Adhesive-Lined Dual-Wall Heat-Shrink Butt/Ring Terminal Kit"),
            ("Ancor Marine", "10/12/14/16 AWG Tinned Copper Primary Spool Assortment for Trailer & Skid Wiring"),
            ("Blue Sea Systems", "ST Blade 12-Circuit ATO/ATC Waterproof Fuse Block w/ Negative Bus & Cover"),
            ("Pollak / Cole Hersee", "75904 300-Amp Heavy-Duty Master Battery Disconnect Switch w/ Lockout Plate"),
            ("NOCO", "GCP1 15-Amp 125V AC Waterproof Flanged Shore-Power / Block-Heater Bumper Inlet"),
            ("Kats Heaters", "300-Watt Heavy-Duty Magnetic Engine Oil-Pan & Hydraulic Tank Winter Block Heater"),
            ("Optima / Odyssey", "Heavy-Duty Group 31 Dual-Battery Steel Hold-Down Tray & Military Terminal Clamps"),
            ("Tesa / Coroplast", "High-Heat Engine-Bay Abrasion-Resistant Cloth Wiring Loom Harness Tape (6-Roll)"),
        ]
    ]

    d["Tire Service, Mud Flaps & Shop Consumables"] = [
        (brand, f"{brand} {item}", "Fleet Bay Staple", f"High-turnover fleet maintenance {item.lower()} stocked in every rig and service truck.", "Commercial fleet grade | Bulk value pack | Harsh-environment formula")
        for brand, item in [
            ("Ken-Tool", "34645 38-Inch & 41-Inch Tubeless Semi-Truck Tire Mount & Demount Iron Pair"),
            ("Gaither / Cheetah", "CH-5 5-Gallon ASME-Certified Commercial Bead-Seater Air Blaster Tank"),
            ("Blackjack Tire", "KT-340 Heavy-Duty T-Handle Cast-Steel Semi & Tractor Radial Tire Plug Repair Kit"),
            ("AME International", "10-Piece 1/2\" & 1\" Drive Color-Coded Torque-Limiting Impact Extension Stick Set"),
            ("Milton / Haltec", "50-Piece High-Temp Brass TR413/TR572 Valve Stems, Cores & Double-Seal Metal Caps"),
            ("Buyers Products", "24\" x 30\" x 1/2\" Extra-Thick Anti-Spray Chevron Semi & Service-Truck Mud Flaps (Pair)"),
            ("Buyers Products", "Spring-Loaded Stainless/Black Steel 30-Inch Bolt-On Mud Flap Hanger Brackets (Pair)"),
            ("CRC Industries", "Brakleen Non-Chlorinated Brake & Metal Parts Degreaser Spray (14-Oz — Case of 12)"),
            ("B'laster", "PB Blaster Penetrating Catalyst Rust-Breaker Spray (11-Oz Cans — 6-Pack)"),
            ("Kano Laboratories", "AeroKroil Creeping Oil Penetrant for Frozen Studs & Valves (13-Oz — 2-Pack)"),
            ("CRC Industries", "QD Electronic Contact Cleaner & Heavy-Duty Corrosion Inhibitor Spray Twin-Pack"),
            ("Permatex", "Medium-Strength Blue 242 & High-Strength Red 271 Threadlocker Gel/Liquid Shop Twin-Pack"),
            ("Permatex", "Ultra Black Maximum Oil-Resistance RTV Silicone Flange Gasket Maker (6-Tube Pack)"),
            ("JB Weld", "Original Cold-Weld Steel Reinforced Epoxy & WaterWeld Emergency Tank/Pipe Putty Kit"),
            ("GOJO / Zep", "Cherry Bomb / Natural Orange Pumice Heavy Industrial Grease Hand Cleaner (1-Gal Pump)"),
            ("Tub O' Towels", "Heavy-Duty 10\" x 12\" Citrus Degreasing Waterless Hand & Tool Wipes (90-Count, 2-Tubs)"),
            ("Scott / Kimberly-Clark", "Shop Towels Pro Blue Heavy Hydroknit Oil-Absorbent Roll/Box (200-Sheet Center-Pull)"),
            ("Lisle", "Magnetic Stainless Steel 6\" & 9.5\" Rectangular Bolt & Parts Trays (3-Piece Set)"),
            ("Hopkins / FloTool", "Giant Spill-Saver Transmission, Hydraulic & Crankcase Offset Funnel Trio"),
            ("Master Magnetics", "36-Inch Telescoping 50-Lb Heavy-Duty Magnetic Sweeper for Pipe Yards & Driveways"),
        ]
    ]
    return d

SUBCATEGORY_CATALOG_PART4 = _build_part4()
