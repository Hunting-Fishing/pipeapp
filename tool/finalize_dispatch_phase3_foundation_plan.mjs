import fs from 'node:fs';

const path = 'docs/DISPATCH_NETWORK_MASTER_PLAN.md';
let source = fs.readFileSync(path, 'utf8');

const replacements = [
  ['**Current verified completion:** **41%**', '**Current verified completion:** **45%**'],
  ['| 3 | Provider/company profile system | 15 | 4 | IN PROGRESS |', '| 3 | Provider/company profile system | 15 | 8 | IN PROGRESS |'],
  ['| **TOTAL** |  | **100** | **41** | **41% COMPLETE** |', '| **TOTAL** |  | **100** | **45** | **45% COMPLETE** |'],
  ['**Current verified:** 4/15', '**Current verified:** 8/15'],
  ['- [ ] Company identity/public profile model. **2 pts**', '- [x] Company identity/public profile model. **2 pts**'],
  ['- [ ] Multi-service structured selection. **2 pts**', '- [x] Multi-service structured selection. **2 pts**'],
  ['**These prepared items do not earn additional official points until the local Phase 3 foundation gate passes.**', '**Phase 3 foundation gate passed locally on 2026-08-17. Company identity and structured multi-service selection are now verified.**'],
];

for (const [before, after] of replacements) {
  if (source.includes(after)) continue;
  if (!source.includes(before)) {
    throw new Error(`Master plan status anchor missing: ${before}`);
  }
  source = source.replace(before, after);
}

fs.writeFileSync(path, source, 'utf8');
console.log('Dispatch master plan advanced to 45% after the verified Phase 3 foundation gate.');
