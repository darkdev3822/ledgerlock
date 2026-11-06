// Add / edit an income or expense (SPEC §5 fast entry: keypad-first amount,
// smart category default, today's date; details are optional).
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/app_controller.dart';
import '../../data/business_types.dart';
import '../../data/database.dart';
import '../../data/recurring.dart';
import '../../media/receipt_parser.dart';
import '../../platform/ocr.dart';
import '../../data/tax_rules.dart';
import '../design/components.dart';
import '../design/theme.dart';
import '../vault/capture_screen.dart';
import '../vault/vault_screens.dart';
import 'category_icons.dart';

/// Opens the entry screen. Pass [existing] to edit.
Future<void> openEntry(BuildContext context, {LedgerEntry? existing, bool income = false, int? receiptId}) =>
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => EntryScreen(existing: existing, startIncome: income, receiptId: receiptId),
      ),
    );

class EntryScreen extends ConsumerStatefulWidget {
  final LedgerEntry? existing;
  final bool startIncome;

  /// A just-scanned receipt: attached on save, and read on the device (OCR) to pre-fill the form.
  final int? receiptId;
  const EntryScreen({super.key, this.existing, this.startIncome = false, this.receiptId});
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

  /// New records: 'never' or a recurringEvery value. Existing records: the repeat that made them, if still on.
  String _repeat = 'never';
  Recurring? _rule;
  List<String> _recentParties = const [];
  List<String> _recentPlatforms = const [];

  /// Receipts captured before a new entry is saved; linked on save.
  final List<int> _pendingReceipts = [];

  /// Receipt reading: null = not started, true = reading, false = done. [_ocrFilled]: what was filled.
  bool? _reading;
  String? _ocrFilled;

  /// Reads [attachmentId] on the device and fills only fields the user hasn't touched.
  Future<void> _readReceipt(int attachmentId) async {
    final app = ref.read(appControllerProvider);
    final docs = app.documents, db = app.db;
    if (docs == null || db == null) return;
    setState(() => _reading = true);
    String? text;
    try {
      final a = await db.attachment(attachmentId);
      if (a != null && a.mime.startsWith('image/')) text = await recognizeText(await docs.read(a));
    } catch (_) {}
    if (!mounted) return;
    final g = text == null ? null : parseReceipt(text, today: ref.read(todayProvider));
    final filled = <String>[];
    setState(() {
      _reading = false;
      if (g == null || g.isEmpty) return;
      if (g.totalCents != null && _cents == 0) {
        _cents = g.totalCents!.clamp(0, 99999999);
        filled.add('amount');
      }
      if (g.merchant != null && _party.text.trim().isEmpty) {
        _party.text = g.merchant!;
        filled.add('payee');
      }
      if (g.date != null && g.date!.year == _date.year) {
        _date = g.date!;
        filled.add('date');
      }
    });
    if (filled.isNotEmpty) {
      HapticFeedback.lightImpact();
      setState(() => _ocrFilled = filled.join(', '));
    }
  }

  bool get _editing => widget.existing != null;

  DateTime _defaultDate() {
    final now = ref.read(todayProvider);
    final year = ref.read(appControllerProvider).selectedYear;
    return now.year == year ? now : DateTime(year, 12, 31);
  }

  @override
  void initState() {
    super.initState();
    _userPickedCategory = _editing;
    FocusManager.instance.addListener(_onFocusChange);
    _party.addListener(_maybeSuggest);
    _loadSuggestions();
    _loadRule();
    if (widget.receiptId != null) {
      _pendingReceipts.add(widget.receiptId!);
      WidgetsBinding.instance.addPostFrameCallback((_) => _readReceipt(widget.receiptId!));
    }
  }

  Future<void> _loadRule() async {
    final id = widget.existing?.recurringId;
    final db = ref.read(appControllerProvider).db;
    if (id == null || db == null) return;
    final r = await db.recurring(id);
    if (mounted) setState(() => _rule = r);
  }

  Future<void> _pickRepeat() async {
    final v = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final e in ['never', ...recurringEvery])
              ListTile(
                title: Text(everyLabel(e)),
                trailing: e == _repeat ? Icon(Icons.check_rounded, color: c.ll.accent) : null,
                onTap: () => Navigator.pop(c, e),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.lg),
              child: Text(
                'LedgerLock adds a copy on each date when you open the app, including dates you missed. '
                'Stop it any time in Settings > Repeating records; copies already made stay.',
                style: c.text.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
    if (v != null && mounted) setState(() => _repeat = v);
  }

  Future<void> _stopRepeat() async {
    final r = _rule;
    final db = ref.read(appControllerProvider).db;
    if (r == null || db == null) return;
    await db.stopRecurring(r.id);
    if (!mounted) return;
    setState(() => _rule = null);
    showSuccess(ScaffoldMessenger.maybeOf(context), 'Stopped. Records already made stay.');
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
    FocusManager.instance.removeListener(_onFocusChange);
    _focus.dispose();
    super.dispose();
  }

  /// The keypad hides only while a TEXT field has focus. Watching _focus.hasFocus alone kept it hidden for good:
  /// unfocusing a field moves focus to the enclosing scope, which still "has focus" (tester report U10).
  void _onFocusChange() {
    final p = FocusManager.instance.primaryFocus;
    final text =
        _focus.hasFocus && p != null && p != _focus && p.context?.findAncestorWidgetOfExactType<EditableText>() != null;
    if (mounted && text != _textFocused) setState(() => _textFocused = text);
  }

  /// Android Back closes the soft keyboard but leaves the field focused: drop focus too, so the keypad returns.
  double _lastInset = 0;
  void _watchKeyboard(double inset) {
    if (_lastInset > 0 && inset == 0 && _textFocused) {
      WidgetsBinding.instance.addPostFrameCallback((_) => FocusManager.instance.primaryFocus?.unfocus());
    }
    _lastInset = inset;
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

  bool _saving = false;
  int _caughtUp = 0;

  Future<void> _save(TaxRules rules) async {
    // A double tap used to insert twice and pop twice, closing the main screen too (UI review U1).
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _saveOnce(rules);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveOnce(TaxRules rules) async {
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
      int? ruleId;
      if (_repeat != 'never') {
        ruleId = await db.addRecurring(
          RecurringsCompanion.insert(
            isIncome: _income,
            amountCents: _cents,
            feeCents: Value(fee),
            businessPct: Value(pct),
            category: category,
            party: Value(_party.text.trim()),
            platform: Value(_platform.text.trim()),
            notes: Value(_notes.text.trim()),
            every: _repeat,
            anchorDay: _date.day,
            nextDate: isoDay(stepDate(_date, _repeat, _date.day)),
          ),
        );
      }
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
          recurringId: Value(ruleId),
        ),
      );
      // A backdated repeat ("Netflix since January") fills in the dates already passed.
      if (ruleId != null) _caughtUp = await db.runRecurring(ref.read(todayProvider));
      for (final r in _pendingReceipts) {
        await db.linkAttachment(r, newId);
      }
    }
    await db.learnFromSave(isIncome: _income, party: _party.text, category: category);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.of(context).pop();
    showSuccess(
      messenger,
      _editing
          ? 'Changes saved.'
          : _repeat != 'never'
          ? 'Saved. Repeats ${everyLabel(_repeat).toLowerCase()}'
                '${_caughtUp > 0 ? '; added $_caughtUp more for dates already passed' : ''}.'
          : _income && !_paid
          ? 'Saved as unpaid. Mark it received when the money lands.'
          : _date.year == ref.read(appControllerProvider).selectedYear
          ? 'Saved to ${DateFormat.MMMM().format(_date)}.'
          : 'Saved to ${DateFormat.yMMMM().format(_date)}. Switch the year to see it.',
    );
  }

  Future<void> _delete() async {
    final db = ref.read(appControllerProvider).db!;
    final e = widget.existing!;
    final linked = await db.deleteEntry(e.id);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    showUndo(messenger, 'Record deleted', () => db.restoreEntry(e, attachmentIds: linked));
  }

  @override
  Widget build(BuildContext context) {
    final year = ref.watch(appControllerProvider.select((a) => a.selectedYear));
    final rules = ref.watch(taxRulesProvider(_date.year)).value ?? ref.watch(taxRulesProvider(year)).value;
    final ll = context.ll;
    if (rules == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final cats = orderCategories(
      rules.categories(_income),
      ref.watch(appControllerProvider.select((a) => a.businessTypes)),
    );
    if (_category != null && !cats.any((c) => c.id == _category)) _category = null;
    final selected = _category == null ? null : rules.category(_category!);
    final amountColor = _cents == 0 ? ll.muted : (_income ? ll.income : ll.text);
    _watchKeyboard(MediaQuery.viewInsetsOf(context).bottom);
    final missing = _cents == 0
        ? 'Type an amount on the keypad.'
        : _category == null
        ? 'Pick a category above to save.'
        : null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
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
                        AnimatedSize(
                          duration: Motion.medium,
                          curve: Motion.enter,
                          child: _reading == null && _ocrFilled == null
                              ? const SizedBox(width: double.infinity)
                              : Padding(
                                  padding: const EdgeInsets.only(top: Space.sm),
                                  child: _ReceiptReadBanner(reading: _reading == true, filled: _ocrFilled),
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
                      if (!_editing)
                        ListTile(
                          leading: const Icon(Icons.repeat_rounded),
                          title: const Text('Repeats'),
                          trailing: Text(everyLabel(_repeat), style: context.text.titleSmall),
                          onTap: _pickRepeat,
                        )
                      else if (_rule != null)
                        ListTile(
                          leading: const Icon(Icons.repeat_rounded),
                          title: Text(everyLabel(_rule!.every)),
                          subtitle: Text(
                            'Next ${DateFormat.yMMMd().format(DateTime.parse(_rule!.nextDate))}. '
                            'Changes here affect this record only.',
                          ),
                          trailing: TextButton(onPressed: _stopRepeat, child: const Text('Stop')),
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
                            if (_cents == 0) _readReceipt(id);
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
          // A Material (not a coloured Container) so the keypad's ink ripples are painted where you can see them.
          Material(
            color: ll.surface,
            shape: Border(top: BorderSide(color: ll.border)),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.md),
                child: Center(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _maxBarWidth),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!_textFocused) _Keypad(onKey: _key),
                        if (missing != null && !_saving)
                          Padding(
                            padding: const EdgeInsets.only(top: Space.sm),
                            child: Text(missing, style: context.text.bodySmall, textAlign: TextAlign.center),
                          ),
                        const SizedBox(height: Space.sm),
                        FilledButton(
                          onPressed: _cents > 0 && _category != null && !_saving ? () => _save(rules) : null,
                          child: Text(_editing ? 'Save changes' : 'Save ${_income ? 'income' : 'expense'}'),
                        ),
                      ],
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

/// Keypad + Save stay phone-sized on tablets and unfolded foldables.
const _maxBarWidth = 480.0;

class _Keypad extends StatelessWidget {
  final ValueChanged<String> onKey;
  const _Keypad({required this.onKey});

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '00', '0', '⌫'];
    // Key height follows the screen HEIGHT, never the width: width-based keys filled a foldable's wide inner
    // screen and pushed the category chips out of view (tester report, U13). 48 dp minimum for touch (M8 a11y).
    final keyHeight = (MediaQuery.sizeOf(context).height * 0.07).clamp(48.0, 64.0);
    Widget key(String k) => Expanded(
      child: SizedBox(
        height: keyHeight,
        child: InkWell(
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
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < 4; r++) Row(children: [for (var c = 0; c < 3; c++) key(keys[r * 3 + c])]),
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

/// Status of on-device receipt reading. Always asks the user to check: OCR is a suggestion, not a fact.
class _ReceiptReadBanner extends StatelessWidget {
  final bool reading;
  final String? filled;
  const _ReceiptReadBanner({required this.reading, required this.filled});

  @override
  Widget build(BuildContext context) {
    final ll = context.ll;
    final text = reading
        ? 'Reading your receipt on this phone…'
        : filled == null
        ? 'Couldn’t read this receipt clearly. Enter the details yourself.'
        : 'Filled $filled from your receipt. Check before saving.';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
      decoration: BoxDecoration(
        color: (filled == null && !reading ? ll.surfaceAlt : ll.accentSoft),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (reading)
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: ll.accent))
          else
            Icon(filled == null ? Icons.info_outline_rounded : Icons.auto_awesome_rounded, size: 16, color: ll.accent),
          const SizedBox(width: Space.sm),
          Flexible(
            child: Text(text, style: context.text.labelMedium?.copyWith(color: ll.text)),
          ),
        ],
      ),
    );
  }
}
