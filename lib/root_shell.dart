import 'package:flutter/material.dart';

import 'package:hospital_code_app/history_page.dart' as history;
import 'package:hospital_code_app/settings_page.dart' as settings;
import 'package:hospital_code_app/main.dart' show HomePage, AppMode;

class RootShell extends StatefulWidget {
  final String email;
  final AppMode mode;

  const RootShell({
    super.key,
    required this.email,
    required this.mode,
  });

  @override
  State<RootShell> createState() => _RootShellState();
}


class _RootShellState extends State<RootShell> {
  int _index = 0;

  late final _pages = <Widget>[
    HomePage(
      email: widget.email,
  mode: widget.mode,
    ),
    const history.HistoryPage(),
    settings.SettingsPage(personelId: widget.email),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Panel',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            selectedIcon: Icon(Icons.history_toggle_off),
            label: 'Geçmiş',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Ayarlar',
          ),
        ],
      ),
    );
  }
}
