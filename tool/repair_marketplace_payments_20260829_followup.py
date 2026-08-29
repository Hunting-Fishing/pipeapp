from pathlib import Path
import re

path = Path("firebase/functions/stripe_webhook.js")
text = path.read_text()
pattern = re.compile(
    r'async function stripeFormRequest\(\{.*?\n\}\n\n(?=async function retrievePaymentIntent)',
    re.S,
)
updated, count = pattern.subn('', text, count=1)
if count != 1:
    raise SystemExit(f"Expected one obsolete stripeFormRequest helper, found {count}")
path.write_text(updated)
print("Removed obsolete webhook Stripe transfer helper.")
