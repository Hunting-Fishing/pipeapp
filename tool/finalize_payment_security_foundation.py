from pathlib import Path

path = Path('lib/marketplace/marketplace_admin_dashboard.dart')
source = path.read_text(encoding='utf-8')

replacements = {
    "Monitors gross transaction volume (\\$), 3.5% company commission earnings, auto-detects new signup countries, categorizes marketplace items into collapsible cards (collapsed first), and provides granular timeline breakdowns (Day, Week, Month, Quarter).":
        "Monitors gross marketplace lifecycle volume, signup countries, item categories, and time-based activity. Payment revenue and provider settlement remain inactive until the separately approved payment release.",
    "Monitors live timed auctions, highest bid volume (\\$), estimated 3.5% fees, global auction distribution across energy basins, and provides live master admin override controls (Force End, Extend, Cancel).":
        "Monitors live timed auctions, highest bid activity, global auction distribution across energy basins, and administrative auction lifecycle controls. Auction payment fees remain inactive until the separately approved payment release.",
    """_metricCard(
                    'EST. 3.5% AUCTION FEES',
                    '\\$${(grossAuctionVolume * 0.035).toStringAsFixed(2)}',
                    Icons.account_balance_wallet,
                    Colors.green)""":
        """_metricCard(
                    'AUCTION PAYMENT FEES',
                    'Not active',
                    Icons.account_balance_wallet_outlined,
                    Colors.grey)""",
}

for old, new in replacements.items():
    count = source.count(old)
    if count != 1:
        raise SystemExit(f'expected exactly one match for {old[:60]!r}, found {count}')
    source = source.replace(old, new, 1)

prohibited = (
    '3.5% company commission earnings',
    'estimated 3.5% fees',
    'EST. 3.5% AUCTION FEES',
    'grossAuctionVolume * 0.035',
)
for value in prohibited:
    if value in source:
        raise SystemExit(f'prohibited stale payment pattern remains: {value}')

path.write_text(source, encoding='utf-8')
