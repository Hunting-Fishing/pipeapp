# PipeBuyer Store — 1,000-Item Master Affiliate Catalog

This directory contains the pre-built **1,000-item industrial, pipeline, welding, rigging, PPE, fleet, jobsite, inspection, and ranch/pipe-fencing catalog** organized across **8 Categories** and **48 Subcategories**:

- **`pipebuyer_store_1000_items_master.xlsx`** — Multi-tab Excel / Google Sheets workbook:
  - **Tab 1 (`1000_Store_Items`)**: All 1,000 curated items with frozen headers, auto-filters, clickable **Column G (`amazon_search_helper_url`)** 1-click Amazon lookup links, and highlighted **Column H (`amazon_affiliate_link`)** ready for your Amazon SiteStripe links.
  - **Tab 2 (`Categories_Subcategories`)**: Full breakdown of all 8 Categories and 48 Subcategories.
  - **Tab 3 (`How_To_Add_Amazon_Links`)**: Quick-reference setup and compliance guide.
- **`pipebuyer_store_1000_items_master.csv`** — Direct upload-ready UTF-8 CSV matching the `/admin/shop` bulk importer.

## Do You Need to Share Your Amazon Associates Login?

**No — never share your Amazon password.**
1. Log into **Amazon Associates Central** in your own browser (`associates.amazon.com`).
2. Go to **Account Settings -> Edit Your Website and Mobile App List** and add your PipeBuyer website domain / app URLs (required by Amazon so clicks from your site are credited).
3. Copy your public **Tracking ID** (e.g., `pipebuyer-20` for US, `pipebuyer0c-20` for Canada) and save it once in **`/admin/shop` -> Amazon & Affiliate Tags**.

## Fast Workflow to Add Your Links (25, 100, or All 1,000 Items)

1. Open **`pipebuyer_store_1000_items_master.xlsx`** in Excel or Google Sheets while signed into Amazon in your browser (so the **Amazon Associates SiteStripe** bar appears at the top of Amazon.com).
2. Click any blue link in **Column G (`amazon_search_helper_url`)** — it opens that exact tool on Amazon.
3. Click **Get Link -> Text** on your SiteStripe bar (`Short Link` `https://amzn.to/...` or `Full Link`) and paste it into **Column H (`amazon_affiliate_link`)**.
4. *(Optional)* If you grab an official product image URL or ASIN, paste it into Column I / Column J — otherwise leave blank (ASINs auto-extract from full links and items automatically fall back to PipeBuyer trade category icons).
5. Save as **CSV UTF-8 (`.csv`)** — or simply highlight and copy your rows directly in Excel / Google Sheets — then open **`/admin/shop`** and click **Import Spreadsheet (.CSV)**.
   - **Incremental uploads are built in:** Rows with an affiliate link in Column H publish immediately to `/shop`. Rows where Column H is still blank are **safely skipped** so you can publish 25 links today, 100 tomorrow, and re-import the same spreadsheet anytime without creating duplicates.

## Regenerating the Master Files

```bash
python scripts/generate_shop_1000_catalog.py
```
