import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/data/database.dart';
import 'package:ledgerlock/data/tax_rules.dart';
import 'package:ledgerlock/tax/checkin.dart';

var _id = 0;
LedgerEntry _e(
  String date, {
  bool income = false,
  String party = '',
  String platform = '',
  String cat = 'supplies',
  bool paid = true,
}) => LedgerEntry(
  id: ++_id,
  isIncome: income,
  date: date,
  amountCents: 1000,
  feeCents: 0,
  businessPct: 100,
  category: cat,
  party: party,
  platform: platform,
  notes: '',
  paid: paid,
  createdAt: DateTime(2026),
);

final _rules = TaxRules(
  year: 2026,
  quarterlyDue: [QuarterDue('Q3', '', DateTime(2026, 9, 15)), QuarterDue('Q4', '', DateTime(2027, 1, 15))],
);

List<CheckInQuestion> _ask(
  DateTime today,
  List<LedgerEntry> e, {
  Set<int> receipts = const {},
  List<TaxPayment> pay = const [],
  List<Form1099> forms = const [],
  Set<String> dismissed = const {},
}) => checkInQuestions(
  today: today,
  entries: e,
  entriesWithReceipt: receipts,
  payments: pay,
  formsLastYear: forms,
  rules: _rules,
  dismissed: dismissed,
);

void main() {
  test('nothing to ask -> empty (check-in is skipped)', () {
    final e = _e('2026-10-28');
    expect(_ask(DateTime(2026, 11, 1), [e], receipts: {e.id}), isEmpty);
  });

  test('quarterly due within 14 days and not logged', () {
    final q = _ask(DateTime(2026, 9, 5), const []);
    expect(q.single.action, CheckInAction.paymentLog);
    final paid = TaxPayment(
      id: 1,
      taxYear: 2026,
      quarter: 'Q3',
      date: '2026-09-01',
      amountCents: 1,
      method: '',
      notes: '',
    );
    expect(_ask(DateTime(2026, 9, 5), const [], pay: [paid]), isEmpty);
  });

  test('quiet for 3 weeks; recurring payee missing this month', () {
    final e = [
      for (final m in [7, 8, 9, 10]) _e('2026-${m.toString().padLeft(2, '0')}-03', party: 'Adobe'),
    ];
    final q = _ask(DateTime(2026, 11, 26), e, receipts: e.map((x) => x.id).toSet());
    expect(q.map((x) => x.action), containsAll([CheckInAction.addEntry]));
    expect(q.any((x) => x.text.contains('Adobe') && x.text.contains('November')), isTrue);
    expect(q.any((x) => x.text.startsWith('Nothing recorded since Oct 3')), isTrue);
  });

  test('unpaid invoices, missing receipts, Other, max 5, dismissed hidden', () {
    final e = [
      _e('2026-09-01', income: true, paid: false, cat: 'services'),
      _e('2026-10-30'),
      _e('2026-10-30', cat: 'other_expense'),
    ];
    final q = _ask(DateTime(2026, 11, 1), e);
    expect(q.map((x) => x.action), [CheckInAction.unpaid, CheckInAction.receipts, CheckInAction.categorize]);
    expect(q.first.query, 'unpaid');
    final again = _ask(DateTime(2026, 11, 1), e, dismissed: {q.first.key});
    expect(again.map((x) => x.action), isNot(contains(CheckInAction.unpaid)));
  });

  test('Jan-Mar: 1099s from platforms (not bank) not entered yet', () {
    final e = [
      _e('2025-06-01', income: true, platform: 'Etsy', cat: 'services'),
      _e('2025-07-01', income: true, platform: 'Bank', cat: 'services'),
      _e('2026-01-20'),
    ];
    final q = _ask(DateTime(2026, 2, 1), e, receipts: {e.last.id});
    expect(q.single.text, contains('from Etsy'));
    expect(q.single.text, isNot(contains('Bank')));
    const f = Form1099(id: 1, year: 2025, kind: '1099-K', payer: 'etsy', amountCents: 1);
    expect(_ask(DateTime(2026, 2, 1), e, receipts: {e.last.id}, forms: [f]), isEmpty);
  });

  test('reminder plan: future only, generic text, check-ins every N days at 18:00', () {
    final plan = planReminders(
      now: DateTime(2026, 9, 10),
      rules: [_rules],
      quarterly: true,
      checkInDays: 7,
      lastCheckIn: DateTime(2026, 9, 1),
    );
    final q = plan.where((r) => r.title.startsWith('Estimated')).toList();
    expect(q.map((r) => r.at), [DateTime(2026, 9, 14, 9), DateTime(2027, 1, 8, 9), DateTime(2027, 1, 14, 9)]);
    final c = plan.where((r) => r.title.contains('check-in')).toList();
    expect(plan.map((r) => r.id).toSet().length, plan.length, reason: 'ids unique');
    expect(c.length, 8);
    expect(c.first.at, DateTime(2026, 9, 15, 18));
    for (final r in plan) {
      expect(r.title + r.body, isNot(contains(r'$')), reason: 'no amounts in notifications');
    }
    expect(planReminders(now: DateTime(2026, 9, 10), rules: [_rules], quarterly: false, checkInDays: 0), isEmpty);
  });
}
