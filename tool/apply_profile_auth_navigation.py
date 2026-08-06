from pathlib import Path

shell_path = Path('lib/marketplace/marketplace_adaptive_shell.dart')
oil_path = Path('lib/marketplace/oil_gas_marketplace.dart')
test_path = Path('test/marketplace_adaptive_shell_test.dart')

shell = shell_path.read_text(encoding='utf-8')

shell = shell.replace(
    "    this.railLeading,\n    this.railTrailing,\n",
    "    this.railLeading,\n    this.railTrailing,\n    this.railFooter,\n",
)
shell = shell.replace(
    "  final Widget? railLeading;\n  final Widget? railTrailing;\n",
    "  final Widget? railLeading;\n  final Widget? railTrailing;\n  final Widget? railFooter;\n",
)
old_rail = """                  NavigationRail(
                    selectedIndex: _selectedDestinationIndex(
                      railDestinations,
                    ),
                    onDestinationSelected: (index) => onDestinationSelected(
                      railDestinations[index].pageIndex,
                    ),
                    extended: extendRail,
                    scrollable: true,
                    groupAlignment: -1,
                    backgroundColor: navigationBackgroundColor,
                    indicatorColor: indicatorColor,
                    leading: railLeading,
                    trailing: railTrailing,
                    destinations: railDestinations
                        .map(
                          (destination) => NavigationRailDestination(
                            icon: destination.icon,
                            selectedIcon:
                                destination.selectedIcon ?? destination.icon,
                            label: Text(destination.label),
                          ),
                        )
                        .toList(growable: false),
                  ),
"""
new_rail = """                  SizedBox(
                    width: extendRail ? 256 : 80,
                    child: Column(
                      children: [
                        Expanded(
                          child: NavigationRail(
                            selectedIndex: _selectedDestinationIndex(
                              railDestinations,
                            ),
                            onDestinationSelected: (index) =>
                                onDestinationSelected(
                              railDestinations[index].pageIndex,
                            ),
                            extended: extendRail,
                            scrollable: true,
                            groupAlignment: -1,
                            backgroundColor: navigationBackgroundColor,
                            indicatorColor: indicatorColor,
                            leading: railLeading,
                            trailing: railTrailing,
                            destinations: railDestinations
                                .map(
                                  (destination) => NavigationRailDestination(
                                    icon: destination.icon,
                                    selectedIcon: destination.selectedIcon ??
                                        destination.icon,
                                    label: Text(destination.label),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ),
                        if (railFooter != null)
                          SafeArea(
                            top: false,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                              child: SizedBox(
                                width: double.infinity,
                                child: railFooter,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
"""
if old_rail not in shell:
    raise SystemExit('Adaptive shell rail block not found')
shell = shell.replace(old_rail, new_rail, 1)
shell_path.write_text(shell, encoding='utf-8')

oil = oil_path.read_text(encoding='utf-8')

oil = oil.replace("          'Account',\n          'Auctions',", "          'Profile',\n          'Auctions',", 1)
oil = oil.replace("            label: 'Account',", "            label: 'Profile',", 2)

rail_leading = """        railLeading: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
          child: Tooltip(
            message: 'Pipe Buyer marketplace',
            child: Image.asset(
              'assets/images/pipe_buyer_logo.png',
              width: 54,
              height: 42,
              fit: BoxFit.contain,
            ),
          ),
        ),
"""
rail_with_footer = rail_leading + """        railFooter: LayoutBuilder(
          builder: (context, constraints) {
            final signedIn = FirebaseAuth.instance.currentUser != null;
            final extended = constraints.maxWidth >= 180;
            final icon = signedIn ? Icons.logout : Icons.login;
            final label = signedIn ? 'Sign out' : 'Sign in';
            final onPressed = signedIn ? _signOut : _openAuth;
            if (!extended) {
              return IconButton(
                tooltip: label,
                onPressed: onPressed,
                icon: Icon(icon),
              );
            }
            return OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(label),
            );
          },
        ),
"""
if rail_leading not in oil:
    raise SystemExit('Rail leading block not found')
oil = oil.replace(rail_leading, rail_with_footer, 1)

oil = oil.replace(
    "  Future<void> _openAuth() async {\n    Navigator.of(context).pop();\n",
    "  Future<void> _openAuth() async {\n    if (_scaffoldKey.currentState?.isDrawerOpen == true) {\n      Navigator.of(context).pop();\n    }\n",
    1,
)
oil = oil.replace(
    "  Future<void> _signOut() async {\n    Navigator.of(context).pop();\n",
    "  Future<void> _signOut() async {\n    if (_scaffoldKey.currentState?.isDrawerOpen == true) {\n      Navigator.of(context).pop();\n    }\n",
    1,
)
oil_path.write_text(oil, encoding='utf-8')

test = test_path.read_text(encoding='utf-8')
test = test.replace("      label: 'Account',", "      label: 'Profile',", 1)
test = test.replace(
    "    ValueChanged<int>? onDestinationSelected,\n  }) async {",
    "    ValueChanged<int>? onDestinationSelected,\n    Widget? railFooter,\n  }) async {",
    1,
)
test = test.replace(
    "          railDestinations: railDestinations,\n          onDestinationSelected:",
    "          railDestinations: railDestinations,\n          railFooter: railFooter,\n          onDestinationSelected:",
    1,
)
insert_before = """  testWidgets('caps wide marketplace content at the shared maximum',
      (tester) async {
"""
new_test = """  testWidgets('pins the rail footer below desktop destinations',
      (tester) async {
    await pumpShell(
      tester,
      width: 1300,
      railFooter: const Text('Sign out', key: Key('rail-auth-footer')),
    );

    expect(find.byKey(const Key('rail-auth-footer')), findsOneWidget);
    final dispatchBottom = tester.getBottomLeft(find.text('Dispatch')).dy;
    final footerTop = tester.getTopLeft(
      find.byKey(const Key('rail-auth-footer')),
    ).dy;
    expect(footerTop, greaterThan(dispatchBottom));
  });

""" + insert_before
if insert_before not in test:
    raise SystemExit('Test insertion point not found')
test = test.replace(insert_before, new_test, 1)
test_path.write_text(test, encoding='utf-8')
