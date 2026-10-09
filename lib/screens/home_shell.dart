import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

import 'dashboard_screen.dart';
import 'debts_screen.dart';
import 'inventory_screen.dart';
import 'invoices_screen.dart';
import 'partners_screen.dart';
import 'profits_screen.dart';
import 'settings_screen.dart';
import 'shipments_screen.dart';
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
  _Dest('العمال', Icons.engineering_outlined, WorkersScreen()),
  _Dest('المخازن', Icons.warehouse_outlined, InventoryScreen()),
  _Dest('الفواتير', Icons.request_quote_outlined, InvoicesScreen()),
  _Dest('الديون', Icons.account_balance_wallet_outlined, DebtsScreen()),
  _Dest('الشحنات البحرية', Icons.directions_boat_outlined, ShipmentsScreen()),
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
    final width = MediaQuery.sizeOf(context).width;
    final page = _dests[_index].page;
    const appName = 'مدبّر';
    final label = Theme.of(context).textTheme.labelLarge;

    if (width >= 800) {
      // اسم كل خيار يظهر بجانب أيقونته دائماً على الشاشات العريضة.
      const extended = true;
      return Scaffold(
        body: Row(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.navBackground, AppColors.navBackgroundEnd],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: NavigationRail(
                extended: extended,
                minExtendedWidth: 220,
                backgroundColor: Colors.transparent,
                indicatorColor: AppColors.navSelected,
                selectedIconTheme: const IconThemeData(
                  color: AppColors.navAccent,
                ),
                unselectedIconTheme: const IconThemeData(
                  color: AppColors.navMuted,
                ),
                selectedLabelTextStyle: label?.copyWith(
                  color: AppColors.navAccent,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelTextStyle: label?.copyWith(
                  color: AppColors.navMuted,
                ),
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _Logo(),
                      if (extended) ...[
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appName,
                              style: TextStyle(
                                color: AppColors.navText,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'إدارة الأعمال',
                              style: TextStyle(
                                color: AppColors.navMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                destinations: [
                  for (final d in _dests)
                    NavigationRailDestination(
                      icon: Icon(d.icon),
                      label: Text(d.label),
                    ),
                ],
              ),
            ),
            Expanded(child: page),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_dests[_index].label),
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(color: AppColors.sidebar.last),
        ),
      ),
      drawer: Theme(
        data: Theme.of(context).copyWith(
          navigationDrawerTheme: NavigationDrawerThemeData(
            backgroundColor: AppColors.navBackground,
            indicatorColor: AppColors.navSelected,
            iconTheme: WidgetStateProperty.resolveWith(
              (s) => IconThemeData(
                color: s.contains(WidgetState.selected)
                    ? AppColors.navAccent
                    : AppColors.navMuted,
              ),
            ),
            labelTextStyle: WidgetStateProperty.resolveWith(
              (s) => label?.copyWith(
                color: s.contains(WidgetState.selected)
                    ? AppColors.navAccent
                    : AppColors.navMuted,
                fontWeight: s.contains(WidgetState.selected)
                    ? FontWeight.bold
                    : null,
              ),
            ),
          ),
        ),
        child: NavigationDrawer(
          selectedIndex: _index,
          onDestinationSelected: (i) {
            setState(() => _index = i);
            Navigator.pop(context);
          },
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Row(
                children: [
                  _Logo(),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$appName - إدارة الأعمال',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.navText,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            for (final d in _dests)
              NavigationDrawerDestination(
                icon: Icon(d.icon),
                label: Text(d.label),
              ),
          ],
        ),
      ),
      body: page,
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.gold,
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Icon(Icons.business, color: Color(0xFF07291F), size: 26),
  );
}
