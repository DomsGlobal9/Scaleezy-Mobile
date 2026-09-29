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
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.accentGold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.auto_awesome, color: AppColors.accentGold, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ScaleEzy',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Boutique Inventory • demo-client',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_outlined, color: AppColors.textSecondary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All alerts are up to date'),
                  backgroundColor: AppColors.bgCard,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.accentGold,
        backgroundColor: AppColors.bgCard,
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 600));
          setState(() {});
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // KPI Overview Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Executive KPIs',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Real-Time WAC',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.accentGold.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // KPI Grid: 2 columns
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.6,
                children: [
                  KpiCard(
                    title: 'Inventory Value',
                    value: currencyFormat.format(kpi.inventoryValue),
                    icon: Icons.account_balance_wallet_outlined,
                    accentColor: AppColors.accentBlue,
                    bgColor: AppColors.accentBlue.withValues(alpha: 0.12),
                    onTap: () => widget.onNavigateTab?.call(1),
                  ),
                  KpiCard(
                    title: 'Open PO Value',
                    value: currencyFormat.format(kpi.openPoValue),
                    icon: Icons.receipt_long_outlined,
                    accentColor: AppColors.accentGold,
                    bgColor: AppColors.accentGold.withValues(alpha: 0.12),
                    onTap: () => widget.onNavigateTab?.call(3),
                  ),
                  KpiCard(
                    title: 'Low Stock Alerts',
                    value: '${kpi.lowStockCount} SKUs',
                    icon: Icons.warning_amber_rounded,
                    accentColor: AppColors.accentDanger,
                    bgColor: AppColors.accentDanger.withValues(alpha: 0.12),
                    onTap: () => widget.onNavigateTab?.call(1),
                  ),
                  KpiCard(
                    title: 'Active Garments',
                    value: '${kpi.activeProducts} Items',
                    icon: Icons.check_circle_outline_rounded,
                    accentColor: AppColors.accentSuccess,
                    bgColor: AppColors.accentSuccess.withValues(alpha: 0.12),
                    onTap: () => widget.onNavigateTab?.call(1),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Quick Actions
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildActionButton(
                      icon: Icons.qr_code_scanner,
                      label: 'Scan Barcode',
                      color: AppColors.accentGold,
                      onTap: () => widget.onNavigateTab?.call(2),
                    ),
                    const SizedBox(width: 10),
                    _buildActionButton(
                      icon: Icons.add_box_outlined,
                      label: 'Quick Stock-In',
                      color: AppColors.accentSuccess,
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
                    _buildActionButton(
                      icon: Icons.add_circle_outline,
                      label: 'Add Product',
                      color: AppColors.accentBlue,
                      onTap: () => widget.onNavigateTab?.call(1),
                    ),
                    const SizedBox(width: 10),
                    _buildActionButton(
                      icon: Icons.fact_check_outlined,
                      label: 'Audit Count',
                      color: AppColors.accentPurple,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Audit mode active. Scan items on aisle.'),
                            backgroundColor: AppColors.bgCard,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Urgent Low Stock Warnings
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Urgent Reorder Alerts',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: () => widget.onNavigateTab?.call(1),
                    child: const Text(
                      'View Catalog',
                      style: TextStyle(color: AppColors.accentGold, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _buildLowStockCard(
                title: 'Silk Anarkali Kurti (Size M, Crimson Red)',
                sku: 'SKU-ANR-RED-M',
                remaining: 3,
                reorderLevel: 5,
              ),
              const SizedBox(height: 8),
              _buildLowStockCard(
                title: 'Zari Banarasi Saree (Emerald Green)',
                sku: 'SKU-BAN-EMR-FREE',
                remaining: 2,
                reorderLevel: 5,
              ),

              const SizedBox(height: 24),

              // Recent Inventory Transactions Feed
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Ledger Movements',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Text(
                    'Audit Log',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
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

                  Color badgeColor = isPositive
                      ? AppColors.accentSuccess
                      : (isAdjustment ? AppColors.accentPurple : AppColors.accentBlue);

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
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
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${tx.sku} • ${tx.reference}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
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
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: badgeColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Bal: ${tx.balanceAfter}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
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
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLowStockCard({
    required String title,
    required String sku,
    required int remaining,
    required int reorderLevel,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accentDanger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentDanger.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accentDanger.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.notification_important, color: AppColors.accentDanger, size: 18),
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
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$sku • Reorder point: $reorderLevel units',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accentDanger,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$remaining Left',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
