import 'package:flutter/material.dart';

import 'marketplace_dispatch_company_profile.dart';
import 'marketplace_dispatch_company_profile_repository.dart';
import 'marketplace_dispatch_credentials.dart';
import 'marketplace_dispatch_equipment_capability.dart';

class MarketplaceDispatchCompanyProfilePage extends StatefulWidget {
  const MarketplaceDispatchCompanyProfilePage({super.key});

  @override
  State<MarketplaceDispatchCompanyProfilePage> createState() =>
      _MarketplaceDispatchCompanyProfilePageState();
}

class _MarketplaceDispatchCompanyProfilePageState
    extends State<MarketplaceDispatchCompanyProfilePage> {
  final MarketplaceDispatchCompanyProfileRepository _repository =
      MarketplaceDispatchCompanyProfileRepository();

  late Future<DispatchCompanyProfileDraft> _loadFuture;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadFuture = _repository.load();
  }

  Future<void> _save(DispatchCompanyProfileDraft draft) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _repository.save(draft);
      if (!mounted) return;
      setState(() {
        _loadFuture = Future.value(draft);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dispatch company profile saved.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Company profile was not saved: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openFleetCapabilities() => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const MarketplaceDispatchEquipmentCapabilitiesPage(),
        ),
      );

  Future<void> _openCredentials() => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const MarketplaceDispatchCredentialsPage(),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DispatchCompanyProfileDraft>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 42),
                  const SizedBox(height: 12),
                  const Text(
                    'Company profile could not be loaded.',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text('${snapshot.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _loadFuture = _repository.load();
                    }),
                    icon: const Icon(Icons.refresh_outlined),
                    label: const Text('Reload company profile'),
                  ),
                ],
              ),
            ),
          );
        }

        final draft = snapshot.data;
        if (draft == null) {
          return const Center(child: Text('Company profile is unavailable.'));
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              child: Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(Icons.local_shipping_outlined),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Fleet & equipment capabilities',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Assign structured Dispatch services and capabilities to each truck, trailer, pilot vehicle, crane or field-service unit.',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: _openFleetCapabilities,
                            icon: const Icon(Icons.tune_outlined),
                            label: const Text('Manage fleet'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_user_outlined),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Credentials & insurance',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Keep self-reported insurance, authority and qualification metadata private. Supporting evidence stays out of the public Directory profile.',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: _openCredentials,
                            icon: const Icon(Icons.lock_outline),
                            label: const Text('Manage credentials'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: MarketplaceDispatchCompanyProfileEditor(
                key: ValueKey(
                  'dispatch-company-${draft.operatingName}-${draft.completionPercent}',
                ),
                initial: draft,
                saving: _saving,
                onSave: _save,
              ),
            ),
          ],
        );
      },
    );
  }
}
