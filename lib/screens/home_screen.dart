import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';
import '../widgets/kpi_card.dart';
import '../widgets/stock_movement_dialog.dart';

class HomeScreen extends StatefulWidget {
  final Function(int tabIndex)? onNavigateTab;

  const HomeScreen({super.key, this.onNavigateTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    final kpi = MockData.kpiSummary;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accentGold,
          backgroundColor: AppColors.bgCard,
          onRefresh: () async {
            await Future.delayed(const Duration(milliseconds: 500));
            setState(() {});
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row
                Row(
                  children: [
                    // Brand Monogram
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppColors.goldGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentGold.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'SE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'ScaleEzy Boutique',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.accentSuccess,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Flagship Store • demo-client',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Notification Icon with Unread Badge
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderLight),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: Stack(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications_none_rounded, color: AppColors.textPrimary, size: 22),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('4 low stock items need attention'),
                                  backgroundColor: AppColors.textPrimary,
                                ),
                              );
                            },
                          ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.accentDanger,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Hero Valuation Portfolio Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppColors.heroGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.auto_awesome, color: Color(0xFFFDE68A), size: 16),
                              SizedBox(width: 6),
                              Text(
                                'TOTAL INVENTORY VALUATION',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF94A3B8),
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'WAC Basis',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        currencyFormat.format(kpi.inventoryValue),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -1.2,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildHeroStat('28', 'Active Styles'),
                            Container(width: 1, height: 24, color: Colors.white12),
                            _buildHeroStat('119', 'Units In Stock'),
                            Container(width: 1, height: 24, color: Colors.white12),
                            _buildHeroStat('+4.2%', 'MoM Growth', isTrend: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // Quick Actions Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Warehouse Ops',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.accentGold.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildQuickActionButton(
                        icon: Icons.qr_code_scanner_rounded,
                        label: 'Scan Tag',
                        accentColor: AppColors.accentGold,
                        bgColor: AppColors.accentGoldLight,
                        onTap: () => widget.onNavigateTab?.call(2),
                      ),
                      const SizedBox(width: 10),
                      _buildQuickActionButton(
                        icon: Icons.add_box_rounded,
                        label: 'Stock In',
                        accentColor: AppColors.accentSuccess,
                        bgColor: AppColors.accentSuccessLight,
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => StockMovementDialog(
                              title: 'Silk Anarkali Suit',
                              sku: 'SKU-ANR-RED-S',
                              currentStock: '12',
                              isStockIn: true,
                              onConfirm: (qty, reason, cost) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Added $qty units ($reason). WAC updated!'),
                                    backgroundColor: AppColors.accentSuccess,
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      _buildQuickActionButton(
                        icon: Icons.indeterminate_check_box_rounded,
                        label: 'Stock Out',
                        accentColor: AppColors.accentDanger,
                        bgColor: AppColors.accentDangerLight,
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => StockMovementDialog(
                              title: 'Silk Anarkali Suit',
                              sku: 'SKU-ANR-RED-S',
                              currentStock: '12',
                              isStockIn: false,
                              onConfirm: (qty, reason, cost) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Dispatched $qty units from stock.'),
                                    backgroundColor: AppColors.accentDanger,
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      _buildQuickActionButton(
                        icon: Icons.checklist_rounded,
                        label: 'Stock Audit',
                        accentColor: AppColors.accentPurple,
                        bgColor: AppColors.accentPurpleLight,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Physical inventory audit initiated.'),
                              backgroundColor: AppColors.textPrimary,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // Operational KPIs
                const Text(
                  'Operations Overview',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 10),

                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.55,
                  children: [
                    KpiCard(
                      title: 'Open PO Value',
                      value: currencyFormat.format(kpi.openPoValue),
                      subtitle: '2 in transit from vendors',
                      icon: Icons.local_shipping_outlined,
                      accentColor: AppColors.accentBlue,
                      bgColor: AppColors.accentBlueLight,
                      onTap: () => widget.onNavigateTab?.call(3),
                    ),
                    KpiCard(
                      title: 'Low Stock Alerts',
                      value: '${kpi.lowStockCount} SKUs',
                      subtitle: 'Action needed immediately',
                      icon: Icons.warning_amber_rounded,
                      accentColor: AppColors.accentDanger,
                      bgColor: AppColors.accentDangerLight,
                      onTap: () => widget.onNavigateTab?.call(1),
                    ),
                    KpiCard(
                      title: 'Dead Stock Value',
                      value: currencyFormat.format(kpi.deadStockValue),
                      subtitle: '>90 days no movement',
                      icon: Icons.inventory_2_outlined,
                      accentColor: AppColors.accentWarning,
                      bgColor: const Color(0xFFFFFBEB),
                      onTap: () => widget.onNavigateTab?.call(1),
                    ),
                    KpiCard(
                      title: 'Stock Health',
                      value: '94.2%',
                      subtitle: 'Optimal turnover rate',
                      icon: Icons.trending_up_rounded,
                      accentColor: AppColors.accentSuccess,
                      bgColor: AppColors.accentSuccessLight,
                      onTap: () => widget.onNavigateTab?.call(1),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Urgent Reorder Alerts Banner
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Urgent Stock Alerts',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    TextButton(
                      onPressed: () => widget.onNavigateTab?.call(1),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text(
                        'View All',
                        style: TextStyle(color: AppColors.accentGold, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _buildAlertCard(
                  title: 'Silk Anarkali Kurti (Size M, Crimson Red)',
                  sku: 'SKU-ANR-RED-M',
                  stock: 3,
                  reorderLevel: 5,
                  onQuickStockIn: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => StockMovementDialog(
                        title: 'Silk Anarkali (M, Red)',
                        sku: 'SKU-ANR-RED-M',
                        currentStock: '3',
                        isStockIn: true,
                        onConfirm: (qty, reason, cost) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added $qty to SKU-ANR-RED-M'),
                              backgroundColor: AppColors.accentSuccess,
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _buildAlertCard(
                  title: 'Handloom Zari Banarasi Saree (Emerald)',
                  sku: 'SKU-BAN-EMR-FREE',
                  stock: 2,
                  reorderLevel: 5,
                  onQuickStockIn: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => StockMovementDialog(
                        title: 'Banarasi Saree (Emerald)',
                        sku: 'SKU-BAN-EMR-FREE',
                        currentStock: '2',
                        isStockIn: true,
                        onConfirm: (qty, reason, cost) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added $qty to SKU-BAN-EMR-FREE'),
                              backgroundColor: AppColors.accentSuccess,
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Recent Ledger Activity
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Live Stock Movements',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Audit Trail',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: MockData.recentTransactions.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final tx = MockData.recentTransactions[index];
                    final isPositive = tx.quantity > 0;
                    final isAdjustment = tx.type == 'ADJUSTMENT';

                    final Color badgeColor = isPositive
                        ? AppColors.accentSuccess
                        : (isAdjustment ? AppColors.accentPurple : AppColors.accentBlue);

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderLight),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isPositive
                                  ? Icons.arrow_downward_rounded
                                  : (isAdjustment ? Icons.sync_alt_rounded : Icons.arrow_upward_rounded),
                              color: badgeColor,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tx.reason.replaceAll('_', ' '),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${tx.sku} • ${tx.reference}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                isPositive ? '+${tx.quantity}' : '${tx.quantity}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: badgeColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Bal: ${tx.balanceAfter}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroStat(String value, String label, {bool isTrend = false}) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isTrend)
              const Icon(Icons.trending_up, color: Color(0xFF34D399), size: 14),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isTrend ? const Color(0xFF34D399) : Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color accentColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderLight),
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: accentColor),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertCard({
    required String title,
    required String sku,
    required int stock,
    required int reorderLevel,
    required VoidCallback onQuickStockIn,
  }) {
    final progress = (stock / reorderLevel).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentDanger.withValues(alpha: 0.2)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentDangerLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.error_outline_rounded, color: AppColors.accentDanger, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sku,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: onQuickStockIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGoldLight,
                  foregroundColor: AppColors.accentGold,
                  elevation: 0,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: AppColors.accentGoldBorder),
                  ),
                ),
                child: const Text('Stock In', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: AppColors.bgSurface,
                    valueColor: const AlwaysStoppedAnimation(AppColors.accentDanger),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$stock of $reorderLevel min',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentDanger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
