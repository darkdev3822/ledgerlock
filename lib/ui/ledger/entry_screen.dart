// Add / edit an income or expense (SPEC §5 fast entry: keypad-first amount,
// smart category default, today's date; details are optional).
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/app_controller.dart';
import '../../data/database.dart';
import '../../data/tax_rules.dart';
import '../design/components.dart';
import '../design/theme.dart';
import '../vault/capture_screen.dart';
import '../vault/vault_screens.dart';
import 'category_icons.dart';

/// Opens the entry screen. Pass [existing] to edit.
Future<void> openEntry(BuildContext context, {LedgerEntry? existing, bool income = false}) => Navigator.of(context)
    .push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => EntryScreen(existing: existing, startIncome: income),
      ),
    );

class EntryScreen extends ConsumerStatefulWidget {
  final LedgerEntry? existing;
  final bool startIncome;
  const EntryScreen({super.key, this.existing, this.startIncome = false});
  @override
  ConsumerState<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends ConsumerState<EntryScreen> {
  late bool _income = widget.existing?.isIncome ?? widget.startIncome;

  /// Income only: false = invoiced, not received yet (not counted until paid).
  late bool _paid = widget.existing?.paid ?? true;
  late int _cents = widget.existing?.amountCents ?? 0;
  late String? _category = widget.existing?.category;
  late DateTime _date = widget.existing?.day ?? _defaultDate();
  late double _businessPct = (widget.existing?.businessPct ?? 100).toDouble();
  late final _party = TextEditingController(text: widget.existing?.party ?? '');
  late final _platform = TextEditingController(text: widget.existing?.platform ?? '');
  late final _fee = TextEditingController(
    text: (widget.existing?.feeCents ?? 0) == 0 ? '' : (widget.existing!.feeCents / 100).toStringAsFixed(2),
  );
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');
  final _focus = FocusScopeNode();
  bool _textFocused = false;
  bool _userPickedCategory = false;
  bool _userSetPct = false;
  List<String> _recentParties = const [];
  List<String> _recentPlatforms = const [];

  /// Receipts captured before a new entry is saved; linked on save.
  final List<int> _pendingReceipts = [];

  bool get _editing => widget.existing != null;

  DateTime _defaultDate() {
    final now = DateTime.now();
    final year = ref.read(appControllerProvider).selectedYear;
    return now.year == year ? now : DateTime(year, 12, 31);
  }

  @override
  void initState() {
    super.initState();
    _userPickedCategory = _editing;
    _focus.addListener(() => setState(() => _textFocused = _focus.hasFocus));
    _party.addListener(_maybeSuggest);
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    final db = ref.read(appControllerProvider).db;
    if (db == null) return;
    _recentParties = await db.recentValues(db.ledgerEntries.party);
    _recentPlatforms = await db.recentValues(db.ledgerEntries.platform);
    await _maybeSuggest();
  }

  Future<void> _maybeSuggest() async {
    if (_userPickedCategory) return;
    final db = ref.read(appControllerProvider).db;
    if (db == null) return;
    final s = await db.suggestCategory(isIncome: _income, party: _party.text);
    final rule = _income || _editing ? null : matchRule(await db.allRules(), isIncome: false, party: _party.text);
    if (!mounted || _userPickedCategory) return;
    setState(() {
      _category = s ?? _category;
      if (rule?.businessPct != null && !_userSetPct) _businessPct = rule!.businessPct!.toDouble();
    });
  }

  @override
  void dispose() {
    for (final c in [_party, _platform, _fee, _notes]) {
      c.dispose();
    }
    _focus.dispose();
    super.dispose();
  }

  void _key(String k) {
    HapticFeedback.selectionClick();
    setState(() {
      if (k == '⌫') {
        _cents ~/= 10;
      } else if (_cents < 100000000) {
        _cents = _cents * 10 + int.parse(k);
      }
    });
  }

  int get _feeCents => ((double.tryParse(_fee.text.replaceAll(',', '')) ?? 0) * 100).round();

  Future<void> _save(TaxRules rules) async {
    final db = ref.read(appControllerProvider).db!;
    final category = _category!;
    final pct = _income ? 100 : _businessPct.round();
    final fee = _income ? _feeCents.clamp(0, _cents) : 0;
    if (_editing) {
      await db.saveEntry(
        widget.existing!.copyWith(
          isIncome: _income,
          date: isoDay(_date),
          amountCents: _cents,
          feeCents: fee,
          businessPct: pct,
          category: category,
          party: _party.text.trim(),
          platform: _platform.text.trim(),
          notes: _notes.text.trim(),
          paid: !_income || _paid,
        ),
      );
    } else {
      final newId = await db.addEntry(
        LedgerEntriesCompanion.insert(
          isIncome: _income,
          date: isoDay(_date),
          amountCents: _cents,
          feeCents: Value(fee),
          businessPct: Value(pct),
          category: category,
          party: Value(_party.text.trim()),
          platform: Value(_platform.text.trim()),
          notes: Value(_notes.text.trim()),
          paid: Value(!_income || _paid),
        ),
      );
      for (final r in _pendingReceipts) {
        await db.linkAttachment(r, newId);
      }
    }
    await db.learnFromSave(isIncome: _income, party: _party.text, category: category);
    HapticFeedback.mediumImpact();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final db = ref.read(appControllerProvider).db!;
    final e = widget.existing!;
    await db.deleteEntry(e.id);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Record deleted'),
        action: SnackBarAction(label: 'Undo', onPressed: () => db.restoreEntry(e)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final year = ref.watch(appControllerProvider.select((a) => a.selectedYear));
    final rules = ref.watch(taxRulesProvider(_date.year)).value ?? ref.watch(taxRulesProvider(year)).value;
    final ll = context.ll;
    if (rules == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final cats = rules.categories(_income);
    if (_category != null && !cats.any((c) => c.id == _category)) _category = null;
    final selected = _category == null ? null : rules.category(_category!);
    final amountColor = _cents == 0 ? ll.muted : (_income ? ll.income : ll.text);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
        title: Text(_editing ? 'Edit record' : (_income ? 'New income' : 'New expense')),
        actions: [
          if (_editing)
            IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline_rounded), onPressed: _delete),
          const SizedBox(width: Space.sm),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FocusScope(
              node: _focus,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                children: [
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: false, label: Text('Expense'), icon: Icon(Icons.north_east_rounded)),
                      ButtonSegment(value: true, label: Text('Income'), icon: Icon(Icons.south_west_rounded)),
                    ],
                    selected: {_income},
                    onSelectionChanged: (s) {
                      setState(() {
                        _income = s.first;
                        _category = null;
                        _userPickedCategory = false;
                      });
                      _maybeSuggest();
                    },
                  ),
                  const SizedBox(height: Space.xl),
                  GestureDetector(
                    onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                    child: Column(
                      children: [
                        Text(_income ? 'Gross amount' : 'Amount', style: context.text.labelMedium),
                        const SizedBox(height: 4),
                        Semantics(
                          label: 'Amount ${formatCents(_cents)}',
                          child: Text(
                            formatCents(_cents),
                            style: context.text.displayMedium?.copyWith(
                              fontFamily: Fonts.ui,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1,
                              color: amountColor,
                              fontFeatures: tabular,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.lg),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: cats.length,
                      separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
                      itemBuilder: (_, i) {
                        final c = cats[i];
                        return ChoiceChip(
                          avatar: Icon(categoryIcon(c.id), size: 18),
                          label: Text(c.name),
                          selected: c.id == _category,
                          showCheckmark: false,
                          onSelected: (_) => setState(() {
                            _category = c.id;
                            _userPickedCategory = true;
                          }),
                        );
                      },
                    ),
                  ),
                  if (selected != null)
                    Padding(
                      padding: const EdgeInsets.only(top: Space.sm, left: 4),
                      child: Text('Schedule C line ${selected.line} · ${selected.hint}', style: context.text.bodySmall),
                    ),
                  const SectionHeader('Details'),
                  LLGroup(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.event_outlined),
                        title: const Text('Date'),
                        trailing: Text(DateFormat.yMMMd().format(_date), style: context.text.titleSmall),
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _date,
                            firstDate: DateTime(TaxRules.supportedYears.last),
                            lastDate: DateTime(TaxRules.supportedYears.first, 12, 31),
                          );
                          if (d != null) setState(() => _date = d);
                        },
                      ),
                      _AutoField(
                        controller: _party,
                        icon: Icons.person_outline_rounded,
                        label: _income ? 'Paid by' : 'Paid to',
                        options: _recentParties,
                      ),
                      if (_income) ...[
                        _AutoField(
                          controller: _platform,
                          icon: Icons.storefront_outlined,
                          label: 'Platform or account',
                          options: {
                            ..._recentPlatforms,
                            'Fiverr',
                            'Etsy',
                            'itch.io',
                            'Uber',
                            'PayPal',
                            'Bank',
                            'Cash',
                          }.toList(),
                        ),
                        _Field(
                          controller: _fee,
                          icon: Icons.percent_rounded,
                          label: 'Platform fee (deductible)',
                          keyboard: const TextInputType.numberWithOptions(decimal: true),
                          prefix: r'$ ',
                        ),
                      ] else
                        Padding(
                          padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.sm),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.work_outline_rounded, color: ll.muted),
                                  const SizedBox(width: Space.lg),
                                  const Expanded(child: Text('Business use')),
                                  Text('${_businessPct.round()}%', style: context.text.titleSmall),
                                ],
                              ),
                              Slider(
                                value: _businessPct,
                                max: 100,
                                divisions: 20,
                                label: '${_businessPct.round()}%',
                                onChanged: (v) => setState(() {
                                  _businessPct = v;
                                  _userSetPct = true;
                                }),
                              ),
                            ],
                          ),
                        ),
                      _Field(controller: _notes, icon: Icons.notes_rounded, label: 'Notes'),
                      _ReceiptRow(
                        entryId: widget.existing?.id,
                        pending: _pendingReceipts,
                        onAdd: () async {
                          final id = await captureReceipt(context, year: _date.year);
                          if (id == null) return;
                          final db = ref.read(appControllerProvider).db!;
                          if (_editing) {
                            await db.linkAttachment(id, widget.existing!.id);
                          } else {
                            setState(() => _pendingReceipts.add(id));
                          }
                        },
                      ),
                    ],
                  ),
                  if (_income) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, Space.sm, 4, 0),
                      child: Text(
                        'Gross is what the buyer paid; the fee is what the platform kept. 1099-K forms report gross.',
                        style: context.text.bodySmall,
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      title: const Text('Received'),
                      subtitle: Text(
                        _paid
                            ? 'Counted in your totals.'
                            : 'Invoiced, not paid yet: not counted until you mark it received.',
                      ),
                      value: _paid,
                      onChanged: (v) => setState(() => _paid = v),
                    ),
                  ],
                  const SizedBox(height: Space.xl),
                ],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: ll.surface,
              border: Border(top: BorderSide(color: ll.border)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_textFocused) _Keypad(onKey: _key),
                    const SizedBox(height: Space.sm),
                    FilledButton(
                      onPressed: _cents > 0 && _category != null ? () => _save(rules) : null,
                      child: Text(_editing ? 'Save changes' : 'Save ${_income ? 'income' : 'expense'}'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  final ValueChanged<String> onKey;
  const _Keypad({required this.onKey});

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '00', '0', '⌫'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.6,
      children: [
        for (final k in keys)
          InkWell(
            borderRadius: BorderRadius.circular(Radii.input),
            onTap: () {
              onKey(k == '00' ? '0' : k);
              if (k == '00') onKey('0');
            },
            child: Center(
              child: k == '⌫'
                  ? Icon(Icons.backspace_outlined, semanticLabel: 'Delete digit', color: context.ll.muted)
                  : Text(
                      k,
                      style: context.text.headlineSmall?.copyWith(
                        fontFamily: Fonts.ui,
                        fontWeight: FontWeight.w600,
                        fontFeatures: tabular,
                      ),
                    ),
            ),
          ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final IconData icon;
  final String label;
  final TextInputType? keyboard;
  final String? prefix;
  const _Field({required this.controller, required this.icon, required this.label, this.keyboard, this.prefix});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Space.lg, 2, Space.lg, 2),
    child: Row(
      children: [
        Icon(icon, color: context.ll.muted),
        const SizedBox(width: Space.lg),
        Expanded(
          child: TextField(
            enableIMEPersonalizedLearning: false,
            controller: controller,
            keyboardType: keyboard,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: label,
              prefixText: prefix,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
      ],
    ),
  );
}

class _AutoField extends StatefulWidget {
  final TextEditingController controller;
  final IconData icon;
  final String label;
  final List<String> options;
  const _AutoField({required this.controller, required this.icon, required this.label, required this.options});
  @override
  State<_AutoField> createState() => _AutoFieldState();
}

class _AutoFieldState extends State<_AutoField> {
  final _node = FocusNode();

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Space.lg, 2, Space.lg, 2),
    child: Row(
      children: [
        Icon(widget.icon, color: context.ll.muted),
        const SizedBox(width: Space.lg),
        Expanded(
          child: RawAutocomplete<String>(
            textEditingController: widget.controller,
            focusNode: _node,
            optionsBuilder: (v) {
              final q = v.text.trim().toLowerCase();
              if (q.isEmpty) return const [];
              return widget.options.where((o) => o.toLowerCase().startsWith(q) && o.toLowerCase() != q).take(5);
            },
            fieldViewBuilder: (context, c, focus, onSubmit) => TextField(
              enableIMEPersonalizedLearning: false,
              controller: c,
              focusNode: focus,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: widget.label,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
            optionsViewBuilder: (context, onSelected, opts) => Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(Radii.input),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220, maxWidth: 280),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    children: [for (final o in opts) ListTile(title: Text(o), onTap: () => onSelected(o))],
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

class _ReceiptRow extends ConsumerWidget {
  final int? entryId;
  final List<int> pending;
  final VoidCallback onAdd;
  const _ReceiptRow({required this.entryId, required this.pending, required this.onAdd});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linked = entryId == null
        ? const <Attachment>[]
        : ref.watch(entryAttachmentsProvider(entryId!)).value ?? const [];
    final count = linked.length + pending.length;
    return ListTile(
      leading: const Icon(Icons.receipt_long_outlined),
      title: Text(count == 0 ? 'Receipt' : '$count ${count == 1 ? 'receipt' : 'receipts'} attached'),
      subtitle: count == 0 ? const Text('Scan or import; stored encrypted') : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final a in linked.take(3))
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ViewerScreen(a))),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(width: 36, height: 44, child: EncryptedThumb(a, size: 44)),
                ),
              ),
            ),
          IconButton(tooltip: 'Add receipt', icon: const Icon(Icons.add_a_photo_outlined), onPressed: onAdd),
        ],
      ),
    );
  }
}
