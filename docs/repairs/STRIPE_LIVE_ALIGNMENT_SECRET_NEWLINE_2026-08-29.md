# Stripe Live Alignment — One-Time Secret Newline Repair — 2026-08-29

Firebase project: `flutter-flow-pipe`
Stripe account: Pipe Buyer (`acct_1U2QmKDkO07WMXyR`)

## Root cause

After separating Cloud Run infrastructure authentication from Pipe Buyer's one-time application token, the temporary billing activator returned HTTP 403.

The release workflow created the token file with:

`openssl rand -hex 32 > .activation-token`

`openssl rand -hex 32` emits 64 hexadecimal characters followed by a newline. The file was passed to Firebase Secret Manager with `functions:secrets:set --data-file`, while the caller later loaded it with Bash command substitution:

`token="$(cat .activation-token)"`

Bash command substitution removes trailing newlines. That means the deployed function could receive a secret value containing the file newline while the HTTP caller sent only the 64 hexadecimal characters. The timing-safe token comparison requires equal byte lengths, so the request correctly failed closed with `403 Forbidden`.

The same defect existed in the planned policy-publication token generation and would have caused the next temporary endpoint to fail identically.

## Repair

The final completion workflow now:

1. Generates each random token into a shell variable.
2. Validates it against `^[0-9a-f]{64}$`.
3. Writes it with `printf '%s'`, which adds no newline.
4. Verifies the token file is exactly 64 bytes before setting the Firebase secret.
5. Uses dedicated `X-PipeBuyer-*` application headers rather than the reserved `Authorization` channel.
6. Probes each temporary endpoint without a token and requires the exact application-level `403 Forbidden` response before sending the authorized request. This proves the request is reaching Pipe Buyer code instead of being rejected by infrastructure IAM.
7. Deletes each temporary endpoint immediately after its one authorized operation.

## Safety boundary retained

The billing activator is still hard-coded to the approved pending-tax production profile:

- Stripe mode: production
- Stripe Connect seller onboarding: enabled
- Dispatch subscriptions: enabled
- marketplace fee billing: enabled
- signed Stripe webhook: verified
- reconciliation readiness: enabled
- Canadian tax registration: pending
- Stripe tax ready: false
- full buyer-to-seller Stripe Checkout: disabled
- affiliate payouts: disabled
- automated financial-resolution/dispute override controls: disabled

This repair does not bypass Canadian tax readiness and cannot enable full buyer-to-seller Checkout.

## Regression rule

For one-time release secrets passed through Firebase Secret Manager, never depend on tools agreeing about trailing newlines. Generate and validate a canonical token value, write exact bytes with `printf`, verify the file length before secret publication, and prove the temporary HTTP handler is reached before performing a privileged write.
