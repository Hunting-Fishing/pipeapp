"""Compact industrial product matrices for Categories 3-5."""

EXTRA_WRENCH_ITEMS = [
    ("Wright Tool", "Wright Tool 3490 3/8-Inch Drive 84-Tooth Contour-Grip Industrial Ratchet", "Dual-Pawl 84T", "Forged 4140 alloy dual-pawl 3/8\" ratchet for tight valve boxes.", "84-tooth 4.3-deg swing | Nitrile grip | Made in USA"),
    ("Proto", "Proto J260SGXL XL Metric Combination Wrench Roll (8mm-24mm, 15-Pc)", "Metric Skid Spec", "Extra-long metric wrench roll for diesel engines, compressors, and pumps.", "8mm-24mm metric | Anti-Slip Design | Tool roll"),
]

def _build_part3():
    d = {}
    d["Shackles, Hooks, Swivels & Hardware"] = [
        ("Crosby", f"Crosby G-209 Screw Pin Anchor Shackle ({sz} - {wll} Ton WLL, Galvanized)", "ASME B30.26", f"Forged Crosby G-209 {sz} galvanized anchor shackle rated {wll} metric tons.", f"{wll} Ton WLL | Alloy pin | PIC stamped")
        for sz, wll in [('3/8"', '1.0'), ('1/2"', '2.0'), ('5/8"', '3.25'), ('7/8"', '6.5'), ('1"', '8.5'), ('1-1/8"', '9.5'), ('1-1/4"', '12.0'), ('1-1/2"', '17.0')]
    ] + [
        ("Crosby", f"Crosby G-2130 Bolt-Type Safety Shackle w/ Cotter ({sz} - {wll} Ton WLL)", "Critical Lift", f"Bolt-nut-cotter {sz} safety shackle for overhead crane and pipe lifts.", f"{wll} Ton WLL | Cotter pin lock | Fatigue rated")
        for sz, wll in [('1/2"', '2.0'), ('5/8"', '3.25'), ('3/4"', '4.75'), ('7/8"', '6.5'), ('1"', '8.5'), ('1-1/4"', '12.0'), ('1-1/2"', '17.0')]
    ] + [
        ("Crosby", f"Crosby {item}", "Forged Alloy", f"Heavy rigging {item.lower()} built to ASME B30.26 lifting specs.", "Quenched & tempered | Stamped WLL | Rigging grade")
        for item in [
            'A-338 Grade 100 Clevis Grab Hook (3/8" - 8,800 lb WLL)',
            'A-1339 Grade 100 Clevis Sling Hook w/ Latch (1/2" - 15,000 lb WLL)',
            'S-322AN Swivel Hoist Hook w/ Latch (5-Ton WLL)',
            'S-319C Alloy Eye Foundry Hook (3/8" Chain)',
            'A-342 Alloy Oblong Master Link for Crane Bridles (1" Stock)',
            'G-277 Forged Shoulder Nut Machinery Eye Bolt Set (1/2" & 3/4")',
            'HG-226 Jaw & Jaw Hot-Dip Galvanized Turnbuckle (3/4" x 12")',
        ]
    ]

    d["Web Slings, Round Slings & Wire Chokers"] = [
        ("Lift-All", f'Lift-All Tuff-Edge II 2-Ply Eye & Eye Nylon Web Sling ({spec})', "Red Core Yarn", f"Heavy abrasion-resistant polymer-edge {spec} lifting sling for pipe bundles.", "Tuff-Edge polymer yarns | Red warning core | Sewn leather tag")
        for spec in ['1" x 6-Ft', '2" x 8-Ft', '2" x 12-Ft', '2" x 16-Ft', '2" x 20-Ft', '3" x 12-Ft', '3" x 16-Ft', '4" x 16-Ft', '4" x 20-Ft']
    ] + [
        ("Lift-All", f"Lift-All KeyFlex Endless Polyester Round Sling ({color}, {len_ft} — {cap} Vertical)", "Color-Coded WLL", f"Double-jacketed {color.lower()} endless round sling choking coated pipe without damage.", f"{cap} vertical / 2x basket | Double poly jacket | Zero stretch mar")
        for color, len_ft, cap in [('Purple', '6-Ft', '2,600 lb'), ('Green', '8-Ft', '5,300 lb'), ('Green', '12-Ft', '5,300 lb'), ('Yellow', '10-Ft', '8,400 lb'), ('Yellow', '16-Ft', '8,400 lb'), ('Tan', '12-Ft', '10,600 lb'), ('Red', '16-Ft', '13,200 lb'), ('Blue', '20-Ft', '21,200 lb')]
    ] + [
        ("Peerless", f"Flemish-Eye Pressed 6x19 EIPS IWRC Wire Rope Choker Sling ({spec})", "Steel Pipe Choker", f" USA-swaged {spec} wire rope sling for yard pipe handling and winching.", "Flemish eye + steel sleeve | 6x19 IWRC core | Metal WLL tag")
        for spec in ['3/8" x 8-Ft (1.4 Ton)', '1/2" x 10-Ft (2.5 Ton)', '1/2" x 16-Ft (2.5 Ton)', '5/8" x 12-Ft (3.9 Ton)', '3/4" x 16-Ft (5.6 Ton)']
    ]

    d["Chain Hoists, Lever Pullers & Clamps"] = [
        ("Harrington", f"Harrington LB Series Steel Lever Chain Hoist / Come-Along ({spec})", "Weston Dual Pawl", f"Compact industrial lever puller ({spec}) for aligning heavy pipe spools and skids.", "Nickel-plated G100 load chain | 360-deg handle | Proof tested")
        for spec in ['3/4-Ton x 5-Ft', '3/4-Ton x 10-Ft', '1.5-Ton x 5-Ft', '1.5-Ton x 10-Ft', '1.5-Ton x 20-Ft', '3-Ton x 10-Ft', '6-Ton x 10-Ft']
    ] + [
        ("CM Rigging", f"Columbus McKinnon Hurricane 360 Hand Chain Block Hoist ({spec})", "360-Deg Hand Wheel", f"Rotating hand-chain cover lets riggers pull {spec} loads from any angle.", "360-deg rotating hand guide | Load-limiter | Hardened alloy chain")
        for spec in ['1-Ton x 10-Ft', '1-Ton x 20-Ft', '2-Ton x 10-Ft', '2-Ton x 20-Ft', '3-Ton x 15-Ft', '5-Ton x 20-Ft']
    ] + [
        ("JET Tools", f"JET Heavy-Duty Rigging {tool}", "ASME B30.16", f"Shop and field {tool.lower()} engineered for structural steel and pipe positioning.", "All-steel load plate | Safety latch | Certified WLL")
        for tool in [
            '1-Ton Vertical Steel Plate Lifting Clamp', '2-Ton Vertical Locking Plate Clamp', '3-Ton Horizontal Plate Clamp Pair',
            '2-Ton Adjustable I-Beam Push Trolley', '3-Ton Geared I-Beam Trolley', '3-Ton Fixed Structural Jaw Beam Clamp',
            '5-Ton Heavy Structural Beam Clamp', '4.5-Ton 6" Sheave Wire-Rope Snatch Block w/ Shackle', '8-Ton 8" Oilfield Tailboard Snatch Block w/ Hook',
        ]
    ]

    d["Grade 70/100 Chains & Load Binders"] = [
        ("Vulcan", f"DOT Grade 70 Yellow-Chromate Transport Binder Chain w/ Grab Hooks ({spec})", "FMCSA / DOT G70", f"NACM-stamped {spec} Grade 70 transport chain for flatbeds, hotshots, and lowboys.", "4:1 DOT safety factor | Stamped G70 links | Forged clevis hooks")
        for spec in ['5/16" x 16-Ft (4,700 WLL)', '5/16" x 20-Ft (4,700 WLL)', '5/16" x 25-Ft (4,700 WLL)', '3/8" x 16-Ft (6,600 WLL)', '3/8" x 25-Ft (6,600 WLL)', '1/2" x 16-Ft (11,300 WLL)', '1/2" x 20-Ft (11,300 WLL)', '1/2" x 25-Ft (11,300 WLL)']
    ] + [
        ("Peerless", f"Peerless QuikBinder Plus & Heavy Load Binder ({spec})", "Zero Whip Handle", f"High-visibility forged load binder ({spec}) securing heavy equipment and drill pipe.", "Stamped WLL on barrel | Folding/ratchet safety | Proof-tested")
        for spec in [
            '5/16"-3/8" Folding-Handle Ratchet Binder (7,100 WLL)', '3/8"-1/2" QuikBinder Plus Ratchet Binder (12,000 WLL)',
            '1/2"-5/8" Heavy Lowboy Ratchet Binder (18,100 WLL)', 'Grade 80 3/8" x 20-Ft Black Alloy Tie-Down Chain (7,100 WLL)',
            'Grade 100 3/8" x 20-Ft Overhead & Heavy-Haul Chain (8,800 WLL)', 'Grade 100 1/2" x 20-Ft Excavator Lowboy Chain (15,000 WLL)',
            'Grade 100 5/8" x 20-Ft Dozer & Rig Hauling Chain (22,600 WLL)', '5/16" x 10-Ft Grade 70 J-Hook V-Bridle Tow Chain',
            '3/8" x 15-Ft Grade 80 Recovery Cluster Hook Chain', 'Lockable Aluminum Headache-Rack Chain & Binder Rack',
            '5-Gallon Ventilated Bucket Grade-70 Bulk Chain (3/8" x 100-Ft)', 'Forged Grade 70 Clevis Grab Hook 6-Pack (3/8" & 1/2")',
        ]
    ]

    d["Flatbed Winch Straps, Tarps & Stakes"] = [
        ("Vulcan", f"Flatbed Cargo Securement {item}", "DOT WSTDA Stamped", f"Commercial flatbed and pipe-hauling {item.lower()} meeting CVSA roadside standards.", "UV/cut-resistant webbing | Stamped WLL tag | Flatbed fleet spec")
        for item in [
            '4" x 30-Ft Heavy Winch Straps w/ Flat Hooks (4-Pack, 5,400 WLL)', '4" x 40-Ft Pipe-Load Winch Straps w/ Flat Hooks (4-Pack)',
            '4" x 30-Ft Winch Straps w/ Grade-70 Chain Anchors (4-Pack)', '3" x 30-Ft Heavy-Duty Ratchet Straps w/ Flat Hooks (2-Pack)',
            '2" x 27-Ft J-Hook & Flat-Hook Hotshot Ratchet Straps (4-Pack, 3,333 WLL)', '2" x 16-Ft E-Track Enclosed Trailer Ratchet Straps (4-Pack)',
            'Weld-On Standard Profile Steel Underbody Trailer Winches (4-Pack)', 'Sliding C-Channel Flatbed Trailer Winches (4-Pack)',
            '40-Inch Chrome-Plated Knurled Non-Slip Combination Winch Bar', 'Ergonomic Box-End Ratcheting Flatbed Winch Bar',
            '24-Ft x 27-Ft Heavy 18-Oz Waterproof 8-Ft Drop Lumber & Pipe Tarp', '16-Ft x 27-Ft Heavy 18-Oz 4-Ft Drop Steel & Machinery Tarp',
            '21-Inch EPDM Heavy Cold-Weather Rubber Tarp Straps w/ S-Hooks (50-Box)', '31-Inch EPDM Heavy Rubber Tarp Straps (50-Box)',
            '54-Inch Removable Steel Stake-Pocket Flatbed Pipe Stakes (4-Pack)', '8" x 8" x 36" Heavy-Duty Polyethylene Vee-Board Pipe Edge Protectors (4-Pack)',
            '4-Inch Plastic Webbing Corner Protectors (20-Pack w/ Mesh Bag)', 'Rubber Friction Anti-Slip Coil & Pipe Bunk Mats (4-Pack)',
            'Bolt-On/Weld-On Forged 1/2" D-Ring Tie-Down Anchors (8-Pack, 12,000 lb)', 'Heavy-Duty Aluminum Folding Flatbed Ladder',
            '8-Ft Fiberglass Telescoping Strap & V-Board Placement Pole',
        ]
    ]

    d["Oversize Load Banners, Beacons & Safety"] = [
        ("Buyers Products", f"Heavy-Haul & Escort {item}", "DOT / FMCSA Spec", f"Commercial fleet {item.lower()} built for oversize pipe loads, hotshots, and service trucks.", "Weatherproof highway build | High-output visibility | DOT compliant")
        for item in [
            '18" x 84" Heavy Mesh Reversible OVERSIZE LOAD / WIDE LOAD Banner w/ Bungees',
            '18" x 18" Wire-Loop & Dowel Red/Fluorescent-Orange Warning Flags (4-Pack)',
            'Heavy-Duty 90-Lb Magnet-Mount Quick-Release Oversize Flag Holders (Pair)',
            '48-Inch SAE Class 1 Amber/White LED Rooftop Tow & Escort Strobe Lightbar',
            'Rechargeable Magnetic Wireless SAE Class 1 Amber Tow/Tail Pipe Strobe Beacon',
            'Mini 17-Inch Permanent/Magnet SAE Class 1 Amber Service-Truck LED Beacon',
            '15-Ft Coiled Red & Blue Tractor-Trailer Air Brake Hose Assembly w/ Gladhands',
            '15-Ft Heavy Zinc-Plug 7-Way ABS Green Coiled Semi Trailer Electrical Cord',
            '3-In-1 Wrapped 15-Ft ABS Power Cord & Air Line Hose Tracker Kit',
            'Cast-Aluminum Color-Coded Service & Emergency Gladhand Pair w/ Poly Seals',
            'Checkers Monster Heavy-Duty Urethane Mine & Semi Wheel Chocks (Pair)',
            'Solid Molded Ribbed Rubber Flatbed Wheel Chocks w/ Eyebolts (Pair)',
            '18" x 18" x 1.5" UHMW Unbreakable Crane & Service-Truck Outrigger Pads (Pair)',
            '24" x 24" x 2" Heavy UHMW Outrigger Stabilizer Pads w/ Rope Handles',
            'Cast-Steel High-Visibility Semi Trailer Kingpin Security Lock w/ Flag',
            'Heavy-Duty Gooseneck 2-5/16" Coupler & Lunette Ring Trailer Lock',
            'DOT-C2 2-Inch x 150-Ft Red/White Alternating Reflective Conspicuity Tape Roll',
            'FMVSS 125 3-Pack Weighted Roadside Emergency Warning Triangles in Box',
            'Rechargeable Magnetic LED Sequential Roadside Flare Disc Kit (6-Pack Case)',
            '15-Ft Telescoping Fiberglass Load Height Measuring Stick (Up to 15\' / 20\')',
            'Waterproof Permit, Manifest & Logbook Aluminum Clipboard Storage Box',
        ]
    ]
    return d

SUBCATEGORY_CATALOG_PART3 = _build_part3()
