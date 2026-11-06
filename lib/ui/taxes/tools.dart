// Taxes tab tools (M6): payment log, mileage log, home office, 1099 tracker. All data in the encrypted DB.
import 'package:drift/drift.dart' show Value;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/app_controller.dart';
import '../../data/csv_export.dart';
import '../../data/database.dart';
import '../../data/ledger.dart';
import '../../data/tax_packet.dart';
import '../../data/tax_rules.dart';
import '../../platform/save_file.dart';
import '../design/components.dart';
import '../design/theme.dart';

const _pad = EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxl);

/// Dollars typed by the user ("12", "12.5", "1,200.00") -> cents, or null.
int? parseCents(String s) {
  final m = RegExp(r'^\$?(\d{1,9})(?:\.(\d{1,2}))?$').firstMatch(s.trim().replaceAll(',', ''));
  if (m == null) return null;
  return int.parse(m[1]!) * 100 + int.parse((m[2] ?? '0').padRight(2, '0'));
}

/// Miles typed ("12", "12.4") -> tenths, or null.
int? parseMilesTenths(String s) {
  final m = RegExp(r'^(\d{1,5})(?:\.(\d))?$').firstMatch(s.trim());
  if (m == null) return null;
  return int.parse(m[1]!) * 10 + int.parse(m[2] ?? '0');
}

final _money = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,$]')), LengthLimitingTextInputFormatter(13)];

InputDecoration _dec(String label, {String? helper, String? prefix}) =>
    InputDecoration(labelText: label, helperText: helper, prefixText: prefix, helperMaxLines: 2);

TextField _field(TextEditingController c, String label, {bool money = false, bool number = false, String? helper}) =>
    TextField(
      controller: c,
      enableIMEPersonalizedLearning: false,
      keyboardType: money || number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      inputFormatters: money ? _money : [LengthLimitingTextInputFormatter(number ? 8 : 80)],
      decoration: _dec(label, helper: helper, prefix: money ? '\$' : null),
    );

/// Dates stay inside the tax year (a trip dated in another year vanished from the screen: UI review). Payments may
/// fall in January of the next year (Q4 is due mid-January).
Future<DateTime?> _pickDate(BuildContext context, DateTime initial, int year, {bool intoNextYear = false}) =>
    showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(year),
      lastDate: intoNextYear ? DateTime(year + 1, 1, 31) : DateTime(year, 12, 31),
    );

/// A simple form sheet: fields + Save. Returns true if saved.
Future<bool> _sheet(BuildContext context, String title, List<Widget> fields, Future<bool> Function() save) async {
  var saving = false;
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => Padding(
      padding: EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, MediaQuery.of(c).viewInsets.bottom + Space.lg),
      child: StatefulBuilder(
        builder: (c, set) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: c.text.titleMedium),
            const SizedBox(height: Space.sm),
            ...fields,
            const SizedBox(height: Space.lg),
            FilledButton(
              // One save at a time: a double tap used to log the same payment twice (UI review U2b).
              onPressed: saving
                  ? null
                  : () async {
                      set(() => saving = true);
                      final ok = await save();
                      if (!c.mounted) return;
                      if (ok) {
                        Navigator.pop(c, true);
                      } else {
                        set(() => saving = false);
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    ),
  );
  // Callers dispose their TextEditingControllers when this returns: wait for the sheet's exit animation so the
  // fields are gone first (UI review U2: "used after being disposed").
  await Future<void>.delayed(const Duration(milliseconds: 350));
  return ok ?? false;
}

void _toast(BuildContext context, String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

/// Date row used inside sheets.
class _DateRow extends StatefulWidget {
  final DateTime initial;
  final int year;
  final ValueChanged<DateTime> onChanged;
  final bool intoNextYear;
  const _DateRow({required this.initial, required this.year, required this.onChanged, this.intoNextYear = false});
  @override
  State<_DateRow> createState() => _DateRowState();
}

class _DateRowState extends State<_DateRow> {
  late DateTime d = widget.initial;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.event_outlined),
    title: Text(DateFormat.yMMMd().format(d)),
    trailing: const Icon(Icons.edit_calendar_outlined),
    onTap: () async {
      final p = await _pickDate(context, d, widget.year, intoNextYear: widget.intoNextYear);
      if (p != null) {
        setState(() => d = p);
        widget.onChanged(p);
      }
    },
  );
}

Widget _deleteBg(BuildContext context) => Container(
  color: Theme.of(context).colorScheme.errorContainer,
  alignment: Alignment.centerRight,
  padding: const EdgeInsets.only(right: Space.lg),
  child: const Icon(Icons.delete_outline_rounded),
);

// ============================== Payment log ==============================

class PaymentLogScreen extends ConsumerWidget {
  final int year;
  const PaymentLogScreen(this.year, {super.key});

  Future<void> _add(BuildContext context, WidgetRef ref, TaxRules? rules) async {
    final db = ref.read(appControllerProvider).db;
    if (db == null) return;
    final today = ref.read(todayProvider);
    var date = today.year == year || today.year == year + 1 ? today : DateTime(year, 4, 15);
    var quarter = rules?.nextDue(today)?.quarter ?? '';
    final amount = TextEditingController(), method = TextEditingController();
    await _sheet(
      context,
      'Log a payment for $year',
      [
        _DateRow(initial: date, year: year, onChanged: (d) => date = d, intoNextYear: true),
        DropdownButtonFormField<String>(
          initialValue: quarter,
          decoration: _dec('Quarter'),
          items: [
            for (final q in ['Q1', 'Q2', 'Q3', 'Q4', ''])
              DropdownMenuItem(value: q, child: Text(q.isEmpty ? 'Other / with return' : q)),
          ],
          onChanged: (v) => quarter = v ?? '',
        ),
        _field(amount, 'Amount', money: true),
        _field(method, 'How you paid (optional)', helper: 'e.g. IRS Direct Pay, EFTPS, check'),
      ],
      () async {
        final c = parseCents(amount.text);
        if (c == null || c <= 0) {
          _toast(context, 'Enter an amount, like 450 or 450.00');
          return false;
        }
        await db.addPayment(
          TaxPaymentsCompanion.insert(
            taxYear: year,
            quarter: Value(quarter),
            date: isoDay(date),
            amountCents: c,
            method: Value(method.text.trim()),
          ),
        );
        if (!context.mounted) return true;
        showSuccess(
          ScaffoldMessenger.maybeOf(context),
          'Logged ${formatCents(c)}${quarter.isEmpty ? '' : ' for $quarter'}. It now counts toward your payments.',
        );
        return true;
      },
    );
    amount.dispose();
    method.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments = ref.watch(paymentsProvider(year)).value ?? const <TaxPayment>[];
    final rules = ref.watch(taxRulesProvider(year)).value;
    final s = ref.watch(summaryProvider(year));
    final paid = payments.fold(0, (a, p) => a + p.amountCents);
    final ll = context.ll;
    return Scaffold(
      appBar: AppBar(title: Text('Payment log · $year')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref, rules),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Log payment'),
      ),
      body: ListView(
        padding: _pad,
        children: [
          LLCard(
            child: Row(
              children: [
                Expanded(
                  child: StatTile(label: 'Paid to the IRS', cents: paid, icon: Icons.account_balance_outlined),
                ),
                Expanded(
                  child: StatTile(label: 'Set aside so far', cents: s.setAsideCents, icon: Icons.savings_outlined),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.sm),
          Text(
            'Estimated tax payments you’ve made for $year. Keep the confirmation numbers in your notes.',
            style: context.text.bodySmall,
          ),
          if (rules != null) ...[
            const SectionHeader('By quarter'),
            LLGroup(
              children: [
                for (final q in rules.quarterlyDue)
                  ListTile(
                    dense: true,
                    title: Text('${q.quarter} · due ${DateFormat.yMMMd().format(q.due)}'),
                    trailing: MoneyText(
                      payments.where((p) => p.quarter == q.quarter).fold(0, (a, p) => a + p.amountCents),
                      style: context.text.bodyMedium,
                    ),
                  ),
              ],
            ),
          ],
          const SectionHeader('Payments'),
          if (payments.isEmpty)
            const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No payments logged',
              body: 'Each time you pay estimated tax, log it here so you know where you stand.',
            )
          else
            LLGroup(
              children: [
                for (final p in payments.reversed)
                  Dismissible(
                    key: ValueKey('pay${p.id}'),
                    direction: DismissDirection.endToStart,
                    background: _deleteBg(context),
                    onDismissed: (_) async {
                      final db = ref.read(appControllerProvider).db;
                      if (db == null) return;
                      await db.deletePayment(p.id);
                      if (!context.mounted) return;
                      showUndo(
                        ScaffoldMessenger.of(context),
                        'Payment deleted',
                        () => db.addPayment(p.toCompanion(true)),
                      );
                    },
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: ll.surfaceAlt,
                        child: Text(p.quarter.isEmpty ? '·' : p.quarter, style: const TextStyle(fontSize: 12)),
                      ),
                      title: Text(DateFormat.yMMMd().format(DateTime.parse(p.date))),
                      subtitle: p.method.isEmpty ? null : Text(p.method),
                      trailing: MoneyText(p.amountCents, style: context.text.titleSmall),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

// ============================== Mileage ==============================

class MileageScreen extends ConsumerWidget {
  final int year;
  const MileageScreen(this.year, {super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final db = ref.read(appControllerProvider).db;
    if (db == null) return;
    final today = ref.read(todayProvider);
    var date = today.year == year ? today : DateTime(year, 1, 1);
    final miles = TextEditingController(), purpose = TextEditingController(), route = TextEditingController();
    await _sheet(
      context,
      'Add a business trip',
      [
        _DateRow(initial: date, year: year, onChanged: (d) => date = d),
        _field(miles, 'Miles', number: true),
        _field(purpose, 'Business purpose', helper: 'The IRS expects a purpose for each trip, e.g. "client meeting"'),
        _field(route, 'Route (optional)', helper: 'e.g. Home to Riverside office'),
      ],
      () async {
        final t = parseMilesTenths(miles.text);
        if (t == null || t <= 0) {
          _toast(context, 'Enter miles, like 12 or 12.4');
          return false;
        }
        if (purpose.text.trim().isEmpty) {
          _toast(context, 'Add the business purpose');
          return false;
        }
        await db.addTrip(
          TripsCompanion.insert(
            date: isoDay(date),
            milesTenths: t,
            purpose: Value(purpose.text.trim()),
            route: Value(route.text.trim()),
          ),
        );
        return true;
      },
    );
    for (final c in [miles, purpose, route]) {
      c.dispose();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(tripsProvider(year)).value ?? const <Trip>[];
    final rules = ref.watch(taxRulesProvider(year)).value;
    final rate = rules?.figure('mileage_rate');
    final tenths = trips.fold(0, (a, t) => a + t.milesTenths);
    final deduction = rules == null ? 0 : mileageDeductionCents(trips.map((t) => (t.date, t.milesTenths)), rules);
    return Scaffold(
      appBar: AppBar(title: Text('Mileage · $year')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add trip'),
      ),
      body: ListView(
        padding: _pad,
        children: [
          LLCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${(tenths / 10).toStringAsFixed(1)} business miles', style: context.text.titleMedium),
                const SizedBox(height: 4),
                if (rate == null)
                  Text(
                    'The $year mileage rate hasn’t been verified yet, so no deduction is counted.',
                    style: context.text.bodySmall,
                  )
                else ...[
                  MoneyText(deduction, style: context.text.headlineMedium),
                  Text(
                    'Standard mileage rate: ${rate.value}¢ a mile'
                    '${rate.changes.isEmpty ? '' : ', ${rate.changes.map((c) => '${c.$2}¢ from ${DateFormat.MMMd().format(c.$1)}').join(', ')}'}. '
                    'Counted on Schedule C line 9. Use either this or actual car costs, not both.',
                    style: context.text.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const SectionHeader('Trips'),
          if (trips.isEmpty)
            const EmptyState(
              icon: Icons.directions_car_outlined,
              title: 'No trips yet',
              body: 'Log business trips as you go: date, miles and purpose. Commuting doesn’t count.',
            )
          else
            LLGroup(
              children: [
                for (final t in trips)
                  Dismissible(
                    key: ValueKey('trip${t.id}'),
                    direction: DismissDirection.endToStart,
                    background: _deleteBg(context),
                    onDismissed: (_) => ref.read(appControllerProvider).db?.deleteTrip(t.id),
                    child: ListTile(
                      title: Text(t.purpose.isEmpty ? 'Trip' : t.purpose),
                      subtitle: Text(
                        [
                          DateFormat.yMMMd().format(DateTime.parse(t.date)),
                          if (t.route.isNotEmpty) t.route,
                        ].join(' · '),
                      ),
                      trailing: Text('${(t.milesTenths / 10).toStringAsFixed(1)} mi', style: context.text.titleSmall),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

// ============================== Home office ==============================

class HomeOfficeScreen extends ConsumerWidget {
  final int year;
  const HomeOfficeScreen(this.year, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider);
    final rules = ref.watch(taxRulesProvider(year)).value;
    final sqft = app.homeOfficeSqft[year] ?? 0;
    final cents = rules == null ? null : homeOfficeCents(sqft, rules);
    final s = ref.watch(summaryProvider(year));
    return Scaffold(
      appBar: AppBar(title: Text('Home office · $year')),
      body: ListView(
        padding: _pad,
        children: [
          LLCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Simplified method', style: context.text.titleMedium),
                const SizedBox(height: 4),
                if (cents == null)
                  Text(
                    'The $year simplified-method rate and area limit haven’t been verified yet, so this '
                    'calculator is off. They’re checked in the next tax-rules review.',
                    style: context.text.bodySmall,
                  )
                else ...[
                  MoneyText(s.lines['30']?.round() ?? 0, style: context.text.headlineMedium),
                  Text(
                    'Area × ${rules!.figure('home_office_rate')!.value} a sq ft, up to '
                    '${rules.figure('home_office_max_sqft')!.value} sq ft. Can’t create a loss. '
                    'Schedule C line 30.',
                    style: context.text.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: Space.md),
          LLGroup(
            children: [
              ListTile(
                leading: const Icon(Icons.square_foot_rounded),
                title: const Text('Office area'),
                trailing: Text(sqft == 0 ? 'Add' : '$sqft sq ft'),
                onTap: () async {
                  final c = TextEditingController(text: sqft == 0 ? '' : '$sqft');
                  await _sheet(
                    context,
                    'Office area for $year',
                    [
                      TextField(
                        controller: c,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
                        decoration: _dec('Square feet', helper: 'Only the part used regularly and only for business.'),
                      ),
                    ],
                    () async {
                      await app.setHomeOfficeSqft(year, int.tryParse(c.text) ?? 0);
                      return true;
                    },
                  );
                  c.dispose();
                },
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          Text(
            'The space must be used regularly and only for your business. The regular method (Form 8829) uses '
            'actual costs; ask a tax professional if it might be worth more for you.',
            style: context.text.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ============================== 1099 tracker ==============================

class Forms1099Screen extends ConsumerWidget {
  final int year;
  const Forms1099Screen(this.year, {super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final db = ref.read(appControllerProvider).db;
    if (db == null) return;
    var kind = '1099-K';
    final payer = TextEditingController(), amount = TextEditingController();
    await _sheet(
      context,
      'Add a 1099 for $year',
      [
        DropdownButtonFormField<String>(
          initialValue: kind,
          decoration: _dec('Form'),
          items: [
            for (final k in ['1099-K', '1099-NEC', '1099-MISC']) DropdownMenuItem(value: k, child: Text(k)),
          ],
          onChanged: (v) => kind = v ?? kind,
        ),
        _field(payer, 'From (platform or client)', helper: 'Use the same name as on your records, e.g. Etsy'),
        _field(amount, 'Amount on the form', money: true, helper: '1099-K: box 1a (gross, before fees)'),
      ],
      () async {
        final c = parseCents(amount.text);
        if (payer.text.trim().isEmpty || c == null) {
          _toast(context, 'Add who it’s from and the amount');
          return false;
        }
        await db.addForm1099(
          Forms1099Companion.insert(year: year, kind: kind, payer: payer.text.trim(), amountCents: c),
        );
        return true;
      },
    );
    payer.dispose();
    amount.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forms = ref.watch(forms1099Provider(year)).value ?? const <Form1099>[];
    final entries = ref.watch(entriesProvider(year)).value ?? const <LedgerEntry>[];
    final ll = context.ll;
    return Scaffold(
      appBar: AppBar(title: Text('1099 tracker · $year')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add 1099'),
      ),
      body: ListView(
        padding: _pad,
        children: [
          Text(
            'Enter each 1099 you receive. We compare it with the income you recorded from the same platform or '
            'client, so mismatches surface before you file.',
            style: context.text.bodySmall,
          ),
          const SectionHeader('Forms'),
          if (forms.isEmpty)
            const EmptyState(
              icon: Icons.description_outlined,
              title: 'No 1099s yet',
              body:
                  'They usually arrive by the end of January. Payment cards report every sale; apps and marketplaces '
                  'above a threshold.',
            )
          else
            LLGroup(
              children: [
                for (final f in forms)
                  Builder(
                    builder: (context) {
                      final rec = recordedFrom(f.payer, entries);
                      final diff = f.amountCents - rec;
                      final ok = diff.abs() <= 100;
                      return Dismissible(
                        key: ValueKey('f${f.id}'),
                        direction: DismissDirection.endToStart,
                        background: _deleteBg(context),
                        onDismissed: (_) => ref.read(appControllerProvider).db?.deleteForm1099(f.id),
                        child: ListTile(
                          leading: Icon(
                            ok ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                            color: ok ? ll.accent : Theme.of(context).colorScheme.error,
                          ),
                          title: Text('${f.payer} · ${f.kind}'),
                          subtitle: Text(
                            ok
                                ? 'Matches your records (${formatCents(rec)}).'
                                : 'Form ${formatCents(f.amountCents)}, your records ${formatCents(rec)}: '
                                      '${diff > 0 ? (f.kind == '1099-K' ? 'the form is higher. Missing income? (A 1099-K\'s gross also includes fees and refunds.)' : 'the form is higher. Is some income missing from your records?') : 'your records are higher. Some payments may not have been reported, which is fine: report all income.'}',
                          ),
                          isThreeLine: !ok,
                          trailing: MoneyText(f.amountCents, style: context.text.titleSmall),
                        ),
                      );
                    },
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

// ============================== CSV export ==============================

Future<void> showExportSheet(BuildContext context, WidgetRef ref, int year) async {
  final db = ref.read(appControllerProvider).db;
  final rules = ref.read(taxRulesProvider(year)).value;
  if (db == null || rules == null) return;
  Future<void> export(String name, Future<String> Function() build) async {
    try {
      final ok = await saveWithPicker(name, Uint8List.fromList(csvBytes(await build())));
      if (ok && context.mounted) _toast(context, 'Saved $name');
    } on PlatformException {
      if (context.mounted) _toast(context, 'Couldn’t save the file.');
    } on MissingPluginException {
      if (context.mounted) _toast(context, 'Export isn’t available here yet.');
    }
  }

  Future<void> packet({required bool withReceipts}) async {
    final app = ref.read(appControllerProvider);
    try {
      if (withReceipts && context.mounted) _toast(context, 'Building the packet with receipts…');
      final trips = await db.watchTrips(year).first;
      final entries = await db.watchYear(year).first;
      final sqft = app.homeOfficeSqft[year] ?? 0;
      final receipts = <PacketReceipt>[];
      final docs = app.documents;
      if (withReceipts && docs != null) {
        final byId = {for (final e in entries) e.id: e};
        for (final a in await db.watchAttachments(year, folder: 'receipt').first) {
          final e = a.entryId == null ? null : byId[a.entryId];
          final caption = e == null
              ? 'Not matched to a record'
              : '${DateFormat.yMMMd().format(e.day)} · '
                    '${e.party.isNotEmpty ? e.party : (rules.category(e.category)?.name ?? e.category)} · '
                    '${formatCents(e.amountCents)}';
          Uint8List? image;
          if (a.mime.startsWith('image/') && receipts.where((r) => r.image != null).length < maxPacketReceiptPages) {
            try {
              image = await docs.read(a); // decrypted in memory only, for this file
            } catch (_) {}
          }
          receipts.add(
            PacketReceipt(name: a.name.isEmpty ? 'Receipt ${a.id}' : a.name, caption: caption, image: image),
          );
        }
      }
      final bytes = await buildTaxPacket(
        PacketInput(
          year: year,
          rules: rules,
          summary: ref.read(summaryProvider(year)),
          entries: entries,
          trips: trips,
          payments: await db.watchPayments(year).first,
          forms: await db.watchForms1099(year).first,
          mileageCents: mileageDeductionCents(trips.map((t) => (t.date, t.milesTenths)), rules),
          homeOfficeCents: homeOfficeCents(sqft, rules) ?? 0,
          generated: DateTime.now(),
          receipts: receipts,
        ),
      );
      final name = 'ledgerlock-$year-tax-packet${withReceipts ? '-with-receipts' : ''}.pdf';
      final ok = await saveWithPicker(name, bytes, mime: 'application/pdf');
      if (ok && context.mounted) _toast(context, 'Saved $name');
    } on PlatformException {
      if (context.mounted) _toast(context, 'Couldn’t save the file.');
    } on MissingPluginException {
      if (context.mounted) _toast(context, 'Export isn’t available here yet.');
    }
  }

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Text(
              'Exported files are NOT encrypted. Anyone with the file can read it. Save it somewhere you trust '
              'and delete it when you’re done.',
              style: c.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: Space.sm),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: Text('Tax packet for a preparer ($year)'),
            subtitle: const Text('PDF summary: Schedule C lines, categories, 1099s, payments, mileage'),
            trailing: const Icon(Icons.download_rounded),
            onTap: () {
              Navigator.pop(c);
              packet(withReceipts: false);
            },
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: Text('Tax packet with receipts ($year)'),
            subtitle: const Text('The same PDF plus a page for each receipt photo. A bigger file.'),
            trailing: const Icon(Icons.download_rounded),
            onTap: () {
              Navigator.pop(c);
              packet(withReceipts: true);
            },
          ),
          for (final (icon, label, name, build) in <(IconData, String, String, Future<String> Function())>[
            (
              Icons.list_alt_rounded,
              'Records',
              'ledgerlock-$year-records.csv',
              () async => entriesCsv(await db.watchYear(year).first, rules),
            ),
            (
              Icons.directions_car_outlined,
              'Mileage log',
              'ledgerlock-$year-mileage.csv',
              () async => tripsCsv(await db.watchTrips(year).first),
            ),
            (
              Icons.payments_outlined,
              'Tax payments',
              'ledgerlock-$year-payments.csv',
              () async => paymentsCsv(await db.watchPayments(year).first),
            ),
          ])
            ListTile(
              leading: Icon(icon),
              title: Text('$label ($year)'),
              trailing: const Icon(Icons.download_rounded),
              onTap: () {
                Navigator.pop(c);
                export(name, build);
              },
            ),
        ],
      ),
    ),
  );
}

// ============================== Smart rules (M7) ==============================

class RulesScreen extends ConsumerWidget {
  const RulesScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref, TaxRules rules) async {
    final db = ref.read(appControllerProvider).db;
    if (db == null) return;
    final cats = [...rules.expenseCategories, ...rules.incomeCategories];
    String? cat;
    final text = TextEditingController(), pct = TextEditingController();
    await _sheet(
      context,
      'New rule',
      [
        _field(text, 'Payee contains', helper: 'e.g. "anthropic" matches "Anthropic PBC" and "ANTHROPIC.COM"'),
        DropdownButtonFormField<String>(
          isExpanded: true,
          decoration: _dec('Category'),
          items: [
            for (final c in cats)
              DropdownMenuItem(value: c.id, child: Text('${c.isIncome ? 'Income' : 'Expense'} · ${c.name}')),
          ],
          onChanged: (v) => cat = v,
        ),
        _field(pct, 'Business use % (expenses, optional)', number: true, helper: 'Leave empty to keep 100%'),
      ],
      () async {
        final t = text.text.trim().toLowerCase();
        final c = cats.where((x) => x.id == cat).firstOrNull;
        final p = int.tryParse(pct.text.trim());
        if (t.length < 2 || c == null || (p != null && (p < 0 || p > 100))) {
          _toast(context, 'Add at least 2 letters, a category, and a % from 0 to 100');
          return false;
        }
        await db.addRule(
          CategoryRulesCompanion.insert(
            isIncome: c.isIncome,
            contains: t,
            category: c.id,
            businessPct: Value(c.isIncome ? null : p),
          ),
        );
        return true;
      },
    );
    text.dispose();
    pct.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(appControllerProvider.select((a) => a.selectedYear));
    final rules = ref.watch(taxRulesProvider(year)).value;
    final list = ref.watch(categoryRulesProvider).value ?? const <CategoryRule>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Smart rules')),
      floatingActionButton: rules == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _add(context, ref, rules),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add rule'),
            ),
      body: ListView(
        padding: _pad,
        children: [
          Text(
            'Rules pick the category when you type a payee, and when you import a file. When you change a '
            'suggested category, LedgerLock learns it for that payee. Swipe a rule away to delete it.',
            style: context.text.bodySmall,
          ),
          const SectionHeader('Rules'),
          if (list.isEmpty)
            const EmptyState(
              icon: Icons.auto_fix_high_outlined,
              title: 'No rules yet',
              body: 'Add one, or just correct a suggested category and it will appear here.',
            )
          else
            LLGroup(
              children: [
                for (final r in list)
                  Dismissible(
                    key: ValueKey('r${r.id}'),
                    direction: DismissDirection.endToStart,
                    background: _deleteBg(context),
                    onDismissed: (_) => ref.read(appControllerProvider).db?.deleteRule(r.id),
                    child: ListTile(
                      leading: Icon(r.learned ? Icons.school_outlined : Icons.rule_rounded),
                      title: Text('"${r.contains}"'),
                      subtitle: Text(
                        '${r.isIncome ? 'Income' : 'Expense'} · ${rules?.category(r.category)?.name ?? r.category}'
                        '${r.businessPct == null ? '' : ' · ${r.businessPct}% business'}'
                        '${r.learned ? ' · learned' : ''}',
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
