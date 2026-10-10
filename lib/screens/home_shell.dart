import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart' as fmt;
import '../widgets/brand.dart';
import '../widgets/shell_nav.dart';
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

/// بنفس ترتيب أرقام [ShellPage].
const _dests = [
  _Dest('الرئيسية', Icons.home_outlined, DashboardScreen()),
  _Dest('الشركاء', Icons.handshake_outlined, PartnersScreen()),
  _Dest('العمال', Icons.badge_outlined, WorkersScreen()),
  _Dest('المخزون', Icons.inventory_2_outlined, InventoryScreen()),
  _Dest('الفواتير', Icons.description_outlined, InvoicesScreen()),
  _Dest('الديون', Icons.account_balance_wallet_outlined, DebtsScreen()),
  _Dest('الشحنات البحرية', Icons.local_shipping_outlined, ShipmentsScreen()),
  _Dest('المعاملات', Icons.receipt_long_outlined, TransactionsScreen()),
  _Dest('التقارير والأرباح', Icons.bar_chart, ProfitsScreen()),
  _Dest('الإعدادات', Icons.settings_outlined, SettingsScreen()),
];

/// خلفية بيضاء بحواف دائرية وظل خفيف لعناصر الشريط العلوي.
BoxDecoration _panel(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  final dark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: dark ? cs.surfaceContainer : Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: const [
      BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 4)),
    ],
  );
}

/// الهيكل الرئيسي: قائمة جانبية وشريط علوي على الشاشات العريضة،
/// ودرج (Drawer) على الجوال.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final page = ShellNav(go: _go, child: _dests[_index].page);

    if (width >= 900) {
      return Scaffold(
        body: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  _TopBar(onNavigate: _go),
                  Expanded(child: page),
                ],
              ),
            ),
            // القائمة في الجهة اليسرى كما في التصميم.
            _Sidebar(index: _index, onSelect: _go),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_dests[_index].label),
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(color: AppColors.navBackground),
        ),
        actions: [
          IconButton(
            tooltip: 'بحث',
            icon: const Icon(Icons.search),
            onPressed: () => _openSearch(context, '', _go),
          ),
          _Bell(onNavigate: _go, light: true),
          const SizedBox(width: 8),
        ],
      ),
      drawer: Drawer(
        width: 280,
        backgroundColor: AppColors.navBackground,
        child: Builder(
          builder: (context) => _Sidebar(
            index: _index,
            onSelect: (i) {
              _go(i);
              Navigator.pop(context);
            },
          ),
        ),
      ),
      body: page,
    );
  }
}

/// القائمة الجانبية الخضراء: الشعار والصفحات.
class _Sidebar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  const _Sidebar({required this.index, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 270,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0B3F2E), Color(0xFF0E4A37), Color(0xFF0A3628)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 26, 16, 26),
              child: Center(
                child: FittedBox(
                  child: BrandLogo(onDark: true, size: 52, showRest: false),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final (i, d) in _dests.indexed)
                    _NavItem(
                      dest: d,
                      selected: i == index,
                      onTap: () => onSelect(i),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final _Dest dest;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({
    required this.dest,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: selected
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFB8893A), Color(0xFFD9AE62)],
                      begin: AlignmentDirectional.centerStart,
                      end: AlignmentDirectional.centerEnd,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x40000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  )
                : null,
            child: Row(
              children: [
                Icon(dest.icon, color: Colors.white, size: 26),
                const SizedBox(width: 18),
                Expanded(
                  child: Text(
                    dest.label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// الشريط العلوي: المستخدم، التنبيهات، والبحث العام.
class _TopBar extends StatefulWidget {
  final ValueChanged<int> onNavigate;
  const _TopBar({required this.onNavigate});

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = context.select<AppState, (String, String)>(
      (s) => (s.company.ownerName, s.company.ownerRole),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Row(
        children: [
          PopupMenuButton<int>(
            tooltip: 'الحساب',
            position: PopupMenuPosition.under,
            onSelected: widget.onNavigate,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: ShellPage.settings,
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined),
                    SizedBox(width: 10),
                    Text('الإعدادات وبيانات المستخدم'),
                  ],
                ),
              ),
            ],
            child: Container(
              height: 64,
              padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 16, 8),
              decoration: _panel(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFFEDEFF2),
                    child: Icon(Icons.person, color: cs.onSurface, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.$1,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        user.$2,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 18),
                  const Icon(Icons.keyboard_arrow_down),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          _Bell(onNavigate: widget.onNavigate),
          const Spacer(),
          Flexible(
            flex: 3,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: DecoratedBox(
                decoration: _panel(context),
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (q) =>
                      _openSearch(context, q, widget.onNavigate),
                  decoration: const InputDecoration(
                    hintText: 'بحث عن منتج، عميل، فاتورة ...',
                    suffixIcon: Icon(Icons.search, size: 26),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// تنبيه في قائمة الجرس: نص والصفحة التي يفتحها.
typedef _Alert = ({IconData icon, Color color, String text, int page});

List<_Alert> _alerts(AppState s) {
  final now = DateTime.now();
  return [
    for (final p in s.lowStockProducts)
      (
        icon: Icons.warning_amber_rounded,
        color: AppColors.expense.last,
        text: 'قارب على النفاد: ${p.name} (${fmt.number(s.stockOf(p.id))})',
        page: ShellPage.inventory,
      ),
    for (final x in s.activeShipments)
      if (x.isDelayed(now) || x.daysToArrival(now) <= 7)
        (
          icon: Icons.directions_boat_outlined,
          color: AppColors.capital.last,
          text: x.isDelayed(now)
              ? 'شحنة متأخرة: ${x.contents}'
              : 'شحنة تصل قريباً: ${x.contents} - ${x.status.label}',
          page: ShellPage.shipments,
        ),
    for (final d in s.debts)
      if (d.isOverdue(now))
        (
          icon: Icons.schedule,
          color: AppColors.loss.last,
          text: 'دين متأخر: ${d.personName} (${fmt.money(d.remaining)})',
          page: ShellPage.debts,
        ),
  ];
}

/// جرس التنبيهات مع عددها؛ كل تنبيه يفتح صفحته.
class _Bell extends StatelessWidget {
  final ValueChanged<int> onNavigate;

  /// على شريط التطبيق الأخضر في الجوال.
  final bool light;
  const _Bell({required this.onNavigate, this.light = false});

  @override
  Widget build(BuildContext context) {
    final alerts = _alerts(context.watch<AppState>());
    final icon = Badge(
      isLabelVisible: alerts.isNotEmpty,
      smallSize: 10,
      backgroundColor: AppColors.expense.first,
      child: Icon(
        Icons.notifications_none,
        size: 28,
        color: light ? Colors.white : null,
      ),
    );
    return PopupMenuButton<int>(
      tooltip: alerts.isEmpty ? 'التنبيهات' : 'التنبيهات (${alerts.length})',
      position: PopupMenuPosition.under,
      onSelected: onNavigate,
      constraints: const BoxConstraints(maxWidth: 380),
      itemBuilder: (_) => alerts.isEmpty
          ? [
              const PopupMenuItem(
                enabled: false,
                child: Text('لا توجد تنبيهات'),
              ),
            ]
          : [
              for (final a in alerts)
                PopupMenuItem(
                  value: a.page,
                  child: Row(
                    children: [
                      Icon(a.icon, color: a.color, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(a.text)),
                    ],
                  ),
                ),
            ],
      child: light
          ? Padding(padding: const EdgeInsets.all(8), child: icon)
          : Container(
              width: 58,
              height: 58,
              decoration: _panel(context),
              child: Center(child: icon),
            ),
    );
  }
}

/// نتيجة بحث عام.
typedef _Hit = ({
  IconData icon,
  String title,
  String subtitle,
  VoidCallback open,
});

/// يبحث في الفواتير والأصناف والشركاء والعمال والديون والشحنات.
Future<void> _openSearch(
  BuildContext context,
  String initial,
  ValueChanged<int> onNavigate,
) {
  final s = context.read<AppState>();
  final controller = TextEditingController(text: initial);

  List<_Hit> find(String raw, BuildContext dialog) {
    final q = raw.trim().toLowerCase();
    if (q.isEmpty) return const [];
    bool has(Iterable<String> xs) => xs.any((x) => x.toLowerCase().contains(q));
    void go(int page) {
      Navigator.pop(dialog);
      onNavigate(page);
    }

    return [
      for (final i in s.invoices)
        if (has([
          i.number,
          i.partyName,
          i.partyPhone,
          for (final l in i.lines) s.productById(l.productId)?.name ?? '',
        ]))
          (
            icon: Icons.description_outlined,
            title: '${i.type.label} ${i.number}',
            subtitle:
                '${i.partyName.isEmpty ? '-' : i.partyName} • '
                '${fmt.date(i.date)} • ${fmt.money(i.total)}',
            open: () {
              Navigator.pop(dialog);
              openInvoicePdf(context, i);
            },
          ),
      for (final p in s.products)
        if (has([p.name, p.code]))
          (
            icon: Icons.category_outlined,
            title: p.name,
            subtitle: 'صنف • المتوفر: ${fmt.number(s.stockOf(p.id))}',
            open: () => go(ShellPage.inventory),
          ),
      for (final p in s.partners)
        if (has([p.name]))
          (
            icon: Icons.handshake_outlined,
            title: p.name,
            subtitle: 'شريك',
            open: () => go(ShellPage.partners),
          ),
      for (final w in s.workers)
        if (has([w.name]))
          (
            icon: Icons.engineering_outlined,
            title: w.name,
            subtitle: 'عامل',
            open: () => go(ShellPage.workers),
          ),
      for (final d in s.debts)
        if (has([d.personName]))
          (
            icon: Icons.account_balance_wallet_outlined,
            title: d.personName,
            subtitle: 'دين • المتبقي: ${fmt.money(d.remaining)}',
            open: () => go(ShellPage.debts),
          ),
      for (final x in s.shipments)
        if (has([x.contents, x.company, x.billOfLading, x.containerNumber]))
          (
            icon: Icons.directions_boat_outlined,
            title: x.contents,
            subtitle: '${x.company} • ${x.status.label}',
            open: () => go(ShellPage.shipments),
          ),
    ];
  }

  return showDialog<void>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (dialog, setState) {
        final hits = find(controller.text, dialog);
        return AlertDialog(
          title: TextField(
            controller: controller,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'ابحث عن فاتورة أو منتج أو عميل ...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          content: SizedBox(
            width: 520,
            height: 380,
            child: controller.text.trim().isEmpty
                ? const Center(child: Text('اكتب كلمة للبحث'))
                : hits.isEmpty
                ? const Center(child: Text('لا توجد نتائج'))
                : ListView(
                    children: [
                      for (final h in hits)
                        ListTile(
                          leading: Icon(h.icon, color: AppColors.brand),
                          title: Text(h.title),
                          subtitle: Text(h.subtitle),
                          onTap: h.open,
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('إغلاق'),
            ),
          ],
        );
      },
    ),
  );
}
