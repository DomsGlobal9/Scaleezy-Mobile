import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:scaleezy/app/app_routes.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/utils/contact_utils.dart';
import 'package:scaleezy/core/utils/money.dart';
import 'package:scaleezy/core/widgets/async_state.dart';
import 'package:scaleezy/core/widgets/ui.dart';
import 'package:scaleezy/features/customers/data/customer_models.dart';
import 'package:scaleezy/features/customers/presentation/view_models/customer_detail_view_model.dart';
import 'package:scaleezy/features/customers/presentation/view_models/customer_form_view_model.dart';
import 'package:scaleezy/features/customers/presentation/view_models/customers_view_model.dart';

class CustomersScreen extends StatefulWidget {
  /// Tests pass their own; otherwise the screen makes and owns one.
  final CustomersViewModel? viewModel;

  const CustomersScreen({super.key, this.viewModel});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  late final CustomersViewModel _vm = widget.viewModel ?? CustomersViewModel();
  final _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    _vm.load();
  }

  @override
  void dispose() {
    if (widget.viewModel == null) _vm.dispose();
    _query.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final created = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => const _CustomerForm(),
    );
    if (created != null && mounted) {
      showMessage(context, '${created.name} added.', success: true);
      _vm.load();
      _open(created);
    }
  }

  Future<void> _open(Customer c) async {
    await AppRoutes.customerDetail(context, c);
    _vm.load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _buildScreen(),
    );
  }

  Widget _buildScreen() {
    final list = _vm.customers;
    final error = _vm.error;
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      floatingActionButton: SessionScope.of(context).can('customer:create')
          ? FloatingActionButton.extended(
              onPressed: _add,
              backgroundColor: AppColors.accentGold,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text(
                'New customer',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(
              title: 'Customers',
              subtitle: list == null
                  ? null
                  : '${list.length} ${list.length == 1 ? 'person' : 'people'}',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: SearchField(
                controller: _query,
                hint: 'Name, phone, email or code',
                onChanged: _vm.search,
              ),
            ),
            Expanded(
              child: list == null && error != null
                  ? ErrorView(message: error, onRetry: _vm.load)
                  : list == null
                  ? ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        for (var i = 0; i < 6; i++)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: Skeleton(height: 72, radius: 18),
                          ),
                      ],
                    )
                  : list.isEmpty
                  ? ErrorView(
                      message: _vm.query.isEmpty
                          ? 'No customers yet.'
                          : 'Nobody matches "${_vm.query}".',
                    )
                  : RefreshIndicator(
                      color: AppColors.accentGold,
                      onRefresh: _vm.load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                        itemCount: list.length,
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _row(list[i]).entrance(i % 15),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(Customer c) {
    final colour = avatarColour(c.id);
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      onTap: () => _open(c),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: colour.withValues(alpha: 0.12),
            child: Text(
              initialsOf(c.name),
              style: TextStyle(color: colour, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    c.phone ?? c.email ?? '',
                    c.code,
                  ].where((s) => s.isNotEmpty).join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (c.status != 'ACTIVE')
            Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                c.status,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          if (c.phone != null)
            IconButton(
              tooltip: 'Call',
              onPressed: () =>
                  launchContact(context, Uri(scheme: 'tel', path: c.phone)),
              icon: const Icon(
                Icons.call_rounded,
                color: AppColors.accentSuccess,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }
}

class CustomerDetailScreen extends StatefulWidget {
  final String customerId;
  final Customer? preview;

  /// Tests pass their own; otherwise the screen makes and owns one.
  final CustomerDetailViewModel? viewModel;

  const CustomerDetailScreen({
    super.key,
    required this.customerId,
    this.preview,
    this.viewModel,
  });

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  late final CustomerDetailViewModel _vm =
      widget.viewModel ?? CustomerDetailViewModel(widget.customerId);
  final _date = DateFormat('d MMM yyyy');

  @override
  void initState() {
    super.initState();
    _vm.load();
  }

  @override
  void dispose() {
    if (widget.viewModel == null) _vm.dispose();
    super.dispose();
  }

  Future<void> _edit() async {
    final updated = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => _CustomerForm(existing: _vm.full ?? widget.preview),
    );
    if (updated != null && mounted) {
      showMessage(context, 'Saved.', success: true);
      _vm.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _buildScreen(),
    );
  }

  Widget _buildScreen() {
    final full = _vm.full;
    final error = _vm.error;
    final c = full ?? widget.preview;
    final orders = full?.orders ?? const [];
    final live = orders.where((o) => o.status != 'CANCELLED').toList();
    final spend = live.fold<double>(0, (a, o) => a + o.totalAmount);
    final colour = avatarColour(widget.customerId);

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accentGold,
          onRefresh: _vm.load,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              PageHeader(
                title: 'Customer',
                actions: [
                  if (c != null &&
                      SessionScope.of(context).can('customer:update'))
                    IconButton(
                      onPressed: _edit,
                      icon: const Icon(Icons.edit_rounded),
                      tooltip: 'Edit',
                    ),
                ],
              ),
              if (c == null && error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 80),
                  child: ErrorView(message: error, onRetry: _vm.load),
                )
              else if (c == null)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Skeleton(height: 220, radius: 22),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Hero(
                        tag: 'customer-${c.id}',
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: colour.withValues(alpha: 0.12),
                          child: Text(
                            initialsOf(c.name),
                            style: TextStyle(
                              color: colour,
                              fontWeight: FontWeight.w900,
                              fontSize: 26,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        c.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (c.companyName != null)
                        Text(
                          c.companyName!,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        c.code,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (c.phone != null) ...[
                            _contact(
                              Icons.call_rounded,
                              'Call',
                              AppColors.accentSuccess,
                              Uri(scheme: 'tel', path: c.phone),
                            ),
                            const SizedBox(width: 10),
                            _contact(
                              Icons.chat_rounded,
                              'WhatsApp',
                              const Color(0xFF16A34A),
                              Uri.parse(
                                'https://wa.me/${whatsappNumber(c.phone!)}',
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          if (c.email != null)
                            _contact(
                              Icons.mail_rounded,
                              'Email',
                              AppColors.accentBlue,
                              Uri(scheme: 'mailto', path: c.email),
                            ),
                        ],
                      ),
                    ],
                  ).entrance(0),
                ),
                const SizedBox(height: 20),
                if (full != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _stat('${live.length}', 'Orders'),
                        const SizedBox(width: 10),
                        _stat(formatRupees(spend), 'Spent'),
                        const SizedBox(width: 10),
                        _stat(
                          live.isEmpty ? '—' : relativeTime(live.first.date),
                          'Last visit',
                        ),
                      ],
                    ).entrance(1),
                  ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SurfaceCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        _info(Icons.phone_outlined, 'Phone', c.phone),
                        _info(Icons.mail_outline_rounded, 'Email', c.email),
                        _info(Icons.receipt_outlined, 'GST', c.gstNumber),
                        _info(Icons.home_outlined, 'Address', c.billingAddress),
                        _info(Icons.sticky_note_2_outlined, 'Notes', c.notes),
                        if (c.createdAt != null)
                          _info(
                            Icons.event_outlined,
                            'Customer since',
                            _date.format(c.createdAt!),
                          ),
                      ],
                    ),
                  ).entrance(2),
                ),
                if (c.tags.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final t in c.tags)
                          Chip(
                            label: Text(
                              t,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            backgroundColor: AppColors.accentGoldLight,
                            side: const BorderSide(
                              color: AppColors.accentGoldBorder,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ),
                ],
                if (orders.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: SectionHeader(title: 'Orders'),
                  ),
                  for (final (i, o) in orders.take(30).indexed)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: SurfaceCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    o.orderNumber,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  Text(
                                    '${_date.format(o.date)} • ${o.itemCount} pcs • ${o.status.replaceAll('_', ' ').toLowerCase()}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              formatRupees(o.totalAmount),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                decoration: o.status == 'CANCELLED'
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: o.status == 'CANCELLED'
                                    ? AppColors.textMuted
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ).entrance(3 + i),
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _contact(IconData icon, String label, Color color, Uri uri) =>
      Pressable(
        onTap: () => launchContact(context, uri),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: color),
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

  Widget _stat(String value, String label) => Expanded(
    child: SurfaceCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Column(
        children: [
          FittedBox(
            child: Text(
              value,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _info(IconData icon, String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20, color: AppColors.textSecondary),
      title: Text(
        label,
        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _CustomerForm extends StatefulWidget {
  final Customer? existing;
  const _CustomerForm({this.existing});

  @override
  State<_CustomerForm> createState() => _CustomerFormState();
}

class _CustomerFormState extends State<_CustomerForm> {
  late final _vm = CustomerFormViewModel(widget.existing);
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _phone = TextEditingController(text: widget.existing?.phone);
  late final _email = TextEditingController(text: widget.existing?.email);
  @override
  void dispose() {
    _vm.dispose();
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final error = await _vm.save(
      name: _name.text,
      phone: _phone.text,
      email: _email.text,
    );
    // A failure shows under the fields (_vm.error), inside the sheet.
    if (error == null && mounted) Navigator.of(context).pop(_vm.saved);
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 20),
    filled: true,
    fillColor: AppColors.bgSurface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _buildForm(),
    );
  }

  Widget _buildForm() {
    final error = _vm.error;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? 'New customer' : 'Edit customer',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: _dec('Name', Icons.person_outline_rounded),
              validator: (v) => (v ?? '').trim().isEmpty
                  ? "Enter the customer's name."
                  : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: _dec('Phone', Icons.phone_outlined),
              validator: (v) => (v ?? '').trim().length < 10
                  ? 'Enter a 10-digit phone number.'
                  : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: _dec('Email (optional)', Icons.mail_outline_rounded),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error,
                style: const TextStyle(
                  color: AppColors.accentDanger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _vm.busy ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentGold,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _vm.busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      widget.existing == null ? 'Add customer' : 'Save',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
