import 'package:flutter/material.dart';

import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/utils/contact_utils.dart';
import 'package:scaleezy/core/widgets/async_state.dart';
import 'package:scaleezy/core/widgets/status_pill.dart';
import 'package:scaleezy/core/widgets/ui.dart';
import 'package:scaleezy/features/customers/data/phone.dart';
import 'package:scaleezy/features/suppliers/data/supplier_models.dart';
import 'package:scaleezy/features/suppliers/presentation/view_models/suppliers_view_model.dart';

class SuppliersScreen extends StatefulWidget {
  /// Tests pass their own; otherwise the screen makes and owns one.
  final SuppliersViewModel? viewModel;

  const SuppliersScreen({super.key, this.viewModel});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final _query = TextEditingController();
  late final SuppliersViewModel _vm = widget.viewModel ?? SuppliersViewModel();

  @override
  void initState() {
    super.initState();
    _vm.load();
  }

  @override
  void dispose() {
    _query.dispose();
    if (widget.viewModel == null) _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _buildScreen(),
    );
  }

  Widget _buildScreen() {
    final list = _vm.visible;
    final failure = _vm.failure;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(
              title: 'Suppliers',
              subtitle: _vm.all == null ? null : '${list.length} shown',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SearchField(
                controller: _query,
                hint: 'Search suppliers by name or code...',
                onChanged: _vm.search,
              ),
            ),
            Expanded(
              child: _vm.all == null && failure != null
                  ? ErrorView.fromError(
                      failure,
                      what: 'suppliers',
                      onRetry: _vm.load,
                    )
                  : _vm.all == null
                  ? ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        for (var i = 0; i < 5; i++)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: Skeleton(height: 96),
                          ),
                      ],
                    )
                  : list.isEmpty
                  ? const EmptyState(
                      Icons.local_shipping_outlined,
                      'No suppliers found.',
                    )
                  : RefreshIndicator(
                      onRefresh: _vm.load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                        itemCount: list.length,
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _card(list[i]).entrance(i % 15),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(Supplier s) {
    final colors = context.colors;
    final type = Theme.of(context).textTheme;
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.input,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.business_rounded,
                  size: 22,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name, style: type.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      '${s.code} · ${s.purchaseOrders} purchase ${s.purchaseOrders == 1 ? 'order' : 'orders'}',
                      style: type.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              s.active
                  ? StatusPill('Active', Tone.success)
                  : StatusPill('Inactive', Tone.danger),
            ],
          ),
          if (s.address != null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.place_outlined, size: 14, color: colors.textMuted),
                const SizedBox(width: 6),
                Expanded(child: Text(s.address!, style: type.bodySmall)),
              ],
            ),
          ],
          if (s.phone != null || s.email != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (s.phone != null) ...[
                  _chip(
                    Icons.call_rounded,
                    formatPhone(s.phone),
                    colors.success,
                    Uri(scheme: 'tel', path: s.phone),
                  ),
                  _chip(
                    Icons.chat_rounded,
                    'WhatsApp',
                    colors.success,
                    Uri.parse('https://wa.me/${whatsappNumber(s.phone!)}'),
                  ),
                ],
                if (s.email != null)
                  _chip(
                    Icons.mail_rounded,
                    'Email',
                    colors.info,
                    Uri(scheme: 'mailto', path: s.email),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color, Uri uri) => Pressable(
    onTap: () => launchContact(context, uri),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tint(color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium!.copyWith(color: color),
          ),
        ],
      ),
    ),
  );
}
