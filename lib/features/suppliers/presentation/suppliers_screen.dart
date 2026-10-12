import 'package:flutter/material.dart';

import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/utils/contact_utils.dart';
import 'package:scaleezy/core/widgets/async_state.dart';
import 'package:scaleezy/core/widgets/ui.dart';
import 'package:scaleezy/features/suppliers/data/supplier_models.dart';
import 'package:scaleezy/features/suppliers/data/supplier_repository.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final _query = TextEditingController();
  List<Supplier>? _all;
  String? _error;
  bool _showInactive = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final s = await SupplierRepository().suppliers();
      if (mounted) setState(() => _all = s);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.text.trim().toLowerCase();
    final list = (_all ?? const <Supplier>[])
        .where((s) => _showInactive || s.active)
        .where(
          (s) =>
              q.isEmpty ||
              '${s.name} ${s.code} ${s.phone ?? ''} ${s.email ?? ''}'
                  .toLowerCase()
                  .contains(q),
        )
        .toList();
    final inactive = (_all ?? const <Supplier>[])
        .where((s) => !s.active)
        .length;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(
              title: 'Suppliers',
              subtitle: _all == null ? null : '${list.length} shown',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: SearchField(
                controller: _query,
                hint: 'Name, code, phone',
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (inactive > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SwitchListTile.adaptive(
                  value: _showInactive,
                  onChanged: (v) => setState(() => _showInactive = v),
                  activeTrackColor: AppColors.accentGold,
                  dense: true,
                  title: Text(
                    'Show $inactive inactive',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            Expanded(
              child: _all == null && _error != null
                  ? ErrorView(message: _error!, onRetry: _load)
                  : _all == null
                  ? ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        for (var i = 0; i < 5; i++)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: Skeleton(height: 96, radius: 18),
                          ),
                      ],
                    )
                  : list.isEmpty
                  ? const ErrorView(message: 'No suppliers match.')
                  : RefreshIndicator(
                      color: AppColors.accentGold,
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
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
    final colour = avatarColour(s.id);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colour.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  initialsOf(s.name),
                  style: TextStyle(color: colour, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${s.code} • ${s.purchaseOrders} purchase ${s.purchaseOrders == 1 ? 'order' : 'orders'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (!s.active)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'INACTIVE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
          if (s.address != null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.place_outlined,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    s.address!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
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
                    s.phone!,
                    AppColors.accentSuccess,
                    Uri(scheme: 'tel', path: s.phone),
                  ),
                  _chip(
                    Icons.chat_rounded,
                    'WhatsApp',
                    const Color(0xFF16A34A),
                    Uri.parse('https://wa.me/${whatsappNumber(s.phone!)}'),
                  ),
                ],
                if (s.email != null)
                  _chip(
                    Icons.mail_rounded,
                    'Email',
                    AppColors.accentBlue,
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );
}
