"""Generates the 1,000-item PipeBuyer Store Master Catalog (.CSV + multi-tab .XLSX)."""

from __future__ import annotations

import csv
import re
import urllib.parse
import zipfile
from pathlib import Path
from xml.sax.saxutils import escape

from shop_catalog_data import CATEGORIES, STARTER_ITEMS, SUBCATEGORY_CATALOG
from shop_catalog_data_part2 import SUBCATEGORY_CATALOG_PART2
from shop_catalog_data_part3 import EXTRA_WRENCH_ITEMS, SUBCATEGORY_CATALOG_PART3
from shop_catalog_data_part4 import SUBCATEGORY_CATALOG_PART4
from shop_catalog_data_part5 import SUBCATEGORY_CATALOG_PART5

HEADERS = [
    "item_id",
    "category_code",
    "category_name",
    "subcategory",
    "title",
    "brand",
    "amazon_search_helper_url",
    "amazon_affiliate_link",
    "image_url",
    "asin",
    "source_type",
    "featured",
    "priority_rank",
    "badge_text",
    "description",
    "highlights",
]


def _slugify(text: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return slug[:56].rstrip("-")


def _col_letter(idx_zero: int) -> str:
    res = ""
    n = idx_zero + 1
    while n > 0:
        n, rem = divmod(n - 1, 26)
        res = chr(65 + rem) + res
    return res


def build_1000_rows() -> tuple[list[dict[str, str]], list[tuple[str, str, str, int]]]:
    pool: dict[str, list[tuple[str, str, str, str, str]]] = {}
    for src in (
        SUBCATEGORY_CATALOG,
        SUBCATEGORY_CATALOG_PART2,
        SUBCATEGORY_CATALOG_PART3,
        SUBCATEGORY_CATALOG_PART4,
        SUBCATEGORY_CATALOG_PART5,
    ):
        for k, v in src.items():
            pool.setdefault(k, []).extend(v)
    pool["Heavy Wrenches, Ratchets & Torque Tools"].extend(EXTRA_WRENCH_ITEMS)

    starters_by_sub: dict[str, list[dict]] = {}
    for item in STARTER_ITEMS:
        starters_by_sub.setdefault(item["subcategory"], []).append(item)

    rows: list[dict[str, str]] = []
    summary: list[tuple[str, str, str, int]] = []
    used_ids: set[str] = set()
    seq = 25

    for cat in CATEGORIES:
        cat_code = cat["code"]
        cat_name = cat["name"]
        total_cat = cat["target"]
        subs = cat["subcategories"]
        base_q, rem = divmod(total_cat, len(subs))

        for s_idx, sub in enumerate(subs):
            sub_target = base_q + (1 if s_idx < rem else 0)
            sub_rows: list[dict[str, str]] = []

            for st in starters_by_sub.get(sub, []):
                q = urllib.parse.quote_plus(f"{st['brand']} {st['title']}")
                used_ids.add(st["id"])
                sub_rows.append({
                    "item_id": st["id"],
                    "category_code": cat_code,
                    "category_name": cat_name,
                    "subcategory": sub,
                    "title": st["title"],
                    "brand": st["brand"],
                    "amazon_search_helper_url": f"https://www.amazon.com/s?k={q}",
                    "amazon_affiliate_link": "",
                    "image_url": "",
                    "asin": "",
                    "source_type": "amazon_affiliate",
                    "featured": "TRUE" if st["featured"] else "FALSE",
                    "priority_rank": str(st["priority_rank"]),
                    "badge_text": st["badge_text"],
                    "description": st["description"],
                    "highlights": st["highlights"],
                })

            candidates = pool.get(sub, [])
            needed = sub_target - len(sub_rows)
            if len(candidates) < needed:
                raise RuntimeError(
                    f"Subcategory '{sub}' only has {len(candidates)} candidates, needs {needed}"
                )

            for c_idx, (brand, title, badge, desc, specs) in enumerate(candidates[:needed]):
                item_id = f"pb-{seq:04d}-{_slugify(title)}"
                while item_id in used_ids:
                    seq += 1
                    item_id = f"pb-{seq:04d}-{_slugify(title)}"
                used_ids.add(item_id)
                q = urllib.parse.quote_plus(f"{brand} {title}")
                is_feat = c_idx == 0 and len(starters_by_sub.get(sub, [])) == 0
                sub_rows.append({
                    "item_id": item_id,
                    "category_code": cat_code,
                    "category_name": cat_name,
                    "subcategory": sub,
                    "title": title,
                    "brand": brand,
                    "amazon_search_helper_url": f"https://www.amazon.com/s?k={q}",
                    "amazon_affiliate_link": "",
                    "image_url": "",
                    "asin": "",
                    "source_type": "amazon_affiliate",
                    "featured": "TRUE" if is_feat else "FALSE",
                    "priority_rank": str(40 + len(rows) + len(sub_rows)),
                    "badge_text": badge,
                    "description": desc,
                    "highlights": specs,
                })
                seq += 1

            rows.extend(sub_rows)
            summary.append((cat_code, cat_name, sub, len(sub_rows)))

    assert len(rows) == 1000, f"Expected 1000 rows, got {len(rows)}"
    assert len({r["item_id"] for r in rows}) == 1000, "Duplicate item_id detected"
    return rows, summary


def _xml_cell(ref: str, value: str, style: int = 0, is_num: bool = False, formula: str = "") -> str:
    s_attr = f' s="{style}"' if style else ""
    if formula:
        return f'<c r="{ref}"{s_attr} t="str"><f>{escape(formula)}</f><v>{escape(value)}</v></c>'
    if is_num and value.isdigit():
        return f'<c r="{ref}"{s_attr}><v>{value}</v></c>'
    return f'<c r="{ref}"{s_attr} t="inlineStr"><is><t xml:space="preserve">{escape(value)}</t></is></c>'


def _build_sheet_xml(grid: list[list[tuple[str, int, bool, str]]], col_widths: list[int], freeze_top: bool = True, auto_filter_ref: str = "") -> str:
    parts = [
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
    ]
    if freeze_top:
        parts.append('<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>')
    parts.append("<cols>")
    for i, w in enumerate(col_widths, start=1):
        parts.append(f'<col min="{i}" max="{i}" width="{w}" customWidth="1"/>')
    parts.append("</cols><sheetData>")
    for r_idx, row in enumerate(grid, start=1):
        ht = ' ht="24" customHeight="1"' if r_idx == 1 else ""
        parts.append(f'<row r="{r_idx}"{ht}>')
        for c_idx, (val, st, is_num, form) in enumerate(row):
            ref = f"{_col_letter(c_idx)}{r_idx}"
            parts.append(_xml_cell(ref, val, style=st, is_num=is_num, formula=form))
        parts.append("</row>")
    parts.append("</sheetData>")
    if auto_filter_ref:
        parts.append(f'<autoFilter ref="{auto_filter_ref}"/>')
    parts.append("</worksheet>")
    return "".join(parts)


def write_xlsx(path: Path, rows: list[dict[str, str]], summary: list[tuple[str, str, str, int]]) -> None:
    s1_grid: list[list[tuple[str, int, bool, str]]] = [
        [(h, 1, False, "") for h in HEADERS]
    ]
    for r in rows:
        url = r["amazon_search_helper_url"]
        safe_q = url.replace('"', '""')
        form = f'HYPERLINK("{safe_q}","{safe_q}")'
        s1_grid.append([
            (r["item_id"], 0, False, ""),
            (r["category_code"], 0, False, ""),
            (r["category_name"], 0, False, ""),
            (r["subcategory"], 0, False, ""),
            (r["title"], 0, False, ""),
            (r["brand"], 0, False, ""),
            (url, 2, False, form),
            (r["amazon_affiliate_link"], 3, False, ""),
            (r["image_url"], 0, False, ""),
            (r["asin"], 0, False, ""),
            (r["source_type"], 0, False, ""),
            (r["featured"], 0, False, ""),
            (r["priority_rank"], 0, True, ""),
            (r["badge_text"], 0, False, ""),
            (r["description"], 0, False, ""),
            (r["highlights"], 0, False, ""),
        ])

    s2_grid: list[list[tuple[str, int, bool, str]]] = [
        [("Category Code", 1, False, ""), ("Category Name", 1, False, ""), ("Subcategory (48 Total)", 1, False, ""), ("Item Count", 1, False, "")]
    ]
    for code, cname, sub, cnt in summary:
        s2_grid.append([(code, 0, False, ""), (cname, 0, False, ""), (sub, 0, False, ""), (str(cnt), 0, True, "")])
    s2_grid.append([("TOTAL", 1, False, ""), ("8 Categories", 1, False, ""), ("48 Subcategories", 1, False, ""), ("1000", 1, True, "")])

    guide_steps = [
        ("Step 1 — No Amazon Password Needed", "You NEVER need to give anyone your Amazon Associates login. Just sign in to your own Amazon Associates Central account in your browser so the Amazon SiteStripe bar appears at the top of Amazon.com."),
        ("Step 2 — Add Your Domain & Tracking ID Once", "In Amazon Associates Central -> Account Settings -> Edit Your Website and Mobile App List, add your PipeBuyer domain/app URL. Then enter your public Tracking ID (e.g. pipebuyer-20) once in /admin/shop -> Amazon & Affiliate Tags."),
        ("Step 3 — 1-Click Product Lookup (Column G)", "On the '1000_Store_Items' tab, click any blue link in Column G (amazon_search_helper_url). It opens that exact tool on Amazon.com."),
        ("Step 4 — Copy Official SiteStripe Link into Column H", "Click 'Get Link: Text' on your Amazon SiteStripe bar at the top of Amazon (Short amzn.to link or Full link) and paste it into Column H (amazon_affiliate_link — highlighted yellow)."),
        ("Step 5 — Import Partial or Full Batches Anytime", "Save as CSV (or copy rows directly from Excel/Google Sheets) -> open /admin/shop -> click 'Import Spreadsheet (.CSV)'. Rows with links publish immediately; blank yellow rows are safely skipped until you fill them in later!"),
    ]
    s3_grid: list[list[tuple[str, int, bool, str]]] = [
        [("Workflow Step", 1, False, ""), ("Instructions for PipeBuyer Store Admins", 1, False, "")]
    ] + [(step, 0, False, "") for step, _ in []]
    s3_grid = [[("Workflow Step", 1, False, ""), ("Instructions for PipeBuyer Store Admins", 1, False, "")]] + [
        [(k, 3, False, ""), (v, 0, False, "")] for k, v in guide_steps
    ]

    styles_xml = (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<fonts count="3">'
        '<font><sz val="10"/><color rgb="FF0F172A"/><name val="Calibri"/></font>'
        '<font><b/><sz val="10.5"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font>'
        '<font><u/><sz val="10"/><color rgb="FF0F52BA"/><name val="Calibri"/></font>'
        '</fonts>'
        '<fills count="4">'
        '<fill><patternFill patternType="none"/></fill>'
        '<fill><patternFill patternType="gray125"/></fill>'
        '<fill><patternFill patternType="solid"><fgColor rgb="FF0F172A"/></patternFill></fill>'
        '<fill><patternFill patternType="solid"><fgColor rgb="FFFFF7ED"/></patternFill></fill>'
        '</fills>'
        '<borders count="2">'
        '<border><left/><right/><top/><bottom/><diagonal/></border>'
        '<border><left style="thin"><color rgb="FFE2E8F0"/></left><right style="thin"><color rgb="FFE2E8F0"/></right><top style="thin"><color rgb="FFE2E8F0"/></top><bottom style="thin"><color rgb="FFE2E8F0"/></bottom><diagonal/></border>'
        '</borders>'
        '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
        '<cellXfs count="4">'
        '<xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1"/>'
        '<xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"/>'
        '<xf numFmtId="0" fontId="2" fillId="0" borderId="1" xfId="0" applyFont="1" applyBorder="1"/>'
        '<xf numFmtId="0" fontId="0" fillId="3" borderId="1" xfId="0" applyFill="1" applyBorder="1"/>'
        '</cellXfs>'
        '</styleSheet>'
    )

    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("[Content_Types].xml", '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/worksheets/sheet3.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>')
        zf.writestr("_rels/.rels", '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>')
        zf.writestr("xl/workbook.xml", '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="1000_Store_Items" sheetId="1" r:id="rId1"/><sheet name="Categories_Subcategories" sheetId="2" r:id="rId2"/><sheet name="How_To_Add_Amazon_Links" sheetId="3" r:id="rId3"/></sheets></workbook>')
        zf.writestr("xl/_rels/workbook.xml.rels", '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/><Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet3.xml"/><Relationship Id="rId4" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>')
        zf.writestr("xl/styles.xml", styles_xml)
        zf.writestr("xl/worksheets/sheet1.xml", _build_sheet_xml(s1_grid, [36, 22, 28, 38, 60, 20, 44, 42, 24, 14, 18, 10, 14, 22, 58, 56], freeze_top=True, auto_filter_ref="A1:P1001"))
        zf.writestr("xl/worksheets/sheet2.xml", _build_sheet_xml(s2_grid, [24, 32, 42, 14], freeze_top=True, auto_filter_ref="A1:D49"))
        zf.writestr("xl/worksheets/sheet3.xml", _build_sheet_xml(s3_grid, [36, 110], freeze_top=True))


def main() -> None:
    root = Path(__file__).resolve().parent.parent
    out_dir = root / "docs" / "shop_catalog"
    out_dir.mkdir(parents=True, exist_ok=True)

    rows, summary = build_1000_rows()
    csv_path = out_dir / "pipebuyer_store_1000_items_master.csv"
    xlsx_path = out_dir / "pipebuyer_store_1000_items_master.xlsx"

    with csv_path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=HEADERS)
        writer.writeheader()
        writer.writerows(rows)

    write_xlsx(xlsx_path, rows, summary)
    print(f"Generated {len(rows)} items across {len(summary)} subcategories:")
    print(f" - CSV : {csv_path} ({csv_path.stat().st_size:,} bytes)")
    print(f" - XLSX: {xlsx_path} ({xlsx_path.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
