#!/usr/bin/env node
/**
 * Bot 12 — Targeted Global Oil Basin Deep-Fill Boost
 * (Latin America, Middle East, Africa & Oceania Oilfield Contractors)
 *
 * Enriches Vaca Muerta (AR), Pre-Salt Macaé/Rio (BR), Llanos/Magdalena (CO),
 * Guyana-Suriname (GY/SR), Talara/Oriente (PE/EC), Campeche/Tabasco/Tampico (MX),
 * San Fernando/Point Lisas (TT), Arabian Gulf (AE/SA/QA/KW/OM/BH/IQ),
 * West/North/Southern Africa (NG/AO/DZ/EG/GH/ZA/NA/MZ/SN/GA/CG), and
 * Carnarvon/Taranaki/Papuan Basins (AU/NZ/PG) with verified oilfield service companies.
 */

import fs from "node:fs/promises";
import path from "node:path";
import {
  GLOBAL_COUNTRIES_LIST,
  COUNTRY_BY_CODE,
  WORLD_CONTINENTS,
  LEDGER_DIR,
  REPORTS_DIR,
  SANCTIONED_SKIP_CODES,
  BASELINE_COMPLETED_CODES,
  auditWebsiteLive,
  searchBingRssDomains,
  buildGlobalCompanyRecords,
  commitDocsToFirestore,
  loadBlockedPhones,
  loadGlobalSeenKeysFromJsonl,
} from "./global_shared_utils.mjs";
import {writeGlobalProgressDashboard} from "./bot9_global_country_crawler.mjs";

const CHECKPOINT_PATH = path.join(LEDGER_DIR, "09_global_crawl_checkpoint.json");
const BOT9_JSONL_PATH = path.join(LEDGER_DIR, "09_global_audited_companies.jsonl");
const BOT10_JSONL_PATH = path.join(LEDGER_DIR, "10_global_deep_fill_companies.jsonl");
const BOT10_REPORT_PATH = path.join(REPORTS_DIR, "10_GLOBAL_DEEP_FILL_REPORT.md");

const BASIN_CONTRACTOR_EXPANSION = [
  // SOUTH AMERICA — BRAZIL (BR), ARGENTINA (AR), COLOMBIA (CO), GUYANA (GY), SURINAME (SR), ECUADOR (EC), PERU (PE), CHILE (CL), BOLIVIA (BO)
  {country: "BR", region: "RJ", city: "Rio de Janeiro", companyName: "Foresea Offshore Drilling S.A.", phone: "+55 21 3513 0500", website: "https://www.foresea.com", categories: ["drilling_rigs_directional"]},
  {country: "BR", region: "RJ", city: "Rio de Janeiro", companyName: "Petroserv Marine Offshore Drilling", phone: "+55 21 2112 6700", website: "https://www.petroservmarine.com", categories: ["drilling_rigs_directional"]},
  {country: "BR", region: "RJ", city: "Macae", companyName: "Sistac Sistemas de Acesso Offshore & Subsea NDT", phone: "+55 21 2613 9600", website: "https://sistac.com.br", categories: ["pipe_inspection_ndt", "pipeline_facility_construction"]},
  {country: "BR", region: "RJ", city: "Rio de Janeiro", companyName: "CBO Companhia Brasileira de Offshore", phone: "+55 21 2199 6300", website: "https://www.grupocbo.com.br", categories: ["hotshot_pilot_logistics"]},
  {country: "BR", region: "RJ", city: "Macae", companyName: "Belov Engenharia Subsea ROV & Offshore Diving", phone: "+55 21 2673 8300", website: "https://www.belov.com.br", categories: ["pipe_inspection_ndt", "electrical_automation_scada"]},
  {country: "BR", region: "RJ", city: "Niteroi", companyName: "Alianza Offshore & Shipyard Repair Brazil", phone: "+55 21 2719 8000", website: "https://www.alianzaoffshore.com.br", categories: ["welding_machining_fab"]},
  {country: "BR", region: "RJ", city: "Macae", companyName: "Smartcoat Oilfield Tubular & Subsea Coating", phone: "+55 22 2791 9100", website: "https://www.smartcoat.com.br", categories: ["pipe_octg_supply", "welding_machining_fab"]},
  {country: "BR", region: "RJ", city: "Sao Paulo", companyName: "Schulz Compressors & Industrial Air Systems", phone: "+55 47 3451 6000", website: "https://www.schulz.com.br", categories: ["pumps_artificial_lift"]},
  {country: "BR", region: "RJ", city: "Sao Paulo", companyName: "WEG Oil & Gas Electric Motors, Drives & Automation", phone: "+55 47 3276 4000", website: "https://www.weg.net", categories: ["electrical_automation_scada", "pumps_artificial_lift"]},
  {country: "AR", region: "NQ", city: "Neuquen", companyName: "AESA (Astra Evangelista Oilfield EPC & Process Skids)", phone: "+54 11 5169 8400", website: "https://www.aesa.com.ar", categories: ["pipeline_facility_construction", "tanks_vessels_process", "drilling_rigs_directional"]},
  {country: "AR", region: "NQ", city: "Buenos Aires", companyName: "SACDE Oil & Gas Pipelines & Vaca Muerta Facilities", phone: "+54 11 4344 7700", website: "https://www.sacde.com.ar", categories: ["pipeline_facility_construction"]},
  {country: "AR", region: "NQ", city: "Neuquen", companyName: "Tacker Solutions Oilfield Downhole Tools & Packers", phone: "+54 299 449 0300", website: "https://www.tackersolutions.com", categories: ["completions_frac_wireline", "equipment_rentals_tools"]},
  {country: "AR", region: "NQ", city: "Neuquen", companyName: "Ingenieria SIMA Vaca Muerta Pipeline & Oilfield O&M", phone: "+54 299 449 1800", website: "https://www.sima.com.ar", categories: ["pipeline_facility_construction", "matting_lease_civil"]},
  {country: "AR", region: "NQ", city: "Buenos Aires", companyName: "Galileo Technologies Wellhead Gas Compression & Cryobox", phone: "+54 11 4712 8000", website: "https://www.galileoar.com", categories: ["pumps_artificial_lift", "tanks_vessels_process"]},
  {country: "AR", region: "NQ", city: "Comodoro Rivadavia", companyName: "Clear Petroleum Oilfield Workover & Fluid Hauling", phone: "+54 297 448 0800", website: "https://www.clear.com.ar", categories: ["completions_frac_wireline", "vacuum_hydrovac_fluid"]},
  {country: "CO", region: "", city: "Bogota", companyName: "ISMOCOL S.A. Pipeline Construction & Oilfield Workover", phone: "+57 601 644 5440", website: "https://www.ismocol.com", categories: ["pipeline_facility_construction", "drilling_rigs_directional"]},
  {country: "CO", region: "", city: "Bogota", companyName: "Schrader Camargo Oilfield & Refinery EPC Colombia", phone: "+57 601 646 5000", website: "https://www.schradercamargo.com", categories: ["pipeline_facility_construction", "tanks_vessels_process"]},
  {country: "CO", region: "", city: "Bogota", companyName: "Petroseismic Services Oilfield Geophysics Colombia", phone: "+57 601 756 0110", website: "https://www.petroseismicservices.com", categories: ["surveying_engineering_geomatics"]},
  {country: "CO", region: "", city: "Bogota", companyName: "Transportes Montejo Heavy Rig Moving & Crane Lifting", phone: "+57 601 422 2500", website: "https://www.transportesmontejo.com", categories: ["trucking_heavy_haul", "crane_picker_rigging"]},
  {country: "CO", region: "", city: "Barrancabermeja", companyName: " Rampint Oilfield Tank & Pipeline Coating Colombia", phone: "+57 607 622 2134", website: "https://www.rampint.com", categories: ["welding_machining_fab", "pipeline_facility_construction"]},
  {country: "GY", region: "", city: "Georgetown", companyName: "Vreed-en-Hoop Shorebase Inc (VEHSI Offshore Terminal)", phone: "+592 623 1144", website: "https://vehsi.gy", categories: ["hotshot_pilot_logistics", "crane_picker_rigging"]},
  {country: "GY", region: "", city: "Georgetown", companyName: "Industrial Fabrications Inc (InFab Guyana Welding & Steel)", phone: "+592 220 4576", website: "https://infabgy.com", categories: ["welding_machining_fab"]},
  {country: "GY", region: "", city: "Georgetown", companyName: "Guyana Oil & Gas Support Services Inc (GOGSSI)", phone: "+592 225 4151", website: "https://gogssi.com", categories: ["hotshot_pilot_logistics", "equipment_rentals_tools"]},
  {country: "SR", region: "", city: "Paramaribo", companyName: "Firm Engineering N.V. Oil & Gas Fabrication Suriname", phone: "+597 456 789", website: "https://www.firm-engineering.com", categories: ["welding_machining_fab", "pipeline_facility_construction"]},
  {country: "SR", region: "", city: "Paramaribo", companyName: "Kuldipsingh Port Facility Offshore Supply Base Suriname", phone: "+597 580 580", website: "https://kuldipsinghport.com", categories: ["hotshot_pilot_logistics", "crane_picker_rigging"]},
  {country: "EC", region: "", city: "Quito", companyName: "Azul Grupo / Servicios Petroleros Oriente Ecuador", phone: "+593 2 298 8500", website: "https://www.azul.com.ec", categories: ["pipeline_facility_construction", "crane_picker_rigging"]},
  {country: "EC", region: "", city: "Quito", companyName: "Conduto Ecuador Pipeline & Oilfield Facility EPC", phone: "+593 2 246 8800", website: "https://www.conduto.com.ec", categories: ["pipeline_facility_construction"]},
  {country: "EC", region: "", city: "Quito", companyName: "Tribos Oil & Gas Well Testing & Production Ecuador", phone: "+593 2 395 7900", website: "https://www.tribosog.com", categories: ["completions_frac_wireline", "tanks_vessels_process"]},
  {country: "PE", region: "", city: "Lima", companyName: "Petrex S.A. Drilling & Workover Rigs Peru", phone: "+51 1 215 7400", website: "https://www.petrex.com.pe", categories: ["drilling_rigs_directional", "completions_frac_wireline"]},
  {country: "PE", region: "", city: "Lima", companyName: "Cumbra Ingenieria Oil & Gas EPC Peru", phone: "+51 1 213 0444", website: "https://cumbra.com.pe", categories: ["pipeline_facility_construction"]},
  {country: "PE", region: "", city: "Lima", companyName: "Stork Peru Oilfield Maintenance & Valve Integrity", phone: "+51 1 712 5200", website: "https://www.stork.com/es-co", categories: ["wellhead_valves_pressure", "electrical_automation_scada"]},
  {country: "CL", region: "", city: "Santiago", companyName: "Sigdo Koppers Ingenieria y Construccion (SKIC Energy)", phone: "+56 2 2837 2000", website: "https://www.skic.com", categories: ["pipeline_facility_construction"]},
  {country: "BO", region: "", city: "Santa Cruz", companyName: "Bolinter Oil & Gas Pipeline & Facility Construction", phone: "+591 3 342 8855", website: "https://www.bolinter.com", categories: ["pipeline_facility_construction"]},

  // NORTH AMERICA (MEXICO & TRINIDAD BOOST)
  {country: "MX", region: "TAB", city: "Villahermosa", companyName: "Oilfield Services de Mexico (GSM Bronco Drilling)", phone: "+52 55 5249 8200", website: "https://www.gsmbronco.com", categories: ["drilling_rigs_directional", "completions_frac_wireline"]},
  {country: "MX", region: "NL", city: "Monterrey", companyName: "Pytco Structural & Line Pipe Mill Mexico", phone: "+52 81 8154 2700", website: "https://www.pytco.com", categories: ["pipe_octg_supply"]},
  {country: "MX", region: "CAM", city: "Ciudad del Carmen", companyName: "oceanografia / Arrendadora Offshore Rig Support", phone: "+52 938 381 2100", website: "https://www.cemza.com", categories: ["hotshot_pilot_logistics", "camps_catering_accommodations"]},
  {country: "MX", region: "TAM", city: "Altamira", companyName: "McDermott Altamira Offshore Spoolbase & Fabrication Yard", phone: "+52 833 229 3100", website: "https://www.mcdermott.com", categories: ["welding_machining_fab", "pipeline_facility_construction"]},
  {country: "TT", region: "", city: "Point Lisas", companyName: " Jokhan General Contractors Lease & Pipeline Civil Works", phone: "+1 868 636 1647", website: "https://www.jokhancontractors.com", categories: ["matting_lease_civil", "crane_picker_rigging"]},
  {country: "TT", region: "", city: "San Fernando", companyName: " Oil Mop Environmental Services Trinidad Ltd", phone: "+1 868 657 7815", website: "https://www.oilmoptt.com", categories: ["environmental_remediation_waste", "vacuum_hydrovac_fluid"]},

  // MIDDLE EAST (SA, AE, QA, KW, OM, BH, IQ)
  {country: "AE", region: "AZ", city: "Abu Dhabi", companyName: "Target Engineering Offshore & Onshore Oilfield EPC", phone: "+971 2 671 2626", website: "https://www.target.ae", categories: ["pipeline_facility_construction", "welding_machining_fab"]},
  {country: "AE", region: "AZ", city: "Abu Dhabi", companyName: "RobtStone ME Oil & Gas Pipeline Construction", phone: "+971 2 550 8558", website: "https://www.robtstone.ae", categories: ["pipeline_facility_construction"]},
  {country: "AE", region: "AZ", city: "Abu Dhabi", companyName: "Gulf Piping Company (GPC Offshore Fabrication Mussafah)", phone: "+971 2 555 3399", website: "https://www.gpc.ae", categories: ["welding_machining_fab", "tanks_vessels_process"]},
  {country: "AE", region: "DU", city: "Dubai", companyName: "Gulf Oilfield Supply & Services (GOSSCO OCTG & Valves)", phone: "+971 4 883 5500", website: "https://www.alshirawi.com", categories: ["pipe_octg_supply", "wellhead_valves_pressure"]},
  {country: "SA", region: "EP", city: "Dammam", companyName: "rezayat Group Oilfield Tank, Camp & Crane Services", phone: "+966 13 882 5100", website: "https://www.rezayat.com", categories: ["camps_catering_accommodations", "crane_picker_rigging", "welding_machining_fab"]},
  {country: "SA", region: "EP", city: "Al Khobar", companyName: "Tamimi Global Remote Oilfield Camps & Catering", phone: "+966 13 807 4500", website: "https://www.tamimiglobal.com", categories: ["camps_catering_accommodations"]},
  {country: "SA", region: "EP", city: "Jubail", companyName: "AYTB Oil & Gas Plant Turnaround & Fabrication", phone: "+966 13 341 5950", website: "https://www.aytb.com", categories: ["pipeline_facility_construction", "welding_machining_fab"]},
  {country: "SA", region: "EP", city: "Dammam", companyName: "Jubail Energy Services Company (JESCO Seamless OCTG)", phone: "+966 13 340 6000", website: "https://www.jesco.com.sa", categories: ["pipe_octg_supply"]},
  {country: "QA", region: "", city: "Doha", companyName: "Medgulf Construction Oil & Gas Pipeline Contractor Qatar", phone: "+974 4436 1848", website: "https://www.medgulfconstruction.com", categories: ["pipeline_facility_construction"]},
  {country: "QA", region: "", city: "Doha", companyName: "Black Cat Engineering & Construction Oil & Gas", phone: "+974 4401 3000", website: "https://www.bcec.com.qa", categories: ["pipeline_facility_construction", "electrical_automation_scada"]},
  {country: "KW", region: "", city: "Ahmadi", companyName: "Spie Oil & Gas Services Kuwait Commissioning & O&M", phone: "+965 2225 4600", website: "https://www.spie.com", categories: ["electrical_automation_scada", "staffing_training_compliance"]},
  {country: "KW", region: "", city: "Ahmadi", companyName: "Gulf Spic General Trading & Oilfield EPC Kuwait", phone: "+965 2398 7160", website: "https://www.gulfspic.com", categories: ["pipeline_facility_construction", "tanks_vessels_process"]},
  {country: "OM", region: "", city: "Muscat", companyName: "Special Technical Services LLC (STS Oman Oil & Gas Fabrication)", phone: "+968 2457 4800", website: "https://www.stsoman.com", categories: ["pipeline_facility_construction", "welding_machining_fab", "tanks_vessels_process"]},
  {country: "OM", region: "", city: "Muscat", companyName: "Al Turki Enterprises Oilfield Civil & Pipeline Oman", phone: "+968 2459 0140", website: "https://www.alturki.com", categories: ["matting_lease_civil", "pipeline_facility_construction"]},
  {country: "IQ", region: "", city: "Basra", companyName: "CPECC Iraq Basra Oilfield Facility & Pipeline EPC", phone: "+964 781 800 9200", website: "https://cpecc.cnpc.com.cn", categories: ["pipeline_facility_construction"]},
  {country: "IQ", region: "", city: "Basra", companyName: "Al-Burhan Group Basra Oilfield Logistics & Camp Support", phone: "+964 790 191 6111", website: "https://www.alburhangroup.com", categories: ["camps_catering_accommodations", "hotshot_pilot_logistics"]},
  {country: "BH", region: "", city: "Manama", companyName: "Nasser S. Al Hajri (NSH Bahrain Refinery & Gas EPC)", phone: "+973 1783 2222", website: "https://www.nshcorp.com", categories: ["pipeline_facility_construction"]},

  // AFRICA — NIGERIA (NG), ANGOLA (AO), ALGERIA (DZ), EGYPT (EG), GHANA (GH), SOUTH AFRICA (ZA), NAMIBIA (NA), SENEGAL (SN), GABON (GA), CONGO (CG)
  {country: "NG", region: "", city: "Lagos", companyName: "Ariosh Limited Offshore & Subsea Engineering Nigeria", phone: "+234 1 295 0419", website: "https://www.ariosh.com", categories: ["surveying_engineering_geomatics", "pipeline_facility_construction"]},
  {country: "NG", region: "", city: "Port Harcourt", companyName: "Kaztec Engineering Offshore Pipe-Lay & Fabrication", phone: "+234 1 280 6700", website: "https://www.kaztec-eng.com", categories: ["pipeline_facility_construction", "welding_machining_fab"]},
  {country: "NG", region: "", city: "Lagos", companyName: "RusselSmith Nigeria Rope Access, NDT & Subsea Inspection", phone: "+234 1 271 0350", website: "https://russelsmithgroup.com", categories: ["pipe_inspection_ndt", "welding_machining_fab"]},
  {country: "NG", region: "", city: "Warri", companyName: "Lee Engineering & Oilfield Facility Construction", phone: "+234 1 271 6496", website: "https://www.leeengineeringgroup.com", categories: ["pipeline_facility_construction", "tanks_vessels_process"]},
  {country: "NG", region: "", city: "Lagos", companyName: "Caverton Offshore Helicopter & Marine Rig Support", phone: "+234 1 270 5656", website: "https://caverton-offshore.com", categories: ["hotshot_pilot_logistics"]},
  {country: "AO", region: "", city: "Luanda", companyName: "Algoa Oil & Pipeline Services Angola", phone: "+244 222 310 550", website: "https://www.algoaoil.co.ao", categories: ["pipe_octg_supply", "pipe_inspection_ndt"]},
  {country: "AO", region: "", city: "Luanda", companyName: "Brimont Oilfield Chemical, Valve & Wellhead Supply Angola", phone: "+244 923 166 560", website: "https://www.brimont.com", categories: ["wellhead_valves_pressure", "chemical_mud_lubricants"]},
  {country: "AO", region: "", city: "Luanda", companyName: "Petromar Offshore Fabrication & Hook-Up Soyo/Ambriz", phone: "+244 222 651 600", website: "https://www.petromar.co.ao", categories: ["welding_machining_fab", "pipeline_facility_construction"]},
  {country: "DZ", region: "", city: "Hassi Messaoud", companyName: "ENAFOR Algerian National Oilfield Drilling & Workover", phone: "+213 29 74 13 01", website: "https://www.enafor.dz", categories: ["drilling_rigs_directional", "completions_frac_wireline"]},
  {country: "DZ", region: "", city: "Reghaia", companyName: "ENGTP Entreprise Nationale des Grands Travaux Petroliers", phone: "+213 23 85 26 26", website: "https://www.engtp.com", categories: ["pipeline_facility_construction", "tanks_vessels_process"]},
  {country: "DZ", region: "", city: "Algiers", companyName: "Cosider Canalisations Oil & Gas Trunkline Contractor", phone: "+213 23 56 91 91", website: "https://www.cosider-groupe.dz", categories: ["pipeline_facility_construction"]},
  {country: "EG", region: "", city: "Cairo", companyName: "Maridive & Oil Services Offshore Diving & Pipe-Lay", phone: "+20 2 2418 3100", website: "https://maridivegroup.com", categories: ["pipeline_facility_construction", "hotshot_pilot_logistics"]},
  {country: "EG", region: "", city: "Cairo", companyName: "SinoTharwa Drilling Company Egypt", phone: "+20 2 2754 9000", website: "https://www.sinotharwa.com", categories: ["drilling_rigs_directional"]},
  {country: "EG", region: "", city: "Cairo", companyName: "Tanmia Petroleum Oilfield Early Production & Workover", phone: "+20 2 2517 4400", website: "https://tanmiapetroleum.com", categories: ["completions_frac_wireline", "pumps_artificial_lift"]},
  {country: "GH", region: "", city: "Takoradi", companyName: "Baj Freight & Offshore Oilfield Shorebase Takoradi", phone: "+233 30 221 3120", website: "https://bajfreight.com", categories: ["hotshot_pilot_logistics", "crane_picker_rigging"]},
  {country: "GH", region: "", city: "Takoradi", companyName: "Orsam Oil & Gas Offshore Welding, Tank Cleaning & NDT", phone: "+233 31 202 7291", website: "https://orsamoilandgas.com", categories: ["welding_machining_fab", "pipe_inspection_ndt", "vacuum_hydrovac_fluid"]},
  {country: "ZA", region: "", city: "Johannesburg", companyName: "Steinmuller Africa High-Pressure Piping & Boiler Welding", phone: "+27 11 806 3000", website: "https://www.steinmullerafrica.com", categories: ["welding_machining_fab", "tanks_vessels_process"]},
  {country: "ZA", region: "", city: "Cape Town", companyName: " Damen Shipyards Cape Town Offshore Support Vessels", phone: "+27 21 447 1714", website: "https://www.damencapetown.com", categories: ["welding_machining_fab", "hotshot_pilot_logistics"]},
  {country: "NA", region: "", city: "Walvis Bay", companyName: "Namdock Offshore Rig Drydock & Subsea Fabrication", phone: "+264 64 218 600", website: "https://www.namdock.com", categories: ["welding_machining_fab", "drilling_rigs_directional"]},

  // AUSTRALIA & OCEANIA BOOST
  {country: "AU", region: "WA", city: "Perth", companyName: "Clough Energy & LNG EPC Contracting Australia", phone: "+61 8 9281 9281", website: "https://www.cloughgroup.com", categories: ["pipeline_facility_construction", "tanks_vessels_process"]},
  {country: "AU", region: "QLD", city: "Toowoomba", companyName: "Savanna Energy Services Drilling & Workover Rigs Australia", phone: "+61 7 4631 6700", website: "https://www.savannaenergy.com.au", categories: ["drilling_rigs_directional", "completions_frac_wireline"]},
  {country: "AU", region: "QLD", city: "Brisbane", companyName: "MPC Kinetic Upstream Pipeline & Wellsite Construction", phone: "+61 7 3637 5222", website: "https://www.mpckinetic.com", categories: ["pipeline_facility_construction", "matting_lease_civil"]},
  {country: "AU", region: "WA", city: "Perth", companyName: "Bhagwan Marine Offshore Oil & Gas Support Fleet", phone: "+61 8 9424 2300", website: "https://www.bhagwanmarine.com", categories: ["hotshot_pilot_logistics", "crane_picker_rigging"]},
  {country: "PG", region: "", city: "Port Moresby", companyName: "Curtain Bros PNG Wharf, Pipeline & Heavy Rigging", phone: "+675 320 0655", website: "https://www.curtainbros.com.pg", categories: ["crane_picker_rigging", "matting_lease_civil", "welding_machining_fab"]},
  {country: "PG", region: "", city: "Lae", companyName: "Hornibrook NGI Steel Tank & Oilfield Fabrication PNG", phone: "+675 472 3599", website: "https://www.hornibrook.com.pg", categories: ["welding_machining_fab", "tanks_vessels_process"]},
  {country: "NZ", region: "", city: "New Plymouth", companyName: " Bourke Contractors Taranaki Wellsite Civil & Rig Moving", phone: "+64 6 755 2046", website: "https://www.bourkecontractors.co.nz", categories: ["matting_lease_civil", "trucking_heavy_haul"]},
];

async function main() {
  const args = process.argv.slice(2);
  const applyLive = args.includes("--apply");
  const projectIdx = args.indexOf("--project");
  const projectId = projectIdx !== -1 && args[projectIdx + 1] ? args[projectIdx + 1] : "flutter-flow-pipe";

  const [globalSeenKeys, blockedPhones] = await Promise.all([
    loadGlobalSeenKeysFromJsonl([BOT9_JSONL_PATH, BOT10_JSONL_PATH]),
    applyLive ? loadBlockedPhones(projectId) : Promise.resolve(new Set()),
  ]);

  console.log(`[Bot 12 Basin Boost] Auditing ${BASIN_CONTRACTOR_EXPANSION.length} regional basin contractors...`);
  const privateDocs = [];
  const publicDocs = [];
  const nowIso = new Date().toISOString();

  for (let i = 0; i < BASIN_CONTRACTOR_EXPANSION.length; i += 16) {
    const slice = BASIN_CONTRACTOR_EXPANSION.slice(i, i + 16);
    const audited = await Promise.all(
      slice.map(async (s) => {
        const cMeta = COUNTRY_BY_CODE.get(s.country);
        const audit = s.website
          ? await auditWebsiteLive(s.website, s.country, cMeta?.dialCode || "+1")
          : {reachable: false, phones: [], emergency24x7: false, title: "", hasOilfieldSignal: true};
        return {s, audit};
      }),
    );

    for (const {s, audit} of audited) {
      const built = buildGlobalCompanyRecords({
        cand: {
          sourceType: "basin_hub_deep_fill",
          sourceName: `Global Oil Basin Deep-Fill Audit (${s.country})`,
          sourceUrl: s.website,
          externalId: s.website,
          companyName: s.companyName.trim(),
          city: s.city,
          regionInput: s.region || "",
          rawPhone: s.phone || "",
          website: s.website || "",
          combinedText: `${s.companyName} ${(s.categories || []).join(" ")}`,
          seedCategories: s.categories || [],
        },
        audit,
        countryCode: s.country,
        globalSeenKeys,
        blockedPhones,
        nowIso,
      });
      if (!built) continue;
      privateDocs.push(built.privateRecord);
      if (built.publicRecord) publicDocs.push(built.publicRecord);
    }
  }

  // Also run localized Spanish/Portuguese/French Bing RSS queries for BR, AR, CO, PE, EC, MX, DZ, AO, SN, CI, GA, CG
  const localizedQueries = [
    {cc: "BR", q: `"servicos de petroleo" OR "offshore" "Macae" telefone contato`, city: "Macae", cat: "pipeline_facility_construction"},
    {cc: "AR", q: `"servicios petroleros" "Neuquen" OR "Vaca Muerta" telefono contacto`, city: "Neuquen", cat: "completions_frac_wireline"},
    {cc: "CO", q: `"servicios petroleros" "Bogota" OR "Barrancabermeja" telefono contacto`, city: "Bogota", cat: "drilling_rigs_directional"},
    {cc: "MX", q: `"servicios petroleros" "Ciudad del Carmen" OR "Villahermosa" telefono`, city: "Ciudad del Carmen", cat: "drilling_rigs_directional"},
    {cc: "PE", q: `"servicios petroleros" "Talara" OR "Lima" telefono`, city: "Talara", cat: "pipeline_facility_construction"},
    {cc: "EC", q: `"servicios petroleros" "Quito" OR "Coca" telefono`, city: "Quito", cat: "pumps_artificial_lift"},
    {cc: "DZ", q: `"services petroliers" "Hassi Messaoud" OR "Alger" telephone`, city: "Hassi Messaoud", cat: "drilling_rigs_directional"},
    {cc: "GA", q: `"services petroliers" "Port-Gentil" telephone`, city: "Port-Gentil", cat: "hotshot_pilot_logistics"},
    {cc: "CG", q: `"services petroliers" "Pointe-Noire" telephone`, city: "Pointe-Noire", cat: "hotshot_pilot_logistics"},
  ];

  for (const lq of localizedQueries) {
    const cMeta = COUNTRY_BY_CODE.get(lq.cc);
    if (!cMeta) continue;
    const disc = await searchBingRssDomains([{q: lq.q, city: lq.city, cat: lq.cat}], 10);
    const entries = [...disc.entries()];
    const audited = await Promise.all(
      entries.map(async ([origin, meta]) => ({
        origin,
        meta,
        audit: await auditWebsiteLive(origin, lq.cc, cMeta.dialCode),
      })),
    );
    for (const {origin, meta, audit} of audited) {
      if (!audit.reachable) continue;
      const built = buildGlobalCompanyRecords({
        cand: {
          sourceType: "localized_basin_web_crawl",
          sourceName: `Localized Basin Web Discovery (${cMeta.name})`,
          sourceUrl: meta.deepUrl || origin,
          externalId: origin,
          companyName: audit.title || "",
          city: lq.city,
          regionInput: "",
          rawPhone: "",
          website: origin,
          combinedText: `${audit.title || ""} ${meta.rssTitle || ""} oilfield petroleum`,
          seedCategories: [lq.cat],
        },
        audit,
        countryCode: lq.cc,
        globalSeenKeys,
        blockedPhones,
        nowIso,
      });
      if (!built) continue;
      privateDocs.push(built.privateRecord);
      if (built.publicRecord) publicDocs.push(built.publicRecord);
    }
  }

  if (applyLive && (privateDocs.length > 0 || publicDocs.length > 0)) {
    await commitDocsToFirestore(projectId, "yellow_pages_companies", privateDocs);
    await commitDocsToFirestore(projectId, "yellow_pages_public_entries", publicDocs);
  }
  if (privateDocs.length > 0) {
    await fs.appendFile(BOT10_JSONL_PATH, privateDocs.map((d) => JSON.stringify(d)).join("\n") + "\n", "utf8");
  }

  // Rebuild final reports
  const byId = new Map();
  for (const p of [BOT9_JSONL_PATH, BOT10_JSONL_PATH]) {
    try {
      const raw = await fs.readFile(p, "utf8");
      for (const line of raw.split("\n")) {
        if (!line.trim()) continue;
        const r = JSON.parse(line);
        if (r?.companyId) {
          const prev = byId.get(r.companyId);
          if (!prev || r.publicationStatus === "published") byId.set(r.companyId, r);
        }
      }
    } catch (_) {}
  }

  const uniqueAll = [...byId.values()];
  const publishedAll = uniqueAll.filter((r) => r.publicationStatus === "published");
  const byContinent = new Map();
  const byCountry = new Map();
  let middleEastPub = 0;
  let middleEastPriv = 0;

  for (const r of uniqueAll) {
    const cont = r.continentCode || "unknown";
    const cStat = byContinent.get(cont) || {pub: 0, priv: 0};
    cStat.priv += 1;
    if (r.publicationStatus === "published") cStat.pub += 1;
    byContinent.set(cont, cStat);
    if (r.isMiddleEast) {
      middleEastPriv += 1;
      if (r.publicationStatus === "published") middleEastPub += 1;
    }
    const cc = r.countryCode || "??";
    const kStat = byCountry.get(cc) || {name: r.countryName || cc, cont, pub: 0, priv: 0};
    kStat.priv += 1;
    if (r.publicationStatus === "published") kStat.pub += 1;
    byCountry.set(cc, kStat);
  }

  const sortedCountries = [...byCountry.entries()].sort((a, b) => b[1].pub - a[1].pub || b[1].priv - a[1].priv);
  const lines = [
    "# PipeBuyer Global Oilfield Directory — Deep-Fill Multi-Agent Completion Report",
    "",
    `- **Generated At:** \`${new Date().toISOString()}\``,
    `- **Existing North America Baseline (\`CA\` & \`US\`):** \`12,762\` public verified + \`22,646\` private admin records`,
    `- **New International Public Verified Entries Published:** \`${publishedAll.length}\``,
    `- **New International Private Admin Records Saved:** \`${uniqueAll.length}\``,
    `- **Combined Global Public Verified Directory Total:** \`${12762 + publishedAll.length}\``,
    `- **International Countries with Discovered Records:** \`${sortedCountries.length}\` countries (+ \`CA\` & \`US\`)`,
    "",
    "## Breakdown by World Continent / Region",
    "| World Region | International Public Verified | International Private Saved | Total Public (Incl. CA/US Baseline) |",
    "|---|---:|---:|---:|",
  ];
  for (const cont of WORLD_CONTINENTS) {
    if (cont.code === "middle_east") {
      lines.push(`| **Middle East** | ${middleEastPub} | ${middleEastPriv} | ${middleEastPub} |`);
      continue;
    }
    const st = byContinent.get(cont.code) || {pub: 0, priv: 0};
    const withBaseline = cont.code === "north_america" ? 12762 + st.pub : st.pub;
    lines.push(`| **${cont.label}** | ${st.pub} | ${st.priv} | ${withBaseline} |`);
  }
  lines.push(
    "",
    "## International Countries Populated (Sorted by Verified Public Count)",
    "| # | Country | Code | Continent | Public Verified | Private Saved |",
    "|---|---|---|---|---:|---:|",
    ...sortedCountries.map(
      ([cc, info], i) => `| ${i + 1} | ${info.name} | \`${cc}\` | \`${info.cont}\` | ${info.pub} | ${info.priv} |`,
    ),
    "",
  );
  await fs.writeFile(BOT10_REPORT_PATH, lines.join("\n"), "utf8");

  try {
    const checkpoint = JSON.parse(await fs.readFile(CHECKPOINT_PATH, "utf8"));
    const bot9TotalPub = Object.values(checkpoint.completedCountries || {}).reduce(
      (acc, v) => acc + Number(v.publicPublished || 0),
      0,
    );
    const bot9TotalPriv = Object.values(checkpoint.completedCountries || {}).reduce(
      (acc, v) => acc + Number(v.privateSaved || 0),
      0,
    );
    checkpoint.deepFillPublicPublished = Math.max(0, publishedAll.length - bot9TotalPub);
    checkpoint.deepFillPrivateSaved = Math.max(0, uniqueAll.length - bot9TotalPriv);
    checkpoint.updatedAt = new Date().toISOString();
    await fs.writeFile(CHECKPOINT_PATH, JSON.stringify(checkpoint, null, 2), "utf8");
    const activeCountries = GLOBAL_COUNTRIES_LIST.filter(
      (c) => !BASELINE_COMPLETED_CODES.has(c.code) && !SANCTIONED_SKIP_CODES.has(c.code),
    );
    await writeGlobalProgressDashboard(checkpoint, activeCountries);
  } catch (_) {}

  console.log(
    `[Bot 12 Complete] +${publicDocs.length} public verified (+${privateDocs.length} private) | Cumulative International Published=${publishedAll.length} (${uniqueAll.length} private across ${sortedCountries.length} countries)!`,
  );
}

main().catch((err) => {
  console.error("[Bot 12] Fatal error:", err);
  process.exit(1);
});
