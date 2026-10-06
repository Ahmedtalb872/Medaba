import 'package:flutter/material.dart';

import 'dashboard_screen.dart';
import 'investors_screen.dart';
import 'partners_screen.dart';
import 'profits_screen.dart';
import 'settings_screen.dart';
import 'transactions_screen.dart';
import 'workers_screen.dart';

class _Dest {
  final String label;
  final IconData icon;
  final Widget page;
  const _Dest(this.label, this.icon, this.page);
}

const _dests = [
  _Dest('لوحة التحكم', Icons.dashboard_outlined, DashboardScreen()),
  _Dest('الشركاء', Icons.handshake_outlined, PartnersScreen()),
  _Dest('المستثمرون', Icons.account_balance_outlined, InvestorsScreen()),
  _Dest('العمال', Icons.engineering_outlined, WorkersScreen()),
  _Dest('المعاملات', Icons.receipt_long_outlined, TransactionsScreen()),
  _Dest('توزيع الأرباح', Icons.pie_chart_outline, ProfitsScreen()),
  _Dest('الإعدادات', Icons.settings_outlined, SettingsScreen()),
];

/// الهيكل الرئيسي: قائمة جانبية على الشاشات العريضة، ودرج (Drawer) على الجوال.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final page = _dests[_index].page;
    const title = Text('مدبّر - إدارة الأعمال');

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: MediaQuery.sizeOf(context).width >= 1100,
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Icon(Icons.business, size: 32),
              ),
              destinations: [
                for (final d in _dests)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: page),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: title),
      drawer: NavigationDrawer(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          Navigator.pop(context);
        },
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(28, 24, 16, 16),
            child: title,
          ),
          for (final d in _dests)
            NavigationDrawerDestination(
              icon: Icon(d.icon),
              label: Text(d.label),
            ),
        ],
      ),
      body: page,
    );
  }
}
