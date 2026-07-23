# Local Firebase emulator workflow

Date: July 22, 2026

`flutter-flow-pipe` is the approved production project. The app now defaults
to the `local` environment. Every non-production development, test, and CI
environment redirects Auth, Firestore, Functions, and Storage to the Firebase
Emulator Suite before application repositories are initialized. Cloud access
requires an explicit `staging` or `production` build with a complete approved
configuration.

## Start the local backend

From the repository root:

```powershell
npx --yes firebase-tools@15.24.0 emulators:start `
  --project flutter-flow-pipe `
  --config firebase.json `
  --only auth,firestore,functions,storage
```

The project ID is used only as the emulator namespace. This command does not
deploy or write to the live Firebase project.

## Run the app locally

Web or desktop:

```powershell
flutter run -d chrome --dart-define=PIPE_ENV=local
```

Android Emulator automatically uses `10.0.2.2` to reach the development
machine:

```powershell
flutter run -d emulator --dart-define=PIPE_ENV=local
```

For a physical device on the same trusted network, provide the development
machine's reachable LAN address:

```powershell
flutter run --dart-define=PIPE_ENV=local `
  --dart-define=PIPE_FIREBASE_EMULATOR_HOST=192.168.1.25
```

Do not expose emulator ports to the public internet. If the suite is stopped,
local Firebase operations fail against the configured local endpoint; they do
not fall back to production.

The emulator UI is available at `http://127.0.0.1:4000` on the development
machine.

The repository integration check runs with the production Functions runtime
(Node 22), creates isolated Auth identities, and executes authenticated
Marketplace, Offer, Auction, bidding, Buy It Now, and Dispatch commands. It
repeats commands to prove retries do not duplicate records or state changes:

```powershell
.\tool\callable_emulator_integration.ps1
```

This check uses only the demo project namespace
`demo-pipe-buyer-integration`; it cannot reach staging or production.
