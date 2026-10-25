#!/usr/bin/env node
/**
 * PipeBuyer 50+ Year (1970–2026) Industrial Equipment Catalog Builder
 *
 * Strictly IP-clean commercial data sources ONLY:
 * 1. US DOT NHTSA vPIC API (17 U.S.C. 105 Federal Public Domain)
 * 2. Caltrans Equipment Rental Rate Schedule (California State Public Domain)
 * 3. US EPA Nonroad & Heavy-Duty Engine Certification Data (17 U.S.C. 105 Public Domain)
 * 4. Factual OEM Model Nomenclature & Production Years (Uncopyrightable Facts per
 *    Feist Publications, Inc. v. Rural Telephone Service Co., 499 U.S. 340)
 *
 * Prohibited commercial spec portals (RitchieSpecs, Lectura, MachineryTrader,
 * EquipmentWatch, TractorData, Kaggle Bulldozers) are NEVER used.
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const ROOT_DIR = path.resolve(__dirname, '..');

const YEAR_FLOOR = 1970;
const YEAR_CEILING = 2026;
const GENERATED_AT = '2026-10-25T00:00:00Z';

const ALLOWED_TYPES_BY_CATEGORY = {
  'Heavy Equipment': [
    'Excavator',
    'Bulldozer',
    'Loader',
    'Backhoe',
    'Skid Steer',
    'Crane',
    'Telehandler',
    'Grader',
    'Compactor',
    'Forklift',
    'Drilling Rig',
  ],
  'Transport & Hauling': [
    'Semi Truck',
    'Flatbed Trailer',
    'Lowboy Trailer',
    'Roll Off Truck',
    'Winch Truck',
    'Step Deck',
    'Drop Deck',
    'Vacuum Truck',
    'Water Truck',
  ],
  'Site Support': [
    'Light Tower',
    'Air Compressor',
    'Welding Machine',
    'Generator',
    'Scissor Lift',
    'Boom Lift',
  ],
  'Oil & Gas Equipment': [
    'Wellhead',
    'Valves',
    'Manifold',
    'Separator',
    'Heater Treater',
    'Compressor',
    'Generator',
    'Pump',
    'Pressure Vessel',
    'Flare Stack',
  ],
  'Oilfield & Drilling': [
    'Derrick',
    'Drill Rig',
    'Mud Pump',
    'Shale Shaker',
    'BOP',
    'Cementing Unit',
    'Mud Tank',
  ],
};

const SOURCE_CALTRANS_OEM = 'public_domain_caltrans+factual_oem';
const SOURCE_EPA_OEM = 'public_domain_epa+factual_oem';
const SOURCE_VPIC_EPA_OEM = 'public_domain_nhtsa_vpic+epa+factual_oem';

const SHORT_MFR_LABELS = {
  'Caterpillar': 'Cat',
  'John Deere': 'Deere',
  'Detroit Diesel': 'Detroit',
  'FPT Industrial': 'FPT',
  'International': 'International',
  'Mercedes-Benz': 'Mercedes',
};

function eng(
  manufacturer,
  engineModel,
  displacementL,
  cylConfig,
  powerHp,
  fuelType,
  transmission,
  yearFrom,
  yearTo,
) {
  const prefix = SHORT_MFR_LABELS[manufacturer] || manufacturer;
  const dispPart = displacementL > 0 ? `${Number(displacementL).toFixed(1)}L ` : '';
  const cylPart = cylConfig ? `${cylConfig} ` : '';
  const label = `${prefix} ${engineModel} • ${dispPart}${cylPart}${fuelType} • ${Math.round(powerHp)} HP • ${transmission}`;
  return {
    label,
    manufacturer,
    engineModel,
    displacementL: Number(Number(displacementL).toFixed(2)),
    powerHp: Math.round(powerHp),
    fuelType,
    transmission,
    yearFrom,
    yearTo,
  };
}

function se(
  manufacturer,
  engineModel,
  displacementL,
  cylConfig,
  powerHp,
  fuelType = 'Diesel',
  transmission = 'Hydraulic',
) {
  return (yearFrom, yearTo) =>
    eng(
      manufacturer,
      engineModel,
      displacementL,
      cylConfig,
      powerHp,
      fuelType,
      transmission,
      yearFrom,
      yearTo,
    );
}

function buildAliases(model, explicitAliases = []) {
  const seen = new Set([model.toLowerCase()]);
  const out = [];
  const candidates = [...explicitAliases];
  const compact = model.replace(/[\s-]+/g, '');
  if (compact !== model && compact.length >= 3) {
    candidates.push(compact);
  }
  if (/^\d{3}[A-Z]?$/.test(model) && model.startsWith('3')) {
    candidates.push(`0${model}`);
  }
  for (const alias of candidates) {
    const clean = String(alias || '').trim();
    if (!clean) continue;
    const key = clean.toLowerCase();
    if (!seen.has(key)) {
      seen.add(key);
      out.push(clean);
    }
  }
  return out;
}

function mdl(
  model,
  series,
  category,
  productTypes,
  yearFrom,
  yearTo,
  enginesInput,
  aliases = [],
  source = SOURCE_CALTRANS_OEM,
) {
  const engines = (Array.isArray(enginesInput) ? enginesInput : [enginesInput]).map((item) =>
    typeof item === 'function' ? item(yearFrom, yearTo) : item,
  );
  return {
    model,
    series,
    category,
    productTypes,
    yearFrom,
    yearTo,
    aliases: buildAliases(model, aliases),
    source,
    engines,
  };
}

const EXC = ['Excavator'];
const DOZ = ['Bulldozer'];
const LDR = ['Loader'];
const BKH = ['Backhoe', 'Loader'];
const SSL = ['Skid Steer', 'Loader'];
const CRN = ['Crane'];
const TLH = ['Telehandler', 'Forklift'];
const GRD = ['Grader'];
const CMP = ['Compactor'];
const FRK = ['Forklift'];
const DRL = ['Drilling Rig'];
const ADT = ['Roll Off Truck', 'Water Truck'];
const TRK_HEAVY = ['Semi Truck', 'Winch Truck', 'Vacuum Truck', 'Water Truck', 'Roll Off Truck'];
const TRK_HWY = ['Semi Truck', 'Winch Truck'];
const TRK_MED = ['Water Truck', 'Vacuum Truck', 'Roll Off Truck', 'Winch Truck'];

// ============================================================================
// 1. CATERPILLAR (1970–2026)
// ============================================================================
const CATERPILLAR_MODELS = [
  // Classic 200-Series Excavators (1972–1994)
  mdl('215', '200 Series Excavators', 'Heavy Equipment', EXC, 1976, 1984, se('Caterpillar', '3304', 7.0, '4-Cyl Turbo', 85), ['Cat 215']),
  mdl('215B', '200 Series Excavators', 'Heavy Equipment', EXC, 1984, 1988, se('Caterpillar', '3304', 7.0, '4-Cyl Turbo', 105), ['215B LC']),
  mdl('215C', '200 Series Excavators', 'Heavy Equipment', EXC, 1987, 1992, se('Caterpillar', '3304', 7.0, '4-Cyl Turbo', 115), ['215C LC']),
  mdl('215D', '200 Series Excavators', 'Heavy Equipment', EXC, 1989, 1993, se('Caterpillar', '3304', 7.0, '4-Cyl Turbo', 125), ['215D LC']),
  mdl('225', '200 Series Excavators', 'Heavy Equipment', EXC, 1972, 1986, [
    eng('Caterpillar', '3160', 10.4, 'V8', 125, 'Diesel', 'Hydraulic', 1972, 1974),
    eng('Caterpillar', '3208', 10.4, 'V8', 135, 'Diesel', 'Hydraulic', 1974, 1986),
  ], ['225 LC', 'Cat 225']),
  mdl('225B', '200 Series Excavators', 'Heavy Equipment', EXC, 1986, 1990, se('Caterpillar', '3208', 10.4, 'V8 Turbo', 145), ['225B LC']),
  mdl('225D', '200 Series Excavators', 'Heavy Equipment', EXC, 1989, 1993, se('Caterpillar', '3208', 10.4, 'V8 Turbo', 150), ['225D LC']),
  mdl('235', '200 Series Excavators', 'Heavy Equipment', EXC, 1973, 1986, se('Caterpillar', '3306', 10.5, '6-Cyl Turbo', 195), ['Cat 235']),
  mdl('235B', '200 Series Excavators', 'Heavy Equipment', EXC, 1986, 1988, se('Caterpillar', '3306', 10.5, '6-Cyl Turbo', 215)),
  mdl('235C', '200 Series Excavators', 'Heavy Equipment', EXC, 1988, 1992, se('Caterpillar', '3306', 10.5, '6-Cyl Turbo', 250)),
  mdl('235D', '200 Series Excavators', 'Heavy Equipment', EXC, 1992, 1994, se('Caterpillar', '3306', 10.5, '6-Cyl Turbo', 250)),
  mdl('245', '200 Series Excavators', 'Heavy Equipment', EXC, 1974, 1988, se('Caterpillar', '3406', 14.6, '6-Cyl Turbo', 325), ['Cat 245']),
  mdl('245B', '200 Series Excavators', 'Heavy Equipment', EXC, 1988, 1992, se('Caterpillar', '3406B', 14.6, '6-Cyl Turbo', 360)),
  mdl('E200B', 'E-Series Excavators', 'Heavy Equipment', EXC, 1987, 1993, se('Mitsubishi', 'S6K-T', 6.4, '6-Cyl Turbo', 118), ['EL200B']),

  // 300-Series Mini Excavators (1998–2026)
  mdl('301.5', '300 Series Mini Excavators', 'Heavy Equipment', EXC, 1999, 2006, se('Perkins', '103-10', 1.0, '3-Cyl', 18), [], SOURCE_EPA_OEM),
  mdl('301.7D', '300 Series Mini Excavators', 'Heavy Equipment', EXC, 2012, 2019, se('Yanmar', '3TNV76', 1.1, '3-Cyl', 18), ['301.7D CR'], SOURCE_EPA_OEM),
  mdl('301.8', 'Next Gen Mini Excavators', 'Heavy Equipment', EXC, 2019, 2026, se('Caterpillar', 'C1.1', 1.1, '3-Cyl', 21), ['301.8C'], SOURCE_EPA_OEM),
  mdl('302.7 CR', 'Next Gen Mini Excavators', 'Heavy Equipment', EXC, 2021, 2026, se('Caterpillar', 'C1.1 Turbo', 1.1, '3-Cyl Turbo', 24), ['302.7D CR'], SOURCE_EPA_OEM),
  mdl('303.5C CR', '300 Series Mini Excavators', 'Heavy Equipment', EXC, 2006, 2012, se('Mitsubishi', 'S3Q2', 1.9, '3-Cyl', 32), [], SOURCE_EPA_OEM),
  mdl('303.5E2 CR', '300 Series Mini Excavators', 'Heavy Equipment', EXC, 2015, 2021, se('Caterpillar', 'C1.7', 1.7, '3-Cyl', 24), ['303.5E2'], SOURCE_EPA_OEM),
  mdl('303.5 CR', 'Next Gen Mini Excavators', 'Heavy Equipment', EXC, 2021, 2026, se('Caterpillar', 'C1.7', 1.7, '3-Cyl', 24), ['303.5'], SOURCE_EPA_OEM),
  mdl('304C CR', '300 Series Mini Excavators', 'Heavy Equipment', EXC, 2006, 2012, se('Mitsubishi', 'S4Q2', 2.5, '4-Cyl', 42), [], SOURCE_EPA_OEM),
  mdl('304E2', '300 Series Mini Excavators', 'Heavy Equipment', EXC, 2015, 2021, se('Caterpillar', 'C2.4', 2.4, '4-Cyl', 40), ['304E2 CR'], SOURCE_EPA_OEM),
  mdl('305C CR', '300 Series Mini Excavators', 'Heavy Equipment', EXC, 2006, 2012, se('Mitsubishi', 'S4Q2-T', 2.5, '4-Cyl Turbo', 47), [], SOURCE_EPA_OEM),
  mdl('305E2 CR', '300 Series Mini Excavators', 'Heavy Equipment', EXC, 2015, 2021, se('Caterpillar', 'C2.4', 2.4, '4-Cyl', 40), ['305E2'], SOURCE_EPA_OEM),
  mdl('305 CR', 'Next Gen Mini Excavators', 'Heavy Equipment', EXC, 2021, 2026, se('Caterpillar', 'C1.7 Turbo', 1.7, '3-Cyl Turbo', 45), ['305'], SOURCE_EPA_OEM),
  mdl('307B', '300 Series Mini Excavators', 'Heavy Equipment', EXC, 1998, 2004, se('Mitsubishi', '4M40', 2.8, '4-Cyl', 54)),
  mdl('308D CR', '300 Series Mini Excavators', 'Heavy Equipment', EXC, 2008, 2014, se('Mitsubishi', '4M40-TL', 2.8, '4-Cyl Turbo', 56)),
  mdl('308E2 CR', '300 Series Mini Excavators', 'Heavy Equipment', EXC, 2014, 2019, se('Caterpillar', 'C3.3B', 3.3, '4-Cyl Turbo', 65), ['308E2']),
  mdl('308 CR', 'Next Gen Mini Excavators', 'Heavy Equipment', EXC, 2019, 2026, se('Caterpillar', 'C3.3B', 3.3, '4-Cyl Turbo', 70), ['308'], SOURCE_EPA_OEM),
  mdl('309 CR', 'Next Gen Mini Excavators', 'Heavy Equipment', EXC, 2020, 2026, se('Caterpillar', 'C3.3B', 3.3, '4-Cyl Turbo', 70), ['309'], SOURCE_EPA_OEM),
  mdl('310', 'Next Gen Mini Excavators', 'Heavy Equipment', EXC, 2020, 2026, se('Caterpillar', 'C3.3B', 3.3, '4-Cyl Turbo', 70), ['Cat 310'], SOURCE_EPA_OEM),

  // 300-Series Small/Medium/Large Excavators (1992–2026)
  mdl('312', '300 Series Excavators', 'Heavy Equipment', EXC, 1993, 1997, se('Caterpillar', '3064T', 4.3, '4-Cyl Turbo', 84)),
  mdl('312B', '300 Series Excavators', 'Heavy Equipment', EXC, 1997, 2002, se('Caterpillar', '3064T', 4.3, '4-Cyl Turbo', 90), ['312BL']),
  mdl('312C', '300 Series Excavators', 'Heavy Equipment', EXC, 2001, 2006, se('Caterpillar', '3064T', 4.3, '4-Cyl Turbo', 90), ['312CL', '312C L']),
  mdl('312D', '300 Series Excavators', 'Heavy Equipment', EXC, 2006, 2012, se('Caterpillar', 'C4.2 ACERT', 4.2, '4-Cyl Turbo', 90), ['312DL', '312D L']),
  mdl('312E', '300 Series Excavators', 'Heavy Equipment', EXC, 2012, 2017, se('Caterpillar', 'C4.4 ACERT', 4.4, '4-Cyl Turbo', 91), ['312EL', '312E L']),
  mdl('313F', '300 Series Excavators', 'Heavy Equipment', EXC, 2015, 2020, se('Caterpillar', 'C3.4B', 3.4, '4-Cyl Turbo', 70), ['313FL', '313F L']),
  mdl('313', 'Next Gen Excavators', 'Heavy Equipment', EXC, 2020, 2026, se('Caterpillar', 'C3.6', 3.6, '4-Cyl Turbo', 108), ['313 GC']),
  mdl('315L', '300 Series Excavators', 'Heavy Equipment', EXC, 1994, 1998, se('Caterpillar', '3046T', 5.0, '6-Cyl Turbo', 99), ['315 L']),
  mdl('315C L', '300 Series Excavators', 'Heavy Equipment', EXC, 2001, 2007, se('Caterpillar', '3046T', 5.0, '6-Cyl Turbo', 110), ['315CL', '315C']),
  mdl('315D L', '300 Series Excavators', 'Heavy Equipment', EXC, 2007, 2013, se('Caterpillar', 'C4.2 ACERT', 4.2, '4-Cyl Turbo', 115), ['315DL', '315D']),
  mdl('315F L', '300 Series Excavators', 'Heavy Equipment', EXC, 2015, 2020, se('Caterpillar', 'C4.4 ACERT', 4.4, '4-Cyl Turbo', 97), ['315FL']),
  mdl('315', 'Next Gen Excavators', 'Heavy Equipment', EXC, 2020, 2026, se('Caterpillar', 'C3.6', 3.6, '4-Cyl Turbo', 108), ['315 GC']),
  mdl('320L', '300 Series Excavators', 'Heavy Equipment', EXC, 1992, 1996, se('Caterpillar', '3066T', 6.4, '6-Cyl Turbo', 128), ['320 L', '0320L']),
  mdl('320B', '300 Series Excavators', 'Heavy Equipment', EXC, 1996, 2002, se('Caterpillar', '3066T', 6.4, '6-Cyl Turbo', 134), ['320BL', '320B L', '0320B']),
  mdl('320C', '300 Series Excavators', 'Heavy Equipment', EXC, 2001, 2006, se('Caterpillar', '3066TA', 6.4, '6-Cyl Turbo', 138), ['320CL', '320C L', '0320C']),
  mdl('320D', '300 Series Excavators', 'Heavy Equipment', EXC, 2006, 2012, se('Caterpillar', 'C6.4 ACERT', 6.4, '6-Cyl Turbo', 148), ['0320D', '320DL', '320D L']),
  mdl('320E', '300 Series Excavators', 'Heavy Equipment', EXC, 2011, 2017, se('Caterpillar', 'C6.6 ACERT', 6.6, '6-Cyl Turbo', 153), ['0320E', '320EL', '320E L', '320E RR']),
  mdl('320F', '300 Series Excavators', 'Heavy Equipment', EXC, 2015, 2019, se('Caterpillar', 'C4.4 ACERT', 4.4, '4-Cyl Twin-Turbo', 161), ['0320F', '320FL', '320F L']),
  mdl('320 GC', 'Next Gen Excavators', 'Heavy Equipment', EXC, 2018, 2026, se('Caterpillar', 'C4.4', 4.4, '4-Cyl Turbo', 143), ['320GC']),
  mdl('320', 'Next Gen Excavators', 'Heavy Equipment', EXC, 2018, 2026, [
    eng('Caterpillar', 'C4.4 ACERT', 4.4, '4-Cyl Twin-Turbo', 162, 'Diesel', 'Hydraulic', 2018, 2021),
    eng('Caterpillar', 'C7.1', 7.0, '6-Cyl Turbo', 172, 'Diesel', 'Electro-Hydraulic', 2021, 2026),
  ], ['0320', 'Cat 320 Next Gen']),
  mdl('321D LCR', '300 Series Excavators', 'Heavy Equipment', EXC, 2007, 2013, se('Caterpillar', 'C6.4 ACERT', 6.4, '6-Cyl Turbo', 148), ['321DLCR']),
  mdl('322L', '300 Series Excavators', 'Heavy Equipment', EXC, 1993, 1997, se('Caterpillar', '3116TA', 6.6, '6-Cyl Turbo', 153), ['322 L']),
  mdl('322B L', '300 Series Excavators', 'Heavy Equipment', EXC, 1997, 2002, se('Caterpillar', '3116TA', 6.6, '6-Cyl Turbo', 168), ['322BL', '322B']),
  mdl('322C L', '300 Series Excavators', 'Heavy Equipment', EXC, 2001, 2006, se('Caterpillar', '3126B', 7.2, '6-Cyl Turbo', 168), ['322CL', '322C']),
  mdl('323D L', '300 Series Excavators', 'Heavy Equipment', EXC, 2006, 2012, se('Caterpillar', 'C6.4 ACERT', 6.4, '6-Cyl Turbo', 148), ['323DL', '323D']),
  mdl('323E L', '300 Series Excavators', 'Heavy Equipment', EXC, 2012, 2015, se('Caterpillar', 'C6.6 ACERT', 6.6, '6-Cyl Turbo', 164), ['323EL', '323E']),
  mdl('323F L', '300 Series Excavators', 'Heavy Equipment', EXC, 2015, 2019, se('Caterpillar', 'C7.1 ACERT', 7.0, '6-Cyl Turbo', 161), ['323FL', '323F']),
  mdl('323', 'Next Gen Excavators', 'Heavy Equipment', EXC, 2018, 2026, se('Caterpillar', 'C7.1', 7.0, '6-Cyl Turbo', 174), ['0323']),
  mdl('324D L', '300 Series Excavators', 'Heavy Equipment', EXC, 2006, 2012, se('Caterpillar', 'C7 ACERT', 7.2, '6-Cyl Turbo', 188), ['324DL', '324D']),
  mdl('325L', '300 Series Excavators', 'Heavy Equipment', EXC, 1992, 1996, se('Caterpillar', '3116TA', 6.6, '6-Cyl Turbo', 168), ['325 L']),
  mdl('325B L', '300 Series Excavators', 'Heavy Equipment', EXC, 1996, 2002, se('Caterpillar', '3116TA', 6.6, '6-Cyl Turbo', 178), ['325BL', '325B']),
  mdl('325C L', '300 Series Excavators', 'Heavy Equipment', EXC, 2001, 2006, se('Caterpillar', '3126B', 7.2, '6-Cyl Turbo', 188), ['325CL', '325C']),
  mdl('325D L', '300 Series Excavators', 'Heavy Equipment', EXC, 2006, 2011, se('Caterpillar', 'C7 ACERT', 7.2, '6-Cyl Turbo', 204), ['325DL', '325D']),
  mdl('325F', '300 Series Excavators', 'Heavy Equipment', EXC, 2015, 2020, se('Caterpillar', 'C4.4 ACERT', 4.4, '4-Cyl Twin-Turbo', 161), ['325FL']),
  mdl('325', 'Next Gen Excavators', 'Heavy Equipment', EXC, 2020, 2026, se('Caterpillar', 'C4.4', 4.4, '4-Cyl Twin-Turbo', 172), ['0325']),
  mdl('326F', '300 Series Excavators', 'Heavy Equipment', EXC, 2016, 2020, se('Caterpillar', 'C7.1 ACERT', 7.0, '6-Cyl Turbo', 203), ['326FL']),
  mdl('326', 'Next Gen Excavators', 'Heavy Equipment', EXC, 2020, 2026, se('Caterpillar', 'C7.1', 7.0, '6-Cyl Turbo', 204), ['0326']),
  mdl('329D L', '300 Series Excavators', 'Heavy Equipment', EXC, 2008, 2012, se('Caterpillar', 'C7 ACERT', 7.2, '6-Cyl Turbo', 204), ['329DL', '329D']),
  mdl('329E L', '300 Series Excavators', 'Heavy Equipment', EXC, 2011, 2016, se('Caterpillar', 'C7.1 ACERT', 7.0, '6-Cyl Turbo', 231), ['329EL', '329E']),
  mdl('330L', '300 Series Excavators', 'Heavy Equipment', EXC, 1992, 1996, se('Caterpillar', '3306TA', 10.5, '6-Cyl Turbo', 222), ['330 L']),
  mdl('330B L', '300 Series Excavators', 'Heavy Equipment', EXC, 1996, 2002, se('Caterpillar', '3306TA', 10.5, '6-Cyl Turbo', 222), ['330BL', '330B']),
  mdl('330C L', '300 Series Excavators', 'Heavy Equipment', EXC, 2001, 2006, se('Caterpillar', 'C9', 8.8, '6-Cyl Turbo', 247), ['330CL', '330C']),
  mdl('330D L', '300 Series Excavators', 'Heavy Equipment', EXC, 2006, 2011, se('Caterpillar', 'C9 ACERT', 8.8, '6-Cyl Turbo', 268), ['330DL', '330D']),
  mdl('330F', '300 Series Excavators', 'Heavy Equipment', EXC, 2015, 2019, se('Caterpillar', 'C7.1 ACERT', 7.0, '6-Cyl Twin-Turbo', 239), ['330FL', '330F L']),
  mdl('330', 'Next Gen Excavators', 'Heavy Equipment', EXC, 2019, 2026, se('Caterpillar', 'C7.1', 7.0, '6-Cyl Twin-Turbo', 273), ['0330', '330 GC']),
  mdl('335F LCR', '300 Series Excavators', 'Heavy Equipment', EXC, 2015, 2020, se('Caterpillar', 'C7.1 ACERT', 7.0, '6-Cyl Turbo', 203), ['335FLCR']),
  mdl('335', 'Next Gen Excavators', 'Heavy Equipment', EXC, 2020, 2026, se('Caterpillar', 'C7.1', 7.0, '6-Cyl Twin-Turbo', 273), ['0335']),
  mdl('336D', '300 Series Excavators', 'Heavy Equipment', EXC, 2008, 2012, se('Caterpillar', 'C9 ACERT', 8.8, '6-Cyl Turbo', 268), ['0336D', '336DL', '336D L']),
  mdl('336E', '300 Series Excavators', 'Heavy Equipment', EXC, 2011, 2015, [
    eng('Caterpillar', 'C9.3 ACERT', 9.3, '6-Cyl Turbo', 300, 'Diesel', 'Hydraulic', 2011, 2015),
    eng('Caterpillar', 'C9.3 ACERT Hybrid', 9.3, '6-Cyl Turbo', 308, 'Diesel-Electric Hybrid', 'Hydraulic Hybrid', 2013, 2015),
  ], ['0336E', '336EL', '336E L', '336E H']),
  mdl('336F', '300 Series Excavators', 'Heavy Equipment', EXC, 2015, 2019, se('Caterpillar', 'C9.3 ACERT', 9.3, '6-Cyl Turbo', 312), ['0336F', '336FL', '336F L']),
  mdl('336', 'Next Gen Excavators', 'Heavy Equipment', EXC, 2018, 2026, se('Caterpillar', 'C9.3B', 9.3, '6-Cyl Turbo', 311), ['0336', '336 GC']),
  mdl('345B L', '300 Series Excavators', 'Heavy Equipment', EXC, 1997, 2002, se('Caterpillar', '3176C', 10.3, '6-Cyl Turbo', 290), ['345BL', '345B']),
  mdl('345C L', '300 Series Excavators', 'Heavy Equipment', EXC, 2005, 2009, se('Caterpillar', 'C13 ACERT', 12.5, '6-Cyl Turbo', 345), ['345CL', '345C']),
  mdl('345D L', '300 Series Excavators', 'Heavy Equipment', EXC, 2009, 2012, se('Caterpillar', 'C13 ACERT', 12.5, '6-Cyl Turbo', 380), ['345DL', '345D']),
  mdl('349E', '300 Series Excavators', 'Heavy Equipment', EXC, 2011, 2015, se('Caterpillar', 'C13 ACERT', 12.5, '6-Cyl Turbo', 396), ['349EL', '349E L']),
  mdl('349F', '300 Series Excavators', 'Heavy Equipment', EXC, 2015, 2020, se('Caterpillar', 'C13 ACERT', 12.5, '6-Cyl Turbo', 417), ['349FL', '349F L']),
  mdl('349', 'Next Gen Excavators', 'Heavy Equipment', EXC, 2020, 2026, se('Caterpillar', 'C13', 12.5, '6-Cyl Turbo', 424), ['0349']),
  mdl('350L', '300 Series Excavators', 'Heavy Equipment', EXC, 1993, 1998, se('Caterpillar', '3306TA', 10.5, '6-Cyl Turbo', 286), ['350 L']),
  mdl('352F', '300 Series Excavators', 'Heavy Equipment', EXC, 2015, 2020, se('Caterpillar', 'C13 ACERT', 12.5, '6-Cyl Turbo', 417), ['352FL']),
  mdl('352', 'Next Gen Excavators', 'Heavy Equipment', EXC, 2020, 2026, se('Caterpillar', 'C13', 12.5, '6-Cyl Turbo', 443), ['0352', '352 UHD']),
  mdl('365B L', '300 Series Excavators', 'Heavy Equipment', EXC, 1999, 2005, se('Caterpillar', '3196', 12.0, '6-Cyl Turbo', 404), ['365BL']),
  mdl('365C L', '300 Series Excavators', 'Heavy Equipment', EXC, 2005, 2010, se('Caterpillar', 'C15 ACERT', 15.2, '6-Cyl Turbo', 404), ['365CL']),
  mdl('374D L', '300 Series Excavators', 'Heavy Equipment', EXC, 2010, 2014, se('Caterpillar', 'C15 ACERT', 15.2, '6-Cyl Turbo', 476), ['374DL']),
  mdl('374F L', '300 Series Excavators', 'Heavy Equipment', EXC, 2014, 2020, se('Caterpillar', 'C15 ACERT', 15.2, '6-Cyl Turbo', 472), ['374FL']),
  mdl('374', 'Next Gen Excavators', 'Heavy Equipment', EXC, 2020, 2026, se('Caterpillar', 'C15', 15.2, '6-Cyl Turbo', 484), ['0374']),
  mdl('385B', '300 Series Excavators', 'Heavy Equipment', EXC, 2001, 2005, se('Caterpillar', '3456', 15.8, '6-Cyl Turbo', 513), ['385BL']),
  mdl('385C', '300 Series Excavators', 'Heavy Equipment', EXC, 2005, 2011, se('Caterpillar', 'C18 ACERT', 18.1, '6-Cyl Turbo', 513), ['385CL']),
  mdl('390D L', '300 Series Excavators', 'Heavy Equipment', EXC, 2010, 2014, se('Caterpillar', 'C18 ACERT', 18.1, '6-Cyl Turbo', 523), ['390DL']),
  mdl('390F L', '300 Series Excavators', 'Heavy Equipment', EXC, 2014, 2020, se('Caterpillar', 'C18 ACERT', 18.1, '6-Cyl Turbo', 524), ['390FL']),
  mdl('395', 'Next Gen Excavators', 'Heavy Equipment', EXC, 2020, 2026, se('Caterpillar', 'C18', 18.1, '6-Cyl Turbo', 542), ['0395']),

  // Crawler Dozers (1970–2026)
  mdl('D3', 'Small Track-Type Tractors', 'Heavy Equipment', DOZ, 1973, 1979, se('Caterpillar', '3204', 5.2, '4-Cyl', 62, 'Diesel', 'Powershift')),
  mdl('D3B', 'Small Track-Type Tractors', 'Heavy Equipment', DOZ, 1979, 1988, se('Caterpillar', '3204', 5.2, '4-Cyl', 65, 'Diesel', 'Powershift')),
  mdl('D3C', 'Small Track-Type Tractors', 'Heavy Equipment', DOZ, 1988, 2002, se('Caterpillar', '3046', 5.0, '6-Cyl', 70, 'Diesel', 'Hydrostatic / Powershift'), ['D3C III']),
  mdl('D3G', 'Small Track-Type Tractors', 'Heavy Equipment', DOZ, 2002, 2007, se('Caterpillar', '3046T', 5.0, '6-Cyl Turbo', 70, 'Diesel', 'Hydrostatic')),
  mdl('D3K2', 'Small Track-Type Tractors', 'Heavy Equipment', DOZ, 2012, 2019, se('Caterpillar', 'C4.4 ACERT', 4.4, '4-Cyl Turbo', 80, 'Diesel', 'Hydrostatic')),
  mdl('D1', 'Next Gen Small Dozers', 'Heavy Equipment', DOZ, 2020, 2026, se('Caterpillar', 'C3.6', 3.6, '4-Cyl Turbo', 80, 'Diesel', 'Hydrostatic')),
  mdl('D4D', 'Small Track-Type Tractors', 'Heavy Equipment', DOZ, 1970, 1977, se('Caterpillar', '3304', 7.0, '4-Cyl', 75, 'Diesel', 'Direct Drive / Powershift')),
  mdl('D4E', 'Small Track-Type Tractors', 'Heavy Equipment', DOZ, 1977, 1987, se('Caterpillar', '3304', 7.0, '4-Cyl', 80, 'Diesel', 'Powershift')),
  mdl('D4H', 'Small Track-Type Tractors', 'Heavy Equipment', DOZ, 1985, 1997, se('Caterpillar', '3204T', 5.2, '4-Cyl Turbo', 95, 'Diesel', 'Powershift')),
  mdl('D4G', 'Small Track-Type Tractors', 'Heavy Equipment', DOZ, 2002, 2007, se('Caterpillar', '3046T', 5.0, '6-Cyl Turbo', 80, 'Diesel', 'Hydrostatic')),
  mdl('D4K2', 'Small Track-Type Tractors', 'Heavy Equipment', DOZ, 2012, 2019, se('Caterpillar', 'C4.4 ACERT', 4.4, '4-Cyl Turbo', 92, 'Diesel', 'Hydrostatic')),
  mdl('D2', 'Next Gen Small Dozers', 'Heavy Equipment', DOZ, 2020, 2026, se('Caterpillar', 'C3.6', 3.6, '4-Cyl Turbo', 92, 'Diesel', 'Hydrostatic')),
  mdl('D5B', 'Medium Track-Type Tractors', 'Heavy Equipment', DOZ, 1977, 1987, se('Caterpillar', '3306', 10.5, '6-Cyl', 105, 'Diesel', 'Powershift')),
  mdl('D5H', 'Medium Track-Type Tractors', 'Heavy Equipment', DOZ, 1985, 1996, se('Caterpillar', '3304T', 7.0, '4-Cyl Turbo', 120, 'Diesel', 'Powershift')),
  mdl('D5M', 'Medium Track-Type Tractors', 'Heavy Equipment', DOZ, 1996, 2002, se('Caterpillar', '3116T', 6.6, '6-Cyl Turbo', 110, 'Diesel', 'Powershift')),
  mdl('D5N', 'Medium Track-Type Tractors', 'Heavy Equipment', DOZ, 2002, 2007, se('Caterpillar', '3126B', 7.2, '6-Cyl Turbo', 115, 'Diesel', 'Powershift')),
  mdl('D5K2', 'Small Track-Type Tractors', 'Heavy Equipment', DOZ, 2012, 2019, se('Caterpillar', 'C4.4 ACERT', 4.4, '4-Cyl Turbo', 104, 'Diesel', 'Hydrostatic')),
  mdl('D5', 'Next Gen Medium Dozers', 'Heavy Equipment', DOZ, 2020, 2026, se('Caterpillar', 'C7.1', 7.0, '6-Cyl Turbo', 170, 'Diesel', '3-Speed Automatic Powershift')),
  mdl('D6C', 'D6 Track-Type Tractors', 'Heavy Equipment', DOZ, 1970, 1977, se('Caterpillar', 'D333C / 3306', 10.5, '6-Cyl Turbo', 140, 'Diesel', 'Powershift'), ['Cat D6C']),
  mdl('D6D', 'D6 Track-Type Tractors', 'Heavy Equipment', DOZ, 1977, 1996, se('Caterpillar', '3306T', 10.5, '6-Cyl Turbo', 140, 'Diesel', 'Powershift'), ['Cat D6D']),
  mdl('D6H', 'D6 Track-Type Tractors', 'Heavy Equipment', DOZ, 1985, 1996, se('Caterpillar', '3306T', 10.5, '6-Cyl Turbo', 165, 'Diesel', 'Differential Steer Powershift'), ['D6H XL', 'D6H LGP']),
  mdl('D6M', 'D6 Track-Type Tractors', 'Heavy Equipment', DOZ, 1996, 2002, se('Caterpillar', '3116TA', 6.6, '6-Cyl Turbo', 140, 'Diesel', 'Powershift'), ['D6M XL', 'D6M LGP']),
  mdl('D6N', 'D6 Track-Type Tractors', 'Heavy Equipment', DOZ, 2002, 2019, [
    eng('Caterpillar', '3126B / C6.6 ACERT', 6.6, '6-Cyl Turbo', 150, 'Diesel', 'Differential Steer Powershift', 2002, 2014),
    eng('Caterpillar', 'C7.1 ACERT', 7.0, '6-Cyl Twin-Turbo', 166, 'Diesel', 'Powershift', 2014, 2019),
  ], ['D6N XL', 'D6N LGP']),
  mdl('D6R', 'D6 Track-Type Tractors', 'Heavy Equipment', DOZ, 1996, 2012, [
    eng('Caterpillar', '3306TA', 10.5, '6-Cyl Turbo', 175, 'Diesel', 'Powershift', 1996, 2002),
    eng('Caterpillar', 'C9 ACERT', 8.8, '6-Cyl Turbo', 195, 'Diesel', 'Differential Steer Powershift', 2002, 2012),
  ], ['D6R XL', 'D6R LGP']),
  mdl('D6T', 'D6 Track-Type Tractors', 'Heavy Equipment', DOZ, 2006, 2019, [
    eng('Caterpillar', 'C9 ACERT', 8.8, '6-Cyl Turbo', 200, 'Diesel', 'Differential Steer Powershift', 2006, 2011),
    eng('Caterpillar', 'C9.3 ACERT', 9.3, '6-Cyl Turbo', 207, 'Diesel', '4-Speed AutoShift Powershift', 2011, 2019),
  ], ['D6T XL', 'D6T XW', 'D6T LGP']),
  mdl('D6', 'Next Gen Medium Dozers', 'Heavy Equipment', DOZ, 2019, 2026, [
    eng('Caterpillar', 'C9.3B', 9.3, '6-Cyl Turbo', 215, 'Diesel', '4-Speed Fully Automatic Powershift', 2019, 2026),
    eng('Caterpillar', 'C9.3B High-Drive Electric', 9.3, '6-Cyl Turbo', 215, 'Diesel-Electric Hybrid', 'Electric Drive', 2019, 2026),
  ], ['D6 Next Gen', 'D6 LGP']),
  mdl('D6 XE', 'Next Gen Electric Drive Dozers', 'Heavy Equipment', DOZ, 2019, 2026, se('Caterpillar', 'C9.3B', 9.3, '6-Cyl Turbo', 215, 'Diesel-Electric Hybrid', 'High-Drive Electric'), ['D6XE', 'D6 XE LGP']),
  mdl('D7F', 'D7 Track-Type Tractors', 'Heavy Equipment', DOZ, 1970, 1974, se('Caterpillar', '3306T', 10.5, '6-Cyl Turbo', 180, 'Diesel', 'Powershift')),
  mdl('D7G', 'D7 Track-Type Tractors', 'Heavy Equipment', DOZ, 1974, 1998, se('Caterpillar', '3306T', 10.5, '6-Cyl Turbo', 200, 'Diesel', 'Powershift')),
  mdl('D7H', 'D7 Track-Type Tractors', 'Heavy Equipment', DOZ, 1986, 1996, se('Caterpillar', '3306TA', 10.5, '6-Cyl Turbo', 215, 'Diesel', 'High-Drive Powershift')),
  mdl('D7R', 'D7 Track-Type Tractors', 'Heavy Equipment', DOZ, 1996, 2014, se('Caterpillar', '3176C / C9', 8.8, '6-Cyl Turbo', 240, 'Diesel', 'Powershift'), ['D7R II', 'D7R XR']),
  mdl('D7E', 'D7 Electric Drive Tractors', 'Heavy Equipment', DOZ, 2009, 2019, se('Caterpillar', 'C9.3 ACERT', 9.3, '6-Cyl Turbo', 235, 'Diesel-Electric Hybrid', 'AC Electric Drive')),
  mdl('D7', 'Next Gen Dozers', 'Heavy Equipment', DOZ, 2020, 2026, se('Caterpillar', 'C9.3B', 9.3, '6-Cyl Turbo', 265, 'Diesel', '4-Speed Fully Automatic Powershift')),
  mdl('D8H', 'D8 Large Track-Type Tractors', 'Heavy Equipment', DOZ, 1970, 1974, se('Caterpillar', 'D342T', 20.4, '6-Cyl Turbo', 270, 'Diesel', 'Torque Converter Powershift')),
  mdl('D8K', 'D8 Large Track-Type Tractors', 'Heavy Equipment', DOZ, 1974, 1982, se('Caterpillar', 'D342T', 20.4, '6-Cyl Turbo', 300, 'Diesel', 'Torque Converter Powershift'), ['Cat D8K']),
  mdl('D8L', 'D8 Large Track-Type Tractors', 'Heavy Equipment', DOZ, 1982, 1987, se('Caterpillar', '3408', 18.0, 'V8 Turbo', 335, 'Diesel', 'High-Drive Powershift')),
  mdl('D8N', 'D8 Large Track-Type Tractors', 'Heavy Equipment', DOZ, 1987, 1996, se('Caterpillar', '3406B', 14.6, '6-Cyl Turbo', 285, 'Diesel', 'Differential Steer Powershift')),
  mdl('D8R', 'D8 Large Track-Type Tractors', 'Heavy Equipment', DOZ, 1996, 2006, se('Caterpillar', '3406C / 3406E', 14.6, '6-Cyl Turbo', 305, 'Diesel', 'Differential Steer Powershift'), ['D8R Series II']),
  mdl('D8T', 'D8 Large Track-Type Tractors', 'Heavy Equipment', DOZ, 2004, 2020, [
    eng('Caterpillar', 'C15 ACERT', 15.2, '6-Cyl Turbo', 310, 'Diesel', 'Planetary Powershift', 2004, 2014),
    eng('Caterpillar', 'C15 ACERT Tier 4', 15.2, '6-Cyl Turbo', 354, 'Diesel', 'Planetary Powershift', 2014, 2020),
  ]),
  mdl('D8', 'Next Gen Large Dozers', 'Heavy Equipment', DOZ, 2020, 2026, se('Caterpillar', 'C15', 15.2, '6-Cyl Turbo', 363, 'Diesel', 'Planetary Powershift'), ['Cat D8']),
  mdl('D9G', 'D9 Large Track-Type Tractors', 'Heavy Equipment', DOZ, 1970, 1974, se('Caterpillar', 'D353E', 24.1, '6-Cyl Turbo', 385, 'Diesel', 'Torque Divider Powershift')),
  mdl('D9H', 'D9 Large Track-Type Tractors', 'Heavy Equipment', DOZ, 1974, 1980, se('Caterpillar', 'D353E', 24.1, '6-Cyl Turbo', 410, 'Diesel', 'Torque Divider Powershift')),
  mdl('D9L', 'D9 Large Track-Type Tractors', 'Heavy Equipment', DOZ, 1980, 1987, se('Caterpillar', '3412', 27.0, 'V12 Turbo', 460, 'Diesel', 'High-Drive Powershift')),
  mdl('D9N', 'D9 Large Track-Type Tractors', 'Heavy Equipment', DOZ, 1987, 1995, se('Caterpillar', '3408B', 18.0, 'V8 Turbo', 370, 'Diesel', 'Differential Steer Powershift')),
  mdl('D9R', 'D9 Large Track-Type Tractors', 'Heavy Equipment', DOZ, 1995, 2007, se('Caterpillar', '3408E', 18.0, 'V8 Turbo', 405, 'Diesel', 'Planetary Powershift')),
  mdl('D9T', 'D9 Large Track-Type Tractors', 'Heavy Equipment', DOZ, 2004, 2020, se('Caterpillar', 'C18 ACERT', 18.1, '6-Cyl Turbo', 436, 'Diesel', 'Planetary Powershift')),
  mdl('D9', 'Next Gen Large Dozers', 'Heavy Equipment', DOZ, 2020, 2026, se('Caterpillar', 'C18', 18.1, '6-Cyl Turbo', 452, 'Diesel', 'Stator Clutch Powershift')),
  mdl('D10N', 'D10 Mining Dozers', 'Heavy Equipment', DOZ, 1987, 1996, se('Caterpillar', '3412', 27.0, 'V12 Twin-Turbo', 520, 'Diesel', 'Planetary Powershift')),
  mdl('D10R', 'D10 Mining Dozers', 'Heavy Equipment', DOZ, 1996, 2005, se('Caterpillar', '3412E', 27.0, 'V12 Twin-Turbo', 570, 'Diesel', 'Planetary Powershift')),
  mdl('D10T', 'D10 Mining Dozers', 'Heavy Equipment', DOZ, 2005, 2014, se('Caterpillar', 'C27 ACERT', 27.0, 'V12 Twin-Turbo', 580, 'Diesel', 'Planetary Powershift')),
  mdl('D10T2', 'D10 Mining Dozers', 'Heavy Equipment', DOZ, 2014, 2023, se('Caterpillar', 'C27 ACERT', 27.0, 'V12 Twin-Turbo', 600, 'Diesel', 'Planetary Powershift')),
  mdl('D11N', 'D11 Mining Dozers', 'Heavy Equipment', DOZ, 1986, 1996, se('Caterpillar', '3508', 34.5, 'V8 Twin-Turbo', 770, 'Diesel', 'Planetary Powershift')),
  mdl('D11R', 'D11 Mining Dozers', 'Heavy Equipment', DOZ, 1996, 2008, se('Caterpillar', '3508B', 34.5, 'V8 Twin-Turbo', 850, 'Diesel', 'Planetary Powershift')),
  mdl('D11T', 'D11 Mining Dozers', 'Heavy Equipment', DOZ, 2008, 2020, se('Caterpillar', 'C32 ACERT', 32.1, 'V12 Twin-Turbo', 850, 'Diesel', 'Planetary Powershift')),
  mdl('D11', 'Next Gen Mining Dozers', 'Heavy Equipment', DOZ, 2020, 2026, se('Caterpillar', 'C32', 32.1, 'V12 Twin-Turbo', 850, 'Diesel', 'Planetary Powershift')),

  // Wheel Loaders (1970–2026)
  mdl('910', 'Compact Wheel Loaders', 'Heavy Equipment', LDR, 1973, 1988, se('Caterpillar', '3204', 5.2, '4-Cyl', 65, 'Diesel', 'Powershift')),
  mdl('914G', 'Compact Wheel Loaders', 'Heavy Equipment', LDR, 1995, 2012, se('Caterpillar', '3054T / C4.4', 4.4, '4-Cyl Turbo', 96, 'Diesel', 'Hydrostatic')),
  mdl('920', 'Small Wheel Loaders', 'Heavy Equipment', LDR, 1970, 1984, se('Caterpillar', '3304', 7.0, '4-Cyl', 80, 'Diesel', 'Powershift')),
  mdl('924G', 'Small Wheel Loaders', 'Heavy Equipment', LDR, 1999, 2007, se('Caterpillar', '3056E', 6.0, '6-Cyl Turbo', 129, 'Diesel', 'Powershift')),
  mdl('924K', 'Small Wheel Loaders', 'Heavy Equipment', LDR, 2012, 2019, se('Caterpillar', 'C6.6 / C7.1', 7.0, '6-Cyl Turbo', 141, 'Diesel', 'Hystat Hydrostatic')),
  mdl('926M', 'Small Wheel Loaders', 'Heavy Equipment', LDR, 2014, 2023, se('Caterpillar', 'C7.1 ACERT', 7.0, '6-Cyl Turbo', 153, 'Diesel', 'Hydrostatic')),
  mdl('930', 'Small Wheel Loaders', 'Heavy Equipment', LDR, 1970, 1984, se('Caterpillar', '3304', 7.0, '4-Cyl', 100, 'Diesel', 'Powershift')),
  mdl('930G', 'Small Wheel Loaders', 'Heavy Equipment', LDR, 2003, 2007, se('Caterpillar', '3056E', 6.0, '6-Cyl Turbo', 149, 'Diesel', 'Powershift')),
  mdl('930K', 'Small Wheel Loaders', 'Heavy Equipment', LDR, 2012, 2015, se('Caterpillar', 'C6.6 ACERT', 6.6, '6-Cyl Turbo', 160, 'Diesel', 'Hydrostatic')),
  mdl('930M', 'Small Wheel Loaders', 'Heavy Equipment', LDR, 2014, 2024, se('Caterpillar', 'C7.1 ACERT', 7.0, '6-Cyl Turbo', 164, 'Diesel', 'Hydrostatic')),
  mdl('936', 'Medium Wheel Loaders', 'Heavy Equipment', LDR, 1983, 1989, se('Caterpillar', '3304T', 7.0, '4-Cyl Turbo', 125, 'Diesel', 'Powershift')),
  mdl('938F', 'Medium Wheel Loaders', 'Heavy Equipment', LDR, 1993, 1998, se('Caterpillar', '3116T', 6.6, '6-Cyl Turbo', 140, 'Diesel', 'Powershift')),
  mdl('938G', 'Medium Wheel Loaders', 'Heavy Equipment', LDR, 1998, 2007, se('Caterpillar', '3126B', 7.2, '6-Cyl Turbo', 160, 'Diesel', 'Powershift')),
  mdl('938H', 'Medium Wheel Loaders', 'Heavy Equipment', LDR, 2007, 2012, se('Caterpillar', 'C6.6 ACERT', 6.6, '6-Cyl Turbo', 180, 'Diesel', 'Powershift')),
  mdl('938K', 'Medium Wheel Loaders', 'Heavy Equipment', LDR, 2012, 2015, se('Caterpillar', 'C7.1 ACERT', 7.0, '6-Cyl Turbo', 188, 'Diesel', 'Hydrostatic')),
  mdl('938M', 'Medium Wheel Loaders', 'Heavy Equipment', LDR, 2014, 2024, se('Caterpillar', 'C7.1 ACERT', 7.0, '6-Cyl Turbo', 188, 'Diesel', 'Hydrostatic')),
  mdl('950', '950 Medium Wheel Loaders', 'Heavy Equipment', LDR, 1970, 1981, se('Caterpillar', '3304T', 7.0, '4-Cyl Turbo', 130, 'Diesel', 'Powershift'), ['Cat 950A']),
  mdl('950B', '950 Medium Wheel Loaders', 'Heavy Equipment', LDR, 1981, 1987, se('Caterpillar', '3304T', 7.0, '4-Cyl Turbo', 155, 'Diesel', 'Powershift')),
  mdl('950E', '950 Medium Wheel Loaders', 'Heavy Equipment', LDR, 1987, 1991, se('Caterpillar', '3304T', 7.0, '4-Cyl Turbo', 160, 'Diesel', 'Powershift')),
  mdl('950F', '950 Medium Wheel Loaders', 'Heavy Equipment', LDR, 1991, 1998, se('Caterpillar', '3116TA', 6.6, '6-Cyl Turbo', 170, 'Diesel', 'Powershift'), ['950F II']),
  mdl('950G', '950 Medium Wheel Loaders', 'Heavy Equipment', LDR, 1998, 2006, se('Caterpillar', '3126B / C7', 7.2, '6-Cyl Turbo', 183, 'Diesel', 'Powershift'), ['950G II']),
  mdl('950H', '950 Medium Wheel Loaders', 'Heavy Equipment', LDR, 2005, 2013, se('Caterpillar', 'C7 ACERT', 7.2, '6-Cyl Turbo', 197, 'Diesel', 'Countershaft Powershift')),
  mdl('950K', '950 Medium Wheel Loaders', 'Heavy Equipment', LDR, 2011, 2015, se('Caterpillar', 'C7.1 ACERT', 7.0, '6-Cyl Twin-Turbo', 211, 'Diesel', 'Powershift')),
  mdl('950M', '950 Medium Wheel Loaders', 'Heavy Equipment', LDR, 2014, 2022, se('Caterpillar', 'C7.1 ACERT', 7.0, '6-Cyl Twin-Turbo', 230, 'Diesel', '5-Speed Powershift')),
  mdl('950 GC', '950 Medium Wheel Loaders', 'Heavy Equipment', LDR, 2015, 2026, se('Caterpillar', 'C7.1', 7.0, '6-Cyl Turbo', 225, 'Diesel', '4F/3R Countershaft Powershift'), ['950GC']),
  mdl('962H', 'Medium Wheel Loaders', 'Heavy Equipment', LDR, 2005, 2013, se('Caterpillar', 'C7 ACERT', 7.2, '6-Cyl Turbo', 211, 'Diesel', 'Powershift')),
  mdl('962M', 'Medium Wheel Loaders', 'Heavy Equipment', LDR, 2014, 2022, se('Caterpillar', 'C7.1 ACERT', 7.0, '6-Cyl Twin-Turbo', 250, 'Diesel', '5-Speed Powershift')),
  mdl('966C', '966 Medium Wheel Loaders', 'Heavy Equipment', LDR, 1970, 1980, se('Caterpillar', '3306T', 10.5, '6-Cyl Turbo', 170, 'Diesel', 'Planetary Powershift'), ['Cat 966C']),
  mdl('966D', '966 Medium Wheel Loaders', 'Heavy Equipment', LDR, 1980, 1987, se('Caterpillar', '3306T', 10.5, '6-Cyl Turbo', 200, 'Diesel', 'Planetary Powershift')),
  mdl('966E', '966 Medium Wheel Loaders', 'Heavy Equipment', LDR, 1987, 1991, se('Caterpillar', '3306TA', 10.5, '6-Cyl Turbo', 216, 'Diesel', 'Planetary Powershift')),
  mdl('966F', '966 Medium Wheel Loaders', 'Heavy Equipment', LDR, 1990, 1998, se('Caterpillar', '3306TA', 10.5, '6-Cyl Turbo', 220, 'Diesel', 'Planetary Powershift'), ['966F II']),
  mdl('966G', '966 Medium Wheel Loaders', 'Heavy Equipment', LDR, 1998, 2006, se('Caterpillar', '3306TA / C11', 11.1, '6-Cyl Turbo', 253, 'Diesel', 'Planetary Powershift'), ['966G II']),
  mdl('966H', '966 Medium Wheel Loaders', 'Heavy Equipment', LDR, 2005, 2013, se('Caterpillar', 'C11 ACERT', 11.1, '6-Cyl Turbo', 262, 'Diesel', 'Planetary Powershift')),
  mdl('966K', '966 Medium Wheel Loaders', 'Heavy Equipment', LDR, 2011, 2014, se('Caterpillar', 'C9.3 ACERT', 9.3, '6-Cyl Turbo', 267, 'Diesel', 'Planetary Powershift')),
  mdl('966M', '966 Medium Wheel Loaders', 'Heavy Equipment', LDR, 2014, 2021, [
    eng('Caterpillar', 'C9.3 ACERT', 9.3, '6-Cyl Turbo', 276, 'Diesel', '5-Speed Planetary Powershift', 2014, 2021),
    eng('Caterpillar', 'C9.3 ACERT XE', 9.3, '6-Cyl Turbo', 299, 'Diesel', 'Continuously Variable Split-Path CVT', 2014, 2021),
  ]),
  mdl('966', 'Next Gen Medium Wheel Loaders', 'Heavy Equipment', LDR, 2021, 2026, [
    eng('Caterpillar', 'C9.3B', 9.3, '6-Cyl Turbo', 321, 'Diesel', '5-Speed Planetary Powershift', 2021, 2026),
    eng('Caterpillar', 'C9.3B XE Powertrain', 9.3, '6-Cyl Turbo', 321, 'Diesel', 'Cat Continuously Variable CVT', 2021, 2026),
  ], ['Cat 966 Next Gen', '966 GC']),
  mdl('966 XE', 'Next Gen CVT Wheel Loaders', 'Heavy Equipment', LDR, 2021, 2026, se('Caterpillar', 'C9.3B', 9.3, '6-Cyl Turbo', 321, 'Diesel', 'Cat Continuously Variable CVT'), ['966XE']),
  mdl('972H', 'Medium Wheel Loaders', 'Heavy Equipment', LDR, 2005, 2013, se('Caterpillar', 'C13 ACERT', 12.5, '6-Cyl Turbo', 287, 'Diesel', 'Planetary Powershift')),
  mdl('972M', 'Medium Wheel Loaders', 'Heavy Equipment', LDR, 2014, 2021, se('Caterpillar', 'C9.3 ACERT', 9.3, '6-Cyl Turbo', 299, 'Diesel', 'Planetary Powershift')),
  mdl('980B', '980 Large Wheel Loaders', 'Heavy Equipment', LDR, 1970, 1977, se('Caterpillar', '3306T', 10.5, '6-Cyl Turbo', 260, 'Diesel', 'Planetary Powershift')),
  mdl('980C', '980 Large Wheel Loaders', 'Heavy Equipment', LDR, 1977, 1993, se('Caterpillar', '3406T', 14.6, '6-Cyl Turbo', 270, 'Diesel', 'Planetary Powershift')),
  mdl('980F', '980 Large Wheel Loaders', 'Heavy Equipment', LDR, 1991, 1996, se('Caterpillar', '3406TA', 14.6, '6-Cyl Turbo', 275, 'Diesel', 'Planetary Powershift')),
  mdl('980G', '980 Large Wheel Loaders', 'Heavy Equipment', LDR, 1996, 2006, se('Caterpillar', '3406C / C15', 14.6, '6-Cyl Turbo', 300, 'Diesel', 'Planetary Powershift'), ['980G II']),
  mdl('980H', '980 Large Wheel Loaders', 'Heavy Equipment', LDR, 2005, 2013, se('Caterpillar', 'C15 ACERT', 15.2, '6-Cyl Turbo', 349, 'Diesel', 'Planetary Powershift')),
  mdl('980K', '980 Large Wheel Loaders', 'Heavy Equipment', LDR, 2010, 2014, se('Caterpillar', 'C13 ACERT', 12.5, '6-Cyl Turbo', 369, 'Diesel', 'Planetary Powershift')),
  mdl('980M', '980 Large Wheel Loaders', 'Heavy Equipment', LDR, 2014, 2021, se('Caterpillar', 'C13 ACERT', 12.5, '6-Cyl Turbo', 386, 'Diesel', 'Planetary Powershift')),
  mdl('980', 'Next Gen Large Wheel Loaders', 'Heavy Equipment', LDR, 2021, 2026, se('Caterpillar', 'C13', 12.5, '6-Cyl Turbo', 420, 'Diesel', 'Planetary Powershift')),
  mdl('988B', '988 Large Wheel Loaders', 'Heavy Equipment', LDR, 1976, 1993, se('Caterpillar', '3408', 18.0, 'V8 Turbo', 375, 'Diesel', 'Planetary Powershift')),
  mdl('988F', '988 Large Wheel Loaders', 'Heavy Equipment', LDR, 1993, 2001, se('Caterpillar', '3408E', 18.0, 'V8 Turbo', 430, 'Diesel', 'Planetary Powershift')),
  mdl('988H', '988 Large Wheel Loaders', 'Heavy Equipment', LDR, 2004, 2013, se('Caterpillar', 'C18 ACERT', 18.1, '6-Cyl Turbo', 501, 'Diesel', 'Planetary Powershift')),
  mdl('988K', '988 Large Wheel Loaders', 'Heavy Equipment', LDR, 2013, 2023, se('Caterpillar', 'C18 ACERT', 18.1, '6-Cyl Turbo', 541, 'Diesel', 'Planetary Powershift')),
  mdl('992C', '992 Mining Wheel Loaders', 'Heavy Equipment', LDR, 1977, 1992, se('Caterpillar', '3412', 27.0, 'V12 Twin-Turbo', 690, 'Diesel', 'Planetary Powershift')),
  mdl('992G', '992 Mining Wheel Loaders', 'Heavy Equipment', LDR, 1996, 2007, se('Caterpillar', '3508B', 34.5, 'V8 Twin-Turbo', 800, 'Diesel', 'Planetary Powershift')),
  mdl('992K', '992 Mining Wheel Loaders', 'Heavy Equipment', LDR, 2007, 2021, se('Caterpillar', 'C32 ACERT', 32.1, 'V12 Twin-Turbo', 814, 'Diesel', 'Planetary Powershift')),
  mdl('992', 'Next Gen Mining Wheel Loaders', 'Heavy Equipment', LDR, 2021, 2026, se('Caterpillar', 'C32B', 32.1, 'V12 Twin-Turbo', 814, 'Diesel', 'Planetary Powershift')),

  // Backhoe Loaders (1985–2026)
  mdl('416 Series I', '400 Series Backhoe Loaders', 'Heavy Equipment', BKH, 1985, 1992, se('Perkins', '4.236', 3.9, '4-Cyl', 62, 'Diesel', '4-Speed Shuttle'), ['416A']),
  mdl('416B', '400 Series Backhoe Loaders', 'Heavy Equipment', BKH, 1992, 1996, se('Caterpillar', '3054', 4.0, '4-Cyl', 75, 'Diesel', '4-Speed Shuttle')),
  mdl('416C', '400 Series Backhoe Loaders', 'Heavy Equipment', BKH, 1996, 2001, se('Caterpillar', '3054T', 4.0, '4-Cyl Turbo', 80, 'Diesel', '4-Speed Shuttle')),
  mdl('416D', '400 Series Backhoe Loaders', 'Heavy Equipment', BKH, 2001, 2006, se('Caterpillar', '3054C', 4.4, '4-Cyl Turbo', 78, 'Diesel', '4-Speed Shuttle')),
  mdl('416E', '400 Series Backhoe Loaders', 'Heavy Equipment', BKH, 2006, 2012, se('Caterpillar', 'C4.4', 4.4, '4-Cyl Turbo', 89, 'Diesel', '4-Speed Shuttle')),
  mdl('416F', '400 Series Backhoe Loaders', 'Heavy Equipment', BKH, 2012, 2015, se('Caterpillar', 'C4.4 ACERT', 4.4, '4-Cyl Turbo', 87, 'Diesel', '4-Speed Shuttle')),
  mdl('416F2', '400 Series Backhoe Loaders', 'Heavy Equipment', BKH, 2015, 2020, se('Caterpillar', 'C4.4 ACERT', 4.4, '4-Cyl Turbo', 87, 'Diesel', '4-Speed Shuttle')),
  mdl('416', 'Next Gen Backhoe Loaders', 'Heavy Equipment', BKH, 2020, 2026, se('Caterpillar', 'C3.6', 3.6, '4-Cyl Turbo', 86, 'Diesel', '4-Speed Powershuttle')),
  mdl('420D', '400 Series Backhoe Loaders', 'Heavy Equipment', BKH, 2001, 2006, se('Caterpillar', '3054T', 4.0, '4-Cyl Turbo', 88, 'Diesel', '4-Speed Powershift')),
  mdl('420E', '400 Series Backhoe Loaders', 'Heavy Equipment', BKH, 2006, 2012, se('Caterpillar', 'C4.4 ACERT', 4.4, '4-Cyl Turbo', 93, 'Diesel', 'AutoShift Powershift')),
  mdl('420F', '400 Series Backhoe Loaders', 'Heavy Equipment', BKH, 2012, 2015, se('Caterpillar', 'C4.4 ACERT', 4.4, '4-Cyl Turbo', 94, 'Diesel', 'AutoShift Powershift')),
  mdl('420F2', '400 Series Backhoe Loaders', 'Heavy Equipment', BKH, 2015, 2020, se('Caterpillar', 'C4.4 ACERT', 4.4, '4-Cyl Turbo', 93, 'Diesel', '6-Speed AutoShift')),
  mdl('420', 'Next Gen Backhoe Loaders', 'Heavy Equipment', BKH, 2020, 2026, se('Caterpillar', 'C3.6', 3.6, '4-Cyl Turbo', 92, 'Diesel', '6-Speed AutoShift'), ['420 XE']),
  mdl('426C', '400 Series Backhoe Loaders', 'Heavy Equipment', BKH, 1996, 2000, se('Caterpillar', '3054T', 4.0, '4-Cyl Turbo', 85, 'Diesel', '4-Speed Powershift')),
  mdl('430E', '400 Series Backhoe Loaders', 'Heavy Equipment', BKH, 2006, 2012, se('Caterpillar', 'C4.4 ACERT', 4.4, '4-Cyl Turbo', 101, 'Diesel', 'AutoShift Powershift')),
  mdl('430F2', '400 Series Backhoe Loaders', 'Heavy Equipment', BKH, 2015, 2020, se('Caterpillar', 'C4.4 ACERT', 4.4, '4-Cyl Turbo', 108, 'Diesel', '6-Speed AutoShift')),
  mdl('430', 'Next Gen Backhoe Loaders', 'Heavy Equipment', BKH, 2020, 2026, se('Caterpillar', 'C3.6', 3.6, '4-Cyl Turbo', 107, 'Diesel', '6-Speed AutoShift')),
  mdl('446B', '400 Series Backhoe Loaders', 'Heavy Equipment', BKH, 1993, 2000, se('Caterpillar', '3114T', 4.4, '4-Cyl Turbo', 102, 'Diesel', 'Powershift')),

  // Skid Steers & Compact Track Loaders (1999–2026)
  mdl('216', '200 Series Skid Steers', 'Heavy Equipment', SSL, 1999, 2004, se('Caterpillar', '3034', 3.0, '4-Cyl', 49, 'Diesel', 'Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('226B', 'B-Series Skid Steers', 'Heavy Equipment', SSL, 2004, 2011, se('Caterpillar', '3024C / C2.2T', 2.2, '4-Cyl Turbo', 57, 'Diesel', 'Hydrostatic'), ['226B3'], SOURCE_EPA_OEM),
  mdl('226D3', 'D3-Series Skid Steers', 'Heavy Equipment', SSL, 2019, 2024, se('Caterpillar', 'C2.2 CRDI', 2.2, '4-Cyl Turbo', 67, 'Diesel', 'Hydrostatic'), ['226D'], SOURCE_EPA_OEM),
  mdl('236B', 'B-Series Skid Steers', 'Heavy Equipment', SSL, 2004, 2010, se('Caterpillar', '3044C', 3.3, '4-Cyl Turbo', 70, 'Diesel', 'Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('236D3', 'D3-Series Skid Steers', 'Heavy Equipment', SSL, 2019, 2024, se('Caterpillar', 'C3.3B DIT', 3.3, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), ['236D'], SOURCE_EPA_OEM),
  mdl('246C', 'C-Series Skid Steers', 'Heavy Equipment', SSL, 2007, 2013, se('Caterpillar', 'C3.4T', 3.3, '4-Cyl Turbo', 73, 'Diesel', '2-Speed Hydrostatic'), ['246B'], SOURCE_EPA_OEM),
  mdl('246D3', 'D3-Series Skid Steers', 'Heavy Equipment', SSL, 2019, 2024, se('Caterpillar', 'C3.3B DIT', 3.3, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), ['246D'], SOURCE_EPA_OEM),
  mdl('259B3', 'B3-Series Compact Track Loaders', 'Heavy Equipment', SSL, 2010, 2014, se('Caterpillar', 'C3.4 DIT', 3.3, '4-Cyl Turbo', 71, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('259D', 'D-Series Compact Track Loaders', 'Heavy Equipment', SSL, 2014, 2019, se('Caterpillar', 'C3.3B DIT', 3.3, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('259D3', 'D3-Series Compact Track Loaders', 'Heavy Equipment', SSL, 2019, 2024, se('Caterpillar', 'C3.3B DIT', 3.3, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('262D3', 'D3-Series Skid Steers', 'Heavy Equipment', SSL, 2019, 2024, se('Caterpillar', 'C3.3B DIT', 3.3, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), ['262C', '262D'], SOURCE_EPA_OEM),
  mdl('272D3', 'D3-Series Skid Steers', 'Heavy Equipment', SSL, 2019, 2024, se('Caterpillar', 'C3.8 DIT', 3.8, '4-Cyl Turbo', 98, 'Diesel', '2-Speed Hydrostatic'), ['272D2', '272D3 XE'], SOURCE_EPA_OEM),
  mdl('279D3', 'D3-Series Compact Track Loaders', 'Heavy Equipment', SSL, 2019, 2024, se('Caterpillar', 'C3.3B DIT', 3.3, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), ['279C', '279D'], SOURCE_EPA_OEM),
  mdl('289D3', 'D3-Series Compact Track Loaders', 'Heavy Equipment', SSL, 2019, 2024, se('Caterpillar', 'C3.3B DIT', 3.3, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), ['289C', '289D'], SOURCE_EPA_OEM),
  mdl('299D3', 'D3-Series Compact Track Loaders', 'Heavy Equipment', SSL, 2019, 2024, [
    eng('Caterpillar', 'C3.8 DIT', 3.8, '4-Cyl Turbo', 98, 'Diesel', '2-Speed Hydrostatic', 2019, 2024),
    eng('Caterpillar', 'C3.8 DIT XE High-Flow', 3.8, '4-Cyl Turbo', 110, 'Diesel', '2-Speed Hydrostatic', 2019, 2024),
  ], ['299C', '299D', '299D2 XHP', '299D3 XE'], SOURCE_EPA_OEM),
  mdl('255', 'Next Gen Compact Track Loaders', 'Heavy Equipment', SSL, 2024, 2026, se('Caterpillar', 'C2.8T', 2.8, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), ['Cat 255'], SOURCE_EPA_OEM),
  mdl('265', 'Next Gen Compact Track Loaders', 'Heavy Equipment', SSL, 2024, 2026, se('Caterpillar', 'C2.8TA', 2.8, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), ['Cat 265'], SOURCE_EPA_OEM),
  mdl('275', 'Next Gen Compact Track Loaders', 'Heavy Equipment', SSL, 2024, 2026, se('Caterpillar', 'C3.6TA', 3.6, '4-Cyl Turbo', 112, 'Diesel', '2-Speed Hydrostatic'), ['275 XE', '285'], SOURCE_EPA_OEM),

  // Motor Graders (1970–2026)
  mdl('12G', 'G-Series Motor Graders', 'Heavy Equipment', GRD, 1973, 1995, se('Caterpillar', '3306', 10.5, '6-Cyl', 135, 'Diesel', '6F/6R Direct Drive Powershift'), ['12F']),
  mdl('12H', 'H-Series Motor Graders', 'Heavy Equipment', GRD, 1995, 2008, se('Caterpillar', '3306TA / C9', 8.8, '6-Cyl Turbo', 145, 'Diesel', '8F/6R Direct Drive Powershift')),
  mdl('12M', 'M-Series Motor Graders', 'Heavy Equipment', GRD, 2008, 2019, se('Caterpillar', 'C6.6 / C7.1 ACERT', 7.0, '6-Cyl Turbo', 173, 'Diesel', '8F/6R Autoshift'), ['12M2', '12M3']),
  mdl('140G', 'G-Series Motor Graders', 'Heavy Equipment', GRD, 1974, 1995, se('Caterpillar', '3306T', 10.5, '6-Cyl Turbo', 150, 'Diesel', '6F/6R Direct Drive Powershift')),
  mdl('140H', 'H-Series Motor Graders', 'Heavy Equipment', GRD, 1995, 2008, se('Caterpillar', '3176C / C9', 8.8, '6-Cyl Turbo', 165, 'Diesel', '8F/6R Direct Drive Powershift')),
  mdl('140M', 'M-Series Motor Graders', 'Heavy Equipment', GRD, 2007, 2019, se('Caterpillar', 'C7 / C9.3 ACERT', 9.3, '6-Cyl Turbo', 183, 'Diesel', '8F/6R Autoshift AWD'), ['140M2', '140M3']),
  mdl('140', 'Next Gen Motor Graders', 'Heavy Equipment', GRD, 2019, 2026, se('Caterpillar', 'C9.3B', 9.3, '6-Cyl Turbo', 231, 'Diesel', '8F/6R Direct Drive Powershift'), ['140 AWD', '140 GC']),
  mdl('14G', 'G-Series Motor Graders', 'Heavy Equipment', GRD, 1973, 1995, se('Caterpillar', '3306T', 10.5, '6-Cyl Turbo', 180, 'Diesel', '8F/8R Powershift')),
  mdl('14H', 'H-Series Motor Graders', 'Heavy Equipment', GRD, 1995, 2007, se('Caterpillar', '3306TA / 3176C', 10.3, '6-Cyl Turbo', 220, 'Diesel', '8F/8R Powershift')),
  mdl('14M', 'M-Series Motor Graders', 'Heavy Equipment', GRD, 2007, 2020, se('Caterpillar', 'C11 / C13 ACERT', 12.5, '6-Cyl Turbo', 259, 'Diesel', '8F/6R Powershift'), ['14M3']),
  mdl('16G', 'G-Series Motor Graders', 'Heavy Equipment', GRD, 1973, 1995, se('Caterpillar', '3406T', 14.6, '6-Cyl Turbo', 250, 'Diesel', '8F/8R Powershift')),
  mdl('16M', 'M-Series Motor Graders', 'Heavy Equipment', GRD, 2007, 2019, se('Caterpillar', 'C13 ACERT', 12.5, '6-Cyl Turbo', 297, 'Diesel', '8F/6R Powershift'), ['16H', '16M3']),

  // Articulated Trucks (1995–2026)
  mdl('725', '700 Series Articulated Trucks', 'Transport & Hauling', ADT, 2001, 2026, [
    eng('Caterpillar', '3176C / C11 ACERT', 11.1, '6-Cyl Turbo', 309, 'Diesel', '6F/1R Planetary Powershift', 2001, 2014),
    eng('Caterpillar', 'C9.3 / C9.3B', 9.3, '6-Cyl Turbo', 342, 'Diesel', '6F/1R Automatic Powershift', 2014, 2026),
  ], ['725C', '725C2', 'D250E']),
  mdl('730', '700 Series Articulated Trucks', 'Transport & Hauling', ADT, 2001, 2026, [
    eng('Caterpillar', '3196 / C11 ACERT', 11.1, '6-Cyl Turbo', 325, 'Diesel', '6F/1R Planetary Powershift', 2001, 2014),
    eng('Caterpillar', 'C13 / C13B', 12.5, '6-Cyl Turbo', 367, 'Diesel', '6F/1R Automatic Powershift', 2014, 2026),
  ], ['730C', '730C2', '730 EJ', 'D300E']),
  mdl('735', '700 Series Articulated Trucks', 'Transport & Hauling', ADT, 2001, 2026, se('Caterpillar', 'C15', 15.2, '6-Cyl Turbo', 428, 'Diesel', '9F/2R Powershift'), ['735B', '735C']),
  mdl('740', '700 Series Articulated Trucks', 'Transport & Hauling', ADT, 2001, 2017, se('Caterpillar', '3406E / C15 ACERT', 15.2, '6-Cyl Turbo', 469, 'Diesel', '7F/2R Powershift'), ['740B', '740 EJ', 'D400E']),
  mdl('745', '700 Series Articulated Trucks', 'Transport & Hauling', ADT, 2015, 2026, se('Caterpillar', 'C18', 18.1, '6-Cyl Turbo', 504, 'Diesel', '9F/2R Automatic Powershift'), ['745C']),

  // Telehandlers & Compactors & Power Systems
  mdl('TH360B', 'TH Series Telehandlers', 'Heavy Equipment', TLH, 2002, 2008, se('Caterpillar', '3054E', 4.4, '4-Cyl Turbo', 99, 'Diesel', '4-Speed Powersyncro'), ['TH63', 'TH83'], SOURCE_EPA_OEM),
  mdl('TL642', 'TL Series Telehandlers', 'Heavy Equipment', TLH, 2007, 2026, se('Caterpillar', 'C3.6 / C4.4', 3.6, '4-Cyl Turbo', 100, 'Diesel', '4-Speed Powershift'), ['TL642D'], SOURCE_EPA_OEM),
  mdl('TL943', 'TL Series Telehandlers', 'Heavy Equipment', TLH, 2007, 2026, se('Caterpillar', 'C3.6 / C4.4', 4.4, '4-Cyl Turbo', 111, 'Diesel', '4-Speed Powershift'), ['TL943D'], SOURCE_EPA_OEM),
  mdl('TL1055', 'TL Series Telehandlers', 'Heavy Equipment', TLH, 2007, 2026, se('Caterpillar', 'C4.4 ACERT', 4.4, '4-Cyl Turbo', 134, 'Diesel', '4-Speed Powershift'), ['TL1055D', 'TL1255D'], SOURCE_EPA_OEM),
  mdl('CS56', 'Vibratory Soil Compactors', 'Heavy Equipment', CMP, 2007, 2013, se('Caterpillar', 'C6.6 ACERT', 6.6, '6-Cyl Turbo', 156, 'Diesel', 'Dual-Pump Hydrostatic'), ['CS-563E']),
  mdl('CS56B', 'Vibratory Soil Compactors', 'Heavy Equipment', CMP, 2012, 2026, se('Caterpillar', 'C4.4 / C7.1', 4.4, '4-Cyl Twin-Turbo', 157, 'Diesel', 'Dual-Pump Hydrostatic'), ['CS11 GC']),
  mdl('CP56', 'Padfoot Soil Compactors', 'Heavy Equipment', CMP, 2007, 2024, se('Caterpillar', 'C4.4 / C6.6 ACERT', 6.6, '6-Cyl Turbo', 156, 'Diesel', 'Dual-Pump Hydrostatic'), ['CP56B']),
  mdl('XQ125', 'XQ Rental Power Modules', 'Site Support', ['Generator'], 2010, 2026, se('Caterpillar', 'C4.4 ACERT', 4.4, '4-Cyl Turbo', 165, 'Diesel', '1800 RPM Synchronous Alternator'), ['XQ60', 'XQ230'], SOURCE_EPA_OEM),
  mdl('XQ400', 'XQ Rental Power Modules', 'Site Support', ['Generator'], 2008, 2026, se('Caterpillar', 'C13 / C15 ACERT', 12.5, '6-Cyl Turbo', 536, 'Diesel', '1800 RPM Synchronous Alternator'), ['XQ500'], SOURCE_EPA_OEM),
  mdl('G3516', '3500 Series Gas Compression & Power', 'Oil & Gas Equipment', ['Compressor', 'Generator'], 1988, 2026, se('Caterpillar', 'G3516 / G3516B', 69.0, 'V16 Lean-Burn', 1380, 'Natural Gas', 'Direct Compressor Coupling'), ['G3512', 'G3516B', 'G3606'], SOURCE_EPA_OEM),
  mdl('3512C Well Service', '3500 Series Petroleum Power', 'Oil & Gas Equipment', ['Pump', 'Generator'], 2007, 2026, se('Caterpillar', '3512C HD', 51.8, 'V12 Twin-Turbo', 2250, 'Diesel', 'Allison / Cat TH55 Powershift'), ['3512C'], SOURCE_EPA_OEM),
];

// ============================================================================
// 2. BOBCAT (1970–2026)
// ============================================================================
const BOBCAT_MODELS = [
  // Classic 600 / 700 / 800 / 900 Skid Steers (1970–2002)
  mdl('M-600', 'Classic M-Series Skid Steers', 'Heavy Equipment', SSL, 1970, 1975, se('Wisconsin', 'VF4D', 2.5, 'V4 Air-Cooled', 25, 'Gasoline', 'Variable Belt / Clutch Drive'), ['600'], SOURCE_EPA_OEM),
  mdl('M-610', 'Classic M-Series Skid Steers', 'Heavy Equipment', SSL, 1972, 1982, se('Wisconsin', 'VH4D', 1.8, 'V4 Air-Cooled', 30, 'Gasoline', 'Variable Speed Clutch Drive'), ['610'], SOURCE_EPA_OEM),
  mdl('720', '700 Series Skid Steers', 'Heavy Equipment', SSL, 1972, 1979, se('Wisconsin', 'VH4D', 1.8, 'V4', 30, 'Gasoline', 'Hydrostatic'), ['721'], SOURCE_EPA_OEM),
  mdl('722', '700 Series Skid Steers', 'Heavy Equipment', SSL, 1976, 1979, se('Ford', 'I4 Industrial', 1.6, '4-Cyl', 32, 'Gasoline', 'Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('730', '700 Series Skid Steers', 'Heavy Equipment', SSL, 1978, 1981, se('Wisconsin', 'VH4D', 1.8, 'V4', 30, 'Gasoline', 'Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('731', '700 Series Skid Steers', 'Heavy Equipment', SSL, 1978, 1981, se('Deutz', 'F2L511', 1.7, '2-Cyl Air-Cooled', 32, 'Diesel', 'Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('732', '700 Series Skid Steers', 'Heavy Equipment', SSL, 1978, 1981, se('Ford', '1.6L Kent', 1.6, '4-Cyl', 34, 'Gasoline', 'Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('741', '740 Series Skid Steers', 'Heavy Equipment', SSL, 1981, 1990, se('Deutz', 'F2L511', 1.7, '2-Cyl Air-Cooled', 32, 'Diesel', 'Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('742', '740 Series Skid Steers', 'Heavy Equipment', SSL, 1981, 1990, se('Ford / Mitsubishi', '4G54', 1.6, '4-Cyl', 34, 'Gasoline', 'Hydrostatic'), ['742B'], SOURCE_EPA_OEM),
  mdl('743', '740 Series Skid Steers', 'Heavy Equipment', SSL, 1981, 1990, se('Kubota', 'V1702-BA', 1.7, '4-Cyl', 36, 'Diesel', 'Hydrostatic'), ['743B', '743DS'], SOURCE_EPA_OEM),
  mdl('843', '800 Series Skid Steers', 'Heavy Equipment', SSL, 1981, 1992, [
    eng('Perkins', '4.154', 2.5, '4-Cyl', 54, 'Diesel', 'Hydrostatic', 1981, 1989),
    eng('Isuzu', '4JB1', 2.8, '4-Cyl', 54, 'Diesel', 'Hydrostatic', 1989, 1992),
  ], ['843B'], SOURCE_EPA_OEM),
  mdl('751', '50-Series Skid Steers', 'Heavy Equipment', SSL, 1995, 2000, se('Peugeot / Kubota', 'XUD9 / V1903', 1.9, '4-Cyl', 38, 'Diesel', 'Hydrostatic'), ['751G'], SOURCE_EPA_OEM),
  mdl('753', '50-Series Skid Steers', 'Heavy Equipment', SSL, 1990, 2002, se('Kubota', 'V2203-EB', 2.2, '4-Cyl', 43, 'Diesel', 'Hydrostatic'), ['753G', '753H'], SOURCE_EPA_OEM),
  mdl('763', '60-Series Skid Steers', 'Heavy Equipment', SSL, 1994, 2002, se('Kubota', 'V2203-EB', 2.2, '4-Cyl', 46, 'Diesel', 'Hydrostatic'), ['763G', '763H'], SOURCE_EPA_OEM),
  mdl('773', '70-Series Skid Steers', 'Heavy Equipment', SSL, 1994, 2002, [
    eng('Kubota', 'V2203-EB', 2.2, '4-Cyl', 46, 'Diesel', 'Hydrostatic', 1994, 1999),
    eng('Kubota', 'V2003-T', 2.0, '4-Cyl Turbo', 56, 'Diesel', 'Hydrostatic', 1999, 2002),
  ], ['773G', '773T'], SOURCE_EPA_OEM),
  mdl('853', '50-Series Skid Steers', 'Heavy Equipment', SSL, 1990, 1996, se('Isuzu', '4JB1', 2.8, '4-Cyl', 58, 'Diesel', 'Hydrostatic'), ['853H'], SOURCE_EPA_OEM),
  mdl('863', '60-Series Skid Steers', 'Heavy Equipment', SSL, 1997, 2002, se('Deutz', 'BF4M1011F', 2.7, '4-Cyl Turbo', 73, 'Diesel', 'Hydrostatic'), ['863G', '863H'], SOURCE_EPA_OEM),
  mdl('873', '70-Series Skid Steers', 'Heavy Equipment', SSL, 1995, 2002, se('Deutz', 'BF4M1011F', 2.7, '4-Cyl Turbo', 73, 'Diesel', 'Hydrostatic'), ['873G'], SOURCE_EPA_OEM),
  mdl('963', 'Large Frame Skid Steers', 'Heavy Equipment', SSL, 1997, 2003, se('Perkins', '1004.4T', 4.0, '4-Cyl Turbo', 105, 'Diesel', 'Hydrostatic'), ['963G'], SOURCE_EPA_OEM),
  mdl('864', 'Early Compact Track Loaders', 'Heavy Equipment', SSL, 1999, 2001, se('Deutz', 'BF4M1011F', 2.7, '4-Cyl Turbo', 73, 'Diesel', 'Hydrostatic'), ['864G'], SOURCE_EPA_OEM),
  mdl('T190', 'K-Series Compact Track Loaders', 'Heavy Equipment', SSL, 2001, 2010, se('Kubota', 'V2003-M-DI-T / V2607', 2.6, '4-Cyl Turbo', 61, 'Diesel', 'Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('T200', 'Early Compact Track Loaders', 'Heavy Equipment', SSL, 2001, 2003, se('Deutz', 'BF4M1011F', 2.7, '4-Cyl Turbo', 73, 'Diesel', 'Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('T250', 'K-Series Compact Track Loaders', 'Heavy Equipment', SSL, 2002, 2010, se('Kubota', 'V3300-DI-T', 3.3, '4-Cyl Turbo', 81, 'Diesel', 'Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('T300', 'K-Series Compact Track Loaders', 'Heavy Equipment', SSL, 2002, 2010, se('Kubota', 'V3300-DI-T / V3800', 3.3, '4-Cyl Turbo', 81, 'Diesel', 'Hydrostatic'), ['T320'], SOURCE_EPA_OEM),

  // S-Series Skid Steers (2001–2013)
  mdl('S130', 'K-Series Skid Steers', 'Heavy Equipment', SSL, 2004, 2013, se('Kubota', 'V2203-M-DI', 2.2, '4-Cyl', 49, 'Diesel', 'Hydrostatic'), ['S100'], SOURCE_EPA_OEM),
  mdl('S150', 'K-Series Skid Steers', 'Heavy Equipment', SSL, 2003, 2012, se('Kubota', 'V2203-M-DI', 2.2, '4-Cyl', 46, 'Diesel', 'Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('S160', 'K-Series Skid Steers', 'Heavy Equipment', SSL, 2004, 2013, se('Kubota', 'V2003-M-DI-T / V2607', 2.6, '4-Cyl Turbo', 61, 'Diesel', 'Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('S175', 'K-Series Skid Steers', 'Heavy Equipment', SSL, 2001, 2012, se('Kubota', 'V2203-M-DI', 2.2, '4-Cyl', 46, 'Diesel', 'Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('S185', 'K-Series Skid Steers', 'Heavy Equipment', SSL, 2001, 2012, se('Kubota', 'V2003-M-DI-T / V2607', 2.6, '4-Cyl Turbo', 56, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('S205', 'K-Series Skid Steers', 'Heavy Equipment', SSL, 2005, 2012, se('Kubota', 'V2607-DI-T', 2.6, '4-Cyl Turbo', 66, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('S220', 'K-Series Skid Steers', 'Heavy Equipment', SSL, 2003, 2010, se('Kubota', 'V3300-DI-T', 3.3, '4-Cyl Turbo', 75, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('S250', 'K-Series Skid Steers', 'Heavy Equipment', SSL, 2001, 2010, se('Kubota', 'V3300-DI-T', 3.3, '4-Cyl Turbo', 75, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('S300', 'K-Series Skid Steers', 'Heavy Equipment', SSL, 2002, 2010, se('Kubota', 'V3300-DI-T / V3800', 3.3, '4-Cyl Turbo', 81, 'Diesel', '2-Speed Hydrostatic'), ['S330'], SOURCE_EPA_OEM),

  // M-Series Skid Steers & CTLs (2010–2023)
  mdl('S450', 'M-Series Skid Steers', 'Heavy Equipment', SSL, 2014, 2026, se('Bobcat / Doosan', 'D18', 1.8, '3-Cyl Turbo', 49, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('S510', 'M-Series Skid Steers', 'Heavy Equipment', SSL, 2012, 2023, se('Bobcat / Kubota', 'V2203 / D24', 2.4, '4-Cyl', 49, 'Diesel', 'Hydrostatic'), ['S530'], SOURCE_EPA_OEM),
  mdl('S550', 'M-Series Skid Steers', 'Heavy Equipment', SSL, 2013, 2022, se('Bobcat', 'D24', 2.4, '4-Cyl Turbo', 61, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('S570', 'M-Series Skid Steers', 'Heavy Equipment', SSL, 2012, 2022, se('Bobcat', 'D24', 2.4, '4-Cyl Turbo', 61, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('S590', 'M-Series Skid Steers', 'Heavy Equipment', SSL, 2012, 2023, se('Bobcat', 'D24', 2.4, '4-Cyl Turbo', 66, 'Diesel', '2-Speed Hydrostatic'), ['S595'], SOURCE_EPA_OEM),
  mdl('S630', 'M-Series Skid Steers', 'Heavy Equipment', SSL, 2010, 2019, se('Kubota / Bobcat', 'V3307 / D34', 3.4, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('S650', 'M-Series Skid Steers', 'Heavy Equipment', SSL, 2010, 2023, [
    eng('Kubota', 'V3307-DI-TE3', 3.3, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic', 2010, 2014),
    eng('Bobcat', 'D24 / D34 Tier 4', 2.4, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic', 2014, 2023),
  ], [], SOURCE_EPA_OEM),
  mdl('S750', 'M-Series Skid Steers', 'Heavy Equipment', SSL, 2011, 2020, se('Kubota / Bobcat', 'V3800 / D34', 3.4, '4-Cyl Turbo', 85, 'Diesel', '2-Speed Hydrostatic'), ['S740'], SOURCE_EPA_OEM),
  mdl('S770', 'M-Series Skid Steers', 'Heavy Equipment', SSL, 2011, 2023, se('Kubota / Bobcat', 'V3800 / D34', 3.4, '4-Cyl Turbo', 92, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('S850', 'M-Series Skid Steers', 'Heavy Equipment', SSL, 2011, 2023, se('Kubota / Bobcat', 'V3800 / D34', 3.4, '4-Cyl Turbo', 100, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('T450', 'M-Series Compact Track Loaders', 'Heavy Equipment', SSL, 2014, 2024, se('Bobcat', 'D24', 2.4, '4-Cyl Turbo', 55, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('T550', 'M-Series Compact Track Loaders', 'Heavy Equipment', SSL, 2013, 2021, se('Bobcat', 'D24', 2.4, '4-Cyl Turbo', 66, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('T590', 'M-Series Compact Track Loaders', 'Heavy Equipment', SSL, 2012, 2022, se('Bobcat', 'D24', 2.4, '4-Cyl Turbo', 66, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('T595', 'M-Series Compact Track Loaders', 'Heavy Equipment', SSL, 2016, 2022, se('Bobcat', 'D24', 2.4, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('T630', 'M-Series Compact Track Loaders', 'Heavy Equipment', SSL, 2010, 2019, se('Kubota / Bobcat', 'V3307 / D34', 3.4, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('T650', 'M-Series Compact Track Loaders', 'Heavy Equipment', SSL, 2010, 2022, [
    eng('Kubota', 'V3307-DI-TE3', 3.3, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic', 2010, 2014),
    eng('Bobcat', 'D24 / D34 Tier 4', 2.4, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic', 2014, 2022),
  ], [], SOURCE_EPA_OEM),
  mdl('T750', 'M-Series Compact Track Loaders', 'Heavy Equipment', SSL, 2011, 2020, se('Kubota / Bobcat', 'V3800 / D34', 3.4, '4-Cyl Turbo', 85, 'Diesel', '2-Speed Hydrostatic'), ['T740'], SOURCE_EPA_OEM),
  mdl('T770', 'M-Series Compact Track Loaders', 'Heavy Equipment', SSL, 2011, 2023, [
    eng('Kubota', 'V3800-DI-TE3', 3.8, '4-Cyl Turbo', 92, 'Diesel', '2-Speed Hydrostatic', 2011, 2014),
    eng('Bobcat', 'D34 Tier 4', 3.4, '4-Cyl Turbo', 92, 'Diesel', '2-Speed Hydrostatic', 2014, 2023),
  ], [], SOURCE_EPA_OEM),
  mdl('T870', 'M-Series Compact Track Loaders', 'Heavy Equipment', SSL, 2011, 2023, se('Kubota / Bobcat', 'V3800 / D34', 3.4, '4-Cyl Turbo', 100, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),

  // R-Series Skid Steers & CTLs (2020–2026)
  mdl('S62', 'R-Series Skid Steers', 'Heavy Equipment', SSL, 2020, 2026, se('Bobcat', 'D24', 2.4, '4-Cyl Turbo', 68, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('S64', 'R-Series Skid Steers', 'Heavy Equipment', SSL, 2020, 2026, se('Bobcat', 'D24', 2.4, '4-Cyl Turbo', 68, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('S66', 'R-Series Skid Steers', 'Heavy Equipment', SSL, 2020, 2026, se('Bobcat', 'D24', 2.4, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('S76', 'R-Series Skid Steers', 'Heavy Equipment', SSL, 2020, 2026, se('Bobcat', 'D24', 2.4, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('S86', 'R-Series Skid Steers', 'Heavy Equipment', SSL, 2022, 2026, se('Bobcat', 'D34', 3.4, '4-Cyl Turbo', 105, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('T62', 'R-Series Compact Track Loaders', 'Heavy Equipment', SSL, 2020, 2026, se('Bobcat', 'D24', 2.4, '4-Cyl Turbo', 68, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('T64', 'R-Series Compact Track Loaders', 'Heavy Equipment', SSL, 2020, 2026, se('Bobcat', 'D24', 2.4, '4-Cyl Turbo', 68, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('T66', 'R-Series Compact Track Loaders', 'Heavy Equipment', SSL, 2020, 2026, se('Bobcat', 'D24', 2.4, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('T76', 'R-Series Compact Track Loaders', 'Heavy Equipment', SSL, 2020, 2026, se('Bobcat', 'D24', 2.4, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('T86', 'R-Series Compact Track Loaders', 'Heavy Equipment', SSL, 2022, 2026, se('Bobcat', 'D34', 3.4, '4-Cyl Turbo', 105, 'Diesel', '2-Speed Super-Flow Hydrostatic'), [], SOURCE_EPA_OEM),

  // Excavators (1992–2026)
  mdl('325', '300 Series Mini Excavators', 'Heavy Equipment', EXC, 1993, 2008, se('Kubota', 'D1703-EB', 1.7, '3-Cyl', 27), ['325D', '325G'], SOURCE_EPA_OEM),
  mdl('331', '300 Series Mini Excavators', 'Heavy Equipment', EXC, 1992, 2008, se('Kubota', 'V2203-EB', 2.2, '4-Cyl', 40), ['331D', '331E', '331G'], SOURCE_EPA_OEM),
  mdl('334', '300 Series Mini Excavators', 'Heavy Equipment', EXC, 2001, 2008, se('Kubota', 'V2203-M-DI', 2.2, '4-Cyl', 40), ['334D', '334G'], SOURCE_EPA_OEM),
  mdl('335', '300 Series Mini Excavators', 'Heavy Equipment', EXC, 2007, 2010, se('Kubota', 'V2003-M-DI-T', 2.0, '4-Cyl Turbo', 41), [], SOURCE_EPA_OEM),
  mdl('430', '400 Series ZHS Mini Excavators', 'Heavy Equipment', EXC, 2003, 2010, se('Kubota', 'V2203-M-DI', 2.2, '4-Cyl', 42), ['430D', '430G'], SOURCE_EPA_OEM),
  mdl('435', '400 Series ZHS Mini Excavators', 'Heavy Equipment', EXC, 2004, 2010, se('Kubota', 'V2003-M-DI-T', 2.0, '4-Cyl Turbo', 49), ['435G'], SOURCE_EPA_OEM),
  mdl('E20', 'E-Series Compact Excavators', 'Heavy Equipment', EXC, 2014, 2026, se('Kubota', 'D722', 0.7, '3-Cyl', 14), ['E10', 'E17'], SOURCE_EPA_OEM),
  mdl('E26', 'E-Series Compact Excavators', 'Heavy Equipment', EXC, 2010, 2026, se('Kubota / Bobcat', 'D1105', 1.1, '3-Cyl', 25), [], SOURCE_EPA_OEM),
  mdl('E32', 'E-Series Compact Excavators', 'Heavy Equipment', EXC, 2010, 2026, se('Kubota / Bobcat', 'D1803 / D18', 1.8, '3-Cyl', 25), [], SOURCE_EPA_OEM),
  mdl('E35', 'E-Series Compact Excavators', 'Heavy Equipment', EXC, 2010, 2026, [
    eng('Kubota', 'D1703-M-DI', 1.7, '3-Cyl', 25, 'Diesel', 'Hydraulic', 2010, 2018),
    eng('Bobcat', 'D18 / D18 Turbo', 1.8, '3-Cyl Turbo', 33, 'Diesel', 'Hydraulic', 2018, 2026),
  ], ['E35i', 'E35 R2-Series'], SOURCE_EPA_OEM),
  mdl('E42', 'R2-Series Compact Excavators', 'Heavy Equipment', EXC, 2019, 2026, se('Bobcat', 'D18', 1.8, '3-Cyl Turbo', 42), ['E45'], SOURCE_EPA_OEM),
  mdl('E50', 'E-Series Compact Excavators', 'Heavy Equipment', EXC, 2010, 2026, se('Kubota / Bobcat', 'V2403 / D18', 1.8, '3-Cyl Turbo', 50), [], SOURCE_EPA_OEM),
  mdl('E55', 'E-Series Compact Excavators', 'Heavy Equipment', EXC, 2011, 2024, se('Kubota / Bobcat', 'V2403 / D24', 2.4, '4-Cyl Turbo', 50), [], SOURCE_EPA_OEM),
  mdl('E60', 'R2-Series Compact Excavators', 'Heavy Equipment', EXC, 2020, 2026, se('Bobcat', 'D24', 2.4, '4-Cyl Turbo', 55), ['E63'], SOURCE_EPA_OEM),
  mdl('E85', 'M-Series Compact Excavators', 'Heavy Equipment', EXC, 2013, 2021, se('Yanmar / Bobcat', '4TNV98C / D34', 3.3, '4-Cyl Turbo', 66), [], SOURCE_EPA_OEM),
  mdl('E88', 'R2-Series Compact Excavators', 'Heavy Equipment', EXC, 2021, 2026, se('Bobcat', 'D24', 2.4, '4-Cyl Turbo', 65), [], SOURCE_EPA_OEM),

  // Telehandlers (2004–2026)
  mdl('V518', 'VersaHandler Telehandlers', 'Heavy Equipment', TLH, 2004, 2013, se('Perkins', '1104C-44T', 4.4, '4-Cyl Turbo', 100, 'Diesel', '2-Speed Hydrostatic'), ['V623'], SOURCE_EPA_OEM),
  mdl('V519', 'VersaHandler Telehandlers', 'Heavy Equipment', TLH, 2016, 2023, se('Bobcat', 'D34', 3.4, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('V723', 'VersaHandler Telehandlers', 'Heavy Equipment', TLH, 2006, 2022, se('Perkins / Bobcat', '1104D / D34', 3.4, '4-Cyl Turbo', 100, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('TL619', 'TL-Series Telehandlers', 'Heavy Equipment', TLH, 2021, 2026, se('Bobcat', 'D34', 3.4, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('TL723', 'TL-Series Telehandlers', 'Heavy Equipment', TLH, 2021, 2026, se('Bobcat', 'D34', 3.4, '4-Cyl Turbo', 100, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('TL923', 'TL-Series Telehandlers', 'Heavy Equipment', TLH, 2021, 2026, se('Bobcat', 'D34', 3.4, '4-Cyl Turbo', 130, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
];

// ============================================================================
// 3. JOHN DEERE (1970–2026)
// ============================================================================
const JOHN_DEERE_MODELS = [
  // Classic 690 / 490 / 790 & LC Excavators (1970–2005)
  mdl('690A', '690 Series Excavators', 'Heavy Equipment', EXC, 1970, 1973, se('John Deere', '6404D', 6.6, '6-Cyl', 131), ['JD690A']),
  mdl('690B', '690 Series Excavators', 'Heavy Equipment', EXC, 1973, 1984, se('John Deere', '6404T', 6.6, '6-Cyl Turbo', 131), ['JD690B']),
  mdl('690C', '690 Series Excavators', 'Heavy Equipment', EXC, 1984, 1987, se('John Deere', '6466T', 7.6, '6-Cyl Turbo', 125), ['JD690C']),
  mdl('690D', '690 Series Excavators', 'Heavy Equipment', EXC, 1987, 1991, se('John Deere', '6466T', 7.6, '6-Cyl Turbo', 125), ['JD690D']),
  mdl('690E', '690 Series Excavators', 'Heavy Equipment', EXC, 1991, 1998, se('John Deere', '6068T', 6.8, '6-Cyl Turbo', 137), ['690E LC']),
  mdl('490', '490 Series Excavators', 'Heavy Equipment', EXC, 1985, 1992, se('John Deere', '4239T', 3.9, '4-Cyl Turbo', 75), ['490D']),
  mdl('490E', '490 Series Excavators', 'Heavy Equipment', EXC, 1992, 1998, se('John Deere', '4045T', 4.5, '4-Cyl Turbo', 93)),
  mdl('790', '790 Series Excavators', 'Heavy Equipment', EXC, 1984, 1992, se('John Deere', '6466A', 7.6, '6-Cyl Turbo', 155), ['790D']),
  mdl('790E LC', '790 Series Excavators', 'Heavy Equipment', EXC, 1992, 1998, se('John Deere', '6076A', 7.6, '6-Cyl Turbo', 165), ['790E']),
  mdl('120', 'Dash / C / D Excavators', 'Heavy Equipment', EXC, 1999, 2006, se('John Deere', '4045T', 4.5, '4-Cyl Turbo', 90), ['120C', '120D']),
  mdl('160 LC', 'LC Series Excavators', 'Heavy Equipment', EXC, 1998, 2006, se('John Deere', '4045T', 4.5, '4-Cyl Turbo', 105), ['160C LC', '160D LC']),
  mdl('200 LC', 'LC Series Excavators', 'Heavy Equipment', EXC, 1998, 2012, [
    eng('John Deere', '6068T', 6.8, '6-Cyl Turbo', 140, 'Diesel', 'Hydraulic', 1998, 2006),
    eng('John Deere', '6068H PowerTech', 6.8, '6-Cyl Turbo', 159, 'Diesel', 'Hydraulic', 2006, 2012),
  ], ['200C LC', '200D LC']),
  mdl('230 LC', 'LC Series Excavators', 'Heavy Equipment', EXC, 1998, 2006, se('John Deere', '6068T', 6.8, '6-Cyl Turbo', 165), ['230C LC', '240D LC']),
  mdl('270 LC', 'LC Series Excavators', 'Heavy Equipment', EXC, 1998, 2012, se('John Deere', '6068H / 6081H', 6.8, '6-Cyl Turbo', 188), ['270C LC', '270D LC']),
  mdl('330 LC', 'LC Series Excavators', 'Heavy Equipment', EXC, 1998, 2012, se('John Deere', '6081H / Isuzu 6HK1', 8.1, '6-Cyl Turbo', 246), ['330C LC', '350D LC']),
  mdl('450 LC', 'LC Series Excavators', 'Heavy Equipment', EXC, 1998, 2012, se('John Deere', '6125H / Isuzu 6WG1', 12.5, '6-Cyl Turbo', 317), ['450C LC', '450D LC']),

  // D / G-Series & P-Tier Excavators (2008–2026)
  mdl('35D', 'Compact Excavators', 'Heavy Equipment', EXC, 2004, 2013, se('Yanmar', '3TNV88', 1.6, '3-Cyl', 27), [], SOURCE_EPA_OEM),
  mdl('35G', 'G-Series Compact Excavators', 'Heavy Equipment', EXC, 2013, 2022, se('Yanmar', '3TNV88F', 1.6, '3-Cyl', 23), [], SOURCE_EPA_OEM),
  mdl('50G', 'G-Series Compact Excavators', 'Heavy Equipment', EXC, 2013, 2022, se('Yanmar', '4TNV88C', 2.2, '4-Cyl', 36), ['50D'], SOURCE_EPA_OEM),
  mdl('75G', 'G-Series Mid-Size Excavators', 'Heavy Equipment', EXC, 2013, 2022, se('Yanmar', '4TNV98CT', 3.3, '4-Cyl Turbo', 57), ['75D'], SOURCE_EPA_OEM),
  mdl('85G', 'G-Series Mid-Size Excavators', 'Heavy Equipment', EXC, 2013, 2022, se('Yanmar', '4TNV98CT', 3.3, '4-Cyl Turbo', 57), ['85D'], SOURCE_EPA_OEM),
  mdl('135G', 'G-Series Excavators', 'Heavy Equipment', EXC, 2014, 2022, se('Isuzu', '4JJ1X', 3.0, '4-Cyl Turbo', 101), ['130G', '135D']),
  mdl('160G LC', 'G-Series Excavators', 'Heavy Equipment', EXC, 2014, 2022, se('John Deere', 'PowerTech PVS 4.5L', 4.5, '4-Cyl Turbo', 121), ['160GLC']),
  mdl('210G LC', 'G-Series Excavators', 'Heavy Equipment', EXC, 2012, 2022, se('John Deere', 'PowerTech PSS 6.8L', 6.8, '6-Cyl Turbo', 159), ['210GLC']),
  mdl('245G LC', 'G-Series Excavators', 'Heavy Equipment', EXC, 2016, 2022, se('Isuzu', '4HK1', 5.2, '4-Cyl Turbo', 159), ['245GLC']),
  mdl('300G LC', 'G-Series Excavators', 'Heavy Equipment', EXC, 2014, 2022, se('John Deere', 'PowerTech PSS 6.8L', 6.8, '6-Cyl Twin-Turbo', 223), ['290G LC', '300GLC']),
  mdl('350G LC', 'G-Series Excavators', 'Heavy Equipment', EXC, 2013, 2022, se('John Deere', 'PowerTech PSS 9.0L', 9.0, '6-Cyl Twin-Turbo', 271), ['350GLC']),
  mdl('470G LC', 'G-Series Excavators', 'Heavy Equipment', EXC, 2013, 2022, se('Isuzu', '6UZ1', 9.8, '6-Cyl Turbo', 367), ['470GLC']),
  mdl('35 P-Tier', 'P-Tier Compact Excavators', 'Heavy Equipment', EXC, 2022, 2026, se('Yanmar', '3TNV88F', 1.6, '3-Cyl', 23), ['35G P-Tier'], SOURCE_EPA_OEM),
  mdl('50 P-Tier', 'P-Tier Compact Excavators', 'Heavy Equipment', EXC, 2022, 2026, se('Yanmar', '4TNV88C', 2.2, '4-Cyl', 36), ['60 P-Tier'], SOURCE_EPA_OEM),
  mdl('85 P-Tier', 'P-Tier Mid-Size Excavators', 'Heavy Equipment', EXC, 2022, 2026, se('Yanmar', '4TNV98CT', 3.3, '4-Cyl Turbo', 57), ['75 P-Tier'], SOURCE_EPA_OEM),
  mdl('135 P-Tier', 'P-Tier Excavators', 'Heavy Equipment', EXC, 2022, 2026, se('Isuzu', '4JJ1', 3.0, '4-Cyl Turbo', 101), ['160 P-Tier'], SOURCE_EPA_OEM),
  mdl('210 P-Tier', 'P-Tier Excavators', 'Heavy Equipment', EXC, 2022, 2026, se('John Deere', 'PowerTech PVS 6.8L', 6.8, '6-Cyl Turbo', 159), ['210G P-Tier'], SOURCE_EPA_OEM),
  mdl('245 P-Tier', 'P-Tier Excavators', 'Heavy Equipment', EXC, 2022, 2026, se('John Deere', 'PowerTech 4.5L', 4.5, '4-Cyl Twin-Turbo', 159), ['300 P-Tier'], SOURCE_EPA_OEM),
  mdl('350 P-Tier', 'P-Tier Excavators', 'Heavy Equipment', EXC, 2022, 2026, se('John Deere', 'PowerTech PSS 9.0L', 9.0, '6-Cyl Twin-Turbo', 271), ['380 P-Tier'], SOURCE_EPA_OEM),
  mdl('470 P-Tier', 'P-Tier Excavators', 'Heavy Equipment', EXC, 2022, 2026, se('Isuzu', '6UZ1', 9.8, '6-Cyl Turbo', 367), [], SOURCE_EPA_OEM),

  // Backhoe Loaders (1971–2026)
  mdl('310A', '310 Series Backhoe Loaders', 'Heavy Equipment', BKH, 1971, 1983, se('John Deere', '3179D / 4219D', 3.6, '4-Cyl', 58, 'Diesel', 'Reverser Shuttle'), ['JD310']),
  mdl('310B', '310 Series Backhoe Loaders', 'Heavy Equipment', BKH, 1983, 1986, se('John Deere', '4219D', 3.6, '4-Cyl', 58, 'Diesel', 'Reverser Shuttle')),
  mdl('310C', '310 Series Backhoe Loaders', 'Heavy Equipment', BKH, 1986, 1991, se('John Deere', '4239D', 3.9, '4-Cyl', 67, 'Diesel', 'Reverser Shuttle')),
  mdl('310D', '310 Series Backhoe Loaders', 'Heavy Equipment', BKH, 1991, 1997, se('John Deere', '4039D / 4039T', 3.9, '4-Cyl Turbo', 75, 'Diesel', '4-Speed Shuttle')),
  mdl('310E', '310 Series Backhoe Loaders', 'Heavy Equipment', BKH, 1997, 2001, se('John Deere', '4045D / 4045T', 4.5, '4-Cyl Turbo', 80, 'Diesel', 'Powershuttle'), ['310SE']),
  mdl('310G', '310 Series Backhoe Loaders', 'Heavy Equipment', BKH, 2001, 2006, se('John Deere', '4045T', 4.5, '4-Cyl Turbo', 80, 'Diesel', 'Powershuttle'), ['310SG']),
  mdl('310J', '310 Series Backhoe Loaders', 'Heavy Equipment', BKH, 2006, 2012, se('John Deere', 'PowerTech 4045T', 4.5, '4-Cyl Turbo', 84, 'Diesel', 'Powershift'), ['310SJ']),
  mdl('310K', '310 Series Backhoe Loaders', 'Heavy Equipment', BKH, 2012, 2015, se('John Deere', 'PowerTech E 4.5L', 4.5, '4-Cyl Turbo', 89, 'Diesel', 'Powershift'), ['310SK']),
  mdl('310L', '310 Series Backhoe Loaders', 'Heavy Equipment', BKH, 2015, 2022, se('John Deere', 'PowerTech EWL 4.5L', 4.5, '4-Cyl Turbo', 93, 'Diesel', '5-Speed Powershift'), ['310SL', '310SL HL']),
  mdl('310 P-Tier', 'P-Tier Backhoe Loaders', 'Heavy Equipment', BKH, 2022, 2026, se('John Deere', 'PowerTech EWL 4.5L', 4.5, '4-Cyl Turbo', 100, 'Diesel', '5-Speed AutoShift'), ['310 G-Tier', '320 P-Tier']),
  mdl('410B', '410 Series Backhoe Loaders', 'Heavy Equipment', BKH, 1982, 1986, se('John Deere', '4219T / 4239D', 3.9, '4-Cyl', 62, 'Diesel', 'Reverser Shuttle'), ['JD410']),
  mdl('410C', '410 Series Backhoe Loaders', 'Heavy Equipment', BKH, 1986, 1991, se('John Deere', '4239T', 3.9, '4-Cyl Turbo', 75, 'Diesel', 'Reverser Shuttle')),
  mdl('410D', '410 Series Backhoe Loaders', 'Heavy Equipment', BKH, 1991, 1997, se('John Deere', '4039T', 3.9, '4-Cyl Turbo', 85, 'Diesel', 'Powershuttle')),
  mdl('410E', '410 Series Backhoe Loaders', 'Heavy Equipment', BKH, 1997, 2000, se('John Deere', '4045T', 4.5, '4-Cyl Turbo', 90, 'Diesel', 'Powershuttle')),
  mdl('410G', '410 Series Backhoe Loaders', 'Heavy Equipment', BKH, 2001, 2006, se('John Deere', '4045T', 4.5, '4-Cyl Turbo', 95, 'Diesel', 'Powershift')),
  mdl('410J', '410 Series Backhoe Loaders', 'Heavy Equipment', BKH, 2006, 2012, se('John Deere', 'PowerTech 4045H', 4.5, '4-Cyl Turbo', 99, 'Diesel', 'Powershift')),
  mdl('410K', '410 Series Backhoe Loaders', 'Heavy Equipment', BKH, 2012, 2015, se('John Deere', 'PowerTech PVX 4.5L', 4.5, '4-Cyl Turbo', 107, 'Diesel', '5-Speed Powershift')),
  mdl('410L', '410 Series Backhoe Loaders', 'Heavy Equipment', BKH, 2015, 2022, se('John Deere', 'PowerTech PVS 4.5L', 4.5, '4-Cyl Turbo', 113, 'Diesel', '5-Speed AutoShift')),
  mdl('410 P-Tier', 'P-Tier Backhoe Loaders', 'Heavy Equipment', BKH, 2022, 2026, se('John Deere', 'PowerTech PVS 4.5L', 4.5, '4-Cyl Turbo', 113, 'Diesel', '5-Speed AutoShift')),
  mdl('510B', '510 / 710 Heavy Backhoes', 'Heavy Equipment', BKH, 1983, 1996, se('John Deere', '4239T / 4045T', 4.5, '4-Cyl Turbo', 85, 'Diesel', 'Powershift'), ['510C', '510D']),
  mdl('710D', '710 Heavy Backhoe Loaders', 'Heavy Equipment', BKH, 1992, 2005, se('John Deere', '6068T', 6.8, '6-Cyl Turbo', 118, 'Diesel', 'Powershift'), ['710B', '710C', '710G']),
  mdl('710J', '710 Heavy Backhoe Loaders', 'Heavy Equipment', BKH, 2006, 2012, se('John Deere', 'PowerTech 6068H', 6.8, '6-Cyl Turbo', 126, 'Diesel', 'Powershift')),
  mdl('710K', '710 Heavy Backhoe Loaders', 'Heavy Equipment', BKH, 2012, 2017, se('John Deere', 'PowerTech PVX 6.8L', 6.8, '6-Cyl Turbo', 130, 'Diesel', 'Powershift')),
  mdl('710L', '710 Heavy Backhoe Loaders', 'Heavy Equipment', BKH, 2017, 2022, se('John Deere', 'PowerTech PSS 6.8L', 6.8, '6-Cyl Turbo', 148, 'Diesel', 'Powershift')),
  mdl('710 P-Tier', 'P-Tier Heavy Backhoe Loaders', 'Heavy Equipment', BKH, 2022, 2026, se('John Deere', 'PowerTech PSS 6.8L', 6.8, '6-Cyl Turbo', 148, 'Diesel', '5-Speed AutoShift')),

  // Crawler Dozers (1970–2026)
  mdl('450B', '450 Crawler Dozers', 'Heavy Equipment', DOZ, 1970, 1985, se('John Deere', '4219D / 4219T', 3.6, '4-Cyl', 65, 'Diesel', 'H-L-R Powershift'), ['450C', '450E']),
  mdl('450G', '450 Crawler Dozers', 'Heavy Equipment', DOZ, 1987, 2003, se('John Deere', '4045D / 4045T', 4.5, '4-Cyl Turbo', 70, 'Diesel', 'Powershift'), ['450H']),
  mdl('450J', '450 Crawler Dozers', 'Heavy Equipment', DOZ, 2004, 2015, se('John Deere', 'PowerTech 4.5L', 4.5, '4-Cyl Turbo', 77, 'Diesel', 'Dual-Path Hydrostatic')),
  mdl('450K', '450 Crawler Dozers', 'Heavy Equipment', DOZ, 2015, 2022, se('John Deere', 'PowerTech E 4.5L', 4.5, '4-Cyl Turbo', 80, 'Diesel', 'Dual-Path Hydrostatic')),
  mdl('450 P-Tier', 'P-Tier Small Dozers', 'Heavy Equipment', DOZ, 2022, 2026, se('John Deere', 'PowerTech E 4.5L', 4.5, '4-Cyl Turbo', 80, 'Diesel', 'Dual-Path Hydrostatic')),
  mdl('550G', '550 Crawler Dozers', 'Heavy Equipment', DOZ, 1976, 2003, se('John Deere', '4276T / 4045T', 4.5, '4-Cyl Turbo', 80, 'Diesel', 'Powershift'), ['550B', '550H']),
  mdl('550J', '550 Crawler Dozers', 'Heavy Equipment', DOZ, 2004, 2012, se('John Deere', 'PowerTech 4.5L', 4.5, '4-Cyl Turbo', 85, 'Diesel', 'Dual-Path Hydrostatic')),
  mdl('550K', '550 Crawler Dozers', 'Heavy Equipment', DOZ, 2012, 2022, se('John Deere', 'PowerTech PVX 4.5L', 4.5, '4-Cyl Turbo', 92, 'Diesel', 'Dual-Path Hydrostatic')),
  mdl('550 P-Tier', 'P-Tier Small Dozers', 'Heavy Equipment', DOZ, 2022, 2026, se('John Deere', 'PowerTech EWL 4.5L', 4.5, '4-Cyl Turbo', 92, 'Diesel', 'Dual-Path Hydrostatic')),
  mdl('650G', '650 Crawler Dozers', 'Heavy Equipment', DOZ, 1987, 2003, se('John Deere', '4045T', 4.5, '4-Cyl Turbo', 90, 'Diesel', 'Powershift'), ['650H']),
  mdl('650J', '650 Crawler Dozers', 'Heavy Equipment', DOZ, 2004, 2012, se('John Deere', 'PowerTech 4.5L', 4.5, '4-Cyl Turbo', 99, 'Diesel', 'Dual-Path Hydrostatic')),
  mdl('650K', '650 Crawler Dozers', 'Heavy Equipment', DOZ, 2012, 2022, se('John Deere', 'PowerTech PVX 4.5L', 4.5, '4-Cyl Turbo', 104, 'Diesel', 'Dual-Path Hydrostatic')),
  mdl('650 P-Tier', 'P-Tier Small Dozers', 'Heavy Equipment', DOZ, 2022, 2026, se('John Deere', 'PowerTech PVS 4.5L', 4.5, '4-Cyl Turbo', 104, 'Diesel', 'Dual-Path Hydrostatic')),
  mdl('700J', '700 Crawler Dozers', 'Heavy Equipment', DOZ, 2001, 2012, se('John Deere', '6068T', 6.8, '6-Cyl Turbo', 115, 'Diesel', 'Dual-Path Hydrostatic'), ['700H']),
  mdl('700K', '700 Crawler Dozers', 'Heavy Equipment', DOZ, 2012, 2020, se('John Deere', 'PowerTech PVX 6.8L', 6.8, '6-Cyl Turbo', 125, 'Diesel', 'Dual-Path Hydrostatic')),
  mdl('700L', '700 Crawler Dozers', 'Heavy Equipment', DOZ, 2020, 2026, se('John Deere', 'PowerTech PVS 6.8L', 6.8, '6-Cyl Turbo', 135, 'Diesel', 'Dual-Path Hydrostatic'), ['700 P-Tier']),
  mdl('750B', '750 Crawler Dozers', 'Heavy Equipment', DOZ, 1976, 1999, se('John Deere', '6414T / 6068T', 6.8, '6-Cyl Turbo', 120, 'Diesel', 'Dual-Path Hydrostatic'), ['JD750', '750C']),
  mdl('750J', '750 Crawler Dozers', 'Heavy Equipment', DOZ, 2004, 2012, se('John Deere', '6068H', 6.8, '6-Cyl Turbo', 145, 'Diesel', 'Dual-Path Hydrostatic')),
  mdl('750K', '750 Crawler Dozers', 'Heavy Equipment', DOZ, 2012, 2020, se('John Deere', 'PowerTech PSS 6.8L', 6.8, '6-Cyl Twin-Turbo', 165, 'Diesel', 'Dual-Path Hydrostatic')),
  mdl('750L', '750 Crawler Dozers', 'Heavy Equipment', DOZ, 2020, 2026, se('John Deere', 'PowerTech PSS 6.8L', 6.8, '6-Cyl Twin-Turbo', 175, 'Diesel', 'Dual-Path Hydrostatic'), ['750 P-Tier']),
  mdl('850B', '850 Crawler Dozers', 'Heavy Equipment', DOZ, 1977, 2004, se('John Deere', '6466A / 6076A', 7.6, '6-Cyl Turbo', 165, 'Diesel', 'Dual-Path Hydrostatic'), ['JD850', '850C']),
  mdl('850J', '850 Crawler Dozers', 'Heavy Equipment', DOZ, 2004, 2012, se('John Deere', 'PowerTech 6090H', 9.0, '6-Cyl Turbo', 185, 'Diesel', 'Dual-Path Hydrostatic')),
  mdl('850K', '850 Crawler Dozers', 'Heavy Equipment', DOZ, 2012, 2020, se('John Deere', 'PowerTech PSX 9.0L', 9.0, '6-Cyl Twin-Turbo', 205, 'Diesel', 'Dual-Path Hydrostatic'), ['850K LGP', '850K WLT']),
  mdl('850L', '850 Crawler Dozers', 'Heavy Equipment', DOZ, 2020, 2026, se('John Deere', 'PowerTech PSS 9.0L', 9.0, '6-Cyl Twin-Turbo', 225, 'Diesel', 'Dual-Path Hydrostatic'), ['850 P-Tier']),
  mdl('950J', 'Large Crawler Dozers', 'Heavy Equipment', DOZ, 2005, 2014, se('John Deere / Liebherr', 'D936L', 10.5, '6-Cyl Turbo', 247, 'Diesel', 'Dual-Path Hydrostatic')),
  mdl('950K', 'Large Crawler Dozers', 'Heavy Equipment', DOZ, 2014, 2022, se('John Deere', 'PowerTech PSS 9.0L', 9.0, '6-Cyl Twin-Turbo', 265, 'Diesel', 'Dual-Path Hydrostatic')),
  mdl('950 P-Tier', 'P-Tier Large Dozers', 'Heavy Equipment', DOZ, 2022, 2026, se('John Deere', 'PowerTech PSS 9.0L', 9.0, '6-Cyl Twin-Turbo', 265, 'Diesel', 'Dual-Path Hydrostatic')),
  mdl('1050J', 'Large Crawler Dozers', 'Heavy Equipment', DOZ, 2005, 2014, se('John Deere / Liebherr', 'D946L', 12.0, '6-Cyl Turbo', 335, 'Diesel', 'Dual-Path Hydrostatic')),
  mdl('1050K', 'Large Crawler Dozers', 'Heavy Equipment', DOZ, 2014, 2022, se('John Deere', 'PowerTech PSS 13.5L', 13.5, '6-Cyl Turbo', 350, 'Diesel', 'Dual-Path Hydrostatic')),
  mdl('1050 P-Tier', 'P-Tier Large Dozers', 'Heavy Equipment', DOZ, 2022, 2026, se('John Deere', 'JD14 13.6L', 13.6, '6-Cyl Turbo', 350, 'Diesel', 'Dual-Path Hydrostatic')),

  // Wheel Loaders (1970–2026)
  mdl('444E', '444 Classic Wheel Loaders', 'Heavy Equipment', LDR, 1987, 1997, se('John Deere', '4276T / 4045T', 4.5, '4-Cyl Turbo', 95, 'Diesel', 'Powershift'), ['JD444', '444G']),
  mdl('444H', '444 Wheel Loaders', 'Heavy Equipment', LDR, 1997, 2003, se('John Deere', '4045T', 4.5, '4-Cyl Turbo', 110, 'Diesel', '4-Speed Powershift')),
  mdl('444J', '444 Wheel Loaders', 'Heavy Equipment', LDR, 2003, 2008, se('John Deere', 'PowerTech 4045H', 4.5, '4-Cyl Turbo', 115, 'Diesel', '4-Speed Powershift')),
  mdl('444K', '444 Wheel Loaders', 'Heavy Equipment', LDR, 2008, 2018, se('John Deere', 'PowerTech E 4.5L', 4.5, '4-Cyl Turbo', 124, 'Diesel', '4-Speed Powershift')),
  mdl('444L', '444 Wheel Loaders', 'Heavy Equipment', LDR, 2018, 2021, se('John Deere', 'PowerTech PVS 4.5L', 4.5, '4-Cyl Turbo', 124, 'Diesel', '4-Speed Powershift')),
  mdl('444 P-Tier', 'P-Tier Wheel Loaders', 'Heavy Equipment', LDR, 2021, 2026, se('John Deere', 'PowerTech EWL 4.5L', 4.5, '4-Cyl Turbo', 124, 'Diesel', '4-Speed Powershift'), ['444 G-Tier']),
  mdl('544B', '544 Classic Wheel Loaders', 'Heavy Equipment', LDR, 1970, 1987, se('John Deere', '6414T', 6.8, '6-Cyl Turbo', 115, 'Diesel', 'Powershift'), ['544A', '544C', '544D']),
  mdl('544E', '544 Wheel Loaders', 'Heavy Equipment', LDR, 1988, 1993, se('John Deere', '6359T', 5.9, '6-Cyl Turbo', 115, 'Diesel', '4-Speed Powershift')),
  mdl('544G', '544 Wheel Loaders', 'Heavy Equipment', LDR, 1993, 1997, se('John Deere', '6059T', 5.9, '6-Cyl Turbo', 130, 'Diesel', '4-Speed Powershift')),
  mdl('544H', '544 Wheel Loaders', 'Heavy Equipment', LDR, 1997, 2003, se('John Deere', '6068T', 6.8, '6-Cyl Turbo', 130, 'Diesel', '4-Speed Powershift')),
  mdl('544J', '544 Wheel Loaders', 'Heavy Equipment', LDR, 2003, 2008, se('John Deere', 'PowerTech 6068H', 6.8, '6-Cyl Turbo', 149, 'Diesel', '4-Speed Powershift')),
  mdl('544K', '544 Wheel Loaders', 'Heavy Equipment', LDR, 2008, 2018, se('John Deere', 'PowerTech PVX 6.8L', 6.8, '6-Cyl Turbo', 163, 'Diesel', '5-Speed Powershift'), ['544K-II']),
  mdl('544L', '544 Wheel Loaders', 'Heavy Equipment', LDR, 2018, 2021, se('John Deere', 'PowerTech PVS 6.8L', 6.8, '6-Cyl Turbo', 166, 'Diesel', '5-Speed Powershift')),
  mdl('544 P-Tier', 'P-Tier Wheel Loaders', 'Heavy Equipment', LDR, 2021, 2026, se('John Deere', 'PowerTech PVS 6.8L', 6.8, '6-Cyl Turbo', 166, 'Diesel', '5-Speed Torque-Converter Powershift'), ['544 G-Tier']),
  mdl('624E', '624 Wheel Loaders', 'Heavy Equipment', LDR, 1988, 1993, se('John Deere', '6414T', 6.8, '6-Cyl Turbo', 135, 'Diesel', '4-Speed Powershift')),
  mdl('624G', '624 Wheel Loaders', 'Heavy Equipment', LDR, 1993, 1997, se('John Deere', '6068T', 6.8, '6-Cyl Turbo', 145, 'Diesel', '4-Speed Powershift')),
  mdl('624H', '624 Wheel Loaders', 'Heavy Equipment', LDR, 1997, 2003, se('John Deere', '6068T', 6.8, '6-Cyl Turbo', 160, 'Diesel', '4-Speed Powershift')),
  mdl('624J', '624 Wheel Loaders', 'Heavy Equipment', LDR, 2003, 2008, se('John Deere', 'PowerTech 6068H', 6.8, '6-Cyl Turbo', 170, 'Diesel', '4-Speed Powershift')),
  mdl('624K', '624 Wheel Loaders', 'Heavy Equipment', LDR, 2008, 2018, se('John Deere', 'PowerTech PVX 6.8L', 6.8, '6-Cyl Turbo', 186, 'Diesel', '5-Speed Powershift'), ['624K-II']),
  mdl('624L', '624 Wheel Loaders', 'Heavy Equipment', LDR, 2018, 2021, se('John Deere', 'PowerTech PVS 6.8L', 6.8, '6-Cyl Turbo', 192, 'Diesel', '5-Speed Powershift')),
  mdl('624 P-Tier', 'P-Tier Wheel Loaders', 'Heavy Equipment', LDR, 2021, 2026, se('John Deere', 'PowerTech PVS 6.8L', 6.8, '6-Cyl Turbo', 192, 'Diesel', '5-Speed Powershift')),
  mdl('644B', '644 Classic Wheel Loaders', 'Heavy Equipment', LDR, 1970, 1987, se('John Deere', '6531A / 6466T', 7.6, '6-Cyl Turbo', 152, 'Diesel', 'Powershift'), ['644A', '644C', '644D']),
  mdl('644E', '644 Wheel Loaders', 'Heavy Equipment', LDR, 1988, 1993, se('John Deere', '6466A', 7.6, '6-Cyl Turbo', 160, 'Diesel', '4-Speed Powershift')),
  mdl('644G', '644 Wheel Loaders', 'Heavy Equipment', LDR, 1993, 1997, se('John Deere', '6076A', 7.6, '6-Cyl Turbo', 175, 'Diesel', '4-Speed Powershift')),
  mdl('644H', '644 Wheel Loaders', 'Heavy Equipment', LDR, 1997, 2003, se('John Deere', '6081A', 8.1, '6-Cyl Turbo', 185, 'Diesel', '4-Speed Powershift')),
  mdl('644J', '644 Wheel Loaders', 'Heavy Equipment', LDR, 2003, 2008, se('John Deere', 'PowerTech 6081H', 8.1, '6-Cyl Turbo', 225, 'Diesel', '4-Speed Powershift')),
  mdl('644K', '644 Wheel Loaders', 'Heavy Equipment', LDR, 2008, 2018, [
    eng('John Deere', 'PowerTech PSX 6.8L / 9.0L', 6.8, '6-Cyl Twin-Turbo', 232, 'Diesel', '5-Speed Lockup Powershift', 2008, 2018),
    eng('John Deere', 'PowerTech 6.8L Hybrid', 6.8, '6-Cyl Twin-Turbo', 231, 'Diesel-Electric Hybrid', 'E-Drive Electric', 2013, 2018),
  ], ['644K Hybrid']),
  mdl('644L', '644 Wheel Loaders', 'Heavy Equipment', LDR, 2018, 2021, [
    eng('John Deere', 'PowerTech PSS 6.8L', 6.8, '6-Cyl Twin-Turbo', 249, 'Diesel', '5-Speed Lockup Powershift', 2018, 2021),
    eng('John Deere', 'PowerTech 6.8L Hybrid', 6.8, '6-Cyl Twin-Turbo', 231, 'Diesel-Electric Hybrid', 'E-Drive Electric', 2018, 2021),
  ], ['644LH']),
  mdl('644 P-Tier', 'P-Tier Wheel Loaders', 'Heavy Equipment', LDR, 2021, 2026, [
    eng('John Deere', 'PowerTech PSS 6.8L', 6.8, '6-Cyl Twin-Turbo', 249, 'Diesel', '5-Speed Lockup Powershift', 2021, 2026),
    eng('John Deere', 'PowerTech 6.8L X-Tier E-Drive', 6.8, '6-Cyl Twin-Turbo', 231, 'Diesel-Electric Hybrid', 'E-Drive Electric', 2021, 2026),
  ], ['644 X-Tier']),
  mdl('744H', '744 Large Wheel Loaders', 'Heavy Equipment', LDR, 1998, 2004, se('John Deere', '6125A', 12.5, '6-Cyl Turbo', 265, 'Diesel', '4-Speed Powershift')),
  mdl('744J', '744 Large Wheel Loaders', 'Heavy Equipment', LDR, 2004, 2008, se('John Deere', 'PowerTech 6125H', 12.5, '6-Cyl Turbo', 295, 'Diesel', '4-Speed Powershift')),
  mdl('744K', '744 Large Wheel Loaders', 'Heavy Equipment', LDR, 2008, 2018, se('John Deere', 'PowerTech PSX 13.5L', 13.5, '6-Cyl Turbo', 304, 'Diesel', '5-Speed Powershift'), ['744K-II']),
  mdl('744L', '744 Large Wheel Loaders', 'Heavy Equipment', LDR, 2018, 2022, se('John Deere', 'PowerTech PSS 13.5L', 13.5, '6-Cyl Turbo', 316, 'Diesel', '5-Speed Lockup Powershift')),
  mdl('744 P-Tier', 'P-Tier Large Wheel Loaders', 'Heavy Equipment', LDR, 2022, 2026, se('John Deere', 'PowerTech PSS 13.5L', 13.5, '6-Cyl Turbo', 316, 'Diesel', '5-Speed Lockup Powershift')),
  mdl('844J', '844 Large Wheel Loaders', 'Heavy Equipment', LDR, 2004, 2009, se('John Deere', 'PowerTech 6125H / 6135H', 13.5, '6-Cyl Turbo', 380, 'Diesel', '4-Speed Powershift')),
  mdl('844K', '844 Large Wheel Loaders', 'Heavy Equipment', LDR, 2009, 2018, se('John Deere', 'PowerTech PSX 13.5L', 13.5, '6-Cyl Turbo', 380, 'Diesel', '5-Speed Powershift'), ['844K-II', '844K-III']),
  mdl('844L', '844 Large Wheel Loaders', 'Heavy Equipment', LDR, 2018, 2022, se('John Deere', 'PowerTech PSS 13.5L', 13.5, '6-Cyl Turbo', 417, 'Diesel', '5-Speed Powershift')),
  mdl('844 P-Tier', 'P-Tier Large Wheel Loaders', 'Heavy Equipment', LDR, 2022, 2026, se('John Deere', 'JD14 13.6L', 13.6, '6-Cyl Turbo', 417, 'Diesel', '5-Speed Lockup Powershift')),

  // Skid Steers & Compact Track Loaders (1998–2026)
  mdl('250', '200 Series Skid Steers', 'Heavy Equipment', SSL, 1998, 2004, se('John Deere', '3029T', 2.9, '3-Cyl Turbo', 61, 'Diesel', 'Hydrostatic'), ['240', '260', '270'], SOURCE_EPA_OEM),
  mdl('317', '300 Series Skid Steers', 'Heavy Equipment', SSL, 2004, 2010, se('John Deere', '4024T', 2.4, '4-Cyl Turbo', 61, 'Diesel', 'Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('320', '300 Series Skid Steers', 'Heavy Equipment', SSL, 2004, 2010, se('John Deere', '4024T', 2.4, '4-Cyl Turbo', 66, 'Diesel', 'Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('325', '300 Series Skid Steers', 'Heavy Equipment', SSL, 2004, 2010, se('John Deere', '5030T', 3.0, '5-Cyl Turbo', 76, 'Diesel', '2-Speed Hydrostatic'), ['332'], SOURCE_EPA_OEM),
  mdl('318D', 'D-Series Skid Steers', 'Heavy Equipment', SSL, 2010, 2014, se('John Deere', '4024HT', 2.4, '4-Cyl Turbo', 63, 'Diesel', '2-Speed Hydrostatic'), ['320D'], SOURCE_EPA_OEM),
  mdl('326D', 'D-Series Skid Steers', 'Heavy Equipment', SSL, 2010, 2014, se('John Deere', '5030HT', 3.0, '5-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), ['332D', '329D', '333D'], SOURCE_EPA_OEM),
  mdl('318E', 'E-Series Skid Steers', 'Heavy Equipment', SSL, 2013, 2016, se('Yanmar', '4TNV98C', 3.3, '4-Cyl', 63, 'Diesel', '2-Speed Hydrostatic'), ['320E'], SOURCE_EPA_OEM),
  mdl('329E', 'E-Series Compact Track Loaders', 'Heavy Equipment', SSL, 2013, 2016, se('Yanmar', '4TNV94CHT', 3.1, '4-Cyl Turbo', 85, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('333E', 'E-Series Compact Track Loaders', 'Heavy Equipment', SSL, 2013, 2016, se('Yanmar', '4TNV94CHT', 3.1, '4-Cyl Turbo', 100, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('317G', 'G-Series Compact Track Loaders', 'Heavy Equipment', SSL, 2016, 2024, se('Yanmar', '4TNV98C', 3.3, '4-Cyl', 65, 'Diesel', '2-Speed Hydrostatic'), ['318G'], SOURCE_EPA_OEM),
  mdl('324G', 'G-Series Skid Steers', 'Heavy Equipment', SSL, 2016, 2024, se('Yanmar', '4TNV98CT', 3.3, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), ['320G'], SOURCE_EPA_OEM),
  mdl('325G', 'G-Series Compact Track Loaders', 'Heavy Equipment', SSL, 2018, 2024, se('Yanmar', '4TNV98CT', 3.3, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('331G', 'G-Series Compact Track Loaders', 'Heavy Equipment', SSL, 2016, 2024, se('Yanmar', '4TNV94FHT', 3.1, '4-Cyl Turbo', 91, 'Diesel', '2-Speed Hydrostatic'), ['330G'], SOURCE_EPA_OEM),
  mdl('333G', 'G-Series Compact Track Loaders', 'Heavy Equipment', SSL, 2016, 2024, se('Yanmar', '4TNV94FHT', 3.1, '4-Cyl Turbo', 100, 'Diesel', '2-Speed Hydrostatic'), ['332G'], SOURCE_EPA_OEM),
  mdl('333 P-Tier', 'P-Tier Compact Track Loaders', 'Heavy Equipment', SSL, 2024, 2026, se('Yanmar', '4TNV94FHT', 3.1, '4-Cyl Turbo', 104, 'Diesel', '2-Speed Hydrostatic'), ['331 P-Tier'], SOURCE_EPA_OEM),
  mdl('335 P-Tier', 'P-Tier Compact Track Loaders', 'Heavy Equipment', SSL, 2024, 2026, se('Yanmar', '4TN101FHT', 3.8, '4-Cyl Turbo', 118, 'Diesel', '2-Speed Hydrostatic'), ['334 P-Tier'], SOURCE_EPA_OEM),

  // Motor Graders & Articulated Trucks (1970–2026)
  mdl('570A', 'Classic Motor Graders', 'Heavy Equipment', GRD, 1970, 1986, se('John Deere', '6329D', 5.4, '6-Cyl', 85, 'Diesel', '8-Speed Powershift'), ['JD570A', '570B']),
  mdl('670A', 'Classic Motor Graders', 'Heavy Equipment', GRD, 1975, 1995, se('John Deere', '6414T', 6.8, '6-Cyl Turbo', 125, 'Diesel', '8-Speed Powershift'), ['JD670', '670B']),
  mdl('770A', 'Classic Motor Graders', 'Heavy Equipment', GRD, 1975, 1997, se('John Deere', '6531T / 6076A', 7.6, '6-Cyl Turbo', 155, 'Diesel', '8-Speed Powershift'), ['JD770', '770B', '770CH']),
  mdl('670D', 'D-Series Motor Graders', 'Heavy Equipment', GRD, 2005, 2009, se('John Deere', 'PowerTech 6068H', 6.8, '6-Cyl Turbo', 185, 'Diesel', '8-Speed Powershift'), ['670C', '670CH']),
  mdl('670G', 'G-Series Motor Graders', 'Heavy Equipment', GRD, 2008, 2022, se('John Deere', 'PowerTech PSS 9.0L', 9.0, '6-Cyl Turbo', 235, 'Diesel', '8-Speed Event-Based Powershift'), ['670GP']),
  mdl('670 P-Tier', 'P-Tier Motor Graders', 'Heavy Equipment', GRD, 2022, 2026, se('John Deere', 'PowerTech PSS 9.0L', 9.0, '6-Cyl Turbo', 235, 'Diesel', '8-Speed Event-Based Powershift')),
  mdl('672G', 'G-Series 6WD Motor Graders', 'Heavy Equipment', GRD, 2008, 2022, se('John Deere', 'PowerTech PSS 9.0L', 9.0, '6-Cyl Turbo', 255, 'Diesel', '8-Speed 6WD Powershift'), ['672D', '672GP']),
  mdl('672 P-Tier', 'P-Tier 6WD Motor Graders', 'Heavy Equipment', GRD, 2022, 2026, se('John Deere', 'PowerTech PSS 9.0L', 9.0, '6-Cyl Turbo', 255, 'Diesel', '8-Speed 6WD Powershift')),
  mdl('770D', 'D-Series Motor Graders', 'Heavy Equipment', GRD, 2005, 2009, se('John Deere', 'PowerTech 6081H', 8.1, '6-Cyl Turbo', 215, 'Diesel', '8-Speed Powershift')),
  mdl('770G', 'G-Series Motor Graders', 'Heavy Equipment', GRD, 2008, 2022, se('John Deere', 'PowerTech PSS 9.0L', 9.0, '6-Cyl Turbo', 255, 'Diesel', '8-Speed Powershift'), ['770GP']),
  mdl('770 P-Tier', 'P-Tier Motor Graders', 'Heavy Equipment', GRD, 2022, 2026, se('John Deere', 'PowerTech PSS 9.0L', 9.0, '6-Cyl Turbo', 255, 'Diesel', '8-Speed Powershift')),
  mdl('772G', 'G-Series 6WD Motor Graders', 'Heavy Equipment', GRD, 2008, 2022, se('John Deere', 'PowerTech PSS 9.0L', 9.0, '6-Cyl Turbo', 275, 'Diesel', '8-Speed 6WD Powershift'), ['772D', '772GP']),
  mdl('772 P-Tier', 'P-Tier 6WD Motor Graders', 'Heavy Equipment', GRD, 2022, 2026, se('John Deere', 'PowerTech PSS 9.0L', 9.0, '6-Cyl Turbo', 275, 'Diesel', '8-Speed 6WD Powershift')),
  mdl('870G', 'G-Series Heavy Motor Graders', 'Heavy Equipment', GRD, 2008, 2022, se('John Deere', 'PowerTech PSS 9.0L', 9.0, '6-Cyl Twin-Turbo', 280, 'Diesel', '8-Speed Powershift'), ['870GP']),
  mdl('872G', 'G-Series 6WD Motor Graders', 'Heavy Equipment', GRD, 2008, 2022, se('John Deere', 'PowerTech PSS 9.0L', 9.0, '6-Cyl Twin-Turbo', 300, 'Diesel', '8-Speed 6WD Powershift'), ['872D', '872GP']),
  mdl('872 P-Tier', 'P-Tier 6WD Motor Graders', 'Heavy Equipment', GRD, 2022, 2026, se('John Deere', 'PowerTech PSS 9.0L', 9.0, '6-Cyl Twin-Turbo', 300, 'Diesel', '8-Speed 6WD Powershift'), ['870 P-Tier']),
  mdl('410E II', 'Articulated Dump Trucks', 'Transport & Hauling', ADT, 2018, 2026, se('John Deere', 'PowerTech PSS 13.5L', 13.5, '6-Cyl Turbo', 443, 'Diesel', 'ZF Planetary Powershift'), ['310E ADT', '460E', '410 P-Tier ADT'], SOURCE_EPA_OEM),
  mdl('300D', 'D-Series Articulated Dump Trucks', 'Transport & Hauling', ADT, 2002, 2012, se('John Deere', 'PowerTech 6081A / 6090H', 9.0, '6-Cyl Turbo', 285, 'Diesel', 'ZF 6F/3R Powershift'), ['250D', '350D', '400D'], SOURCE_EPA_OEM),
];

// ============================================================================
// 4. KOMATSU (1970–2026)
// ============================================================================
const KOMATSU_MODELS = [
  // PC200 / PC220 / PC300 / PC400 Generational Excavators (1980–2012)
  mdl('PC200-1', 'PC200 Series Excavators', 'Heavy Equipment', EXC, 1980, 1982, se('Komatsu', 'S6D105-1', 6.5, '6-Cyl Turbo', 105), ['PC200-2']),
  mdl('PC200-3', 'PC200 Series Excavators', 'Heavy Equipment', EXC, 1984, 1988, se('Komatsu', 'S6D105-B', 6.5, '6-Cyl Turbo', 118), ['PC200LC-3']),
  mdl('PC200-5', 'PC200 Series Excavators', 'Heavy Equipment', EXC, 1988, 1993, se('Komatsu', 'S6D95L-1', 4.9, '6-Cyl Turbo', 123), ['PC200LC-5']),
  mdl('PC200-6', 'Avance Series Excavators', 'Heavy Equipment', EXC, 1994, 2001, se('Komatsu', 'S6D102E-1', 5.9, '6-Cyl Turbo', 133), ['PC200LC-6']),
  mdl('PC200-7', 'Galeo Series Excavators', 'Heavy Equipment', EXC, 2001, 2005, se('Komatsu', 'SAA6D102E-2', 5.9, '6-Cyl Turbo', 143), ['PC200LC-7']),
  mdl('PC200-8', 'ecot3 Series Excavators', 'Heavy Equipment', EXC, 2005, 2012, se('Komatsu', 'SAA6D107E-1', 6.7, '6-Cyl Turbo', 148), ['PC200LC-8']),
  mdl('PC120-5', 'PC120 Series Excavators', 'Heavy Equipment', EXC, 1988, 2002, se('Komatsu', 'S4D95L / S4D102E', 3.9, '4-Cyl Turbo', 86), ['PC120-6']),
  mdl('PC220LC-3', 'PC220 Series Excavators', 'Heavy Equipment', EXC, 1984, 1989, se('Komatsu', 'S6D105', 6.5, '6-Cyl Turbo', 148), ['PC220-3']),
  mdl('PC220LC-5', 'PC220 Series Excavators', 'Heavy Equipment', EXC, 1989, 1994, se('Komatsu', 'SA6D95L-1', 4.9, '6-Cyl Turbo', 157), ['PC220-5']),
  mdl('PC220LC-6', 'Avance Series Excavators', 'Heavy Equipment', EXC, 1994, 2001, se('Komatsu', 'SA6D102E-1', 5.9, '6-Cyl Turbo', 158), ['PC220-6']),
  mdl('PC220LC-7', 'Galeo Series Excavators', 'Heavy Equipment', EXC, 2001, 2005, se('Komatsu', 'SAA6D102E-2', 5.9, '6-Cyl Turbo', 168), ['PC220-7']),
  mdl('PC220LC-8', 'ecot3 Series Excavators', 'Heavy Equipment', EXC, 2005, 2012, se('Komatsu', 'SAA6D107E-1', 6.7, '6-Cyl Turbo', 168), ['PC220-8']),
  mdl('PC300LC-3', 'PC300 Series Excavators', 'Heavy Equipment', EXC, 1985, 1990, se('Komatsu', 'S6D125-1', 11.0, '6-Cyl Turbo', 207), ['PC300-3']),
  mdl('PC300LC-5', 'PC300 Series Excavators', 'Heavy Equipment', EXC, 1990, 1995, se('Komatsu', 'SA6D108-1', 7.2, '6-Cyl Turbo', 211), ['PC300-5']),
  mdl('PC300LC-6', 'Avance Series Excavators', 'Heavy Equipment', EXC, 1995, 2002, se('Komatsu', 'SAA6D108E-2', 7.2, '6-Cyl Turbo', 232), ['PC300-6']),
  mdl('PC300LC-7', 'Galeo Series Excavators', 'Heavy Equipment', EXC, 2002, 2006, se('Komatsu', 'SAA6D114E-2', 8.3, '6-Cyl Turbo', 242), ['PC300-7']),
  mdl('PC300LC-8', 'ecot3 Series Excavators', 'Heavy Equipment', EXC, 2006, 2012, se('Komatsu', 'SAA6D114E-3', 8.3, '6-Cyl Turbo', 246), ['PC300-8']),
  mdl('PC400LC-3', 'PC400 Series Excavators', 'Heavy Equipment', EXC, 1985, 1995, se('Komatsu', 'S6D125-1', 11.0, '6-Cyl Turbo', 276), ['PC400LC-5']),
  mdl('PC400LC-6', 'Avance Series Excavators', 'Heavy Equipment', EXC, 1995, 2005, se('Komatsu', 'SA6D125E-2', 11.0, '6-Cyl Turbo', 306), ['PC400LC-7']),
  mdl('PC400LC-8', 'ecot3 Series Excavators', 'Heavy Equipment', EXC, 2006, 2012, se('Komatsu', 'SAA6D125E-5', 11.0, '6-Cyl Turbo', 345), ['PC450LC-8']),

  // Compact & Dash-10 / Dash-11 / Hybrid Excavators (2006–2026)
  mdl('PC35MR-5', 'Compact Midi Excavators', 'Heavy Equipment', EXC, 2017, 2026, se('Komatsu', '3D88E-7', 1.6, '3-Cyl', 24), ['PC35MR-3'], SOURCE_EPA_OEM),
  mdl('PC55MR-3', 'Compact Midi Excavators', 'Heavy Equipment', EXC, 2009, 2018, se('Komatsu', '4D88E-6', 2.2, '4-Cyl', 38), [], SOURCE_EPA_OEM),
  mdl('PC55MR-5', 'Compact Midi Excavators', 'Heavy Equipment', EXC, 2018, 2026, se('Komatsu', '4D88E-7', 2.2, '4-Cyl', 38), ['PC55MR5'], SOURCE_EPA_OEM),
  mdl('PC78US-6', 'Tight-Tail Excavators', 'Heavy Equipment', EXC, 2003, 2014, se('Komatsu', '4D95LE-3', 3.3, '4-Cyl Turbo', 54), ['PC78US-8']),
  mdl('PC78US-10', 'Tight-Tail Excavators', 'Heavy Equipment', EXC, 2015, 2026, se('Komatsu', 'SAA4D95LE-6 / -7', 3.3, '4-Cyl Turbo', 65), ['PC78US-11']),
  mdl('PC88MR-10', 'Tight-Tail Excavators', 'Heavy Equipment', EXC, 2015, 2020, se('Komatsu', 'SAA4D95LE-6', 3.3, '4-Cyl Turbo', 65)),
  mdl('PC88MR-11', 'Tight-Tail Excavators', 'Heavy Equipment', EXC, 2020, 2026, se('Komatsu', 'SAA4D95LE-7', 3.3, '4-Cyl Turbo', 68)),
  mdl('PC138USLC-8', 'Tight-Tail Excavators', 'Heavy Equipment', EXC, 2007, 2012, se('Komatsu', 'SAA4D95LE-5', 3.3, '4-Cyl Turbo', 92)),
  mdl('PC138USLC-10', 'Tight-Tail Excavators', 'Heavy Equipment', EXC, 2012, 2016, se('Komatsu', 'SAA4D95LE-6', 3.3, '4-Cyl Turbo', 93), ['PC 138US LC-10']),
  mdl('PC138USLC-11', 'Tight-Tail Excavators', 'Heavy Equipment', EXC, 2016, 2026, se('Komatsu', 'SAA4D95LE-7', 3.3, '4-Cyl Turbo', 97), ['PC170LC-11']),
  mdl('PC210LC-10', 'Dash-10 Excavators', 'Heavy Equipment', EXC, 2012, 2017, se('Komatsu', 'SAA6D107E-2', 6.7, '6-Cyl Turbo', 158), ['PC210-10']),
  mdl('PC210LC-11', 'Dash-11 Excavators', 'Heavy Equipment', EXC, 2017, 2026, se('Komatsu', 'SAA6D107E-3', 6.7, '6-Cyl Turbo', 165), ['PC210-11', 'PC210LCi-11']),
  mdl('PC240LC-10', 'Dash-10 Excavators', 'Heavy Equipment', EXC, 2012, 2016, se('Komatsu', 'SAA6D107E-2', 6.7, '6-Cyl Turbo', 177)),
  mdl('PC240LC-11', 'Dash-11 Excavators', 'Heavy Equipment', EXC, 2016, 2026, se('Komatsu', 'SAA6D107E-3', 6.7, '6-Cyl Turbo', 189), ['PC240LCi-11']),
  mdl('PC290LC-10', 'Dash-10 Excavators', 'Heavy Equipment', EXC, 2012, 2016, se('Komatsu', 'SAA6D107E-2', 6.7, '6-Cyl Turbo', 196)),
  mdl('PC290LC-11', 'Dash-11 Excavators', 'Heavy Equipment', EXC, 2016, 2026, se('Komatsu', 'SAA6D107E-3', 6.7, '6-Cyl Turbo', 196), ['PC290LCi-11']),
  mdl('PC360LC-10', 'Dash-10 Excavators', 'Heavy Equipment', EXC, 2011, 2015, se('Komatsu', 'SAA6D114E-5', 8.9, '6-Cyl Turbo', 257)),
  mdl('PC360LC-11', 'Dash-11 Excavators', 'Heavy Equipment', EXC, 2015, 2026, se('Komatsu', 'SAA6D114E-6', 8.9, '6-Cyl Turbo', 257), ['PC360LCi-11']),
  mdl('PC490LC-10', 'Dash-10 Excavators', 'Heavy Equipment', EXC, 2012, 2015, se('Komatsu', 'SAA6D125E-6', 11.0, '6-Cyl Turbo', 359)),
  mdl('PC490LC-11', 'Dash-11 Excavators', 'Heavy Equipment', EXC, 2015, 2026, se('Komatsu', 'SAA6D125E-7', 11.0, '6-Cyl Turbo', 359), ['PC490LCi-11']),
  mdl('HB215LC-1', 'Hybrid Excavators', 'Heavy Equipment', EXC, 2011, 2014, se('Komatsu', 'SAA4D107E-1', 4.5, '4-Cyl Turbo', 139, 'Diesel-Electric Hybrid', 'Capacitor Swing Hybrid')),
  mdl('HB215LC-2', 'Hybrid Excavators', 'Heavy Equipment', EXC, 2014, 2017, se('Komatsu', 'SAA4D107E-2', 4.5, '4-Cyl Turbo', 148, 'Diesel-Electric Hybrid', 'Capacitor Swing Hybrid')),
  mdl('HB215LC-3', 'Hybrid Excavators', 'Heavy Equipment', EXC, 2017, 2024, se('Komatsu', 'SAA4D107E-3', 4.5, '4-Cyl Turbo', 148, 'Diesel-Electric Hybrid', 'Capacitor Swing Hybrid'), ['HB365LC-3']),

  // Crawler Dozers (1970–2026)
  mdl('D39EX-24', 'Small Hydrostatic Dozers', 'Heavy Equipment', DOZ, 2016, 2026, se('Komatsu', 'SAA4D95LE-7', 3.3, '4-Cyl Turbo', 105, 'Diesel', 'Hydrostatic'), ['D39PX-24']),
  mdl('D51EX-24', 'Medium Hydrostatic Dozers', 'Heavy Equipment', DOZ, 2016, 2026, se('Komatsu', 'SAA4D107E-3', 4.5, '4-Cyl Turbo', 131, 'Diesel', 'Hydrostatic'), ['D51PX-24', 'D51EXi-24']),
  mdl('D61EX-24', 'Medium Hydrostatic Dozers', 'Heavy Equipment', DOZ, 2016, 2026, se('Komatsu', 'SAA6D107E-3', 6.8, '6-Cyl Turbo', 168, 'Diesel', 'Hydrostatic'), ['D61PX-24', 'D61EXi-24']),
  mdl('D65E-6', 'D65 Classic Dozers', 'Heavy Equipment', DOZ, 1972, 1985, se('Cummins / Komatsu', 'NH-220-CI', 12.2, '6-Cyl', 155, 'Diesel', 'Torqflow Powershift'), ['D65A-6']),
  mdl('D65E-8', 'D65 Classic Dozers', 'Heavy Equipment', DOZ, 1985, 1992, se('Komatsu', '6D125-1', 11.0, '6-Cyl', 165, 'Diesel', 'Torqflow Powershift')),
  mdl('D65EX-12', 'D65 Crawler Dozers', 'Heavy Equipment', DOZ, 1992, 2004, se('Komatsu', 'S6D125E-2', 11.0, '6-Cyl Turbo', 190, 'Diesel', 'Torqflow Powershift')),
  mdl('D65EX-15', 'D65 Crawler Dozers', 'Heavy Equipment', DOZ, 2004, 2011, se('Komatsu', 'SAA6D114E-3', 8.3, '6-Cyl Turbo', 205, 'Diesel', 'Torqflow Powershift'), ['D65PX-15']),
  mdl('D65EX-17', 'D65 Crawler Dozers', 'Heavy Equipment', DOZ, 2011, 2015, se('Komatsu', 'SAA6D114E-5', 8.9, '6-Cyl Turbo', 205, 'Diesel', 'Automatic Torqflow Powershift'), ['D65PX-17']),
  mdl('D65EX-18', 'D65 Crawler Dozers', 'Heavy Equipment', DOZ, 2015, 2026, se('Komatsu', 'SAA6D114E-6', 8.9, '6-Cyl Turbo', 217, 'Diesel', 'Automatic Torqflow Powershift'), ['D65PX-18', 'D65WX-18', 'D65EXi-18']),
  mdl('D85E-21', 'D85 Classic Large Dozers', 'Heavy Equipment', DOZ, 1986, 2003, se('Komatsu', 'S6D125E-2', 11.0, '6-Cyl Turbo', 225, 'Diesel', 'Torqflow Powershift'), ['D85A-18']),
  mdl('D85EX-15', 'D85 Large Dozers', 'Heavy Equipment', DOZ, 2003, 2014, se('Komatsu', 'SAA6D125E-5', 11.0, '6-Cyl Turbo', 264, 'Diesel', 'Torqflow Powershift'), ['D85PX-15']),
  mdl('D85EX-18', 'D85 Large Dozers', 'Heavy Equipment', DOZ, 2014, 2026, se('Komatsu', 'SAA6D125E-7', 11.0, '6-Cyl Turbo', 264, 'Diesel', 'Automatic Torqflow Powershift'), ['D85PX-18', 'D85EXi-18']),
  mdl('D155A-2', 'D155 Classic Large Dozers', 'Heavy Equipment', DOZ, 1986, 2001, se('Komatsu', 'SA6D140-2', 15.2, '6-Cyl Turbo', 320, 'Diesel', 'Torqflow Powershift')),
  mdl('D155AX-6', 'D155 Large Dozers', 'Heavy Equipment', DOZ, 2007, 2014, se('Komatsu', 'SAA6D140E-5', 15.2, '6-Cyl Turbo', 354, 'Diesel', 'Torqflow Powershift')),
  mdl('D155AX-8', 'D155 Large Dozers', 'Heavy Equipment', DOZ, 2014, 2026, se('Komatsu', 'SAA6D140E-7', 15.2, '6-Cyl Turbo', 354, 'Diesel', 'Automatic Torqflow Powershift'), ['D155AXi-8']),
  mdl('D275A-2', 'D275 Classic Mining Dozers', 'Heavy Equipment', DOZ, 1989, 2002, se('Komatsu', 'S6D170E-2', 23.2, '6-Cyl Turbo', 405, 'Diesel', 'Torqflow Powershift')),
  mdl('D275AX-5', 'D275 Mining Dozers', 'Heavy Equipment', DOZ, 2002, 2026, se('Komatsu', 'SAA6D140E / SDA6D140E', 15.2, '6-Cyl Turbo', 449, 'Diesel', 'Torqflow Powershift'), ['D275AX-5E0']),
  mdl('D375A-5', 'D375 Mining Dozers', 'Heavy Equipment', DOZ, 2002, 2010, se('Komatsu', 'SA6D170E-3', 23.2, '6-Cyl Turbo', 525, 'Diesel', 'Torqflow Powershift'), ['D375A-3']),
  mdl('D375A-6', 'D375 Mining Dozers', 'Heavy Equipment', DOZ, 2010, 2017, se('Komatsu', 'SAA6D170E-5', 23.2, '6-Cyl Turbo', 610, 'Diesel', 'Torqflow Powershift')),
  mdl('D375A-8', 'D375 Mining Dozers', 'Heavy Equipment', DOZ, 2017, 2026, se('Komatsu', 'SAA6D170E-7', 23.2, '6-Cyl Turbo', 610, 'Diesel', 'Torqflow Powershift')),

  // Wheel Loaders, Graders & Haulers (1984–2026)
  mdl('WA200-5', 'WA Series Wheel Loaders', 'Heavy Equipment', LDR, 2004, 2008, se('Komatsu', 'SAA6D102E-2', 5.9, '6-Cyl Turbo', 123, 'Diesel', 'Hydrostatic'), ['WA200-1', 'WA200-3']),
  mdl('WA200-7', 'WA Series Wheel Loaders', 'Heavy Equipment', LDR, 2013, 2017, se('Komatsu', 'SAA4D107E-2', 4.5, '4-Cyl Turbo', 126, 'Diesel', 'Hydrostatic')),
  mdl('WA200-8', 'WA Series Wheel Loaders', 'Heavy Equipment', LDR, 2017, 2026, se('Komatsu', 'SAA4D107E-3', 4.5, '4-Cyl Turbo', 126, 'Diesel', 'Hydrostatic')),
  mdl('WA250-5', 'WA Series Wheel Loaders', 'Heavy Equipment', LDR, 2001, 2007, se('Komatsu', 'SAA6D102E-2', 5.9, '6-Cyl Turbo', 134, 'Diesel', 'Hydrostatic'), ['WA250-3']),
  mdl('WA250-6', 'WA Series Wheel Loaders', 'Heavy Equipment', LDR, 2007, 2014, se('Komatsu', 'SAA6D107E-1', 6.7, '6-Cyl Turbo', 138, 'Diesel', 'Hydrostatic')),
  mdl('WA270-7', 'WA Series Wheel Loaders', 'Heavy Equipment', LDR, 2013, 2017, se('Komatsu', 'SAA6D107E-2', 6.7, '6-Cyl Turbo', 149, 'Diesel', 'Hydrostatic')),
  mdl('WA270-8', 'WA Series Wheel Loaders', 'Heavy Equipment', LDR, 2017, 2026, se('Komatsu', 'SAA6D107E-3', 6.7, '6-Cyl Turbo', 149, 'Diesel', 'Hydrostatic')),
  mdl('WA320-5', 'WA Series Wheel Loaders', 'Heavy Equipment', LDR, 2003, 2008, se('Komatsu', 'SAA6D102E-2', 5.9, '6-Cyl Turbo', 166, 'Diesel', 'Hydrostatic'), ['WA320-3']),
  mdl('WA320-7', 'WA Series Wheel Loaders', 'Heavy Equipment', LDR, 2013, 2017, se('Komatsu', 'SAA6D107E-2', 6.7, '6-Cyl Turbo', 165, 'Diesel', 'Hydrostatic')),
  mdl('WA320-8', 'WA Series Wheel Loaders', 'Heavy Equipment', LDR, 2017, 2026, se('Komatsu', 'SAA6D107E-3', 6.7, '6-Cyl Turbo', 165, 'Diesel', 'Hydrostatic')),
  mdl('WA380-5', 'WA Series Wheel Loaders', 'Heavy Equipment', LDR, 2002, 2007, se('Komatsu', 'SAA6D114E-2', 8.3, '6-Cyl Turbo', 187, 'Diesel', 'Automatic Powershift'), ['WA380-3']),
  mdl('WA380-7', 'WA Series Wheel Loaders', 'Heavy Equipment', LDR, 2012, 2016, se('Komatsu', 'SAA6D107E-2', 6.7, '6-Cyl Turbo', 191, 'Diesel', 'Automatic Powershift')),
  mdl('WA380-8', 'WA Series Wheel Loaders', 'Heavy Equipment', LDR, 2016, 2026, se('Komatsu', 'SAA6D107E-3', 6.7, '6-Cyl Turbo', 191, 'Diesel', 'Automatic Powershift')),
  mdl('WA470-7', 'WA Series Wheel Loaders', 'Heavy Equipment', LDR, 2012, 2016, se('Komatsu', 'SAA6D125E-6', 11.0, '6-Cyl Turbo', 272, 'Diesel', 'Automatic Powershift')),
  mdl('WA470-8', 'WA Series Wheel Loaders', 'Heavy Equipment', LDR, 2016, 2026, se('Komatsu', 'SAA6D125E-7', 11.0, '6-Cyl Turbo', 272, 'Diesel', 'Automatic Powershift'), ['WA475-10']),
  mdl('WA500-7', 'WA Series Large Loaders', 'Heavy Equipment', LDR, 2012, 2016, se('Komatsu', 'SAA6D140E-6', 15.2, '6-Cyl Turbo', 353, 'Diesel', 'Automatic Powershift')),
  mdl('WA500-8', 'WA Series Large Loaders', 'Heavy Equipment', LDR, 2016, 2026, se('Komatsu', 'SAA6D140E-7', 15.2, '6-Cyl Turbo', 357, 'Diesel', 'Automatic Powershift')),
  mdl('GD655-3', 'GD Series Motor Graders', 'Heavy Equipment', GRD, 2001, 2009, se('Komatsu', 'SAA6D114E-2', 8.3, '6-Cyl Turbo', 190, 'Diesel', 'Dual-Mode Powershift'), ['GD655A-2']),
  mdl('GD655-5', 'GD Series Motor Graders', 'Heavy Equipment', GRD, 2009, 2015, se('Komatsu', 'SAA6D107E-1', 6.7, '6-Cyl Turbo', 218, 'Diesel', 'Dual-Mode Powershift')),
  mdl('GD655-6', 'GD Series Motor Graders', 'Heavy Equipment', GRD, 2015, 2019, se('Komatsu', 'SAA6D107E-2', 6.7, '6-Cyl Turbo', 218, 'Diesel', 'Dual-Mode Powershift')),
  mdl('GD655-7', 'GD Series Motor Graders', 'Heavy Equipment', GRD, 2019, 2026, se('Komatsu', 'SAA6D107E-3', 6.7, '6-Cyl Turbo', 218, 'Diesel', 'Dual-Mode Torque Converter / Direct Powershift')),
  mdl('HM300-2', 'HM Articulated Dump Trucks', 'Transport & Hauling', ADT, 2005, 2012, se('Komatsu', 'SAA6D125E-5', 11.0, '6-Cyl Turbo', 329, 'Diesel', '6F/2R K-ATOMiCS Powershift'), ['HM300-1']),
  mdl('HM300-3', 'HM Articulated Dump Trucks', 'Transport & Hauling', ADT, 2012, 2016, se('Komatsu', 'SAA6D125E-6', 11.0, '6-Cyl Turbo', 325, 'Diesel', '6F/2R K-ATOMiCS Powershift')),
  mdl('HM300-5', 'HM Articulated Dump Trucks', 'Transport & Hauling', ADT, 2016, 2026, se('Komatsu', 'SAA6D125E-7', 11.0, '6-Cyl Turbo', 324, 'Diesel', '6F/2R K-ATOMiCS Powershift')),
  mdl('HM400-2', 'HM Articulated Dump Trucks', 'Transport & Hauling', ADT, 2005, 2012, se('Komatsu', 'SAA6D140E-5', 15.2, '6-Cyl Turbo', 438, 'Diesel', '6F/2R K-ATOMiCS Powershift'), ['HM400-1']),
  mdl('HM400-3', 'HM Articulated Dump Trucks', 'Transport & Hauling', ADT, 2012, 2016, se('Komatsu', 'SAA6D140E-6', 15.2, '6-Cyl Turbo', 448, 'Diesel', '6F/2R K-ATOMiCS Powershift')),
  mdl('HM400-5', 'HM Articulated Dump Trucks', 'Transport & Hauling', ADT, 2016, 2026, se('Komatsu', 'SAA6D140E-7', 15.2, '6-Cyl Turbo', 469, 'Diesel', '6F/2R K-ATOMiCS Powershift')),
];

// ============================================================================
// 5. CASE (1970–2026)
// ============================================================================
const CASE_MODELS = [
  // Legendary 580 / 590 Backhoe Loaders (1970–2026)
  mdl('580CK', '580 Series Backhoe Loaders', 'Heavy Equipment', BKH, 1970, 1971, se('Case', 'G188D', 3.1, '4-Cyl', 52, 'Diesel', '4-Speed Power Shuttle')),
  mdl('580B', '580 Series Backhoe Loaders', 'Heavy Equipment', BKH, 1971, 1976, se('Case', 'G188D', 3.1, '4-Cyl', 57, 'Diesel', '4-Speed Power Shuttle'), ['580BCK']),
  mdl('580C', '580 Series Backhoe Loaders', 'Heavy Equipment', BKH, 1975, 1980, se('Case', 'G207D', 3.4, '4-Cyl', 55, 'Diesel', '4-Speed Power Shuttle')),
  mdl('580D', '580 Series Backhoe Loaders', 'Heavy Equipment', BKH, 1980, 1984, se('Case', 'G207D', 3.4, '4-Cyl', 55, 'Diesel', '4-Speed Power Shuttle')),
  mdl('580 Super D', '580 Series Backhoe Loaders', 'Heavy Equipment', BKH, 1980, 1984, se('Case', 'G207D Turbo', 3.4, '4-Cyl Turbo', 60, 'Diesel', '4-Speed Power Shuttle'), ['580SD']),
  mdl('580E', '580 Series Backhoe Loaders', 'Heavy Equipment', BKH, 1984, 1988, se('Case / CDC', '4-390', 3.9, '4-Cyl', 63, 'Diesel', '4-Speed Power Shuttle')),
  mdl('580 Super E', '580 Series Backhoe Loaders', 'Heavy Equipment', BKH, 1984, 1988, se('Case / CDC', '4T-390', 3.9, '4-Cyl Turbo', 75, 'Diesel', '4-Speed Power Shuttle'), ['580SE']),
  mdl('580K', '580 Series Backhoe Loaders', 'Heavy Equipment', BKH, 1986, 1994, se('Case / CDC', '4-390', 3.9, '4-Cyl', 69, 'Diesel', '4-Speed Synchromesh Shuttle')),
  mdl('580 Super K', '580 Series Backhoe Loaders', 'Heavy Equipment', BKH, 1990, 1994, se('Case / CDC', '4T-390', 3.9, '4-Cyl Turbo', 75, 'Diesel', '4-Speed Powershuttle'), ['580SK']),
  mdl('580L', '580 Series Backhoe Loaders', 'Heavy Equipment', BKH, 1995, 2000, se('Case / CDC', '4-390', 3.9, '4-Cyl', 70, 'Diesel', '4-Speed Powershuttle'), ['580L Series 2']),
  mdl('580 Super L', '580 Series Backhoe Loaders', 'Heavy Equipment', BKH, 1995, 2000, se('Case / CDC', '4T-390', 3.9, '4-Cyl Turbo', 86, 'Diesel', '4-Speed Powershuttle'), ['580SL']),
  mdl('580M', '580 Series Backhoe Loaders', 'Heavy Equipment', BKH, 2001, 2010, se('Case', '445T/M2', 4.5, '4-Cyl Turbo', 76, 'Diesel', '4-Speed Powershuttle'), ['580M Series 2', '580M Series 3']),
  mdl('580 Super M', '580 Series Backhoe Loaders', 'Heavy Equipment', BKH, 2001, 2010, se('Case', '445T/M3', 4.5, '4-Cyl Turbo', 95, 'Diesel', 'Powershift H-Type'), ['580SM']),
  mdl('580N', 'N-Series Backhoe Loaders', 'Heavy Equipment', BKH, 2010, 2026, se('FPT Industrial', 'F5C / F5BFL413', 3.4, '4-Cyl Turbo', 79, 'Diesel', '4-Speed Powershuttle'), ['580N EP']),
  mdl('580SN', 'N-Series Backhoe Loaders', 'Heavy Equipment', BKH, 2010, 2026, se('FPT Industrial', 'F5BFL413 / N45', 3.4, '4-Cyl Turbo', 97, 'Diesel', 'S-Type 4-Speed Powershift'), ['580 Super N', '580SN WT']),
  mdl('580SV', 'Construction King Backhoe Loaders', 'Heavy Equipment', BKH, 2019, 2026, se('FPT Industrial', 'F5C / F36 Stage V', 3.6, '4-Cyl Turbo', 97, 'Diesel', '4-Speed Powershift'), ['580 SV']),
  mdl('590SN', 'N-Series Heavy Backhoes', 'Heavy Equipment', BKH, 2010, 2026, se('FPT Industrial', 'F5BFL413A / N45', 3.4, '4-Cyl Turbo', 110, 'Diesel', 'Powershift'), ['590 Super N']),

  // Excavators (1975–2026)
  mdl('9010B', '9000 Series Excavators', 'Heavy Equipment', EXC, 1994, 2000, se('Case / CDC', '4T-390', 3.9, '4-Cyl Turbo', 92), ['9010', '880B']),
  mdl('9020B', '9000 Series Excavators', 'Heavy Equipment', EXC, 1994, 2000, se('Case / CDC', '6T-590', 5.9, '6-Cyl Turbo', 115), ['9020']),
  mdl('9030B', '9000 Series Excavators', 'Heavy Equipment', EXC, 1994, 2001, se('Case / CDC', '6T-590', 5.9, '6-Cyl Turbo', 142), ['9030', '9040B']),
  mdl('CX130', 'CX Series Excavators', 'Heavy Equipment', EXC, 2002, 2006, se('Isuzu', '4BG1T', 4.3, '4-Cyl Turbo', 95)),
  mdl('CX130C', 'CX-C Series Excavators', 'Heavy Equipment', EXC, 2011, 2015, se('Isuzu', '4JJ1X', 3.0, '4-Cyl Turbo', 95)),
  mdl('CX130D', 'CX-D Series Excavators', 'Heavy Equipment', EXC, 2015, 2023, se('Isuzu', '4JJ1X', 3.0, '4-Cyl Turbo', 102)),
  mdl('CX130E', 'CX-E Series Excavators', 'Heavy Equipment', EXC, 2023, 2026, se('FPT Industrial', 'NEF4', 4.5, '4-Cyl Turbo', 130), ['CX145E SR']),
  mdl('CX160', 'CX Series Excavators', 'Heavy Equipment', EXC, 2002, 2006, se('Isuzu', '4BG1T', 4.3, '4-Cyl Turbo', 112)),
  mdl('CX160B', 'CX-B Series Excavators', 'Heavy Equipment', EXC, 2007, 2011, se('Isuzu', '4JJ1X', 3.0, '4-Cyl Turbo', 120)),
  mdl('CX160C', 'CX-C Series Excavators', 'Heavy Equipment', EXC, 2011, 2015, se('Isuzu', '4JJ1X', 3.0, '4-Cyl Turbo', 120)),
  mdl('CX160D', 'CX-D Series Excavators', 'Heavy Equipment', EXC, 2015, 2023, se('Isuzu', '4JJ1X', 3.0, '4-Cyl Turbo', 120)),
  mdl('CX170E', 'CX-E Series Excavators', 'Heavy Equipment', EXC, 2023, 2026, se('FPT Industrial', 'NEF4', 4.5, '4-Cyl Turbo', 130)),
  mdl('CX210B', 'CX Series Excavators', 'Heavy Equipment', EXC, 2007, 2011, se('Isuzu', '4HK1X', 5.2, '4-Cyl Turbo', 157), ['CX210']),
  mdl('CX210C', 'CX Series Excavators', 'Heavy Equipment', EXC, 2011, 2015, se('Isuzu', '4HK1X', 5.2, '4-Cyl Turbo', 160)),
  mdl('CX210D', 'CX-D Series Excavators', 'Heavy Equipment', EXC, 2015, 2023, se('Isuzu', '4HK1X', 5.2, '4-Cyl Turbo', 160)),
  mdl('CX220E', 'CX-E Series Excavators', 'Heavy Equipment', EXC, 2022, 2026, se('FPT Industrial', 'NEF6', 6.7, '6-Cyl Turbo', 173), ['CX210E']),
  mdl('CX250C', 'CX-C Series Excavators', 'Heavy Equipment', EXC, 2011, 2015, se('Isuzu', '4HK1X', 5.2, '4-Cyl Turbo', 177), ['CX240B']),
  mdl('CX250E', 'CX-E Series Excavators', 'Heavy Equipment', EXC, 2023, 2026, se('FPT Industrial', 'NEF6', 6.7, '6-Cyl Turbo', 188)),
  mdl('CX300C', 'CX-C Series Excavators', 'Heavy Equipment', EXC, 2011, 2015, se('Isuzu', '6HK1X', 7.8, '6-Cyl Turbo', 207), ['CX290B']),
  mdl('CX300D', 'CX-D Series Excavators', 'Heavy Equipment', EXC, 2015, 2023, se('Isuzu', '6HK1X', 7.8, '6-Cyl Turbo', 207)),
  mdl('CX300E', 'CX-E Series Excavators', 'Heavy Equipment', EXC, 2023, 2026, se('FPT Industrial', 'NEF6', 6.7, '6-Cyl Turbo', 252)),
  mdl('CX350C', 'CX-C Series Excavators', 'Heavy Equipment', EXC, 2011, 2015, se('Isuzu', '6HK1X', 7.8, '6-Cyl Turbo', 268), ['CX330']),
  mdl('CX350D', 'CX-D Series Excavators', 'Heavy Equipment', EXC, 2015, 2023, se('Isuzu', '6HK1X', 7.8, '6-Cyl Turbo', 268)),
  mdl('CX370E', 'CX-E Series Excavators', 'Heavy Equipment', EXC, 2023, 2026, se('FPT Industrial', 'Cursor 9', 8.7, '6-Cyl Turbo', 295)),

  // Wheel Loaders (1972–2026)
  mdl('W14', 'Classic W-Series Loaders', 'Heavy Equipment', LDR, 1974, 1988, se('Case', 'A336BD', 5.5, '6-Cyl', 83, 'Diesel', 'Powershift'), ['W14B']),
  mdl('W20', 'Classic W-Series Loaders', 'Heavy Equipment', LDR, 1972, 1988, se('Case', 'A401BD', 6.6, '6-Cyl', 103, 'Diesel', 'Powershift'), ['W20B', 'W20C']),
  mdl('621', '621 Wheel Loaders', 'Heavy Equipment', LDR, 1989, 1993, se('Case / CDC', '6T-590', 5.9, '6-Cyl Turbo', 116, 'Diesel', 'ZF 4-Speed Powershift')),
  mdl('621B', '621 Wheel Loaders', 'Heavy Equipment', LDR, 1993, 1999, se('Case / CDC', '6T-590', 5.9, '6-Cyl Turbo', 126, 'Diesel', 'ZF 4-Speed Powershift'), ['621C']),
  mdl('621D', '621 Wheel Loaders', 'Heavy Equipment', LDR, 2001, 2006, se('Case', '6TAA-5904', 5.9, '6-Cyl Turbo', 138, 'Diesel', 'ZF 4-Speed Powershift')),
  mdl('621E', '621 Wheel Loaders', 'Heavy Equipment', LDR, 2007, 2012, se('Case / FPT', '667TA', 6.7, '6-Cyl Turbo', 149, 'Diesel', 'ZF 4-Speed Powershift')),
  mdl('621F', '621 Wheel Loaders', 'Heavy Equipment', LDR, 2012, 2017, se('FPT Industrial', 'F4HFE613', 6.7, '6-Cyl Turbo', 162, 'Diesel', 'ZF Powershift')),
  mdl('621G', 'G-Series Wheel Loaders', 'Heavy Equipment', LDR, 2017, 2026, se('FPT Industrial', 'NEF 6.7L', 6.7, '6-Cyl Turbo', 172, 'Diesel', '5-Speed Lockup Powershift')),
  mdl('721D', '721 Wheel Loaders', 'Heavy Equipment', LDR, 2002, 2006, se('Case', '6TAA-5904', 5.9, '6-Cyl Turbo', 170, 'Diesel', 'ZF 4-Speed Powershift')),
  mdl('721E', '721 Wheel Loaders', 'Heavy Equipment', LDR, 2007, 2011, se('Case / FPT', '667TA', 6.7, '6-Cyl Turbo', 183, 'Diesel', 'ZF 4-Speed Powershift')),
  mdl('721G', 'G-Series Wheel Loaders', 'Heavy Equipment', LDR, 2017, 2026, se('FPT Industrial', 'NEF 6.7L', 6.7, '6-Cyl Turbo', 195, 'Diesel', '5-Speed Lockup Powershift')),
  mdl('821E', '821 Wheel Loaders', 'Heavy Equipment', LDR, 2007, 2011, se('Case / FPT', '667TA', 6.7, '6-Cyl Turbo', 213, 'Diesel', 'ZF 4-Speed Powershift')),
  mdl('821F', '821 Wheel Loaders', 'Heavy Equipment', LDR, 2011, 2017, se('FPT Industrial', 'F4HFE613', 6.7, '6-Cyl Turbo', 213, 'Diesel', 'ZF 5-Speed Powershift')),
  mdl('821G', 'G-Series Wheel Loaders', 'Heavy Equipment', LDR, 2017, 2026, se('FPT Industrial', 'NEF 6.7L', 6.7, '6-Cyl Turbo', 230, 'Diesel', '5-Speed Lockup Powershift'), ['921G']),

  // Skid Steers, CTLs & Dozers (1985–2026)
  mdl('1840', 'Uni-Loader Skid Steers', 'Heavy Equipment', SSL, 1989, 2001, se('Case / CDC', '4-390', 3.9, '4-Cyl', 50, 'Diesel', 'Hydrostatic'), ['1835B', '1838'], SOURCE_EPA_OEM),
  mdl('1845C', 'Uni-Loader Skid Steers', 'Heavy Equipment', SSL, 1985, 2001, se('Case / CDC', '4-390', 3.9, '4-Cyl', 56, 'Diesel', 'Hydrostatic'), ['1845B'], SOURCE_EPA_OEM),
  mdl('40XT', 'XT-Series Skid Steers', 'Heavy Equipment', SSL, 2000, 2005, se('Case / CDC', '4-390 / 4T-390', 3.9, '4-Cyl Turbo', 60, 'Diesel', 'Hydrostatic'), ['60XT', '70XT', '75XT'], SOURCE_EPA_OEM),
  mdl('SR210', 'Alpha Series Skid Steers', 'Heavy Equipment', SSL, 2011, 2019, se('ISM / FPT', 'N844LT / F5C', 3.4, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('SR210B', 'B-Series Skid Steers', 'Heavy Equipment', SSL, 2020, 2026, se('FPT Industrial', 'F5C', 3.4, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('SR240', 'Alpha Series Skid Steers', 'Heavy Equipment', SSL, 2014, 2019, se('FPT Industrial', 'F5C', 3.4, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('SR240B', 'B-Series Skid Steers', 'Heavy Equipment', SSL, 2020, 2026, se('FPT Industrial', 'F5C', 3.4, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('SR250', 'Alpha Series Skid Steers', 'Heavy Equipment', SSL, 2011, 2019, se('FPT Industrial', 'F5BFL413', 3.4, '4-Cyl Turbo', 90, 'Diesel', '2-Speed Hydrostatic'), ['SR270'], SOURCE_EPA_OEM),
  mdl('SR270B', 'B-Series Skid Steers', 'Heavy Equipment', SSL, 2020, 2026, se('FPT Industrial', 'F5BFL413A', 3.4, '4-Cyl Turbo', 90, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('SV280', 'Alpha Series Skid Steers', 'Heavy Equipment', SSL, 2015, 2019, se('FPT Industrial', 'F5C', 3.4, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('SV280B', 'B-Series Skid Steers', 'Heavy Equipment', SSL, 2020, 2026, se('FPT Industrial', 'F5C', 3.4, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('SV300', 'Alpha Series Skid Steers', 'Heavy Equipment', SSL, 2011, 2017, se('FPT Industrial', 'F5BFL413', 3.4, '4-Cyl Turbo', 90, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('SV340', 'Alpha Series Skid Steers', 'Heavy Equipment', SSL, 2017, 2019, se('FPT Industrial', 'F5BFL413A', 3.4, '4-Cyl Turbo', 90, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('SV340B', 'B-Series Skid Steers', 'Heavy Equipment', SSL, 2020, 2026, se('FPT Industrial', 'F5BFL413A', 3.4, '4-Cyl Turbo', 90, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('TR270', 'Alpha Series CTLs', 'Heavy Equipment', SSL, 2011, 2019, se('FPT Industrial', 'F5C', 3.4, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('TR270B', 'B-Series CTLs', 'Heavy Equipment', SSL, 2020, 2026, se('FPT Industrial', 'F5C', 3.4, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('TR310', 'Alpha Series CTLs', 'Heavy Equipment', SSL, 2014, 2019, se('FPT Industrial', 'F5C', 3.4, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('TR310B', 'B-Series CTLs', 'Heavy Equipment', SSL, 2020, 2026, se('FPT Industrial', 'F5C', 3.4, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('TR340', 'Alpha Series CTLs', 'Heavy Equipment', SSL, 2014, 2019, se('FPT Industrial', 'F5BFL413A', 3.4, '4-Cyl Turbo', 90, 'Diesel', '2-Speed Hydrostatic'), ['TR320'], SOURCE_EPA_OEM),
  mdl('TR340B', 'B-Series CTLs', 'Heavy Equipment', SSL, 2020, 2026, se('FPT Industrial', 'F5BFL413A', 3.4, '4-Cyl Turbo', 90, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('TV380', 'Alpha Series CTLs', 'Heavy Equipment', SSL, 2011, 2019, se('FPT Industrial', 'F5BFL413A', 3.4, '4-Cyl Turbo', 90, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('TV370B', 'B-Series CTLs', 'Heavy Equipment', SSL, 2020, 2026, se('FPT Industrial', 'F5C', 3.4, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), ['TV380B'], SOURCE_EPA_OEM),
  mdl('TV450', 'Alpha Series Heavy CTLs', 'Heavy Equipment', SSL, 2019, 2019, se('FPT Industrial', 'F5BFL413A', 3.4, '4-Cyl Turbo', 90, 'Diesel', '2-Speed High-Flow Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('TV450B', 'B-Series Heavy CTLs', 'Heavy Equipment', SSL, 2020, 2026, se('FPT Industrial', 'F5BFL413A', 3.4, '4-Cyl Turbo', 90, 'Diesel', '2-Speed High-Flow Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('TV620B', 'B-Series Heavy CTLs', 'Heavy Equipment', SSL, 2021, 2026, se('FPT Industrial', 'F5HFL463A', 3.6, '4-Cyl Turbo', 114, 'Diesel', '2-Speed High-Flow Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('850D', 'Classic 850 Crawler Dozers', 'Heavy Equipment', DOZ, 1985, 1993, se('Case / CDC', '6-590', 5.9, '6-Cyl', 82, 'Diesel', 'Powershift'), ['850C', '850E']),
  mdl('850G', 'G-Series Crawler Dozers', 'Heavy Equipment', DOZ, 1994, 2001, se('Case / CDC', '6T-590', 5.9, '6-Cyl Turbo', 89, 'Diesel', 'Powershift'), ['850H']),
  mdl('850L', 'L-Series Crawler Dozers', 'Heavy Equipment', DOZ, 2008, 2013, se('Case / FPT', 'F4HE0484', 4.5, '4-Cyl Turbo', 97, 'Diesel', 'Dual-Path Hydrostatic')),
  mdl('850M', 'M-Series Crawler Dozers', 'Heavy Equipment', DOZ, 2013, 2026, se('FPT Industrial', 'F4HFE413 / NEF 4.5L', 4.5, '4-Cyl Turbo', 112, 'Diesel', 'Dual-Path Hydrostatic')),
  mdl('1150E', 'Classic 1150 Crawler Dozers', 'Heavy Equipment', DOZ, 1986, 1994, se('Case / CDC', '6T-590', 5.9, '6-Cyl Turbo', 113, 'Diesel', 'Powershift'), ['1150C', '1150G']),
  mdl('1150H', 'H-Series Crawler Dozers', 'Heavy Equipment', DOZ, 1998, 2005, se('Case / CDC', '6T-590', 5.9, '6-Cyl Turbo', 119, 'Diesel', 'Powershift')),
  mdl('1150M', 'M-Series Crawler Dozers', 'Heavy Equipment', DOZ, 2013, 2026, se('FPT Industrial', 'NEF 6.7L', 6.7, '6-Cyl Turbo', 127, 'Diesel', 'Dual-Path Hydrostatic')),
  mdl('1650K', 'K-Series Crawler Dozers', 'Heavy Equipment', DOZ, 2002, 2008, se('Case', '6TAA-5904', 5.9, '6-Cyl Turbo', 144, 'Diesel', 'Dual-Path Hydrostatic')),
  mdl('1650M', 'M-Series Crawler Dozers', 'Heavy Equipment', DOZ, 2014, 2026, se('FPT Industrial', 'NEF 6.7L', 6.7, '6-Cyl Turbo', 150, 'Diesel', 'Dual-Path Hydrostatic')),
  mdl('2050M', 'M-Series Large Dozers', 'Heavy Equipment', DOZ, 2013, 2026, se('FPT Industrial', 'NEF 6.7L', 6.7, '6-Cyl Turbo', 214, 'Diesel', 'Dual-Path Hydrostatic')),
];

// ============================================================================
// 6. KUBOTA (1975–2026)
// ============================================================================
const KUBOTA_MODELS = [
  // Classic KH & KX Excavators (1975–2026)
  mdl('KH-60', 'KH Classic Mini Excavators', 'Heavy Equipment', EXC, 1979, 1990, se('Kubota', 'D1302', 1.3, '3-Cyl', 23), ['KH-18', 'KH-90', 'KH-151'], SOURCE_EPA_OEM),
  mdl('KX121-2', 'KX Series Compact Excavators', 'Heavy Equipment', EXC, 1994, 2002, se('Kubota', 'V2203', 2.2, '4-Cyl', 40), ['KX91-2', 'KX151'], SOURCE_EPA_OEM),
  mdl('KX121-3', 'KX-3 Compact Excavators', 'Heavy Equipment', EXC, 2003, 2013, se('Kubota', 'V2203-M', 2.2, '4-Cyl', 40), ['KX71-3', 'KX91-3'], SOURCE_EPA_OEM),
  mdl('KX161-3', 'KX-3 Compact Excavators', 'Heavy Equipment', EXC, 2003, 2013, se('Kubota', 'V2203-M / V2403', 2.4, '4-Cyl', 42), [], SOURCE_EPA_OEM),
  mdl('KX018-4', 'KX-4 Compact Excavators', 'Heavy Equipment', EXC, 2011, 2026, se('Kubota', 'D902-E4', 0.9, '3-Cyl', 16), ['K008-5'], SOURCE_EPA_OEM),
  mdl('KX033-4', 'KX-4 Compact Excavators', 'Heavy Equipment', EXC, 2016, 2026, se('Kubota', 'D1703-M-DI-E4', 1.6, '3-Cyl', 25), ['KX030-4'], SOURCE_EPA_OEM),
  mdl('KX040-4', 'KX-4 Compact Excavators', 'Heavy Equipment', EXC, 2014, 2024, se('Kubota', 'D1803-CR-TE4', 1.8, '3-Cyl Turbo', 40), [], SOURCE_EPA_OEM),
  mdl('KX040-5', 'KX-5 Compact Excavators', 'Heavy Equipment', EXC, 2024, 2026, se('Kubota', 'D1803-CR-TE5', 1.8, '3-Cyl Turbo', 40), [], SOURCE_EPA_OEM),
  mdl('KX057-4', 'KX-4 Compact Excavators', 'Heavy Equipment', EXC, 2011, 2020, se('Kubota', 'V2607-DI-E4', 2.6, '4-Cyl', 48), [], SOURCE_EPA_OEM),
  mdl('KX057-5', 'KX-5 Compact Excavators', 'Heavy Equipment', EXC, 2020, 2026, se('Kubota', 'V2607-CR-E5', 2.6, '4-Cyl', 48), [], SOURCE_EPA_OEM),
  mdl('KX080-4', 'KX-4 Mid-Size Excavators', 'Heavy Equipment', EXC, 2013, 2024, se('Kubota', 'V3307-CR-TE4', 3.3, '4-Cyl Turbo', 67), ['KX080-3', 'KX080-4s2'], SOURCE_EPA_OEM),
  mdl('KX080-5', 'KX-5 Mid-Size Excavators', 'Heavy Equipment', EXC, 2024, 2026, se('Kubota', 'V3307-CR-TE5', 3.3, '4-Cyl Turbo', 67), [], SOURCE_EPA_OEM),
  mdl('U35-3', 'U-Series Zero-Tail Excavators', 'Heavy Equipment', EXC, 2004, 2013, se('Kubota', 'D1703-M', 1.6, '3-Cyl', 29), ['U17', 'U25S'], SOURCE_EPA_OEM),
  mdl('U35-4', 'U-Series Zero-Tail Excavators', 'Heavy Equipment', EXC, 2013, 2026, se('Kubota', 'D1703-M-DI-E4', 1.6, '3-Cyl', 25), ['U48-5'], SOURCE_EPA_OEM),
  mdl('U55-4', 'U-Series Zero-Tail Excavators', 'Heavy Equipment', EXC, 2012, 2020, se('Kubota', 'V2607-DI-E4', 2.6, '4-Cyl', 48), [], SOURCE_EPA_OEM),
  mdl('U55-5', 'U-Series Zero-Tail Excavators', 'Heavy Equipment', EXC, 2020, 2026, se('Kubota', 'V2607-CR-E5', 2.6, '4-Cyl', 48), [], SOURCE_EPA_OEM),

  // SVL / SSV Compact Track Loaders & Skid Steers (2010–2026)
  mdl('SVL65-2', 'SVL Compact Track Loaders', 'Heavy Equipment', SSL, 2019, 2026, se('Kubota', 'V2607-CR-TE4', 2.6, '4-Cyl Turbo', 68, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('SVL75', 'SVL Compact Track Loaders', 'Heavy Equipment', SSL, 2010, 2014, se('Kubota', 'V3307-DI-TE3', 3.3, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('SVL75-2', 'SVL Compact Track Loaders', 'Heavy Equipment', SSL, 2014, 2023, se('Kubota', 'V3307-CR-TE4', 3.3, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('SVL75-3', 'SVL Compact Track Loaders', 'Heavy Equipment', SSL, 2023, 2026, se('Kubota', 'V3307-CR-TE5', 3.3, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('SVL90', 'SVL Compact Track Loaders', 'Heavy Equipment', SSL, 2010, 2013, se('Kubota', 'V3800-DI-TE3', 3.8, '4-Cyl Turbo', 90, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('SVL90-2', 'SVL Compact Track Loaders', 'Heavy Equipment', SSL, 2013, 2016, se('Kubota', 'V3800-CR-TE4', 3.8, '4-Cyl Turbo', 92, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('SVL95-2s', 'SVL Compact Track Loaders', 'Heavy Equipment', SSL, 2016, 2021, se('Kubota', 'V3800-TIEF4', 3.8, '4-Cyl Turbo', 96, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('SVL97-2', 'SVL Compact Track Loaders', 'Heavy Equipment', SSL, 2021, 2026, se('Kubota', 'V3800-TIEF4', 3.8, '4-Cyl Turbo', 96, 'Diesel', '2-Speed Hydrostatic'), ['SVL97-3'], SOURCE_EPA_OEM),
  mdl('SSV65', 'SSV Skid Steer Loaders', 'Heavy Equipment', SSL, 2015, 2026, se('Kubota', 'V2607-CR-TE4', 2.6, '4-Cyl Turbo', 64, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('SSV75', 'SSV Skid Steer Loaders', 'Heavy Equipment', SSL, 2015, 2026, se('Kubota', 'V3307-CR-TE4', 3.3, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),

  // Tractor-Loader-Backhoes, Compact Wheel Loaders & Utility (1990–2026)
  mdl('BX23S', 'BX Sub-Compact TLBs', 'Heavy Equipment', BKH, 2017, 2026, se('Kubota', 'D902', 0.9, '3-Cyl', 23, 'Diesel', '2-Range HST Hydrostatic'), ['BX22', 'BX24', 'BX25D'], SOURCE_EPA_OEM),
  mdl('B21', 'B-Series Compact TLBs', 'Heavy Equipment', BKH, 1997, 2007, se('Kubota', 'D1005-TLB', 1.0, '3-Cyl', 21, 'Diesel', '3-Range HST Hydrostatic'), ['B20'], SOURCE_EPA_OEM),
  mdl('B26', 'B-Series Compact TLBs', 'Heavy Equipment', BKH, 2007, 2026, se('Kubota', 'D1105-E4', 1.1, '3-Cyl', 26, 'Diesel', '3-Range HST Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('L39', 'L-Series TLBs', 'Heavy Equipment', BKH, 2005, 2013, se('Kubota', 'D1803-M', 1.8, '3-Cyl', 39, 'Diesel', '12F/8R GST Glide Shift'), ['L35'], SOURCE_EPA_OEM),
  mdl('L45', 'L-Series TLBs', 'Heavy Equipment', BKH, 2009, 2016, se('Kubota', 'V2003-M-T', 2.0, '4-Cyl Turbo', 45, 'Diesel', 'HST Plus Hydrostatic'), ['L48'], SOURCE_EPA_OEM),
  mdl('L47', 'L-Series TLBs', 'Heavy Equipment', BKH, 2016, 2026, se('Kubota', 'V2403-CR-E4', 2.4, '4-Cyl', 47, 'Diesel', 'HST Plus Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('M59', 'M-Series Commercial TLBs', 'Heavy Equipment', BKH, 2008, 2015, se('Kubota', 'V2403-M-TI', 2.4, '4-Cyl Turbo', 59, 'Diesel', 'HST Plus Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('M62', 'M-Series Commercial TLBs', 'Heavy Equipment', BKH, 2016, 2026, se('Kubota', 'V2403-CR-TE4', 2.4, '4-Cyl Turbo', 63, 'Diesel', 'HST Plus Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('R530', 'R-Series Wheel Loaders', 'Heavy Equipment', LDR, 1995, 2022, se('Kubota', 'V2403-CR', 2.4, '4-Cyl', 51, 'Diesel', 'Hydrostatic'), ['R420S', 'R520S', 'R540'], SOURCE_EPA_OEM),
  mdl('R640', 'R-Series Wheel Loaders', 'Heavy Equipment', LDR, 2020, 2026, se('Kubota', 'V2607-CR-TE5', 2.6, '4-Cyl Turbo', 64, 'Diesel', 'Hydrostatic'), ['R630'], SOURCE_EPA_OEM),
  mdl('RTV900', 'RTV Diesel Utility Work Vehicles', 'Heavy Equipment', LDR, 2004, 2014, se('Kubota', 'D902-E3', 0.9, '3-Cyl', 22, 'Diesel', 'VHT Plus Hydrostatic'), ['RTV-X900'], SOURCE_EPA_OEM),
  mdl('RTV-X1100C', 'RTV-X Cab Diesel Utility Work Vehicles', 'Heavy Equipment', LDR, 2014, 2026, se('Kubota', 'D1105-E4-UV', 1.1, '3-Cyl', 25, 'Diesel', 'VHT-X Variable Hydrostatic'), ['RTV1100', 'RTV-X1130'], SOURCE_EPA_OEM),
];

// ============================================================================
// 7. VOLVO CE (1970–2026, incl. Volvo BM / Michigan / Åkerman heritage)
// ============================================================================
const VOLVO_CE_MODELS = [
  // Volvo BM / L-Series Wheel Loaders (1970–2026)
  mdl('LM 841', 'Volvo BM Classic Loaders', 'Heavy Equipment', LDR, 1970, 1978, se('Volvo', 'D60A', 5.5, '6-Cyl', 112, 'Diesel', 'Powershift'), ['LM 641', '4300', '4400']),
  mdl('L70B', 'L70 Wheel Loaders', 'Heavy Equipment', LDR, 1986, 1995, se('Volvo', 'TD45B / TD61G', 5.5, '6-Cyl Turbo', 110, 'Diesel', 'Automatic Powershift'), ['L70', 'L-70']),
  mdl('L70C', 'L70 Wheel Loaders', 'Heavy Equipment', LDR, 1995, 2000, se('Volvo', 'TD63KDE', 5.5, '6-Cyl Turbo', 122, 'Diesel', 'APS Powershift'), ['L-70C']),
  mdl('L70D', 'L70 Wheel Loaders', 'Heavy Equipment', LDR, 2000, 2002, se('Volvo', 'TD63KGE', 5.5, '6-Cyl Turbo', 129, 'Diesel', 'APS Powershift')),
  mdl('L70E', 'L70 Wheel Loaders', 'Heavy Equipment', LDR, 2002, 2007, se('Volvo', 'D6D', 5.7, '6-Cyl Turbo', 152, 'Diesel', 'HTE Powershift')),
  mdl('L70F', 'L70 Wheel Loaders', 'Heavy Equipment', LDR, 2007, 2012, se('Volvo', 'D6E', 5.7, '6-Cyl Turbo', 168, 'Diesel', 'HTE Powershift')),
  mdl('L70G', 'L70 Wheel Loaders', 'Heavy Equipment', LDR, 2012, 2014, se('Volvo', 'D6H', 5.7, '6-Cyl Turbo', 170, 'Diesel', 'HTE Powershift')),
  mdl('L70H', 'L70 Wheel Loaders', 'Heavy Equipment', LDR, 2014, 2026, se('Volvo', 'D6J', 5.7, '6-Cyl Turbo', 173, 'Diesel', 'HTE 4-Speed Powershift')),
  mdl('L90B', 'L90 Wheel Loaders', 'Heavy Equipment', LDR, 1986, 1995, se('Volvo', 'TD61GB', 5.5, '6-Cyl Turbo', 148, 'Diesel', 'APS Powershift'), ['L90', 'L-90']),
  mdl('L90C', 'L90 Wheel Loaders', 'Heavy Equipment', LDR, 1995, 2000, se('Volvo', 'TD63KBE', 5.5, '6-Cyl Turbo', 153, 'Diesel', 'APS Powershift')),
  mdl('L90D', 'L90 Wheel Loaders', 'Heavy Equipment', LDR, 2000, 2002, se('Volvo', 'TD63KCE', 5.5, '6-Cyl Turbo', 160, 'Diesel', 'APS Powershift')),
  mdl('L90E', 'L90 Wheel Loaders', 'Heavy Equipment', LDR, 2002, 2007, se('Volvo', 'D6D', 5.7, '6-Cyl Turbo', 164, 'Diesel', 'HTE Powershift')),
  mdl('L90F', 'L90 Wheel Loaders', 'Heavy Equipment', LDR, 2007, 2012, se('Volvo', 'D6E', 5.7, '6-Cyl Turbo', 174, 'Diesel', 'HTE Powershift')),
  mdl('L90G', 'L90 Wheel Loaders', 'Heavy Equipment', LDR, 2011, 2014, se('Volvo', 'D6H', 5.7, '6-Cyl Turbo', 174, 'Diesel', 'HTE Powershift')),
  mdl('L90H', 'L90 Wheel Loaders', 'Heavy Equipment', LDR, 2014, 2026, se('Volvo', 'D6J', 5.7, '6-Cyl Turbo', 184, 'Diesel', 'OptiShift Powershift')),
  mdl('L120C', 'L120 Wheel Loaders', 'Heavy Equipment', LDR, 1995, 2001, se('Volvo', 'TD73KCE', 6.7, '6-Cyl Turbo', 201, 'Diesel', 'APS Powershift'), ['L120', 'L120B', 'L120D']),
  mdl('L120F', 'L120 Wheel Loaders', 'Heavy Equipment', LDR, 2007, 2011, se('Volvo', 'D7E', 7.1, '6-Cyl Turbo', 243, 'Diesel', 'HTE Powershift')),
  mdl('L120H', 'L120 Wheel Loaders', 'Heavy Equipment', LDR, 2014, 2026, se('Volvo', 'D8J', 7.8, '6-Cyl Turbo', 272, 'Diesel', 'OptiShift Powershift')),
  mdl('L150E', 'L150 Large Wheel Loaders', 'Heavy Equipment', LDR, 2002, 2007, se('Volvo', 'D9A / D10B', 9.4, '6-Cyl Turbo', 281, 'Diesel', 'HTE Powershift')),
  mdl('L150F', 'L150 Large Wheel Loaders', 'Heavy Equipment', LDR, 2007, 2011, se('Volvo', 'D12D', 12.1, '6-Cyl Turbo', 284, 'Diesel', 'HTE Powershift')),
  mdl('L150G', 'L150 Large Wheel Loaders', 'Heavy Equipment', LDR, 2011, 2014, se('Volvo', 'D13H', 12.8, '6-Cyl Turbo', 296, 'Diesel', 'OptiShift Powershift')),
  mdl('L150H', 'Large Wheel Loaders', 'Heavy Equipment', LDR, 2014, 2026, se('Volvo', 'D13J', 12.8, '6-Cyl Turbo', 295, 'Diesel', 'OptiShift Powershift')),

  // Articulated Haulers (1970–2026)
  mdl('BM 861', 'Volvo BM Classic Haulers', 'Transport & Hauling', ADT, 1970, 1986, se('Volvo', 'TD60B', 5.5, '6-Cyl Turbo', 170, 'Diesel', '4-Speed Powershift'), ['DR 860', '5350']),
  mdl('A25C', 'A-Series Articulated Haulers', 'Transport & Hauling', ADT, 1986, 2001, se('Volvo', 'TD73KCE', 6.7, '6-Cyl Turbo', 254, 'Diesel', 'PT 1562 Powershift'), ['A25', 'A25B']),
  mdl('A30C', 'A-Series Articulated Haulers', 'Transport & Hauling', ADT, 1993, 2001, se('Volvo', 'TD103KAE', 9.6, '6-Cyl Turbo', 315, 'Diesel', '6F/2R Powershift')),
  mdl('A30D', 'A-Series Articulated Haulers', 'Transport & Hauling', ADT, 2001, 2007, se('Volvo', 'D9A / D10B', 9.4, '6-Cyl Turbo', 324, 'Diesel', '6F/2R PowerTronic')),
  mdl('A30E', 'A-Series Articulated Haulers', 'Transport & Hauling', ADT, 2007, 2011, se('Volvo', 'D9B', 9.4, '6-Cyl Turbo', 343, 'Diesel', '6F/2R PowerTronic'), ['A30F']),
  mdl('A35D', 'A-Series Articulated Haulers', 'Transport & Hauling', ADT, 2000, 2007, se('Volvo', 'D12C', 12.1, '6-Cyl Turbo', 385, 'Diesel', 'PowerTronic Planetary'), ['A35C']),
  mdl('A35F', 'A-Series Articulated Haulers', 'Transport & Hauling', ADT, 2011, 2014, se('Volvo', 'D13H', 12.8, '6-Cyl Turbo', 441, 'Diesel', 'PowerTronic Planetary'), ['A35E']),
  mdl('A35G', 'G-Series Articulated Haulers', 'Transport & Hauling', ADT, 2014, 2026, se('Volvo', 'D13J', 12.8, '6-Cyl Turbo', 447, 'Diesel', 'PowerTronic Planetary')),
  mdl('A40D', 'A40 Articulated Haulers', 'Transport & Hauling', ADT, 2000, 2007, se('Volvo', 'D12C', 12.1, '6-Cyl Turbo', 420, 'Diesel', '6F/2R PowerTronic')),
  mdl('A40E', 'A40 Articulated Haulers', 'Transport & Hauling', ADT, 2007, 2011, se('Volvo', 'D16E', 16.1, '6-Cyl Turbo', 464, 'Diesel', '9F/3R PowerTronic')),
  mdl('A40F', 'A40 Articulated Haulers', 'Transport & Hauling', ADT, 2011, 2014, se('Volvo', 'D16F', 16.1, '6-Cyl Turbo', 465, 'Diesel', '9F/3R PowerTronic')),
  mdl('A40G', 'A40 Articulated Haulers', 'Transport & Hauling', ADT, 2014, 2026, se('Volvo', 'D16J', 16.1, '6-Cyl Turbo', 469, 'Diesel', '9F/3R PowerTronic'), ['A40G FS']),
  mdl('A45G', 'A45 Articulated Haulers', 'Transport & Hauling', ADT, 2016, 2026, se('Volvo', 'D16J', 16.1, '6-Cyl Turbo', 469, 'Diesel', '9F/3R PowerTronic'), ['A45G FS', 'A60H']),

  // Excavators (1998–2026)
  mdl('EC18E', 'Compact Excavators', 'Heavy Equipment', EXC, 2018, 2026, se('Volvo / Kubota', 'D0.9A', 0.9, '3-Cyl', 16), ['EC18D', 'ECR25D'], SOURCE_EPA_OEM),
  mdl('ECR58', 'Short-Swing Compact Excavators', 'Heavy Equipment', EXC, 2004, 2013, se('Volvo / Yanmar', 'D3.1A', 3.1, '4-Cyl', 50), [], SOURCE_EPA_OEM),
  mdl('ECR58D', 'D-Series Short-Swing Excavators', 'Heavy Equipment', EXC, 2013, 2021, se('Volvo', 'D2.6A', 2.6, '4-Cyl Turbo', 48), ['ECR88D'], SOURCE_EPA_OEM),
  mdl('ECR58F', 'F-Series Short-Swing Excavators', 'Heavy Equipment', EXC, 2021, 2026, se('Volvo', 'D2.6H', 2.6, '4-Cyl Turbo', 48), [], SOURCE_EPA_OEM),
  mdl('EC140B', 'EC-B Crawler Excavators', 'Heavy Equipment', EXC, 2001, 2007, se('Volvo', 'D4D', 4.0, '4-Cyl Turbo', 98)),
  mdl('EC140C', 'EC-C Crawler Excavators', 'Heavy Equipment', EXC, 2007, 2012, se('Volvo', 'D4E', 4.0, '4-Cyl Turbo', 99)),
  mdl('EC140E', 'EC-E Crawler Excavators', 'Heavy Equipment', EXC, 2015, 2026, se('Volvo', 'D4J', 4.0, '4-Cyl Turbo', 121)),
  mdl('EC210B', 'EC Series Crawler Excavators', 'Heavy Equipment', EXC, 2002, 2008, se('Volvo', 'D6D', 5.7, '6-Cyl Turbo', 143)),
  mdl('EC210C', 'EC Series Crawler Excavators', 'Heavy Equipment', EXC, 2008, 2012, se('Volvo', 'D6E', 5.7, '6-Cyl Turbo', 148)),
  mdl('EC210D', 'EC Series Crawler Excavators', 'Heavy Equipment', EXC, 2012, 2020, se('Volvo', 'D5E', 4.8, '4-Cyl Turbo', 154)),
  mdl('EC220D', 'EC Series Crawler Excavators', 'Heavy Equipment', EXC, 2011, 2015, se('Volvo', 'D6H', 5.7, '6-Cyl Turbo', 173)),
  mdl('EC220E', 'EC-E Series Crawler Excavators', 'Heavy Equipment', EXC, 2015, 2026, se('Volvo', 'D6J', 5.7, '6-Cyl Turbo', 172), ['EC230F']),
  mdl('EC300D', 'EC Series Crawler Excavators', 'Heavy Equipment', EXC, 2011, 2015, se('Volvo', 'D8H', 7.8, '6-Cyl Turbo', 227), ['EC290B', 'EC290C']),
  mdl('EC300E', 'EC-E Series Crawler Excavators', 'Heavy Equipment', EXC, 2015, 2026, se('Volvo', 'D8J', 7.8, '6-Cyl Turbo', 240)),
  mdl('EC350E', 'EC-E Series Crawler Excavators', 'Heavy Equipment', EXC, 2014, 2026, se('Volvo', 'D8J / D13J', 7.8, '6-Cyl Turbo', 299), ['EC340D']),
  mdl('EC380E', 'EC-E Series Crawler Excavators', 'Heavy Equipment', EXC, 2014, 2026, se('Volvo', 'D13J', 12.8, '6-Cyl Turbo', 306), ['EC360B', 'EC380D']),
  mdl('EC480E', 'EC-E Series Crawler Excavators', 'Heavy Equipment', EXC, 2014, 2026, se('Volvo', 'D13J', 12.8, '6-Cyl Turbo', 373), ['EC460B', 'EC480D']),
];

// ============================================================================
// 8. HITACHI (1970–2026)
// ============================================================================
const HITACHI_MODELS = [
  // Classic UH & EX Series (1970–2002)
  mdl('UH07', 'UH Classic Excavators', 'Heavy Equipment', EXC, 1972, 1985, se('Isuzu', '6BD1', 5.8, '6-Cyl', 105), ['UH 07LC', 'UH062']),
  mdl('UH083', 'UH Classic Excavators', 'Heavy Equipment', EXC, 1983, 1988, se('Hino / Isuzu', 'H07C-T / 6BD1T', 6.7, '6-Cyl Turbo', 123), ['UH122', 'UH172']),
  mdl('EX120', 'EX Series Excavators', 'Heavy Equipment', EXC, 1987, 2001, se('Isuzu', '4BD1T', 3.9, '4-Cyl Turbo', 84), ['EX120-2', 'EX120-3', 'EX120-5', 'EX150']),
  mdl('EX200-1', 'EX200 Series Excavators', 'Heavy Equipment', EXC, 1987, 1991, se('Isuzu', '6BD1T', 5.8, '6-Cyl Turbo', 125), ['EX 200 LC']),
  mdl('EX200-2', 'EX200 Series Excavators', 'Heavy Equipment', EXC, 1991, 1993, se('Isuzu', '6BD1T', 5.8, '6-Cyl Turbo', 133), ['EX200LC-2']),
  mdl('EX200-3', 'EX200 Series Excavators', 'Heavy Equipment', EXC, 1993, 1996, se('Isuzu', '6BD1T', 5.8, '6-Cyl Turbo', 135), ['EX200LC-3']),
  mdl('EX200-5', 'EX200 Super Series Excavators', 'Heavy Equipment', EXC, 1996, 2001, se('Isuzu', '6BG1T', 6.5, '6-Cyl Turbo', 138), ['EX200LC-5', 'EX270']),
  mdl('EX300-3', 'EX300 Series Excavators', 'Heavy Equipment', EXC, 1988, 2001, se('Isuzu', '6SD1T', 9.8, '6-Cyl Turbo', 217), ['EX300-2', 'EX330LC-5']),
  mdl('EX400', 'EX400 Heavy Excavators', 'Heavy Equipment', EXC, 1988, 2001, se('Isuzu', '6RB1T', 13.7, '6-Cyl Turbo', 296), ['EX400LC-3', 'EX450LC-5']),

  // ZAXIS (ZX) Excavators & ZW Wheel Loaders (2001–2026)
  mdl('ZX50U-5N', 'ZAXIS Compact Excavators', 'Heavy Equipment', EXC, 2014, 2026, se('Yanmar', '4TNV88C', 2.2, '4-Cyl', 36), ['ZX35U-5N', 'ZX60USB-5N'], SOURCE_EPA_OEM),
  mdl('ZX85USB-5N', 'ZAXIS Mid-Size Excavators', 'Heavy Equipment', EXC, 2014, 2026, se('Yanmar', '4TNV98CT', 3.3, '4-Cyl Turbo', 57), ['ZX75US-5N', 'ZX85USB-7'], SOURCE_EPA_OEM),
  mdl('ZX135US-6', 'ZAXIS Short-Tail Excavators', 'Heavy Equipment', EXC, 2016, 2026, se('Isuzu', '4JJ1', 3.0, '4-Cyl Turbo', 101), ['ZX135US-5N', 'ZX135US-7', 'ZX160LC-6']),
  mdl('ZX200-3', 'ZAXIS-3 Excavators', 'Heavy Equipment', EXC, 2006, 2012, se('Isuzu', '4HK1X', 5.2, '4-Cyl Turbo', 164), ['ZX200LC-3', 'ZX200']),
  mdl('ZX210LC-5', 'ZAXIS-5 Excavators', 'Heavy Equipment', EXC, 2012, 2016, se('Isuzu', '4HK1X', 5.2, '4-Cyl Turbo', 159), ['ZX210-5N']),
  mdl('ZX210LC-6', 'ZAXIS-6 Excavators', 'Heavy Equipment', EXC, 2016, 2022, se('Isuzu', '4HK1', 5.2, '4-Cyl Turbo', 164), ['ZX245USLC-6', 'ZX250LC-6']),
  mdl('ZX210LC-7', 'ZAXIS-7 Excavators', 'Heavy Equipment', EXC, 2022, 2026, se('Isuzu', '4HK1', 5.2, '4-Cyl Turbo', 164), ['ZX210-7', 'ZX245USLC-7']),
  mdl('ZX300LC-6', 'ZAXIS-6 Excavators', 'Heavy Equipment', EXC, 2016, 2026, se('Isuzu', '6HK1', 7.8, '6-Cyl Turbo', 249), ['ZX290LC-5N', 'ZX300LC-7']),
  mdl('ZX350LC-5', 'ZAXIS-5 Excavators', 'Heavy Equipment', EXC, 2012, 2016, se('Isuzu', '6HK1X', 7.8, '6-Cyl Turbo', 271), ['ZX350LC-3']),
  mdl('ZX350LC-6', 'ZAXIS-6 Excavators', 'Heavy Equipment', EXC, 2016, 2022, se('Isuzu', '6HK1', 7.8, '6-Cyl Turbo', 271)),
  mdl('ZX350LC-7', 'ZAXIS-7 Excavators', 'Heavy Equipment', EXC, 2022, 2026, se('Isuzu', '6HK1', 7.8, '6-Cyl Turbo', 271)),
  mdl('ZX490LC-6', 'ZAXIS Heavy Excavators', 'Heavy Equipment', EXC, 2015, 2026, se('Isuzu', '6UZ1', 9.8, '6-Cyl Turbo', 362), ['ZX470LC-5', 'ZX490LC-7', 'ZX690LC-6']),
  mdl('ZW180-6', 'ZW Series Wheel Loaders', 'Heavy Equipment', LDR, 2015, 2026, se('Cummins', 'QSB6.7', 6.7, '6-Cyl Turbo', 173, 'Diesel', '5-Speed Torque Converter Powershift'), ['ZW150-6', 'ZW180-5'], SOURCE_EPA_OEM),
  mdl('ZW220-6', 'ZW Series Wheel Loaders', 'Heavy Equipment', LDR, 2016, 2026, se('Cummins', 'QSB6.7', 6.7, '6-Cyl Turbo', 200, 'Diesel', '5-Speed Torque Converter Powershift'), ['ZW220-5', 'ZW220-7'], SOURCE_EPA_OEM),
  mdl('ZW310-6', 'ZW Series Wheel Loaders', 'Heavy Equipment', LDR, 2016, 2026, se('Cummins', 'QSL9', 8.9, '6-Cyl Turbo', 298, 'Diesel', '5-Speed Torque Converter Powershift'), ['ZW310-5', 'ZW370-6'], SOURCE_EPA_OEM),
];

// ============================================================================
// 9. JCB (1970–2026)
// ============================================================================
const JCB_MODELS = [
  // Iconic Backhoes (1970–2026)
  mdl('3C', 'Classic Backhoe Loaders', 'Heavy Equipment', BKH, 1970, 1980, se('Leyland / Perkins', '4/98NT / 4.236', 3.8, '4-Cyl', 70, 'Diesel', '4-Speed Synchromesh'), ['3C II', '3C III'], SOURCE_EPA_OEM),
  mdl('3D', 'Classic Backhoe Loaders', 'Heavy Equipment', BKH, 1970, 1981, se('Leyland / Perkins', '4/98NT', 3.8, '4-Cyl', 75, 'Diesel', 'Torque Converter Shuttle'), [], SOURCE_EPA_OEM),
  mdl('1400B', 'North American Backhoe Series', 'Heavy Equipment', BKH, 1985, 1992, se('Perkins', '4.236', 3.9, '4-Cyl', 74, 'Diesel', '4-Speed Syncro Shuttle'), ['1550B', '1700B'], SOURCE_EPA_OEM),
  mdl('214', '200 Series Backhoe Loaders', 'Heavy Equipment', BKH, 1991, 2005, se('Perkins', '1004.4 / 1004.4T', 4.0, '4-Cyl Turbo', 82, 'Diesel', 'Powershift Shuttle'), ['214S', '214E'], SOURCE_EPA_OEM),
  mdl('215', '200 Series Backhoe Loaders', 'Heavy Equipment', BKH, 1992, 2005, se('Perkins', '1004.4T', 4.0, '4-Cyl Turbo', 96, 'Diesel', 'Powershift'), ['215S', '217'], SOURCE_EPA_OEM),
  mdl('3CX', '3CX Backhoe Loaders', 'Heavy Equipment', BKH, 1981, 2026, [
    eng('Perkins', '4.236 / 1004.4T', 4.0, '4-Cyl Turbo', 85, 'Diesel', '4-Speed Syncroshuttle', 1981, 2004),
    eng('JCB', 'Dieselmax 444', 4.4, '4-Cyl Turbo', 92, 'Diesel', '4-Speed Powershift', 2005, 2014),
    eng('JCB', 'EcoMAX 448 / 430', 4.8, '4-Cyl Turbo', 109, 'Diesel', '6-Speed AutoShift', 2015, 2026),
  ], ['3CX-14', '3CX Super', '3CX Pro'], SOURCE_EPA_OEM),
  mdl('4CX', '4CX Equal-Wheel Backhoe Loaders', 'Heavy Equipment', BKH, 1991, 2026, [
    eng('Perkins', '1004.4T', 4.0, '4-Cyl Turbo', 100, 'Diesel', '4-Speed Powershift', 1991, 2004),
    eng('JCB', 'Dieselmax / EcoMAX 448', 4.8, '4-Cyl Turbo', 109, 'Diesel', '6-Speed AutoShift', 2005, 2026),
  ], ['4CX-15', '5CX'], SOURCE_EPA_OEM),

  // Excavators, Telehandlers & Skid Steers (1985–2026)
  mdl('85Z-1', 'Compact Excavators', 'Heavy Equipment', EXC, 2014, 2026, se('JCB / Kohler', 'Diesel by Kohler KDI 2504TCR', 2.5, '4-Cyl Turbo', 64), ['8035 ZTS', '50Z-1', '86C-1'], SOURCE_EPA_OEM),
  mdl('JS130', 'JS Series Excavators', 'Heavy Equipment', EXC, 1998, 2022, se('Isuzu / JCB', 'EcoMAX 444', 4.4, '4-Cyl Turbo', 109), ['JS145W', 'JS160'], SOURCE_EPA_OEM),
  mdl('JS200', 'JS Series Excavators', 'Heavy Equipment', EXC, 1995, 2016, se('Isuzu', '4HK1X / 6BG1', 5.2, '4-Cyl Turbo', 172), ['JS210'], SOURCE_EPA_OEM),
  mdl('JS220', 'JS Series Excavators', 'Heavy Equipment', EXC, 2002, 2020, se('JCB', 'EcoMAX 448', 4.8, '4-Cyl Turbo', 173), ['JS220LC'], SOURCE_EPA_OEM),
  mdl('220X', 'X-Series Crawler Excavators', 'Heavy Equipment', EXC, 2018, 2026, se('JCB', 'EcoMAX 448', 4.8, '4-Cyl Turbo', 173), ['140X', '245XR'], SOURCE_EPA_OEM),
  mdl('506-36', 'Loadall Telehandlers', 'Heavy Equipment', TLH, 1988, 2026, se('JCB', 'EcoMAX 4.4 / Kohler 2.5L', 4.4, '4-Cyl Turbo', 74, 'Diesel', '4-Speed Powershift'), ['506C', '506B'], SOURCE_EPA_OEM),
  mdl('507-42', 'Loadall Telehandlers', 'Heavy Equipment', TLH, 2005, 2026, se('JCB', 'EcoMAX 444', 4.4, '4-Cyl Turbo', 74, 'Diesel', '4-Speed Powershift'), ['508C'], SOURCE_EPA_OEM),
  mdl('509-42', 'Loadall Telehandlers', 'Heavy Equipment', TLH, 2006, 2026, se('JCB', 'EcoMAX 444', 4.4, '4-Cyl Turbo', 109, 'Diesel', '4-Speed Powershift'), [], SOURCE_EPA_OEM),
  mdl('510-56', 'Loadall Telehandlers', 'Heavy Equipment', TLH, 2007, 2026, se('JCB', 'EcoMAX 448', 4.8, '4-Cyl Turbo', 109, 'Diesel', '4-Speed Powershift'), [], SOURCE_EPA_OEM),
  mdl('512-56', 'Loadall Telehandlers', 'Heavy Equipment', TLH, 2012, 2026, se('JCB', 'EcoMAX 448', 4.8, '4-Cyl Turbo', 109, 'Diesel', '4-Speed Powershift'), ['514-56'], SOURCE_EPA_OEM),
  mdl('540-170', 'Loadall High-Reach Telehandlers', 'Heavy Equipment', TLH, 2002, 2026, se('JCB', 'Dieselmax / EcoMAX 444', 4.4, '4-Cyl Turbo', 109, 'Diesel', '4-Speed Powershift'), ['540-200', '541-70'], SOURCE_EPA_OEM),
  mdl('260', 'PowerBoom Skid Steers', 'Heavy Equipment', SSL, 2011, 2022, se('JCB / Kohler', 'EcoMAX 444 / KDI 2504', 2.5, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), ['270'], SOURCE_EPA_OEM),
  mdl('270T', 'PowerBoom Compact Track Loaders', 'Heavy Equipment', SSL, 2017, 2026, se('JCB / Kohler', 'KDI 2504TCR', 2.5, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), ['215T'], SOURCE_EPA_OEM),
  mdl('300T', 'PowerBoom Compact Track Loaders', 'Heavy Equipment', SSL, 2012, 2026, se('JCB', 'EcoMAX 444', 4.4, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), ['320T', '3TS-8T'], SOURCE_EPA_OEM),
  mdl('457', 'Wheel Loaders', 'Heavy Equipment', LDR, 2012, 2026, se('Cummins / MTU', 'B6.7 / 6R1000', 6.7, '6-Cyl Turbo', 282, 'Diesel', '5-Speed ZF Powershift'), ['427', '437'], SOURCE_EPA_OEM),
];

// ============================================================================
// 10. NEW HOLLAND (1972–2026)
// ============================================================================
const NEW_HOLLAND_MODELS = [
  // Super Boom Skid Steers & CTLs (1972–2026)
  mdl('L35', 'Classic Super Boom Skid Steers', 'Heavy Equipment', SSL, 1972, 1981, se('Wisconsin', 'VG4D', 2.5, 'V4 Air-Cooled', 37, 'Gasoline', 'Hydrostatic'), ['L775'], SOURCE_EPA_OEM),
  mdl('L555', '500 Series Skid Steers', 'Heavy Equipment', SSL, 1981, 1993, se('Kubota', 'V1902', 1.9, '4-Cyl', 42, 'Diesel', 'Hydrostatic'), ['L445', 'L553', 'L785'], SOURCE_EPA_OEM),
  mdl('LX665', 'LX Series Super Boom Skid Steers', 'Heavy Equipment', SSL, 1994, 1999, se('New Holland / ISM', 'N844T', 2.2, '4-Cyl Turbo', 50, 'Diesel', 'Hydrostatic'), ['LX565', 'LX865', 'LX885'], SOURCE_EPA_OEM),
  mdl('LS180', 'LS Series Super Boom Skid Steers', 'Heavy Equipment', SSL, 1999, 2006, se('New Holland', '332T', 3.2, '3-Cyl Turbo', 73, 'Diesel', '2-Speed Hydrostatic'), ['LS160', 'LS170', 'LS180B', 'LS190'], SOURCE_EPA_OEM),
  mdl('L220', '200 Series Skid Steers', 'Heavy Equipment', SSL, 2011, 2020, se('ISM / FPT', 'N844LTA / F5C', 3.4, '4-Cyl Turbo', 67, 'Diesel', '2-Speed Hydrostatic'), ['L218', 'L225'], SOURCE_EPA_OEM),
  mdl('L228', '200 Series Skid Steers', 'Heavy Equipment', SSL, 2015, 2020, se('FPT Industrial', 'F5C', 3.4, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), ['L230', 'L234'], SOURCE_EPA_OEM),
  mdl('L328', '300 Series Skid Steers', 'Heavy Equipment', SSL, 2020, 2026, se('FPT Industrial', 'F5C', 3.4, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), ['L320', 'L334'], SOURCE_EPA_OEM),
  mdl('C232', '200 Series Compact Track Loaders', 'Heavy Equipment', SSL, 2011, 2020, se('FPT Industrial', 'F5C', 3.4, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), ['C185', 'C227'], SOURCE_EPA_OEM),
  mdl('C238', '200 Series Compact Track Loaders', 'Heavy Equipment', SSL, 2011, 2020, se('FPT Industrial', 'F5BFL413A', 3.4, '4-Cyl Turbo', 90, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('C337', '300 Series Compact Track Loaders', 'Heavy Equipment', SSL, 2020, 2026, se('FPT Industrial', 'F5C', 3.4, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), ['C327', 'C332'], SOURCE_EPA_OEM),
  mdl('C345', '300 Series Compact Track Loaders', 'Heavy Equipment', SSL, 2020, 2026, se('FPT Industrial', 'F5BFL413A', 3.4, '4-Cyl Turbo', 90, 'Diesel', '2-Speed High-Flow Hydrostatic'), ['C362'], SOURCE_EPA_OEM),

  // Backhoes, Excavators & Loaders (1995–2026)
  mdl('555E', 'Ford / New Holland Classic Backhoes', 'Heavy Equipment', BKH, 1996, 2000, se('Ford / Genesis', '304T', 5.0, '4-Cyl Turbo', 75, 'Diesel', '4-Speed Power Reversing'), ['545D', '575E', '655E', '675E']),
  mdl('LB75B', 'LB Series Backhoe Loaders', 'Heavy Equipment', BKH, 2001, 2006, se('CNH / Iveco', '445T/M2', 4.5, '4-Cyl Turbo', 88, 'Diesel', '4-Speed Powershuttle'), ['LB90B', 'LB115B']),
  mdl('B95B', 'B-Series Backhoe Loaders', 'Heavy Equipment', BKH, 2008, 2012, se('FPT Industrial', 'F4GE9484', 4.5, '4-Cyl Turbo', 95, 'Diesel', 'Powershuttle')),
  mdl('B95C', 'C-Series Backhoe Loaders', 'Heavy Equipment', BKH, 2012, 2020, se('FPT Industrial', 'F5C', 3.4, '4-Cyl Turbo', 95, 'Diesel', '4-Speed Powershift'), ['B95C TC', 'B110C']),
  mdl('B75D', 'D-Series Backhoe Loaders', 'Heavy Equipment', BKH, 2020, 2026, se('FPT Industrial', 'F36 Stage V', 3.6, '4-Cyl Turbo', 74, 'Diesel', '4-Speed Powershuttle')),
  mdl('B95D', 'D-Series Backhoe Loaders', 'Heavy Equipment', BKH, 2020, 2026, se('FPT Industrial', 'F36 Stage V', 3.6, '4-Cyl Turbo', 97, 'Diesel', '4-Speed Powershift')),
  mdl('B110D', 'D-Series Backhoe Loaders', 'Heavy Equipment', BKH, 2020, 2026, se('FPT Industrial', 'F36 Stage V', 3.6, '4-Cyl Turbo', 110, 'Diesel', '4-Speed AutoShift')),
  mdl('E35B', 'E-Series Compact Excavators', 'Heavy Equipment', EXC, 2008, 2017, se('Yanmar', '3TNV88', 1.6, '3-Cyl', 27), ['E37C'], SOURCE_EPA_OEM),
  mdl('E57C', 'C-Series Compact Excavators', 'Heavy Equipment', EXC, 2017, 2026, se('Kubota / Yanmar', 'V2607 / 4TNV98C', 2.6, '4-Cyl', 45), ['E60C'], SOURCE_EPA_OEM),
  mdl('W170D', 'W-Series Wheel Loaders', 'Heavy Equipment', LDR, 2006, 2026, se('FPT Industrial', 'NEF 6.7L', 6.7, '6-Cyl Turbo', 197, 'Diesel', '5-Speed Powershift'), ['W170B', 'W170C', 'W190D'], SOURCE_EPA_OEM),
];

// ============================================================================
// 11. KOBELCO (1975–2026)
// ============================================================================
const KOBELCO_MODELS = [
  mdl('K904D', 'Classic K-Series Excavators', 'Heavy Equipment', EXC, 1978, 1989, se('Mitsubishi / Isuzu', '6D14T', 6.6, '6-Cyl Turbo', 88), ['K903B', 'K904E', 'K905']),
  mdl('K907C', 'Classic K-Series Excavators', 'Heavy Equipment', EXC, 1978, 1990, se('Mitsubishi', '6D15T', 6.9, '6-Cyl Turbo', 128), ['K907D', 'K907 LC']),
  mdl('K909A', 'Classic K-Series Excavators', 'Heavy Equipment', EXC, 1980, 1990, se('Mitsubishi', '6D22T', 11.1, '6-Cyl Turbo', 168), ['K909 LC', 'K912A', 'K914']),
  mdl('SK200LC Mark III', 'Mark III / IV Excavators', 'Heavy Equipment', EXC, 1990, 1998, se('Mitsubishi', '6D31T / 6D34T', 5.9, '6-Cyl Turbo', 133), ['SK200LC MARK III', 'SK200-3', 'SK200LC-IV']),
  mdl('SK270LC Mark IV', 'Mark IV Excavators', 'Heavy Equipment', EXC, 1993, 1999, se('Mitsubishi', '6D16T', 7.5, '6-Cyl Turbo', 182), ['SK270LC MARK IV']),
  mdl('SK400LC Mark IV', 'Mark IV Heavy Excavators', 'Heavy Equipment', EXC, 1993, 2000, se('Mitsubishi', '6D22TC', 11.1, '6-Cyl Turbo', 285), ['SK400LC MARK IV']),
  mdl('SK35SR-6E', 'SR Short-Radius Mini Excavators', 'Heavy Equipment', EXC, 2005, 2026, se('Yanmar', '3TNV88F', 1.6, '3-Cyl', 23), ['SK30SR', 'SK35SR-5'], SOURCE_EPA_OEM),
  mdl('SK55SRX-7', 'SR Short-Radius Mini Excavators', 'Heavy Equipment', EXC, 2019, 2026, se('Yanmar', '4TNV88C', 2.2, '4-Cyl', 37), ['SK55SRX-6E'], SOURCE_EPA_OEM),
  mdl('SK75SR-7', 'SR Mid-Size Excavators', 'Heavy Equipment', EXC, 2013, 2026, se('Yanmar', '4TNV98CT', 3.3, '4-Cyl Turbo', 70), ['SK75SR-3E', 'SK85CS-7'], SOURCE_EPA_OEM),
  mdl('SK140SRLC-5', 'SR Short-Radius Excavators', 'Heavy Equipment', EXC, 2016, 2020, se('Isuzu', '4JJ1X', 3.0, '4-Cyl Turbo', 105), ['SK140SRLC-3'], SOURCE_EPA_OEM),
  mdl('SK140SRLC-7', 'SR-7 Short-Radius Excavators', 'Heavy Equipment', EXC, 2020, 2026, se('Isuzu', '4JJ1X', 3.0, '4-Cyl Turbo', 105), [], SOURCE_EPA_OEM),
  mdl('SK170LC-10', 'SK-10 Crawler Excavators', 'Heavy Equipment', EXC, 2016, 2020, se('Isuzu', '4JJ1X', 3.0, '4-Cyl Turbo', 127), ['SK170LC-8', 'SK170LC-9'], SOURCE_EPA_OEM),
  mdl('SK170LC-11', 'SK-11 Crawler Excavators', 'Heavy Equipment', EXC, 2021, 2026, se('Isuzu', '4JJ1X', 3.0, '4-Cyl Turbo', 127), [], SOURCE_EPA_OEM),
  mdl('SK210LC-8', 'SK-8 / -9 Series Excavators', 'Heavy Equipment', EXC, 2006, 2015, se('Hino', 'J05E-TA', 5.1, '4-Cyl Turbo', 157), ['SK210LC-9'], SOURCE_EPA_OEM),
  mdl('SK210LC-10', 'SK-10 Series Excavators', 'Heavy Equipment', EXC, 2016, 2020, se('Hino', 'J05E-UM', 5.1, '4-Cyl Turbo', 160), [], SOURCE_EPA_OEM),
  mdl('SK210LC-11', 'SK-11 Series Excavators', 'Heavy Equipment', EXC, 2021, 2026, se('Yanmar / Hino', '4TN107FHT', 4.6, '4-Cyl Twin-Turbo', 160), ['SK210-11'], SOURCE_EPA_OEM),
  mdl('SK260LC-11', 'SK-11 Crawler Excavators', 'Heavy Equipment', EXC, 2021, 2026, se('Hino', 'J05E', 5.1, '4-Cyl Turbo', 182), ['SK270SRLC-5'], SOURCE_EPA_OEM),
  mdl('SK300LC-11', 'SK Series Crawler Excavators', 'Heavy Equipment', EXC, 2016, 2026, se('Hino', 'J08E-YD', 7.7, '6-Cyl Turbo', 252), ['SK300LC-10'], SOURCE_EPA_OEM),
  mdl('SK350LC-8', 'SK-8 / -9 Series Excavators', 'Heavy Equipment', EXC, 2007, 2015, se('Hino', 'J08E-TM', 7.7, '6-Cyl Turbo', 270), ['SK350LC-9'], SOURCE_EPA_OEM),
  mdl('SK350LC-10', 'SK-10 Series Excavators', 'Heavy Equipment', EXC, 2016, 2020, se('Hino', 'J08E-UV', 7.7, '6-Cyl Turbo', 270), [], SOURCE_EPA_OEM),
  mdl('SK350LC-11', 'SK-11 Series Excavators', 'Heavy Equipment', EXC, 2021, 2026, se('Isuzu / Hino', '6HK1X', 7.8, '6-Cyl Turbo', 270), [], SOURCE_EPA_OEM),
  mdl('SK500LC-11', 'SK Heavy Excavators', 'Heavy Equipment', EXC, 2016, 2026, se('Hino', 'E13C / P11C', 10.5, '6-Cyl Turbo', 369), ['SK500LC-10'], SOURCE_EPA_OEM),
  mdl('SK850LC-10', 'SK Mass Excavators', 'Heavy Equipment', EXC, 2017, 2026, se('Hino', 'E13C-YV', 12.9, '6-Cyl Turbo', 510), ['SK850LC'], SOURCE_EPA_OEM),
];

// ============================================================================
// 12. LINK-BELT (1970–2026)
// ============================================================================
const LINK_BELT_MODELS = [
  mdl('LS-98', 'Classic Lattice Crawler Cranes', 'Heavy Equipment', CRN, 1970, 1995, se('Detroit Diesel / GM', '4-71N', 4.7, '4-Cyl 2-Stroke', 110, 'Diesel', 'Friction Clutch Mechanical'), ['LS-108B', 'LS-318']),
  mdl('LS-2800', 'LS Series Hydraulic Excavators', 'Heavy Equipment', EXC, 1978, 1994, se('Isuzu', '6BD1T', 5.8, '6-Cyl Turbo', 122), ['LS 2800A', 'LS-3400', 'LS-4300']),
  mdl('2700 Quantum', 'Quantum Series Excavators', 'Heavy Equipment', EXC, 1994, 1999, se('Isuzu', '4BD1T / 6BG1', 5.8, '6-Cyl Turbo', 125), ['2800 Quantum', '3400 Quantum']),
  mdl('160 LX', 'LX Series Excavators', 'Heavy Equipment', EXC, 2001, 2007, se('Isuzu', '4JJ1X', 3.0, '4-Cyl Turbo', 112), ['130 LX']),
  mdl('210 LX', 'LX Series Excavators', 'Heavy Equipment', EXC, 2001, 2007, se('Isuzu', '4HK1X', 5.2, '4-Cyl Turbo', 143), ['240 LX', '290 LX', '330 LX']),
  mdl('135 Spin Ace', 'Spin Ace Short-Radius Excavators', 'Heavy Equipment', EXC, 2003, 2012, se('Isuzu', '4JJ1X', 3.0, '4-Cyl Turbo', 95), ['75 Spin Ace', '225 Spin Ace']),
  mdl('145 X3', 'X3 / X4 Spin Ace Excavators', 'Heavy Equipment', EXC, 2012, 2021, se('Isuzu', '4JJ1X', 3.0, '4-Cyl Turbo', 102), ['145 X4']),
  mdl('145 X4S', 'X4S Series Excavators', 'Heavy Equipment', EXC, 2022, 2026, se('Isuzu', '4JJ1X Tier 4F', 3.0, '4-Cyl Turbo', 102), [], SOURCE_EPA_OEM),
  mdl('160 X4', 'X2 / X3 / X4 Excavators', 'Heavy Equipment', EXC, 2008, 2026, se('Isuzu', '4JJ1X', 3.0, '4-Cyl Turbo', 120), ['160 X2', '160 X3', '160 X4S']),
  mdl('210 X2', 'X2 / X3 Series Excavators', 'Heavy Equipment', EXC, 2007, 2015, se('Isuzu', '4HK1X', 5.2, '4-Cyl Turbo', 157), ['210 X3']),
  mdl('210 X4', 'X4 Series Excavators', 'Heavy Equipment', EXC, 2015, 2022, se('Isuzu', '4HK1X', 5.2, '4-Cyl Turbo', 160)),
  mdl('210 X4S', 'X4S Series Excavators', 'Heavy Equipment', EXC, 2022, 2026, se('Isuzu', '4HK1X Tier 4F', 5.2, '4-Cyl Turbo', 160), ['220 X4S'], SOURCE_EPA_OEM),
  mdl('250 X4', 'X3 / X4 Series Excavators', 'Heavy Equipment', EXC, 2012, 2026, se('Isuzu', '4HK1X', 5.2, '4-Cyl Turbo', 177), ['250 X3', '250 X4S']),
  mdl('300 X4', 'X3 / X4 Series Excavators', 'Heavy Equipment', EXC, 2012, 2022, se('Isuzu', '6HK1X', 7.8, '6-Cyl Turbo', 207), ['290 X2', '300 X3']),
  mdl('300 X4S', 'X4S Series Excavators', 'Heavy Equipment', EXC, 2022, 2026, se('Isuzu', '6HK1X Tier 4F', 7.8, '6-Cyl Turbo', 207), [], SOURCE_EPA_OEM),
  mdl('350 X4', 'X3 / X4 Series Excavators', 'Heavy Equipment', EXC, 2012, 2022, se('Isuzu', '6HK1X', 7.8, '6-Cyl Turbo', 268), ['350 X2', '350 X3']),
  mdl('350 X4S', 'X4S Series Excavators', 'Heavy Equipment', EXC, 2022, 2026, se('Isuzu', '6HK1X Tier 4F', 7.8, '6-Cyl Turbo', 268), ['355 X4S'], SOURCE_EPA_OEM),
  mdl('490 X4', 'X3 / X4 Heavy Excavators', 'Heavy Equipment', EXC, 2012, 2026, se('Isuzu', '6UZ1X', 9.8, '6-Cyl Turbo', 362), ['460 X2', '470 X3', '490 X4S']),
  mdl('RTC-8065', 'Rough Terrain Cranes', 'Heavy Equipment', CRN, 1998, 2026, se('Cummins', 'QSB6.7', 6.7, '6-Cyl Turbo', 270, 'Diesel', '6-Speed Powershift'), ['HSP-8040', 'RTC-8080', 'RTC-80100']),
  mdl('HTC-8675', 'Hydraulic Truck Cranes', 'Heavy Equipment', CRN, 1995, 2026, se('Cummins', 'ISX12 / X12', 11.8, '6-Cyl Turbo', 450, 'Diesel', 'ZF / Eaton Automated'), ['HTC-8660', 'HTC-86100', 'TCC-750']),
];

// ============================================================================
// 13. TAKEUCHI (1975–2026)
// ============================================================================
const TAKEUCHI_MODELS = [
  mdl('TB15', 'Classic TB Mini Excavators', 'Heavy Equipment', EXC, 1978, 1995, se('Yanmar', '3TNA72', 0.9, '3-Cyl', 16), ['TB 15', 'TB 025', 'TB 045', 'TB 070']),
  mdl('TB135', 'TB100 Series Compact Excavators', 'Heavy Equipment', EXC, 2001, 2013, se('Yanmar', '3TNV88', 1.6, '3-Cyl', 28), ['TB125', 'TB145'], SOURCE_EPA_OEM),
  mdl('TB153FR', 'Zero-Swing FR Excavators', 'Heavy Equipment', EXC, 2004, 2015, se('Yanmar', '4TNV88', 2.2, '4-Cyl', 39), ['TB138FR', 'TB280FR'], SOURCE_EPA_OEM),
  mdl('TB175', 'Mid-Size Compact Excavators', 'Heavy Equipment', EXC, 2001, 2012, se('Yanmar', '4TNV98T', 3.3, '4-Cyl Turbo', 61), ['TB180FR'], SOURCE_EPA_OEM),
  mdl('TB216', 'TB200 Series Compact Excavators', 'Heavy Equipment', EXC, 2014, 2026, se('Yanmar', '3TNV70', 0.9, '3-Cyl', 15), ['TB210R', 'TB218'], SOURCE_EPA_OEM),
  mdl('TB230', 'TB200 Series Compact Excavators', 'Heavy Equipment', EXC, 2016, 2026, se('Yanmar', '3TNV88F', 1.6, '3-Cyl', 24), ['TB235-2'], SOURCE_EPA_OEM),
  mdl('TB240', 'TB200 Series Compact Excavators', 'Heavy Equipment', EXC, 2014, 2026, se('Yanmar', '4TNV88C', 2.2, '4-Cyl', 35), [], SOURCE_EPA_OEM),
  mdl('TB250-2', 'TB200 Series Compact Excavators', 'Heavy Equipment', EXC, 2019, 2026, se('Yanmar', '4TNV88C', 2.2, '4-Cyl', 39), ['TB250'], SOURCE_EPA_OEM),
  mdl('TB260', 'TB200 Series Compact Excavators', 'Heavy Equipment', EXC, 2014, 2026, se('Yanmar', '4TNV98C', 3.3, '4-Cyl Turbo', 48), [], SOURCE_EPA_OEM),
  mdl('TB290', 'TB200 Series Mid-Size Excavators', 'Heavy Equipment', EXC, 2014, 2026, se('Isuzu / Yanmar', '4JJ1X / 4TNV98CT', 3.3, '4-Cyl Turbo', 69), ['TB285', 'TB290-2'], SOURCE_EPA_OEM),
  mdl('TB370', 'TB300 Series Excavators', 'Heavy Equipment', EXC, 2020, 2026, se('Kubota', 'V2607-CR-TE5', 2.6, '4-Cyl Turbo', 56), ['TB335R', 'TB350R'], SOURCE_EPA_OEM),
  mdl('TL130', 'Original Compact Track Loaders', 'Heavy Equipment', SSL, 2002, 2012, se('Yanmar', '4TNV98', 3.3, '4-Cyl', 67, 'Diesel', '2-Speed Hydrostatic'), ['TL26', 'TL126'], SOURCE_EPA_OEM),
  mdl('TL140', 'Original Compact Track Loaders', 'Heavy Equipment', SSL, 2004, 2012, se('Isuzu', '4JG1T', 3.1, '4-Cyl Turbo', 81, 'Diesel', '2-Speed Hydrostatic'), ['TL240'], SOURCE_EPA_OEM),
  mdl('TL150', 'Original Compact Track Loaders', 'Heavy Equipment', SSL, 2004, 2012, se('Yanmar', '4TNE106T', 4.4, '4-Cyl Turbo', 97, 'Diesel', '2-Speed Hydrostatic'), ['TL250'], SOURCE_EPA_OEM),
  mdl('TL8', 'TL Series Compact Track Loaders', 'Heavy Equipment', SSL, 2013, 2026, se('Kubota', 'V3307-CR-TE4', 3.3, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), ['TL6R', 'TL8R2'], SOURCE_EPA_OEM),
  mdl('TL10V2', 'Vertical-Lift Compact Track Loaders', 'Heavy Equipment', SSL, 2016, 2026, se('Kubota', 'V3307-CR-TE4', 3.3, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), ['TL10'], SOURCE_EPA_OEM),
  mdl('TL12V2', 'Vertical-Lift Compact Track Loaders', 'Heavy Equipment', SSL, 2016, 2026, se('Kubota', 'V3800-CR-TI-E4', 3.8, '4-Cyl Turbo', 111, 'Diesel', '2-Speed High-Flow Hydrostatic'), ['TL12', 'TL12R2'], SOURCE_EPA_OEM),
  mdl('TW80', 'Compact Wheel Loaders', 'Heavy Equipment', LDR, 2015, 2026, se('Deutz', 'TD2.9 L4', 2.9, '4-Cyl Turbo', 73, 'Diesel', 'Hydrostatic'), ['TW65', 'TW95'], SOURCE_EPA_OEM),
];

// ============================================================================
// 14. DEVELON (1985–2026, incl. Daewoo Solar/Mega & Doosan DX/DL heritage)
// ============================================================================
const DEVELON_MODELS = [
  mdl('Solar 220LC-III', 'Daewoo Solar Classic Excavators', 'Heavy Equipment', EXC, 1990, 2004, se('Daewoo', 'D1146T', 8.1, '6-Cyl Turbo', 147), ['Solar 130LC-V', 'Solar 175LC-V', 'Solar 225LC-V', 'Solar 290LC-V'], SOURCE_EPA_OEM),
  mdl('Mega 300-V', 'Daewoo Mega Wheel Loaders', 'Heavy Equipment', LDR, 1994, 2005, se('Daewoo', 'DE08TIS', 8.1, '6-Cyl Turbo', 200, 'Diesel', 'ZF 4-Speed Powershift'), ['Mega 200-V', 'Mega 250-V'], SOURCE_EPA_OEM),
  mdl('DX35Z', 'Compact Excavators', 'Heavy Equipment', EXC, 2007, 2026, se('Yanmar / Kubota', '3TNV88 / D1703', 1.7, '3-Cyl', 25), ['DX35Z-7', 'DX50Z-7'], SOURCE_EPA_OEM),
  mdl('DX62R-7', 'Dash-7 Compact Excavators', 'Heavy Equipment', EXC, 2021, 2026, se('Develon / Doosan', 'D24', 2.4, '4-Cyl Turbo', 59), ['DX63-3', 'DX62R-3'], SOURCE_EPA_OEM),
  mdl('DX85R-7', 'Reduced-Tail Mid-Size Excavators', 'Heavy Equipment', EXC, 2013, 2026, se('Develon / Yanmar', 'D24', 2.4, '4-Cyl Turbo', 65), ['DX85R-3'], SOURCE_EPA_OEM),
  mdl('DX140LC-3', 'DX140 Crawler Excavators', 'Heavy Equipment', EXC, 2007, 2015, se('Doosan', 'DL06', 5.9, '6-Cyl Turbo', 109), ['DX140LC'], SOURCE_EPA_OEM),
  mdl('DX140LC-7', 'Dash-7 Crawler Excavators', 'Heavy Equipment', EXC, 2021, 2026, se('Develon', 'D34', 3.4, '4-Cyl Turbo', 115), ['DX140LCR-7'], SOURCE_EPA_OEM),
  mdl('DX180LC-5', 'DX180 Crawler Excavators', 'Heavy Equipment', EXC, 2007, 2022, se('Doosan', 'DL06P', 5.9, '6-Cyl Turbo', 129), ['DX180LC', 'DX180LC-3'], SOURCE_EPA_OEM),
  mdl('DX225LC-3', 'DX225 Crawler Excavators', 'Heavy Equipment', EXC, 2006, 2015, se('Doosan', 'DL06', 5.9, '6-Cyl Turbo', 148), ['DX225LC'], SOURCE_EPA_OEM),
  mdl('DX225LC-5', 'DX225 Crawler Excavators', 'Heavy Equipment', EXC, 2015, 2021, se('Doosan', 'DL06P', 5.9, '6-Cyl Turbo', 166), ['DX235LCR-5'], SOURCE_EPA_OEM),
  mdl('DX225LC-7', 'Dash-7 Crawler Excavators', 'Heavy Equipment', EXC, 2021, 2026, se('Develon', 'DL06V', 5.9, '6-Cyl Turbo', 174), ['DX235LCR-7'], SOURCE_EPA_OEM),
  mdl('DX300LC-3', 'DX300 Crawler Excavators', 'Heavy Equipment', EXC, 2006, 2015, se('Doosan', 'DL08', 7.6, '6-Cyl Turbo', 227), ['DX300LC'], SOURCE_EPA_OEM),
  mdl('DX300LC-7', 'Dash-7 Crawler Excavators', 'Heavy Equipment', EXC, 2021, 2026, se('Develon', 'DL08V', 7.6, '6-Cyl Turbo', 271), [], SOURCE_EPA_OEM),
  mdl('DX350LC-5', 'DX350 Crawler Excavators', 'Heavy Equipment', EXC, 2007, 2021, se('Doosan', 'DL08P / Scania DC9', 7.6, '6-Cyl Turbo', 281), ['DX340LC', 'DX350LC-3'], SOURCE_EPA_OEM),
  mdl('DX350LC-7', 'Dash-7 Crawler Excavators', 'Heavy Equipment', EXC, 2021, 2026, se('Develon', 'DL08V', 7.6, '6-Cyl Turbo', 284), [], SOURCE_EPA_OEM),
  mdl('DX490LC-7', 'Heavy Crawler Excavators', 'Heavy Equipment', EXC, 2021, 2026, se('Scania / Develon', 'DC13 / DX12', 12.7, '6-Cyl Turbo', 394), ['DX530LC-7'], SOURCE_EPA_OEM),
  mdl('DX480LC', 'DX480 / DX490 Heavy Excavators', 'Heavy Equipment', EXC, 2007, 2020, se('Doosan / Scania', 'DV11 / DC13', 10.9, '6-Cyl Turbo', 369), ['DX490LC-3', 'DX490LC-5'], SOURCE_EPA_OEM),
  mdl('DL250-5', 'DL-5 Wheel Loaders', 'Heavy Equipment', LDR, 2015, 2021, se('Doosan', 'DL06P', 5.9, '6-Cyl Turbo', 172, 'Diesel', 'ZF Powershift'), ['DL250', 'DL250-3'], SOURCE_EPA_OEM),
  mdl('DL250-7', 'Dash-7 Wheel Loaders', 'Heavy Equipment', LDR, 2021, 2026, se('Develon', 'DL06V', 5.9, '6-Cyl Turbo', 172, 'Diesel', 'ZF Powershift'), ['DL220-7', 'DL280-7'], SOURCE_EPA_OEM),
  mdl('DL320-7', 'Dash-7 Wheel Loaders', 'Heavy Equipment', LDR, 2021, 2026, se('Develon', 'DL08V', 7.6, '6-Cyl Turbo', 271, 'Diesel', 'ZF 5-Speed Powershift'), ['DL300-5', 'DL350-5'], SOURCE_EPA_OEM),
  mdl('DL420-5', 'DL-5 Large Wheel Loaders', 'Heavy Equipment', LDR, 2015, 2021, se('Scania', 'DC13', 12.7, '6-Cyl Turbo', 345, 'Diesel', 'ZF 5-Speed Powershift'), ['DL420', 'DL420-3', 'DL550-5'], SOURCE_EPA_OEM),
  mdl('DL420-7', 'Dash-7 Large Wheel Loaders', 'Heavy Equipment', LDR, 2021, 2026, se('Scania', 'DC13', 12.7, '6-Cyl Turbo', 345, 'Diesel', 'ZF 5-Speed Powershift'), [], SOURCE_EPA_OEM),
  mdl('DD100', 'Crawler Dozers', 'Heavy Equipment', DOZ, 2022, 2026, se('Develon', 'D34', 3.4, '4-Cyl Turbo', 122, 'Diesel', 'Dual-Path Hydrostatic'), ['DD130'], SOURCE_EPA_OEM),
  mdl('DA30-7', 'Articulated Dump Trucks', 'Transport & Hauling', ADT, 2011, 2026, se('Scania', 'DC9', 9.3, '5-Cyl Turbo', 375, 'Diesel', 'ZF EP320 8F/4R Powershift'), ['MT31', 'DA30-5', 'DA45-7'], SOURCE_EPA_OEM),
];

// ============================================================================
// 15. HYUNDAI CE (1988–2026)
// ============================================================================
const HYUNDAI_CE_MODELS = [
  mdl('R210LC-3', 'Robex Classic Excavators', 'Heavy Equipment', EXC, 1994, 2002, se('Cummins', '6BT5.9-C', 5.9, '6-Cyl Turbo', 138), ['200LC', '210LC-3', '290LC-3']),
  mdl('R210LC-7', 'Robex Dash-7 Excavators', 'Heavy Equipment', EXC, 2002, 2009, se('Cummins', 'B5.9-C / QSB6.7', 5.9, '6-Cyl Turbo', 143), ['R140LC-7', 'R290LC-7', 'R320LC-7']),
  mdl('R210LC-9', 'Robex Dash-9 Excavators', 'Heavy Equipment', EXC, 2010, 2015, se('Cummins', 'QSB6.7', 6.7, '6-Cyl Turbo', 151), ['R140LC-9', 'R220LC-9A', 'R330LC-9A'], SOURCE_EPA_OEM),
  mdl('HX60A', 'HX-A Compact Excavators', 'Heavy Equipment', EXC, 2020, 2026, se('Yanmar', '4TNV98C', 3.3, '4-Cyl', 65), ['R55-9A', 'HX35AZ', 'HX55A'], SOURCE_EPA_OEM),
  mdl('HX85A', 'HX-A Mid-Size Excavators', 'Heavy Equipment', EXC, 2016, 2026, se('Yanmar', '4TNV98C', 3.3, '4-Cyl', 67), ['R80CR-9A'], SOURCE_EPA_OEM),
  mdl('HX145A LCR', 'HX-A Short-Radius Excavators', 'Heavy Equipment', EXC, 2016, 2026, se('Cummins', 'F3.8', 3.8, '4-Cyl Turbo', 131), ['HX130A LCR', 'HX145LCR'], SOURCE_EPA_OEM),
  mdl('HX160A L', 'HX-A Crawler Excavators', 'Heavy Equipment', EXC, 2016, 2026, se('Cummins', 'B4.5', 4.5, '4-Cyl Turbo', 152), ['HX160L', 'HX180A L'], SOURCE_EPA_OEM),
  mdl('HX220L', 'HX Series Crawler Excavators', 'Heavy Equipment', EXC, 2015, 2020, se('Cummins', 'QSB6.7', 6.7, '6-Cyl Turbo', 173), ['HX210A L'], SOURCE_EPA_OEM),
  mdl('HX220A L', 'HX-A Series Crawler Excavators', 'Heavy Equipment', EXC, 2020, 2026, se('Cummins', 'B6.7', 6.7, '6-Cyl Turbo', 173), ['HX220AL'], SOURCE_EPA_OEM),
  mdl('HX300A L', 'HX-A Series Crawler Excavators', 'Heavy Equipment', EXC, 2015, 2026, se('Cummins', 'B6.7 / L9', 6.7, '6-Cyl Turbo', 252), ['HX260A L', 'HX300L'], SOURCE_EPA_OEM),
  mdl('HX350A L', 'HX-A Series Crawler Excavators', 'Heavy Equipment', EXC, 2020, 2026, se('Cummins', 'L9', 8.9, '6-Cyl Turbo', 324), ['HX350L', 'HX355A L'], SOURCE_EPA_OEM),
  mdl('HX480A L', 'HX-A Heavy Excavators', 'Heavy Equipment', EXC, 2016, 2026, se('Cummins', 'X12', 11.8, '6-Cyl Turbo', 430), ['HX480L', 'HX520A L'], SOURCE_EPA_OEM),
  mdl('HL757-9A', 'HL-9 Series Wheel Loaders', 'Heavy Equipment', LDR, 2002, 2016, se('Cummins', 'QSB6.7', 6.7, '6-Cyl Turbo', 197, 'Diesel', 'ZF 4-Speed Powershift'), ['HL740-9A', 'HL770-9A'], SOURCE_EPA_OEM),
  mdl('HL940A', 'HL900A Wheel Loaders', 'Heavy Equipment', LDR, 2016, 2026, se('Cummins', 'B6.7', 6.7, '6-Cyl Turbo', 156, 'Diesel', 'ZF 4-Speed Powershift'), ['HL940', 'HL955A'], SOURCE_EPA_OEM),
  mdl('HL960A', 'HL900A Wheel Loaders', 'Heavy Equipment', LDR, 2016, 2026, se('Cummins', 'B6.7', 6.7, '6-Cyl Turbo', 222, 'Diesel', 'ZF 5-Speed Lockup Powershift'), ['HL960', 'HL960A HD'], SOURCE_EPA_OEM),
  mdl('HL975A CVT', 'HL900A Large Wheel Loaders', 'Heavy Equipment', LDR, 2016, 2026, se('Cummins', 'L9 / X12', 8.9, '6-Cyl Turbo', 335, 'Diesel', 'ZF cPOWER CVT / Powershift'), ['HL970A', 'HL980A'], SOURCE_EPA_OEM),
  mdl('HT100V', 'Compact Track Loaders', 'Heavy Equipment', SSL, 2023, 2026, se('Hyundai / Doosan', 'D24', 2.4, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), ['HS120V'], SOURCE_EPA_OEM),
];

// ============================================================================
// 16. LIEBHERR (1970–2026)
// ============================================================================
const LIEBHERR_MODELS = [
  mdl('R 942', 'Classic Litronic Excavators', 'Heavy Equipment', EXC, 1975, 1998, se('Liebherr / Cummins', 'D906TB / NTA855', 10.0, '6-Cyl Turbo', 220), ['R 912', 'R 922', 'R 954'], SOURCE_EPA_OEM),
  mdl('A 914', 'Wheeled Excavators', 'Heavy Equipment', EXC, 2000, 2026, se('Liebherr / Deutz', 'D924 / TCD 3.6 L4', 3.6, '4-Cyl Turbo', 143, 'Diesel', 'Hydrostatic Wheeled Travel'), ['A 914 Compact', 'A 918', 'A 920'], SOURCE_EPA_OEM),
  mdl('R 914 Compact', 'Compact Crawler Excavators', 'Heavy Equipment', EXC, 2012, 2026, se('Deutz', 'TCD 3.6 L4', 3.6, '4-Cyl Turbo', 121), ['R 918'], SOURCE_EPA_OEM),
  mdl('R 920', 'Generation 6 / 8 Crawler Excavators', 'Heavy Equipment', EXC, 2013, 2026, se('Liebherr / Cummins', 'B4.5 / D924', 4.5, '4-Cyl Turbo', 150), ['R 920 Compact', 'R 922 G8'], SOURCE_EPA_OEM),
  mdl('R 926', 'Generation 6 / 8 Crawler Excavators', 'Heavy Equipment', EXC, 2008, 2026, se('Liebherr', 'D924 / D944', 7.0, '4-Cyl Turbo', 204), ['R 924', 'R 926 Compact', 'R 930'], SOURCE_EPA_OEM),
  mdl('R 936', 'Crawler Excavators', 'Heavy Equipment', EXC, 2008, 2024, se('Liebherr', 'D936', 10.5, '6-Cyl Turbo', 258), ['R 934', 'R 938'], SOURCE_EPA_OEM),
  mdl('R 945', 'Generation 8 Crawler Excavators', 'Heavy Equipment', EXC, 2020, 2026, se('Liebherr', 'D946 A7', 12.0, '6-Cyl Turbo', 299), ['R 946', 'R 956'], SOURCE_EPA_OEM),
  mdl('R 976', 'Mining & Mass Excavators', 'Heavy Equipment', EXC, 2006, 2026, se('Liebherr', 'D9508', 16.2, 'V8 Twin-Turbo', 544), ['R 966', 'R 980 SME'], SOURCE_EPA_OEM),
  mdl('L 538', 'Stereoloader & Medium Wheel Loaders', 'Heavy Equipment', LDR, 1998, 2026, se('Liebherr / John Deere', 'D924 / 4045H', 4.5, '4-Cyl Turbo', 154, 'Diesel', 'Hydrostatic Travel Drive'), ['L 526', 'L 546'], SOURCE_EPA_OEM),
  mdl('L 550', 'XPower Wheel Loaders', 'Heavy Equipment', LDR, 1998, 2026, se('Liebherr', 'D944 A7', 8.0, '4-Cyl Turbo', 222, 'Diesel', 'XPower Power-Split CVT'), ['L 550 XPower', 'L 556 XPower'], SOURCE_EPA_OEM),
  mdl('L 566 XPower', 'XPower Large Wheel Loaders', 'Heavy Equipment', LDR, 2016, 2026, se('Liebherr', 'D936 / D946', 12.0, '6-Cyl Turbo', 272, 'Diesel', 'XPower Power-Split CVT'), ['L 580 XPower', 'L 586 XPower'], SOURCE_EPA_OEM),
  mdl('PR 726', 'Litronic Hydrostatic Dozers', 'Heavy Equipment', DOZ, 1998, 2026, se('Liebherr', 'D924', 4.5, '4-Cyl Turbo', 161, 'Diesel', 'Hydrostatic'), ['PR 716', 'PR 724'], SOURCE_EPA_OEM),
  mdl('PR 736', 'Generation 6 / 8 Hydrostatic Dozers', 'Heavy Equipment', DOZ, 2015, 2026, se('Liebherr', 'D934 / D944', 7.0, '4-Cyl Turbo', 217, 'Diesel', 'Infinitely Variable Hydrostatic'), ['PR 734'], SOURCE_EPA_OEM),
  mdl('PR 756', 'Large Hydrostatic Dozers', 'Heavy Equipment', DOZ, 2006, 2026, se('Liebherr', 'D946 / D9508', 12.0, '6-Cyl Turbo', 392, 'Diesel', 'Hydrostatic'), ['PR 746', 'PR 766'], SOURCE_EPA_OEM),
  mdl('TA 230 Litronic', 'Articulated Dump Trucks', 'Transport & Hauling', ADT, 2011, 2026, se('Liebherr', 'D956', 12.0, '6-Cyl Turbo', 355, 'Diesel', '8F/4R Automatic Powershift'), ['TA 230'], SOURCE_EPA_OEM),
  mdl('LTM 1090-4.2', 'LTM All-Terrain Mobile Cranes', 'Heavy Equipment', CRN, 1995, 2026, se('Liebherr', 'D946 A7', 12.0, '6-Cyl Turbo', 449, 'Diesel', 'ZF TraXon 12-Speed Automated'), ['LTM 1070-4.2', 'LTM 1130-5.1', 'LTM 1250-5.1'], SOURCE_EPA_OEM),
];

// ============================================================================
// 17. YANMAR (1975–2026)
// ============================================================================
const YANMAR_MODELS = [
  mdl('B37', 'Classic B-Series Mini Excavators', 'Heavy Equipment', EXC, 1982, 2003, se('Yanmar', '3TNE88', 1.6, '3-Cyl', 28), ['YB251', 'B27', 'B50'], SOURCE_EPA_OEM),
  mdl('SV08-1C', 'Ultra-Compact Excavators', 'Heavy Equipment', EXC, 2006, 2026, se('Yanmar', '2TE67L-BV', 0.5, '2-Cyl', 10), ['ViO17'], SOURCE_EPA_OEM),
  mdl('ViO25-6A', 'ViO True Zero-Tail Excavators', 'Heavy Equipment', EXC, 2005, 2026, se('Yanmar', '3TNV80F', 1.3, '3-Cyl', 20), ['ViO27-6', 'ViO25-4'], SOURCE_EPA_OEM),
  mdl('ViO35-6A', 'ViO True Zero-Tail Excavators', 'Heavy Equipment', EXC, 2002, 2022, se('Yanmar', '3TNV88F', 1.6, '3-Cyl', 24), ['ViO35-3', 'ViO35-5'], SOURCE_EPA_OEM),
  mdl('ViO35-7', 'ViO-7 True Zero-Tail Excavators', 'Heavy Equipment', EXC, 2022, 2026, se('Yanmar', '3TNV88F-ESBV', 1.6, '3-Cyl', 24), [], SOURCE_EPA_OEM),
  mdl('ViO45-6A', 'ViO True Zero-Tail Excavators', 'Heavy Equipment', EXC, 2006, 2026, se('Yanmar', '4TNV88C', 2.2, '4-Cyl', 37), ['ViO50-6A'], SOURCE_EPA_OEM),
  mdl('ViO55-6A', 'ViO True Zero-Tail Excavators', 'Heavy Equipment', EXC, 2006, 2026, se('Yanmar', '4TNV88C-PBV', 2.2, '4-Cyl', 48), ['ViO55-5B'], SOURCE_EPA_OEM),
  mdl('ViO80-1A', 'ViO Mid-Size Excavators', 'Heavy Equipment', EXC, 2014, 2026, se('Yanmar', '4TNV98C-WBV', 3.3, '4-Cyl', 57), ['ViO80-7', 'SV40'], SOURCE_EPA_OEM),
  mdl('SV100-2B', 'SV Mid-Size Excavators', 'Heavy Equipment', EXC, 2010, 2022, se('Yanmar', '4TNV98CT', 3.3, '4-Cyl Turbo', 72), ['SV100-1'], SOURCE_EPA_OEM),
  mdl('SV100-7', 'SV-7 Mid-Size Excavators', 'Heavy Equipment', EXC, 2022, 2026, se('Yanmar', '4TNV98CT-VBV', 3.3, '4-Cyl Turbo', 72), [], SOURCE_EPA_OEM),
  mdl('TL65RS', 'TL Compact Track Loaders', 'Heavy Equipment', SSL, 2023, 2026, se('Yanmar', '4TNV98C', 3.3, '4-Cyl', 67, 'Diesel', '2-Speed Hydrostatic'), ['TL75VS', 'TL80VS'], SOURCE_EPA_OEM),
  mdl('TL100VS', 'TL Vertical-Lift Compact Track Loaders', 'Heavy Equipment', SSL, 2023, 2026, se('Yanmar', '4TNV94FHT', 3.1, '4-Cyl Turbo', 103, 'Diesel', '2-Speed High-Flow Hydrostatic'), [], SOURCE_EPA_OEM),
  mdl('V8', 'Compact Wheel Loaders', 'Heavy Equipment', LDR, 2005, 2026, se('Yanmar', '4TNV98C', 3.3, '4-Cyl', 62, 'Diesel', 'Hydrostatic'), ['V4-7', 'V70S', 'V100'], SOURCE_EPA_OEM),
];

// ============================================================================
// 18. WACKER NEUSON (1975–2026)
// ============================================================================
const WACKER_NEUSON_MODELS = [
  mdl('RT82-SC', 'Trench & Vibratory Rollers', 'Heavy Equipment', CMP, 1988, 2026, se('Lombardini / Kohler', 'LDW1003 / KDW1003', 1.0, '3-Cyl', 20, 'Diesel', 'Infrared Remote Hydrostatic'), ['WDH 86-110', 'RTkx', 'RD12A', 'RD27']),
  mdl('EZ17', 'EZ Zero-Tail Mini Excavators', 'Heavy Equipment', EXC, 2008, 2026, se('Yanmar', '3TNV76', 1.1, '3-Cyl', 18), ['803', 'ET18', 'ET24', 'EZ26', 'EZ28'], SOURCE_EPA_OEM),
  mdl('EZ36', 'EZ Zero-Tail Excavators', 'Heavy Equipment', EXC, 2018, 2026, se('Yanmar', '3TNV88F', 1.6, '3-Cyl', 24), ['EZ38'], SOURCE_EPA_OEM),
  mdl('EZ50', 'EZ Zero-Tail Excavators', 'Heavy Equipment', EXC, 2016, 2026, se('Perkins / Yanmar', '404J-E22T / 4TNV88C', 2.2, '4-Cyl Turbo', 45), ['EZ53', 'EZ80'], SOURCE_EPA_OEM),
  mdl('ET65', 'ET Tracked Excavators', 'Heavy Equipment', EXC, 2015, 2026, se('Perkins', '404F-E22TA', 2.2, '4-Cyl Turbo', 56), ['ET60'], SOURCE_EPA_OEM),
  mdl('ET90', 'ET Tracked Excavators', 'Heavy Equipment', EXC, 2015, 2026, se('Perkins', '854F-E34T', 3.4, '4-Cyl Turbo', 74), ['ET145'], SOURCE_EPA_OEM),
  mdl('SW28', 'Skid Steer Loaders', 'Heavy Equipment', SSL, 2015, 2026, se('Kohler', 'KDI 2504TCR', 2.5, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), ['SW20', 'SW21', 'SM100'], SOURCE_EPA_OEM),
  mdl('ST31', 'Compact Track Loaders', 'Heavy Equipment', SSL, 2015, 2026, se('Kohler', 'KDI 2504TCR', 2.5, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), ['ST27', 'ST28'], SOURCE_EPA_OEM),
  mdl('ST45', 'Large Compact Track Loaders', 'Heavy Equipment', SSL, 2015, 2026, se('Perkins / Kohler', '854F-E34TA / KDI 3404', 3.4, '4-Cyl Turbo', 100, 'Diesel', '2-Speed Hydrostatic'), ['ST35', 'ST50'], SOURCE_EPA_OEM),
  mdl('WL34', 'Articulated Wheel Loaders', 'Heavy Equipment', LDR, 2014, 2026, se('Deutz / Perkins', 'TD 2.2 L3 / 404J', 2.2, '3-Cyl Turbo', 60, 'Diesel', '2-Speed Hydrostatic'), ['WL28', 'WL32'], SOURCE_EPA_OEM),
  mdl('WL52', 'Articulated Wheel Loaders', 'Heavy Equipment', LDR, 2014, 2026, se('Deutz', 'TD 2.9 L4', 2.9, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), ['WL38', 'WL60', 'TH627'], SOURCE_EPA_OEM),
  mdl('LTN6L', 'Mobile Light Towers', 'Site Support', ['Light Tower'], 2005, 2026, se('Kohler / Kubota', 'KDW1003 / D1005', 1.0, '3-Cyl', 13, 'Diesel', '1800 RPM 6kW Generator'), ['LTV6L', 'LTW6K'], SOURCE_EPA_OEM),
  mdl('G50', 'Mobile Towable Generators', 'Site Support', ['Generator'], 2006, 2026, se('Cummins / Isuzu', '4BT3.3 / QSB4.5', 4.5, '4-Cyl Turbo', 75, 'Diesel', '1800 RPM Synchronous Alternator'), ['G25', 'G70', 'G100'], SOURCE_EPA_OEM),
];

// ============================================================================
// 19. TEREX (1970–2026, incl. Fermec / Schaeff / ASV-PosiTrack / Terex Trucks)
// ============================================================================
const TEREX_MODELS = [
  mdl('72-71B', 'Classic Wheel Loaders', 'Heavy Equipment', LDR, 1970, 1986, se('Detroit Diesel', '8V-71T', 9.3, 'V8 2-Stroke Turbo', 336, 'Diesel', 'Allison Powershift'), ['70C', '72-61', '72-81']),
  mdl('82-30B', 'Classic Crawler Dozers', 'Heavy Equipment', DOZ, 1972, 1985, se('Detroit Diesel', '6-71T', 7.0, '6-Cyl 2-Stroke Turbo', 260, 'Diesel', 'Allison CRT Powershift'), ['82-20B', '82-50']),
  mdl('TX760B', 'TX / TLB Backhoe Loaders', 'Heavy Equipment', BKH, 1998, 2011, se('Perkins', '1104C-44T', 4.4, '4-Cyl Turbo', 94, 'Diesel', '4-Speed Syncro Shuttle'), ['TX860B', 'TLB840', 'TLB890'], SOURCE_EPA_OEM),
  mdl('860SX', 'SX / Elite Backhoe Loaders', 'Heavy Equipment', BKH, 2006, 2017, se('Perkins', '1104D-44TA', 4.4, '4-Cyl Turbo', 100, 'Diesel', '4-Speed Syncro / Powershift'), ['820', '880SX'], SOURCE_EPA_OEM),
  mdl('970 Elite', 'Equal-Wheel Backhoe Loaders', 'Heavy Equipment', BKH, 2006, 2016, se('Perkins', '1104D-44TA', 4.4, '4-Cyl Turbo', 100, 'Diesel', 'Powershift'), ['980 Elite'], SOURCE_EPA_OEM),
  mdl('TL80', 'Compact Wheel Loaders', 'Heavy Equipment', LDR, 2005, 2017, se('Deutz', 'TD2011 L04w / TD2.9', 2.9, '4-Cyl Turbo', 60, 'Diesel', 'Hydrostatic'), ['SKL 834', 'TL100', 'TL120'], SOURCE_EPA_OEM),
  mdl('TC50', 'Compact Excavators', 'Heavy Equipment', EXC, 2004, 2017, se('Kubota / Mitsubishi', 'V2403 / S4Q2', 2.4, '4-Cyl', 44), ['HR16', 'TC35', 'TC75'], SOURCE_EPA_OEM),
  mdl('PT-80', 'Posi-Track Compact Track Loaders', 'Heavy Equipment', SSL, 2007, 2016, se('Perkins', '804D-33T / 1104C', 3.3, '4-Cyl Turbo', 80, 'Diesel', '2-Speed Hydrostatic'), ['PT-60', 'PT-100G', 'TSV80'], SOURCE_EPA_OEM),
  mdl('TA30', 'TA Articulated Dump Trucks', 'Transport & Hauling', ADT, 1995, 2011, se('Cummins', 'QSM11', 10.8, '6-Cyl Turbo', 385, 'Diesel', 'ZF 6F/3R Powershift'), ['TA25', 'TA27', 'TA40'], SOURCE_EPA_OEM),
  mdl('TA300', 'Generation 9 / 10 Articulated Dump Trucks', 'Transport & Hauling', ADT, 2011, 2026, se('Scania', 'DC9', 9.3, '5-Cyl Turbo', 370, 'Diesel', 'ZF EP320 8F/4R Powershift'), ['TA250', 'TA400'], SOURCE_EPA_OEM),
  mdl('RT555', 'Rough Terrain Cranes', 'Heavy Equipment', CRN, 1998, 2026, se('Cummins', 'QSB6.7', 6.7, '6-Cyl Turbo', 200, 'Diesel', '6-Speed Powershift'), ['RT670', 'RT780', 'TRT 80US'], SOURCE_EPA_OEM),
  mdl('RL4000', 'Towable Site Light Towers', 'Site Support', ['Light Tower'], 1998, 2023, se('Kubota', 'D905 / D1005', 1.0, '3-Cyl', 13, 'Diesel', '6kW Brushless Generator'), ['AL4000', 'AL5000'], SOURCE_EPA_OEM),
];

// ============================================================================
// 20. GRADALL (1970–2026)
// ============================================================================
const GRADALL_MODELS = [
  mdl('G-660', 'Classic G-Series Telescopic Excavators', 'Heavy Equipment', EXC, 1970, 1992, se('Detroit Diesel', '4-53N / 6V-53', 5.2, '6-Cyl 2-Stroke', 160, 'Diesel', 'Highway Carrier / Crawler Hydraulic'), ['G 660', 'G 660B', 'G 660C', 'G-600']),
  mdl('G-880C', 'Classic G-Series Telescopic Excavators', 'Heavy Equipment', EXC, 1974, 1994, se('Detroit Diesel / Cummins', '6V-53T / 6BT5.9', 5.9, '6-Cyl Turbo', 190, 'Diesel', 'Hydraulic Telescopic Boom'), ['G 880B', 'G 880C', 'G 1000']),
  mdl('G3WD', 'Wheeled Telescopic Excavators', 'Heavy Equipment', EXC, 1984, 1998, se('Cummins', '6BT5.9', 5.9, '6-Cyl Turbo', 165, 'Diesel', '6x4 / 6x6 Carrier'), []),
  mdl('XL 3100 III', 'XL III / IV Highway-Speed Excavators', 'Heavy Equipment', EXC, 1998, 2013, se('Detroit Diesel / Mercedes', 'MBE 900', 6.4, '6-Cyl Turbo', 210, 'Diesel', 'Allison 3000 RDS Automatic'), ['XL 3100 IV'], SOURCE_EPA_OEM),
  mdl('XL 3100 V', 'Series V Highway-Speed Excavators', 'Heavy Equipment', EXC, 2014, 2026, se('Volvo / Penta', 'TAD572VE / TAD881VE', 5.1, '4-Cyl Turbo', 218, 'Diesel', 'Allison 3000 RDS 6-Speed Automatic'), ['XL3100V', 'XL 3200 V', 'XL 3300 V'], SOURCE_EPA_OEM),
  mdl('XL 4100 IV', 'XL III / IV Highway-Speed Excavators', 'Heavy Equipment', EXC, 1998, 2013, se('Detroit Diesel / Mercedes', 'MBE 906', 6.4, '6-Cyl Turbo', 250, 'Diesel', 'Allison 3000 RDS Automatic'), ['XL 4100 III', 'XL 4200'], SOURCE_EPA_OEM),
  mdl('XL 4100 V', 'Series V Highway-Speed Excavators', 'Heavy Equipment', EXC, 2014, 2026, se('Volvo Penta', 'TAD871VE / TAD881VE', 7.7, '6-Cyl Turbo', 248, 'Diesel', 'Allison 3000 RDS 6-Speed Automatic'), ['XL4100V', 'XL 4200 V', 'XL 4300 V'], SOURCE_EPA_OEM),
  mdl('XL 5100 V', 'Series V Heavy Highway-Speed Excavators', 'Heavy Equipment', EXC, 2014, 2026, se('Volvo Penta', 'TAD872VE / TAD882VE', 7.7, '6-Cyl Turbo', 281, 'Diesel', 'Allison 3000 RDS 6-Speed Automatic'), ['XL 5100 III', 'XL 5100 IV', 'XL 5200 V', 'XL 5300 V'], SOURCE_EPA_OEM),
  mdl('D152', 'Discovery Crossover Wheeled Excavators', 'Heavy Equipment', EXC, 2014, 2026, se('Cummins', 'QSB4.5', 4.5, '4-Cyl Turbo', 160, 'Diesel', '4x2 / 4x4 Hydrostatic'), ['D154'], SOURCE_EPA_OEM),
  mdl('534D9-45', 'Material Handler Telehandlers', 'Heavy Equipment', TLH, 1982, 2006, se('Cummins', '4BT3.9', 3.9, '4-Cyl Turbo', 110, 'Diesel', '3-Speed Powershift'), ['534C-9', '534D10-45', '544D10-55'], SOURCE_EPA_OEM),
];

// ============================================================================
// 21. BELL (1984–2026)
// ============================================================================
const BELL_MODELS = [
  mdl('B25C', 'B- & C-Series Articulated Dump Trucks', 'Transport & Hauling', ADT, 1985, 2001, se('Mercedes-Benz', 'OM906LA / ADE 366T', 6.4, '6-Cyl Turbo', 260, 'Diesel', 'ZF 6-Speed Powershift'), ['B25B', 'B30B', 'B30C', 'B40C'], SOURCE_EPA_OEM),
  mdl('B30D', 'D-Series Articulated Dump Trucks', 'Transport & Hauling', ADT, 2001, 2013, se('Mercedes-Benz', 'OM906LA / OM926LA', 7.2, '6-Cyl Turbo', 322, 'Diesel', 'Allison 3500PR 6-Speed Automatic'), ['B25D', 'B35D'], SOURCE_EPA_OEM),
  mdl('B40D', 'D-Series Heavy Articulated Dump Trucks', 'Transport & Hauling', ADT, 2001, 2013, se('Mercedes-Benz', 'OM501LA', 11.9, 'V6 Turbo', 422, 'Diesel', 'Allison 4500PR 6-Speed Automatic'), ['B50D'], SOURCE_EPA_OEM),
  mdl('B20E', 'E-Series Articulated Dump Trucks', 'Transport & Hauling', ADT, 2014, 2026, se('Mercedes-Benz / MTU', 'OM934LA (4R1000)', 5.1, '4-Cyl Turbo', 228, 'Diesel', 'Allison 3200PR 6-Speed Automatic'), ['B18E', 'B20E LGP'], SOURCE_EPA_OEM),
  mdl('B25E', 'E-Series Articulated Dump Trucks', 'Transport & Hauling', ADT, 2013, 2026, se('Mercedes-Benz / MTU', 'OM936LA (6R1000)', 7.7, '6-Cyl Turbo', 282, 'Diesel', 'Allison 3400PR 6-Speed Automatic'), [], SOURCE_EPA_OEM),
  mdl('B30E', 'E-Series Articulated Dump Trucks', 'Transport & Hauling', ADT, 2013, 2026, se('Mercedes-Benz / MTU', 'OM936LA (6R1000)', 7.7, '6-Cyl Turbo', 335, 'Diesel', 'Allison 3400PR 6-Speed Automatic'), [], SOURCE_EPA_OEM),
  mdl('B35E', 'E-Series Articulated Dump Trucks', 'Transport & Hauling', ADT, 2014, 2026, se('Mercedes-Benz / MTU', 'OM470LA (6R1100)', 10.7, '6-Cyl Turbo', 416, 'Diesel', 'Allison 4700ORS 7-Speed Automatic'), [], SOURCE_EPA_OEM),
  mdl('B40E', 'E-Series Articulated Dump Trucks', 'Transport & Hauling', ADT, 2014, 2026, se('Mercedes-Benz / MTU', 'OM471LA (6R1300)', 12.8, '6-Cyl Turbo', 510, 'Diesel', 'Allison 4700ORS 7-Speed Automatic'), [], SOURCE_EPA_OEM),
  mdl('B45E', 'E-Series Articulated Dump Trucks', 'Transport & Hauling', ADT, 2016, 2026, se('Mercedes-Benz / MTU', 'OM471LA (6R1300)', 12.8, '6-Cyl Turbo', 523, 'Diesel', 'Allison 4700ORS 7-Speed Automatic'), [], SOURCE_EPA_OEM),
  mdl('B50E', 'E-Series Heavy Articulated Dump Trucks', 'Transport & Hauling', ADT, 2015, 2026, se('Mercedes-Benz / MTU', 'OM473LA (6R1500)', 15.6, '6-Cyl Turbo', 577, 'Diesel', 'Allison 4800ORS 7-Speed Automatic'), ['B60E'], SOURCE_EPA_OEM),
  mdl('L2106E', 'Wheel Loaders', 'Heavy Equipment', LDR, 2005, 2026, se('John Deere / Cummins', '6068H / QSB6.7', 6.8, '6-Cyl Turbo', 217, 'Diesel', 'ZF 4-Speed Powershift'), ['L1806E', 'L2606E'], SOURCE_EPA_OEM),
];

// ============================================================================
// 22. MANITOU (1975–2026, incl. Mustang / Gehl Manitou North America)
// ============================================================================
const MANITOU_MODELS = [
  mdl('4RM25', 'Classic Rough Terrain Forklifts', 'Heavy Equipment', FRK, 1975, 1995, se('Perkins', '4.236', 3.9, '4-Cyl', 72, 'Diesel', 'Torque Converter Shuttle'), ['M 30-4', 'M 50-4'], SOURCE_EPA_OEM),
  mdl('MT 625 H', 'MT Construction Telehandlers', 'Heavy Equipment', TLH, 2010, 2026, se('Kubota', 'V3307-DI-T', 3.3, '4-Cyl Turbo', 75, 'Diesel', 'Hydrostatic'), ['MT 732', 'MT 932', 'MT 1030 S'], SOURCE_EPA_OEM),
  mdl('MT 1440', 'MT High-Reach Construction Telehandlers', 'Heavy Equipment', TLH, 2006, 2026, se('Deutz / Perkins', 'TCD 3.6 L4', 3.6, '4-Cyl Turbo', 100, 'Diesel', '4-Speed Torque Converter'), ['MT 1335', 'MT 1840'], SOURCE_EPA_OEM),
  mdl('MLT 737', 'MLT Heavy-Duty Telehandlers', 'Heavy Equipment', TLH, 2016, 2026, se('Deutz', 'TCD 3.6 L4', 3.6, '4-Cyl Turbo', 129, 'Diesel', 'M-Vario Plus Powershift'), ['MLT 625', 'MLT 737-130 PS+'], SOURCE_EPA_OEM),
  mdl('MLT 840', 'MLT Heavy-Capacity Telehandlers', 'Heavy Equipment', TLH, 2012, 2026, se('John Deere / Yanmar', '4045PWX / 4TN107FHT', 4.5, '4-Cyl Turbo', 137, 'Diesel', 'M-Shift 5-Speed Powershift'), ['MLT 840-145 PS+', 'MLT 841'], SOURCE_EPA_OEM),
  mdl('MTA 6642', 'MTA North American Telehandlers', 'Heavy Equipment', TLH, 2008, 2026, se('Cummins / Deutz', 'QSF3.8 / TCD 3.6', 3.6, '4-Cyl Turbo', 74, 'Diesel', 'Powershuttle'), ['MTA 8044'], SOURCE_EPA_OEM),
  mdl('MTA 10055', 'MTA Heavy North American Telehandlers', 'Heavy Equipment', TLH, 2008, 2026, se('Cummins / Deutz', 'QSB4.5 / TCD 3.6 L4', 3.6, '4-Cyl Turbo', 120, 'Diesel', '4-Speed Powershift'), ['MTA 12055'], SOURCE_EPA_OEM),
  mdl('MRT 2150', 'MRT Rotating Telehandlers', 'Heavy Equipment', TLH, 2004, 2021, se('Mercedes-Benz', 'OM934LA', 5.1, '4-Cyl Turbo', 150, 'Diesel', 'Hydrostatic'), ['MRT 2550'], SOURCE_EPA_OEM),
  mdl('MRT 2660', 'MRT Vision+ Rotating Telehandlers', 'Heavy Equipment', TLH, 2021, 2026, se('Yanmar', '4TN107FHT', 4.6, '4-Cyl Twin-Turbo', 156, 'Diesel', '2-Speed Hydrostatic'), ['MRT 2260', 'MRT 3060'], SOURCE_EPA_OEM),
  mdl('2700V', 'Skid Steer & Track Loaders', 'Heavy Equipment', SSL, 2015, 2026, se('Yanmar', '4TNV98C', 3.3, '4-Cyl', 72, 'Diesel', '2-Speed Hydrostatic'), ['2200R', '2750VT', '3200VT'], SOURCE_EPA_OEM),
];

// ============================================================================
// 23. SKYTRAK (1975–2026)
// ============================================================================
const SKYTRAK_MODELS = [
  mdl('4030', 'Classic SkyTrak Shooting-Boom Forklifts', 'Heavy Equipment', TLH, 1975, 1994, se('John Deere / Continental', '4219D', 3.6, '4-Cyl', 70, 'Diesel', '3-Speed Torque Converter'), ['5028', '6036', '9038'], SOURCE_EPA_OEM),
  mdl('3606', 'Millennia Series Telehandlers', 'Heavy Equipment', TLH, 1996, 2004, se('Cummins', '4B3.9 / 4BT3.9', 3.9, '4-Cyl Turbo', 80, 'Diesel', '4-Speed Powershift'), ['4266', '4270', '4290'], SOURCE_EPA_OEM),
  mdl('10042', 'Legacy & Plus Series Telehandlers', 'Heavy Equipment', TLH, 1998, 2020, se('Cummins', '4BT3.9 / QSB4.5', 4.5, '4-Cyl Turbo', 110, 'Diesel', '4-Speed Modulated Powershift'), ['3013'], SOURCE_EPA_OEM),
  mdl('6034', 'Current Series Telehandlers', 'Heavy Equipment', TLH, 2022, 2026, se('Deutz', 'TCD 2.9 L4', 2.9, '4-Cyl Turbo', 74, 'Diesel', 'Hydrostatic / Powershift'), [], SOURCE_EPA_OEM),
  mdl('6036', 'Legacy / Tier 4 Telehandlers', 'Heavy Equipment', TLH, 2004, 2023, [
    eng('Cummins', '4BT3.9 / QSB4.5', 4.5, '4-Cyl Turbo', 110, 'Diesel', '4-Speed Powershift', 2004, 2015),
    eng('Cummins / Deutz', 'QSF3.8 / TCD 3.6 L4', 3.6, '4-Cyl Turbo', 74, 'Diesel', '4-Speed Powershift', 2015, 2023),
  ], [], SOURCE_EPA_OEM),
  mdl('6042', 'Current Series Telehandlers', 'Heavy Equipment', TLH, 2018, 2026, se('Deutz', 'TCD 2.9 L4 / 3.6 L4', 2.9, '4-Cyl Turbo', 74, 'Diesel', '4-Speed Powershift'), [], SOURCE_EPA_OEM),
  mdl('8042', 'Heavy-Duty Jobsite Telehandlers', 'Heavy Equipment', TLH, 2004, 2026, [
    eng('Cummins', 'QSB4.5', 4.5, '4-Cyl Turbo', 110, 'Diesel', '4-Speed Powershift', 2004, 2015),
    eng('Cummins', 'QSF3.8 Tier 4F', 3.8, '4-Cyl Turbo', 74, 'Diesel', '4-Speed Powershift', 2015, 2026),
    eng('Deutz', 'TCD 3.6 L4', 3.6, '4-Cyl Turbo', 115, 'Diesel', '4-Speed Powershift', 2018, 2026),
  ], [], SOURCE_EPA_OEM),
  mdl('10054', 'High-Reach Jobsite Telehandlers', 'Heavy Equipment', TLH, 2004, 2026, [
    eng('Cummins', 'QSB4.5', 4.5, '4-Cyl Turbo', 110, 'Diesel', '4-Speed Powershift', 2004, 2015),
    eng('Cummins', 'QSF3.8 / Deutz TCD 3.6', 3.6, '4-Cyl Turbo', 74, 'Diesel', '4-Speed Powershift', 2015, 2026),
    eng('Deutz', 'TCD 3.6 L4 High-Output', 3.6, '4-Cyl Turbo', 115, 'Diesel', '4-Speed Powershift', 2018, 2026),
  ], [], SOURCE_EPA_OEM),
  mdl('12054', 'Heavy-Capacity Telehandlers', 'Heavy Equipment', TLH, 2020, 2026, se('Cummins / Deutz', 'QSF3.8 / TCD 3.6 L4', 3.6, '4-Cyl Turbo', 115, 'Diesel', '4-Speed Powershift'), [], SOURCE_EPA_OEM),
];

// ============================================================================
// 24. GROVE / MANITOWOC (1970–2026)
// ============================================================================
const GROVE_MANITOWOC_MODELS = [
  mdl('RT58', 'Classic Grove Rough Terrain Cranes', 'Heavy Equipment', CRN, 1970, 1994, se('Detroit Diesel / Cummins', '4-53N / 6BT5.9', 5.9, '6-Cyl Turbo', 130, 'Diesel', '6-Speed Powershift'), ['RT-48', 'RT-58', 'RT58B', 'RT528C']),
  mdl('RT635C', 'C-Series Rough Terrain Cranes', 'Heavy Equipment', CRN, 1986, 2002, se('Cummins', '6BT5.9', 5.9, '6-Cyl Turbo', 152, 'Diesel', '6-Speed Powershift'), ['RT745']),
  mdl('RT540E', 'E-Series Rough Terrain Cranes', 'Heavy Equipment', CRN, 2007, 2022, se('Cummins', 'QSB6.7', 6.7, '6-Cyl Turbo', 160, 'Diesel', 'Range-Shift 6-Speed Powershift'), ['RT530E-2']),
  mdl('RT650E', 'E-Series Rough Terrain Cranes', 'Heavy Equipment', CRN, 2005, 2020, se('Cummins', 'QSB6.7', 6.7, '6-Cyl Turbo', 173, 'Diesel', '6-Speed Powershift'), []),
  mdl('RT765E-2', 'E-Series Rough Terrain Cranes', 'Heavy Equipment', CRN, 2010, 2024, se('Cummins', 'QSB6.7', 6.7, '6-Cyl Turbo', 240, 'Diesel', 'Range-Shift 6-Speed Powershift'), ['RT760E', 'RT770E']),
  mdl('RT890E', 'E-Series Heavy Rough Terrain Cranes', 'Heavy Equipment', CRN, 2006, 2024, se('Cummins', 'QSB6.7', 6.7, '6-Cyl Turbo', 275, 'Diesel', 'Range-Shift 6-Speed Powershift'), ['RT880E', 'RT9130E-2']),
  mdl('GRT8100', 'GRT Next-Gen Rough Terrain Cranes', 'Heavy Equipment', CRN, 2016, 2026, se('Cummins', 'B6.7', 6.7, '6-Cyl Turbo', 275, 'Diesel', 'ECO Mode Range-Shift Powershift'), ['GRT655', 'GRT880', 'GRT8120'], SOURCE_EPA_OEM),
  mdl('TMS9000-2', 'Truck-Mounted Telescopic Cranes', 'Heavy Equipment', CRN, 2003, 2026, se('Cummins', 'ISX12 / X12', 11.8, '6-Cyl Turbo', 450, 'Diesel', 'Eaton Roadranger 11-Speed'), ['TMS700E', 'TMS800E', 'TMS9000E']),
  mdl('GMK5250L', 'GMK All-Terrain Cranes', 'Heavy Equipment', CRN, 2015, 2026, se('Mercedes-Benz / MTU', 'OM471LA (6R1300)', 12.8, '6-Cyl Turbo', 523, 'Diesel', 'Mercedes G280-16 VIAB Turbo Retarder Clutch'), ['GMK3060L', 'GMK4100L', 'GMK5150L', 'GMK5250XL-1'], SOURCE_EPA_OEM),
  mdl('Manitowoc 4100W', 'Classic VICON Lattice Crawler Cranes', 'Heavy Equipment', CRN, 1970, 1995, se('Cummins / Cat', 'NTA-855-C360', 14.0, '6-Cyl Turbo', 360, 'Diesel', 'VICON Controlled Torque Converter'), ['3900W', '4000W']),
  mdl('Manitowoc 999', 'Lattice-Boom Crawler Cranes', 'Heavy Equipment', CRN, 1998, 2022, se('Cummins', 'QSC8.3 / QSL9', 8.9, '6-Cyl Turbo', 400, 'Diesel', 'Closed-Loop Hydrostatic'), ['888', '2250']),
  mdl('Manitowoc MLC150-1', 'MLC Lattice Crawler Cranes', 'Heavy Equipment', CRN, 2014, 2026, se('Cummins', 'B6.7 / L9', 6.7, '6-Cyl Turbo', 326, 'Diesel', 'Closed-Loop Hydrostatic'), ['MLC100-1', 'MLC300'], SOURCE_EPA_OEM),
];

// ============================================================================
// 25. GENIE / JLG (1973–2026, Combined Rental Access & Telehandler Fleet)
// ============================================================================
const GENIE_JLG_MODELS = [
  mdl('S-65', 'Telescopic Boom Lifts', 'Site Support', ['Boom Lift'], 1998, 2022, [
    eng('Deutz', 'D2011 L03i / D2.9 L4', 2.9, '4-Cyl', 49, 'Diesel', '4WD Hydrostatic', 1998, 2022),
    eng('Perkins', '404D-22 / 404F-22T', 2.2, '4-Cyl Turbo', 51, 'Diesel', '4WD Hydrostatic', 2004, 2022),
    eng('Ford', 'MSG-425 EFI', 2.5, '4-Cyl', 75, 'Dual Fuel (Gas/LPG)', '4WD Hydrostatic', 2005, 2022),
  ], ['S65'], SOURCE_EPA_OEM),
  mdl('S-85', 'Telescopic Boom Lifts', 'Site Support', ['Boom Lift'], 1998, 2022, [
    eng('Deutz', 'TD2011 L04i / TD2.9 L4', 2.9, '4-Cyl Turbo', 74, 'Diesel', '4WD Hydrostatic', 1998, 2022),
    eng('Perkins', '804D-33 / 404F-E22TA', 2.2, '4-Cyl Turbo', 67, 'Diesel', '4WD Hydrostatic', 2005, 2022),
    eng('Continental / Ford', 'MSG-425 EFI', 2.5, '4-Cyl', 75, 'Dual Fuel (Gas/LPG)', '4WD Hydrostatic', 2006, 2022),
  ], ['S85'], SOURCE_EPA_OEM),
  mdl('Z-45/25', 'Articulating Boom Lifts', 'Site Support', ['Boom Lift'], 1995, 2026, [
    eng('Deutz', 'D2011 L03i / D2.9 L4', 2.9, '3-Cyl / 4-Cyl', 49, 'Diesel', '4WD Hydrostatic', 1995, 2026),
    eng('Ford / Kubota', 'MSG-425 / WG2503', 2.5, '4-Cyl', 60, 'Dual Fuel (Gas/LPG)', '4WD Hydrostatic', 1998, 2026),
    eng('Genie Electric', '48V DC Drive Pack', 0.0, 'Electric Motor', 18, 'Electric', 'Electric Direct Drive', 1998, 2026),
  ], ['Z-45/25J RT', 'Z-45/25 DC'], SOURCE_EPA_OEM),
  mdl('450AJ', 'JLG Articulating Boom Lifts', 'Site Support', ['Boom Lift'], 1997, 2026, [
    eng('Deutz', 'D2011 L03i / D2.9 L4', 2.9, '4-Cyl', 49, 'Diesel', '4WD Hydrostatic', 1997, 2026),
    eng('Ford / Kubota', 'MSG-425 / WG2503', 2.5, '4-Cyl', 61, 'Dual Fuel (Gas/LPG)', '4WD Hydrostatic', 2000, 2026),
  ], ['400S', '460SJ'], SOURCE_EPA_OEM),
  mdl('600S', 'JLG Telescopic Boom Lifts', 'Site Support', ['Boom Lift'], 1997, 2026, [
    eng('Deutz', 'D2011 L04i / D2.9 L4', 2.9, '4-Cyl', 67, 'Diesel', '4WD Hydrostatic', 1997, 2026),
    eng('Ford / GM', '3.0L / MSG-425', 2.5, '4-Cyl', 75, 'Dual Fuel (Gas/LPG)', '4WD Hydrostatic', 1999, 2026),
  ], ['660SJ'], SOURCE_EPA_OEM),
  mdl('800S', 'JLG High-Reach Telescopic Boom Lifts', 'Site Support', ['Boom Lift'], 1998, 2026, [
    eng('Deutz', 'TD2.9 L4', 2.9, '4-Cyl Turbo', 67, 'Diesel', '4WD Hydrostatic', 1998, 2026),
    eng('Ford', 'MSG-425', 2.5, '4-Cyl', 75, 'Dual Fuel (Gas/LPG)', '4WD Hydrostatic', 2002, 2026),
  ], ['860SJ', '1200SJP', '1350SJP'], SOURCE_EPA_OEM),
  mdl('1930ES', 'Electric & Rough-Terrain Scissor Lifts', 'Site Support', ['Scissor Lift'], 2003, 2026, se('JLG Electric', '24V DC Brushless Drive', 0.0, 'Electric Motor', 8, 'Electric', 'Direct Electric Front-Wheel Drive'), ['2630ES', '3246ES'], SOURCE_EPA_OEM),
  mdl('4394RT', 'Rough-Terrain Scissor Lifts', 'Site Support', ['Scissor Lift'], 2004, 2026, [
    eng('Deutz', 'D2.9 L4', 2.9, '4-Cyl', 49, 'Diesel', '4WD Hydrostatic', 2004, 2026),
    eng('Kubota', 'WG2503', 2.5, '4-Cyl', 61, 'Dual Fuel (Gas/LPG)', '4WD Hydrostatic', 2008, 2026),
  ], ['3394RT'], SOURCE_EPA_OEM),
  mdl('G10-55A', 'JLG Telehandlers', 'Heavy Equipment', TLH, 2006, 2020, [
    eng('Cummins', 'QSB4.5', 4.5, '4-Cyl Turbo', 130, 'Diesel', '4-Speed Powershift', 2006, 2015),
    eng('Cummins', 'QSF3.8 Tier 4F', 3.8, '4-Cyl Turbo', 130, 'Diesel', '4-Speed Powershift', 2015, 2020),
  ], ['G6-42A', 'G9-43A', 'G12-55A'], SOURCE_EPA_OEM),
  mdl('1055', 'JLG Current Generation Telehandlers', 'Heavy Equipment', TLH, 2016, 2026, se('Cummins', 'QSF3.8', 3.8, '4-Cyl Turbo', 130, 'Diesel', '4-Speed Modulated Powershift'), ['742', '943', '1255', '1644'], SOURCE_EPA_OEM),
];

// ============================================================================
// 26. GENIE (1975–2026)
// ============================================================================
const GENIE_MODELS = [
  mdl('S-45 XC', 'S-Series Telescopic Boom Lifts', 'Site Support', ['Boom Lift'], 1996, 2026, [
    eng('Deutz', 'D2011 L03i / D2.9 L4', 2.9, '4-Cyl', 49, 'Diesel', '4WD Hydrostatic', 1996, 2026),
    eng('Kubota / Ford', 'WG2503 / MSG-425', 2.5, '4-Cyl', 60, 'Dual Fuel (Gas/LPG)', '4WD Hydrostatic', 2000, 2026),
  ], ['S-40', 'S-45', 'S-60', 'S-60 J'], SOURCE_EPA_OEM),
  mdl('S-65 XC', 'Xtra Capacity Telescopic Boom Lifts', 'Site Support', ['Boom Lift'], 2018, 2026, [
    eng('Deutz', 'D2.9 L4 Tier 4F', 2.9, '4-Cyl', 49, 'Diesel', '4WD Positive Traction Hydrostatic', 2018, 2026),
    eng('Deutz', 'TD2.9 L4 Turbo', 2.9, '4-Cyl Turbo', 74, 'Diesel', '4WD Hydrostatic', 2018, 2026),
    eng('Ford', 'MSG-425 EFI', 2.5, '4-Cyl', 75, 'Dual Fuel (Gas/LPG)', '4WD Hydrostatic', 2018, 2026),
  ], ['S65XC'], SOURCE_EPA_OEM),
  mdl('S-85 XC', 'Xtra Capacity High-Reach Boom Lifts', 'Site Support', ['Boom Lift'], 2018, 2026, [
    eng('Deutz', 'TD2.9 L4 Tier 4F', 2.9, '4-Cyl Turbo', 74, 'Diesel', '4WD Hydrostatic', 2018, 2026),
    eng('Perkins', '404F-E22TA', 2.2, '4-Cyl Turbo', 67, 'Diesel', '4WD Hydrostatic', 2018, 2026),
  ], ['S-80', 'S-80 J', 'SX-105 XC', 'SX-135 XC'], SOURCE_EPA_OEM),
  mdl('Z-62/40', 'Z-Series Articulating Boom Lifts', 'Site Support', ['Boom Lift'], 1998, 2026, [
    eng('Deutz', 'D2.9 L4', 2.9, '4-Cyl', 49, 'Diesel', '4WD Hydrostatic', 1998, 2026),
    eng('Ford', 'MSG-425', 2.5, '4-Cyl', 75, 'Dual Fuel (Gas/LPG)', '4WD Hydrostatic', 2002, 2026),
  ], ['Z-34/22 IC', 'Z-45 XC', 'Z-60/34', 'Z-80/60'], SOURCE_EPA_OEM),
  mdl('GS-1930', 'GS Slab Electric Scissor Lifts', 'Site Support', ['Scissor Lift'], 1998, 2026, se('Genie Electric', '24V DC E-Drive', 0.0, 'Electric Motor', 8, 'Electric', 'AC Sealed Electric Wheel Motors'), ['GS-1932', 'GS-2632', 'GS-3246', 'GS-4047'], SOURCE_EPA_OEM),
  mdl('GS-4390 RT', 'GS Rough-Terrain Scissor Lifts', 'Site Support', ['Scissor Lift'], 2002, 2026, [
    eng('Deutz', 'D2.9 L4', 2.9, '4-Cyl', 49, 'Diesel', '4WD Hydrostatic', 2002, 2026),
    eng('Ford', 'MSG-425', 2.5, '4-Cyl', 75, 'Dual Fuel (Gas/LPG)', '4WD Hydrostatic', 2005, 2026),
  ], ['GS-3369 RT', 'GS-5390 RT'], SOURCE_EPA_OEM),
  mdl('GTH-5519', 'GTH Compact Telehandlers', 'Heavy Equipment', TLH, 2007, 2026, se('Deutz', 'TD 2.9 L4', 2.9, '4-Cyl Turbo', 74, 'Diesel', 'Hydrostatic Variable Speed'), [], SOURCE_EPA_OEM),
  mdl('GTH-636', 'GTH Construction Telehandlers', 'Heavy Equipment', TLH, 2007, 2024, se('Deutz', 'TCD 3.6 L4', 3.6, '4-Cyl Turbo', 74, 'Diesel', '3-Speed Powershift'), [], SOURCE_EPA_OEM),
  mdl('GTH-844', 'GTH Construction Telehandlers', 'Heavy Equipment', TLH, 2006, 2026, [
    eng('Perkins / Deutz', '1104D-44T / TCD 3.6 L4', 3.6, '4-Cyl Turbo', 74, 'Diesel', '3-Speed Powershift', 2006, 2026),
    eng('Deutz', 'TCD 3.6 L4 High-Torque', 3.6, '4-Cyl Turbo', 99, 'Diesel', '3-Speed Powershift', 2015, 2026),
  ], [], SOURCE_EPA_OEM),
  mdl('GTH-1056', 'GTH High-Reach Telehandlers', 'Heavy Equipment', TLH, 2007, 2026, [
    eng('Deutz', 'TCD 3.6 L4', 3.6, '4-Cyl Turbo', 74, 'Diesel', '3-Speed Powershift', 2007, 2026),
    eng('Deutz / Perkins', 'TCD 3.6 L4 High-Output', 3.6, '4-Cyl Turbo', 121, 'Diesel', '4-Speed Powershift', 2015, 2026),
  ], ['GTH-1256', 'GTH-1544'], SOURCE_EPA_OEM),
];

// ============================================================================
// 27. MASSEY FERGUSON (1970–2026)
// ============================================================================
const MASSEY_FERGUSON_MODELS = [
  mdl('MF 50', 'Industrial Tractor-Loader-Backhoes', 'Heavy Equipment', BKH, 1970, 1994, se('Perkins', 'AD4.203 / A4.236', 3.9, '4-Cyl', 65, 'Diesel', 'Instant Reverse Torque Converter'), ['MF 50B', 'MF 50D', 'MF 50E', 'MF 50H', 'MF 50HX']),
  mdl('MF 60', 'Industrial Tractor-Loader-Backhoes', 'Heavy Equipment', BKH, 1975, 1994, se('Perkins', 'A4.236 / A4.248', 3.9, '4-Cyl', 68, 'Diesel', '4-Speed Powershuttle'), ['MF 60H', 'MF 70', 'MF 80']),
  mdl('MF 65', 'Classic Industrial Utility Loaders', 'Heavy Equipment', LDR, 1970, 1976, se('Perkins', 'AD4.203', 3.3, '4-Cyl', 58, 'Diesel', 'Dual-Range Manual / Multipower'), ['MF 20', 'MF 30', 'MF 40'], SOURCE_EPA_OEM),
  mdl('MF 55C', 'Classic Articulated Wheel Loaders', 'Heavy Equipment', LDR, 1976, 1988, se('Perkins / Hanomag', '6.354 / D962K', 5.8, '6-Cyl', 144, 'Diesel', 'Powershift'), ['MF 44C', 'MF 66C']),
  mdl('MF 750', 'Industrial Backhoe Loaders', 'Heavy Equipment', BKH, 1986, 2001, se('Perkins', '1004.4T', 4.0, '4-Cyl Turbo', 86, 'Diesel', '4-Speed Powershuttle'), ['MF 860', 'MF 965'], SOURCE_EPA_OEM),
  mdl('MF 4707', 'Global Series Utility Loader Tractors', 'Heavy Equipment', LDR, 2016, 2026, se('AGCO Power', '33AWFC', 3.3, '3-Cyl Turbo', 75, 'Diesel', '12x12 Power-Shuttle'), ['MF 2600H', 'MF 4710', 'MF 5711'], SOURCE_EPA_OEM),
];

// ============================================================================
// 28. VERMEER (1972–2026)
// ============================================================================
const VERMEER_MODELS = [
  mdl('M475', 'Classic M-Series Wheel Trenchers', 'Heavy Equipment', DRL, 1972, 1995, se('Detroit Diesel / John Deere', '4-53 / 4239D', 3.9, '4-Cyl', 78, 'Diesel', 'Hydrostatic'), ['M 455 / M455A', 'M 475A', 'M 485', 'M 495']),
  mdl('T655', 'Commander Track Trenchers', 'Heavy Equipment', DRL, 1985, 2026, se('John Deere / Cat', '6068H / C7.1', 6.8, '6-Cyl Turbo', 250, 'Diesel', 'Hydrostatic Crawler'), ['T 300B', 'T455', 'T555', 'T755', 'T855']),
  mdl('RTX550', 'RTX Ride-On Utility Trenchers', 'Heavy Equipment', DRL, 2010, 2026, se('Cummins / Kubota', 'B2.8 / V2607', 2.6, '4-Cyl Turbo', 67, 'Diesel', 'Hydrostatic Quad-Track / Tire'), ['RTX450', 'RTX750', 'RTX1250'], SOURCE_EPA_OEM),
  mdl('D10x15 S3', 'Navigator Horizontal Directional Drills', 'Heavy Equipment', DRL, 2002, 2026, se('Kubota / Deutz', 'V2607 / TD2.9', 2.6, '4-Cyl Turbo', 60, 'Diesel', 'Rack & Pinion Hydrostatic'), ['D7x11', 'D9x13', 'D10x15', 'D16x20'], SOURCE_EPA_OEM),
  mdl('D20x22 S3', 'Navigator Horizontal Directional Drills', 'Heavy Equipment', DRL, 2005, 2026, se('Deutz', 'TD2.9 L4', 2.9, '4-Cyl Turbo', 74, 'Diesel', 'Rack & Pinion Hydrostatic'), ['D20x22', 'D23x30 S3'], SOURCE_EPA_OEM),
  mdl('D24x40 S3', 'Navigator Horizontal Directional Drills', 'Heavy Equipment', DRL, 1996, 2026, [
    eng('John Deere', '4045TF275 / 4045HFC', 4.5, '4-Cyl Turbo', 125, 'Diesel', 'Rack & Pinion Hydrostatic', 1996, 2026),
    eng('Cummins', 'QSB4.5', 4.5, '4-Cyl Turbo', 140, 'Diesel', 'Rack & Pinion Hydrostatic', 2010, 2026),
  ], ['D24x40A', 'D24x40 Series II'], SOURCE_EPA_OEM),
  mdl('D40x55 S3', 'Mid-Range Pipeline Directional Drills', 'Heavy Equipment', DRL, 2004, 2026, se('John Deere', '4045HFC04', 4.5, '4-Cyl Twin-Turbo', 140, 'Diesel', 'Rack & Pinion Hydrostatic'), ['D36x50', 'D36x50 Series II'], SOURCE_EPA_OEM),
  mdl('D100x140 S3', 'Pipeline Maxi-Rig Directional Drills', 'Heavy Equipment', DRL, 2002, 2026, se('Caterpillar', 'C7.1 / C9 ACERT', 7.0, '6-Cyl Turbo', 275, 'Diesel', 'Rack & Pinion Hydrostatic'), ['D60x90 S3', 'D80x100', 'D220x300'], SOURCE_EPA_OEM),
  mdl('S925TX', 'Mini Skid Steers', 'Heavy Equipment', SSL, 2008, 2026, se('Kubota', 'D1305 / V1505', 1.5, '4-Cyl', 35, 'Diesel', 'Hydrostatic Track'), ['CTX100', 'CTX160'], SOURCE_EPA_OEM),
  mdl('PD10', 'Solar & Pipeline Pile Drivers', 'Heavy Equipment', DRL, 2012, 2026, se('CAT / Yanmar', 'C2.2 / 4TNV88C', 2.2, '4-Cyl', 49, 'Diesel', 'Hydrostatic Track'), ['PD10R'], SOURCE_EPA_OEM),
];

// ============================================================================
// 29. DITCH WITCH (1970–2026)
// ============================================================================
const DITCH_WITCH_MODELS = [
  mdl('R40', 'Classic R- & V-Series Ride-On Trenchers', 'Heavy Equipment', DRL, 1970, 1992, se('Wisconsin / Deutz', 'F3L912', 2.8, '3-Cyl Air-Cooled', 45, 'Diesel', 'Mechanical / Hydrostatic'), ['J20', 'V 30', 'R 30', 'R 65']),
  mdl('R100', 'Heavy Pipeline Trenchers', 'Heavy Equipment', DRL, 1975, 1998, se('John Deere / Detroit', '6414T / 4-53T', 6.8, '6-Cyl Turbo', 140, 'Diesel', 'Hydrostatic'), ['3500', '3700', '7610']),
  mdl('RT45', 'RT Ride-On Trenchers', 'Heavy Equipment', DRL, 2005, 2026, se('Yanmar / Deutz', '4TNV88C / D2.9', 2.2, '4-Cyl', 49, 'Diesel', 'Hydrostatic'), ['RT55', 'RT80', 'RT120'], SOURCE_EPA_OEM),
  mdl('JT9', 'Jet Trac Horizontal Directional Drills', 'Heavy Equipment', DRL, 1995, 2026, se('Kubota', 'D1105 / V1505', 1.5, '4-Cyl', 25, 'Diesel', 'Rack & Pinion Hydrostatic'), ['JT5', 'JT920', 'JT922'], SOURCE_EPA_OEM),
  mdl('JT20', 'Jet Trac Horizontal Directional Drills', 'Heavy Equipment', DRL, 2000, 2026, se('Deutz', 'TD2.9 L4', 2.9, '4-Cyl Turbo', 74, 'Diesel', 'Rack & Pinion Hydrostatic'), ['JT1720', 'JT2020', 'JT24'], SOURCE_EPA_OEM),
  mdl('JT25', 'Jet Trac Horizontal Directional Drills', 'Heavy Equipment', DRL, 2008, 2026, se('Cummins', 'QSB4.5', 4.5, '4-Cyl Turbo', 130, 'Diesel', 'Rack & Pinion Hydrostatic'), ['JT2720', 'JT28'], SOURCE_EPA_OEM),
  mdl('JT40', 'Heavy Jet Trac Directional Drills', 'Heavy Equipment', DRL, 2004, 2026, se('Cummins', 'QSB4.5 / B6.7', 4.5, '4-Cyl Turbo', 160, 'Diesel', 'Rack & Pinion Hydrostatic'), ['JT30', 'JT3020', 'JT4020'], SOURCE_EPA_OEM),
  mdl('JT100', 'All-Terrain & Pipeline Directional Drills', 'Heavy Equipment', DRL, 2005, 2026, se('Cummins', 'QSC8.3 / L9', 8.9, '6-Cyl Turbo', 268, 'Diesel', 'Rack & Pinion Hydrostatic'), ['JT60', 'AT30', 'AT40', 'AT60', 'AT120'], SOURCE_EPA_OEM),
  mdl('SK1050', 'Stand-On Mini Skid Steers', 'Heavy Equipment', SSL, 2010, 2026, se('Yanmar', '3TNV88C / 4TNV86CT', 1.6, '3-Cyl', 37, 'Diesel', 'Hydrostatic Track'), ['SK755', 'SK800', 'SK1550', 'SK3000'], SOURCE_EPA_OEM),
];

// ============================================================================
// 30. BOMAG (1970–2026, incl. Koehring-Bomag / Buffalo-Bomag)
// ============================================================================
const BOMAG_MODELS = [
  mdl('BW 210', 'Classic Buffalo-Bomag Soil Rollers', 'Heavy Equipment', CMP, 1972, 1995, se('Detroit Diesel / Deutz', '4-53 / BF6L913', 6.1, '6-Cyl Air-Cooled', 120, 'Diesel', 'Hydrostatic'), ['BW 210A', 'BW 213', 'BW 214', 'K 300']),
  mdl('BW 141 AD', 'Classic Tandem Asphalt Rollers', 'Heavy Equipment', CMP, 1978, 2004, se('Deutz', 'F4L912 / BF4M1012', 3.2, '4-Cyl', 75, 'Diesel', 'Hydrostatic'), ['BW 120AD', 'BW 130AD', 'BW 142D']),
  mdl('BMP 8500', 'Multipurpose Trench Compactors', 'Heavy Equipment', CMP, 2004, 2026, se('Kubota', 'D1005', 1.0, '3-Cyl', 19, 'Diesel', 'Radio Remote Hydrostatic'), ['BMP 851'], SOURCE_EPA_OEM),
  mdl('BW 120 AD-5', 'Light Tandem Vibratory Rollers', 'Heavy Equipment', CMP, 2002, 2026, se('Kubota', 'D1703 / D1803', 1.7, '3-Cyl', 33, 'Diesel', 'Hydrostatic'), ['BW 90 AD-5', 'BW 100 AD-5', 'BW 138 AD-5'], SOURCE_EPA_OEM),
  mdl('BW 161 AD-5', 'Heavy Tandem Asphalt Rollers', 'Heavy Equipment', CMP, 2002, 2026, se('Deutz', 'TCD 3.6 L4', 3.6, '4-Cyl Turbo', 114, 'Diesel', 'Hydrostatic'), ['BW 174 AP', 'BW 190 AD-5', 'BW 206 AD-5'], SOURCE_EPA_OEM),
  mdl('BW 177 D-5', 'Single-Drum Soil Compactors', 'Heavy Equipment', CMP, 2002, 2026, se('Kubota', 'V3307-CR-T', 3.3, '4-Cyl Turbo', 74, 'Diesel', 'Dual-Pump Hydrostatic'), ['BW 145 D-5', 'BW 177 DH-5'], SOURCE_EPA_OEM),
  mdl('BW 211 D-5', 'Single-Drum Vibratory Soil Rollers', 'Heavy Equipment', CMP, 2000, 2026, se('Deutz', 'TCD 3.6 L4', 3.6, '4-Cyl Turbo', 127, 'Diesel', 'Hydrostatic'), ['BW 211 D-40', 'BW 211 PD-5'], SOURCE_EPA_OEM),
  mdl('BW 213 DH-5', 'Heavy Single-Drum Soil Rollers', 'Heavy Equipment', CMP, 1998, 2026, se('Deutz', 'TCD 4.1 L4', 4.1, '4-Cyl Turbo', 154, 'Diesel', 'Dual-Pump Hydrostatic'), ['BW 213 D-3', 'BW 213 D-5', 'BW 216 D-5', 'BW 219 DH-5'], SOURCE_EPA_OEM),
  mdl('BC 772 RB-4', 'Refuse & Heavy Earthwork Compactors', 'Heavy Equipment', CMP, 2005, 2026, se('Mercedes-Benz / MTU', 'OM470LA', 10.7, '6-Cyl Turbo', 442, 'Diesel', '4-Wheel Hydrostatic'), ['BC 473 RB', 'BC 773 RB-5'], SOURCE_EPA_OEM),
];

// ============================================================================
// 31. INGERSOLL-RAND (1970–2026, incl. Doosan Portable Power / IR heritage)
// ============================================================================
const INGERSOLL_RAND_MODELS = [
  mdl('P175', 'Classic Portable Rotary-Screw Compressors', 'Site Support', ['Air Compressor'], 1972, 1994, se('Deutz / John Deere', 'F4L912 / 4239D', 3.9, '4-Cyl', 68, 'Diesel', 'Direct Rotary Screw'), ['P160', 'P250WD'], SOURCE_EPA_OEM),
  mdl('P185WJD', 'Towable Utility Air Compressors', 'Site Support', ['Air Compressor'], 1988, 2026, [
    eng('John Deere', '4039D / 4024TF', 2.4, '4-Cyl Turbo', 49, 'Diesel', 'Direct Drive Airend', 1988, 2016),
    eng('Yanmar / Doosan', '4TNV88C / D24', 2.4, '4-Cyl Turbo', 49, 'Diesel', 'Direct Drive Airend', 2012, 2026),
    eng('Kubota', 'V2403M-T', 2.4, '4-Cyl Turbo', 49, 'Diesel', 'Direct Drive Airend', 2005, 2026),
  ], ['P185', 'XP185WJD'], SOURCE_EPA_OEM),
  mdl('XP375WJD', 'Mid-Range Portable Air Compressors', 'Site Support', ['Air Compressor'], 1990, 2024, [
    eng('John Deere', '4045TF / 4045HFC', 4.5, '4-Cyl Turbo', 115, 'Diesel', 'Direct Drive Airend', 1990, 2024),
    eng('Cummins', '4BT3.9 / QSB4.5', 4.5, '4-Cyl Turbo', 120, 'Diesel', 'Direct Drive Airend', 1995, 2024),
  ], ['HP375WJD', 'HP450WCU'], SOURCE_EPA_OEM),
  mdl('HP750WCU', 'High-Pressure Pipeline Air Compressors', 'Site Support', ['Air Compressor'], 1988, 2026, [
    eng('Cummins', 'L10 / QSL9', 8.9, '6-Cyl Turbo', 300, 'Diesel', 'Direct Drive Two-Stage Airend', 1988, 2026),
    eng('Caterpillar', '3306T / C9 ACERT', 8.8, '6-Cyl Turbo', 325, 'Diesel', 'Direct Drive Airend', 1992, 2026),
  ], ['XP825WCU', 'XHP900WCAT', 'XHP1070WCAT'], SOURCE_EPA_OEM),
  mdl('SD-100D', 'SD Series Vibratory Soil Compactors', 'Heavy Equipment', CMP, 1980, 2010, se('Cummins', '4BT3.9 / B4.5', 4.5, '4-Cyl Turbo', 125, 'Diesel', 'Hydrostatic'), ['SP-54', 'SD-45D', 'SD-70D', 'SD-105DX', 'SD-116DX']),
  mdl('DD-90', 'DD Series Tandem Asphalt Compactors', 'Heavy Equipment', CMP, 1985, 2008, se('Cummins', '4BT3.9', 3.9, '4-Cyl Turbo', 110, 'Diesel', 'Hydrostatic'), ['DD-24', 'DD-110', 'DD-130']),
  mdl('VR-1056', 'VR Series Rough-Terrain Telehandlers', 'Heavy Equipment', TLH, 1996, 2008, se('Cummins', '4BT3.9 / QSB4.5', 4.5, '4-Cyl Turbo', 110, 'Diesel', 'Powershift'), ['VR-642', 'VR-843'], SOURCE_EPA_OEM),
  mdl('ECM-350', 'Crawler Rock Drills', 'Heavy Equipment', DRL, 1975, 2006, se('Cummins / Cat', '6CT8.3 / 3126B', 8.3, '6-Cyl Turbo', 240, 'Diesel', 'Hydraulic Top-Hammer Crawler'), ['CM-780D', 'ECM-590']),
  mdl('L6', 'Towable Jobsite Light Towers', 'Site Support', ['Light Tower'], 1998, 2024, se('Kubota', 'D905 / D1005', 1.0, '3-Cyl', 13, 'Diesel', '6kW 1800 RPM Generator'), ['L8'], SOURCE_EPA_OEM),
];

// ============================================================================
// 32. PETERBILT (1970–2026) — Multi-Engine Highway & Oilfield Trucks
// ============================================================================
const PETERBILT_MODELS = [
  mdl('281 / 351', 'Classic Butterfly-Hood Conventionals', 'Transport & Hauling', TRK_HEAVY, 1970, 1976, [
    eng('Cummins', 'NTC-290 / NTC-350', 14.0, '6-Cyl Turbo', 350, 'Diesel', 'Fuller Roadranger 13-Speed Manual', 1970, 1976),
    eng('Detroit Diesel', '8V-71N / 8V-71T', 9.3, 'V8 2-Stroke', 318, 'Diesel', 'Spicer / Fuller 13-Speed Manual', 1970, 1976),
    eng('Caterpillar', '1693TA', 14.6, '6-Cyl Turbo', 375, 'Diesel', 'Fuller 13-Speed Manual', 1970, 1976),
  ], ['281', '351'], SOURCE_VPIC_EPA_OEM),
  mdl('352', 'Pacemaker Cabover COE', 'Transport & Hauling', TRK_HWY, 1970, 1980, [
    eng('Cummins', 'NTC-350 / NTC-400', 14.0, '6-Cyl Turbo', 350, 'Diesel', 'Fuller RT-12513 13-Speed Manual', 1970, 1980),
    eng('Detroit Diesel', '8V-71T / 8V-92TA', 12.1, 'V8 2-Stroke Turbo', 430, 'Diesel', 'Fuller 13-Speed Manual', 1970, 1980),
    eng('Caterpillar', '3406A', 14.6, '6-Cyl Turbo', 380, 'Diesel', 'Fuller 13-Speed Manual', 1974, 1980),
  ], ['352H'], SOURCE_VPIC_EPA_OEM),
  mdl('359', 'Classic Extended-Hood Conventional', 'Transport & Hauling', TRK_HEAVY, 1970, 1987, [
    eng('Cummins', 'NTC-350 / NTC-400 Big Cam', 14.0, '6-Cyl Turbo', 400, 'Diesel', 'Fuller Roadranger 13/15-Speed Manual', 1970, 1987),
    eng('Caterpillar', '3406A / 3406B', 14.6, '6-Cyl Turbo', 425, 'Diesel', 'Fuller 13/15/18-Speed Manual', 1973, 1987),
    eng('Detroit Diesel', '8V-92TA Silver', 12.1, 'V8 2-Stroke Turbo', 445, 'Diesel', 'Fuller 13-Speed Manual', 1976, 1987),
    eng('Caterpillar', '3408 PCTA', 18.0, 'V8 Turbo', 450, 'Diesel', 'Fuller 15-Speed Overdrive Manual', 1977, 1986),
  ], ['359 EXHD'], SOURCE_VPIC_EPA_OEM),
  mdl('353', 'Oilfield Heavy-Haul Conventional', 'Transport & Hauling', TRK_HEAVY, 1972, 1987, [
    eng('Cummins', 'NTC-400 Big Cam III', 14.0, '6-Cyl Turbo', 400, 'Diesel', 'Fuller 15-Speed Deep Reduction Manual', 1972, 1987),
    eng('Caterpillar', '3406B', 14.6, '6-Cyl Turbo', 425, 'Diesel', 'Spicer Aux / 18-Speed Manual', 1978, 1987),
  ], ['349', '397'], SOURCE_VPIC_EPA_OEM),
  mdl('362', 'Cabover COE Highway Tractor', 'Transport & Hauling', TRK_HWY, 1981, 2005, [
    eng('Cummins', 'NTC-400 / N14 Celect', 14.0, '6-Cyl Turbo', 435, 'Diesel', 'Eaton Fuller 13-Speed Manual', 1981, 2001),
    eng('Caterpillar', '3406B / 3406E', 14.6, '6-Cyl Turbo', 455, 'Diesel', 'Eaton Fuller 13/18-Speed Manual', 1981, 2005),
    eng('Detroit Diesel', 'Series 60 12.7L', 12.7, '6-Cyl Turbo', 430, 'Diesel', 'Eaton Fuller 10/13-Speed Manual', 1988, 2005),
  ], ['362E'], SOURCE_VPIC_EPA_OEM),
  mdl('377', 'Aerodynamic Set-Back / Set-Forward Tractor', 'Transport & Hauling', TRK_HWY, 1987, 2000, [
    eng('Caterpillar', '3406B / 3406E', 14.6, '6-Cyl Turbo', 435, 'Diesel', 'Eaton Fuller 10/13-Speed Manual', 1987, 2000),
    eng('Cummins', 'N14 Celect Plus', 14.0, '6-Cyl Turbo', 460, 'Diesel', 'Eaton Fuller 13-Speed Manual', 1991, 2000),
    eng('Detroit Diesel', 'Series 60 12.7L', 12.7, '6-Cyl Turbo', 430, 'Diesel', 'Eaton Fuller 10/13-Speed Manual', 1987, 2000),
  ], ['375', '377A/E'], SOURCE_VPIC_EPA_OEM),
  mdl('357', 'Heavy Vocational Chassis & Winch Truck', 'Transport & Hauling', TRK_HEAVY, 1987, 2007, [
    eng('Caterpillar', '3306 / C12 / C15', 14.6, '6-Cyl Turbo', 435, 'Diesel', 'Eaton Fuller 8LL / 18-Speed Manual', 1987, 2007),
    eng('Cummins', 'L10 / M11 / ISM', 10.8, '6-Cyl Turbo', 385, 'Diesel', 'Allison 4500 RDS / Fuller 8LL', 1987, 2007),
  ], [], SOURCE_VPIC_EPA_OEM),
  mdl('378', 'Sloped-Hood Heavy Highway & Vocational Tractor', 'Transport & Hauling', TRK_HEAVY, 1987, 2007, [
    eng('Caterpillar', '3406B / 3406E', 14.6, '6-Cyl Turbo', 455, 'Diesel', 'Eaton Fuller 13/18-Speed Manual', 1987, 1999),
    eng('Caterpillar', 'C15 / C15 ACERT', 15.2, '6-Cyl Twin-Turbo', 475, 'Diesel', 'Eaton Fuller 18-Speed Manual', 1999, 2007),
    eng('Cummins', 'N14 / ISX15', 14.9, '6-Cyl Turbo', 475, 'Diesel', 'Eaton Fuller 13/18-Speed Manual', 1991, 2007),
  ], [], SOURCE_VPIC_EPA_OEM),
  mdl('379', 'Flagship Extended-Hood Conventional', 'Transport & Hauling', TRK_HEAVY, 1987, 2007, [
    eng('Caterpillar', '3406B / 3406E', 14.6, '6-Cyl Turbo', 475, 'Diesel', 'Eaton Fuller 13/18-Speed Manual', 1987, 1999),
    eng('Caterpillar', 'C15 / C15 ACERT', 15.2, '6-Cyl Twin-Turbo', 550, 'Diesel', 'Eaton Fuller RTLO-18918B 18-Speed Manual', 1999, 2007),
    eng('Cummins', 'N14 Celect Plus / ISX15', 14.9, '6-Cyl Turbo', 525, 'Diesel', 'Eaton Fuller 13/18-Speed Manual', 1991, 2007),
    eng('Detroit Diesel', 'Series 60 12.7L / 14.0L', 12.7, '6-Cyl Turbo', 470, 'Diesel', 'Eaton Fuller 13-Speed Manual', 1987, 2007),
  ], ['379 EXHD'], SOURCE_VPIC_EPA_OEM),
  mdl('385', 'Regional Haul Aerodynamic Tractor', 'Transport & Hauling', TRK_HWY, 1996, 2007, [
    eng('Caterpillar', 'C12 / C13 ACERT', 12.5, '6-Cyl Turbo', 410, 'Diesel', 'Eaton Fuller 10/13-Speed Manual', 1996, 2007),
    eng('Cummins', 'ISM', 10.8, '6-Cyl Turbo', 385, 'Diesel', 'Eaton Fuller 10-Speed Manual', 1998, 2007),
  ], ['384'], SOURCE_VPIC_EPA_OEM),
  mdl('387', 'Wide-Cab Aerodynamic Sleeper Tractor', 'Transport & Hauling', TRK_HWY, 1999, 2010, [
    eng('Caterpillar', 'C15 ACERT', 15.2, '6-Cyl Twin-Turbo', 475, 'Diesel', 'Eaton Fuller 13-Speed / UltraShift', 1999, 2009),
    eng('Cummins', 'ISX15', 14.9, '6-Cyl Turbo', 485, 'Diesel', 'Eaton Fuller 10/13-Speed Manual', 2001, 2010),
  ], ['587'], SOURCE_VPIC_EPA_OEM),
  mdl('386', 'Aerodynamic Long-Haul Tractor', 'Transport & Hauling', TRK_HWY, 2006, 2015, [
    eng('Caterpillar', 'C15 ACERT', 15.2, '6-Cyl Twin-Turbo', 475, 'Diesel', 'Eaton Fuller 13-Speed Manual', 2006, 2009),
    eng('Cummins', 'ISX15', 14.9, '6-Cyl Turbo', 485, 'Diesel', 'Eaton Fuller 13-Speed / UltraShift PLUS', 2006, 2015),
    eng('PACCAR', 'MX-13', 12.9, '6-Cyl Turbo', 455, 'Diesel', 'Eaton Fuller 13-Speed Manual', 2010, 2015),
  ], [], SOURCE_VPIC_EPA_OEM),
  mdl('388', 'Sloped-Hood Traditional Highway Tractor', 'Transport & Hauling', TRK_HEAVY, 2007, 2015, [
    eng('Caterpillar', 'C15 ACERT', 15.2, '6-Cyl Twin-Turbo', 475, 'Diesel', 'Eaton Fuller 18-Speed Manual', 2007, 2009),
    eng('Cummins', 'ISX15', 14.9, '6-Cyl Turbo', 525, 'Diesel', 'Eaton Fuller 18-Speed Manual', 2007, 2015),
    eng('PACCAR', 'MX-13', 12.9, '6-Cyl Turbo', 485, 'Diesel', 'Eaton Fuller 13/18-Speed Manual', 2010, 2015),
  ], [], SOURCE_VPIC_EPA_OEM),
  mdl('389', 'Flagship Extended-Hood Traditional Tractor', 'Transport & Hauling', TRK_HEAVY, 2007, 2023, [
    eng('Caterpillar', 'C15 ACERT', 15.2, '6-Cyl Twin-Turbo', 550, 'Diesel', 'Eaton Fuller 18-Speed Manual', 2007, 2009),
    eng('Cummins', 'ISX15 / X15 Performance', 14.9, '6-Cyl Turbo', 565, 'Diesel', 'Eaton Fuller RTLO-18918B 18-Speed Manual', 2007, 2023),
    eng('PACCAR', 'MX-13', 12.9, '6-Cyl Turbo', 510, 'Diesel', 'Eaton Fuller 13/18-Speed / PACCAR TX-18', 2010, 2023),
  ], ['389X'], SOURCE_VPIC_EPA_OEM),
  mdl('589', 'Next-Generation Flagship Traditional Tractor', 'Transport & Hauling', TRK_HEAVY, 2024, 2026, [
    eng('Cummins', 'X15 Performance Series', 14.9, '6-Cyl Turbo', 565, 'Diesel', 'Eaton Fuller 18-Speed Manual', 2024, 2026),
    eng('Cummins', 'X15 Productivity Series', 14.9, '6-Cyl Turbo', 605, 'Diesel', 'Eaton Endurant XD Pro 18-Speed Automated', 2024, 2026),
    eng('PACCAR', 'MX-13', 12.9, '6-Cyl Turbo', 510, 'Diesel', 'PACCAR TX-18 Pro Automated / 18-Speed Manual', 2024, 2026),
  ], [], SOURCE_VPIC_EPA_OEM),
  mdl('367', 'Severe-Duty Oilfield & Winch Tractor', 'Transport & Hauling', TRK_HEAVY, 2007, 2026, [
    eng('Caterpillar', 'C15 ACERT', 15.2, '6-Cyl Twin-Turbo', 500, 'Diesel', 'Eaton Fuller 18-Speed Manual', 2007, 2009),
    eng('Cummins', 'ISX15 / X15 Vocational', 14.9, '6-Cyl Turbo', 565, 'Diesel', 'Eaton Fuller 18-Speed / Allison 4500 RDS', 2007, 2026),
    eng('PACCAR', 'MX-13', 12.9, '6-Cyl Turbo', 510, 'Diesel', 'Eaton Fuller 18-Speed / TX-18 Pro', 2010, 2026),
  ], ['365'], SOURCE_VPIC_EPA_OEM),
  mdl('567', 'Set-Back / Set-Forward Vocational & Oilfield Truck', 'Transport & Hauling', TRK_HEAVY, 2014, 2026, [
    eng('Cummins', 'ISX15 / X15 Vocational', 14.9, '6-Cyl Turbo', 565, 'Diesel', 'Eaton Fuller 18-Speed Manual', 2014, 2026),
    eng('PACCAR', 'MX-13', 12.9, '6-Cyl Turbo', 510, 'Diesel', 'PACCAR TX-18 Pro / Allison 4500 RDS', 2014, 2026),
    eng('PACCAR', 'MX-11', 10.8, '6-Cyl Turbo', 430, 'Diesel', 'Allison 4500 RDS 6-Speed Automatic', 2016, 2026),
  ], [], SOURCE_VPIC_EPA_OEM),
  mdl('579', 'UltraLoft Aerodynamic Highway Tractor', 'Transport & Hauling', TRK_HWY, 2012, 2026, [
    eng('PACCAR', 'MX-13', 12.9, '6-Cyl Turbo', 510, 'Diesel', 'PACCAR TX-12 Automated / Eaton 13-Speed', 2012, 2026),
    eng('Cummins', 'ISX15 / X15 Efficiency', 14.9, '6-Cyl Turbo', 500, 'Diesel', 'Eaton Endurant 12-Speed Automated', 2012, 2026),
  ], ['579EV'], SOURCE_VPIC_EPA_OEM),
  mdl('337', 'Medium-Duty Tanker / Water / Service Chassis', 'Transport & Hauling', TRK_MED, 1995, 2022, [
    eng('Caterpillar / Cummins', '3126B / ISC 8.3', 8.3, '6-Cyl Turbo', 300, 'Diesel', 'Allison 3000 RDS Automatic / Eaton 8LL', 1995, 2009),
    eng('PACCAR', 'PX-7 / PX-9', 8.9, '6-Cyl Turbo', 350, 'Diesel', 'Allison 3000 RDS 6-Speed Automatic', 2010, 2022),
  ], ['330', '335'], SOURCE_VPIC_EPA_OEM),
  mdl('348', 'Heavy Medium-Duty Vacuum & Water Truck', 'Transport & Hauling', TRK_MED, 2008, 2022, [
    eng('PACCAR', 'PX-8 / PX-9', 8.9, '6-Cyl Turbo', 380, 'Diesel', 'Allison 3000 / 3500 RDS Automatic', 2008, 2022),
    eng('Cummins', 'ISL9 / L9', 8.9, '6-Cyl Turbo', 380, 'Diesel', 'Eaton Fuller 8LL Manual', 2008, 2022),
  ], ['340'], SOURCE_VPIC_EPA_OEM),
  mdl('548', 'Next-Gen Medium/Heavy Vocational Chassis', 'Transport & Hauling', TRK_MED, 2021, 2026, [
    eng('PACCAR', 'PX-9', 8.9, '6-Cyl Turbo', 380, 'Diesel', 'PACCAR TX-8 Automatic / Allison 3500 RDS', 2021, 2026),
    eng('PACCAR', 'PX-7', 6.7, '6-Cyl Turbo', 325, 'Diesel', 'PACCAR TX-8 8-Speed Automatic', 2021, 2026),
  ], ['536', '537', '520'], SOURCE_VPIC_EPA_OEM),
];

// ============================================================================
// 33. KENWORTH (1970–2026) — Multi-Engine Highway & Oilfield Trucks
// ============================================================================
const KENWORTH_MODELS = [
  mdl('W900A', 'Classic Extended-Hood Conventional', 'Transport & Hauling', TRK_HEAVY, 1970, 1982, [
    eng('Cummins', 'NTC-350 / NTC-400', 14.0, '6-Cyl Turbo', 400, 'Diesel', 'Fuller Roadranger 13/15-Speed Manual', 1970, 1982),
    eng('Caterpillar', '1693TA / 3406A', 14.6, '6-Cyl Turbo', 380, 'Diesel', 'Fuller 13-Speed Manual', 1970, 1982),
    eng('Detroit Diesel', '8V-71T / 8V-92TA', 12.1, 'V8 2-Stroke Turbo', 430, 'Diesel', 'Fuller 13-Speed Manual', 1970, 1982),
  ], [], SOURCE_VPIC_EPA_OEM),
  mdl('W900', 'Iconic Long-Hood Conventional (W900B / W900L)', 'Transport & Hauling', TRK_HEAVY, 1982, 2026, [
    eng('Caterpillar', '3406B / 3406E / C15 ACERT', 15.2, '6-Cyl Turbo', 550, 'Diesel', 'Eaton Fuller 13/18-Speed Manual', 1982, 2009),
    eng('Cummins', 'NTC-400 / N14 / ISX15 / X15', 14.9, '6-Cyl Turbo', 565, 'Diesel', 'Eaton Fuller RTLO-18918B 18-Speed Manual', 1982, 2026),
    eng('Detroit Diesel', 'Series 60 12.7L / 14.0L', 12.7, '6-Cyl Turbo', 470, 'Diesel', 'Eaton Fuller 13-Speed Manual', 1987, 2007),
    eng('PACCAR', 'MX-13', 12.9, '6-Cyl Turbo', 510, 'Diesel', 'Eaton Fuller 18-Speed / PACCAR TX-18', 2010, 2026),
  ], ['W900B', 'W900L', 'W900S'], SOURCE_VPIC_EPA_OEM),
  mdl('W990', 'Modern Long-Hood Highway & Heavy-Haul Tractor', 'Transport & Hauling', TRK_HEAVY, 2019, 2026, [
    eng('PACCAR', 'MX-13', 12.9, '6-Cyl Turbo', 510, 'Diesel', 'PACCAR TX-12 / TX-18 Automated', 2019, 2026),
    eng('Cummins', 'X15 Performance Series', 14.9, '6-Cyl Turbo', 565, 'Diesel', 'Eaton Fuller 18-Speed Manual', 2019, 2026),
  ], [], SOURCE_VPIC_EPA_OEM),
  mdl('K100', 'Cabover COE Highway Tractor (K100C / K100E)', 'Transport & Hauling', TRK_HWY, 1970, 2004, [
    eng('Cummins', 'NTC-350 / N14 Celect', 14.0, '6-Cyl Turbo', 435, 'Diesel', 'Fuller 13-Speed Manual', 1970, 2001),
    eng('Caterpillar', '3406B / 3406E', 14.6, '6-Cyl Turbo', 455, 'Diesel', 'Fuller 13/18-Speed Manual', 1976, 2004),
    eng('Detroit Diesel', '8V-92TA / Series 60', 12.7, '6-Cyl Turbo', 430, 'Diesel', 'Fuller 10/13-Speed Manual', 1972, 2004),
  ], ['K100C', 'K100E', 'K 100E'], SOURCE_VPIC_EPA_OEM),
  mdl('C500', 'Severe-Duty Oilfield Winch & Rig-Moving Truck', 'Transport & Hauling', TRK_HEAVY, 1972, 2026, [
    eng('Caterpillar', '3406B / 3408 / C15 / C18', 15.2, '6-Cyl Turbo', 550, 'Diesel', 'Eaton Fuller 18-Speed + Aux Box / Allison', 1972, 2010),
    eng('Cummins', 'NTC-400 / N14 / ISX15 / X15', 14.9, '6-Cyl Turbo', 605, 'Diesel', 'Eaton Fuller 18-Speed / Allison 4700 RDS', 1972, 2026),
    eng('PACCAR', 'MX-13', 12.9, '6-Cyl Turbo', 510, 'Diesel', 'Eaton Fuller 18-Speed / Allison 4500 RDS', 2011, 2026),
  ], ['C500B', 'C550', '548CH'], SOURCE_VPIC_EPA_OEM),
  mdl('T600', 'Anteater Aerodynamic Highway Tractor', 'Transport & Hauling', TRK_HWY, 1985, 2007, [
    eng('Cummins', 'L10 / N14 / ISX15', 14.0, '6-Cyl Turbo', 475, 'Diesel', 'Eaton Fuller 10/13-Speed Manual', 1985, 2007),
    eng('Caterpillar', '3406B / 3406E / C15', 14.6, '6-Cyl Turbo', 475, 'Diesel', 'Eaton Fuller 13-Speed Manual', 1985, 2007),
    eng('Detroit Diesel', 'Series 60 12.7L', 12.7, '6-Cyl Turbo', 430, 'Diesel', 'Eaton Fuller 10/13-Speed Manual', 1987, 2007),
  ], ['T600A', 'T600B'], SOURCE_VPIC_EPA_OEM),
  mdl('T660', 'Aerodynamic Sleeper & Daycab Tractor', 'Transport & Hauling', TRK_HWY, 2008, 2017, [
    eng('Caterpillar', 'C15 ACERT', 15.2, '6-Cyl Twin-Turbo', 475, 'Diesel', 'Eaton Fuller 13-Speed Manual', 2008, 2010),
    eng('Cummins', 'ISX15', 14.9, '6-Cyl Turbo', 485, 'Diesel', 'Eaton Fuller 13-Speed / UltraShift PLUS', 2008, 2017),
    eng('PACCAR', 'MX-13', 12.9, '6-Cyl Turbo', 455, 'Diesel', 'Eaton Fuller 10/13-Speed Manual', 2010, 2017),
  ], ['T2000', 'T700'], SOURCE_VPIC_EPA_OEM),
  mdl('T680', 'Flagship Aerodynamic Highway Tractor', 'Transport & Hauling', TRK_HWY, 2013, 2026, [
    eng('PACCAR', 'MX-13', 12.9, '6-Cyl Turbo', 510, 'Diesel', 'PACCAR TX-12 Automated / Eaton 13-Speed', 2013, 2026),
    eng('Cummins', 'ISX15 / X15 Efficiency', 14.9, '6-Cyl Turbo', 500, 'Diesel', 'Eaton Endurant 12-Speed Automated', 2013, 2026),
  ], ['T680 Next Gen', 'T680E'], SOURCE_VPIC_EPA_OEM),
  mdl('T800', 'Sloped-Hood Heavy Vocational & Oilfield Workhorse', 'Transport & Hauling', TRK_HEAVY, 1986, 2025, [
    eng('Caterpillar', '3406B / 3406E / C15 ACERT', 15.2, '6-Cyl Turbo', 500, 'Diesel', 'Eaton Fuller 18-Speed Manual', 1986, 2009),
    eng('Cummins', 'N14 / ISM / ISX15 / X15', 14.9, '6-Cyl Turbo', 565, 'Diesel', 'Eaton Fuller 8LL / 18-Speed Manual', 1986, 2025),
    eng('PACCAR', 'MX-13', 12.9, '6-Cyl Turbo', 510, 'Diesel', 'Eaton Fuller 18-Speed / Allison 4500 RDS', 2010, 2025),
  ], ['T800B', 'T800H', 'T800W'], SOURCE_VPIC_EPA_OEM),
  mdl('T880', 'Modern Vocational, Winch, Vacuum & Heavy-Haul Truck', 'Transport & Hauling', TRK_HEAVY, 2014, 2026, [
    eng('PACCAR', 'MX-13', 12.9, '6-Cyl Turbo', 510, 'Diesel', 'PACCAR TX-18 Pro / Eaton Fuller 18-Speed', 2014, 2026),
    eng('Cummins', 'ISX15 / X15 Vocational', 14.9, '6-Cyl Turbo', 565, 'Diesel', 'Eaton Fuller RTLO-18918B 18-Speed Manual', 2014, 2026),
    eng('PACCAR', 'MX-11', 10.8, '6-Cyl Turbo', 430, 'Diesel', 'Allison 4500 RDS 6-Speed Automatic', 2016, 2026),
  ], ['T880S'], SOURCE_VPIC_EPA_OEM),
  mdl('T370', 'Medium-Duty Water, Fuel & Service Truck', 'Transport & Hauling', TRK_MED, 1994, 2022, [
    eng('Cummins', '6CT8.3 / ISB6.7 / ISC8.3', 6.7, '6-Cyl Turbo', 300, 'Diesel', 'Allison 3000 RDS / Eaton 6-Speed', 1994, 2012),
    eng('PACCAR', 'PX-7 / PX-9', 8.9, '6-Cyl Turbo', 350, 'Diesel', 'Allison 3000 RDS Automatic', 2010, 2022),
  ], ['T300', 'T400', 'T440', 'T470'], SOURCE_VPIC_EPA_OEM),
  mdl('T480', 'Next-Gen Medium/Heavy Vocational Chassis', 'Transport & Hauling', TRK_MED, 2022, 2026, [
    eng('PACCAR', 'PX-9', 8.9, '6-Cyl Turbo', 380, 'Diesel', 'PACCAR TX-8 Automatic / Allison 3500 RDS', 2022, 2026),
    eng('PACCAR', 'PX-7', 6.7, '6-Cyl Turbo', 325, 'Diesel', 'PACCAR TX-8 8-Speed Automatic', 2022, 2026),
  ], ['T280', 'T380'], SOURCE_VPIC_EPA_OEM),
];

// ============================================================================
// 34. WESTERN STAR (1970–2026) — Multi-Engine Highway & Oilfield Trucks
// ============================================================================
const WESTERN_STAR_MODELS = [
  mdl('4864', 'Heritage Set-Back / Set-Forward Vocational Truck', 'Transport & Hauling', TRK_HEAVY, 1970, 2001, [
    eng('Cummins', 'NTC-350 / N14 Celect', 14.0, '6-Cyl Turbo', 435, 'Diesel', 'Fuller Roadranger 13/15-Speed Manual', 1970, 2001),
    eng('Caterpillar', '3406A / 3406B / 3406E', 14.6, '6-Cyl Turbo', 455, 'Diesel', 'Fuller 15/18-Speed Manual', 1974, 2001),
    eng('Detroit Diesel', '8V-92TA / Series 60', 12.7, '6-Cyl Turbo', 430, 'Diesel', 'Fuller 13-Speed Manual', 1975, 2001),
  ], ['4864-2'], SOURCE_VPIC_EPA_OEM),
  mdl('4964', 'Heritage Long-Hood Heavy-Haul & Oilfield Truck', 'Transport & Hauling', TRK_HEAVY, 1970, 2002, [
    eng('Caterpillar', '3406B / 3406E', 14.6, '6-Cyl Turbo', 475, 'Diesel', 'Eaton Fuller 18-Speed Manual', 1974, 2002),
    eng('Cummins', 'NTC-400 / N14 Celect Plus', 14.0, '6-Cyl Turbo', 460, 'Diesel', 'Eaton Fuller 15/18-Speed Manual', 1970, 2002),
    eng('Detroit Diesel', 'Series 60 12.7L', 12.7, '6-Cyl Turbo', 470, 'Diesel', 'Eaton Fuller 13/18-Speed Manual', 1988, 2002),
  ], ['4964EX', '4964FX', '5964'], SOURCE_VPIC_EPA_OEM),
  mdl('4800', 'Constellation Heavy Vocational & Oilfield Truck', 'Transport & Hauling', TRK_HEAVY, 1997, 2021, [
    eng('Caterpillar', 'C12 / C13 / C15 ACERT', 15.2, '6-Cyl Turbo', 475, 'Diesel', 'Eaton Fuller 8LL / 18-Speed Manual', 1997, 2009),
    eng('Detroit Diesel', 'Series 60 / DD13', 12.8, '6-Cyl Turbo', 470, 'Diesel', 'Eaton Fuller 18-Speed / Allison 4500 RDS', 1997, 2021),
    eng('Cummins', 'ISM / ISL9 / ISX12', 11.9, '6-Cyl Turbo', 425, 'Diesel', 'Allison 4500 RDS Automatic', 2002, 2021),
  ], ['4800SB', '4800SF', '4800TS'], SOURCE_VPIC_EPA_OEM),
  mdl('4900', 'Constellation Flagship Heavy-Haul & Winch Tractor', 'Transport & Hauling', TRK_HEAVY, 2002, 2023, [
    eng('Caterpillar', 'C15 ACERT', 15.2, '6-Cyl Twin-Turbo', 550, 'Diesel', 'Eaton Fuller 18-Speed Manual', 2002, 2009),
    eng('Detroit Diesel', 'DD15 / DD16', 15.6, '6-Cyl Turbo', 600, 'Diesel', 'Eaton Fuller RTLO-18918B 18-Speed / DT12', 2008, 2023),
    eng('Cummins', 'ISX15 / X15', 14.9, '6-Cyl Turbo', 565, 'Diesel', 'Eaton Fuller 18-Speed Manual', 2002, 2023),
  ], ['4900EX', '4900FA', '4900SA', '4900SB', '4900TS'], SOURCE_VPIC_EPA_OEM),
  mdl('6900XD', 'Extreme-Duty Off-Highway Oilfield & Rig Mover', 'Transport & Hauling', TRK_HEAVY, 2002, 2024, [
    eng('Detroit Diesel', 'Series 60 14.0L / DD16', 15.6, '6-Cyl Turbo', 600, 'Diesel', 'Allison 4700 / 4800 RDS Planetary Automatic', 2002, 2024),
    eng('Caterpillar', 'C15 / C16 ACERT', 15.2, '6-Cyl Turbo', 550, 'Diesel', 'Eaton Fuller 18-Speed + 4-Speed Aux', 2002, 2009),
    eng('Cummins', 'ISX15 / X15', 14.9, '6-Cyl Turbo', 600, 'Diesel', 'Allison 4700 RDS / Eaton 18-Speed', 2005, 2024),
  ], ['6900', '6900TS'], SOURCE_VPIC_EPA_OEM),
  mdl('4700', 'Vocational Dump, Vacuum & Water Chassis', 'Transport & Hauling', TRK_HEAVY, 2012, 2022, [
    eng('Detroit Diesel', 'DD13', 12.8, '6-Cyl Turbo', 470, 'Diesel', 'Allison 4500 RDS / Eaton 8LL Manual', 2012, 2022),
    eng('Cummins', 'ISL9 / L9', 8.9, '6-Cyl Turbo', 380, 'Diesel', 'Allison 3000 / 3500 RDS Automatic', 2012, 2022),
  ], ['4700SB', '4700SF', '5700XE'], SOURCE_VPIC_EPA_OEM),
  mdl('47X', 'X-Series Vocational Truck', 'Transport & Hauling', TRK_HEAVY, 2022, 2026, [
    eng('Detroit Diesel', 'DD13 Gen 5', 12.8, '6-Cyl Turbo', 525, 'Diesel', 'Detroit DT12-V Vocational Automated / Eaton 18-Speed', 2022, 2026),
    eng('Cummins', 'L9 / X12', 11.8, '6-Cyl Turbo', 455, 'Diesel', 'Allison 4500 RDS 6-Speed Automatic', 2022, 2026),
  ], ['47X Chassis'], SOURCE_VPIC_EPA_OEM),
  mdl('49X', 'X-Series Severe-Duty Oilfield & Heavy-Haul Tractor', 'Transport & Hauling', TRK_HEAVY, 2021, 2026, [
    eng('Detroit Diesel', 'DD15 Gen 5 / DD16', 15.6, '6-Cyl Turbo', 600, 'Diesel', 'Detroit DT12-VX Automated / Eaton Fuller 18-Speed', 2021, 2026),
    eng('Cummins', 'X15 Performance Series', 14.9, '6-Cyl Turbo', 565, 'Diesel', 'Eaton Fuller RTLO-18918B 18-Speed Manual', 2021, 2026),
  ], ['49X Chassis'], SOURCE_VPIC_EPA_OEM),
  mdl('57X', 'X-Series Aerodynamic Highway Tractor', 'Transport & Hauling', TRK_HWY, 2023, 2026, [
    eng('Detroit Diesel', 'DD15 Gen 5', 14.8, '6-Cyl Turbo', 505, 'Diesel', 'Detroit DT12 On-Highway 12-Speed Automated', 2023, 2026),
    eng('Detroit Diesel', 'DD13 Gen 5', 12.8, '6-Cyl Turbo', 470, 'Diesel', 'Detroit DT12 12-Speed Automated', 2023, 2026),
  ], ['57X Chassis'], SOURCE_VPIC_EPA_OEM),
];

// ============================================================================
// 35. MACK (1970–2026) — Multi-Engine Highway & Vocational Trucks
// ============================================================================
const MACK_MODELS = [
  mdl('R Series', 'Legendary R-Model Conventional (R600 / R685 / R686)', 'Transport & Hauling', TRK_HEAVY, 1970, 2005, [
    eng('Mack', 'ENDT675 / EM6-237 Maxidyne', 11.0, '6-Cyl Turbo', 237, 'Diesel', 'Mack Maxitorque TRXL107 5/6-Speed Manual', 1970, 1990),
    eng('Mack', 'E6-300 / E6-350 Econodyne', 11.0, '6-Cyl Turbo', 350, 'Diesel', 'Mack T2090 / T2100 9/10-Speed Manual', 1978, 1995),
    eng('Mack', 'E7-350 / E7-400', 12.0, '6-Cyl Turbo', 400, 'Diesel', 'Mack T2180 18-Speed / Fuller 8LL', 1990, 2005),
  ], ['R600', 'R685ST', 'R686ST', 'RB690S'], SOURCE_VPIC_EPA_OEM),
  mdl('RD', 'Heavy-Duty Vocational & Winch R-Model (RD688S / RD800)', 'Transport & Hauling', TRK_HEAVY, 1979, 2004, [
    eng('Mack', 'E6-350', 11.0, '6-Cyl Turbo', 350, 'Diesel', 'Mack Maxitorque / Fuller 8LL Manual', 1979, 1991),
    eng('Mack', 'E7-350 / E7-427 / E7-460', 12.0, '6-Cyl Turbo', 427, 'Diesel', 'Mack T2180 18-Speed / Eaton 8LL Manual', 1990, 2004),
  ], ['RD688S', 'RD690S', 'RD800'], SOURCE_VPIC_EPA_OEM),
  mdl('DM', 'Offset-Cab Heavy Construction & Mixer Chassis (DM600 / DM800)', 'Transport & Hauling', TRK_HEAVY, 1970, 2005, [
    eng('Mack', 'ENDT676 / EM6-285', 11.0, '6-Cyl Turbo', 285, 'Diesel', 'Mack Maxitorque 6/7-Speed Manual', 1970, 1990),
    eng('Mack', 'E7-300 / E7-350', 12.0, '6-Cyl Turbo', 350, 'Diesel', 'Mack T2070 / Allison Automatic', 1990, 2005),
  ], ['DM600', 'DM685S', 'DM690S', 'DM800', 'DMM'], SOURCE_VPIC_EPA_OEM),
  mdl('Super-Liner RW', 'Long-Hood Heavy-Haul Conventional (RW613 / RW713)', 'Transport & Hauling', TRK_HEAVY, 1977, 1993, [
    eng('Mack', 'E9-440 / E9-500 V8', 16.4, 'V8 Turbo', 500, 'Diesel', 'Mack T2180 12/18-Speed Manual', 1979, 1993),
    eng('Mack', 'E6-350 / E7-400', 12.0, '6-Cyl Turbo', 400, 'Diesel', 'Fuller Roadranger 13/15-Speed Manual', 1977, 1993),
    eng('Cummins / Cat', 'NTC-400 / 3406B', 14.6, '6-Cyl Turbo', 425, 'Diesel', 'Fuller 15-Speed Manual', 1977, 1990),
  ], ['RW613', 'RW713', 'Super-Liner'], SOURCE_VPIC_EPA_OEM),
  mdl('CH / Vision', 'Fleet Highway Tractor (CH613 / CX613 / CXN613)', 'Transport & Hauling', TRK_HWY, 1989, 2007, [
    eng('Mack', 'E7-350 / E7-427 E-Tech', 12.0, '6-Cyl Turbo', 427, 'Diesel', 'Mack T2130 / Eaton Fuller 10/13-Speed', 1989, 2003),
    eng('Mack', 'ASET AC-427 / AC-460', 12.0, '6-Cyl Turbo', 460, 'Diesel', 'Eaton Fuller 10/13/18-Speed Manual', 2003, 2007),
  ], ['CH613', 'CHN613', 'CL713', 'CX613', 'CXN613', 'Vision'], SOURCE_VPIC_EPA_OEM),
  mdl('Granite', 'Flagship Vocational, Roll-Off, Vacuum & Water Truck', 'Transport & Hauling', TRK_HEAVY, 2001, 2026, [
    eng('Mack', 'E7 / ASET AI-400 / AMI-370', 12.0, '6-Cyl Turbo', 400, 'Diesel', 'Mack T309 / Eaton Fuller 8LL Manual', 2001, 2007),
    eng('Mack', 'MP7', 10.8, '6-Cyl Turbo', 425, 'Diesel', 'Mack mDRIVE HD 12/14-Speed / Allison 4500 RDS', 2007, 2026),
    eng('Mack', 'MP8', 12.8, '6-Cyl Turbo', 505, 'Diesel', 'Mack mDRIVE HD 13/14-Speed / Eaton 18-Speed', 2007, 2026),
  ], ['CV713', 'GU713', 'GU813', 'GR64F', 'GR64B'], SOURCE_VPIC_EPA_OEM),
  mdl('Pinnacle', 'Axle-Forward / Axle-Back Highway & Heavy-Spec Tractor', 'Transport & Hauling', TRK_HWY, 2006, 2026, [
    eng('Mack', 'ASET AC-427 / AC-460', 12.0, '6-Cyl Turbo', 460, 'Diesel', 'Eaton Fuller 10/13/18-Speed Manual', 2006, 2007),
    eng('Mack', 'MP8', 12.8, '6-Cyl Turbo', 505, 'Diesel', 'Mack mDRIVE 12-Speed Automated / Eaton 13/18-Speed', 2007, 2026),
    eng('Mack', 'MP7', 10.8, '6-Cyl Turbo', 425, 'Diesel', 'Mack mDRIVE 12-Speed Automated', 2007, 2026),
  ], ['CHU613', 'CXU613', 'PI64T'], SOURCE_VPIC_EPA_OEM),
  mdl('Titan', 'Severe-Duty Heavy-Haul & Oilfield Winch Tractor', 'Transport & Hauling', TRK_HEAVY, 2008, 2017, [
    eng('Mack', 'MP10', 16.1, '6-Cyl Turbo', 605, 'Diesel', 'Mack T318LR 18-Speed / mDRIVE HD / Eaton 18-Speed', 2008, 2017),
    eng('Mack', 'MP10 515 / 565', 16.1, '6-Cyl Turbo', 565, 'Diesel', 'Eaton Fuller RTLO-18918B 18-Speed Manual', 2008, 2017),
  ], ['TD713'], SOURCE_VPIC_EPA_OEM),
  mdl('Anthem', 'Aerodynamic Long-Haul & Regional Tractor', 'Transport & Hauling', TRK_HWY, 2018, 2026, [
    eng('Mack', 'MP8 / MP8HE', 12.8, '6-Cyl Turbo-Compound', 505, 'Diesel', 'Mack mDRIVE 12-Speed Overdrive Automated', 2018, 2026),
    eng('Mack', 'MP7', 10.8, '6-Cyl Turbo', 425, 'Diesel', 'Mack mDRIVE 12-Speed Automated', 2018, 2026),
  ], ['AN64T'], SOURCE_VPIC_EPA_OEM),
  mdl('MD7', 'Medium-Duty Tanker, Water & Roll-Off Chassis (MD6 / MD7)', 'Transport & Hauling', TRK_MED, 2020, 2026, [
    eng('Cummins', 'ISB6.7 / B6.7', 6.7, '6-Cyl Turbo', 300, 'Diesel', 'Allison 2500 / 3000 HS/RDS 6-Speed Automatic', 2020, 2026),
    eng('Cummins', 'B6.7 250', 6.7, '6-Cyl Turbo', 250, 'Diesel', 'Allison 2500 RDS Automatic', 2020, 2026),
  ], ['MD6', 'MD642', 'TerraPro'], SOURCE_VPIC_EPA_OEM),
];

// ============================================================================
// 36. FREIGHTLINER (1970–2026) — Multi-Engine Highway & Vocational Trucks
// ============================================================================
const FREIGHTLINER_MODELS = [
  mdl('FLA / FLB', 'Classic COE Cabover Highway Tractor', 'Transport & Hauling', TRK_HWY, 1970, 1998, [
    eng('Cummins', 'NTC-350 / NTC-400 / N14', 14.0, '6-Cyl Turbo', 400, 'Diesel', 'Fuller Roadranger 10/13-Speed Manual', 1970, 1998),
    eng('Detroit Diesel', '8V-71T / 8V-92TA / Series 60', 12.7, '6-Cyl Turbo', 430, 'Diesel', 'Fuller 10/13-Speed Manual', 1970, 1998),
    eng('Caterpillar', '3406A / 3406B / 3406E', 14.6, '6-Cyl Turbo', 425, 'Diesel', 'Fuller 13-Speed Manual', 1974, 1998),
  ], ['WFT', 'FLA86', 'FLB', 'Argosy'], SOURCE_VPIC_EPA_OEM),
  mdl('FLC120', 'First-Generation Conventional Tractor', 'Transport & Hauling', TRK_HEAVY, 1977, 1992, [
    eng('Cummins', 'NTC-350 / NTC-400 Big Cam', 14.0, '6-Cyl Turbo', 400, 'Diesel', 'Fuller 13-Speed Manual', 1977, 1992),
    eng('Caterpillar', '3406B', 14.6, '6-Cyl Turbo', 425, 'Diesel', 'Fuller 13/15-Speed Manual', 1978, 1992),
  ], ['FLC 12064T'], SOURCE_VPIC_EPA_OEM),
  mdl('FLD120', 'Aerodynamic Workhorse Conventional & Heavy-Spec', 'Transport & Hauling', TRK_HEAVY, 1988, 2010, [
    eng('Detroit Diesel', 'Series 60 12.7L', 12.7, '6-Cyl Turbo', 430, 'Diesel', 'Eaton Fuller 10/13-Speed Manual', 1988, 2007),
    eng('Cummins', 'N14 Celect Plus / ISX15', 14.0, '6-Cyl Turbo', 460, 'Diesel', 'Eaton Fuller 13-Speed Manual', 1990, 2010),
    eng('Caterpillar', '3406B / 3406E / C15', 14.6, '6-Cyl Turbo', 475, 'Diesel', 'Eaton Fuller 13/18-Speed Manual', 1988, 2009),
  ], ['FLD112', 'FLD120SD'], SOURCE_VPIC_EPA_OEM),
  mdl('Classic XL', 'Extended-Hood Owner-Operator Conventional (FLD132)', 'Transport & Hauling', TRK_HEAVY, 1990, 2010, [
    eng('Detroit Diesel', 'Series 60 12.7L / 14.0L', 14.0, '6-Cyl Turbo', 515, 'Diesel', 'Eaton Fuller 13/18-Speed Manual', 1990, 2010),
    eng('Caterpillar', '3406E / C15 ACERT', 15.2, '6-Cyl Twin-Turbo', 550, 'Diesel', 'Eaton Fuller 18-Speed Manual', 1994, 2009),
    eng('Cummins', 'N14 / ISX15', 14.9, '6-Cyl Turbo', 525, 'Diesel', 'Eaton Fuller 13/18-Speed Manual', 1991, 2010),
  ], ['FLD132', 'Classic'], SOURCE_VPIC_EPA_OEM),
  mdl('FL80', 'Business Class Medium/Heavy Service & Water Truck', 'Transport & Hauling', TRK_MED, 1991, 2005, [
    eng('Cummins', '6BT5.9 / 6CT8.3 / ISC', 8.3, '6-Cyl Turbo', 285, 'Diesel', 'Allison MD3060 Automatic / Fuller 8LL', 1991, 2005),
    eng('Caterpillar', '3116 / 3126B', 7.2, '6-Cyl Turbo', 275, 'Diesel', 'Eaton Fuller 6/9-Speed Manual', 1991, 2005),
  ], ['FL60', 'FL70', 'FL112'], SOURCE_VPIC_EPA_OEM),
  mdl('Century Class', 'C120 Aerodynamic Highway Tractor', 'Transport & Hauling', TRK_HWY, 1996, 2010, [
    eng('Detroit Diesel', 'Series 60 12.7L / 14.0L', 12.7, '6-Cyl Turbo', 455, 'Diesel', 'Eaton Fuller 10-Speed / SmartShift', 1996, 2010),
    eng('Caterpillar', 'C15', 14.6, '6-Cyl Turbo', 475, 'Diesel', 'Eaton Fuller 13-Speed Manual', 1999, 2008),
  ], ['CST120', 'C120'], SOURCE_VPIC_EPA_OEM),
  mdl('Columbia', 'Fleet Highway & Regional Tractor', 'Transport & Hauling', TRK_HWY, 2000, 2017, [
    eng('Detroit Diesel', 'Series 60 12.7L / 14.0L', 14.0, '6-Cyl Turbo', 515, 'Diesel', 'Eaton Fuller 10-Speed Manual / UltraShift', 2000, 2017),
    eng('Mercedes-Benz', 'MBE 4000', 12.8, '6-Cyl Turbo', 450, 'Diesel', 'Eaton Fuller 10-Speed Manual', 2002, 2009),
  ], ['CL120'], SOURCE_VPIC_EPA_OEM),
  mdl('Coronado', 'Long-Hood Chrome-Grille Highway & Heavy-Spec Tractor', 'Transport & Hauling', TRK_HEAVY, 2001, 2016, [
    eng('Detroit Diesel', 'Series 60 14.0L / DD15 / DD16', 14.8, '6-Cyl Turbo', 560, 'Diesel', 'Eaton Fuller 13/18-Speed Manual', 2001, 2016),
    eng('Caterpillar', 'C15 ACERT', 15.2, '6-Cyl Twin-Turbo', 550, 'Diesel', 'Eaton Fuller 18-Speed Manual', 2001, 2009),
    eng('Cummins', 'ISX15', 14.9, '6-Cyl Turbo', 550, 'Diesel', 'Eaton Fuller 18-Speed Manual', 2003, 2016),
  ], ['CC132', 'Coronado SD'], SOURCE_VPIC_EPA_OEM),
  mdl('M2 106', 'Business Class Medium-Duty Water, Fuel & Vacuum Chassis', 'Transport & Hauling', TRK_MED, 2003, 2026, [
    eng('Cummins', 'ISB6.7 / B6.7', 6.7, '6-Cyl Turbo', 300, 'Diesel', 'Allison 2500 / 3000 RDS 6-Speed Automatic', 2007, 2026),
    eng('Cummins', 'ISL9 / L9', 8.9, '6-Cyl Turbo', 350, 'Diesel', 'Allison 3000 RDS / Eaton 9-Speed', 2008, 2026),
    eng('Mercedes-Benz', 'MBE 900', 6.4, '6-Cyl Turbo', 260, 'Diesel', 'Allison 3000 RDS Automatic', 2003, 2009),
  ], ['M2 112', 'M2 106 Plus', 'eM2'], SOURCE_VPIC_EPA_OEM),
  mdl('Cascadia', 'Flagship Aerodynamic Highway Tractor', 'Transport & Hauling', TRK_HWY, 2008, 2026, [
    eng('Detroit Diesel', 'DD15 / DD15 Gen 5', 14.8, '6-Cyl Turbo', 505, 'Diesel', 'Detroit DT12 12-Speed Automated / Eaton 10-Speed', 2008, 2026),
    eng('Detroit Diesel', 'DD13 / DD13 Gen 5', 12.8, '6-Cyl Turbo', 470, 'Diesel', 'Detroit DT12 12-Speed Automated', 2009, 2026),
    eng('Cummins', 'ISX15 / X15 Efficiency', 14.9, '6-Cyl Turbo', 500, 'Diesel', 'Eaton Endurant 12-Speed / Fuller 13-Speed', 2008, 2026),
  ], ['Cascadia Evolution', 'eCascadia'], SOURCE_VPIC_EPA_OEM),
  mdl('114SD', 'Severe-Duty Vocational, Vacuum, Roll-Off & Water Truck', 'Transport & Hauling', TRK_HEAVY, 2012, 2026, [
    eng('Detroit Diesel', 'DD13 / DD13 Gen 5', 12.8, '6-Cyl Turbo', 505, 'Diesel', 'Allison 4500 RDS / Eaton Fuller 8LL / DT12-V', 2012, 2026),
    eng('Cummins', 'ISL9 / L9 / X12', 11.8, '6-Cyl Turbo', 455, 'Diesel', 'Allison 3000 / 4500 RDS Automatic', 2012, 2026),
  ], ['108SD', '114SD Plus'], SOURCE_VPIC_EPA_OEM),
  mdl('122SD', 'Severe-Duty Oilfield Winch & Heavy-Haul Tractor', 'Transport & Hauling', TRK_HEAVY, 2013, 2024, [
    eng('Detroit Diesel', 'DD15 / DD16', 15.6, '6-Cyl Turbo', 600, 'Diesel', 'Eaton Fuller RTLO-18918B 18-Speed Manual', 2013, 2024),
    eng('Cummins', 'ISX15 / X15 Performance', 14.9, '6-Cyl Turbo', 565, 'Diesel', 'Eaton Fuller 18-Speed / Allison 4700 RDS', 2013, 2024),
  ], ['SD122'], SOURCE_VPIC_EPA_OEM),
];

// ============================================================================
// 37. INTERNATIONAL (1970–2026) — Multi-Engine Highway & Vocational Trucks
// ============================================================================
const INTERNATIONAL_MODELS = [
  mdl('Paystar 5000', 'Classic Oilfield & Construction Heavy Chassis', 'Transport & Hauling', TRK_HEAVY, 1972, 1999, [
    eng('Cummins', 'NTC-350 / N14', 14.0, '6-Cyl Turbo', 400, 'Diesel', 'Fuller Roadranger 8LL / 13/15-Speed Manual', 1972, 1999),
    eng('International', 'DT466 / HT530', 8.7, '6-Cyl Turbo', 300, 'Diesel', 'Allison Automatic / Fuller 8LL', 1976, 1999),
    eng('Caterpillar', '3406B / C12', 14.6, '6-Cyl Turbo', 425, 'Diesel', 'Fuller 15/18-Speed Manual', 1978, 1999),
  ], ['5070', 'Transtar 4300', 'CO4070B'], SOURCE_VPIC_EPA_OEM),
  mdl('4900', '4000-Series Medium-Duty Service, Fuel & Water Truck', 'Transport & Hauling', TRK_MED, 1989, 2002, [
    eng('International', 'DT466 / DT466E', 7.6, '6-Cyl Turbo', 250, 'Diesel', 'Allison MD3060 / Spicer 6+1 Manual', 1989, 2002),
    eng('International', 'DT530E', 8.7, '6-Cyl Turbo', 300, 'Diesel', 'Eaton Fuller 8LL / 10-Speed Manual', 1994, 2002),
  ], ['4700', 'S-Series 1954', '2574'], SOURCE_VPIC_EPA_OEM),
  mdl('9900i', 'Eagle Classic Long-Hood Highway & Heavy-Spec Tractor', 'Transport & Hauling', TRK_HEAVY, 1989, 2017, [
    eng('Cummins', 'N14 Celect Plus / ISX15', 14.9, '6-Cyl Turbo', 550, 'Diesel', 'Eaton Fuller 13/18-Speed Manual', 1989, 2017),
    eng('Caterpillar', '3406E / C15 ACERT', 15.2, '6-Cyl Twin-Turbo', 550, 'Diesel', 'Eaton Fuller 18-Speed Manual', 1994, 2009),
  ], ['9300', '9400i', '9900ix'], SOURCE_VPIC_EPA_OEM),
  mdl('7600 WorkStar', 'WorkStar Heavy Vocational, Vacuum & Water Truck', 'Transport & Hauling', TRK_HEAVY, 2002, 2017, [
    eng('Cummins', 'ISM / ISL9', 10.8, '6-Cyl Turbo', 410, 'Diesel', 'Eaton Fuller 8LL / Allison 4500 RDS', 2002, 2017),
    eng('Caterpillar', 'C11 / C13 ACERT', 12.5, '6-Cyl Turbo', 430, 'Diesel', 'Eaton Fuller 10/18-Speed Manual', 2003, 2009),
    eng('International', 'DT466 / MaxxForce 13 / N13', 12.4, '6-Cyl Turbo', 430, 'Diesel', 'Allison 3000 / 4500 RDS Automatic', 2008, 2017),
  ], ['7400 WorkStar', '7500 WorkStar', 'PayStar 5900i'], SOURCE_VPIC_EPA_OEM),
  mdl('ProStar', 'Aerodynamic Long-Haul Highway Tractor', 'Transport & Hauling', TRK_HWY, 2007, 2017, [
    eng('Cummins', 'ISX15', 14.9, '6-Cyl Turbo', 485, 'Diesel', 'Eaton Fuller 10-Speed / UltraShift PLUS', 2007, 2017),
    eng('International', 'MaxxForce 13 / N13', 12.4, '6-Cyl Turbo', 450, 'Diesel', 'Eaton Fuller 10-Speed Manual', 2010, 2017),
  ], ['Lonestar', '8600 TranStar'], SOURCE_VPIC_EPA_OEM),
  mdl('HX620', 'HX Severe-Duty Oilfield Winch & Heavy-Haul Tractor', 'Transport & Hauling', TRK_HEAVY, 2017, 2026, [
    eng('Cummins', 'X15 Performance / Vocational', 14.9, '6-Cyl Turbo', 565, 'Diesel', 'Eaton Fuller RTLO-18918B 18-Speed Manual', 2017, 2026),
    eng('International', 'A26 / S13 Integrated', 12.7, '6-Cyl Turbo', 515, 'Diesel', 'Allison 4500 RDS / T14 Automated', 2017, 2026),
  ], ['HX520', 'HX515', 'HX615'], SOURCE_VPIC_EPA_OEM),
  mdl('LT', 'LT Series Aerodynamic Highway Tractor', 'Transport & Hauling', TRK_HWY, 2017, 2026, [
    eng('Cummins', 'X15 Efficiency Series', 14.9, '6-Cyl Turbo', 500, 'Diesel', 'Eaton Endurant 12-Speed Automated', 2017, 2026),
    eng('International', 'A26', 12.4, '6-Cyl Turbo', 475, 'Diesel', 'Eaton Endurant 12-Speed Automated', 2017, 2024),
    eng('International', 'S13 Integrated Powertrain', 12.7, '6-Cyl Turbo', 515, 'Diesel', 'International T14 14-Speed Automated', 2024, 2026),
  ], ['LT625', 'RH'], SOURCE_VPIC_EPA_OEM),
  mdl('HV607', 'HV Vocational Vacuum, Water & Roll-Off Chassis', 'Transport & Hauling', TRK_MED, 2018, 2026, [
    eng('Cummins', 'B6.7 / L9', 8.9, '6-Cyl Turbo', 380, 'Diesel', 'Allison 3000 / 3500 RDS 6-Speed Automatic', 2018, 2026),
    eng('International', 'A26', 12.4, '6-Cyl Turbo', 475, 'Diesel', 'Allison 4500 RDS / Eaton 8LL Manual', 2018, 2026),
  ], ['HV507', 'HV613', 'MV607', '4300 DuraStar'], SOURCE_VPIC_EPA_OEM),
];

// ============================================================================
// 38. VOLVO TRUCKS (1981–2026) — Multi-Engine Highway & Vocational Trucks
// ============================================================================
const VOLVO_TRUCKS_MODELS = [
  mdl('WIA', 'WhiteGMC / Volvo Aero & WG Conventional', 'Transport & Hauling', TRK_HWY, 1988, 2001, [
    eng('Detroit Diesel', 'Series 60 12.7L', 12.7, '6-Cyl Turbo', 430, 'Diesel', 'Eaton Fuller 10/13-Speed Manual', 1988, 2001),
    eng('Cummins', 'N14 Celect', 14.0, '6-Cyl Turbo', 435, 'Diesel', 'Eaton Fuller 10/13-Speed Manual', 1990, 2001),
    eng('Volvo', 'VE D12', 12.1, '6-Cyl Turbo', 425, 'Diesel', 'Eaton Fuller 10-Speed Manual', 1994, 2001),
  ], ['WG', 'WCA', 'AUTOCAR ACL'], SOURCE_VPIC_EPA_OEM),
  mdl('VNL', 'Flagship Long-Haul Highway Tractor (VNL 670 / 760 / 860)', 'Transport & Hauling', TRK_HWY, 1996, 2026, [
    eng('Volvo', 'D12 / D13 / D13TC Turbo-Compound', 12.8, '6-Cyl Turbo', 500, 'Diesel', 'Volvo I-Shift 12-Speed Automated', 1996, 2026),
    eng('Cummins', 'N14 / ISX15 / X15', 14.9, '6-Cyl Turbo', 500, 'Diesel', 'Eaton Fuller 13-Speed / Endurant Automated', 1996, 2026),
    eng('Detroit Diesel', 'Series 60 12.7L', 12.7, '6-Cyl Turbo', 430, 'Diesel', 'Eaton Fuller 10-Speed Manual', 1996, 2003),
  ], ['VNL64T', 'VNL 670', 'VNL 760', 'VNL 860', 'VNM', 'VT 880'], SOURCE_VPIC_EPA_OEM),
  mdl('VNR', 'Regional Haul & Tanker Tractor', 'Transport & Hauling', TRK_HWY, 2018, 2026, [
    eng('Volvo', 'D11', 10.8, '6-Cyl Turbo', 425, 'Diesel', 'Volvo I-Shift 12-Speed Automated', 2018, 2026),
    eng('Volvo', 'D13', 12.8, '6-Cyl Turbo', 455, 'Diesel', 'Volvo I-Shift 12-Speed Automated', 2018, 2026),
  ], ['VNR 300', 'VNR 640', 'VNR Electric'], SOURCE_VPIC_EPA_OEM),
  mdl('VHD', 'Severe-Duty Vocational, Roll-Off, Vacuum & Water Truck', 'Transport & Hauling', TRK_HEAVY, 2001, 2026, [
    eng('Volvo', 'D12 / D13', 12.8, '6-Cyl Turbo', 475, 'Diesel', 'Volvo I-Shift Severe Duty 13/14-Speed Crawler', 2001, 2026),
    eng('Volvo', 'D11', 10.8, '6-Cyl Turbo', 425, 'Diesel', 'Allison 4500 RDS 6-Speed Automatic', 2008, 2026),
  ], ['VHD64B', 'VHD64F'], SOURCE_VPIC_EPA_OEM),
  mdl('VNX', 'Heavy-Haul & Oilfield Tractor', 'Transport & Hauling', TRK_HEAVY, 2014, 2024, [
    eng('Volvo', 'D16', 16.1, '6-Cyl Turbo', 600, 'Diesel', 'Volvo I-Shift Severe Duty Automated', 2014, 2017),
    eng('Cummins', 'X15 Performance Series', 14.9, '6-Cyl Turbo', 605, 'Diesel', 'Eaton Fuller RTLO-18918B 18-Speed Manual', 2018, 2024),
    eng('Volvo', 'D13', 12.8, '6-Cyl Turbo', 500, 'Diesel', 'Volvo I-Shift 13/14-Speed Crawler', 2018, 2024),
  ], ['VNX 300', 'VNX 740'], SOURCE_VPIC_EPA_OEM),
];

// ============================================================================
// 39. FORD (1970–2026) — Multi-Engine Commercial & Oilfield Service Trucks
// ============================================================================
const FORD_MODELS = [
  mdl('L9000 Louisville', 'Louisville Heavy Vocational & Highway Line (L8000 / LT9000)', 'Transport & Hauling', TRK_HEAVY, 1970, 1998, [
    eng('Cummins', 'NTC-350 / L10 / M11 / N14', 14.0, '6-Cyl Turbo', 400, 'Diesel', 'Fuller Roadranger 8LL / 10/13-Speed Manual', 1970, 1998),
    eng('Caterpillar', '3208 / 3306 / 3406B', 14.6, '6-Cyl Turbo', 425, 'Diesel', 'Fuller 9/13-Speed Manual', 1972, 1998),
    eng('Ford', '7.8L Brazilian / Detroit 8V-71', 7.8, '6-Cyl Turbo', 240, 'Diesel', 'Allison MT653 / Spicer Manual', 1970, 1993),
  ], ['L8000', 'L9000', 'LT9000', 'LTL9000', 'Aeromax 9000'], SOURCE_VPIC_EPA_OEM),
  mdl('F-800', 'Classic Medium-Duty Service & Water Chassis (F-700 / F-800)', 'Transport & Hauling', TRK_MED, 1970, 1999, [
    eng('Ford', '361 / 391 FT Heavy-Duty V8', 6.4, 'V8', 210, 'Gasoline', 'Clark 5-Speed + 2-Speed Rear Axle', 1970, 1978),
    eng('Caterpillar', '3208', 10.4, 'V8', 210, 'Diesel', '5+2 Manual / Allison Automatic', 1975, 1991),
    eng('Ford', '370 / 429 Lima V8', 7.0, 'V8', 235, 'Gasoline', '5-Speed Manual / Allison Automatic', 1979, 1998),
    eng('Ford / Cummins', '5.9L 6BT / 8.3L 6CT', 5.9, '6-Cyl Turbo', 210, 'Diesel', 'Allison AT545 / Eaton 6-Speed Manual', 1992, 1999),
  ], ['F-700', 'F7000', 'F8000'], SOURCE_VPIC_EPA_OEM),
  mdl('F-350 Super Duty', '1-Ton Welding Rig & Hotshot Chassis', 'Transport & Hauling', TRK_MED, 1999, 2026, [
    eng('Ford / International', '7.3L Power Stroke V8', 7.3, 'V8 Turbo', 250, 'Diesel', '4R100 Automatic / ZF 6-Speed Manual', 1999, 2003),
    eng('Ford', '6.0L / 6.4L Power Stroke V8', 6.4, 'V8 Twin-Turbo', 350, 'Diesel', 'TorqShift 5-Speed Automatic', 2003, 2010),
    eng('Ford', '6.7L Power Stroke V8', 6.7, 'V8 Turbo', 475, 'Diesel', 'TorqShift 6/10-Speed Heavy-Duty Automatic', 2011, 2026),
    eng('Ford', '6.8L Triton V10 / 7.3L Godzilla V8', 7.3, 'V8', 430, 'Gasoline', 'TorqShift 10-Speed Automatic', 1999, 2026),
  ], ['F-250 Super Duty', 'F-350'], SOURCE_VPIC_EPA_OEM),
  mdl('F-550 Super Duty', 'Mechanics Crane, Welding & Field Service Chassis (F-450 / F-550)', 'Transport & Hauling', TRK_MED, 1999, 2026, [
    eng('Ford / International', '7.3L Power Stroke V8', 7.3, 'V8 Turbo', 250, 'Diesel', '4R100 Automatic / ZF 6-Speed Manual', 1999, 2003),
    eng('Ford', '6.0L / 6.4L Power Stroke V8', 6.4, 'V8 Twin-Turbo', 325, 'Diesel', 'TorqShift 5-Speed Automatic', 2003, 2010),
    eng('Ford', '6.7L Power Stroke V8', 6.7, 'V8 Turbo', 330, 'Diesel', 'TorqShift 6/10-Speed Automatic', 2011, 2026),
    eng('Ford', '6.8L V10 / 7.3L V8 Gas', 7.3, 'V8', 335, 'Gasoline', 'TorqShift 10-Speed Automatic', 1999, 2026),
  ], ['F-450 Super Duty', 'F-550', 'F-600 Super Duty'], SOURCE_VPIC_EPA_OEM),
  mdl('F-750', 'Medium-Duty Water, Fuel, Lube & Roll-Off Chassis (F-650 / F-750)', 'Transport & Hauling', TRK_MED, 2000, 2026, [
    eng('Cummins', '5.9L ISB / 6.7L ISB', 6.7, '6-Cyl Turbo', 325, 'Diesel', 'Allison 2500 / 3000 RDS Automatic', 2000, 2015),
    eng('Caterpillar', '3126B / C7 ACERT', 7.2, '6-Cyl Turbo', 300, 'Diesel', 'Allison 3000 RDS / Eaton 6-Speed', 2000, 2009),
    eng('Ford', '6.7L Power Stroke V8', 6.7, 'V8 Turbo', 330, 'Diesel', 'Ford TorqShift HD 6/10-Speed Automatic', 2016, 2026),
    eng('Ford', '7.3L V8 Commercial Gas', 7.3, 'V8', 335, 'Gasoline', 'Ford TorqShift HD 6-Speed Automatic', 2021, 2026),
  ], ['F-650', 'F-650/F-750'], SOURCE_VPIC_EPA_OEM),
];

// ============================================================================
// 40. SULLAIR (1970–2026) — Multi-Engine Portable Air Compressors
// ============================================================================
const SULLAIR_MODELS = [
  mdl('185', 'Classic Portable Rotary-Screw Air Compressors', 'Site Support', ['Air Compressor'], 1972, 2008, [
    eng('John Deere', '4239D / 4039D / 4024TF', 2.4, '4-Cyl Turbo', 49, 'Diesel', 'Direct Rotary-Screw Airend', 1975, 2008),
    eng('Perkins', '4.203 / 1004-4', 3.9, '4-Cyl', 58, 'Diesel', 'Direct Rotary-Screw Airend', 1972, 2002),
    eng('Caterpillar', '3024C', 2.2, '4-Cyl', 49, 'Diesel', 'Direct Rotary-Screw Airend', 2003, 2008),
  ], ['160', '185DPQ'], SOURCE_EPA_OEM),
  mdl('185 Series', 'Tier 4 Towable Utility Air Compressors', 'Site Support', ['Air Compressor'], 2008, 2026, [
    eng('Kubota', 'V2403-CR-E4B Tier 4F', 2.4, '4-Cyl', 49, 'Diesel', 'Direct Drive 14-Series Airend', 2013, 2026),
    eng('Caterpillar', 'C2.2', 2.2, '4-Cyl', 49, 'Diesel', 'Direct Drive Rotary-Screw Airend', 2008, 2020),
    eng('Perkins', '404F-E22T', 2.2, '4-Cyl Turbo', 49, 'Diesel', 'Direct Drive Airend', 2014, 2026),
  ], ['185 Tier 4F', '210H', '260'], SOURCE_EPA_OEM),
  mdl('375', 'Classic Mid-Range Portable Air Compressors', 'Site Support', ['Air Compressor'], 1976, 2008, [
    eng('Detroit Diesel', '4-53N', 3.5, '4-Cyl 2-Stroke', 120, 'Diesel', 'Direct Rotary-Screw Airend', 1976, 1994),
    eng('John Deere', '4045TF / 6068TF', 4.5, '4-Cyl Turbo', 115, 'Diesel', 'Direct Rotary-Screw Airend', 1990, 2008),
    eng('Caterpillar', '3054C / C4.4', 4.4, '4-Cyl Turbo', 125, 'Diesel', 'Direct Rotary-Screw Airend', 1998, 2008),
  ], ['375H'], SOURCE_EPA_OEM),
  mdl('375 Series', 'Mid-Range Pipeline & Sandblast Air Compressors', 'Site Support', ['Air Compressor'], 2008, 2026, [
    eng('John Deere', '4045HFC04 Tier 4F', 4.5, '4-Cyl Turbo', 125, 'Diesel', 'Direct Rotary-Screw Airend', 2008, 2026),
    eng('Caterpillar', 'C4.4 ACERT', 4.4, '4-Cyl Turbo', 122, 'Diesel', 'Direct Rotary-Screw Airend', 2008, 2026),
    eng('Perkins', '1204E / 1204F-E44TA', 4.4, '4-Cyl Turbo', 122, 'Diesel', 'Direct Rotary-Screw Airend', 2013, 2026),
  ], ['375H Tier 4F', '400HH', '425H'], SOURCE_EPA_OEM),
  mdl('750H', 'Heavy Pipeline Testing & Drilling Air Compressors', 'Site Support', ['Air Compressor'], 1980, 2026, [
    eng('Caterpillar', '3306T / C9 ACERT', 8.8, '6-Cyl Turbo', 275, 'Diesel', 'Direct Rotary-Screw Airend', 1980, 2026),
    eng('Cummins', 'L10 / QSL9', 8.9, '6-Cyl Turbo', 290, 'Diesel', 'Direct Rotary-Screw Airend', 1988, 2026),
  ], ['750', '825'], SOURCE_EPA_OEM),
  mdl('900H', 'High-Pressure Pipeline & Drilling Air Compressors', 'Site Support', ['Air Compressor'], 1985, 2026, [
    eng('Caterpillar', '3406C / C9 / C13 / C15 ACERT', 12.5, '6-Cyl Turbo', 385, 'Diesel', 'Two-Stage Rotary-Screw Airend', 1985, 2026),
    eng('Cummins', 'NTA-855 / QSL9 / QSX15', 8.9, '6-Cyl Turbo', 365, 'Diesel', 'Two-Stage Rotary-Screw Airend', 1985, 2026),
  ], ['900XHH', '1150XH'], SOURCE_EPA_OEM),
  mdl('1600H', 'Large Volume Pipeline Pigging & Drilling Air Compressors', 'Site Support', ['Air Compressor'], 1988, 2026, [
    eng('Caterpillar', '3412 / C15 / C18 ACERT', 18.1, '6-Cyl Turbo', 575, 'Diesel', 'Heavy Rotary-Screw Airend', 1988, 2026),
    eng('Cummins', 'QSX15 / X15', 14.9, '6-Cyl Turbo', 560, 'Diesel', 'Heavy Rotary-Screw Airend', 2002, 2026),
  ], ['1600'], SOURCE_EPA_OEM),
];

// ============================================================================
// 41. ATLAS COPCO (1972–2026) — Multi-Engine Compressors, Generators & Towers
// ============================================================================
const ATLAS_COPCO_MODELS = [
  mdl('XAS 185', 'Towable Utility Rotary-Screw Air Compressors', 'Site Support', ['Air Compressor'], 1985, 2026, [
    eng('Deutz', 'F3L912 / BF4M2011', 3.1, '4-Cyl', 49, 'Diesel', 'Oil-Injected Screw Element', 1985, 2012),
    eng('John Deere', '4024TF270', 2.4, '4-Cyl Turbo', 49, 'Diesel', 'Oil-Injected Screw Element', 2004, 2016),
    eng('Kubota', 'V2403-CR-T Tier 4F', 2.4, '4-Cyl Turbo', 49, 'Diesel', 'PACE Screw Element', 2014, 2026),
  ], ['XA 175', 'XAS 90', 'XAS 97', 'XAS 110'], SOURCE_EPA_OEM),
  mdl('XAS 188', 'HardHat Canopy PACE Portable Air Compressors', 'Site Support', ['Air Compressor'], 2016, 2026, [
    eng('Kubota', 'V2403-CR-E4B Tier 4F', 2.4, '4-Cyl', 49, 'Diesel', 'C90 Screw Element', 2016, 2026),
    eng('John Deere', '4045TF / Kubota D1803', 1.8, '3-Cyl Turbo', 49, 'Diesel', 'C90 Screw Element', 2018, 2026),
  ], ['XAS 188 KD'], SOURCE_EPA_OEM),
  mdl('XAS 400', 'Mid-Size Pipeline & Construction Air Compressors', 'Site Support', ['Air Compressor'], 2004, 2026, [
    eng('John Deere', '4045HF285 / 4045HFC04', 4.5, '4-Cyl Turbo', 115, 'Diesel', 'Atlas Copco Screw Element', 2004, 2026),
    eng('Caterpillar', 'C4.4 ACERT', 4.4, '4-Cyl Turbo', 130, 'Diesel', 'Atlas Copco Screw Element', 2008, 2026),
  ], ['XAS 375', 'XATS 400'], SOURCE_EPA_OEM),
  mdl('XRVS 1000', 'High-Pressure Drilling & Pipeline Air Compressors', 'Site Support', ['Air Compressor'], 2000, 2026, [
    eng('Caterpillar', 'C13 / C15 / C18 ACERT', 15.2, '6-Cyl Turbo', 575, 'Diesel', 'Two-Stage High-Pressure Screw', 2000, 2026),
    eng('Cummins', 'QSX15', 14.9, '6-Cyl Turbo', 560, 'Diesel', 'Two-Stage High-Pressure Screw', 2008, 2026),
  ], ['XAMS 850', 'XRHS 666', 'XRV 1200'], SOURCE_EPA_OEM),
  mdl('QAS 45', 'Prime-Power Sound-Attenuated Mobile Generators', 'Site Support', ['Generator'], 2006, 2026, [
    eng('Kubota', 'V3307 / V3800-DI-T', 3.8, '4-Cyl Turbo', 66, 'Diesel', '1800 RPM AREP Brushless Alternator', 2006, 2026),
    eng('John Deere', '4045TF', 4.5, '4-Cyl Turbo', 68, 'Diesel', '1800 RPM Brushless Alternator', 2006, 2018),
  ], ['QAS 25', 'QAS 60'], SOURCE_EPA_OEM),
  mdl('QAS 150', 'Heavy Jobsite & Camp Prime-Power Generators', 'Site Support', ['Generator'], 2006, 2026, [
    eng('John Deere', '6068HFG08 Tier 4F', 6.8, '6-Cyl Turbo', 224, 'Diesel', '1800 RPM Mecc Alte Brushless Alternator', 2006, 2026),
    eng('Volvo Penta', 'TAD731GE / TAD751GE', 7.2, '6-Cyl Turbo', 228, 'Diesel', '1800 RPM Synchronous Alternator', 2008, 2026),
  ], ['QAS 80', 'QAS 125', 'QAS 250'], SOURCE_EPA_OEM),
  mdl('HiLight V4', 'Towable Metal-Halide & LED Light Towers', 'Site Support', ['Light Tower'], 2012, 2026, se('Kubota', 'Z482 / D902', 0.9, '2/3-Cyl', 11, 'Diesel', '6kW Integrated Alternator'), ['Qlt M10'], SOURCE_EPA_OEM),
  mdl('HiLight V5+', 'HardHat Extended-Runtime LED Light Towers', 'Site Support', ['Light Tower'], 2016, 2026, se('Kubota', 'Z482 Tier 4F', 0.5, '2-Cyl', 11, 'Diesel', '2.7kW High-Efficiency LED Generator'), ['HiLight B5+', 'HiLight H5+'], SOURCE_EPA_OEM),
];

// ============================================================================
// 42. LINCOLN ELECTRIC (1970–2026) — Multi-Engine Pipeline & Field Welders
// ============================================================================
const LINCOLN_ELECTRIC_MODELS = [
  mdl('SA-200', 'Legendary Pipeliner Red-Face / Black-Face DC Welders', 'Site Support', ['Welding Machine'], 1970, 1995, [
    eng('Continental', 'F-162 / F-163', 2.7, '4-Cyl Water-Cooled', 37, 'Gasoline', '1500 RPM Pure DC Generator', 1970, 1995),
    eng('Perkins', '4.108', 1.8, '4-Cyl', 32, 'Diesel', '1500 RPM DC Exciter Generator', 1976, 1992),
  ], ['SA-200 Red Face', 'SA-200 Black Face'], SOURCE_EPA_OEM),
  mdl('SA-250', 'Heavy-Duty Pipeline DC Engine-Driven Welders', 'Site Support', ['Welding Machine'], 1972, 1998, [
    eng('Continental', 'TMD27 / F-163', 2.7, '4-Cyl', 44, 'Diesel', '1800 RPM DC Generator', 1972, 1998),
    eng('Perkins', 'D3.152 / 4.154', 2.5, '3/4-Cyl', 45, 'Diesel', '1800 RPM DC Generator', 1975, 1998),
  ], ['SAE-300', 'SAE-400'], SOURCE_EPA_OEM),
  mdl('Classic 300D', 'Pipeline Pure-DC Diesel Welders', 'Site Support', ['Welding Machine'], 1995, 2026, [
    eng('Perkins', '104-22 / 404D-22', 2.2, '4-Cyl', 38, 'Diesel', '1800 RPM Pure DC Wound-Field Generator', 1995, 2015),
    eng('Kubota', 'V1505 / D1803-CR', 1.8, '3/4-Cyl', 37, 'Diesel', '1800 RPM Pure DC Generator', 2006, 2026),
  ], ['Classic II', 'Classic 300 MP', 'Classic 300 HE'], SOURCE_EPA_OEM),
  mdl('Pipeliner 200D', 'Pure-DC Mainline Pipeline Welders', 'Site Support', ['Welding Machine'], 2004, 2026, [
    eng('Kubota', 'V1505 / D1703M', 1.5, '4-Cyl', 34, 'Diesel', '1650 RPM Pure DC Exciter Generator', 2004, 2026),
    eng('Kubota', 'V1305', 1.3, '4-Cyl', 29, 'Diesel', '1650 RPM Pure DC Generator', 2004, 2014),
  ], ['SA-400I'], SOURCE_EPA_OEM),
  mdl('Ranger 225', 'Field Service Gasoline Engine-Driven Welders', 'Site Support', ['Welding Machine'], 2002, 2026, [
    eng('Kohler', 'Command Pro CH23 / CH730', 0.7, 'V-Twin OHV', 23, 'Gasoline', '3600 RPM AC/DC Welder/Generator', 2002, 2026),
    eng('Onan', 'Performer P220G', 0.8, 'V-Twin', 20, 'Gasoline', '3600 RPM Welder/Generator', 2002, 2008),
  ], ['Ranger 8', 'Ranger 9'], SOURCE_EPA_OEM),
  mdl('Ranger 250', 'Multi-Process Service Truck Welders', 'Site Support', ['Welding Machine'], 1998, 2022, [
    eng('Kohler', 'Command Pro CH20 / CH730', 0.7, 'V-Twin OHV', 23, 'Gasoline', '3600 RPM Chopper-Tech Generator', 1998, 2022),
    eng('Onan', 'Performer OHV', 0.7, 'V-Twin', 20, 'Gasoline', '3600 RPM Generator', 1998, 2007),
    eng('Kohler', 'Command Pro LP', 0.7, 'V-Twin LPG', 22, 'Dual Fuel (Gas/LPG)', '3600 RPM Generator', 2002, 2022),
  ], ['Ranger 250 GXT', 'Ranger 260MPX'], SOURCE_EPA_OEM),
  mdl('Ranger 305G', 'Multi-Process Gasoline / Diesel Welders (305G / 305D)', 'Site Support', ['Welding Machine'], 2003, 2026, [
    eng('Kohler', 'Command Pro CH730 / ECH740 EFI', 0.7, 'V-Twin EFI', 25, 'Gasoline', '3600 RPM Chopper-Tech Generator', 2003, 2026),
    eng('Kubota', 'D722', 0.7, '3-Cyl Water-Cooled', 19, 'Diesel', '3600 RPM Chopper-Tech Generator', 2004, 2026),
  ], ['Ranger 305D', 'Ranger 305G EFI', 'Ranger 330MPX'], SOURCE_EPA_OEM),
  mdl('Vantage 300', 'Compact Diesel Multi-Process Pipeline/Field Welders', 'Site Support', ['Welding Machine'], 2003, 2020, [
    eng('Kubota', 'V1505', 1.5, '4-Cyl', 22, 'Diesel', '1800 RPM Chopper-Tech Generator', 2003, 2020),
    eng('Deutz', 'D2011L03', 2.3, '3-Cyl Oil-Cooled', 32, 'Diesel', '1800 RPM Generator', 2005, 2015),
  ], [], SOURCE_EPA_OEM),
  mdl('Vantage 322', 'Tier 4 Final Diesel Multi-Process Welders', 'Site Support', ['Welding Machine'], 2015, 2026, [
    eng('Kubota', 'D1105 / V1505', 1.5, '4-Cyl', 24, 'Diesel', '1800 RPM 3-Phase Aux + Welder', 2015, 2026),
    eng('Kubota', 'V1505 Cold-Weather Package', 1.5, '4-Cyl', 25, 'Diesel', '1800 RPM Stainless Enclosure Generator', 2016, 2026),
  ], ['Vantage 300X'], SOURCE_EPA_OEM),
  mdl('Vantage 400', 'Heavy Industrial & Gouging Diesel Welders (400 / 500)', 'Site Support', ['Welding Machine'], 2004, 2026, [
    eng('Perkins', '404D-22 / 404F-22', 2.2, '4-Cyl', 33, 'Diesel', '1800 RPM Chopper-Tech Generator', 2004, 2026),
    eng('Kubota', 'V2403-M / V1505-T', 2.4, '4-Cyl', 36, 'Diesel', '1800 RPM Chopper-Tech Generator', 2008, 2026),
    eng('Deutz', 'D2.9 L4', 2.9, '4-Cyl', 48, 'Diesel', '1800 RPM Heavy Gouging Generator', 2014, 2026),
  ], ['Vantage 410', 'Vantage 441X', 'Vantage 500', 'Vantage 549X'], SOURCE_EPA_OEM),
  mdl('Air Vantage 600', 'Integrated Screw-Compressor & Gouging Diesel Welders', 'Site Support', ['Welding Machine'], 2006, 2026, [
    eng('Cummins', 'B3.3 / QSF2.8', 2.8, '4-Cyl Turbo', 65, 'Diesel', '1800 RPM Welder + VMAC Rotary Air Compressor', 2006, 2026),
    eng('Deutz', 'TD2.9 L4 Tier 4F', 2.9, '4-Cyl Turbo', 65, 'Diesel', '1800 RPM Welder + Integrated Rotary Air Compressor', 2015, 2026),
  ], ['Air Vantage 500', 'Air Vantage 566X', 'Air Vantage 600 SD'], SOURCE_EPA_OEM),
];

// ============================================================================
// 43. MILLER (1972–2026) — Multi-Engine Field & Pipeline Welders
// ============================================================================
const MILLER_MODELS = [
  mdl('Big 40', 'Classic Heavy-Duty Field Welders', 'Site Support', ['Welding Machine'], 1972, 1998, [
    eng('Continental', 'F-162 / F-163', 2.7, '4-Cyl Water-Cooled', 39, 'Gasoline', '1800 RPM Revolving-Field Generator', 1972, 1996),
    eng('Continental / Teledyne', 'TMD27', 2.7, '4-Cyl', 44, 'Diesel', '1800 RPM Generator', 1978, 1998),
    eng('Deutz', 'F3L912', 2.8, '3-Cyl Air-Cooled', 42, 'Diesel', '1800 RPM Generator', 1982, 1998),
  ], ['Big 20', 'Big 40G', 'Big 40D', 'AEAD-200LE'], SOURCE_EPA_OEM),
  mdl('Bobcat 225', 'Service Truck Welder/Generators', 'Site Support', ['Welding Machine'], 1987, 2020, [
    eng('Onan', 'Performer P216 / P220', 0.7, 'V-Twin', 20, 'Gasoline', '3600 RPM AC/DC Generator', 1987, 2003),
    eng('Kohler', 'Command Pro CH20 / CH730', 0.7, 'V-Twin OHV', 23, 'Gasoline', '3600 RPM Accu-Rated Generator', 1998, 2020),
    eng('Subaru', 'EH65', 0.7, 'V-Twin OHV', 22, 'Gasoline', '3600 RPM Generator', 2005, 2016),
  ], ['Bobcat 225G', 'Bobcat 225NT'], SOURCE_EPA_OEM),
  mdl('Bobcat 250', 'Multi-Process Truck-Mount Welder/Generators', 'Site Support', ['Welding Machine'], 2001, 2021, [
    eng('Kohler', 'Command Pro CH730 / ECH730 EFI', 0.7, 'V-Twin OHV', 23, 'Gasoline', '3600 RPM Accu-Rated Generator', 2001, 2021),
    eng('Kubota', 'D722', 0.7, '3-Cyl Water-Cooled', 19, 'Diesel', '3600 RPM Accu-Rated Generator', 2002, 2021),
    eng('Kohler', 'Command Pro LP', 0.7, 'V-Twin', 23, 'Dual Fuel (Gas/LPG)', '3600 RPM Generator', 2004, 2021),
  ], ['Bobcat 250 EFI', 'Bobcat 250 Diesel', 'Bobcat 260'], SOURCE_EPA_OEM),
  mdl('Bobcat 265', 'Next-Gen Lightweight Inverter Engine-Driven Welders', 'Site Support', ['Welding Machine'], 2022, 2026, [
    eng('Kohler', 'Command Pro CH730 Carbureted', 0.7, 'V-Twin OHV', 23.5, 'Gasoline', 'Auto-Speed Inverter Welder/Generator', 2022, 2026),
    eng('Kohler', 'Command Pro ECH730 EFI', 0.7, 'V-Twin EFI', 23.5, 'Gasoline', 'Auto-Speed Inverter Welder/Generator', 2022, 2026),
  ], ['Bobcat 230', 'Bobcat 200 Air Pak'], SOURCE_EPA_OEM),
  mdl('Trailblazer 302', 'Pro Field Fabrication & Pipe Welder/Generators', 'Site Support', ['Welding Machine'], 2001, 2013, [
    eng('Kohler', 'Command Pro CH23 / CH730', 0.7, 'V-Twin OHV', 23, 'Gasoline', 'Four-Pole 3-Phase Swept-Field Generator', 2001, 2013),
    eng('Kubota', 'D722', 0.7, '3-Cyl', 19, 'Diesel', 'Four-Pole Generator', 2002, 2013),
    eng('Subaru', 'EH65', 0.7, 'V-Twin', 22, 'Gasoline', 'Four-Pole Generator', 2005, 2013),
  ], ['Trailblazer 251', 'Trailblazer 275', 'Trailblazer 302 Air Pak'], SOURCE_EPA_OEM),
  mdl('Trailblazer 325', 'EFI & Diesel Pro Multi-Process Welders', 'Site Support', ['Welding Machine'], 2013, 2023, [
    eng('Kohler', 'Command Pro CH730 / ECH730 EFI', 0.7, 'V-Twin EFI', 25, 'Gasoline', 'Excel Power Auto-Speed Generator', 2013, 2023),
    eng('Kubota', 'D902', 0.9, '3-Cyl Water-Cooled', 25, 'Diesel', 'Excel Power Auto-Speed Generator', 2013, 2023),
  ], ['Trailblazer 325 Diesel', 'Trailblazer 325 EFI'], SOURCE_EPA_OEM),
  mdl('Trailblazer 330', 'Next-Gen ArcReach Multi-Process Engine Welders', 'Site Support', ['Welding Machine'], 2023, 2026, [
    eng('Kohler', 'Command Pro ECH730 EFI', 0.7, 'V-Twin EFI', 23.5, 'Gasoline', 'Dynamic Dig Inverter Generator', 2023, 2026),
    eng('Kubota', 'D902', 0.9, '3-Cyl Water-Cooled', 24.8, 'Diesel', 'Dynamic Dig Inverter Generator', 2023, 2026),
  ], ['Trailblazer 330 Air Pak'], SOURCE_EPA_OEM),
  mdl('Big Blue 400 Pro', 'Industrial Pipeline & Structural Diesel Welders', 'Site Support', ['Welding Machine'], 2000, 2026, [
    eng('Kubota', 'V1505', 1.5, '4-Cyl', 24.8, 'Diesel', '1800 RPM Low-Speed Industrial Generator', 2012, 2026),
    eng('Caterpillar / Perkins', 'C1.5 / 404D-22', 2.2, '4-Cyl', 32, 'Diesel', '1800 RPM Industrial Generator', 2000, 2020),
    eng('Mitsubishi', 'S4L2', 1.8, '4-Cyl', 24.7, 'Diesel', '1800 RPM Industrial Generator', 2014, 2026),
  ], ['Big Blue 300 Pro', 'Big Blue 400 PipePro', 'PipePro 304'], SOURCE_EPA_OEM),
  mdl('Big Blue 500 Pro', 'Heavy Gouging & Multi-Operator Diesel Welders', 'Site Support', ['Welding Machine'], 2002, 2026, [
    eng('Deutz', 'D2011L03i / D2.9 L4', 2.9, '4-Cyl', 48, 'Diesel', '1800 RPM Heavy Industrial Generator', 2002, 2026),
    eng('Kubota', 'V2403-CR-T', 2.4, '4-Cyl Turbo', 49, 'Diesel', '1800 RPM Heavy Industrial Generator', 2014, 2026),
  ], ['Big Blue 450 Duo CST'], SOURCE_EPA_OEM),
  mdl('Big Blue 600', 'Heavy Oilfield Gouging & Air-Pak Diesel Welders', 'Site Support', ['Welding Machine'], 2005, 2026, [
    eng('Deutz', 'TD2011L04w / TD2.9 L4', 2.9, '4-Cyl Turbo', 65.7, 'Diesel', '1800 RPM Generator + Ingersoll-Rand Screw Compressor', 2005, 2026),
    eng('Cummins', 'B3.3T', 3.3, '4-Cyl Turbo', 65, 'Diesel', '1800 RPM Heavy Industrial Generator', 2005, 2016),
  ], ['Big Blue 600 Pro', 'Big Blue 600 Air Pak'], SOURCE_EPA_OEM),
  mdl('Big Blue 800 Duo Air Pak', 'Dual-Operator Heavy Gouging & Rotary Compressor Welders', 'Site Support', ['Welding Machine'], 2010, 2026, [
    eng('Deutz', 'TD2.9 L4 Tier 4F', 2.9, '4-Cyl Turbo', 65.7, 'Diesel', '1800 RPM Dual-Arc + 60 CFM Screw Air Compressor', 2014, 2026),
    eng('Cummins', 'B3.3T', 3.3, '4-Cyl Turbo', 65, 'Diesel', '1800 RPM Dual-Operator Generator', 2010, 2015),
  ], ['Big Blue 700X Duo Pro', 'Big Blue 800X Duo Pro'], SOURCE_EPA_OEM),
];

// ============================================================================
// EXTENDED 1970–2026 GENERATIONAL MODELS (Ensuring full generational depth across all OEMs)
// ============================================================================
const EXTENDED_MODELS_BY_ID = {
  komatsu: [
    mdl('D31E-20', 'Small Hydrostatic Dozers', 'Heavy Equipment', DOZ, 1992, 2006, se('Komatsu', 'S4D102E-1', 3.9, '4-Cyl Turbo', 70, 'Diesel', 'Hydrostatic')),
    mdl('D39EX-22', 'Small Hydrostatic Dozers', 'Heavy Equipment', DOZ, 2007, 2014, se('Komatsu', 'SAA4D95LE-5', 3.3, '4-Cyl Turbo', 95, 'Diesel', 'Hydrostatic')),
    mdl('D51EX-22', 'Medium Hydrostatic Dozers', 'Heavy Equipment', DOZ, 2007, 2014, se('Komatsu', 'SAA6D107E-1', 6.7, '6-Cyl Turbo', 130, 'Diesel', 'Hydrostatic')),
    mdl('D61EX-15', 'Medium Hydrostatic Dozers', 'Heavy Equipment', DOZ, 2003, 2012, se('Komatsu', 'SAA6D107E-1', 6.7, '6-Cyl Turbo', 155, 'Diesel', 'Hydrostatic')),
    mdl('D61EX-23', 'Medium Hydrostatic Dozers', 'Heavy Equipment', DOZ, 2013, 2016, se('Komatsu', 'SAA6D107E-2', 6.8, '6-Cyl Turbo', 168, 'Diesel', 'Hydrostatic')),
    mdl('D155A-1', 'Classic Large Dozers', 'Heavy Equipment', DOZ, 1971, 1986, se('Komatsu', 'S6D155-4', 19.3, '6-Cyl Turbo', 320, 'Diesel', 'Torqflow Powershift')),
    mdl('D155AX-5', 'Large Crawler Dozers', 'Heavy Equipment', DOZ, 1997, 2007, se('Komatsu', 'SA6D140E-2', 15.2, '6-Cyl Turbo', 310, 'Diesel', 'Torqflow Powershift')),
    mdl('PC170LC-11', 'Dash-11 Crawler Excavators', 'Heavy Equipment', EXC, 2017, 2026, se('Komatsu', 'SAA4D107E-3', 4.5, '4-Cyl Turbo', 121)),
    mdl('WA200-6', 'WA Series Wheel Loaders', 'Heavy Equipment', LDR, 2008, 2013, se('Komatsu', 'SAA4D107E-1', 4.5, '4-Cyl Turbo', 126, 'Diesel', 'Hydrostatic')),
    mdl('WA320-6', 'WA Series Wheel Loaders', 'Heavy Equipment', LDR, 2008, 2013, se('Komatsu', 'SAA6D107E-1', 6.7, '6-Cyl Turbo', 167, 'Diesel', 'Hydrostatic')),
    mdl('WA380-6', 'WA Series Wheel Loaders', 'Heavy Equipment', LDR, 2006, 2013, se('Komatsu', 'SAA6D107E-1', 6.7, '6-Cyl Turbo', 191, 'Diesel', 'Powershift')),
    mdl('WA470-6', 'WA Series Wheel Loaders', 'Heavy Equipment', LDR, 2006, 2013, se('Komatsu', 'SAA6D125E-5', 11.0, '6-Cyl Turbo', 272, 'Diesel', 'Powershift')),
    mdl('WA500-6', 'WA Series Large Loaders', 'Heavy Equipment', LDR, 2006, 2014, se('Komatsu', 'SAA6D140E-5', 15.2, '6-Cyl Turbo', 353, 'Diesel', 'Powershift')),
  ],
  case: [
    mdl('590 Super L', '590 Heavy Backhoe Loaders', 'Heavy Equipment', BKH, 1995, 2000, se('Case / CDC', '4T-390', 3.9, '4-Cyl Turbo', 95, 'Diesel', '4-Speed Powershuttle')),
    mdl('590 Super M', '590 Heavy Backhoe Loaders', 'Heavy Equipment', BKH, 2001, 2010, se('Case', '445T/M3', 4.5, '4-Cyl Turbo', 98, 'Diesel', 'Powershift')),
    mdl('CX80C', 'CX Midi Excavators', 'Heavy Equipment', EXC, 2013, 2024, se('Isuzu', '4LE2X', 2.2, '4-Cyl Turbo', 54), [], SOURCE_EPA_OEM),
    mdl('CX130B', 'CX Series Excavators', 'Heavy Equipment', EXC, 2007, 2012, se('Isuzu', '4JJ1X', 3.0, '4-Cyl Turbo', 95)),
    mdl('CX145D SR', 'Short-Radius Excavators', 'Heavy Equipment', EXC, 2016, 2026, se('Isuzu', '4JJ1X', 3.0, '4-Cyl Turbo', 102)),
    mdl('CX250D', 'CX-D Series Excavators', 'Heavy Equipment', EXC, 2015, 2025, se('Isuzu', '4HK1X', 5.2, '4-Cyl Turbo', 177)),
    mdl('CX490D', 'CX-D Heavy Excavators', 'Heavy Equipment', EXC, 2015, 2025, se('Isuzu', '6UZ1X', 9.8, '6-Cyl Turbo', 362)),
    mdl('721F', 'F-Series Wheel Loaders', 'Heavy Equipment', LDR, 2011, 2017, se('FPT Industrial', 'F4HFE613', 6.7, '6-Cyl Turbo', 179, 'Diesel', 'ZF Powershift')),
    mdl('850K', 'K-Series Crawler Dozers', 'Heavy Equipment', DOZ, 2002, 2012, se('Case', '6T-590 / 667TA', 5.9, '6-Cyl Turbo', 96, 'Diesel', 'Hydrostatic')),
    mdl('1150K', 'K-Series Crawler Dozers', 'Heavy Equipment', DOZ, 2002, 2013, se('Case', '6T-590 / 667TA', 6.7, '6-Cyl Turbo', 118, 'Diesel', 'Hydrostatic')),
    mdl('1650L', 'L-Series Crawler Dozers', 'Heavy Equipment', DOZ, 2008, 2014, se('Case', '667TA', 6.7, '6-Cyl Turbo', 144, 'Diesel', 'Hydrostatic')),
  ],
  kubota: [
    mdl('KH-90', 'KH Classic Mini Excavators', 'Heavy Equipment', EXC, 1983, 1992, se('Kubota', 'V1702', 1.7, '4-Cyl', 32), [], SOURCE_EPA_OEM),
    mdl('KH-151', 'KH Classic Excavators', 'Heavy Equipment', EXC, 1985, 1994, se('Kubota', 'V1902', 1.9, '4-Cyl', 41), [], SOURCE_EPA_OEM),
    mdl('KX71-3', 'KX-3 Compact Excavators', 'Heavy Equipment', EXC, 2003, 2013, se('Kubota', 'V1505', 1.5, '4-Cyl', 27), [], SOURCE_EPA_OEM),
    mdl('KX91-3', 'KX-3 Compact Excavators', 'Heavy Equipment', EXC, 2003, 2014, se('Kubota', 'D1503-M', 1.5, '3-Cyl', 28), [], SOURCE_EPA_OEM),
    mdl('KX080-3', 'KX-3 Mid-Size Excavators', 'Heavy Equipment', EXC, 2006, 2013, se('Kubota', 'V3307-DI-T', 3.3, '4-Cyl Turbo', 65), [], SOURCE_EPA_OEM),
    mdl('U17', 'Zero-Tail Ultra-Compact Excavators', 'Heavy Equipment', EXC, 2008, 2026, se('Kubota', 'D902', 0.9, '3-Cyl', 16), [], SOURCE_EPA_OEM),
    mdl('U25S', 'Zero-Tail Compact Excavators', 'Heavy Equipment', EXC, 2009, 2024, se('Kubota', 'D1105-E4', 1.1, '3-Cyl', 20), ['U27-4'], SOURCE_EPA_OEM),
    mdl('U48-5', 'Zero-Tail Compact Excavators', 'Heavy Equipment', EXC, 2021, 2026, se('Kubota', 'D1803-CR-TE5', 1.8, '3-Cyl Turbo', 40), [], SOURCE_EPA_OEM),
  ],
  volvo_ce: [
    mdl('L120E', 'L120 Wheel Loaders', 'Heavy Equipment', LDR, 2002, 2007, se('Volvo', 'D7D', 7.1, '6-Cyl Turbo', 221, 'Diesel', 'HTE Powershift')),
    mdl('L120G', 'L120 Wheel Loaders', 'Heavy Equipment', LDR, 2011, 2014, se('Volvo', 'D8H', 7.8, '6-Cyl Turbo', 243, 'Diesel', 'HTE Powershift')),
    mdl('L180H', 'Large Wheel Loaders', 'Heavy Equipment', LDR, 2014, 2026, se('Volvo', 'D13J', 12.8, '6-Cyl Turbo', 330, 'Diesel', 'OptiShift Powershift')),
    mdl('L220H', 'Large Wheel Loaders', 'Heavy Equipment', LDR, 2014, 2026, se('Volvo', 'D13J', 12.8, '6-Cyl Turbo', 366, 'Diesel', 'OptiShift Powershift')),
    mdl('A25D', 'A-Series Articulated Haulers', 'Transport & Hauling', ADT, 2001, 2007, se('Volvo', 'D9A / D10B', 9.4, '6-Cyl Turbo', 300, 'Diesel', 'PowerTronic')),
    mdl('A30G', 'G-Series Articulated Haulers', 'Transport & Hauling', ADT, 2014, 2026, se('Volvo', 'D11L', 10.8, '6-Cyl Turbo', 355, 'Diesel', 'PowerTronic')),
    mdl('EC140D', 'D-Series Crawler Excavators', 'Heavy Equipment', EXC, 2012, 2016, se('Volvo', 'D4H', 4.0, '4-Cyl Turbo', 105)),
    mdl('EC250E', 'E-Series Crawler Excavators', 'Heavy Equipment', EXC, 2015, 2026, se('Volvo', 'D8J', 7.8, '6-Cyl Turbo', 213)),
    mdl('G940', 'G900 Series Motor Graders', 'Heavy Equipment', GRD, 2006, 2015, se('Volvo', 'D7E', 7.1, '6-Cyl Turbo', 215, 'Diesel', 'HTE840 8F/4R Powershift'), ['G930', 'G970']),
  ],
  hitachi: [
    mdl('UH122', 'UH Classic Excavators', 'Heavy Equipment', EXC, 1978, 1986, se('Isuzu', '6BG1T', 6.5, '6-Cyl Turbo', 160)),
    mdl('UH172', 'UH Classic Heavy Excavators', 'Heavy Equipment', EXC, 1978, 1987, se('Isuzu', 'E120', 12.0, '6-Cyl', 220)),
    mdl('EX60', 'EX Compact Excavators', 'Heavy Equipment', EXC, 1988, 2000, se('Nissan / Isuzu', 'FD33 / 4JG1', 3.1, '4-Cyl', 54), ['EX60-2', 'EX60-5']),
    mdl('EX100-2', 'EX Series Excavators', 'Heavy Equipment', EXC, 1991, 1998, se('Isuzu', '4BD1T', 3.9, '4-Cyl Turbo', 74), ['EX100-3', 'EX100-5']),
    mdl('EX120-3', 'EX Series Excavators', 'Heavy Equipment', EXC, 1993, 1997, se('Isuzu', '4BD1T', 3.9, '4-Cyl Turbo', 84)),
    mdl('EX150', 'EX Series Excavators', 'Heavy Equipment', EXC, 1989, 1997, se('Isuzu', '6BB1 / 4BG1T', 4.3, '4-Cyl Turbo', 99), ['EX160LC-5']),
    mdl('EX270', 'EX Series Excavators', 'Heavy Equipment', EXC, 1989, 2001, se('Isuzu', '6BG1T / H07CT', 6.7, '6-Cyl Turbo', 178), ['EX 270 LC', 'EX270-5']),
    mdl('EX300-2', 'EX300 Series Excavators', 'Heavy Equipment', EXC, 1991, 1995, se('Isuzu', '6SD1T', 9.8, '6-Cyl Turbo', 217), ['EX 300LC-2']),
    mdl('EX330LC-5', 'EX-5 Series Excavators', 'Heavy Equipment', EXC, 1997, 2002, se('Isuzu', '6SD1TC', 9.8, '6-Cyl Turbo', 237), ['EX370-5']),
    mdl('EX450LC-5', 'EX-5 Heavy Excavators', 'Heavy Equipment', EXC, 1997, 2002, se('Isuzu', '6WG1', 15.7, '6-Cyl Turbo', 311), ['EX550LC', 'EX750-5']),
    mdl('ZX35U-5N', 'ZAXIS Compact Excavators', 'Heavy Equipment', EXC, 2014, 2026, se('Yanmar', '3TNV88F', 1.6, '3-Cyl', 23), [], SOURCE_EPA_OEM),
    mdl('ZX130-6', 'ZAXIS-6 Excavators', 'Heavy Equipment', EXC, 2016, 2024, se('Isuzu', '4JJ1', 3.0, '4-Cyl Turbo', 98), ['ZX120'], SOURCE_EPA_OEM),
    mdl('ZX160LC-6', 'ZAXIS-6 Excavators', 'Heavy Equipment', EXC, 2016, 2024, se('Isuzu', '4JJ1', 3.0, '4-Cyl Turbo', 121), [], SOURCE_EPA_OEM),
    mdl('ZX250LC-6', 'ZAXIS-6 Excavators', 'Heavy Equipment', EXC, 2016, 2024, se('Isuzu', '4HK1', 5.2, '4-Cyl Turbo', 177), ['ZX240-3'], SOURCE_EPA_OEM),
    mdl('ZX470LC-5', 'ZAXIS-5 Heavy Excavators', 'Heavy Equipment', EXC, 2012, 2016, se('Isuzu', '6UZ1', 9.8, '6-Cyl Turbo', 362), [], SOURCE_EPA_OEM),
    mdl('ZW150-6', 'ZW Series Wheel Loaders', 'Heavy Equipment', LDR, 2016, 2026, se('Cummins', 'QSB6.7', 6.7, '6-Cyl Turbo', 142, 'Diesel', 'Hydrostatic'), [], SOURCE_EPA_OEM),
  ],
  jcb: [
    mdl('1550B', 'North American Backhoe Series', 'Heavy Equipment', BKH, 1986, 1993, se('Perkins', '4.236T', 3.9, '4-Cyl Turbo', 86, 'Diesel', '4-Speed Syncro Shuttle'), [], SOURCE_EPA_OEM),
    mdl('214E', '200 Series Backhoe Loaders', 'Heavy Equipment', BKH, 2000, 2006, se('Perkins', '1004.4 / 1104C-44', 4.4, '4-Cyl', 82, 'Diesel', '4-Speed Syncro Shuttle'), [], SOURCE_EPA_OEM),
    mdl('5CX', 'Heavy Backhoe Loaders', 'Heavy Equipment', BKH, 2014, 2026, se('JCB', 'EcoMAX 448', 4.8, '4-Cyl Turbo', 118, 'Diesel', '6-Speed AutoShift'), [], SOURCE_EPA_OEM),
    mdl('8035 ZTS', 'Compact Zero-Tail Excavators', 'Heavy Equipment', EXC, 2007, 2017, se('Perkins', '403D-15', 1.5, '3-Cyl', 31), [], SOURCE_EPA_OEM),
    mdl('50Z-1', 'Next-Gen Compact Excavators', 'Heavy Equipment', EXC, 2018, 2026, se('Perkins', '404D-22 / Kohler KDI 1903', 1.9, '3-Cyl', 48), [], SOURCE_EPA_OEM),
    mdl('JS160', 'JS Series Excavators', 'Heavy Equipment', EXC, 2002, 2020, se('Isuzu / JCB', 'EcoMAX 444', 4.4, '4-Cyl Turbo', 125), [], SOURCE_EPA_OEM),
    mdl('245XR', 'X-Series Reduced-Swing Excavators', 'Heavy Equipment', EXC, 2021, 2026, se('JCB', 'Dieselmax 448', 4.8, '4-Cyl Turbo', 173), [], SOURCE_EPA_OEM),
    mdl('520-50', 'Compact Loadall Telehandlers', 'Heavy Equipment', TLH, 1994, 2018, se('Perkins / JCB', '1004-4 / Dieselmax', 4.4, '4-Cyl', 74, 'Diesel', 'Hydrostatic'), ['524-50', '525-60'], SOURCE_EPA_OEM),
    mdl('506C', 'Classic North American Telehandlers', 'Heavy Equipment', TLH, 1998, 2007, se('Perkins', '1004-4T', 4.0, '4-Cyl Turbo', 82, 'Diesel', '4-Speed Powershift'), [], SOURCE_EPA_OEM),
    mdl('541-70', 'Agri / Industrial Loadall Telehandlers', 'Heavy Equipment', TLH, 2006, 2026, se('JCB', 'EcoMAX 444 / 448', 4.8, '4-Cyl Turbo', 125, 'Diesel', '4/6-Speed Powershift'), [], SOURCE_EPA_OEM),
    mdl('270', 'Large Platform Skid Steers', 'Heavy Equipment', SSL, 2011, 2026, se('JCB / Kohler', 'EcoMAX 444 / KDI 2504TCR', 2.5, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
    mdl('427', 'Wheel Loaders', 'Heavy Equipment', LDR, 2013, 2026, se('Cummins', 'QSB6.7', 6.7, '6-Cyl Turbo', 179, 'Diesel', 'ZF 5-Speed Powershift'), ['437'], SOURCE_EPA_OEM),
  ],
  new_holland: [
    mdl('L445', 'Classic Skid Steers', 'Heavy Equipment', SSL, 1975, 1984, se('Wisconsin / Deutz', 'F2L511', 1.7, '2-Cyl', 31, 'Diesel', 'Hydrostatic'), [], SOURCE_EPA_OEM),
    mdl('L785', '700 Series Super Boom Skid Steers', 'Heavy Equipment', SSL, 1984, 1994, se('Ford', 'BSD333', 3.3, '3-Cyl', 57, 'Diesel', 'Hydrostatic'), [], SOURCE_EPA_OEM),
    mdl('LX565', 'LX Series Skid Steers', 'Heavy Equipment', SSL, 1994, 1999, se('ISM / Shibaura', 'N844', 2.0, '4-Cyl', 40, 'Diesel', 'Hydrostatic'), [], SOURCE_EPA_OEM),
    mdl('LX885', 'LX Series Turbo Skid Steers', 'Heavy Equipment', SSL, 1994, 1999, se('New Holland', '332T', 3.2, '3-Cyl Turbo', 60, 'Diesel', 'Hydrostatic'), [], SOURCE_EPA_OEM),
    mdl('LS160', 'LS Series Skid Steers', 'Heavy Equipment', SSL, 1999, 2006, se('ISM', 'N844', 2.0, '4-Cyl', 42, 'Diesel', 'Hydrostatic'), ['LS170'], SOURCE_EPA_OEM),
    mdl('LS190', 'LS Heavy Super Boom Skid Steers', 'Heavy Equipment', SSL, 1999, 2006, se('New Holland', '450T', 4.5, '4-Cyl Turbo', 83, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
    mdl('L218', '200 Series Skid Steers', 'Heavy Equipment', SSL, 2011, 2019, se('ISM', 'N844LTA', 2.2, '4-Cyl Turbo', 60, 'Diesel', 'Hydrostatic'), ['L225', 'L230'], SOURCE_EPA_OEM),
    mdl('L320', '300 Series Skid Steers', 'Heavy Equipment', SSL, 2020, 2026, se('ISM', 'N844LTA Tier 4F', 2.2, '4-Cyl Turbo', 67, 'Diesel', 'Hydrostatic'), ['L334'], SOURCE_EPA_OEM),
    mdl('655E', 'Ford / New Holland Backhoe Loaders', 'Heavy Equipment', BKH, 1996, 2000, se('Ford / Genesis', '304T', 5.0, '4-Cyl Turbo', 90, 'Diesel', '4-Speed Powershuttle'), ['675E']),
    mdl('E37C', 'C-Series Compact Excavators', 'Heavy Equipment', EXC, 2017, 2026, se('Yanmar', '3TNV88F', 1.6, '3-Cyl', 24), [], SOURCE_EPA_OEM),
  ],
  kobelco: [
    mdl('K905', 'Classic K-Series Excavators', 'Heavy Equipment', EXC, 1978, 1989, se('Mitsubishi', '6D14T', 6.6, '6-Cyl Turbo', 104), ['K 905A LC']),
    mdl('SK120', 'Mark III / IV Excavators', 'Heavy Equipment', EXC, 1990, 1999, se('Isuzu', '4BD1T', 3.9, '4-Cyl Turbo', 84), ['SK120LC-IV']),
    mdl('SK135SR', 'SR Short-Radius Excavators', 'Heavy Equipment', EXC, 2000, 2012, se('Isuzu', '4BG1T / 4JJ1X', 3.0, '4-Cyl Turbo', 94), ['SK135SRLC-2'], SOURCE_EPA_OEM),
    mdl('SK200-8', 'Acera Geospec Excavators', 'Heavy Equipment', EXC, 2006, 2012, se('Hino', 'J05E', 5.1, '4-Cyl Turbo', 148), [], SOURCE_EPA_OEM),
    mdl('SK260LC-10', 'SK-10 Series Excavators', 'Heavy Equipment', EXC, 2016, 2021, se('Hino', 'J05E-UM', 5.1, '4-Cyl Turbo', 181), [], SOURCE_EPA_OEM),
    mdl('SK300LC-10', 'SK-10 Series Excavators', 'Heavy Equipment', EXC, 2016, 2021, se('Hino', 'J08E-UV', 7.7, '6-Cyl Turbo', 252), [], SOURCE_EPA_OEM),
  ],
  link_belt: [
    mdl('LS-3400', 'Classic LS Crawler Excavators', 'Heavy Equipment', EXC, 1978, 1993, se('Isuzu', '6BG1T / GM 6-71', 6.5, '6-Cyl Turbo', 155)),
    mdl('LS-4300', 'Classic LS Crawler Excavators', 'Heavy Equipment', EXC, 1980, 1994, se('Isuzu', '6RB1 / Cummins NTA855', 11.0, '6-Cyl Turbo', 208), ['LS-5800']),
    mdl('3400 Quantum', 'Quantum Series Excavators', 'Heavy Equipment', EXC, 1994, 1999, se('Isuzu', '6SD1T', 9.8, '6-Cyl Turbo', 184)),
    mdl('130 LX', 'LX Series Excavators', 'Heavy Equipment', EXC, 2001, 2007, se('Isuzu', '4BG1T', 4.3, '4-Cyl Turbo', 90)),
    mdl('240 LX', 'LX Series Excavators', 'Heavy Equipment', EXC, 2001, 2007, se('Isuzu', '6HK1X', 7.8, '6-Cyl Turbo', 174), ['290 LX', '330 LX']),
    mdl('75 Spin Ace', 'Midi Short-Radius Excavators', 'Heavy Equipment', EXC, 2003, 2015, se('Isuzu', '4LE2X', 2.2, '4-Cyl Turbo', 54), ['80 Spin Ace']),
  ],
  takeuchi: [
    mdl('TB025', 'Classic TB Mini Excavators', 'Heavy Equipment', EXC, 1990, 2000, se('Yanmar', '3TNA84', 1.5, '3-Cyl', 23), ['TB 025']),
    mdl('TB045', 'Classic TB Compact Excavators', 'Heavy Equipment', EXC, 1990, 2000, se('Yanmar', '4TNA84', 2.0, '4-Cyl', 38), ['TB 045', 'TB 070']),
    mdl('TB125', 'TB100 Compact Excavators', 'Heavy Equipment', EXC, 2000, 2012, se('Yanmar', '3TNE82 / 3TNV82', 1.3, '3-Cyl', 23), [], SOURCE_EPA_OEM),
    mdl('TB145', 'TB100 Compact Excavators', 'Heavy Equipment', EXC, 2001, 2012, se('Yanmar', '4TNV88', 2.2, '4-Cyl', 37), [], SOURCE_EPA_OEM),
    mdl('TB235-2', 'TB200 Compact Excavators', 'Heavy Equipment', EXC, 2018, 2026, se('Yanmar', '3TNV88F', 1.6, '3-Cyl', 24), [], SOURCE_EPA_OEM),
    mdl('TB280FR', 'Full-Rotation Zero-Swing Excavators', 'Heavy Equipment', EXC, 2012, 2022, se('Yanmar', '4TNV98CT', 3.3, '4-Cyl Turbo', 69), [], SOURCE_EPA_OEM),
    mdl('TL6R', 'Compact Track Loaders', 'Heavy Equipment', SSL, 2018, 2026, se('Kubota', 'V2403-CR-TE4', 2.4, '4-Cyl Turbo', 65, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
    mdl('TL8R2', 'Radial-Lift Compact Track Loaders', 'Heavy Equipment', SSL, 2020, 2026, se('Kubota', 'V3307-CR-TE5', 3.3, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
  ],
  develon: [
    mdl('Solar 130LC-V', 'Daewoo Solar Excavators', 'Heavy Equipment', EXC, 1996, 2005, se('Daewoo', 'DB58T', 5.8, '6-Cyl Turbo', 95), ['Solar 175LC-V'], SOURCE_EPA_OEM),
    mdl('Solar 290LC-V', 'Daewoo Solar Excavators', 'Heavy Equipment', EXC, 1997, 2005, se('Daewoo', 'DE08TIS', 8.1, '6-Cyl Turbo', 195), ['Solar 340LC-V'], SOURCE_EPA_OEM),
    mdl('DX63-3', 'Compact Excavators', 'Heavy Equipment', EXC, 2013, 2021, se('Yanmar', '4TNV98C', 3.3, '4-Cyl', 59), [], SOURCE_EPA_OEM),
    mdl('DX140LC-5', 'DX-5 Crawler Excavators', 'Heavy Equipment', EXC, 2015, 2021, se('Perkins', '1204F', 4.4, '4-Cyl Turbo', 115), ['DX140LCR-5'], SOURCE_EPA_OEM),
    mdl('DX300LC-5', 'DX-5 Crawler Excavators', 'Heavy Equipment', EXC, 2015, 2021, se('Doosan', 'DL08P', 7.6, '6-Cyl Turbo', 271), [], SOURCE_EPA_OEM),
    mdl('DX420LC-7', 'Dash-7 Heavy Excavators', 'Heavy Equipment', EXC, 2021, 2026, se('Scania', 'DC13', 12.7, '6-Cyl Turbo', 344), [], SOURCE_EPA_OEM),
    mdl('DL200-5', 'DL Series Wheel Loaders', 'Heavy Equipment', LDR, 2015, 2021, se('Perkins / Doosan', '1204F / DL06', 4.4, '4-Cyl Turbo', 142, 'Diesel', 'ZF Powershift'), ['DL200-7'], SOURCE_EPA_OEM),
    mdl('DA45-7', 'Heavy Articulated Dump Trucks', 'Transport & Hauling', ADT, 2020, 2026, se('Scania', 'DC13', 12.7, '6-Cyl Turbo', 500, 'Diesel', 'ZF EP420 8F/4R Powershift'), ['DA40-5'], SOURCE_EPA_OEM),
  ],
  hyundai_ce: [
    mdl('290LC-3', 'Robex Classic Excavators', 'Heavy Equipment', EXC, 1995, 2002, se('Cummins', '6CT8.3-C', 8.3, '6-Cyl Turbo', 195), ['280LC', '450LC']),
    mdl('R290LC-7', 'Robex Dash-7 Excavators', 'Heavy Equipment', EXC, 2002, 2010, se('Cummins', 'QSC8.3', 8.3, '6-Cyl Turbo', 213), ['R320LC-7']),
    mdl('R380LC-9', 'Robex Dash-9 Excavators', 'Heavy Equipment', EXC, 2010, 2016, se('Cummins', 'QSL9', 8.9, '6-Cyl Turbo', 296), ['R330LC-9A'], SOURCE_EPA_OEM),
    mdl('R55-9A', 'Robex Compact Excavators', 'Heavy Equipment', EXC, 2012, 2020, se('Yanmar', '4TNV98C', 3.3, '4-Cyl', 65), ['R35Z-9A'], SOURCE_EPA_OEM),
    mdl('HX130A LCR', 'HX-A Short-Radius Excavators', 'Heavy Equipment', EXC, 2020, 2026, se('Cummins', 'F3.8', 3.8, '4-Cyl Turbo', 74), [], SOURCE_EPA_OEM),
    mdl('HX260A L', 'HX-A Crawler Excavators', 'Heavy Equipment', EXC, 2020, 2026, se('Cummins', 'B6.7', 6.7, '6-Cyl Turbo', 192), ['HX260L'], SOURCE_EPA_OEM),
    mdl('HL770-9A', 'HL-9 Large Wheel Loaders', 'Heavy Equipment', LDR, 2010, 2016, se('Cummins', 'QSL9', 8.9, '6-Cyl Turbo', 297, 'Diesel', 'ZF Powershift'), [], SOURCE_EPA_OEM),
    mdl('HL955A', 'HL900A Wheel Loaders', 'Heavy Equipment', LDR, 2020, 2026, se('Cummins', 'B6.7', 6.7, '6-Cyl Turbo', 200, 'Diesel', 'ZF 4-Speed Powershift'), [], SOURCE_EPA_OEM),
  ],
  liebherr: [
    mdl('R 912', 'Classic Litronic Excavators', 'Heavy Equipment', EXC, 1972, 1995, se('Deutz / Liebherr', 'F6L912 / D904T', 5.7, '6-Cyl', 106), [], SOURCE_EPA_OEM),
    mdl('R 924', 'Litronic Crawler Excavators', 'Heavy Equipment', EXC, 1998, 2016, se('Liebherr', 'D924 TI-E', 4.5, '4-Cyl Turbo', 173), ['R 924 Compact'], SOURCE_EPA_OEM),
    mdl('R 934', 'Generation 8 Crawler Excavators', 'Heavy Equipment', EXC, 2000, 2026, se('Liebherr', 'D944 A7', 8.0, '4-Cyl Turbo', 272), [], SOURCE_EPA_OEM),
    mdl('R 954', 'Heavy Demolition & Quarry Excavators', 'Heavy Equipment', EXC, 1982, 2015, se('Liebherr', 'D926 / D936L', 10.5, '6-Cyl Turbo', 326), ['R 954 C'], SOURCE_EPA_OEM),
    mdl('A 918', 'Wheeled Excavators', 'Heavy Equipment', EXC, 2012, 2026, se('Liebherr', 'D924', 4.5, '4-Cyl Turbo', 163, 'Diesel', 'Hydrostatic Wheeled Travel'), ['A 918 Compact'], SOURCE_EPA_OEM),
    mdl('L 526', 'All-Rounder Wheel Loaders', 'Heavy Equipment', LDR, 2012, 2026, se('Liebherr / John Deere', '4045H / D924', 4.5, '4-Cyl Turbo', 136, 'Diesel', 'Hydrostatic'), [], SOURCE_EPA_OEM),
    mdl('L 580 XPower', 'XPower Large Wheel Loaders', 'Heavy Equipment', LDR, 2016, 2026, se('Liebherr', 'D936 A7', 12.0, '6-Cyl Turbo', 313, 'Diesel', 'XPower Power-Split CVT'), [], SOURCE_EPA_OEM),
    mdl('PR 716', 'Small Hydrostatic Dozers', 'Heavy Equipment', DOZ, 2015, 2026, se('Liebherr', 'D924', 4.5, '4-Cyl Turbo', 126, 'Diesel', 'Hydrostatic'), ['PR 724'], SOURCE_EPA_OEM),
    mdl('PR 746', 'Medium-Large Hydrostatic Dozers', 'Heavy Equipment', DOZ, 2016, 2026, se('Liebherr', 'D936 / D946', 12.0, '6-Cyl Turbo', 252, 'Diesel', 'Hydrostatic'), [], SOURCE_EPA_OEM),
    mdl('LTM 1250-5.1', '5-Axle All-Terrain Mobile Cranes', 'Heavy Equipment', CRN, 2015, 2026, se('Liebherr', 'D946 A7', 12.0, '6-Cyl Turbo', 544, 'Diesel', 'ZF TraXon 12-Speed Automated'), [], SOURCE_EPA_OEM),
  ],
  yanmar: [
    mdl('YB251', 'Classic YB Mini Excavators', 'Heavy Equipment', EXC, 1978, 1991, se('Yanmar', '3T84H', 1.5, '3-Cyl', 25), [], SOURCE_EPA_OEM),
    mdl('B50', 'Classic B-Series Excavators', 'Heavy Equipment', EXC, 1989, 2002, se('Yanmar', '4TNE88', 2.2, '4-Cyl', 39), ['B50-2B'], SOURCE_EPA_OEM),
    mdl('ViO17', 'True Zero-Tail Mini Excavators', 'Heavy Equipment', EXC, 2006, 2026, se('Yanmar', '3TNV70', 0.9, '3-Cyl', 13.5), ['ViO17-1E'], SOURCE_EPA_OEM),
    mdl('ViO27-6', 'True Zero-Tail Mini Excavators', 'Heavy Equipment', EXC, 2014, 2024, se('Yanmar', '3TNV80F', 1.3, '3-Cyl', 21), [], SOURCE_EPA_OEM),
    mdl('ViO35-5', 'ViO-5 Zero-Tail Excavators', 'Heavy Equipment', EXC, 2007, 2014, se('Yanmar', '3TNV88', 1.6, '3-Cyl', 27), [], SOURCE_EPA_OEM),
    mdl('ViO50-6A', 'True Zero-Tail Excavators', 'Heavy Equipment', EXC, 2014, 2026, se('Yanmar', '4TNV88C', 2.2, '4-Cyl', 39), [], SOURCE_EPA_OEM),
    mdl('ViO80-7', 'ViO-7 Mid-Size Excavators', 'Heavy Equipment', EXC, 2023, 2026, se('Yanmar', '4TNV98C', 3.3, '4-Cyl', 56), [], SOURCE_EPA_OEM),
    mdl('SV40', 'Ultra-Tight Turning Excavators', 'Heavy Equipment', EXC, 2016, 2026, se('Yanmar', '4TNV88C', 2.2, '4-Cyl', 39), [], SOURCE_EPA_OEM),
    mdl('TL75VS', 'Vertical-Lift Compact Track Loaders', 'Heavy Equipment', SSL, 2023, 2026, se('Yanmar', '4TNV98CT', 3.3, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
    mdl('TL80VS', 'Vertical-Lift Compact Track Loaders', 'Heavy Equipment', SSL, 2023, 2026, se('Yanmar', '4TNV98CT', 3.3, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
    mdl('V4-7', 'Compact Articulated Wheel Loaders', 'Heavy Equipment', LDR, 2014, 2026, se('Yanmar', '3TNV88C', 1.6, '3-Cyl', 36, 'Diesel', 'Hydrostatic'), [], SOURCE_EPA_OEM),
  ],
  wacker_neuson: [
    mdl('RD12A', '1-Ton Dual-Drum Asphalt Rollers', 'Heavy Equipment', CMP, 2002, 2026, se('Honda', 'GX630', 0.7, 'V-Twin', 20.8, 'Gasoline', 'Hydrostatic'), ['RD12', 'RD18'], SOURCE_EPA_OEM),
    mdl('RD27', '2.7-Ton Tandem Vibratory Rollers', 'Heavy Equipment', CMP, 2008, 2026, se('Kubota', 'D1703', 1.7, '3-Cyl', 33, 'Diesel', 'Hydrostatic'), ['RD24', 'RD28'], SOURCE_EPA_OEM),
    mdl('803', 'Ultra-Compact Dual-Power Excavators', 'Heavy Equipment', EXC, 2005, 2026, se('Yanmar', '3TNV70', 0.9, '3-Cyl', 13), [], SOURCE_EPA_OEM),
    mdl('ET24', 'Tracked Conventional-Tail Excavators', 'Heavy Equipment', EXC, 2014, 2026, se('Yanmar', '3TNV76', 1.1, '3-Cyl', 18), ['ET18'], SOURCE_EPA_OEM),
    mdl('EZ26', 'Zero-Tail Compact Excavators', 'Heavy Equipment', EXC, 2018, 2026, se('Yanmar', '3TNV80F', 1.3, '3-Cyl', 20), ['EZ28'], SOURCE_EPA_OEM),
    mdl('EZ53', 'Zero-Tail Excavators', 'Heavy Equipment', EXC, 2019, 2026, se('Perkins', '404J-E22T', 2.2, '4-Cyl Turbo', 49), ['EZ80'], SOURCE_EPA_OEM),
    mdl('ET145', '14-Ton Tracked Excavators', 'Heavy Equipment', EXC, 2017, 2026, se('Perkins', '904J-E36TA', 3.6, '4-Cyl Turbo', 100), [], SOURCE_EPA_OEM),
    mdl('SW21', 'Radial-Lift Skid Steers', 'Heavy Equipment', SSL, 2015, 2026, se('Kohler', 'KDI 2504TCR', 2.5, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), ['SM100'], SOURCE_EPA_OEM),
    mdl('ST35', 'Radial-Lift Compact Track Loaders', 'Heavy Equipment', SSL, 2015, 2022, se('Kohler', 'KDI 3404TCR', 3.4, '4-Cyl Turbo', 74, 'Diesel', '2-Speed Hydrostatic'), ['ST28'], SOURCE_EPA_OEM),
    mdl('TH627', 'Compact All-Wheel-Steer Telehandlers', 'Heavy Equipment', TLH, 2017, 2026, se('Kohler', 'KDI 2504TCR', 2.5, '4-Cyl Turbo', 74, 'Diesel', 'Hydrostatic'), ['TH412'], SOURCE_EPA_OEM),
    mdl('G25', 'Mobile Towable Generators', 'Site Support', ['Generator'], 2008, 2026, se('Isuzu / Kubota', '4LE2T / V2403', 2.2, '4-Cyl Turbo', 40, 'Diesel', '1800 RPM Synchronous Alternator'), ['G100'], SOURCE_EPA_OEM),
  ],
  terex: [
    mdl('72-61', 'Classic Terex-GM Wheel Loaders', 'Heavy Equipment', LDR, 1972, 1984, se('Detroit Diesel', '6V-71T', 7.0, 'V6 2-Stroke Turbo', 307, 'Diesel', 'Allison Powershift')),
    mdl('S-24B', 'Classic Open-Bowl Motor Scrapers / Graders', 'Heavy Equipment', GRD, 1970, 1986, se('Detroit Diesel', '12V-71T', 14.0, 'V12 2-Stroke Turbo', 475, 'Diesel', 'Allison CLT Powershift'), ['S 24', 'S 24C']),
    mdl('TLB840', 'Backhoe Loaders', 'Heavy Equipment', BKH, 2012, 2017, se('Deutz / Perkins', 'TCD 3.6 L4', 3.6, '4-Cyl Turbo', 74, 'Diesel', '4-Speed Syncro Shuttle'), ['TLB890'], SOURCE_EPA_OEM),
    mdl('TL100', 'Compact Articulated Wheel Loaders', 'Heavy Equipment', LDR, 2005, 2017, se('Deutz', 'TD2011 L04w', 3.6, '4-Cyl Turbo', 74, 'Diesel', 'Hydrostatic'), ['TL120'], SOURCE_EPA_OEM),
    mdl('TC35', 'Compact Mini Excavators', 'Heavy Equipment', EXC, 2005, 2017, se('Mitsubishi', 'S4L2', 1.8, '4-Cyl', 30), ['HR16', 'TC75'], SOURCE_EPA_OEM),
    mdl('PT-60', 'Posi-Track Compact Track Loaders', 'Heavy Equipment', SSL, 2007, 2015, se('Perkins', '404D-22T', 2.2, '4-Cyl Turbo', 60, 'Diesel', 'Hydrostatic'), ['TSR70'], SOURCE_EPA_OEM),
    mdl('PT-100G', 'Forestry & Heavy Posi-Track CTLs', 'Heavy Equipment', SSL, 2009, 2016, se('Perkins', '1104D-E44TA', 4.4, '4-Cyl Turbo', 99.5, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
    mdl('TA25', 'Articulated Dump Trucks', 'Transport & Hauling', ADT, 1998, 2011, se('Cummins', 'QSC8.3', 8.3, '6-Cyl Turbo', 300, 'Diesel', 'ZF 6F/3R Powershift'), ['TA27'], SOURCE_EPA_OEM),
    mdl('TA400', 'Heavy Articulated Dump Trucks', 'Transport & Hauling', ADT, 2011, 2026, se('Scania', 'DC13', 12.7, '6-Cyl Turbo', 444, 'Diesel', 'Allison HD4560 6-Speed Automatic'), ['TA40'], SOURCE_EPA_OEM),
    mdl('RT670', 'Rough Terrain Cranes', 'Heavy Equipment', CRN, 2002, 2024, se('Cummins', 'QSB6.7', 6.7, '6-Cyl Turbo', 240, 'Diesel', '6-Speed Powershift'), ['RT780'], SOURCE_EPA_OEM),
  ],
  gradall: [
    mdl('G-600', 'Classic Telescopic Boom Excavators', 'Heavy Equipment', EXC, 1970, 1982, se('Detroit Diesel', '4-53N', 3.5, '4-Cyl 2-Stroke', 120, 'Diesel', '6x4 Truck Carrier Hydraulic')),
    mdl('G-1000', 'Heavy Telescopic Boom Excavators', 'Heavy Equipment', EXC, 1972, 1988, se('Detroit Diesel', '6-71N', 7.0, '6-Cyl 2-Stroke', 238, 'Diesel', '8x4 Carrier / Crawler Hydraulic'), ['G 1000']),
    mdl('XL 2200', 'Compact Telescopic Crawler Excavators', 'Heavy Equipment', EXC, 1996, 2006, se('Cummins', '4BT3.9', 3.9, '4-Cyl Turbo', 100), ['XL 2300'], SOURCE_EPA_OEM),
    mdl('XL 3200 V', 'Crawler Telescopic Excavators', 'Heavy Equipment', EXC, 2014, 2026, se('Volvo Penta', 'TAD571VE', 5.1, '4-Cyl Turbo', 173), ['XL 3200 III'], SOURCE_EPA_OEM),
    mdl('XL 3300 V', 'Wheeled Yard/Site Telescopic Excavators', 'Heavy Equipment', EXC, 2014, 2026, se('Volvo Penta', 'TAD571VE', 5.1, '4-Cyl Turbo', 173, 'Diesel', '4WD Hydrostatic'), [], SOURCE_EPA_OEM),
    mdl('XL 4200 V', 'Crawler Telescopic Excavators', 'Heavy Equipment', EXC, 2014, 2026, se('Volvo Penta', 'TAD572VE', 5.1, '4-Cyl Turbo', 218), ['XL4200'], SOURCE_EPA_OEM),
    mdl('XL 4300 V', 'Wheeled Off-Pavement Telescopic Excavators', 'Heavy Equipment', EXC, 2014, 2026, se('Volvo Penta', 'TAD572VE', 5.1, '4-Cyl Turbo', 218, 'Diesel', '4WD Hydrostatic'), [], SOURCE_EPA_OEM),
    mdl('XL 5200 V', 'Heavy Crawler Telescopic Excavators', 'Heavy Equipment', EXC, 2014, 2026, se('Volvo Penta', 'TAD871VE', 7.7, '6-Cyl Turbo', 248), ['XL5200'], SOURCE_EPA_OEM),
    mdl('XL 5300 V', 'Heavy Wheeled Telescopic Excavators', 'Heavy Equipment', EXC, 2014, 2026, se('Volvo Penta', 'TAD871VE', 7.7, '6-Cyl Turbo', 248, 'Diesel', '4WD Hydrostatic'), [], SOURCE_EPA_OEM),
    mdl('534C-9', 'Classic Material Handler Telehandlers', 'Heavy Equipment', TLH, 1986, 1998, se('Cummins', '4BT3.9', 3.9, '4-Cyl Turbo', 95, 'Diesel', '3-Speed Powershift'), ['534B-8'], SOURCE_EPA_OEM),
    mdl('544D10-55', 'High-Capacity Telehandlers', 'Heavy Equipment', TLH, 1998, 2006, se('Cummins', '4BT3.9 / QSB4.5', 4.5, '4-Cyl Turbo', 110, 'Diesel', 'Powershift'), [], SOURCE_EPA_OEM),
  ],
  bell: [
    mdl('B25B', 'B-Series Articulated Dump Trucks', 'Transport & Hauling', ADT, 1989, 1996, se('Deutz / ADE', 'BF6L913C / ADE 366T', 6.1, '6-Cyl Turbo', 240, 'Diesel', 'ZF 6-Speed Powershift'), [], SOURCE_EPA_OEM),
    mdl('B30B', 'B-Series Articulated Dump Trucks', 'Transport & Hauling', ADT, 1989, 1996, se('ADE / Mercedes', 'ADE 442T', 11.0, 'V6 Turbo', 290, 'Diesel', 'ZF Powershift'), ['B40B'], SOURCE_EPA_OEM),
    mdl('B30C', 'C-Series Articulated Dump Trucks', 'Transport & Hauling', ADT, 1996, 2001, se('Mercedes-Benz', 'OM906LA', 6.4, '6-Cyl Turbo', 275, 'Diesel', 'ZF 6-Speed Powershift'), ['B40C'], SOURCE_EPA_OEM),
    mdl('B25D', 'D-Series Articulated Dump Trucks', 'Transport & Hauling', ADT, 2001, 2013, se('Mercedes-Benz', 'OM906LA', 6.4, '6-Cyl Turbo', 275, 'Diesel', 'Allison 3500PR Automatic'), [], SOURCE_EPA_OEM),
    mdl('B35D', 'D-Series Articulated Dump Trucks', 'Transport & Hauling', ADT, 2002, 2013, se('Mercedes-Benz', 'OM501LA', 11.9, 'V6 Turbo', 389, 'Diesel', 'Allison 4500PR Automatic'), [], SOURCE_EPA_OEM),
    mdl('B50D', 'D-Series 50-Ton Articulated Dump Trucks', 'Transport & Hauling', ADT, 2003, 2015, se('Mercedes-Benz', 'OM502LA', 15.9, 'V8 Turbo', 516, 'Diesel', 'Allison 4700PR Automatic'), [], SOURCE_EPA_OEM),
    mdl('B60E', 'E-Series 4x4 Crossover Mining Haulers', 'Transport & Hauling', ADT, 2017, 2026, se('Mercedes-Benz / MTU', 'OM473LA (6R1500)', 15.6, '6-Cyl Turbo', 577, 'Diesel', 'Allison 4700ORS 7-Speed Automatic'), [], SOURCE_EPA_OEM),
    mdl('L1806E', 'Articulated Wheel Loaders', 'Heavy Equipment', LDR, 2008, 2026, se('John Deere / Cummins', '6068H / QSB6.7', 6.7, '6-Cyl Turbo', 172, 'Diesel', 'ZF 4-Speed Powershift'), [], SOURCE_EPA_OEM),
    mdl('L2606E', 'Heavy Articulated Wheel Loaders', 'Heavy Equipment', LDR, 2008, 2026, se('John Deere / MTU', '6090H / 6R1000', 7.7, '6-Cyl Turbo', 282, 'Diesel', 'ZF Powershift'), [], SOURCE_EPA_OEM),
  ],
  manitou: [
    mdl('M 30-4', 'M-Series Rough-Terrain Forklifts', 'Heavy Equipment', FRK, 1995, 2026, se('Perkins / Deutz', '854F / TCD 2.9 L4', 2.9, '4-Cyl Turbo', 74, 'Diesel', '4WD Torque Converter'), [], SOURCE_EPA_OEM),
    mdl('M 50-4', 'Heavy Rough-Terrain Forklifts', 'Heavy Equipment', FRK, 1995, 2026, se('Perkins / Deutz', '1104D / TCD 3.6 L4', 3.6, '4-Cyl Turbo', 74, 'Diesel', '4WD Torque Converter'), [], SOURCE_EPA_OEM),
    mdl('MT 732', 'Easy Construction Telehandlers', 'Heavy Equipment', TLH, 2002, 2024, se('Perkins / Deutz', '1104C / TD 3.6 L4', 3.6, '4-Cyl Turbo', 75, 'Diesel', '4-Speed Torque Converter'), ['MT 932'], SOURCE_EPA_OEM),
    mdl('MT 1030 S', 'Construction Telehandlers', 'Heavy Equipment', TLH, 2000, 2018, se('Perkins', '1104C-44T', 4.4, '4-Cyl Turbo', 100, 'Diesel', '4-Speed Powershuttle'), ['MT 1335'], SOURCE_EPA_OEM),
    mdl('MT 1840', '18-Meter High-Reach Telehandlers', 'Heavy Equipment', TLH, 2008, 2026, se('Perkins / Deutz', 'TCD 3.6 L4', 3.6, '4-Cyl Turbo', 100, 'Diesel', '4-Speed Torque Converter'), [], SOURCE_EPA_OEM),
    mdl('MLT 625', 'Compact Ag/Industrial Telehandlers', 'Heavy Equipment', TLH, 2011, 2026, se('Kubota', 'V3307-CR-TE5', 3.3, '4-Cyl Turbo', 75, 'Diesel', 'Hydrostatic'), ['MLT 625-75 H'], SOURCE_EPA_OEM),
    mdl('MTA 8044', 'North American Construction Telehandlers', 'Heavy Equipment', TLH, 2008, 2024, se('Cummins / Deutz', 'QSB4.5 / TCD 3.6', 3.6, '4-Cyl Turbo', 120, 'Diesel', '4-Speed Powershift'), [], SOURCE_EPA_OEM),
    mdl('MTA 12055', '12,000-lb Heavy Telehandlers', 'Heavy Equipment', TLH, 2012, 2026, se('Cummins / Deutz', 'QSB4.5 / TCD 3.6 L4', 3.6, '4-Cyl Turbo', 120, 'Diesel', '4-Speed Powershift'), [], SOURCE_EPA_OEM),
    mdl('MRT 2550', 'Privilege Plus Rotating Telehandlers', 'Heavy Equipment', TLH, 2016, 2022, se('Mercedes-Benz', 'OM934LA', 5.1, '4-Cyl Turbo', 156, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
    mdl('2200R', 'Radial-Lift Skid Steers', 'Heavy Equipment', SSL, 2015, 2026, se('Yanmar', '4TNV98C', 3.3, '4-Cyl', 68, 'Diesel', '2-Speed Hydrostatic'), [], SOURCE_EPA_OEM),
    mdl('3200VT', 'Heavy Vertical-Lift Compact Track Loaders', 'Heavy Equipment', SSL, 2016, 2026, se('Deutz', 'TCD 3.6 L4', 3.6, '4-Cyl Turbo', 114, 'Diesel', '2-Speed High-Flow Hydrostatic'), ['2750VT'], SOURCE_EPA_OEM),
  ],
  skytrak: [
    mdl('5028', 'Classic SkyTrak Telehandlers', 'Heavy Equipment', TLH, 1978, 1994, se('John Deere', '4239D', 3.9, '4-Cyl', 72, 'Diesel', '3-Speed Shuttle'), [], SOURCE_EPA_OEM),
    mdl('8038', 'Classic Heavy Shooting-Boom Forklifts', 'Heavy Equipment', TLH, 1984, 1997, se('John Deere / Cummins', '4039T / 4BT3.9', 3.9, '4-Cyl Turbo', 85, 'Diesel', 'Powershift'), ['7038', '9038'], SOURCE_EPA_OEM),
    mdl('4266', 'Millennia Series Telehandlers', 'Heavy Equipment', TLH, 1997, 2003, se('Cummins', '4B3.9', 3.9, '4-Cyl', 80, 'Diesel', '3-Speed Powershift'), [], SOURCE_EPA_OEM),
    mdl('4270', 'Millennia Series Telehandlers', 'Heavy Equipment', TLH, 1997, 2004, se('Cummins', '4BT3.9', 3.9, '4-Cyl Turbo', 100, 'Diesel', '4-Speed Powershift'), [], SOURCE_EPA_OEM),
    mdl('4290', 'Millennia High-Reach Telehandlers', 'Heavy Equipment', TLH, 1998, 2004, se('Cummins', '4BT3.9', 3.9, '4-Cyl Turbo', 110, 'Diesel', '4-Speed Powershift'), [], SOURCE_EPA_OEM),
    mdl('3013', 'Ultra-Compact Jobsite Telehandlers', 'Heavy Equipment', TLH, 2004, 2026, se('Kubota', 'V1505 / D1305', 1.5, '3/4-Cyl', 25, 'Diesel', '4WD Hydrostatic'), [], SOURCE_EPA_OEM),
    mdl('10042 Legacy', 'Legacy Series 10,000-lb Telehandlers', 'Heavy Equipment', TLH, 2003, 2008, se('Cummins', '4BT3.9', 3.9, '4-Cyl Turbo', 110, 'Diesel', '4-Speed Powershift'), [], SOURCE_EPA_OEM),
    mdl('8042 Legacy', 'Legacy Series 8,000-lb Telehandlers', 'Heavy Equipment', TLH, 2002, 2008, se('Cummins', '4BT3.9', 3.9, '4-Cyl Turbo', 110, 'Diesel', '4-Speed Powershift'), [], SOURCE_EPA_OEM),
    mdl('6036 Legacy', 'Legacy Series 6,000-lb Telehandlers', 'Heavy Equipment', TLH, 2002, 2008, se('Cummins', '4B3.9 / 4BT3.9', 3.9, '4-Cyl Turbo', 95, 'Diesel', '4-Speed Powershift'), [], SOURCE_EPA_OEM),
    mdl('15054', 'Heavy-Lift 15,000-lb Telehandlers', 'Heavy Equipment', TLH, 2023, 2026, se('Deutz', 'TCD 3.6 L4', 3.6, '4-Cyl Turbo', 134, 'Diesel', '4-Speed Powershift'), [], SOURCE_EPA_OEM),
    mdl('9042', 'Legacy / Plus 9,000-lb Telehandlers', 'Heavy Equipment', TLH, 1999, 2006, se('Cummins', '4BT3.9', 3.9, '4-Cyl Turbo', 110, 'Diesel', '4-Speed Powershift'), [], SOURCE_EPA_OEM),
  ],
  grove_manitowoc: [
    mdl('RT528C', 'C-Series Rough Terrain Cranes', 'Heavy Equipment', CRN, 1985, 1998, se('Cummins', '6BT5.9', 5.9, '6-Cyl Turbo', 130, 'Diesel', '6-Speed Powershift')),
    mdl('RT745', 'Rough Terrain Cranes', 'Heavy Equipment', CRN, 1986, 1999, se('Cummins', '6CT8.3', 8.3, '6-Cyl Turbo', 190, 'Diesel', '6-Speed Powershift')),
    mdl('RT530E-2', 'E-Series 30-Ton Rough Terrain Cranes', 'Heavy Equipment', CRN, 2008, 2024, se('Cummins', 'QSB6.7', 6.7, '6-Cyl Turbo', 160, 'Diesel', '6-Speed Powershift')),
    mdl('RT770E', '70-Ton Rough Terrain Cranes', 'Heavy Equipment', CRN, 2014, 2024, se('Cummins', 'QSB6.7', 6.7, '6-Cyl Turbo', 240, 'Diesel', '6-Speed Powershift')),
    mdl('RT880E', '80-Ton Rough Terrain Cranes', 'Heavy Equipment', CRN, 2008, 2022, se('Cummins', 'QSB6.7', 6.7, '6-Cyl Turbo', 275, 'Diesel', '6-Speed Powershift')),
    mdl('RT9130E-2', '130-Ton Heavy Rough Terrain Cranes', 'Heavy Equipment', CRN, 2008, 2025, se('Cummins', 'QSC8.3 / QSL9', 8.9, '6-Cyl Turbo', 320, 'Diesel', '6-Speed Powershift')),
    mdl('GRT880', 'GRT 80-Ton Rough Terrain Cranes', 'Heavy Equipment', CRN, 2017, 2026, se('Cummins', 'B6.7', 6.7, '6-Cyl Turbo', 275, 'Diesel', 'Range-Shift Powershift'), [], SOURCE_EPA_OEM),
    mdl('GMK4100L', '4-Axle All-Terrain Mobile Cranes', 'Heavy Equipment', CRN, 2008, 2026, se('Mercedes-Benz', 'OM470LA', 10.7, '6-Cyl Turbo', 429, 'Diesel', 'ZF AS-Tronic / TraXon Automated'), ['GMK4100L-2'], SOURCE_EPA_OEM),
    mdl('Manitowoc 3900W', 'Classic Lattice-Boom Crawler Cranes', 'Heavy Equipment', CRN, 1970, 1990, se('Cummins', 'NT-855-C310', 14.0, '6-Cyl Turbo', 310, 'Diesel', 'VICON Torque Converter'), ['3900B']),
    mdl('Manitowoc 2250', '300-Ton Lattice-Boom Crawler Cranes', 'Heavy Equipment', CRN, 1998, 2022, se('Cummins', 'QSX15', 14.9, '6-Cyl Turbo', 450, 'Diesel', 'Closed-Loop Hydrostatic')),
  ],
  genie_jlg: [
    mdl('400S', 'JLG 40-ft Telescopic Boom Lifts', 'Site Support', ['Boom Lift'], 1998, 2026, [
      eng('Deutz', 'D2011 L03i / D2.9 L4', 2.9, '4-Cyl', 49, 'Diesel', '4WD Hydrostatic', 1998, 2026),
      eng('Ford / Kubota', 'MSG-425 / WG2503', 2.5, '4-Cyl', 61, 'Dual Fuel (Gas/LPG)', '4WD Hydrostatic', 2001, 2026),
    ], ['460SJ'], SOURCE_EPA_OEM),
    mdl('660SJ', 'JLG 66-ft Jib Telescopic Boom Lifts', 'Site Support', ['Boom Lift'], 1999, 2026, [
      eng('Deutz', 'D2.9 L4', 2.9, '4-Cyl', 67, 'Diesel', '4WD Hydrostatic', 1999, 2026),
      eng('Ford', 'MSG-425', 2.5, '4-Cyl', 75, 'Dual Fuel (Gas/LPG)', '4WD Hydrostatic', 2003, 2026),
    ], [], SOURCE_EPA_OEM),
    mdl('860SJ', 'JLG 86-ft Telescopic Boom Lifts', 'Site Support', ['Boom Lift'], 2000, 2026, [
      eng('Deutz', 'TD2.9 L4', 2.9, '4-Cyl Turbo', 67, 'Diesel', '4WD Hydrostatic', 2000, 2026),
      eng('Ford', 'MSG-425', 2.5, '4-Cyl', 75, 'Dual Fuel (Gas/LPG)', '4WD Hydrostatic', 2004, 2026),
    ], [], SOURCE_EPA_OEM),
    mdl('1200SJP', 'JLG Ultra Boom Telescopic Lifts', 'Site Support', ['Boom Lift'], 2002, 2026, se('Deutz', 'TD2.9 L4 / TCD 3.6', 2.9, '4-Cyl Turbo', 74, 'Diesel', '4WD Hydrostatic'), ['1350SJP'], SOURCE_EPA_OEM),
    mdl('2630ES', 'Electric Slab Scissor Lifts', 'Site Support', ['Scissor Lift'], 2003, 2026, se('JLG Electric', '24V DC Drive', 0.0, 'Electric Motor', 8, 'Electric', 'Electric Front-Wheel Drive'), [], SOURCE_EPA_OEM),
    mdl('3246ES', 'Electric Slab Scissor Lifts', 'Site Support', ['Scissor Lift'], 2003, 2026, se('JLG Electric', '24V DC Drive', 0.0, 'Electric Motor', 8, 'Electric', 'Electric Front-Wheel Drive'), [], SOURCE_EPA_OEM),
    mdl('3394RT', 'Rough-Terrain Scissor Lifts', 'Site Support', ['Scissor Lift'], 2004, 2026, se('Deutz / Kubota', 'D2.9 L4 / WG2503', 2.9, '4-Cyl', 49, 'Diesel', '4WD Hydrostatic'), [], SOURCE_EPA_OEM),
    mdl('G6-42A', 'JLG Compact/Mid Telehandlers', 'Heavy Equipment', TLH, 2006, 2018, se('John Deere / Deutz', '4045TF / TCD 3.6', 3.6, '4-Cyl Turbo', 99, 'Diesel', '4-Speed Powershift'), ['G5-18A'], SOURCE_EPA_OEM),
    mdl('G9-43A', 'JLG 9,000-lb Telehandlers', 'Heavy Equipment', TLH, 2006, 2018, se('Cummins', 'QSB4.5 / QSF3.8', 3.8, '4-Cyl Turbo', 110, 'Diesel', '4-Speed Powershift'), [], SOURCE_EPA_OEM),
    mdl('G12-55A', 'JLG 12,000-lb High-Reach Telehandlers', 'Heavy Equipment', TLH, 2006, 2018, se('Cummins', 'QSB4.5 / QSF3.8', 3.8, '4-Cyl Turbo', 130, 'Diesel', '4-Speed Powershift'), [], SOURCE_EPA_OEM),
    mdl('1255', 'JLG 12,000-lb Current Telehandlers', 'Heavy Equipment', TLH, 2017, 2026, se('Cummins', 'QSF3.8', 3.8, '4-Cyl Turbo', 130, 'Diesel', '4-Speed Powershift'), ['1644', '1732'], SOURCE_EPA_OEM),
  ],
  genie: [
    mdl('S-40', 'Classic Telescopic Boom Lifts', 'Site Support', ['Boom Lift'], 1995, 2019, [
      eng('Deutz', 'F3L1011 / D2011 L03i', 2.3, '3-Cyl Oil-Cooled', 48, 'Diesel', '4WD Hydrostatic', 1995, 2019),
      eng('Ford', 'LRG-425 / MSG-425', 2.5, '4-Cyl', 70, 'Dual Fuel (Gas/LPG)', '4WD Hydrostatic', 1996, 2019),
    ], ['S-45'], SOURCE_EPA_OEM),
    mdl('S-60', '60-ft Telescopic Boom Lifts', 'Site Support', ['Boom Lift'], 1994, 2020, [
      eng('Deutz', 'D2011 L03i / D2.9 L4', 2.9, '4-Cyl', 49, 'Diesel', '4WD Hydrostatic', 1994, 2020),
      eng('Perkins', '404D-22', 2.2, '4-Cyl', 51, 'Diesel', '4WD Hydrostatic', 2004, 2020),
    ], ['S-60X', 'S-60 XC'], SOURCE_EPA_OEM),
    mdl('S-60 J', 'Lightweight Jib Telescopic Boom Lifts', 'Site Support', ['Boom Lift'], 2020, 2026, se('Kubota', 'D1105 / D1803', 1.1, '3-Cyl', 24.8, 'Diesel', '4WD Hydrostatic'), ['S-80 J'], SOURCE_EPA_OEM),
    mdl('S-80', '80-ft Telescopic Boom Lifts', 'Site Support', ['Boom Lift'], 1997, 2019, se('Deutz / Perkins', 'TD2011 L04i / 804D-33', 2.9, '4-Cyl Turbo', 74, 'Diesel', '4WD Hydrostatic'), ['S-80X'], SOURCE_EPA_OEM),
    mdl('SX-135 XC', 'Super Boom Telescopic Lifts', 'Site Support', ['Boom Lift'], 2017, 2026, se('Deutz / Perkins', 'TD2.9 L4 / 854F-E34T', 2.9, '4-Cyl Turbo', 74, 'Diesel', '4WD X-Chassis Hydrostatic'), ['SX-105 XC', 'SX-125 XC'], SOURCE_EPA_OEM),
    mdl('Z-34/22 IC', 'Compact Articulating Boom Lifts', 'Site Support', ['Boom Lift'], 1994, 2024, se('Kubota', 'D1105 / DF972', 1.1, '3-Cyl', 24.8, 'Diesel', '4WD Hydrostatic'), ['Z-34/22N'], SOURCE_EPA_OEM),
    mdl('Z-45 XC', 'Xtra Capacity Articulating Boom Lifts', 'Site Support', ['Boom Lift'], 2018, 2026, se('Deutz', 'D2.9 L4', 2.9, '4-Cyl', 49, 'Diesel', '4WD Hydrostatic'), [], SOURCE_EPA_OEM),
    mdl('Z-60/34', '60-ft Articulating Boom Lifts', 'Site Support', ['Boom Lift'], 1996, 2016, se('Deutz / Ford', 'D2011 L03i / MSG-425', 2.9, '4-Cyl', 49, 'Diesel', '4WD Hydrostatic'), ['Z-60/37 DC'], SOURCE_EPA_OEM),
    mdl('Z-80/60', '80-ft Articulating Boom Lifts', 'Site Support', ['Boom Lift'], 2003, 2026, se('Deutz / Perkins', 'TD2.9 L4', 2.9, '4-Cyl Turbo', 74, 'Diesel', '4WD Hydrostatic'), [], SOURCE_EPA_OEM),
    mdl('GS-2632', 'Slab Electric Scissor Lifts', 'Site Support', ['Scissor Lift'], 1998, 2026, se('Genie Electric', '24V DC E-Drive', 0.0, 'Electric Motor', 8, 'Electric', 'Electric Wheel Drive'), ['GS-3246'], SOURCE_EPA_OEM),
    mdl('GS-3369 RT', 'Compact Rough-Terrain Scissor Lifts', 'Site Support', ['Scissor Lift'], 2011, 2026, se('Kubota', 'D1105', 1.1, '3-Cyl', 24.8, 'Diesel', '4WD Hydrostatic'), ['GS-4069 RT'], SOURCE_EPA_OEM),
    mdl('GTH-1256', '12,000-lb Heavy Telehandlers', 'Heavy Equipment', TLH, 2016, 2026, se('Deutz', 'TCD 3.6 L4', 3.6, '4-Cyl Turbo', 121, 'Diesel', '4-Speed Powershift'), ['GTH-1544'], SOURCE_EPA_OEM),
  ],
  massey_ferguson: [
    mdl('MF 20', 'Classic Industrial Loader Tractors', 'Heavy Equipment', LDR, 1970, 1982, se('Perkins', 'AD3.152', 2.5, '3-Cyl', 42, 'Diesel', 'Manual / Shuttle'), ['MF 20C'], SOURCE_EPA_OEM),
    mdl('MF 30', 'Industrial Tractor-Loader-Backhoes', 'Heavy Equipment', BKH, 1970, 1985, se('Perkins', 'AD4.203', 3.3, '4-Cyl', 61, 'Diesel', 'Instant Reverse Torque Converter'), ['MF 30B', 'MF 30E'], SOURCE_EPA_OEM),
    mdl('MF 40', 'Industrial Tractor-Loader-Backhoes', 'Heavy Equipment', BKH, 1970, 1988, se('Perkins', 'AD3.152 / A4.236', 2.5, '3-Cyl', 50, 'Diesel', 'Instant Reverse Shuttle'), ['MF 40B', 'MF 40E'], SOURCE_EPA_OEM),
    mdl('MF 50B', 'Industrial Backhoe Loaders', 'Heavy Equipment', BKH, 1974, 1983, se('Perkins', 'A4.212 / A4.236', 3.9, '4-Cyl', 68, 'Diesel', 'Torque Converter Shuttle')),
    mdl('MF 50E', 'Powershuttle Backhoe Loaders', 'Heavy Equipment', BKH, 1983, 1990, se('Perkins', 'A4.236', 3.9, '4-Cyl', 70, 'Diesel', '4-Speed Powershuttle'), ['MF 50D']),
    mdl('MF 50H', 'Series S Backhoe Loaders', 'Heavy Equipment', BKH, 1985, 1994, se('Perkins', 'A4.236 / 1004-4', 3.9, '4-Cyl', 74, 'Diesel', '4-Speed Powershuttle')),
    mdl('MF 50HX', 'Series S 4WD Backhoe Loaders', 'Heavy Equipment', BKH, 1986, 1996, se('Perkins', '1004-4T', 4.0, '4-Cyl Turbo', 84, 'Diesel', '4-Speed Powershuttle')),
    mdl('MF 60H', 'Heavy Industrial Backhoe Loaders', 'Heavy Equipment', BKH, 1986, 1994, se('Perkins', '1004-4T', 4.0, '4-Cyl Turbo', 86, 'Diesel', '4-Speed Powershuttle')),
    mdl('MF 70', 'Integrated Heavy Backhoe Loaders', 'Heavy Equipment', BKH, 1971, 1978, se('Perkins', 'A4.318', 5.2, '4-Cyl', 84, 'Diesel', 'Full Powershift')),
    mdl('MF 80', 'Integrated Heavy Backhoe Loaders', 'Heavy Equipment', BKH, 1971, 1979, se('Perkins', 'A6.354', 5.8, '6-Cyl', 100, 'Diesel', 'Full Powershift')),
    mdl('MF 44C', 'Articulated Wheel Loaders', 'Heavy Equipment', LDR, 1976, 1986, se('Perkins', '6.354', 5.8, '6-Cyl', 113, 'Diesel', 'Powershift')),
    mdl('MF 66C', 'Heavy Articulated Wheel Loaders', 'Heavy Equipment', LDR, 1976, 1987, se('Hanomag / Perkins', 'D963', 9.5, '6-Cyl Turbo', 180, 'Diesel', 'Powershift')),
    mdl('MF 860', '90s Backhoe Loaders', 'Heavy Equipment', BKH, 1992, 2001, se('Perkins', '1004.4T', 4.0, '4-Cyl Turbo', 90, 'Diesel', 'Powershuttle'), ['MF 965'], SOURCE_EPA_OEM),
    mdl('MF 4710', 'Global Series Utility Loader Tractors', 'Heavy Equipment', LDR, 2016, 2026, se('AGCO Power', '33AWFC', 3.3, '3-Cyl Turbo', 100, 'Diesel', '12x12 Dyna-2 Power-Shuttle'), [], SOURCE_EPA_OEM),
    mdl('MF 5711', 'Global Heavy Utility Loader Tractors', 'Heavy Equipment', LDR, 2017, 2026, se('AGCO Power', '44AWFC', 4.4, '4-Cyl Turbo', 110, 'Diesel', 'Dyna-4 Semi-Powershift'), ['MF 5713'], SOURCE_EPA_OEM),
  ],
  vermeer: [
    mdl('M455', 'Classic Rubber-Tire Trenchers', 'Heavy Equipment', DRL, 1972, 1988, se('Detroit Diesel / Ford', '3-53 / 192D', 2.6, '3-Cyl', 58, 'Diesel', 'Hydrostatic'), ['M 455 / M455A']),
    mdl('T455', 'Commander Hydrostatic Track Trenchers', 'Heavy Equipment', DRL, 1992, 2014, se('John Deere', '4045TF / 6068TF', 4.5, '4-Cyl Turbo', 125, 'Diesel', 'Hydrostatic Crawler')),
    mdl('T555', 'Commander III Pipeline Rock Trenchers', 'Heavy Equipment', DRL, 1995, 2026, se('John Deere', '6068HFC', 6.8, '6-Cyl Turbo', 185, 'Diesel', 'Hydrostatic Crawler')),
    mdl('T755', 'Commander III Heavy Pipeline Trenchers', 'Heavy Equipment', DRL, 1996, 2026, se('Caterpillar', 'C9 / C9.3B', 9.3, '6-Cyl Turbo', 275, 'Diesel', 'Hydrostatic Crawler')),
    mdl('T855', 'Commander III Mainline Pipeline Trenchers', 'Heavy Equipment', DRL, 1998, 2026, se('Caterpillar', 'C13 ACERT', 12.5, '6-Cyl Turbo', 350, 'Diesel', 'Hydrostatic Crawler'), ['T955', 'T1255']),
    mdl('RTX450', 'Ride-On Utility Quad-Track Trenchers', 'Heavy Equipment', DRL, 2008, 2026, se('Deutz / Kubota', 'D2.9 L4 / V2403', 2.4, '4-Cyl', 49, 'Diesel', 'Hydrostatic'), [], SOURCE_EPA_OEM),
    mdl('RTX1250', 'Heavy Ride-On Rockwheel & Plow Tractors', 'Heavy Equipment', DRL, 2012, 2026, se('Cummins', 'QSB4.5 / B4.5', 4.5, '4-Cyl Turbo', 127, 'Diesel', 'Hydrostatic Quad-Track'), ['RTX750'], SOURCE_EPA_OEM),
    mdl('D7x11 Series II', 'Compact Utility Directional Drills', 'Heavy Equipment', DRL, 2001, 2018, se('Kubota', 'D1105 / V1505', 1.5, '4-Cyl', 35, 'Diesel', 'Rack & Pinion Hydrostatic'), ['D8x12'], SOURCE_EPA_OEM),
    mdl('D23x30 S3', 'Quiet-Pack Horizontal Directional Drills', 'Heavy Equipment', DRL, 2015, 2026, se('Deutz', 'TD2.9 L4 / TCD 3.6', 3.6, '4-Cyl Turbo', 100, 'Diesel', 'Rack & Pinion Hydrostatic'), [], SOURCE_EPA_OEM),
    mdl('D24x40 Series II', 'Navigator Industry-Standard HDD', 'Heavy Equipment', DRL, 2005, 2015, se('John Deere', '4045TF275', 4.5, '4-Cyl Turbo', 125, 'Diesel', 'Rack & Pinion Hydrostatic'), [], SOURCE_EPA_OEM),
    mdl('D36x50 Series II', 'Navigator Mid-Size Directional Drills', 'Heavy Equipment', DRL, 2004, 2016, se('John Deere', '4045HF275', 4.5, '4-Cyl Turbo', 140, 'Diesel', 'Rack & Pinion Hydrostatic'), ['D36x50'], SOURCE_EPA_OEM),
    mdl('D60x90 S3', 'Pipeline Crossing Directional Drills', 'Heavy Equipment', DRL, 2015, 2026, se('John Deere / Cat', '6068HFC / C7.1', 6.8, '6-Cyl Turbo', 225, 'Diesel', 'Rack & Pinion Hydrostatic'), [], SOURCE_EPA_OEM),
    mdl('D220x300 S3', 'Maxi-Rig Pipeline River-Crossing Drills', 'Heavy Equipment', DRL, 2008, 2026, se('Caterpillar', 'C13 / C15 ACERT', 12.5, '6-Cyl Turbo', 415, 'Diesel', 'Rack & Pinion Hydrostatic'), ['D220x300'], SOURCE_EPA_OEM),
    mdl('CTX160', 'Vertical-Lift Mini Skid Steers', 'Heavy Equipment', SSL, 2019, 2026, se('Kohler', 'KDI 1903TCR', 1.9, '3-Cyl Turbo', 40, 'Diesel', 'Hydrostatic Track'), ['CTX100'], SOURCE_EPA_OEM),
  ],
  ditch_witch: [
    mdl('V30', 'Classic 30-HP Ride-On Utility Trenchers', 'Heavy Equipment', DRL, 1970, 1988, se('Wisconsin', 'VH4D', 1.8, 'V4 Air-Cooled', 30, 'Gasoline', '4WD Mechanical / Hydraulic'), ['J20']),
    mdl('R65', 'Classic 65-HP Ride-On Trenchers', 'Heavy Equipment', DRL, 1971, 1989, se('Wisconsin / Deutz', 'F4L912', 3.8, '4-Cyl Air-Cooled', 65, 'Diesel', 'Hydrostatic')),
    mdl('3500', '3000-Series Ride-On Trenchers', 'Heavy Equipment', DRL, 1988, 2002, se('Deutz', 'F3L1011', 2.0, '3-Cyl Oil-Cooled', 41, 'Diesel', 'Hydrostatic'), ['2310']),
    mdl('3700', 'Ride-On Utility Trenchers & Plows', 'Heavy Equipment', DRL, 1995, 2014, se('Deutz', 'D2011L03', 2.3, '3-Cyl', 43, 'Diesel', '4WD Hydrostatic')),
    mdl('RT80', 'Heavy Ride-On Trenchers & Vibratory Plows', 'Heavy Equipment', DRL, 2006, 2026, se('Deutz', 'TD 3.6 L4', 3.6, '4-Cyl Turbo', 74, 'Diesel', 'Hydrostatic Quad-Track / Tire'), ['RT55'], SOURCE_EPA_OEM),
    mdl('RT120', '120-HP Oilfield Lease & Pipeline Trenchers', 'Heavy Equipment', DRL, 2008, 2026, se('Cummins / Deutz', 'QSB4.5 / TCD 3.6 L4', 3.6, '4-Cyl Turbo', 121, 'Diesel', 'Hydrostatic Quad-Track'), ['RT125'], SOURCE_EPA_OEM),
    mdl('JT920', 'Classic Compact Jet Trac Directional Drills', 'Heavy Equipment', DRL, 1997, 2009, se('Kubota', 'V1505 / V2203', 2.2, '4-Cyl', 42, 'Diesel', 'Rack & Pinion Hydrostatic'), ['JT922'], SOURCE_EPA_OEM),
    mdl('JT1720', 'Mid-Compact Directional Drills', 'Heavy Equipment', DRL, 1998, 2008, se('John Deere', '4045D', 4.5, '4-Cyl', 80, 'Diesel', 'Rack & Pinion Hydrostatic'), [], SOURCE_EPA_OEM),
    mdl('JT2020 Mach 1', 'Mach 1 Horizontal Directional Drills', 'Heavy Equipment', DRL, 2002, 2015, se('Cummins / John Deere', 'B3.3T / 4045TF', 3.3, '4-Cyl Turbo', 85, 'Diesel', 'Rack & Pinion Hydrostatic'), [], SOURCE_EPA_OEM),
    mdl('JT24', 'Horizontal Directional Drills', 'Heavy Equipment', DRL, 2018, 2026, se('Cummins', 'QSF2.8 / B3.3', 2.8, '4-Cyl Turbo', 101, 'Diesel', 'Rack & Pinion Hydrostatic'), [], SOURCE_EPA_OEM),
    mdl('JT30', 'All-Around Mid-Size Directional Drills', 'Heavy Equipment', DRL, 2008, 2026, se('Cummins', 'QSB4.5', 4.5, '4-Cyl Turbo', 160, 'Diesel', 'Rack & Pinion Hydrostatic'), ['JT3020'], SOURCE_EPA_OEM),
    mdl('AT30', 'All-Terrain Rock Directional Drills', 'Heavy Equipment', DRL, 2008, 2026, se('Cummins', 'QSB4.5', 4.5, '4-Cyl Turbo', 155, 'Diesel', 'Dual-Pipe Rock Drilling Drive'), ['AT32'], SOURCE_EPA_OEM),
    mdl('AT40', 'All-Terrain Rock Directional Drills', 'Heavy Equipment', DRL, 2012, 2026, se('Cummins', 'QSB4.5 / B4.5', 4.5, '4-Cyl Turbo', 160, 'Diesel', 'Dual-Pipe Rock Drilling Drive'), ['AT60', 'AT120'], SOURCE_EPA_OEM),
    mdl('SK800', 'Stand-On Mini Skid Steers', 'Heavy Equipment', SSL, 2015, 2026, se('Kubota / Yanmar', 'D1105 / 3TNV80F', 1.1, '3-Cyl', 24.8, 'Diesel', 'Hydrostatic Track'), [], SOURCE_EPA_OEM),
    mdl('SK1550', 'High-Capacity Stand-On Skid Steers', 'Heavy Equipment', SSL, 2016, 2026, se('Yanmar', '4TNV86CT', 2.1, '4-Cyl Turbo', 44, 'Diesel', 'Hydrostatic Track'), ['SK3000'], SOURCE_EPA_OEM),
  ],
  bomag: [
    mdl('BW 65S', 'Classic Walk-Behind Double-Drum Rollers', 'Heavy Equipment', CMP, 1970, 1998, se('Hatz', 'E79 / 1D41S', 0.4, '1-Cyl Air-Cooled', 8, 'Diesel', 'Mechanical / Hydrostatic'), ['BW 75S']),
    mdl('BW 90 AD-5', 'Sub-2-Ton Tandem Asphalt Rollers', 'Heavy Equipment', CMP, 2004, 2026, se('Kubota', 'D902', 0.9, '3-Cyl', 20.2, 'Diesel', 'Hydrostatic'), ['BW 100 AD-5'], SOURCE_EPA_OEM),
    mdl('BW 138 AD-5', '4.5-Ton Tandem Vibratory Rollers', 'Heavy Equipment', CMP, 2005, 2026, se('Kubota', 'V2203 / V2403', 2.4, '4-Cyl', 45, 'Diesel', 'Hydrostatic'), [], SOURCE_EPA_OEM),
    mdl('BW 145 D-5', '5-Ton Single-Drum Soil Compactors', 'Heavy Equipment', CMP, 2006, 2026, se('Kubota', 'V3307-CR-T', 3.3, '4-Cyl Turbo', 74, 'Diesel', 'Hydrostatic'), ['BW 145 PD-5'], SOURCE_EPA_OEM),
    mdl('BW 174 AP', 'Pivot-Steer Tandem Asphalt Rollers', 'Heavy Equipment', CMP, 2006, 2026, se('Kubota / Deutz', 'V3800 / TCD 3.6', 3.8, '4-Cyl Turbo', 99, 'Diesel', 'Hydrostatic'), [], SOURCE_EPA_OEM),
    mdl('BW 190 AD-5', '12-Ton Heavy Highway Asphalt Rollers', 'Heavy Equipment', CMP, 2004, 2026, se('Deutz', 'TCD 3.6 L4 / TCD 4.1', 4.1, '4-Cyl Turbo', 134, 'Diesel', 'Hydrostatic'), ['BW 206 AD-5'], SOURCE_EPA_OEM),
    mdl('BW 211 D-40', 'Tier 3 / 4i 11-Ton Soil Compactors', 'Heavy Equipment', CMP, 2004, 2016, se('Deutz', 'BF4M2012C', 4.0, '4-Cyl Turbo', 131, 'Diesel', 'Hydrostatic'), [], SOURCE_EPA_OEM),
    mdl('BW 213 D-3', '13-Ton Vibratory Soil Compactors', 'Heavy Equipment', CMP, 1996, 2006, se('Deutz', 'BF4M1013EC', 4.8, '4-Cyl Turbo', 145, 'Diesel', 'Hydrostatic'), ['BW 213 PD-3'], SOURCE_EPA_OEM),
    mdl('BW 213 D-5', '13-Ton Tier 4F Soil Compactors', 'Heavy Equipment', CMP, 2014, 2026, se('Deutz', 'TCD 3.6 L4', 3.6, '4-Cyl Turbo', 127, 'Diesel', 'Hydrostatic'), [], SOURCE_EPA_OEM),
    mdl('BW 216 D-5', '16-Ton Heavy Soil Compactors', 'Heavy Equipment', CMP, 2006, 2026, se('Deutz', 'TCD 4.1 L4', 4.1, '4-Cyl Turbo', 154, 'Diesel', 'Dual-Pump Hydrostatic'), ['BW 219 DH-5'], SOURCE_EPA_OEM),
    mdl('BW 24 RH', 'Pneumatic-Tired Asphalt Compactors', 'Heavy Equipment', CMP, 2008, 2026, se('Kubota / Deutz', 'V3307 / TCD 3.6', 3.6, '4-Cyl Turbo', 99, 'Diesel', 'Hydrostatic'), ['BW 11 RH-5'], SOURCE_EPA_OEM),
    mdl('BC 473 RB', 'Soil & Landfill Refuse Compactors', 'Heavy Equipment', CMP, 2008, 2026, se('Mercedes-Benz / MTU', 'OM936LA', 7.7, '6-Cyl Turbo', 320, 'Diesel', '4-Wheel Hydrostatic'), [], SOURCE_EPA_OEM),
  ],
  ingersoll_rand: [
    mdl('XP185WJD', '200-PSI High-Pressure Towable Compressors', 'Site Support', ['Air Compressor'], 1994, 2026, [
      eng('John Deere', '4024TF / 4045D', 2.4, '4-Cyl Turbo', 66, 'Diesel', 'Direct Rotary-Screw Airend', 1994, 2016),
      eng('Doosan', 'D24 Tier 4F', 2.4, '4-Cyl Turbo', 67, 'Diesel', 'Direct Rotary-Screw Airend', 2014, 2026),
    ], [], SOURCE_EPA_OEM),
    mdl('P250WD', '250-CFM Portable Air Compressors', 'Site Support', ['Air Compressor'], 1978, 2018, se('Deutz / John Deere', 'F4L912 / 4045TF', 4.5, '4-Cyl Turbo', 80, 'Diesel', 'Rotary-Screw Airend'), ['P260WYM'], SOURCE_EPA_OEM),
    mdl('HP450WCU', 'Mid-Size High-Pressure Air Compressors', 'Site Support', ['Air Compressor'], 1996, 2026, se('Cummins', 'QSB4.5 / B4.5', 4.5, '4-Cyl Turbo', 155, 'Diesel', 'Rotary-Screw Airend'), ['P425WCU'], SOURCE_EPA_OEM),
    mdl('XP825WCU', '825-CFM Pipeline & Sandblast Compressors', 'Site Support', ['Air Compressor'], 1992, 2026, se('Cummins', 'L10 / QSL9', 8.9, '6-Cyl Turbo', 300, 'Diesel', 'Two-Stage Airend'), [], SOURCE_EPA_OEM),
    mdl('XHP900WCAT', '350-PSI Drilling & Pipeline Test Compressors', 'Site Support', ['Air Compressor'], 1992, 2024, se('Caterpillar', '3406C / C13 / C15 ACERT', 12.5, '6-Cyl Turbo', 440, 'Diesel', 'Two-Stage High-Pressure Airend'), ['XHP1070WCAT', 'XHP1170WCU'], SOURCE_EPA_OEM),
    mdl('SP-54', 'Classic Vibratory Single-Drum Rollers', 'Heavy Equipment', CMP, 1970, 1988, se('Detroit Diesel', '3-53 / 4-53', 3.5, '4-Cyl 2-Stroke', 105, 'Diesel', 'Hydrostatic'), ['SP-42']),
    mdl('SD-45D', 'Compact Single-Drum Soil Compactors', 'Heavy Equipment', CMP, 1995, 2008, se('Cummins', 'B3.3', 3.3, '4-Cyl', 60, 'Diesel', 'Hydrostatic'), []),
    mdl('SD-70D', '7-Ton Single-Drum Soil Compactors', 'Heavy Equipment', CMP, 1994, 2008, se('Cummins', '4BT3.9', 3.9, '4-Cyl Turbo', 95, 'Diesel', 'Hydrostatic'), []),
    mdl('SD-116DX', '11-Ton Heavy Soil Compactors', 'Heavy Equipment', CMP, 1998, 2008, se('Cummins', 'QSB4.5 / QSB5.9', 5.9, '6-Cyl Turbo', 148, 'Diesel', 'Dual-Range Hydrostatic'), ['SD-105DX']),
    mdl('DD-24', 'Compact Double-Drum Asphalt Rollers', 'Heavy Equipment', CMP, 1994, 2008, se('Kubota', 'D1703', 1.7, '3-Cyl', 32.5, 'Diesel', 'Hydrostatic'), ['DD-28HF']),
    mdl('DD-110', 'Heavy Highway Tandem Asphalt Rollers', 'Heavy Equipment', CMP, 1994, 2008, se('Cummins', '4BT3.9 / QSB4.5', 4.5, '4-Cyl Turbo', 125, 'Diesel', 'Hydrostatic'), ['DD-130']),
    mdl('VR-642', 'Rough-Terrain Telehandlers', 'Heavy Equipment', TLH, 1997, 2008, se('Cummins', '4BT3.9 / QSB4.5', 4.5, '4-Cyl Turbo', 100, 'Diesel', '4-Speed Powershift'), [], SOURCE_EPA_OEM),
    mdl('VR-843', '8,000-lb Rough-Terrain Telehandlers', 'Heavy Equipment', TLH, 1998, 2008, se('Cummins', '4BT3.9 / QSB4.5', 4.5, '4-Cyl Turbo', 110, 'Diesel', '4-Speed Powershift'), [], SOURCE_EPA_OEM),
    mdl('CM-780D', 'Surface Crawler Blasthole Drills', 'Heavy Equipment', DRL, 1992, 2008, se('Caterpillar / Cummins', 'C11 / QSL9', 8.9, '6-Cyl Turbo', 325, 'Diesel', 'Down-The-Hole Crawler'), []),
    mdl('L8', '8kW Extended-Output Jobsite Light Towers', 'Site Support', ['Light Tower'], 2000, 2024, se('Kubota', 'D1105', 1.1, '3-Cyl', 15.4, 'Diesel', '8kW 1800 RPM Brushless Generator'), [], SOURCE_EPA_OEM),
  ],
  western_star: [
    mdl('3800', 'Medium/Heavy Heritage Conventional', 'Transport & Hauling', TRK_HEAVY, 1988, 2001, [
      eng('Caterpillar', '3116 / 3126B / 3306', 7.2, '6-Cyl Turbo', 300, 'Diesel', 'Eaton Fuller 8LL / Allison Automatic', 1988, 2001),
      eng('Cummins', '6CT8.3 / L10 / M11', 8.3, '6-Cyl Turbo', 300, 'Diesel', 'Fuller 9/10-Speed Manual', 1988, 2001),
    ], ['3700'], SOURCE_VPIC_EPA_OEM),
    mdl('4900EX', 'Extended-Hood Heavy Highway & Oilfield Tractor', 'Transport & Hauling', TRK_HEAVY, 2002, 2023, [
      eng('Caterpillar', 'C15 ACERT', 15.2, '6-Cyl Twin-Turbo', 550, 'Diesel', 'Eaton Fuller 18-Speed Manual', 2002, 2009),
      eng('Detroit Diesel', 'DD15 / DD16', 15.6, '6-Cyl Turbo', 600, 'Diesel', 'Eaton Fuller 18-Speed Manual', 2009, 2023),
      eng('Cummins', 'ISX15 / X15', 14.9, '6-Cyl Turbo', 565, 'Diesel', 'Eaton Fuller 18-Speed Manual', 2002, 2023),
    ], [], SOURCE_VPIC_EPA_OEM),
    mdl('4900TS', 'Twin-Steer Oilfield Bed, Crane & Vacuum Chassis', 'Transport & Hauling', TRK_HEAVY, 2004, 2023, [
      eng('Detroit Diesel', 'DD16', 15.6, '6-Cyl Turbo', 600, 'Diesel', 'Eaton Fuller 18-Speed / Allison 4700 RDS', 2010, 2023),
      eng('Cummins', 'ISX15 / X15', 14.9, '6-Cyl Turbo', 565, 'Diesel', 'Eaton Fuller 18-Speed + Aux Box', 2004, 2023),
    ], ['6900TS'], SOURCE_VPIC_EPA_OEM),
    mdl('5700XE', 'Extreme-Efficiency Aerodynamic Highway Tractor', 'Transport & Hauling', TRK_HWY, 2015, 2022, [
      eng('Detroit Diesel', 'DD15', 14.8, '6-Cyl Turbo', 505, 'Diesel', 'Detroit DT12 12-Speed Automated', 2015, 2022),
      eng('Detroit Diesel', 'DD13 / DD16', 12.8, '6-Cyl Turbo', 470, 'Diesel', 'Detroit DT12 / Eaton 13/18-Speed', 2015, 2022),
    ], [], SOURCE_VPIC_EPA_OEM),
    mdl('48X', 'X-Series Western Canadian / Oilfield Vocational Chassis', 'Transport & Hauling', TRK_HEAVY, 2023, 2026, [
      eng('Detroit Diesel', 'DD13 Gen 5 / DD15 Gen 5', 14.8, '6-Cyl Turbo', 505, 'Diesel', 'Detroit DT12-V / Eaton Fuller 18-Speed', 2023, 2026),
      eng('Cummins', 'X15', 14.9, '6-Cyl Turbo', 565, 'Diesel', 'Eaton Fuller 18-Speed Manual', 2023, 2026),
    ], [], SOURCE_VPIC_EPA_OEM),
  ],
  mack: [
    mdl('MH Ultra-Liner', 'Cabover COE Highway Tractor', 'Transport & Hauling', TRK_HWY, 1983, 1994, [
      eng('Mack', 'E6-350 Econodyne', 11.0, '6-Cyl Turbo', 350, 'Diesel', 'Mack T2090 / T2100 Manual', 1983, 1994),
      eng('Mack', 'E9-440 / E9-500 V8', 16.4, 'V8 Turbo', 500, 'Diesel', 'Mack T2180 12-Speed Manual', 1983, 1994),
    ], ['MH613', 'F700'], SOURCE_VPIC_EPA_OEM),
    mdl('CL700', 'CL713 Elite Heavy-Haul & Logging Conventional', 'Transport & Hauling', TRK_HEAVY, 1991, 2007, [
      eng('Mack', 'E9-500 V8 / E7-460', 12.0, '6-Cyl / V8 Turbo', 460, 'Diesel', 'Eaton Fuller 18-Speed Manual', 1991, 2007),
      eng('Cummins', 'N14 / ISX15', 14.9, '6-Cyl Turbo', 525, 'Diesel', 'Eaton Fuller 18-Speed Manual', 1993, 2007),
    ], ['CL713', 'CL733'], SOURCE_VPIC_EPA_OEM),
    mdl('RB690S', 'Set-Back Axle Heavy Construction Chassis', 'Transport & Hauling', TRK_HEAVY, 1989, 2005, [
      eng('Mack', 'E6-350 / E7-350 / E7-400', 12.0, '6-Cyl Turbo', 350, 'Diesel', 'Mack Maxitorque T2080 / Fuller 8LL', 1989, 2005),
      eng('Mack', 'EM7-300', 12.0, '6-Cyl Turbo', 300, 'Diesel', 'Allison HD4560 Automatic', 1991, 2005),
    ], ['RB'], SOURCE_VPIC_EPA_OEM),
    mdl('TerraPro', 'Cabover Pump, Vacuum & Refuse Vocational Chassis', 'Transport & Hauling', TRK_MED, 2007, 2026, [
      eng('Mack', 'MP7', 10.8, '6-Cyl Turbo', 395, 'Diesel', 'Allison 4500 RDS 6-Speed Automatic', 2007, 2026),
      eng('Cummins', 'ISL-G / L9N Near-Zero', 8.9, '6-Cyl Turbo', 320, 'Natural Gas', 'Allison 4500 RDS Automatic', 2010, 2026),
    ], ['MRU613', 'TE64'], SOURCE_VPIC_EPA_OEM),
    mdl('MD6', 'Class 6 Non-CDL Service, Water & Flatbed Chassis', 'Transport & Hauling', TRK_MED, 2020, 2026, [
      eng('Cummins', 'B6.7 220 / 250', 6.7, '6-Cyl Turbo', 250, 'Diesel', 'Allison 2500 HS/RDS 6-Speed Automatic', 2020, 2026),
      eng('Cummins', 'B6.7 300 High-Output', 6.7, '6-Cyl Turbo', 300, 'Diesel', 'Allison 2500 RDS Automatic', 2020, 2026),
    ], [], SOURCE_VPIC_EPA_OEM),
  ],
  freightliner: [
    mdl('FLD112', 'Regional & Vocational Set-Back Conventional', 'Transport & Hauling', TRK_HEAVY, 1989, 2005, [
      eng('Cummins', 'L10 / M11 / ISM', 10.8, '6-Cyl Turbo', 370, 'Diesel', 'Eaton Fuller 8LL / 10-Speed Manual', 1989, 2005),
      eng('Caterpillar', '3306 / C10 / C12', 12.0, '6-Cyl Turbo', 380, 'Diesel', 'Eaton Fuller 10-Speed Manual', 1991, 2005),
    ], [], SOURCE_VPIC_EPA_OEM),
    mdl('M2 112', 'Heavy Business Class Tanker, Vacuum & Roll-Off Truck', 'Transport & Hauling', TRK_HEAVY, 2004, 2026, [
      eng('Detroit Diesel', 'DD13', 12.8, '6-Cyl Turbo', 450, 'Diesel', 'Allison 4500 RDS / Eaton 10-Speed Manual', 2010, 2026),
      eng('Cummins', 'ISL9 / L9', 8.9, '6-Cyl Turbo', 380, 'Diesel', 'Allison 3000 / 3500 RDS Automatic', 2007, 2026),
      eng('Mercedes-Benz / Cat', 'MBE 4000 / C11 / C13', 12.8, '6-Cyl Turbo', 410, 'Diesel', 'Allison 4500 RDS / Eaton 8LL', 2004, 2009),
    ], ['M2 112 Plus'], SOURCE_VPIC_EPA_OEM),
    mdl('108SD', 'Medium/Heavy Vocational Water, Crane & Dump Truck', 'Transport & Hauling', TRK_MED, 2012, 2026, [
      eng('Cummins', 'ISB6.7 / B6.7', 6.7, '6-Cyl Turbo', 325, 'Diesel', 'Allison 3000 RDS Automatic', 2012, 2026),
      eng('Cummins', 'ISL9 / L9', 8.9, '6-Cyl Turbo', 380, 'Diesel', 'Allison 3000 / 3500 RDS / Eaton 8LL', 2012, 2026),
    ], ['108SD Plus'], SOURCE_VPIC_EPA_OEM),
    mdl('Coronado SD', 'Severe-Duty Vocational & Heavy-Haul Tractor', 'Transport & Hauling', TRK_HEAVY, 2010, 2016, [
      eng('Detroit Diesel', 'DD15 / DD16', 15.6, '6-Cyl Turbo', 600, 'Diesel', 'Eaton Fuller 18-Speed Manual', 2010, 2016),
      eng('Cummins', 'ISX15', 14.9, '6-Cyl Turbo', 550, 'Diesel', 'Eaton Fuller 18-Speed Manual', 2010, 2016),
    ], [], SOURCE_VPIC_EPA_OEM),
    mdl('eCascadia', 'Battery-Electric Class 8 Regional Highway Tractor', 'Transport & Hauling', TRK_HWY, 2022, 2026, [
      eng('Detroit ePowertrain', 'Dual eAxle 438 kWh', 0.0, 'Tandem Electric', 470, 'Electric', '2-Speed Integrated Detroit eAxle', 2022, 2026),
      eng('Detroit ePowertrain', 'Single eAxle 291 kWh', 0.0, 'Single Electric', 320, 'Electric', '2-Speed Integrated Detroit eAxle', 2022, 2026),
    ], [], SOURCE_VPIC_EPA_OEM),
  ],
  international: [
    mdl('4700', 'Medium-Duty Mechanics, Welding & Flatbed Chassis', 'Transport & Hauling', TRK_MED, 1989, 2002, [
      eng('International', 'DT360 / T444E 7.3L V8', 7.3, 'V8 Turbo', 210, 'Diesel', 'Allison AT545 / Spicer 5/6-Speed Manual', 1989, 2002),
      eng('International', 'DT466 / DT466E', 7.6, '6-Cyl Turbo', 230, 'Diesel', 'Allison MD3060 / Eaton 6-Speed Manual', 1989, 2002),
    ], [], SOURCE_VPIC_EPA_OEM),
    mdl('7400 WorkStar', 'Medium/Heavy Vocational Water & Vacuum Truck', 'Transport & Hauling', TRK_MED, 2002, 2017, [
      eng('International', 'DT466 / DT570 / MaxxForce DT / N9', 9.3, '6-Cyl Turbo', 330, 'Diesel', 'Allison 3000 / 3500 RDS Automatic', 2002, 2017),
      eng('Cummins', 'ISL9', 8.9, '6-Cyl Turbo', 350, 'Diesel', 'Allison 3000 RDS / Eaton 8LL', 2013, 2017),
    ], [], SOURCE_VPIC_EPA_OEM),
    mdl('9400i', 'Set-Back Axle Highway & Regional Tractor', 'Transport & Hauling', TRK_HWY, 1990, 2010, [
      eng('Cummins', 'N14 / ISX15', 14.9, '6-Cyl Turbo', 475, 'Diesel', 'Eaton Fuller 10/13-Speed Manual', 1990, 2010),
      eng('Caterpillar', '3406E / C15', 14.6, '6-Cyl Turbo', 475, 'Diesel', 'Eaton Fuller 13-Speed Manual', 1994, 2009),
    ], ['9200i', '9300'], SOURCE_VPIC_EPA_OEM),
    mdl('HX520', 'Set-Forward Axle Oilfield & Heavy-Haul Conventional', 'Transport & Hauling', TRK_HEAVY, 2017, 2026, [
      eng('Cummins', 'X15 Performance / Vocational', 14.9, '6-Cyl Turbo', 565, 'Diesel', 'Eaton Fuller 18-Speed Manual', 2017, 2026),
      eng('International', 'A26 / S13', 12.7, '6-Cyl Turbo', 515, 'Diesel', 'Allison 4500 RDS / T14 Automated', 2018, 2026),
    ], [], SOURCE_VPIC_EPA_OEM),
    mdl('HV613', '13-Liter Vocational Roll-Off, Vacuum & Dump Chassis', 'Transport & Hauling', TRK_HEAVY, 2018, 2026, [
      eng('International', 'A26 / S13 Integrated', 12.7, '6-Cyl Turbo', 475, 'Diesel', 'Allison 4500 RDS / Eaton 8LL Manual', 2018, 2026),
      eng('Cummins', 'L9', 8.9, '6-Cyl Turbo', 380, 'Diesel', 'Allison 3500 RDS Automatic', 2018, 2026),
    ], [], SOURCE_VPIC_EPA_OEM),
    mdl('MV607', 'Medium-Duty Mechanics, Fuel/Lube & Water Truck', 'Transport & Hauling', TRK_MED, 2018, 2026, [
      eng('Cummins', 'B6.7', 6.7, '6-Cyl Turbo', 300, 'Diesel', 'Allison 2500 / 3000 RDS 6-Speed Automatic', 2018, 2026),
      eng('Cummins', 'L9', 8.9, '6-Cyl Turbo', 350, 'Diesel', 'Allison 3000 RDS Automatic', 2019, 2026),
    ], ['4300 DuraStar'], SOURCE_VPIC_EPA_OEM),
  ],
  volvo_trucks: [
    mdl('WG', 'WhiteGMC / Volvo Set-Back Vocational & Regional Tractor', 'Transport & Hauling', TRK_HEAVY, 1988, 2001, [
      eng('Volvo', 'VE D12 / TD122', 12.1, '6-Cyl Turbo', 415, 'Diesel', 'Eaton Fuller 8LL / 10-Speed Manual', 1988, 2001),
      eng('Cummins', 'L10 / M11 / N14', 10.8, '6-Cyl Turbo', 370, 'Diesel', 'Eaton Fuller 10-Speed / Allison Automatic', 1988, 2001),
    ], ['N10', 'F7'], SOURCE_VPIC_EPA_OEM),
    mdl('VNM', 'Medium-Hood Regional Haul Tractor (VNM 200 / 430 / 630)', 'Transport & Hauling', TRK_HWY, 1996, 2017, [
      eng('Volvo', 'D11 / D12 / D13', 12.8, '6-Cyl Turbo', 435, 'Diesel', 'Volvo I-Shift / Eaton 10-Speed Manual', 1996, 2017),
      eng('Cummins', 'ISM / ISX12', 10.8, '6-Cyl Turbo', 400, 'Diesel', 'Eaton Fuller 10-Speed Manual', 1998, 2015),
    ], [], SOURCE_VPIC_EPA_OEM),
    mdl('VT 880', 'Long-Hood Flagship Owner-Operator Tractor', 'Transport & Hauling', TRK_HEAVY, 2005, 2010, [
      eng('Volvo', 'D16', 16.1, '6-Cyl Turbo', 625, 'Diesel', 'Eaton Fuller 13/18-Speed / Volvo I-Shift', 2005, 2010),
      eng('Cummins', 'ISX15', 14.9, '6-Cyl Turbo', 565, 'Diesel', 'Eaton Fuller 18-Speed Manual', 2005, 2010),
    ], ['VT 800'], SOURCE_VPIC_EPA_OEM),
    mdl('VNR Electric', 'Zero-Emission Regional Highway Tractor', 'Transport & Hauling', TRK_HWY, 2021, 2026, [
      eng('Volvo Electric', 'Dual-Motor 565 kWh Pack', 0.0, 'Electric Drive', 455, 'Electric', '2-Speed Volvo I-Shift Electric', 2021, 2026),
      eng('Volvo Electric', '375 kWh Daycab Pack', 0.0, 'Electric Drive', 455, 'Electric', '2-Speed Volvo I-Shift Electric', 2021, 2026),
    ], [], SOURCE_VPIC_EPA_OEM),
  ],
  ford: [
    mdl('CL-9000', 'Cabover Air-Ride Linehaul Tractor', 'Transport & Hauling', TRK_HWY, 1978, 1991, [
      eng('Cummins', 'NTC-350 / NTC-400', 14.0, '6-Cyl Turbo', 400, 'Diesel', 'Fuller Roadranger 13-Speed Manual', 1978, 1991),
      eng('Caterpillar', '3406B', 14.6, '6-Cyl Turbo', 425, 'Diesel', 'Fuller 13-Speed Manual', 1978, 1991),
      eng('Detroit Diesel', '8V-92TA', 12.1, 'V8 2-Stroke Turbo', 435, 'Diesel', 'Fuller 13-Speed Manual', 1978, 1990),
    ], ['CLT-9000'], SOURCE_VPIC_EPA_OEM),
    mdl('F-450 Super Duty', 'Class 4 Welding, Crane & Hotshot Hauler Chassis', 'Transport & Hauling', TRK_MED, 1999, 2026, [
      eng('Ford / International', '7.3L Power Stroke V8', 7.3, 'V8 Turbo', 250, 'Diesel', '4R100 Automatic / ZF 6-Speed Manual', 1999, 2003),
      eng('Ford', '6.0L / 6.4L Power Stroke V8', 6.4, 'V8 Twin-Turbo', 325, 'Diesel', 'TorqShift 5-Speed Automatic', 2003, 2010),
      eng('Ford', '6.7L Power Stroke V8 / High-Output', 6.7, 'V8 Turbo', 500, 'Diesel', 'TorqShift 6/10-Speed Automatic', 2011, 2026),
      eng('Ford', '6.8L Triton V10 / 7.3L V8 Gas', 7.3, 'V8', 335, 'Gasoline', 'TorqShift 10-Speed Automatic', 1999, 2026),
    ], ['F-450'], SOURCE_VPIC_EPA_OEM),
    mdl('F-650', 'Class 6 Water, Flatbed, Rollback & Fuel Truck', 'Transport & Hauling', TRK_MED, 2000, 2026, [
      eng('Cummins', '5.9L ISB / 6.7L ISB', 6.7, '6-Cyl Turbo', 300, 'Diesel', 'Allison 2500 RDS Automatic', 2000, 2015),
      eng('Caterpillar', '3126B / C7 ACERT', 7.2, '6-Cyl Turbo', 250, 'Diesel', 'Allison 2500 RDS / Eaton 6-Speed', 2000, 2009),
      eng('Ford', '6.7L Power Stroke V8', 6.7, 'V8 Turbo', 330, 'Diesel', 'Ford TorqShift HD 6/10-Speed Automatic', 2016, 2026),
      eng('Ford', '7.3L Godzilla V8 Gas', 7.3, 'V8', 335, 'Gasoline', 'Ford TorqShift HD 6-Speed Automatic', 2021, 2026),
    ], ['F-600'], SOURCE_VPIC_EPA_OEM),
  ],
  lincoln_electric: [
    mdl('Ranger 330MPX', 'Next-Gen Compact Multi-Process Truck Welders', 'Site Support', ['Welding Machine'], 2020, 2026, [
      eng('Kohler', 'Command Pro CH740', 0.7, 'V-Twin OHV', 25, 'Gasoline', 'CrossLinc Chopper-Tech Generator', 2020, 2026),
      eng('Kohler', 'Command Pro ECH740 EFI', 0.7, 'V-Twin EFI', 25, 'Gasoline', 'CrossLinc Auto-Stop/Start Generator', 2022, 2026),
    ], ['Ranger 260MPX'], SOURCE_EPA_OEM),
    mdl('Vantage 500', 'High-Amperage Pipeline & Gouging Diesel Welders', 'Site Support', ['Welding Machine'], 2005, 2026, [
      eng('Cummins', 'B3.3', 3.3, '4-Cyl', 60, 'Diesel', '1800 RPM Chopper-Tech Generator', 2005, 2015),
      eng('Deutz', 'TD2.9 L4 Tier 4F', 2.9, '4-Cyl Turbo', 65, 'Diesel', '1800 RPM 3-Phase Industrial Generator', 2015, 2026),
    ], ['Air Vantage 500'], SOURCE_EPA_OEM),
  ],
  miller: [
    mdl('Bobcat 260', 'Quiet-Pulse Service Truck Welder/Generators', 'Site Support', ['Welding Machine'], 2019, 2023, [
      eng('Kohler', 'Command Pro CH730 / ECH730 EFI', 0.7, 'V-Twin', 23.5, 'Gasoline', '3600 RPM Generator', 2019, 2023),
      eng('Kubota', 'D722', 0.7, '3-Cyl', 19, 'Diesel', '3600 RPM Generator', 2019, 2023),
      eng('Kohler', 'Command Pro LP', 0.7, 'V-Twin', 23, 'Dual Fuel (Gas/LPG)', '3600 RPM Generator', 2019, 2023),
    ], [], SOURCE_EPA_OEM),
  ],
};
// ============================================================================
// EXTRA FIRST-CLASS GENERATIONAL MODELS (Highway Trucks, Compressors, Welders)
// ============================================================================
const EXTRA_MODELS_BY_ID = {
  peterbilt: [
    mdl('220', 'Cabover Medium-Duty Service & Tank Chassis', 'Transport & Hauling', TRK_MED, 2007, 2026, [
      eng('PACCAR', 'PX-6 / PX-7', 6.7, '6-Cyl Turbo', 300, 'Diesel', 'Allison 2500 / 3000 HS/RDS Automatic', 2007, 2026),
      eng('Cummins', 'ISB6.7', 6.7, '6-Cyl Turbo', 260, 'Diesel', 'Allison 2500 RDS Automatic', 2007, 2016),
    ], ['220EV'], SOURCE_VPIC_EPA_OEM),
    mdl('320', 'Low-Cab-Forward Vacuum, Refuse & Tanker Chassis', 'Transport & Hauling', TRK_MED, 1987, 2017, [
      eng('Caterpillar / Cummins', '3306 / L10 / ISM', 10.8, '6-Cyl Turbo', 350, 'Diesel', 'Allison HD4560 / 4500 RDS Automatic', 1987, 2009),
      eng('PACCAR / Cummins', 'PX-9 / ISX12 / ISL-G', 8.9, '6-Cyl Turbo', 380, 'Diesel', 'Allison 4500 RDS Automatic', 2010, 2017),
    ], [], SOURCE_VPIC_EPA_OEM),
    mdl('330', 'Class 6/7 Service, Fuel & Water Chassis', 'Transport & Hauling', TRK_MED, 1995, 2020, [
      eng('Caterpillar', '3116 / 3126B / C7', 7.2, '6-Cyl Turbo', 250, 'Diesel', 'Allison MD3060 / Eaton 6-Speed Manual', 1995, 2007),
      eng('PACCAR / Cummins', 'PX-6 / PX-7 / ISB6.7', 6.7, '6-Cyl Turbo', 280, 'Diesel', 'Allison 2500 / 3000 RDS Automatic', 2007, 2020),
    ], [], SOURCE_VPIC_EPA_OEM),
    mdl('335', 'Class 7 Heavy Medium-Duty Water & Lube Chassis', 'Transport & Hauling', TRK_MED, 2005, 2010, [
      eng('Cummins', 'ISC8.3 / ISL', 8.3, '6-Cyl Turbo', 315, 'Diesel', 'Allison 3000 RDS / Eaton 8LL Manual', 2005, 2010),
      eng('Caterpillar / PACCAR', 'C7 ACERT / PX-8', 8.3, '6-Cyl Turbo', 300, 'Diesel', 'Allison 3000 RDS Automatic', 2005, 2010),
    ], [], SOURCE_VPIC_EPA_OEM),
    mdl('365', 'Set-Back / Set-Forward Vocational Dump & Vacuum Truck', 'Transport & Hauling', TRK_HEAVY, 2007, 2023, [
      eng('Caterpillar', 'C13 ACERT', 12.5, '6-Cyl Twin-Turbo', 430, 'Diesel', 'Eaton Fuller 8LL / Allison 4500 RDS', 2007, 2009),
      eng('Cummins', 'ISL9 / ISX12', 11.9, '6-Cyl Turbo', 425, 'Diesel', 'Eaton Fuller 8LL / Allison 4500 RDS', 2007, 2023),
      eng('PACCAR', 'MX-11 / MX-13', 12.9, '6-Cyl Turbo', 455, 'Diesel', 'Eaton Fuller 18-Speed / TX-18 Pro', 2011, 2023),
    ], [], SOURCE_VPIC_EPA_OEM),
    mdl('375', 'Medium-Length Conventional Highway & Tanker Tractor', 'Transport & Hauling', TRK_HWY, 1988, 1996, [
      eng('Caterpillar', '3176 / 3306B', 10.5, '6-Cyl Turbo', 350, 'Diesel', 'Fuller Roadranger 9/10-Speed Manual', 1988, 1996),
      eng('Cummins', 'L10 / M11', 10.8, '6-Cyl Turbo', 370, 'Diesel', 'Fuller 10-Speed Manual', 1988, 1996),
    ], [], SOURCE_VPIC_EPA_OEM),
    mdl('520', 'Severe-Duty Cabover Roll-Off & Vacuum Chassis', 'Transport & Hauling', TRK_MED, 2016, 2026, [
      eng('PACCAR', 'MX-11 / PX-9', 10.8, '6-Cyl Turbo', 430, 'Diesel', 'Allison 4500 RDS 6-Speed Automatic', 2016, 2026),
      eng('Cummins', 'ISX12N / L9N Near-Zero', 11.9, '6-Cyl Turbo', 400, 'Natural Gas', 'Allison 4500 RDS Automatic', 2016, 2026),
    ], ['520EV'], SOURCE_VPIC_EPA_OEM),
    mdl('536', 'Next-Gen Class 6 Non-CDL Service & Flatbed Truck', 'Transport & Hauling', TRK_MED, 2021, 2026, [
      eng('PACCAR', 'PX-7', 6.7, '6-Cyl Turbo', 300, 'Diesel', 'PACCAR TX-8 8-Speed Automatic', 2021, 2026),
      eng('PACCAR', 'PX-9', 8.9, '6-Cyl Turbo', 350, 'Diesel', 'Allison 3000 RDS Automatic', 2021, 2026),
    ], [], SOURCE_VPIC_EPA_OEM),
    mdl('537', 'Next-Gen Class 7 Mechanics, Lube & Water Truck', 'Transport & Hauling', TRK_MED, 2021, 2026, [
      eng('PACCAR', 'PX-7', 6.7, '6-Cyl Turbo', 325, 'Diesel', 'PACCAR TX-8 Automatic', 2021, 2026),
      eng('PACCAR', 'PX-9', 8.9, '6-Cyl Turbo', 380, 'Diesel', 'Allison 3000 / 3500 RDS Automatic', 2021, 2026),
    ], [], SOURCE_VPIC_EPA_OEM),
    mdl('587', 'Wide-Body Aerodynamic Long-Haul Tractor', 'Transport & Hauling', TRK_HWY, 2010, 2017, [
      eng('Cummins', 'ISX15', 14.9, '6-Cyl Turbo', 500, 'Diesel', 'Eaton Fuller 13-Speed / UltraShift PLUS', 2010, 2017),
      eng('PACCAR', 'MX-13', 12.9, '6-Cyl Turbo', 485, 'Diesel', 'Eaton Fuller 10/13-Speed Manual', 2010, 2017),
    ], [], SOURCE_VPIC_EPA_OEM),
  ],
  kenworth: [
    mdl('W900B', 'Standard-Hood W900 Heavy Highway & Winch Tractor', 'Transport & Hauling', TRK_HEAVY, 1982, 2025, [
      eng('Caterpillar', '3406B / 3406E / C15', 14.6, '6-Cyl Turbo', 475, 'Diesel', 'Eaton Fuller 13/18-Speed Manual', 1982, 2009),
      eng('Cummins', 'NTC-400 / N14 / ISX15 / X15', 14.9, '6-Cyl Turbo', 550, 'Diesel', 'Eaton Fuller 18-Speed Manual', 1982, 2025),
      eng('PACCAR', 'MX-13', 12.9, '6-Cyl Turbo', 510, 'Diesel', 'Eaton Fuller 18-Speed Manual', 2010, 2025),
    ], [], SOURCE_VPIC_EPA_OEM),
    mdl('W900L', 'Extended-Hood 130-BBC Flagship Conventional', 'Transport & Hauling', TRK_HEAVY, 1990, 2026, [
      eng('Caterpillar', '3406E / C15 / C16 ACERT', 15.2, '6-Cyl Twin-Turbo', 550, 'Diesel', 'Eaton Fuller RTLO-18918B 18-Speed Manual', 1990, 2009),
      eng('Cummins', 'N14 / ISX15 / X15 Performance', 14.9, '6-Cyl Turbo', 605, 'Diesel', 'Eaton Fuller RTLO-18918B 18-Speed Manual', 1990, 2026),
      eng('PACCAR', 'MX-13', 12.9, '6-Cyl Turbo', 510, 'Diesel', 'Eaton Fuller 18-Speed / TX-18 Pro', 2010, 2026),
    ], ['W900L Studio Sleeper'], SOURCE_VPIC_EPA_OEM),
    mdl('K100E', 'Square-Headlight Aerodynamic Cabover COE', 'Transport & Hauling', TRK_HWY, 1984, 2004, [
      eng('Cummins', 'NTC-400 / N14 Celect', 14.0, '6-Cyl Turbo', 435, 'Diesel', 'Eaton Fuller 13-Speed Manual', 1984, 2004),
      eng('Caterpillar', '3406B / 3406E', 14.6, '6-Cyl Turbo', 455, 'Diesel', 'Eaton Fuller 13/18-Speed Manual', 1984, 2004),
      eng('Detroit Diesel', 'Series 60 12.7L', 12.7, '6-Cyl Turbo', 430, 'Diesel', 'Eaton Fuller 10/13-Speed Manual', 1988, 2004),
    ], [], SOURCE_VPIC_EPA_OEM),
    mdl('T2000', 'Wide-Body Aerodynamic Sleeper Highway Tractor', 'Transport & Hauling', TRK_HWY, 1996, 2010, [
      eng('Caterpillar', '3406E / C15 ACERT', 15.2, '6-Cyl Turbo', 475, 'Diesel', 'Eaton Fuller 10/13-Speed Manual', 1996, 2009),
      eng('Cummins', 'N14 / ISX15', 14.9, '6-Cyl Turbo', 485, 'Diesel', 'Eaton Fuller 13-Speed / AutoShift', 1996, 2010),
      eng('Detroit Diesel', 'Series 60 12.7L', 12.7, '6-Cyl Turbo', 430, 'Diesel', 'Eaton Fuller 10-Speed Manual', 1996, 2003),
    ], [], SOURCE_VPIC_EPA_OEM),
    mdl('T700', 'Wide-Cab Aerodynamic Long-Haul Tractor', 'Transport & Hauling', TRK_HWY, 2010, 2014, [
      eng('PACCAR', 'MX-13', 12.9, '6-Cyl Turbo', 485, 'Diesel', 'Eaton Fuller 13-Speed / UltraShift PLUS', 2010, 2014),
      eng('Cummins', 'ISX15', 14.9, '6-Cyl Turbo', 500, 'Diesel', 'Eaton Fuller 13-Speed Manual', 2010, 2014),
    ], [], SOURCE_VPIC_EPA_OEM),
    mdl('T300', 'First-Gen Medium-Duty Conventional Service & Water Truck', 'Transport & Hauling', TRK_MED, 1994, 2008, [
      eng('Cummins', '6BT5.9 / 6CT8.3 / ISB / ISC', 8.3, '6-Cyl Turbo', 285, 'Diesel', 'Allison MD3060 / Eaton 6/9-Speed Manual', 1994, 2008),
      eng('Caterpillar', '3126B / C7', 7.2, '6-Cyl Turbo', 250, 'Diesel', 'Allison 3000 RDS Automatic', 1998, 2007),
    ], [], SOURCE_VPIC_EPA_OEM),
    mdl('T380', 'Next-Gen Class 7 Service, Fuel & Water Chassis', 'Transport & Hauling', TRK_MED, 2022, 2026, [
      eng('PACCAR', 'PX-7', 6.7, '6-Cyl Turbo', 325, 'Diesel', 'PACCAR TX-8 8-Speed Automatic', 2022, 2026),
      eng('PACCAR', 'PX-9', 8.9, '6-Cyl Turbo', 380, 'Diesel', 'Allison 3000 RDS 6-Speed Automatic', 2022, 2026),
    ], ['T280'], SOURCE_VPIC_EPA_OEM),
    mdl('T440', 'Heavy Medium-Duty Regional, Tanker & Vacuum Truck', 'Transport & Hauling', TRK_MED, 2010, 2021, [
      eng('PACCAR', 'PX-9', 8.9, '6-Cyl Turbo', 380, 'Diesel', 'Allison 3000 / 3500 RDS Automatic', 2010, 2021),
      eng('Cummins', 'ISL9 / ISL-G', 8.9, '6-Cyl Turbo', 350, 'Diesel', 'Eaton Fuller 8LL / Allison Automatic', 2010, 2021),
    ], ['T470'], SOURCE_VPIC_EPA_OEM),
  ],
  western_star: [
    mdl('4964EX', 'Heritage Extended-Hood Heavy-Haul & Logging Tractor', 'Transport & Hauling', TRK_HEAVY, 1990, 2002, [
      eng('Caterpillar', '3406B / 3406E', 14.6, '6-Cyl Turbo', 500, 'Diesel', 'Eaton Fuller 18-Speed Manual', 1990, 2002),
      eng('Cummins', 'N14 Celect Plus', 14.0, '6-Cyl Turbo', 525, 'Diesel', 'Eaton Fuller 18-Speed Manual', 1991, 2002),
      eng('Detroit Diesel', 'Series 60 12.7L / 14.0L', 12.7, '6-Cyl Turbo', 500, 'Diesel', 'Eaton Fuller 18-Speed Manual', 1990, 2002),
    ], [], SOURCE_VPIC_EPA_OEM),
    mdl('6900TS', 'Twin-Steer Extreme-Duty Oilfield Bed & Rig Mover', 'Transport & Hauling', TRK_HEAVY, 2005, 2024, [
      eng('Detroit Diesel', 'DD16', 15.6, '6-Cyl Turbo', 600, 'Diesel', 'Allison 4700 RDS / Eaton 18-Speed + Aux', 2009, 2024),
      eng('Caterpillar / Cummins', 'C15 ACERT / ISX15 / X15', 14.9, '6-Cyl Turbo', 600, 'Diesel', 'Allison 4700 RDS / Eaton 18-Speed', 2005, 2024),
    ], [], SOURCE_VPIC_EPA_OEM),
  ],
  mack: [
    mdl('DM800', 'Extra-Heavy Steel-Nose Oilfield & Mining Chassis', 'Transport & Hauling', TRK_HEAVY, 1970, 2002, [
      eng('Mack', 'ENDT865 / E9 V8', 16.4, 'V8 Turbo', 440, 'Diesel', 'Mack Maxitorque / Allison Planetary', 1970, 1995),
      eng('Mack', 'EM6-300 / E7-400', 12.0, '6-Cyl Turbo', 400, 'Diesel', 'Mack T2180 / Fuller 8LL Manual', 1978, 2002),
    ], [], SOURCE_VPIC_EPA_OEM),
    mdl('CH613', 'Fleet Conventional Highway & Heavy Daycab Tractor', 'Transport & Hauling', TRK_HWY, 1989, 2005, [
      eng('Mack', 'E7-350 / E7-400 / E7-427', 12.0, '6-Cyl Turbo', 427, 'Diesel', 'Mack T2100 / Eaton Fuller 10/13-Speed', 1989, 2003),
      eng('Mack', 'ASET AC-427 / AC-460', 12.0, '6-Cyl Turbo', 460, 'Diesel', 'Eaton Fuller 13/18-Speed Manual', 2002, 2005),
    ], ['CHN613'], SOURCE_VPIC_EPA_OEM),
    mdl('CXN613', 'Vision Aerodynamic Regional & Long-Haul Tractor', 'Transport & Hauling', TRK_HWY, 1999, 2007, [
      eng('Mack', 'E7-427 / E7-460 E-Tech', 12.0, '6-Cyl Turbo', 460, 'Diesel', 'Eaton Fuller 10/13-Speed Manual', 1999, 2003),
      eng('Mack', 'ASET AC-380 / AC-460', 12.0, '6-Cyl Turbo', 460, 'Diesel', 'Eaton Fuller 10/13-Speed Manual', 2003, 2007),
    ], ['CX613'], SOURCE_VPIC_EPA_OEM),
    mdl('LR', 'Low-Entry Cabover Refuse & Industrial Vacuum Chassis', 'Transport & Hauling', TRK_MED, 2015, 2026, [
      eng('Mack', 'MP7', 10.8, '6-Cyl Turbo', 355, 'Diesel', 'Allison 4500 RDS 6-Speed Automatic', 2015, 2026),
      eng('Cummins', 'L9N Near-Zero Natural Gas', 8.9, '6-Cyl Turbo', 320, 'Natural Gas', 'Allison 4500 RDS Automatic', 2016, 2026),
    ], ['LR Electric'], SOURCE_VPIC_EPA_OEM),
  ],
  freightliner: [
    mdl('FL70', 'Business Class Medium-Duty Service, Fuel & Water Truck', 'Transport & Hauling', TRK_MED, 1991, 2005, [
      eng('Cummins', '6BT5.9 / ISB 5.9', 5.9, '6-Cyl Turbo', 230, 'Diesel', 'Allison AT545 / MD3060 / Eaton 6-Speed', 1991, 2005),
      eng('Caterpillar', '3116 / 3126B', 7.2, '6-Cyl Turbo', 250, 'Diesel', 'Allison MD3060 Automatic', 1991, 2005),
    ], ['FL60'], SOURCE_VPIC_EPA_OEM),
    mdl('FL112', 'Heavy Business Class Vocational & Tanker Chassis', 'Transport & Hauling', TRK_HEAVY, 1994, 2004, [
      eng('Caterpillar', 'C10 / C12', 12.0, '6-Cyl Turbo', 410, 'Diesel', 'Eaton Fuller 8LL / 10-Speed Manual', 1996, 2004),
      eng('Cummins', 'M11 / ISM', 10.8, '6-Cyl Turbo', 370, 'Diesel', 'Eaton Fuller 8LL / Allison HD4560', 1994, 2004),
    ], [], SOURCE_VPIC_EPA_OEM),
    mdl('Argosy', 'Flat-Floor High-Cab COE Highway Tractor', 'Transport & Hauling', TRK_HWY, 1999, 2020, [
      eng('Detroit Diesel', 'Series 60 12.7L / 14.0L / DD15', 14.0, '6-Cyl Turbo', 515, 'Diesel', 'Eaton Fuller SmartShift / UltraShift / 18-Speed', 1999, 2020),
      eng('Caterpillar', 'C15 ACERT', 15.2, '6-Cyl Turbo', 500, 'Diesel', 'Eaton Fuller 13/18-Speed Manual', 1999, 2009),
      eng('Cummins', 'ISX15', 14.9, '6-Cyl Turbo', 525, 'Diesel', 'Eaton Fuller 18-Speed Manual', 2001, 2020),
    ], [], SOURCE_VPIC_EPA_OEM),
    mdl('C120', 'Century Class S/T Heavy Highway Tractor', 'Transport & Hauling', TRK_HWY, 1996, 2010, [
      eng('Detroit Diesel', 'Series 60 12.7L / 14.0L', 14.0, '6-Cyl Turbo', 515, 'Diesel', 'Eaton Fuller 10/13-Speed Manual', 1996, 2010),
      eng('Caterpillar / Cummins', 'C15 / ISX15', 14.9, '6-Cyl Turbo', 475, 'Diesel', 'Eaton Fuller 13-Speed Manual', 1998, 2010),
    ], ['CST120'], SOURCE_VPIC_EPA_OEM),
  ],
  international: [
    mdl('Transtar 4300', 'Classic Long-Hood Conventional Highway Tractor (4200 / 4300)', 'Transport & Hauling', TRK_HEAVY, 1971, 1985, [
      eng('Cummins', 'NTC-290 / NTC-350 / NTC-400', 14.0, '6-Cyl Turbo', 400, 'Diesel', 'Fuller Roadranger 13-Speed Manual', 1971, 1985),
      eng('Detroit Diesel', '8V-71N / 8V-92TA', 12.1, 'V8 2-Stroke Turbo', 430, 'Diesel', 'Fuller 13-Speed Manual', 1971, 1985),
      eng('Caterpillar', '3406A / 3406B', 14.6, '6-Cyl Turbo', 400, 'Diesel', 'Fuller 13/15-Speed Manual', 1975, 1985),
    ], ['Transtar 4200'], SOURCE_VPIC_EPA_OEM),
    mdl('CO4070B', 'Transtar II Cabover COE Highway Tractor (CO4070A / CO9670)', 'Transport & Hauling', TRK_HWY, 1970, 1989, [
      eng('Cummins', 'NTC-350 / NTC-400', 14.0, '6-Cyl Turbo', 400, 'Diesel', 'Fuller Roadranger 10/13-Speed Manual', 1970, 1989),
      eng('Detroit Diesel', '8V-71T / 8V-92TA', 12.1, 'V8 2-Stroke Turbo', 430, 'Diesel', 'Fuller 13-Speed Manual', 1970, 1988),
    ], ['CO4070A', 'CO9670'], SOURCE_VPIC_EPA_OEM),
    mdl('PayStar 5900i', 'Severe-Duty Oilfield Winch, Gin-Pole & Heavy-Haul Truck', 'Transport & Hauling', TRK_HEAVY, 2000, 2016, [
      eng('Cummins', 'ISX15', 14.9, '6-Cyl Turbo', 550, 'Diesel', 'Eaton Fuller RTLO-18918B 18-Speed Manual', 2000, 2016),
      eng('Caterpillar', 'C15 ACERT', 15.2, '6-Cyl Twin-Turbo', 550, 'Diesel', 'Eaton Fuller 18-Speed Manual', 2000, 2009),
      eng('International', 'MaxxForce 13 / N13', 12.4, '6-Cyl Turbo', 475, 'Diesel', 'Allison 4500 RDS / Eaton 18-Speed', 2011, 2016),
    ], ['5500i', '5600i'], SOURCE_VPIC_EPA_OEM),
    mdl('9300', 'Eagle Classic Square-Hood Conventional Tractor', 'Transport & Hauling', TRK_HEAVY, 1985, 1999, [
      eng('Cummins', 'NTC-400 / N14 Celect Plus', 14.0, '6-Cyl Turbo', 460, 'Diesel', 'Eaton Fuller 13/18-Speed Manual', 1985, 1999),
      eng('Caterpillar', '3406B / 3406E', 14.6, '6-Cyl Turbo', 475, 'Diesel', 'Eaton Fuller 13/18-Speed Manual', 1985, 1999),
      eng('Detroit Diesel', 'Series 60 12.7L', 12.7, '6-Cyl Turbo', 430, 'Diesel', 'Eaton Fuller 10/13-Speed Manual', 1988, 1999),
    ], ['9370'], SOURCE_VPIC_EPA_OEM),
    mdl('Lonestar', 'Art-Deco Long-Hood Flagship Heavy Highway Tractor', 'Transport & Hauling', TRK_HEAVY, 2009, 2024, [
      eng('Cummins', 'ISX15 / X15 Performance', 14.9, '6-Cyl Turbo', 605, 'Diesel', 'Eaton Fuller RTLO-18918B 18-Speed Manual', 2009, 2024),
      eng('International', 'MaxxForce 13', 12.4, '6-Cyl Turbo', 475, 'Diesel', 'Eaton Fuller 13/18-Speed Manual', 2011, 2015),
    ], [], SOURCE_VPIC_EPA_OEM),
    mdl('8600 TranStar', 'Regional Daycab & Tanker Highway Tractor', 'Transport & Hauling', TRK_HWY, 2002, 2017, [
      eng('Caterpillar / Cummins', 'C11 / C13 / ISM / ISL9', 10.8, '6-Cyl Turbo', 410, 'Diesel', 'Eaton Fuller 10-Speed / Allison 3000 RDS', 2002, 2017),
      eng('International', 'MaxxForce 11 / MaxxForce 13 / N13', 12.4, '6-Cyl Turbo', 430, 'Diesel', 'Eaton Fuller 10-Speed / UltraShift', 2009, 2017),
    ], ['8500'], SOURCE_VPIC_EPA_OEM),
    mdl('RH', 'Regional Haul Agile Daycab & Sleeper Tractor', 'Transport & Hauling', TRK_HWY, 2018, 2026, [
      eng('International', 'A26', 12.4, '6-Cyl Turbo', 450, 'Diesel', 'Eaton Endurant 12-Speed / Allison 4500 RDS', 2018, 2024),
      eng('International', 'S13 Integrated Powertrain', 12.7, '6-Cyl Turbo', 475, 'Diesel', 'International T14 14-Speed Automated', 2024, 2026),
    ], ['RH613'], SOURCE_VPIC_EPA_OEM),
  ],
  volvo_trucks: [
    mdl('VNL 670', 'Gen-2 Mid/High-Roof Sleeper Highway Tractor', 'Transport & Hauling', TRK_HWY, 2003, 2017, [
      eng('Volvo', 'D12 / D13', 12.8, '6-Cyl Turbo', 485, 'Diesel', 'Volvo I-Shift 12-Speed / Eaton 13-Speed', 2003, 2017),
      eng('Cummins', 'ISX15', 14.9, '6-Cyl Turbo', 500, 'Diesel', 'Eaton Fuller 13-Speed / UltraShift PLUS', 2003, 2017),
    ], ['VNL 630', 'VNL 780'], SOURCE_VPIC_EPA_OEM),
    mdl('VNL 760', 'High-Roof 70-Inch Sleeper Long-Haul Tractor', 'Transport & Hauling', TRK_HWY, 2018, 2026, [
      eng('Volvo', 'D13 / D13TC Turbo-Compound', 12.8, '6-Cyl Turbo', 455, 'Diesel', 'Volvo I-Shift 12-Speed Overdrive', 2018, 2026),
      eng('Cummins', 'X15 Efficiency Series', 14.9, '6-Cyl Turbo', 500, 'Diesel', 'Eaton Endurant 12-Speed Automated', 2018, 2026),
    ], ['VNL 740'], SOURCE_VPIC_EPA_OEM),
    mdl('VNL 860', 'Flagship 77-Inch Sleeper Long-Haul Tractor', 'Transport & Hauling', TRK_HWY, 2018, 2026, [
      eng('Volvo', 'D13TC Turbo-Compound / D13 500', 12.8, '6-Cyl Turbo', 500, 'Diesel', 'Volvo I-Shift 12/13-Speed Automated', 2018, 2026),
      eng('Cummins', 'X15 Performance / Efficiency', 14.9, '6-Cyl Turbo', 565, 'Diesel', 'Eaton Fuller 13/18-Speed / Endurant', 2018, 2026),
    ], ['VNL 840'], SOURCE_VPIC_EPA_OEM),
    mdl('VNR 640', 'Mid-Roof Regional Tanker & Bulk-Haul Sleeper', 'Transport & Hauling', TRK_HWY, 2018, 2026, [
      eng('Volvo', 'D11', 10.8, '6-Cyl Turbo', 425, 'Diesel', 'Volvo I-Shift 12-Speed Automated', 2018, 2026),
      eng('Volvo', 'D13', 12.8, '6-Cyl Turbo', 455, 'Diesel', 'Volvo I-Shift 12-Speed Automated', 2018, 2026),
    ], ['VNR 400'], SOURCE_VPIC_EPA_OEM),
    mdl('FE', 'Cabover Medium-Duty Service & Tank Truck (FE6 / FE7 / FE42)', 'Transport & Hauling', TRK_MED, 1986, 1998, [
      eng('Volvo', 'TD61 / TD71 / D7', 6.7, '6-Cyl Turbo', 230, 'Diesel', 'Volvo 6-Speed Syncro / Allison Automatic', 1986, 1998),
      eng('Caterpillar', '3116', 6.6, '6-Cyl Turbo', 215, 'Diesel', 'Allison MD3060 Automatic', 1991, 1998),
    ], ['FE6', 'FE7'], SOURCE_VPIC_EPA_OEM),
    mdl('WX', 'WhiteGMC / Volvo Xpeditor Low-Cab-Forward Vacuum & Tanker', 'Transport & Hauling', TRK_MED, 1988, 2006, [
      eng('Volvo', 'VE D7 / D12', 12.1, '6-Cyl Turbo', 345, 'Diesel', 'Allison HD4560 Automatic', 1988, 2006),
      eng('Cummins', 'L10 / M11 / ISM', 10.8, '6-Cyl Turbo', 330, 'Diesel', 'Allison HD4560 Automatic', 1988, 2006),
    ], ['WX64', 'WXLL'], SOURCE_VPIC_EPA_OEM),
  ],
  ford: [
    mdl('L8000', 'Louisville Medium/Heavy Dump, Water & Winch Chassis', 'Transport & Hauling', TRK_MED, 1970, 1998, [
      eng('Caterpillar', '3208', 10.4, 'V8', 210, 'Diesel', 'Fuller RT-6610 / Allison MT653 Automatic', 1970, 1992),
      eng('Ford', '7.8L Turbo Diesel', 7.8, '6-Cyl Turbo', 240, 'Diesel', 'Fuller 8LL / Allison Automatic', 1987, 1993),
      eng('Ford / Cummins', 'FD-1460 (8.3L 6CT)', 8.3, '6-Cyl Turbo', 275, 'Diesel', 'Eaton Fuller 8LL / Allison MD3060', 1993, 1998),
    ], ['LN8000', 'LTS8000'], SOURCE_VPIC_EPA_OEM),
    mdl('LT9000', 'Louisville Tandem-Axle Vocational & Winch Truck', 'Transport & Hauling', TRK_HEAVY, 1970, 1998, [
      eng('Cummins', 'NTC-350 / L10 / M11 / N14', 14.0, '6-Cyl Turbo', 400, 'Diesel', 'Fuller Roadranger 8LL / 13-Speed Manual', 1970, 1998),
      eng('Caterpillar', '3306B / 3406B / 3406E', 14.6, '6-Cyl Turbo', 425, 'Diesel', 'Fuller 13/15-Speed Manual', 1973, 1998),
      eng('Detroit Diesel', '6-71N / 8V-71T / Series 60', 12.7, '6-Cyl Turbo', 400, 'Diesel', 'Fuller 9/13-Speed Manual', 1970, 1998),
    ], ['LTS9000'], SOURCE_VPIC_EPA_OEM),
    mdl('LTL9000', 'Long-Hood 118-BBC Heavy-Haul & Oilfield Conventional', 'Transport & Hauling', TRK_HEAVY, 1976, 1997, [
      eng('Caterpillar', '3406A / 3406B / 3406E', 14.6, '6-Cyl Turbo', 455, 'Diesel', 'Eaton Fuller 13/15/18-Speed Manual', 1976, 1997),
      eng('Cummins', 'NTC-400 Big Cam / N14 Celect', 14.0, '6-Cyl Turbo', 460, 'Diesel', 'Eaton Fuller 15/18-Speed Manual', 1976, 1997),
      eng('Detroit Diesel', '8V-92TA / Series 60', 12.7, '6-Cyl Turbo', 430, 'Diesel', 'Fuller 13-Speed Manual', 1976, 1997),
    ], ['LL9000'], SOURCE_VPIC_EPA_OEM),
    mdl('Aeromax 9000', 'Aerodynamic Set-Back Highway Tractor (LA9000 / Aeromax 120 / HN80)', 'Transport & Hauling', TRK_HWY, 1988, 1998, [
      eng('Detroit Diesel', 'Series 60 12.7L', 12.7, '6-Cyl Turbo', 430, 'Diesel', 'Eaton Fuller 10/13-Speed Manual', 1988, 1998),
      eng('Cummins', 'L10 / M11 / N14', 14.0, '6-Cyl Turbo', 435, 'Diesel', 'Eaton Fuller 10/13-Speed Manual', 1988, 1998),
      eng('Caterpillar', '3406B / 3406E', 14.6, '6-Cyl Turbo', 455, 'Diesel', 'Eaton Fuller 13-Speed Manual', 1988, 1998),
    ], ['LA9000', 'Aeromax 120', 'A9513'], SOURCE_VPIC_EPA_OEM),
    mdl('F-700', 'Medium-Duty Mechanics, Flatbed & Fuel Truck', 'Transport & Hauling', TRK_MED, 1970, 1998, [
      eng('Ford', '361 / 391 FT V8', 6.4, 'V8', 200, 'Gasoline', 'Clark 5+2 Manual', 1970, 1978),
      eng('Ford', '370 / 429 Lima V8', 7.0, 'V8', 235, 'Gasoline', '5-Speed Manual / Allison AT545', 1979, 1998),
      eng('Ford / Cummins', '6.6L / FD-1060 (5.9L 6BT)', 5.9, '6-Cyl Turbo', 190, 'Diesel', 'Allison AT545 / Eaton 6-Speed', 1987, 1998),
    ], [], SOURCE_VPIC_EPA_OEM),
    mdl('F-250 Super Duty', '3/4-Ton Field Supervisor & Service Rig Pickup', 'Transport & Hauling', TRK_MED, 1999, 2026, [
      eng('Ford / International', '7.3L Power Stroke V8', 7.3, 'V8 Turbo', 250, 'Diesel', '4R100 Automatic / ZF 6-Speed Manual', 1999, 2003),
      eng('Ford', '6.0L / 6.4L Power Stroke V8', 6.4, 'V8 Twin-Turbo', 350, 'Diesel', 'TorqShift 5-Speed Automatic', 2003, 2010),
      eng('Ford', '6.7L Power Stroke V8 / High-Output', 6.7, 'V8 Turbo', 500, 'Diesel', 'TorqShift 6/10-Speed Automatic', 2011, 2026),
      eng('Ford', '5.4L / 6.2L / 6.8L / 7.3L V8 Gas', 7.3, 'V8', 430, 'Gasoline', 'TorqShift 6/10-Speed Automatic', 1999, 2026),
    ], ['F-250'], SOURCE_VPIC_EPA_OEM),
    mdl('F-600 Super Duty', 'Class 6 Compact-Footprint Mechanics Crane & Service Chassis', 'Transport & Hauling', TRK_MED, 2020, 2026, [
      eng('Ford', '6.7L Power Stroke V8', 6.7, 'V8 Turbo', 330, 'Diesel', 'TorqShift 10-Speed Heavy-Duty Automatic', 2020, 2026),
      eng('Ford', '7.3L Godzilla V8 Gas', 7.3, 'V8', 335, 'Gasoline', 'TorqShift 10-Speed Heavy-Duty Automatic', 2020, 2026),
    ], [], SOURCE_VPIC_EPA_OEM),
    mdl('E-450 Super Duty', 'Cutaway Field Instrumentation, Wireline & Utility Van Chassis', 'Transport & Hauling', TRK_MED, 1999, 2026, [
      eng('Ford', '6.8L Triton V10', 6.8, 'V10', 305, 'Gasoline', 'TorqShift 5/6-Speed Automatic', 1999, 2020),
      eng('Ford', '7.3L V8 Economy / Premium Gas', 7.3, 'V8', 325, 'Gasoline', 'TorqShift 6-Speed Automatic', 2021, 2026),
      eng('Ford', '7.3L / 6.0L Power Stroke V8', 6.0, 'V8 Turbo', 235, 'Diesel', '4R100 / TorqShift Automatic', 1999, 2010),
    ], ['E-350 Super Duty'], SOURCE_VPIC_EPA_OEM),
  ],
  sullair: [
    mdl('160', 'Compact Towable Utility Air Compressors', 'Site Support', ['Air Compressor'], 1972, 2004, [
      eng('John Deere', '4219D / 4039D', 3.9, '4-Cyl', 52, 'Diesel', 'Direct Rotary-Screw Airend', 1972, 2004),
      eng('Kubota', 'V1903 / V2203', 2.2, '4-Cyl', 44, 'Diesel', 'Direct Rotary-Screw Airend', 1988, 2004),
    ], ['125'], SOURCE_EPA_OEM),
    mdl('210H', 'High-Pressure Utility & Fiber-Blowing Air Compressors', 'Site Support', ['Air Compressor'], 1995, 2026, [
      eng('John Deere', '4024TF / 4045D', 2.4, '4-Cyl Turbo', 61, 'Diesel', 'Direct Rotary-Screw Airend', 1995, 2014),
      eng('Kubota / Perkins', 'V2403-CR-T / 404F-E22TA', 2.4, '4-Cyl Turbo', 65, 'Diesel', 'Direct Rotary-Screw Airend', 2013, 2026),
    ], [], SOURCE_EPA_OEM),
    mdl('260', '260-CFM Two-Tool / Sandblast Air Compressors', 'Site Support', ['Air Compressor'], 1985, 2026, [
      eng('John Deere', '4039T / 4045TF', 4.5, '4-Cyl Turbo', 74, 'Diesel', 'Direct Rotary-Screw Airend', 1985, 2014),
      eng('Kubota', 'V3307-CR-T Tier 4F', 3.3, '4-Cyl Turbo', 74, 'Diesel', 'Direct Rotary-Screw Airend', 2013, 2026),
    ], [], SOURCE_EPA_OEM),
    mdl('400HH', 'High-Pressure 200-PSI Mid-Frame Air Compressors', 'Site Support', ['Air Compressor'], 2012, 2026, [
      eng('Caterpillar', 'C4.4 ACERT Tier 4F', 4.4, '4-Cyl Turbo', 143, 'Diesel', 'Direct Rotary-Screw Airend', 2012, 2026),
      eng('Perkins', '1204F-E44TA', 4.4, '4-Cyl Turbo', 143, 'Diesel', 'Direct Rotary-Screw Airend', 2014, 2026),
    ], [], SOURCE_EPA_OEM),
    mdl('425H', '425-CFM Pipeline & Abrasive-Blasting Air Compressors', 'Site Support', ['Air Compressor'], 1998, 2026, [
      eng('Caterpillar', '3054C / C4.4 ACERT', 4.4, '4-Cyl Turbo', 140, 'Diesel', 'Direct Rotary-Screw Airend', 1998, 2026),
      eng('John Deere', '4045HF285 / 4045HFC04', 4.5, '4-Cyl Turbo', 138, 'Diesel', 'Direct Rotary-Screw Airend', 1998, 2026),
    ], [], SOURCE_EPA_OEM),
    mdl('1050', 'High-Volume Pipeline Pigging & Testing Air Compressors', 'Site Support', ['Air Compressor'], 1985, 2024, [
      eng('Caterpillar', '3406C / C9 / C11 / C13', 11.1, '6-Cyl Turbo', 350, 'Diesel', 'Rotary-Screw Airend', 1985, 2024),
      eng('Cummins', 'NTA-855 / QSL9', 8.9, '6-Cyl Turbo', 330, 'Diesel', 'Rotary-Screw Airend', 1985, 2024),
    ], ['825'], SOURCE_EPA_OEM),
    mdl('1150XH', '350/500-PSI Deep-Hole Drilling & Pipeline Test Compressors', 'Site Support', ['Air Compressor'], 1996, 2026, [
      eng('Caterpillar', 'C15 ACERT', 15.2, '6-Cyl Twin-Turbo', 540, 'Diesel', 'Two-Stage High-Pressure Airend', 1996, 2026),
      eng('Cummins', 'QSX15 / X15', 14.9, '6-Cyl Turbo', 535, 'Diesel', 'Two-Stage High-Pressure Airend', 2002, 2026),
    ], ['900XHH'], SOURCE_EPA_OEM),
  ],
  atlas_copco: [
    mdl('XA 175', 'Classic Air-Cooled Deutz Portable Compressors', 'Site Support', ['Air Compressor'], 1974, 1998, [
      eng('Deutz', 'F4L912 / F5L912', 4.7, '4/5-Cyl Air-Cooled', 78, 'Diesel', 'Oil-Injected Screw Element', 1974, 1998),
      eng('Perkins', '4.236', 3.9, '4-Cyl', 75, 'Diesel', 'Oil-Injected Screw Element', 1974, 1992),
    ], ['XA 120', 'XA 160'], SOURCE_EPA_OEM),
    mdl('XAS 90', 'Compact Single-Axle Towable Air Compressors', 'Site Support', ['Air Compressor'], 1986, 2014, [
      eng('Deutz', 'F3L1011 / D2011L03', 2.3, '3-Cyl Oil-Cooled', 44, 'Diesel', 'Oil-Injected Screw Element', 1986, 2014),
      eng('Kubota', 'V1505-T', 1.5, '4-Cyl Turbo', 44, 'Diesel', 'Oil-Injected Screw Element', 2002, 2014),
    ], ['XAS 97'], SOURCE_EPA_OEM),
    mdl('XAS 110', 'Compact HardHat Towable Air Compressors', 'Site Support', ['Air Compressor'], 2012, 2026, [
      eng('Kubota', 'V1505 / D1803-CR', 1.8, '3/4-Cyl', 49, 'Diesel', 'Atlas Copco C80 Screw Element', 2012, 2026),
      eng('Deutz', 'D2011L03', 2.3, '3-Cyl', 46, 'Diesel', 'Screw Element', 2012, 2016),
    ], [], SOURCE_EPA_OEM),
    mdl('XAS 375', 'Mid-Range Pipeline & Blasting Air Compressors', 'Site Support', ['Air Compressor'], 1996, 2018, [
      eng('John Deere', '4045TF270 / 4045HF285', 4.5, '4-Cyl Turbo', 115, 'Diesel', 'Screw Element', 1996, 2018),
      eng('Deutz', 'BF4M1013EC / TCD 2012', 4.0, '4-Cyl Turbo', 120, 'Diesel', 'Screw Element', 1996, 2014),
    ], [], SOURCE_EPA_OEM),
    mdl('XAMS 850', 'High-Capacity Medium-Pressure Pipeline Air Compressors', 'Site Support', ['Air Compressor'], 2004, 2026, [
      eng('Caterpillar', 'C7 / C9 / C9.3B', 9.3, '6-Cyl Turbo', 300, 'Diesel', 'Screw Element', 2004, 2026),
      eng('John Deere', '6090HFC09', 9.0, '6-Cyl Turbo', 325, 'Diesel', 'Screw Element', 2012, 2026),
    ], [], SOURCE_EPA_OEM),
    mdl('QAS 25', 'Compact Sound-Attenuated Rental Generators', 'Site Support', ['Generator'], 2006, 2026, [
      eng('Kubota', 'V2403-M / D1803-CR', 2.4, '4-Cyl', 33, 'Diesel', '1800 RPM Brushless Alternator', 2006, 2026),
      eng('Isuzu', '4LE2T', 2.2, '4-Cyl Turbo', 34, 'Diesel', '1800 RPM Brushless Alternator', 2014, 2026),
    ], [], SOURCE_EPA_OEM),
    mdl('QAS 80', 'Mid-Size Skid/Trailer Prime-Power Generators', 'Site Support', ['Generator'], 2006, 2026, [
      eng('John Deere', '4045HFG', 4.5, '4-Cyl Turbo', 107, 'Diesel', '1800 RPM Brushless Alternator', 2006, 2026),
      eng('Kubota', 'V3800-CR-TI', 3.8, '4-Cyl Turbo', 103, 'Diesel', '1800 RPM Brushless Alternator', 2015, 2026),
    ], [], SOURCE_EPA_OEM),
    mdl('QAS 250', 'Heavy Oilfield Pad & Camp Prime-Power Generators', 'Site Support', ['Generator'], 2008, 2026, [
      eng('John Deere', '6090HFG', 9.0, '6-Cyl Turbo', 335, 'Diesel', '1800 RPM Synchronous Alternator', 2008, 2026),
      eng('Volvo Penta', 'TAD941GE / TAD873VE', 7.7, '6-Cyl Turbo', 340, 'Diesel', '1800 RPM Synchronous Alternator', 2008, 2026),
    ], [], SOURCE_EPA_OEM),
  ],
  lincoln_electric: [
    mdl('SAE-300', 'Classic Heavy Pipeline DC Exciter Welders', 'Site Support', ['Welding Machine'], 1970, 2016, [
      eng('Bedford / Perkins', '220 / 4.236 / 1004-4', 3.9, '4-Cyl', 58, 'Diesel', '1500 RPM Pure DC Generator', 1970, 2008),
      eng('Perkins', '1104C-44 / 404D-22T', 4.4, '4-Cyl', 60, 'Diesel', '1500 RPM Pure DC Generator', 2004, 2016),
    ], ['SAE-300 HE'], SOURCE_EPA_OEM),
    mdl('SAE-400', 'Heavy Mainline Pipeline & Offshore Gouging Welders', 'Site Support', ['Welding Machine'], 1970, 2020, [
      eng('Detroit Diesel', '3-53N / 3-71', 2.6, '3-Cyl 2-Stroke', 70, 'Diesel', '1800 RPM Pure DC Generator', 1970, 1995),
      eng('Perkins / Cat', '4.236 / 1104D-44T / C4.4', 4.4, '4-Cyl Turbo', 80, 'Diesel', '1800 RPM Pure DC Generator', 1982, 2020),
    ], ['SAE-500 Severe Duty'], SOURCE_EPA_OEM),
    mdl('Classic II', '1990s Mainline Pipeline Pure-DC Diesel Welders', 'Site Support', ['Welding Machine'], 1990, 2002, [
      eng('Perkins', '4.154 / 104-22', 2.2, '4-Cyl', 38, 'Diesel', '1800 RPM Pure DC Generator', 1990, 2002),
      eng('Continental', 'TMD27', 2.7, '4-Cyl', 44, 'Diesel', '1800 RPM Pure DC Generator', 1990, 1998),
    ], ['Classic I', 'Classic III'], SOURCE_EPA_OEM),
    mdl('Classic 300 MP', 'Multi-Process Pipeline Engine-Driven Welders', 'Site Support', ['Welding Machine'], 2012, 2026, [
      eng('Kubota', 'V1505 / D1803-CR', 1.8, '3/4-Cyl', 24.8, 'Diesel', '1800 RPM Microprocessor-Controlled DC Generator', 2012, 2026),
      eng('Perkins', '404D-22', 2.2, '4-Cyl', 32, 'Diesel', '1800 RPM Multi-Process Generator', 2012, 2018),
    ], [], SOURCE_EPA_OEM),
    mdl('Ranger 8', 'Classic Portable Field Maintenance Welders', 'Site Support', ['Welding Machine'], 1988, 2004, [
      eng('Onan', 'Performer P216 / P218G', 0.8, 'V-Twin', 18, 'Gasoline', '3600 RPM AC/DC Generator', 1988, 2004),
      eng('Kohler', 'Command CH18 / CH20', 0.6, 'V-Twin OHV', 20, 'Gasoline', '3600 RPM AC/DC Generator', 1994, 2004),
    ], ['Weldanpower 225'], SOURCE_EPA_OEM),
    mdl('Ranger 260MPX', 'Digital Multi-Process Service Truck Welders', 'Site Support', ['Welding Machine'], 2021, 2026, [
      eng('Kohler', 'Command Pro CH730', 0.7, 'V-Twin OHV', 23.5, 'Gasoline', 'CrossLinc Chopper-Tech Generator', 2021, 2026),
      eng('Kohler', 'Command Pro ECH730 EFI', 0.7, 'V-Twin EFI', 23.5, 'Gasoline', 'CrossLinc Chopper-Tech Generator', 2022, 2026),
    ], [], SOURCE_EPA_OEM),
    mdl('Ranger 305D', 'Water-Cooled Diesel Service Truck Welders', 'Site Support', ['Welding Machine'], 2004, 2026, [
      eng('Kubota', 'D722', 0.7, '3-Cyl Water-Cooled', 18.8, 'Diesel', '3600 RPM Chopper-Tech Generator', 2004, 2026),
      eng('Kubota', 'D902 Extreme-Duty', 0.9, '3-Cyl Water-Cooled', 21.6, 'Diesel', '3600 RPM Chopper-Tech Generator', 2014, 2026),
    ], [], SOURCE_EPA_OEM),
  ],
  miller: [
    mdl('Big 20', 'Classic Continental Pipeline & Structural DC Welders', 'Site Support', ['Welding Machine'], 1972, 1994, [
      eng('Continental', 'F-163 / Y-112', 2.7, '4-Cyl Water-Cooled', 37, 'Gasoline', '1800 RPM DC Generator', 1972, 1994),
      eng('Teledyne / Perkins', 'TMD20 / 4.108', 2.0, '4-Cyl', 35, 'Diesel', '1800 RPM DC Generator', 1976, 1994),
    ], [], SOURCE_EPA_OEM),
    mdl('AEAD-200LE', 'Classic Legend Onan Engine-Driven AC/DC Welders', 'Site Support', ['Welding Machine'], 1970, 1992, [
      eng('Onan', 'CCK / B48G / P218G', 0.8, 'Opposed Twin Air-Cooled', 18, 'Gasoline', '1800/3600 RPM Weld/Power Generator', 1970, 1992),
      eng('Kohler', 'Magnum M18', 0.7, 'Twin Air-Cooled', 18, 'Gasoline', 'Weld/Power Generator', 1986, 1992),
    ], ['Legend'], SOURCE_EPA_OEM),
    mdl('Blue Star 185', 'Compact Field Maintenance Engine-Driven Welders', 'Site Support', ['Welding Machine'], 1995, 2026, [
      eng('Kohler', 'Command Pro CH440', 0.4, '1-Cyl OHV', 14, 'Gasoline', '3600 RPM Accu-Rated Generator', 2005, 2026),
      eng('Honda / Tecumseh', 'GX390 / OHV13', 0.4, '1-Cyl OHV', 13, 'Gasoline', '3600 RPM Generator', 1995, 2020),
    ], ['Blue Star 145'], SOURCE_EPA_OEM),
    mdl('Trailblazer 251', '1990s Four-Pole Pro Field Welders', 'Site Support', ['Welding Machine'], 1993, 2002, [
      eng('Onan', 'Performer P220G', 0.8, 'V-Twin', 20, 'Gasoline', 'Four-Pole 3-Phase Swept-Field Generator', 1993, 2002),
      eng('Kohler', 'Command Pro CH20', 0.6, 'V-Twin OHV', 20, 'Gasoline', 'Four-Pole Generator', 1997, 2002),
    ], ['Trailblazer 250G'], SOURCE_EPA_OEM),
    mdl('Trailblazer 275', 'Pro Multi-Process Service Truck Welders', 'Site Support', ['Welding Machine'], 2005, 2016, [
      eng('Kohler', 'Command Pro CH23 / CH730', 0.7, 'V-Twin OHV', 23, 'Gasoline', 'Four-Pole Swept-Field Generator', 2005, 2016),
      eng('Subaru', 'EH65', 0.7, 'V-Twin OHV', 22, 'Gasoline', 'Four-Pole Generator', 2006, 2014),
    ], [], SOURCE_EPA_OEM),
    mdl('PipePro 304', 'Dedicated Mainline Pipeline Inverter/Hybrid Diesel Welders', 'Site Support', ['Welding Machine'], 2003, 2015, [
      eng('Kubota', 'V1505', 1.5, '4-Cyl Water-Cooled', 33, 'Diesel', '1800 RPM PipePro Smart-Arc Generator', 2003, 2015),
      eng('Caterpillar / Perkins', '3013C / 403D-15', 1.5, '3-Cyl', 31, 'Diesel', '1800 RPM PipePro Generator', 2003, 2010),
    ], [], SOURCE_EPA_OEM),
    mdl('Big Blue 300 Pro', 'Compact Quiet-Diesel Pipeline & Structural Welders', 'Site Support', ['Welding Machine'], 2002, 2020, [
      eng('Kubota', 'V1505 / D1105', 1.5, '4-Cyl', 24.8, 'Diesel', '1800 RPM Low-Speed Generator', 2008, 2020),
      eng('Caterpillar / Deutz', '3013C / F3L1011', 1.5, '3-Cyl', 29, 'Diesel', '1800 RPM Low-Speed Generator', 2002, 2012),
    ], [], SOURCE_EPA_OEM),
  ],
};

// ============================================================================
// LEGACY SNAPSHOTS FOR 100% BACKWARD COMPATIBILITY VERIFICATION
// ============================================================================
const LEGACY_SEED_BRANDS = {
  'Caterpillar': ['301.8', '305 CR', '320', '336', '950 GC', '966', 'D6', 'D8'],
  'Komatsu': ['PC55MR-5', 'PC210LC-11', 'PC360LC-11', 'WA270-8', 'D65EX-18'],
  'Volvo CE': ['EC18E', 'ECR58', 'EC220E', 'EC300E', 'L90H', 'A40G'],
  'John Deere': ['35 P-Tier', '210 P-Tier', '350 P-Tier', '544 P-Tier', '850K'],
  'Hitachi': ['ZX50U-5N', 'ZX210LC-7', 'ZX350LC-7', 'ZW220-6'],
  'JCB': ['3CX', '4CX', '220X', '540-170', '270T'],
  'Bobcat': ['E35', 'E60', 'S650', 'T76', 'TL619'],
  'Case': ['580SV', 'CX210D', '621G', 'TV450B'],
  'Sullair': ['185 Series', '375 Series', '900H'],
  'Atlas Copco': ['XAS 188', 'XAS 400', 'QAS 45', 'QAS 150'],
  'Lincoln Electric': ['Ranger 250', 'Vantage 322', 'Air Vantage 600'],
  'Miller': ['Bobcat 265', 'Trailblazer 330', 'Big Blue 600'],
  'National Oilwell Varco': ['TDS-11SA', '14-P-220', 'FD-1600'],
  'Weatherford': ['MPD Package', 'Wellhead System', 'Rod Pump'],
  'New Holland': ['B75D', 'B95D', 'B110D', 'C337', 'E57C'],
  'Kubota': ['BX23S', 'M62', 'KX040-5', 'KX057-5', 'SVL75-3'],
  'Terex': ['860SX', '970 Elite', 'TL80', 'TA300'],
  'Mecalac': ['TLB830', 'TLB870', '12MTX', '15MC'],
  'Manitou': ['MLT 737', 'MLT 840', 'MTA 10055', 'MRT 2660'],
  'LiuGong': ['766A', '777A', '915E', '922F', '856H'],
  'Develon': ['DX62R-7', 'DX225LC-7', 'DX350LC-7', 'DL320-7'],
  'Hyundai CE': ['HX60A', 'HX220A L', 'HX350A L', 'HL960A'],
  'Takeuchi': ['TB240', 'TB260', 'TB290', 'TL10V2', 'TL12V2'],
  'Wacker Neuson': ['EZ36', 'ET65', 'ET90', 'ST31', 'WL34'],
  'Yanmar': ['ViO35-7', 'ViO55-6A', 'SV100-7', 'TL100VS'],
  'Liebherr': ['A 914', 'R 920', 'R 945', 'L 550', 'PR 736'],
  'Kobelco': ['SK55SRX-7', 'SK210LC-11', 'SK350LC-11', 'SK850LC-10'],
  'Link-Belt': ['145 X4S', '210 X4S', '300 X4S', '350 X4S'],
  'Gradall': ['XL 3100 V', 'XL 4100 V', 'XL 5100 V', 'D152'],
  'Bell': ['B20E', 'B30E', 'B40E', 'B50E'],
  'Genie': ['GTH-5519', 'GTH-844', 'GTH-1056', 'S-65 XC'],
  'SkyTrak': ['6034', '6042', '8042', '10054', '12054'],
  'Mahindra': ['1626B', '2638 HST', '3650B', '6075'],
  'Massey Ferguson': ['MF 50', 'MF 60', 'MF 65', 'MF 750'],
};

function parseDartEquipmentBrandModels() {
  const dartPath = path.join(ROOT_DIR, 'lib', 'marketplace', 'oil_gas_marketplace.dart');
  const src = fs.readFileSync(dartPath, 'utf8');
  const startMatch = src.match(/const\s+equipmentBrandModels\s*=\s*<String,\s*List<String>>\s*\{/);
  if (!startMatch) {
    throw new Error('Could not locate equipmentBrandModels in lib/marketplace/oil_gas_marketplace.dart');
  }
  const bodyStart = startMatch.index + startMatch[0].length;
  const endIdx = src.indexOf('};', bodyStart);
  if (endIdx < 0) {
    throw new Error('Could not locate closing }; for equipmentBrandModels');
  }
  const block = src.slice(bodyStart, endIdx);
  const result = {};
  const entryRegex = /'([^']+)':\s*\[([^\]]*)\]/g;
  let m;
  while ((m = entryRegex.exec(block)) !== null) {
    const brand = m[1];
    const items = [];
    const itemRegex = /'([^']+)'/g;
    let im;
    while ((im = itemRegex.exec(m[2])) !== null) {
      items.push(im[1]);
    }
    result[brand] = items;
  }
  return result;
}

const DART_BRAND_MODELS = parseDartEquipmentBrandModels();

function combinedLegacyModelsFor(brandName) {
  const out = [];
  const seen = new Set();
  for (const list of [DART_BRAND_MODELS[brandName] || [], LEGACY_SEED_BRANDS[brandName] || []]) {
    for (const item of list) {
      const key = item.toLowerCase();
      if (!seen.has(key)) {
        seen.add(key);
        out.push(item);
      }
    }
  }
  return out;
}

function assembleFullManufacturer({
  id,
  name,
  aliases = [],
  wmiPrefixes = [],
  baseModels,
  featuredModels = [],
}) {
  const combinedRaw = [
    ...baseModels,
    ...(EXTENDED_MODELS_BY_ID[id] || []),
    ...(EXTRA_MODELS_BY_ID[id] || []),
  ];

  const seenModels = new Set();
  for (const m of combinedRaw) {
    const k = m.model.toLowerCase();
    if (seenModels.has(k)) {
      throw new Error(`Duplicate model "${m.model}" defined on manufacturer "${name}" (${id})`);
    }
    seenModels.add(k);
  }

  // Strip any alias that collides with an actual first-class model name on this manufacturer
  const models = combinedRaw.map((m) => ({
    ...m,
    aliases: m.aliases.filter((alias) => !seenModels.has(alias.toLowerCase())),
  }));

  const categories = [];
  for (const m of models) {
    if (!categories.includes(m.category)) {
      categories.push(m.category);
    }
  }

  const exampleModels = [];
  const exSeen = new Set();
  const candidates = [
    ...combinedLegacyModelsFor(name),
    ...featuredModels,
    ...models.map((m) => m.model),
  ];
  for (const candidate of candidates) {
    const key = candidate.toLowerCase();
    if (seenModels.has(key) && !exSeen.has(key)) {
      const canonical = models.find((m) => m.model.toLowerCase() === key).model;
      exSeen.add(key);
      exampleModels.push(canonical);
    }
    if (exampleModels.length >= 10 && exSeen.size >= combinedLegacyModelsFor(name).length) {
      break;
    }
  }

  return {
    id,
    name,
    aliases,
    categories,
    manualEntryOnly: false,
    manualEntryReason: null,
    wmiPrefixes,
    exampleModels,
    models,
  };
}

function assembleManualManufacturer({
  id,
  name,
  aliases = [],
  categories,
  manualEntryReason,
  wmiPrefixes = [],
  extraExampleModels = [],
}) {
  const exampleModels = [];
  const seen = new Set();
  for (const m of [...combinedLegacyModelsFor(name), ...extraExampleModels]) {
    const clean = String(m || '').trim();
    if (!clean) continue;
    const k = clean.toLowerCase();
    if (!seen.has(k)) {
      seen.add(k);
      exampleModels.push(clean);
    }
  }
  return {
    id,
    name,
    aliases,
    categories,
    manualEntryOnly: true,
    manualEntryReason,
    wmiPrefixes,
    exampleModels,
    models: [],
  };
}

// ============================================================================
// ASSEMBLE ALL 57 MANUFACTURERS (43 FULL-CATALOG + 14 MANUAL-ENTRY-ONLY)
// ============================================================================
const MANUFACTURERS = [
  // --- 43 Full-Catalog OEMs (1970–2026) ---
  assembleFullManufacturer({
    id: 'caterpillar',
    name: 'Caterpillar',
    aliases: ['Cat', 'CAT', 'Caterpillar Inc.'],
    baseModels: CATERPILLAR_MODELS,
  }),
  assembleFullManufacturer({
    id: 'komatsu',
    name: 'Komatsu',
    aliases: ['Komatsu Ltd.', 'Komatsu America', 'Dresser'],
    baseModels: KOMATSU_MODELS,
  }),
  assembleFullManufacturer({
    id: 'john_deere',
    name: 'John Deere',
    aliases: ['Deere', 'Deere & Company', 'JD'],
    baseModels: JOHN_DEERE_MODELS,
  }),
  assembleFullManufacturer({
    id: 'bobcat',
    name: 'Bobcat',
    aliases: ['Melroe', 'Clark Bobcat', 'Doosan Bobcat'],
    baseModels: BOBCAT_MODELS,
    featuredModels: ['S160', 'S650', 'T770', 'T76', 'E35'],
  }),
  assembleFullManufacturer({
    id: 'case',
    name: 'Case',
    aliases: ['CASE Construction', 'Case CE', 'J.I. Case', 'Drott'],
    baseModels: CASE_MODELS,
  }),
  assembleFullManufacturer({
    id: 'kubota',
    name: 'Kubota',
    aliases: ['Kubota Tractor', 'Kubota Engine America'],
    baseModels: KUBOTA_MODELS,
  }),
  assembleFullManufacturer({
    id: 'volvo_ce',
    name: 'Volvo CE',
    aliases: ['Volvo Construction Equipment', 'Volvo BM', 'Michigan', 'Akerman'],
    baseModels: VOLVO_CE_MODELS,
  }),
  assembleFullManufacturer({
    id: 'hitachi',
    name: 'Hitachi',
    aliases: ['Hitachi Construction Machinery', 'ZAXIS'],
    baseModels: HITACHI_MODELS,
  }),
  assembleFullManufacturer({
    id: 'jcb',
    name: 'JCB',
    aliases: ['J.C. Bamford', 'JCB Inc.'],
    baseModels: JCB_MODELS,
  }),
  assembleFullManufacturer({
    id: 'new_holland',
    name: 'New Holland',
    aliases: ['New Holland Construction', 'Ford New Holland'],
    baseModels: NEW_HOLLAND_MODELS,
  }),
  assembleFullManufacturer({
    id: 'kobelco',
    name: 'Kobelco',
    aliases: ['Kobelco Construction Machinery', 'Kobe Steel'],
    baseModels: KOBELCO_MODELS,
  }),
  assembleFullManufacturer({
    id: 'link_belt',
    name: 'Link-Belt',
    aliases: ['Link-Belt Excavators', 'LBX Company', 'Link-Belt Cranes'],
    baseModels: LINK_BELT_MODELS,
  }),
  assembleFullManufacturer({
    id: 'takeuchi',
    name: 'Takeuchi',
    aliases: ['Takeuchi Mfg', 'Takeuchi US'],
    baseModels: TAKEUCHI_MODELS,
  }),
  assembleFullManufacturer({
    id: 'develon',
    name: 'Develon',
    aliases: ['Doosan', 'Daewoo', 'Doosan Infracore', 'HD Hyundai Infracore'],
    baseModels: DEVELON_MODELS,
  }),
  assembleFullManufacturer({
    id: 'hyundai_ce',
    name: 'Hyundai CE',
    aliases: ['Hyundai Construction Equipment', 'HD Hyundai CE', 'Hyundai Robex'],
    baseModels: HYUNDAI_CE_MODELS,
  }),
  assembleFullManufacturer({
    id: 'liebherr',
    name: 'Liebherr',
    aliases: ['Liebherr Construction', 'Liebherr Cranes'],
    baseModels: LIEBHERR_MODELS,
  }),
  assembleFullManufacturer({
    id: 'yanmar',
    name: 'Yanmar',
    aliases: ['Yanmar Compact Equipment', 'Yanmar CE'],
    baseModels: YANMAR_MODELS,
  }),
  assembleFullManufacturer({
    id: 'wacker_neuson',
    name: 'Wacker Neuson',
    aliases: ['Wacker', 'Neuson'],
    baseModels: WACKER_NEUSON_MODELS,
  }),
  assembleFullManufacturer({
    id: 'terex',
    name: 'Terex',
    aliases: ['Terex Corporation', 'Fermec', 'ASV Posi-Track'],
    baseModels: TEREX_MODELS,
  }),
  assembleFullManufacturer({
    id: 'gradall',
    name: 'Gradall',
    aliases: ['Gradall Industries', 'Warner & Swasey Gradall'],
    baseModels: GRADALL_MODELS,
  }),
  assembleFullManufacturer({
    id: 'bell',
    name: 'Bell',
    aliases: ['Bell Equipment', 'Bell Trucks'],
    baseModels: BELL_MODELS,
  }),
  assembleFullManufacturer({
    id: 'manitou',
    name: 'Manitou',
    aliases: ['Manitou Group', 'Gehl', 'Mustang'],
    baseModels: MANITOU_MODELS,
  }),
  assembleFullManufacturer({
    id: 'skytrak',
    name: 'SkyTrak',
    aliases: ['Sky Trak', 'JLG SkyTrak', 'Koehring SkyTrak'],
    baseModels: SKYTRAK_MODELS,
  }),
  assembleFullManufacturer({
    id: 'grove_manitowoc',
    name: 'Grove / Manitowoc',
    aliases: ['Grove', 'Manitowoc', 'Manitowoc Cranes', 'National Crane'],
    baseModels: GROVE_MANITOWOC_MODELS,
  }),
  assembleFullManufacturer({
    id: 'genie_jlg',
    name: 'Genie / JLG',
    aliases: ['JLG', 'JLG Industries', 'Lull'],
    baseModels: GENIE_JLG_MODELS,
  }),
  assembleFullManufacturer({
    id: 'genie',
    name: 'Genie',
    aliases: ['Genie Industries', 'Terex AWP'],
    baseModels: GENIE_MODELS,
  }),
  assembleFullManufacturer({
    id: 'massey_ferguson',
    name: 'Massey Ferguson',
    aliases: ['MF', 'Massey', 'MF Industrial', 'AGCO'],
    baseModels: MASSEY_FERGUSON_MODELS,
  }),
  assembleFullManufacturer({
    id: 'vermeer',
    name: 'Vermeer',
    aliases: ['Vermeer Corporation', 'Vermeer Navigator'],
    baseModels: VERMEER_MODELS,
    featuredModels: ['D24x40 S3', 'D40x55 S3', 'D100x140 S3', 'T655', 'T855'],
  }),
  assembleFullManufacturer({
    id: 'ditch_witch',
    name: 'Ditch Witch',
    aliases: ['Charles Machine Works', 'DW'],
    baseModels: DITCH_WITCH_MODELS,
    featuredModels: ['JT20', 'JT30', 'JT40', 'AT40', 'RT120'],
  }),
  assembleFullManufacturer({
    id: 'bomag',
    name: 'Bomag',
    aliases: ['BOMAG', 'Fayat Bomag'],
    baseModels: BOMAG_MODELS,
    featuredModels: ['BW 120 AD-5', 'BW 177 D-5', 'BW 211 D-5', 'BW 213 D-5'],
  }),
  assembleFullManufacturer({
    id: 'ingersoll_rand',
    name: 'Ingersoll Rand',
    aliases: ['Ingersoll-Rand', 'IR', 'Doosan Portable Power'],
    baseModels: INGERSOLL_RAND_MODELS,
    featuredModels: ['P185WJD', 'HP375WCU', 'VHP750WCAT', 'SD-100D', 'DD-90'],
  }),
  assembleFullManufacturer({
    id: 'peterbilt',
    name: 'Peterbilt',
    aliases: ['Pete', 'Peterbilt Motors', 'PACCAR'],
    wmiPrefixes: ['1XP', '1NP', '2XP'],
    baseModels: PETERBILT_MODELS,
  }),
  assembleFullManufacturer({
    id: 'kenworth',
    name: 'Kenworth',
    aliases: ['KW', 'Kenworth Truck Company'],
    wmiPrefixes: ['1XK', '1NK', '2XK', '2NK', '3WK'],
    baseModels: KENWORTH_MODELS,
  }),
  assembleFullManufacturer({
    id: 'western_star',
    name: 'Western Star',
    aliases: ['Western Star Trucks', 'White Western Star'],
    wmiPrefixes: ['2WK', '2WL', '2WM', '5KJ', '5KK'],
    baseModels: WESTERN_STAR_MODELS,
  }),
  assembleFullManufacturer({
    id: 'mack',
    name: 'Mack',
    aliases: ['Mack Trucks', 'Mack Defense'],
    wmiPrefixes: ['1M1', '1M2', '1M3', '2M2'],
    baseModels: MACK_MODELS,
  }),
  assembleFullManufacturer({
    id: 'freightliner',
    name: 'Freightliner',
    aliases: ['Freightliner Trucks', 'Daimler Truck North America'],
    wmiPrefixes: ['1FU', '1FV', '3AK', '3AL'],
    baseModels: FREIGHTLINER_MODELS,
  }),
  assembleFullManufacturer({
    id: 'international',
    name: 'International',
    aliases: ['International Harvester', 'Navistar', 'IHC', 'International Trucks'],
    wmiPrefixes: ['1HS', '1HT', '2HS', '2HT', '3HS', '3HA', '3HC'],
    baseModels: INTERNATIONAL_MODELS,
    featuredModels: ['Paystar 5000', '4900', '9900i', '7600 WorkStar', 'HX620', 'LT', 'HV607'],
  }),
  assembleFullManufacturer({
    id: 'volvo_trucks',
    name: 'Volvo Trucks',
    aliases: ['Volvo', 'WhiteGMC', 'Autocar / Volvo'],
    wmiPrefixes: ['4V1', '4V2', '4V4', '4V5', '4VG'],
    baseModels: VOLVO_TRUCKS_MODELS,
    featuredModels: ['VNL', 'VNL 860', 'VNR', 'VHD', 'VNX'],
  }),
  assembleFullManufacturer({
    id: 'ford',
    name: 'Ford',
    aliases: ['Ford Commercial Trucks', 'Ford Heavy Truck', 'Super Duty'],
    wmiPrefixes: ['1FD', '1FT', '1FM', '3FR'],
    baseModels: FORD_MODELS,
    featuredModels: ['F-350 Super Duty', 'F-450 Super Duty', 'F-550 Super Duty', 'F-650', 'F-750', 'L9000 Louisville'],
  }),
  assembleFullManufacturer({
    id: 'sullair',
    name: 'Sullair',
    aliases: ['Hitachi Global Air Power / Sullair'],
    baseModels: SULLAIR_MODELS,
  }),
  assembleFullManufacturer({
    id: 'atlas_copco',
    name: 'Atlas Copco',
    aliases: ['Atlas Copco Power Technique'],
    baseModels: ATLAS_COPCO_MODELS,
  }),
  assembleFullManufacturer({
    id: 'lincoln_electric',
    name: 'Lincoln Electric',
    aliases: ['Lincoln', 'Lincoln Welders'],
    baseModels: LINCOLN_ELECTRIC_MODELS,
  }),
  assembleFullManufacturer({
    id: 'miller',
    name: 'Miller',
    aliases: ['Miller Electric', 'Miller Welders', 'ITW Miller'],
    baseModels: MILLER_MODELS,
  }),

  // --- 14 Manual-Entry-Only OEMs (Oilfield Custom Packages, Trailers, Specialty) ---
  assembleManualManufacturer({
    id: 'national_oilwell_varco',
    name: 'National Oilwell Varco',
    aliases: ['NOV', 'National Oilwell', 'Varco', 'Continental Emsco', 'Dreco', 'Ideco'],
    categories: ['Oilfield & Drilling', 'Oil & Gas Equipment'],
    manualEntryReason:
      'Custom-engineered oilfield drilling, top-drive, and mud-pump packages without standardized model-year or single-OEM engine trim.',
    extraExampleModels: [
      'TDS-8SA',
      'TDS-9SA',
      '12-P-160',
      'IDEAL Land Rig',
      'King Cobra Venom Shale Shaker',
      'NXT Ram BOP',
    ],
  }),
  assembleManualManufacturer({
    id: 'weatherford',
    name: 'Weatherford',
    aliases: ['Weatherford International', 'Lufkin'],
    categories: ['Oil & Gas Equipment', 'Oilfield & Drilling'],
    manualEntryReason:
      'Custom-configured wellhead, artificial-lift, and managed-pressure-drilling packages specified per well program.',
    extraExampleModels: [
      'Rotaflex Long-Stroke Pumping Unit',
      'Lufkin Mark II Pumping Unit',
      'Victus Intelligent MPD',
      'Magnus Rotary Steerable',
    ],
  }),
  assembleManualManufacturer({
    id: 'gardner_denver',
    name: 'Gardner Denver',
    aliases: ['GD Energy Products', 'GDEP'],
    categories: ['Oilfield & Drilling', 'Oil & Gas Equipment'],
    manualEntryReason:
      'Skid- and trailer-packaged triplex/quintuplex mud and well-stimulation pumps custom-paired with customer prime movers.',
    extraExampleModels: ['PZ-7', 'PZ-8', 'GD-2250', 'GD-2500Q', 'GD-3000'],
  }),
  assembleManualManufacturer({
    id: 'spm_weir',
    name: 'SPM / Weir',
    aliases: ['SPM', 'Weir Oil & Gas', 'SPM Oil & Gas'],
    categories: ['Oil & Gas Equipment', 'Oilfield & Drilling'],
    manualEntryReason:
      'Custom well-service, frac-pump, and high-pressure flow-iron packages built to customer prime-mover and pressure ratings.',
    extraExampleModels: [
      'TWS 2500',
      'QEM 3000',
      'QEM 5000',
      'Destiny 2500',
      '1502 Treating Iron Manifold',
    ],
  }),
  assembleManualManufacturer({
    id: 'ariel',
    name: 'Ariel',
    aliases: ['Ariel Corporation', 'Ariel Compressors'],
    categories: ['Oil & Gas Equipment'],
    manualEntryReason:
      'Separable reciprocating gas-compressor frames custom-packaged by third-party packagers with customer-selected gas/electric drivers.',
    extraExampleModels: ['JGJ/4', 'JGE/4', 'JGC/4', 'JGD/4', 'KBB/6', 'KBC/6'],
  }),
  assembleManualManufacturer({
    id: 'cameron_slb',
    name: 'Cameron / SLB',
    aliases: ['Cameron', 'SLB', 'Schlumberger', 'Shaffer', 'WKM'],
    categories: ['Oil & Gas Equipment', 'Oilfield & Drilling'],
    manualEntryReason:
      'Non-engine pressure-control, BOP, valve, manifold, and wellhead assemblies specified by API bore and working pressure.',
    extraExampleModels: [
      'TL BOP',
      'EVO BOP',
      'FLS Gate Valve',
      '15K Frac Tree',
      'CAMIRON Choke',
    ],
  }),
  assembleManualManufacturer({
    id: 'trail_king',
    name: 'Trail King',
    aliases: ['Trail King Industries', 'TKI'],
    categories: ['Transport & Hauling'],
    manualEntryReason:
      'Non-powered heavy-haul lowboy, detachable-gooseneck, and flatbed trailers without drivetrain or engine trim.',
    wmiPrefixes: ['1TK'],
    extraExampleModels: [
      'TK80HT',
      'TK100HDG',
      'TK110SA',
      'TK130HDG',
      'Advantage Plus Detachable',
    ],
  }),
  assembleManualManufacturer({
    id: 'fontaine',
    name: 'Fontaine',
    aliases: ['Fontaine Trailer', 'Fontaine Heavy-Haul'],
    categories: ['Transport & Hauling'],
    manualEntryReason:
      'Non-powered heavy-haul lowboy, flatbed, and step-deck trailers specified by deck length, axle group, and tonnage.',
    wmiPrefixes: ['13N'],
    extraExampleModels: [
      'Magnitude 55H',
      'Magnitude 65',
      'Magnitude 80',
      'Infinity Flatbed',
      'Infinity Drop Deck',
    ],
  }),
  assembleManualManufacturer({
    id: 'great_dane',
    name: 'Great Dane',
    aliases: ['Great Dane Trailers'],
    categories: ['Transport & Hauling'],
    manualEntryReason:
      'Non-powered commercial flatbed and drop-deck highway trailers without powertrain.',
    wmiPrefixes: ['1GR'],
    extraExampleModels: [
      'Freedom LT Flatbed',
      'Freedom SE Flatbed',
      'Freedom XP Flatbed',
      'Freedom Drop Deck',
      'Sahara Flatbed',
    ],
  }),
  assembleManualManufacturer({
    id: 'doepker',
    name: 'Doepker',
    aliases: ['Doepker Industries'],
    categories: ['Transport & Hauling'],
    manualEntryReason:
      'Non-powered Canadian oilfield scissorneck, lowbed, step-deck, and Super-B trailers without powertrain.',
    wmiPrefixes: ['2DE'],
    extraExampleModels: [
      'Oilfield Scissorneck 45T',
      'Oilfield Float',
      'Tridem Step Deck',
      'Super B Flatbed',
      '55-Ton Lowbed',
      '85-Ton Jeep & Booster Lowboy',
    ],
  }),
  assembleManualManufacturer({
    id: 'lode_king',
    name: 'Lode King',
    aliases: ['Lode King Industries', 'Prestige'],
    categories: ['Transport & Hauling'],
    manualEntryReason:
      'Non-powered commercial flatbed, drop-deck, and Super-B highway trailers without powertrain.',
    wmiPrefixes: ['2LD'],
    extraExampleModels: [
      'Renegade Steel Drop Deck',
      'Renegade Combo Flatbed',
      'Brilliance All-Aluminum Flatbed',
      'Super-B Flatbed',
      'Tridem Step Deck',
    ],
  }),
  assembleManualManufacturer({
    id: 'mecalac',
    name: 'Mecalac',
    aliases: ['Mecalac Groupe', 'Ahlmann'],
    categories: ['Heavy Equipment'],
    manualEntryReason:
      'Specialty European multi-purpose excavator/loader line configured for manual specification entry in North America.',
    extraExampleModels: ['6MCR', '8MCR', '10MCR', '9MWR', '15MWR'],
  }),
  assembleManualManufacturer({
    id: 'liugong',
    name: 'LiuGong',
    aliases: ['LiuGong North America', 'Guangxi LiuGong'],
    categories: ['Heavy Equipment'],
    manualEntryReason:
      'Regional export trim variations across North American dealer configurations; manual model/year/engine entry enabled.',
    extraExampleModels: ['9035E', '909ECR', '936F', '835H', '848H'],
  }),
  assembleManualManufacturer({
    id: 'mahindra',
    name: 'Mahindra',
    aliases: ['Mahindra Tractors', 'Mahindra USA'],
    categories: ['Heavy Equipment'],
    manualEntryReason:
      'Compact agricultural/utility tractor-loader line configured for manual model and specification entry.',
    extraExampleModels: ['1635 HST', '2645 Shuttle', '5145', '5155', '6065'],
  }),
];

// ============================================================================
// BUILD CATALOG PAYLOAD & RUN STRICT INVARIANT / SCHEMA / COMPATIBILITY CHECKS
// ============================================================================
const totalManufacturers = MANUFACTURERS.length;
const fullCatalogManufacturers = MANUFACTURERS.filter((m) => !m.manualEntryOnly).length;
const manualEntryManufacturers = MANUFACTURERS.filter((m) => m.manualEntryOnly).length;
let totalModels = 0;
let multiEngineModels = 0;
let totalEngineOptions = 0;

for (const mfr of MANUFACTURERS) {
  totalModels += mfr.models.length;
  for (const mdlObj of mfr.models) {
    if (mdlObj.engines.length >= 2) multiEngineModels += 1;
    totalEngineOptions += mdlObj.engines.length;
  }
}

const catalog = {
  schemaVersion: 2,
  generatedAt: GENERATED_AT,
  yearFloor: YEAR_FLOOR,
  yearCeiling: YEAR_CEILING,
  licensing: {
    prohibitedSourcesUsed: false,
    sources: [
      {
        id: 'nhtsa_vpic',
        name: 'US DOT NHTSA vPIC Vehicle Product Information Catalog API',
        license: 'US Federal Public Domain (17 U.S.C. § 105)',
        coverage: 'Highway trucks, commercial chassis, WMI prefixes, and highway trailer makes (1980–2026)',
      },
      {
        id: 'caltrans_eqp',
        name: 'California Department of Transportation (Caltrans) Labor Surcharge & Equipment Rental Rates',
        license: 'California State Public Domain Government Schedule',
        coverage: 'Heavy earthmoving, crane, compaction, trenching, and site-support equipment nomenclature & horsepower classes',
      },
      {
        id: 'epa_nonroad_hd',
        name: 'US EPA Nonroad Compression-Ignition, Spark-Ignition & Heavy-Duty Highway Engine Certification Data',
        license: 'US Federal Public Domain (17 U.S.C. § 105)',
        coverage: 'Diesel, gasoline, dual-fuel, natural-gas, and electric engine families, displacements, and power ratings',
      },
      {
        id: 'factual_oem_nomenclature',
        name: 'Uncopyrightable Factual OEM Model Designations, Production Spans & Powertrain Pairings',
        license: 'Public Facts (Feist Publications, Inc. v. Rural Telephone Service Co., 499 U.S. 340)',
        coverage: '1970–2026 generational model designations, production year spans, and factory engine/transmission options',
      },
    ],
    complianceStatement:
      'Compiled exclusively from US Federal and California State public-domain schedules plus uncopyrightable factual OEM model designations, production years, and engine pairings. Zero data was scraped or copied from restricted commercial spec portals.',
  },
  stats: {
    totalManufacturers,
    fullCatalogManufacturers,
    manualEntryManufacturers,
    totalModels,
    multiEngineModels,
    totalEngineOptions,
  },
  manufacturers: MANUFACTURERS,
};

function validateCatalog(cat) {
  const errors = [];
  if (cat.schemaVersion !== 2) errors.push(`Expected schemaVersion 2, got ${cat.schemaVersion}`);
  if (cat.yearFloor !== 1970 || cat.yearCeiling !== 2026) {
    errors.push(`Invalid year bounds: ${cat.yearFloor}..${cat.yearCeiling}`);
  }
  if (cat.licensing?.prohibitedSourcesUsed !== false) {
    errors.push('licensing.prohibitedSourcesUsed must be strictly false');
  }
  if (cat.stats.totalModels < 1200) {
    errors.push(`Expected >= 1200 total models, got ${cat.stats.totalModels}`);
  }

  const seenIds = new Set();
  const seenNames = new Set();
  const mfrByName = new Map();

  for (const mfr of cat.manufacturers) {
    if (!mfr.id || !/^[a-z0-9_]+$/.test(mfr.id)) {
      errors.push(`Invalid manufacturer id: ${mfr.id}`);
    }
    if (seenIds.has(mfr.id)) errors.push(`Duplicate manufacturer id: ${mfr.id}`);
    seenIds.add(mfr.id);

    if (!mfr.name) errors.push(`Missing manufacturer name for id ${mfr.id}`);
    if (seenNames.has(mfr.name.toLowerCase())) errors.push(`Duplicate manufacturer name: ${mfr.name}`);
    seenNames.add(mfr.name.toLowerCase());
    mfrByName.set(mfr.name, mfr);

    const shardBytes = Buffer.byteLength(JSON.stringify(mfr), 'utf8');
    if (shardBytes >= 500 * 1024) {
      errors.push(`Manufacturer shard ${mfr.id} exceeds 500 KB limit (${shardBytes} bytes)`);
    }

    if (!Array.isArray(mfr.categories) || mfr.categories.length === 0) {
      errors.push(`${mfr.name}: categories must be non-empty`);
    }
    for (const c of mfr.categories) {
      if (!ALLOWED_TYPES_BY_CATEGORY[c]) {
        errors.push(`${mfr.name}: unknown category "${c}"`);
      }
    }

    if (mfr.manualEntryOnly) {
      if (!mfr.manualEntryReason || typeof mfr.manualEntryReason !== 'string') {
        errors.push(`${mfr.name}: manualEntryOnly requires non-empty manualEntryReason`);
      }
      if (mfr.models.length !== 0) {
        errors.push(`${mfr.name}: manualEntryOnly manufacturer must have models: []`);
      }
      if (!Array.isArray(mfr.exampleModels) || mfr.exampleModels.length === 0) {
        errors.push(`${mfr.name}: manualEntryOnly manufacturer must have non-empty exampleModels`);
      }
    } else {
      if (mfr.manualEntryReason !== null) {
        errors.push(`${mfr.name}: full-catalog manufacturer must have manualEntryReason: null`);
      }
      if (mfr.models.length === 0) {
        errors.push(`${mfr.name}: full-catalog manufacturer has 0 models`);
      }
    }

    const modelNameSet = new Set();
    for (const mdlObj of mfr.models) {
      const mk = mdlObj.model.toLowerCase();
      if (modelNameSet.has(mk)) {
        errors.push(`${mfr.name}: duplicate model "${mdlObj.model}"`);
      }
      modelNameSet.add(mk);

      const allowedTypes = ALLOWED_TYPES_BY_CATEGORY[mdlObj.category];
      if (!allowedTypes) {
        errors.push(`${mfr.name} ${mdlObj.model}: invalid category "${mdlObj.category}"`);
      } else {
        if (!Array.isArray(mdlObj.productTypes) || mdlObj.productTypes.length === 0) {
          errors.push(`${mfr.name} ${mdlObj.model}: empty productTypes`);
        }
        for (const pt of mdlObj.productTypes) {
          if (!allowedTypes.includes(pt)) {
            errors.push(
              `${mfr.name} ${mdlObj.model}: productType "${pt}" not allowed in category "${mdlObj.category}"`,
            );
          }
        }
      }

      if (
        !Number.isInteger(mdlObj.yearFrom) ||
        !Number.isInteger(mdlObj.yearTo) ||
        mdlObj.yearFrom < YEAR_FLOOR ||
        mdlObj.yearTo > YEAR_CEILING ||
        mdlObj.yearFrom > mdlObj.yearTo
      ) {
        errors.push(
          `${mfr.name} ${mdlObj.model}: invalid year span ${mdlObj.yearFrom}..${mdlObj.yearTo}`,
        );
      }

      if (!Array.isArray(mdlObj.engines) || mdlObj.engines.length === 0) {
        errors.push(`${mfr.name} ${mdlObj.model}: must have at least 1 engine option`);
        continue;
      }

      for (const e of mdlObj.engines) {
        if (!e.label || !e.manufacturer || !e.engineModel || !e.fuelType || !e.transmission) {
          errors.push(`${mfr.name} ${mdlObj.model}: incomplete engine metadata (${JSON.stringify(e)})`);
        }
        if (typeof e.displacementL !== 'number' || !Number.isFinite(e.displacementL) || e.displacementL < 0) {
          errors.push(`${mfr.name} ${mdlObj.model}: invalid displacementL ${e.displacementL}`);
        }
        if (typeof e.powerHp !== 'number' || !Number.isFinite(e.powerHp) || e.powerHp <= 0) {
          errors.push(`${mfr.name} ${mdlObj.model}: invalid powerHp ${e.powerHp}`);
        }
        if (
          !Number.isInteger(e.yearFrom) ||
          !Number.isInteger(e.yearTo) ||
          e.yearFrom > e.yearTo ||
          e.yearFrom < mdlObj.yearFrom ||
          e.yearTo > mdlObj.yearTo
        ) {
          errors.push(
            `${mfr.name} ${mdlObj.model} [${e.engineModel}]: engine years ${e.yearFrom}..${e.yearTo} outside model years ${mdlObj.yearFrom}..${mdlObj.yearTo}`,
          );
        }
      }

      for (let y = mdlObj.yearFrom; y <= mdlObj.yearTo; y++) {
        const covered = mdlObj.engines.some((e) => y >= e.yearFrom && y <= e.yearTo);
        if (!covered) {
          errors.push(
            `${mfr.name} ${mdlObj.model}: year ${y} is not covered by any engine option (${mdlObj.yearFrom}..${mdlObj.yearTo})`,
          );
          break;
        }
      }
    }
  }

  // Backward compatibility checks against BOTH Dart equipmentBrandModels & legacy seed-marketplace.js
  for (const [sourceLabel, brandMap] of [
    ['oil_gas_marketplace.dart', DART_BRAND_MODELS],
    ['legacy seed-marketplace.js', LEGACY_SEED_BRANDS],
  ]) {
    for (const [brandName, requiredModels] of Object.entries(brandMap)) {
      const mfr = mfrByName.get(brandName);
      if (!mfr) {
        errors.push(`[${sourceLabel}] Missing manufacturer "${brandName}"`);
        continue;
      }
      if (mfr.manualEntryOnly) {
        const exSet = new Set(mfr.exampleModels.map((x) => x.toLowerCase()));
        for (const reqModel of requiredModels) {
          if (!exSet.has(reqModel.toLowerCase())) {
            errors.push(
              `[${sourceLabel}] Manual-entry OEM "${brandName}" missing required exampleModel "${reqModel}"`,
            );
          }
        }
      } else {
        const mdlSet = new Set(mfr.models.map((x) => x.model.toLowerCase()));
        for (const reqModel of requiredModels) {
          if (!mdlSet.has(reqModel.toLowerCase())) {
            errors.push(
              `[${sourceLabel}] Full-catalog OEM "${brandName}" missing required model "${reqModel}"`,
            );
          }
        }
      }
    }
  }

  if (errors.length > 0) {
    throw new Error(
      `Catalog validation failed with ${errors.length} error(s):\n  - ${errors.slice(0, 40).join('\n  - ')}`,
    );
  }
}

validateCatalog(catalog);

// ============================================================================
// WRITE JSON & CSV ARTIFACTS DETERMINISTICALLY
// ============================================================================
function csvEscape(val) {
  const s = val === null || val === undefined ? '' : String(val);
  if (/[",\r\n]/.test(s)) {
    return `"${s.replace(/"/g, '""')}"`;
  }
  return s;
}

const MANUAL_DEFAULT_PRIMARY_TYPE = {
  'Oilfield & Drilling': 'Drill Rig',
  'Oil & Gas Equipment': 'Wellhead',
  'Transport & Hauling': 'Lowboy Trailer',
  'Heavy Equipment': 'Excavator',
  'Site Support': 'Generator',
};

function buildCsv(cat) {
  const lines = [
    'brand,model,primary_type,category,year_from,year_to,engine_summary,manual_entry_only',
  ];
  for (const mfr of cat.manufacturers) {
    if (mfr.manualEntryOnly) {
      const primaryCategory = mfr.categories[0];
      const defaultType = MANUAL_DEFAULT_PRIMARY_TYPE[primaryCategory] || primaryCategory;
      for (const exModel of mfr.exampleModels) {
        lines.push(
          [
            mfr.name,
            exModel,
            defaultType,
            primaryCategory,
            '',
            '',
            '',
            'true',
          ]
            .map(csvEscape)
            .join(','),
        );
      }
    } else {
      for (const mdlObj of mfr.models) {
        const primaryType = mdlObj.productTypes[0];
        const engineSummary = mdlObj.engines
          .map((e) => `${e.manufacturer} ${e.engineModel} (${e.powerHp} HP)`)
          .join(' | ');
        lines.push(
          [
            mfr.name,
            mdlObj.model,
            primaryType,
            mdlObj.category,
            mdlObj.yearFrom,
            mdlObj.yearTo,
            engineSummary,
            'false',
          ]
            .map(csvEscape)
            .join(','),
        );
      }
    }
  }
  return `${lines.join('\n')}\n`;
}

const dataDir = path.join(ROOT_DIR, 'assets', 'data');
fs.mkdirSync(dataDir, { recursive: true });

const jsonOutPath = path.join(dataDir, 'equipment_catalog_50yr.json');
const csvOutPath = path.join(dataDir, 'equipment_catalog.csv');

const jsonPayload = `${JSON.stringify(catalog, null, 2)}\n`;
const csvPayload = buildCsv(catalog);

fs.writeFileSync(jsonOutPath, jsonPayload, 'utf8');
fs.writeFileSync(csvOutPath, csvPayload, 'utf8');

const maxShard = MANUFACTURERS.reduce((acc, m) => {
  const bytes = Buffer.byteLength(JSON.stringify(m), 'utf8');
  return bytes > acc.bytes ? { id: m.id, name: m.name, bytes } : acc;
}, { id: '', name: '', bytes: 0 });

console.log('================================================================');
console.log('PipeBuyer 50-Year Equipment Catalog Build Complete');
console.log('================================================================');
console.log(`Schema Version:             ${catalog.schemaVersion}`);
console.log(`Year Range:                 ${catalog.yearFloor}–${catalog.yearCeiling}`);
console.log(`Prohibited Sources Used:    ${catalog.licensing.prohibitedSourcesUsed}`);
console.log(`Total Manufacturers:        ${catalog.stats.totalManufacturers} (${catalog.stats.fullCatalogManufacturers} full + ${catalog.stats.manualEntryManufacturers} manual-entry)`);
console.log(`Total Catalog Models:       ${catalog.stats.totalModels}`);
console.log(`Multi-Engine Models:        ${catalog.stats.multiEngineModels}`);
console.log(`Total Engine Options:       ${catalog.stats.totalEngineOptions}`);
console.log(`Largest Firestore Shard:    ${maxShard.name} (${(maxShard.bytes / 1024).toFixed(1)} KB < 500.0 KB limit)`);
console.log(`JSON Output:                ${jsonOutPath} (${(Buffer.byteLength(jsonPayload, 'utf8') / 1024).toFixed(1)} KB)`);
console.log(`CSV Output:                 ${csvOutPath} (${(Buffer.byteLength(csvPayload, 'utf8') / 1024).toFixed(1)} KB)`);
console.log('All backward-compatibility, year-coverage, and schema assertions PASSED.');
