from pathlib import Path

path = Path('lib/marketplace/oil_gas_marketplace.dart')
text = path.read_text(encoding='utf-8')
old = """          const MarketplaceShellDestination(
            pageIndex: 5,
            label: 'Profile',
"""
new = """          const MarketplaceShellDestination(
            pageIndex: 5,
            label: 'Account',
"""
count = text.count(old)
if count != 2:
    raise SystemExit(
        f'account destination prepatch: expected two Profile destinations, found {count}'
    )
path.write_text(text.replace(old, new, 1), encoding='utf-8')
