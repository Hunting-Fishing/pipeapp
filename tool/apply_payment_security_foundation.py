from pathlib import Path
import re

path = Path('lib/marketplace/marketplace_admin_dashboard.dart')
source = path.read_text(encoding='utf-8')


def replace_once(old: str, new: str, label: str) -> None:
    global source
    count = source.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 match, found {count}')
    source = source.replace(old, new, 1)


def sub_once(pattern: str, replacement: str, label: str) -> None:
    global source
    source, count = re.subn(pattern, replacement, source, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 match, found {count}')


replace_once(
    "import 'marketplace_admin_access.dart';\n",
    "import 'marketplace_admin_access.dart';\n"
    "import 'marketplace_payment_readiness.dart';\n",
    'payment readiness import',
)

sub_once(
    r"\n  // Banking & Gateway controllers\n.*?\n  final _userSearchController",
    "\n  final _userSearchController",
    'financial credential controllers',
)

sub_once(
    r"\n  // Modular saving states\n.*?\n  // System feature flags state",
    "\n  // System feature flags state",
    'credential saving states',
)

replace_once(
    "  bool _escrowEnabled = true;\n",
    "",
    'legacy escrow flag declaration',
)
replace_once(
    "    _loadGatewayCredentials();\n",
    "",
    'gateway load call',
)

for line in (
    "    _companyBankName.dispose();\n",
    "    _companyRoutingNumber.dispose();\n",
    "    _companyAccountNumber.dispose();\n",
    "    _companySwiftIban.dispose();\n",
    "    _stripePublishableKey.dispose();\n",
    "    _stripeSecretKey.dispose();\n",
    "    _stripeWebhookSecret.dispose();\n",
    "    _paypalClientId.dispose();\n",
    "    _paypalSecretKey.dispose();\n",
    "    _paypalMerchantId.dispose();\n",
    "    _authorizeApiLoginId.dispose();\n",
    "    _authorizeTransactionKey.dispose();\n",
):
    replace_once(line, "", f'dispose {line.strip()}')

sub_once(
    r"\n  Future<void> _loadGatewayCredentials\(\) async \{.*?\n  Future<void> _loadFeatureFlags",
    "\n  Future<void> _loadFeatureFlags",
    'gateway credential loader',
)
replace_once(
    "          _escrowEnabled = data['escrowEnabled'] ?? true;\n",
    "",
    'legacy escrow flag load',
)

sub_once(
    r"\n  Future<void> _saveBankCredentials\(\) async \{.*?\n  Future<void> _saveFeatureFlags",
    "\n  Future<void> _saveFeatureFlags",
    'client credential save methods',
)
replace_once(
    "        'escrowEnabled': _escrowEnabled,\n",
    "",
    'legacy escrow flag write',
)

replace_once(
    "                text: '💰 Sales Payments & Escrow Transfers'),",
    "                text: 'Transaction Records'),",
    'transaction tab title',
)
replace_once(
    "                text: 'Banking & Merchant Setup'),",
    "                text: 'Billing & Provider Readiness'),",
    'provider tab title',
)

sub_once(
    r"  // 3\. Sales Payments & Escrow Transfers Tab\n.*?(?=  // 4\. MODULAR BANKING & MERCHANT PROCESSING GATEWAYS TAB)",
    "  // 3. Read-only transaction lifecycle records\n"
    "  Widget _buildTransactionsTab() =>\n"
    "      const MarketplaceTransactionRecordsPanel();\n\n",
    'transaction custody controls',
)

sub_once(
    r"  // 4\. MODULAR BANKING & MERCHANT PROCESSING GATEWAYS TAB\n.*?(?=  // 5\. Users Directory & Leaderboards Tab)",
    "  // 4. Provider readiness and non-secret billing architecture\n"
    "  Widget _buildBankingGatewaysTab() =>\n"
    "      const MarketplacePaymentReadinessPanel();\n\n",
    'bank and gateway credential tab',
)

replace_once(
    "        double sellerFees = 0.0;\n        double escrowFees = 0.0;\n",
    "",
    'hard-coded fee accumulator declarations',
)
replace_once(
    "          sellerFees += subtotal * 0.025;\n"
    "          escrowFees += subtotal * 0.010;\n",
    "",
    'hard-coded fee calculations',
)

sub_once(
    r"_metricCard\(\s*'TOTAL COMPANY EARNINGS \(3\.5%\)',\s*'\\\$\$\{\(sellerFees \+ escrowFees\)\.toStringAsFixed\(2\)\}',\s*Icons\.account_balance_wallet,\s*Colors\.green\)",
    "_metricCard(\n"
    "                      'PAYMENT REVENUE',\n"
    "                      'Not active',\n"
    "                      Icons.account_balance_wallet_outlined,\n"
    "                      Colors.grey)",
    'company earnings metric',
)
sub_once(
    r"_metricCard\(\s*'2\.5% SELLER COMMISSIONS',\s*'\\\$\$\{sellerFees\.toStringAsFixed\(2\)\}',\s*Icons\.sell_outlined,\s*Colors\.purple\)",
    "_metricCard(\n"
    "                      'COMMISSION SCHEDULE',\n"
    "                      'Draft only',\n"
    "                      Icons.percent_outlined,\n"
    "                      Colors.grey)",
    'seller commission metric',
)
sub_once(
    r"_metricCard\(\s*'1\.0% ESCROW PROTECTION',\s*'\\\$\$\{escrowFees\.toStringAsFixed\(2\)\}',\s*Icons\.shield_outlined,\s*Colors\.teal\)",
    "_metricCard(\n"
    "                      'PROVIDER SETTLEMENT',\n"
    "                      'Not connected',\n"
    "                      Icons.account_balance_outlined,\n"
    "                      Colors.grey)",
    'escrow revenue metric',
)

sub_once(
    r"\n        SwitchListTile\(\s*value: _escrowEnabled,.*?\n        \),",
    "",
    'legacy escrow feature toggle',
)

prohibited = (
    'stripeSecretKey',
    'stripeWebhookSecret',
    'paypalSecretKey',
    'authorizeTransactionKey',
    'companyAccountNumber',
    'companyRoutingNumber',
    "doc('payment_gateways')",
    'Admin Force Release Funds',
    'Admin Force Refund Buyer',
    'force_release',
    'force_refund',
    'Industrial Escrow Protection Active',
    'escrowEnabled',
    'subtotal * 0.025',
    'subtotal * 0.010',
    'TOTAL COMPANY EARNINGS (3.5%)',
    '2.5% SELLER COMMISSIONS',
    '1.0% ESCROW PROTECTION',
)
for value in prohibited:
    if value in source:
        raise SystemExit(f'prohibited payment pattern remains: {value}')

path.write_text(source, encoding='utf-8')
