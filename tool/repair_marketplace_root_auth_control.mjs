import fs from 'node:fs';

const target = 'lib/marketplace/oil_gas_marketplace.dart';
let source = fs.readFileSync(target, 'utf8');

const fixedMarkers = [
  'bool _authResolved = false;',
  'bool _authGateScheduled = false;',
  'bool _authRouteOpen = false;',
  'void _scheduleAuthGate()',
  'Future<void> _showAuth({required bool enforced}) async',
  'return const _MarketplaceAuthControlBackdrop();',
  'class _MarketplaceAuthControlBackdrop extends StatelessWidget',
];

if (fixedMarkers.every((marker) => source.includes(marker))) {
  console.log('Marketplace root auth control is already applied.');
  process.exit(0);
}

const fieldAnchor = `  bool _savedLoading = false;\n  Object? _savedLoadError;`;
const fieldReplacement = `  bool _savedLoading = false;\n  Object? _savedLoadError;\n  bool _authResolved = false;\n  bool _authGateScheduled = false;\n  bool _authRouteOpen = false;`;

const buildAnchor = `  @override\n  Widget build(BuildContext context) {\n    final pages = [`;
const buildReplacement = `  @override\n  Widget build(BuildContext context) {\n    if (!_authResolved || FirebaseAuth.instance.currentUser == null) {\n      _scheduleAuthGate();\n      return const _MarketplaceAuthControlBackdrop();\n    }\n\n    final pages = [`;

const authChangedAnchor = `  void _handleAuthChanged(User? user) {\n    _savedSubscription?.cancel();\n    _savedSubscription = null;\n    if (!mounted) return;\n    setState(() {\n      _saved.clear();\n      _savedLoadError = null;\n      _savedLoading = user != null;\n    });\n    if (user == null) return;`;
const authChangedReplacement = `  void _handleAuthChanged(User? user) {\n    _savedSubscription?.cancel();\n    _savedSubscription = null;\n    if (!mounted) return;\n    setState(() {\n      _authResolved = true;\n      _saved.clear();\n      _savedLoadError = null;\n      _savedLoading = user != null;\n    });\n    if (user == null) {\n      _scheduleAuthGate();\n      return;\n    }`;

const oldOpenAuth = `  Future<void> _openAuth() async {\n    if (_scaffoldKey.currentState?.isDrawerOpen == true) {\n      Navigator.of(context).pop();\n    }\n    final signedIn = await Navigator.of(context)\n        .push(MaterialPageRoute(builder: (_) => const MarketplaceAuthPage()));\n    if (mounted) {\n      setState(() {});\n      if (signedIn == true) {\n        PipeFeedback.show(\n          context,\n          message: 'Signed in successfully. Your account is ready.',\n          tone: PipeStatusTone.success,\n        );\n      }\n    }\n  }`;
const newOpenAuth = `  void _scheduleAuthGate() {\n    if (!mounted ||\n        _authGateScheduled ||\n        _authRouteOpen ||\n        FirebaseAuth.instance.currentUser != null) {\n      return;\n    }\n    _authGateScheduled = true;\n    WidgetsBinding.instance.addPostFrameCallback((_) {\n      if (!mounted) return;\n      _authGateScheduled = false;\n      if (_authRouteOpen || FirebaseAuth.instance.currentUser != null) return;\n      unawaited(_showAuth(enforced: true));\n    });\n  }\n\n  Future<void> _openAuth() => _showAuth(enforced: false);\n\n  Future<void> _showAuth({required bool enforced}) async {\n    if (_authRouteOpen) return;\n    if (enforced && FirebaseAuth.instance.currentUser != null) return;\n    if (_scaffoldKey.currentState?.isDrawerOpen == true) {\n      Navigator.of(context).pop();\n    }\n\n    _authRouteOpen = true;\n    try {\n      final signedIn = await Navigator.of(context)\n          .push(MaterialPageRoute(builder: (_) => const MarketplaceAuthPage()));\n      if (!mounted) return;\n      setState(() {});\n      if (signedIn == true) {\n        PipeFeedback.show(\n          context,\n          message: 'Signed in successfully. Your account is ready.',\n          tone: PipeStatusTone.success,\n        );\n      }\n    } finally {\n      _authRouteOpen = false;\n      if (mounted &&\n          enforced &&\n          FirebaseAuth.instance.currentUser == null) {\n        _scheduleAuthGate();\n      }\n    }\n  }`;

const classAnchor = `}\n\nclass _NavAccountIcon extends StatelessWidget {`;
const classReplacement = `}\n\nclass _MarketplaceAuthControlBackdrop extends StatelessWidget {\n  const _MarketplaceAuthControlBackdrop();\n\n  @override\n  Widget build(BuildContext context) => Scaffold(\n        backgroundColor: const Color(0xFF0D131A),\n        body: Center(\n          child: Padding(\n            padding: const EdgeInsets.all(28),\n            child: Column(\n              mainAxisSize: MainAxisSize.min,\n              children: [\n                Image.asset(\n                  'assets/images/pipe_buyer_logo.png',\n                  width: 132,\n                  height: 96,\n                  fit: BoxFit.contain,\n                ),\n                const SizedBox(height: 18),\n                const CircularProgressIndicator(),\n                const SizedBox(height: 14),\n                const Text(\n                  'Opening secure Pipe Buyer access...',\n                  textAlign: TextAlign.center,\n                  style: TextStyle(\n                    color: Colors.white,\n                    fontWeight: FontWeight.w800,\n                  ),\n                ),\n              ],\n            ),\n          ),\n        ),\n      );\n}\n\nclass _NavAccountIcon extends StatelessWidget {`;

for (const [label, oldText] of [
  ['auth state fields', fieldAnchor],
  ['root build gate', buildAnchor],
  ['auth-state handler', authChangedAnchor],
  ['auth route method', oldOpenAuth],
  ['auth backdrop anchor', classAnchor],
]) {
  const count = source.split(oldText).length - 1;
  if (count !== 1) {
    throw new Error(`Expected exactly one ${label} target, found ${count}. Stop instead of guessing.`);
  }
}

source = source.replace(fieldAnchor, fieldReplacement);
source = source.replace(buildAnchor, buildReplacement);
source = source.replace(authChangedAnchor, authChangedReplacement);
source = source.replace(oldOpenAuth, newOpenAuth);
source = source.replace(classAnchor, classReplacement);

for (const marker of fixedMarkers) {
  if (!source.includes(marker)) {
    throw new Error(`Root auth repair marker missing after update: ${marker}`);
  }
}

fs.writeFileSync(target, source, 'utf8');
console.log('Marketplace root auth control applied.');
