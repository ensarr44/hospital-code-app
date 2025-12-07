import 'package:flutter/material.dart';

// 📦 Paket import + alias (yolu doğruysa kesin bulur)
import 'package:hospital_code_app/history_page.dart' as pages;
import 'package:hospital_code_app/settings_page.dart' as pages;
import 'package:hospital_code_app/main.dart' show HomePage;

class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  late final _pages = <Widget>[
    const HomePage(),       // Panel
    const pages.HistoryPage(),  // Geçmiş
    pages.SettingsPage(),       // Ayarlar (const YOK)
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
