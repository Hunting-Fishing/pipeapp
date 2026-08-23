import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import {fileURLToPath} from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, "..");
const target = path.join(
    repoRoot,
    "lib",
    "marketplace",
    "marketplace_dispatch_page.dart",
);

const expectedBaseBlob = "f79998e4cfe41eea2d348ae91e12099dd7afc630";
const navigationImport = "import 'marketplace_dispatch_navigation.dart';";

function gitBlobSha(text) {
  const body = Buffer.from(text, "utf8");
  const header = Buffer.from(`blob ${body.length}\0`, "utf8");
  return crypto.createHash("sha1").update(header).update(body).digest("hex");
}

const source = fs.readFileSync(target, "utf8");
if (source.includes(navigationImport) &&
    source.includes("DispatchSection section = DispatchSection.dashboard;")) {
  console.log("Dispatch Phase 1 navigation is already applied.");
  process.exit(0);
}

const actualBlob = gitBlobSha(source);
if (actualBlob !== expectedBaseBlob) {
  throw new Error(
      "marketplace_dispatch_page.dart does not match the verified Phase 0 base. " +
      `Expected ${expectedBaseBlob}, found ${actualBlob}. ` +
      "No product file was changed. Upload the current file before applying Phase 1.",
  );
}

const dashboardImport = "import 'marketplace_dispatch_dashboard.dart';";
if (!source.includes(dashboardImport)) {
  throw new Error("Dispatch dashboard import anchor is missing.");
}

const startMarker =
  "class _MarketplaceDispatchPageState extends State<MarketplaceDispatchPage> {";
const endMarker = "\nclass _PilotTruckSection extends StatelessWidget {";
const start = source.indexOf(startMarker);
const end = source.indexOf(endMarker, start);
if (start < 0 || end < 0) {
  throw new Error("Verified Dispatch page state anchors were not found.");
}

const replacement = `class _MarketplaceDispatchPageState extends State<MarketplaceDispatchPage> {
  final repo = MarketplaceDispatchRepository();
  DispatchSection section = DispatchSection.dashboard;

  Future<void> _openProviderAccount(
    DispatchAccountState accountState,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text(
              accountState.providerRegistered
                  ? 'Dispatch company profile'
                  : 'Join Pipe Buyer Dispatch',
            ),
          ),
          body: _CarrierEnrollment(repo: repo),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => section = DispatchSection.dashboard);
  }

  @override
  Widget build(BuildContext context) {
    if (FirebaseAuth.instance.currentUser == null) {
      return const Center(child: Text('Sign in to use Dispatch.'));
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: repo.carrierProfile(),
      builder: (context, profile) {
        if (profile.connectionState == ConnectionState.waiting &&
            !profile.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (profile.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 42,
                    color: Color(0xFFB42318),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Dispatch account state could not be loaded.',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Check the connection and reload Dispatch before changing provider settings.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh_outlined),
                    label: const Text('Reload Dispatch'),
                  ),
                ],
              ),
            ),
          );
        }

        final accountState = DispatchAccountState.fromCarrierProfile(
          exists: profile.data?.exists == true,
          data: profile.data?.data(),
        );

        final content = switch (section) {
          DispatchSection.dashboard => accountState.providerRegistered
              ? MarketplaceDispatchDashboard(
                  repo: repo,
                  onPostLoad: () =>
                      setState(() => section = DispatchSection.requestService),
                  onBrowseJobs: () =>
                      setState(() => section = DispatchSection.jobs),
                  onJoinCarrier: () => _openProviderAccount(accountState),
                )
              : MarketplaceDispatchCustomerHome(
                  onRequestService: () =>
                      setState(() => section = DispatchSection.requestService),
                  onBrowseDirectory: () =>
                      setState(() => section = DispatchSection.directory),
                  onBrowseJobs: () =>
                      setState(() => section = DispatchSection.jobs),
                  onListBusiness: () => _openProviderAccount(accountState),
                ),
          DispatchSection.requestService => _PostJob(repo: repo),
          DispatchSection.directory => MarketplaceDispatchDirectoryFoundation(
              accountState: accountState,
              legacyProviderTools: accountState.providerRegistered
                  ? _PilotTruckSection(repo: repo)
                  : null,
            ),
          DispatchSection.jobs => _JobBoard(repo: repo),
        };

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dispatch',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Industrial service requests, provider network and job opportunities.',
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12),
                      IndustrialAssetIcon(
                        label: 'Dispatch load board',
                        assetPath: IndustrialIconAssets.dispatchLoadBoard,
                        size: 62,
                        borderRadius: 12,
                        fallback: Icon(
                          Icons.local_shipping_outlined,
                          size: 42,
                          color: Color(0xFF0878E8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  MarketplaceDispatchNavigation(
                    selected: section,
                    accountState: accountState,
                    onSelected: (value) => setState(() => section = value),
                    onProviderAction: () =>
                        _openProviderAccount(accountState),
                  ),
                ],
              ),
            ),
            Expanded(child: content),
          ],
        );
      },
    );
  }
}
`;

let updated = source.replace(
    dashboardImport,
    `${dashboardImport}\n${navigationImport}`,
);
updated = updated.slice(0, start) + replacement + updated.slice(end);

if (!updated.includes("label: Text('Request Service')") ||
    !updated.includes("label: Text('Directory')") ||
    updated.includes("label: Text('Signup')") ||
    updated.includes("label: Text('Pilot')")) {
  throw new Error("Dispatch Phase 1 navigation postcondition failed.");
}

fs.writeFileSync(target, updated, "utf8");
console.log("Dispatch Phase 1 role-aware navigation applied.");
console.log("The legacy Pilot provider tool remains available inside Directory during migration.");
