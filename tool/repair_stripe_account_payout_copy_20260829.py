from pathlib import Path

PATH = Path("lib/marketplace/marketplace_account_hub.dart")
OLD_TITLE = "title: const Text('Banking & Direct Payout Settings'),"
NEW_TITLE = "title: const Text('Seller Payout Setup'),"
OLD_SUBTITLE = (
    "subtitle: const Text(\n"
    "              'Connect bank routing & account numbers for ACH / Wire escrow releases.'),"
)
NEW_SUBTITLE = (
    "subtitle: const Text(\n"
    "              'Connect or update seller payouts securely with Stripe. Pipe Buyer does not store your bank account details.'),"
)

source = PATH.read_text(encoding="utf-8")

if source.count(OLD_TITLE) != 1:
    raise SystemExit(
        f"Expected exactly one stale payout title, found {source.count(OLD_TITLE)}"
    )
if source.count(OLD_SUBTITLE) != 1:
    raise SystemExit(
        f"Expected exactly one stale payout subtitle, found {source.count(OLD_SUBTITLE)}"
    )

source = source.replace(OLD_TITLE, NEW_TITLE, 1)
source = source.replace(OLD_SUBTITLE, NEW_SUBTITLE, 1)

if "ACH / Wire escrow releases" in source:
    raise SystemExit("Stale payout/escrow wording remains after repair")
if "Seller Payout Setup" not in source:
    raise SystemExit("Seller payout title was not installed")
if "Pipe Buyer does not store your bank account details" not in source:
    raise SystemExit("Stripe-hosted payout privacy copy was not installed")

PATH.write_text(source, encoding="utf-8")
print(f"Updated {PATH} with Stripe-hosted seller payout copy.")
