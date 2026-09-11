import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'pipebuyer_yellow_pages_client.dart';

class PipeBuyerYellowPagesDirectoryPage extends StatefulWidget {
  const PipeBuyerYellowPagesDirectoryPage({super.key});

  @override
  State<PipeBuyerYellowPagesDirectoryPage> createState() =>
      _PipeBuyerYellowPagesDirectoryPageState();
}

class _PipeBuyerYellowPagesDirectoryPageState
    extends State<PipeBuyerYellowPagesDirectoryPage> {
  final PipeBuyerYellowPagesClient _client = PipeBuyerYellowPagesClient();

  bool _loading = false;
  String? _error;
  String? _nextCursor;
  List<Map<String, dynamic>> _entries = const [];

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _entries = const [];
        _nextCursor = null;
      }
    });
    try {
      final page = await _client.listPublic(
        cursor: reset ? null : _nextCursor,
      );
      if (!mounted) return;
      setState(() {
        _entries = reset
            ? page.items
            : List<Map<String, dynamic>>.unmodifiable(
                <Map<String, dynamic>>[..._entries, ...page.items],
              );
        _nextCursor = page.nextCursor;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst(RegExp(r'^Bad state:\s*'), '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PIPEBUYER YELLOW PAGES',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.7),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh directory',
            onPressed: _loading ? null : () => _load(reset: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: const Row(
              children: [
                Icon(Icons.verified_outlined, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Public listings shown here are published from PipeBuyer’s verified, current paid directory records. Internal Contact Center notes and private outreach data are not exposed.',
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: Text(_error!),
                  trailing: TextButton(
                    onPressed: () => _load(reset: true),
                    child: const Text('Retry'),
                  ),
                ),
              ),
            ),
          Expanded(
            child: _loading && _entries.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _entries.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No paid and verified PipeBuyer Yellow Pages listings are published yet.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: _entries.length + (_nextCursor != null ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _entries.length) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: FilledButton.tonalIcon(
                                  onPressed: _loading
                                      ? null
                                      : () => _load(reset: false),
                                  icon: _loading
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Icon(Icons.expand_more),
                                  label: const Text('Load more companies'),
                                ),
                              ),
                            );
                          }
                          return _PublicCompanyCard(entry: _entries[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _PublicCompanyCard extends StatelessWidget {
  const _PublicCompanyCard({required this.entry});

  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final companyName = '${entry['companyName'] ?? 'Company'}'.trim();
    final city = '${entry['city'] ?? ''}'.trim();
    final region = '${entry['regionCode'] ?? ''}'.trim();
    final phone = '${entry['publicPhone'] ?? ''}'.trim();
    final email = '${entry['publicEmail'] ?? ''}'.trim();
    final website = '${entry['website'] ?? ''}'.trim();
    final description = '${entry['description'] ?? ''}'.trim();
    final categories = (entry['categories'] as List?)
            ?.map((item) => item.toString())
            .where((item) => item.trim().isNotEmpty)
            .toList(growable: false) ??
        const <String>[];
    final location = [city, region].where((item) => item.isNotEmpty).join(', ');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.business_outlined)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              companyName,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Tooltip(
                            message: 'Verified PipeBuyer Yellow Pages listing',
                            child: Icon(Icons.verified, size: 19),
                          ),
                        ],
                      ),
                      if (location.isNotEmpty) Text(location),
                    ],
                  ),
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                description,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (categories.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 5,
                children: categories
                    .take(8)
                    .map((category) => Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(category),
                        ))
                    .toList(growable: false),
              ),
            ],
            if (phone.isNotEmpty || email.isNotEmpty || website.isNotEmpty) ...[
              const Divider(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (phone.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => launchUrl(Uri(scheme: 'tel', path: phone)),
                      icon: const Icon(Icons.phone_outlined, size: 18),
                      label: Text(phone),
                    ),
                  if (email.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => launchUrl(Uri(scheme: 'mailto', path: email)),
                      icon: const Icon(Icons.email_outlined, size: 18),
                      label: const Text('Email'),
                    ),
                  if (website.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => _openWebsite(website),
                      icon: const Icon(Icons.language_outlined, size: 18),
                      label: const Text('Website'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openWebsite(String website) async {
    final value = website.trim();
    final uri = Uri.tryParse(value.contains('://') ? value : 'https://$value');
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
