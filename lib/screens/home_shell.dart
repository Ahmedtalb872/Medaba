import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart' as fmt;
import '../utils/fullscreen.dart';
import '../widgets/brand.dart';
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
  _Dest('لوحة التحكم', Icons.home_outlined, DashboardScreen()),
  _Dest('الشركاء', Icons.handshake_outlined, PartnersScreen()),
  _Dest('العمال', Icons.engineering_outlined, WorkersScreen()),
  _Dest('المخازن', Icons.warehouse_outlined, InventoryScreen()),
  _Dest('الفواتير', Icons.description_outlined, InvoicesScreen()),
  _Dest('الديون', Icons.account_balance_wallet_outlined, DebtsScreen()),
  _Dest('الشحنات البحرية', Icons.directions_boat_outlined, ShipmentsScreen()),
  _Dest('المعاملات', Icons.receipt_long_outlined, TransactionsScreen()),
  _Dest('توزيع الأرباح', Icons.pie_chart_outline, ProfitsScreen()),
  _Dest('الإعدادات', Icons.settings_outlined, SettingsScreen()),
];

// أرقام الصفحات التي تفتحها نتائج البحث والتنبيهات.
const _partnersPage = 1;
const _workersPage = 2;
const _inventoryPage = 3;
const _debtsPage = 5;
const _shipmentsPage = 6;
const _settingsPage = 9;

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
    final page = _dests[_index].page;

    if (width >= 900) {
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(index: _index, onSelect: _go),
            Expanded(
              child: Column(
                children: [
                  _TopBar(onNavigate: _go),
                  Expanded(child: page),
                ],
              ),
            ),
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

/// القائمة الجانبية الخضراء: الشعار، الصفحات، وبطاقة إجمالي الأرباح.
class _Sidebar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  const _Sidebar({required this.index, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 270,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D4A36), AppColors.navBackground],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          // دوائر شفافة خفيفة تعطي عمقاً للخلفية.
          const PositionedDirectional(
            start: -120,
            top: 260,
            child: _Glow(size: 320),
          ),
          const PositionedDirectional(
            end: -140,
            bottom: 60,
            child: _Glow(size: 300),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 22, 16, 18),
                  child: Center(
                    child: FittedBox(child: BrandLogo(onDark: true, size: 44)),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
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
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: _ProfitCard(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final double size;
  const _Glow({required this.size});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.05),
        width: 40,
      ),
    ),
  );
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
    final color = selected ? AppColors.navAccent : AppColors.navText;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: selected
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: [
                        AppColors.navAccent.withValues(alpha: 0.30),
                        AppColors.navAccent.withValues(alpha: 0.10),
                      ],
                      begin: AlignmentDirectional.centerStart,
                      end: AlignmentDirectional.centerEnd,
                    ),
                    border: Border.all(
                      color: AppColors.navAccent.withValues(alpha: 0.35),
                    ),
                  )
                : null,
            child: Row(
              children: [
                Icon(dest.icon, color: color, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    dest.label,
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
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

/// صافي الأرباح منذ بداية التسجيل.
class _ProfitCard extends StatelessWidget {
  const _ProfitCard();

  @override
  Widget build(BuildContext context) {
    final net = context.select<AppState, double>(
      (s) => s.profitReport().netProfit,
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'إجمالي الأرباح',
                  style: TextStyle(color: AppColors.navMuted, fontSize: 13),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    fmt.number(net),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bar_chart, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// الشريط العلوي: التاريخ، البحث العام، ملء الشاشة، التنبيهات، والمستخدم.
class _TopBar extends StatefulWidget {
  final ValueChanged<int> onNavigate;
  const _TopBar({required this.onNavigate});

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  final _search = TextEditingController();

  static const _weekdays = [
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final company = context.select<AppState, (String, String)>(
      (s) => (s.company.ownerName, s.company.ownerRole),
    );
    final fill = dark ? cs.surfaceContainerHigh : const Color(0xFFF3F4F6);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: dark ? cs.surfaceContainer : Colors.white,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_month_outlined, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _weekdays[now.weekday - 1],
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
              Text(
                fmt.date(now),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(width: 24),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: (q) => _openSearch(context, q, widget.onNavigate),
                decoration: InputDecoration(
                  hintText: 'ابحث عن فاتورة أو منتج أو عميل ...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: fill,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          if (fullscreenSupported) ...[
            _SquareButton(
              tooltip: 'ملء الشاشة',
              icon: Icons.fullscreen,
              onTap: toggleFullscreen,
            ),
            const SizedBox(width: 10),
          ],
          _Bell(onNavigate: widget.onNavigate),
          const SizedBox(width: 10),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => widget.onNavigate(_settingsPage),
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.brand,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        company.$1,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        company.$2,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  const _SquareButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: dark ? cs.surfaceContainerHigh : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(width: 50, height: 50, child: Icon(icon)),
        ),
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
        page: _inventoryPage,
      ),
    for (final x in s.activeShipments)
      if (x.isDelayed(now) || x.daysToArrival(now) <= 7)
        (
          icon: Icons.directions_boat_outlined,
          color: AppColors.capital.last,
          text: x.isDelayed(now)
              ? 'شحنة متأخرة: ${x.contents}'
              : 'شحنة تصل قريباً: ${x.contents} - ${x.status.label}',
          page: _shipmentsPage,
        ),
    for (final d in s.debts)
      if (d.isOverdue(now))
        (
          icon: Icons.schedule,
          color: AppColors.loss.last,
          text: 'دين متأخر: ${d.personName} (${fmt.money(d.remaining)})',
          page: _debtsPage,
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
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final icon = Badge(
      isLabelVisible: alerts.isNotEmpty,
      label: Text('${alerts.length}'),
      backgroundColor: AppColors.expense.first,
      child: Icon(Icons.notifications_none, color: light ? Colors.white : null),
    );
    return PopupMenuButton<int>(
      tooltip: 'التنبيهات',
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
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: dark ? cs.surfaceContainerHigh : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(14),
              ),
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
            open: () => go(_inventoryPage),
          ),
      for (final p in s.partners)
        if (has([p.name]))
          (
            icon: Icons.handshake_outlined,
            title: p.name,
            subtitle: 'شريك',
            open: () => go(_partnersPage),
          ),
      for (final w in s.workers)
        if (has([w.name]))
          (
            icon: Icons.engineering_outlined,
            title: w.name,
            subtitle: 'عامل',
            open: () => go(_workersPage),
          ),
      for (final d in s.debts)
        if (has([d.personName]))
          (
            icon: Icons.account_balance_wallet_outlined,
            title: d.personName,
            subtitle: 'دين • المتبقي: ${fmt.money(d.remaining)}',
            open: () => go(_debtsPage),
          ),
      for (final x in s.shipments)
        if (has([x.contents, x.company, x.billOfLading, x.containerNumber]))
          (
            icon: Icons.directions_boat_outlined,
            title: x.contents,
            subtitle: '${x.company} • ${x.status.label}',
            open: () => go(_shipmentsPage),
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
