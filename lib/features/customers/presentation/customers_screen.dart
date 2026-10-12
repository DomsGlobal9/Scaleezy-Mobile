import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:scaleezy/app/app_routes.dart';
import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/utils/contact_utils.dart';
import 'package:scaleezy/core/utils/labels.dart';
import 'package:scaleezy/core/utils/money.dart';
import 'package:scaleezy/core/widgets/async_state.dart';
import 'package:scaleezy/core/widgets/status_pill.dart';
import 'package:scaleezy/core/widgets/ui.dart';
import 'package:scaleezy/features/customers/data/customer_models.dart';
import 'package:scaleezy/features/customers/data/phone.dart';
import 'package:scaleezy/features/customers/presentation/view_models/customer_detail_view_model.dart';
import 'package:scaleezy/features/customers/presentation/view_models/customer_form_view_model.dart';
import 'package:scaleezy/features/customers/presentation/view_models/customers_view_model.dart';
import 'package:scaleezy/features/customers/presentation/widgets/points_and_credit_section.dart';
import 'package:scaleezy/features/orders/data/order_models.dart';

/// What the customer form closes with: the saved customer, or ([existing]) the one who already
/// had the number, to open instead.
typedef _FormResult = ({Customer customer, bool existing});

Future<_FormResult?> _showCustomerForm(
  BuildContext context, {
  Customer? existing,
}) => showModalBottomSheet<_FormResult>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _CustomerForm(existing: existing),
);

Widget _statusPill(String status) {
  final look = describeStatus(customerStatuses, status);
  return StatusPill(look.label, look.tone);
}

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
    final result = await _showCustomerForm(context);
    if (result == null || !mounted) return;
    if (!result.existing) {
      showMessage(context, '${result.customer.name} added', success: true);
      _vm.load();
    }
    _open(result.customer);
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
    final failure = _vm.failure;
    return Scaffold(
      floatingActionButton: SessionScope.of(context).can('customer:create')
          ? FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Add customer'),
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
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SearchField(
                controller: _query,
                hint: 'Search by phone, name, code or email...',
                onChanged: _vm.search,
              ),
            ),
            Expanded(
              child: list == null && failure != null
                  ? ErrorView.fromError(
                      failure,
                      what: 'customers',
                      onRetry: _vm.load,
                    )
                  : list == null
                  ? ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        for (var i = 0; i < 6; i++)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: Skeleton(height: 72),
                          ),
                      ],
                    )
                  : list.isEmpty
                  ? const EmptyState(
                      Icons.people_outline_rounded,
                      'No customers found.',
                    )
                  : RefreshIndicator(
                      onRefresh: _vm.load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
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

  /// The website's phone card: name and status, phone · code, then email · company.
  Widget _row(Customer c) {
    final colors = context.colors;
    final type = Theme.of(context).textTheme;
    final extra = [?c.email, ?c.companyName].join(' · ');
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
      onTap: () => _open(c),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.titleSmall,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _statusPill(c.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    children: [
                      c.phone == null
                          ? TextSpan(
                              text: 'No phone',
                              style: TextStyle(color: colors.warning),
                            )
                          : TextSpan(text: formatPhone(c.phone)),
                      TextSpan(text: ' · ${c.code}'),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.bodySmall,
                ),
                if (extra.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    extra,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.labelMedium!.copyWith(
                      fontWeight: FontWeight.w400,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (c.phone != null)
            IconButton(
              tooltip: 'Call',
              onPressed: () =>
                  launchContact(context, Uri(scheme: 'tel', path: c.phone)),
              icon: Icon(Icons.call_rounded, color: colors.success, size: 20),
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
    final result = await _showCustomerForm(
      context,
      existing: _vm.full ?? widget.preview,
    );
    if (result == null || !mounted) return;
    if (result.existing) {
      AppRoutes.customerDetail(context, result.customer);
      return;
    }
    showMessage(context, 'Customer updated', success: true);
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
    final colors = context.colors;
    final type = Theme.of(context).textTheme;
    final full = _vm.full;
    final failure = _vm.failure;
    final c = full ?? widget.preview;
    final orders = full?.orders ?? const [];
    final live = orders.where((o) => o.status != 'CANCELLED').toList();
    final spend = live.fold<double>(0, (a, o) => a + o.totalAmount);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
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
              if (c == null && failure != null)
                Padding(
                  padding: const EdgeInsets.only(top: 80),
                  child: ErrorView.fromError(
                    failure,
                    what: 'this customer',
                    onRetry: _vm.load,
                  ),
                )
              else if (c == null)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Skeleton(height: 220, radius: 16),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Text(
                        c.name,
                        textAlign: TextAlign.center,
                        style: type.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      _statusPill(c.status),
                      if (c.companyName != null) ...[
                        const SizedBox(height: 4),
                        Text(c.companyName!, style: type.bodySmall),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        c.code,
                        style: type.labelMedium!.copyWith(
                          color: colors.textMuted,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          if (c.phone != null) ...[
                            _contact(
                              Icons.call_rounded,
                              'Call',
                              colors.success,
                              Uri(scheme: 'tel', path: c.phone),
                            ),
                            _contact(
                              Icons.chat_rounded,
                              'WhatsApp',
                              colors.success,
                              Uri.parse(
                                'https://wa.me/${whatsappNumber(c.phone!)}',
                              ),
                            ),
                          ],
                          if (c.email != null)
                            _contact(
                              Icons.mail_rounded,
                              'Email',
                              colors.info,
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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SurfaceCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        _info(
                          Icons.phone_outlined,
                          'Phone',
                          formatPhone(c.phone),
                        ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final t in c.tags)
                          Chip(
                            label: Text(t),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ),
                ],
                if (_vm.points != null || _vm.credit != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
                    child: PointsAndCreditSection(
                      points: _vm.points,
                      credit: _vm.credit,
                    ).entrance(3),
                  ),
                if (orders.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SectionHeader(title: 'Orders'),
                  ),
                  for (final (i, o) in orders.take(30).indexed)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: _order(o).entrance(3 + i),
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _order(OrderItemSummary o) {
    final colors = context.colors;
    final type = Theme.of(context).textTheme;
    final cancelled = o.status == 'CANCELLED';
    final look = describeStatus(orderStatuses, o.status);
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        o.orderNumber,
                        overflow: TextOverflow.ellipsis,
                        style: type.titleSmall!.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusPill(look.label, look.tone),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${_date.format(o.date)} · ${o.itemCount} pieces',
                  style: type.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            formatRupees(o.totalAmount),
            style: type.titleSmall!.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              decoration: cancelled ? TextDecoration.lineThrough : null,
              color: cancelled ? colors.textMuted : colors.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _contact(IconData icon, String label, Color color, Uri uri) =>
      Pressable(
        onTap: () => launchContact(context, uri),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: tint(color),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge!.copyWith(color: color),
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
              style: Theme.of(context).textTheme.titleLarge!.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    ),
  );

  Widget _info(IconData icon, String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    final type = Theme.of(context).textTheme;
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20, color: context.colors.textSecondary),
      title: Text(label, style: type.bodySmall),
      subtitle: Text(value, style: type.titleSmall),
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
  late final _phone = TextEditingController(
    text: formatPhone(widget.existing?.phone),
  );
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
    // A failure shows above the buttons (_vm.error), inside the sheet.
    if (error == null && mounted) {
      Navigator.of(context).pop((customer: _vm.saved!, existing: false));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _buildForm(),
    );
  }

  Widget _buildForm() {
    final colors = context.colors;
    final type = Theme.of(context).textTheme;
    final error = _vm.error;
    final taken = _vm.taken;
    final editing = widget.existing != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                editing ? 'Edit customer' : 'Add customer',
                style: type.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                editing
                    ? widget.existing!.code
                    : 'Customers are found by their phone number.',
                style: type.bodySmall,
              ),
              const SizedBox(height: 16),
              // Phone first: "your number?" comes before "your name?" at a counter.
              ValueListenableBuilder(
                valueListenable: _phone,
                builder: (context, value, _) {
                  final checked = normalisePhone(value.text);
                  final empty = value.text.trim().isEmpty;
                  return TextFormField(
                    controller: _phone,
                    autofocus: !editing,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    inputFormatters: [
                      TextInputFormatter.withFunction((_, next) {
                        final kept = typedPhone(next.text);
                        return kept == next.text
                            ? next
                            : TextEditingValue(
                                text: kept,
                                selection: TextSelection.collapsed(
                                  offset: kept.length,
                                ),
                              );
                      }),
                    ],
                    decoration: InputDecoration(
                      labelText: _vm.phoneOptional ? 'Phone' : 'Phone *',
                      hintText: 'e.g. 98480 22338',
                      prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                      helperText: checked.value != null
                          ? 'Saved as ${formatPhone(checked.value)}'
                          : empty && _vm.phoneOptional
                          ? 'This customer has no phone number yet. Add it so they can be found at the counter.'
                          : null,
                      helperMaxLines: 2,
                      helperStyle: type.bodySmall!.copyWith(
                        color: checked.value != null ? colors.success : null,
                      ),
                    ),
                    validator: (v) => _vm.phoneOptional && empty
                        ? null
                        : normalisePhone(v).reason,
                  );
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  hintText: 'e.g. Priya Sharma',
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                ),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? "Enter the customer's name."
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'Optional',
                  prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
                ),
                validator: emailProblem,
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: tint(colors.danger, 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.danger),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 18,
                            color: colors.danger,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              error,
                              style: type.bodyMedium!.copyWith(
                                color: colors.danger,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (taken != null) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(
                            context,
                          ).pop((customer: taken, existing: true)),
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                          ),
                          iconAlignment: IconAlignment.end,
                          label: Text('Open ${taken.name}'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _vm.busy ? null : _save,
                      child: _vm.busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(editing ? 'Save changes' : 'Add customer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
