from pathlib import Path


def replace_once(path, old, new):
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'{path}: expected one match, found {count}')
    p.write_text(text.replace(old, new, 1), encoding='utf-8')


messages = 'lib/marketplace/marketplace_messages_page.dart'
replace_once(
    messages,
    "  @override\n"
    "  Widget build(BuildContext context) {\n"
    "    final uid = FirebaseAuth.instance.currentUser?.uid;\n"
    "    if (uid == null) return _SignedOutMessages();\n"
    "    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(\n",
    "  @override\n"
    "  Widget build(BuildContext context) {\n"
    "    final uid = FirebaseAuth.instance.currentUser?.uid;\n"
    "    if (uid == null) return _SignedOutMessages();\n"
    "    return Column(\n"
    "      children: [\n"
    "        Container(\n"
    "          width: double.infinity,\n"
    "          padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),\n"
    "          child: Row(\n"
    "            children: [\n"
    "              IconButton(\n"
    "                tooltip: 'Back',\n"
    "                onPressed: () =>\n"
    "                    context.canPop() ? context.pop() : context.go('/'),\n"
    "                icon: const Icon(Icons.arrow_back),\n"
    "              ),\n"
    "              const SizedBox(width: 4),\n"
    "              const Expanded(\n"
    "                child: Text(\n"
    "                  'Forum & Messages',\n"
    "                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),\n"
    "                ),\n"
    "              ),\n"
    "            ],\n"
    "          ),\n"
    "        ),\n"
    "        Expanded(\n"
    "          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(\n",
)
replace_once(
    messages,
    "      },\n"
    "    );\n"
    "  }\n"
    "}\n\n"
    "class _ActivityLimitNotice",
    "      },\n"
    "    )),\n"
    "      ],\n"
    "    );\n"
    "  }\n"
    "}\n\n"
    "class _ActivityLimitNotice",
)

# Standalone onboarding/admin windows must not suppress the route back button.
for path in [
    'lib/marketplace/marketplace_profile_page.dart',
    'lib/marketplace/marketplace_tax_compliance_admin_page.dart',
]:
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    text = text.replace('automaticallyImplyLeading: false,',
                        'automaticallyImplyLeading: true,')
    p.write_text(text, encoding='utf-8')

security = 'lib/marketplace/marketplace_account_security_page.dart'
p = Path(security)
text = p.read_text(encoding='utf-8')
text = text.replace('automaticallyImplyLeading: !widget.onboarding,',
                    'automaticallyImplyLeading: true,')
p.write_text(text, encoding='utf-8')

print('Back navigation patch applied.')
