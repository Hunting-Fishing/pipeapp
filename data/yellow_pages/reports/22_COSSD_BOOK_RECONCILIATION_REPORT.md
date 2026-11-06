# Bot 22 — COSSD Book vs Live Directory Reconciliation

- **Generated**: `2026-11-06T02:50:42.064Z` (apply=true)
- **Transcribed listing rows**: **14,919** (overlap/duplicate rows inside the book transcription removed: 963)
- **Unique book listings compared**: **13,956** against **63,134** live directory entries

| Result | Count |
|---|---|
| duplicate_phone | 6,922 |
| new | 6,306 |
| review_same_name_region | 466 |
| duplicate_name_city | 158 |
| review_low_confidence | 79 |
| rejected_name | 11 |
| rejected_no_phone | 8 |
| duplicate_fuzzy | 2 |
| rejected_region | 2 |
| review_missing_city | 1 |
| duplicate_name_region_no_city | 1 |

`new` = no phone/name match anywhere -> published unverified. `review_same_name_region` = same company name already listed in that province/state (branch office or a single mis-read digit) -> **not** published, listed in `22_book_review.json`.
