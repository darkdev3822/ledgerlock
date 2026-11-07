import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/data/attention.dart';
import 'package:ledgerlock/data/database.dart';
import 'package:ledgerlock/data/tax_rules.dart';
import 'package:ledgerlock/data/year_end.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TaxRules rules;
  setUpAll(() async => rules = await TaxRules.load(2026));

  test('the checklist is for the year ending: Dec 1 - Jan 31 only', () {
    expect(yearEndYear(DateTime(2026, 12, 1)), 2026);
    expect(yearEndYear(DateTime(2027, 1, 31, 23, 59)), 2026);
    expect(yearEndYear(DateTime(2026, 11, 30)), isNull);
    expect(yearEndYear(DateTime(2027, 2, 1)), isNull);
  });

  test('the quarter periods parse from the rules file', () {
    expect(rules.quarterlyDue.map((q) => q.period(2026)), everyElement(isNotNull));
    expect(rules.quarterlyDue[1].period(2026), (DateTime(2026, 4, 1), DateTime(2026, 5, 31)));
    expect(QuarterDue('Q1', 'garbage', DateTime(2026)).period(2026), isNull);
  });

  test('items tick themselves from the data; manual ones need a tick; driving adds mileage', () {
    final today = DateTime(2026, 12, 10);
    List<YearEndItem> run({
      List<AttentionItem> attention = const [],
      List<TaxPayment> payments = const [],
      DateTime? backup,
      Set<String> ticked = const {},
      bool drives = false,
      List<Trip> trips = const [],
    }) => yearEndItems(
      year: 2026,
      rules: rules,
      today: today,
      attention: attention,
      payments: payments,
      trips: trips,
      forms: const [],
      drives: drives,
      lastBackup: backup,
      ticked: ticked,
    );
    bool done(List<YearEndItem> l, String id) => l.firstWhere((i) => i.id == id).done;

    final fresh = run();
    expect(fresh.any((i) => i.id == 'mileage'), isFalse);
    expect(done(fresh, 'backup'), isFalse);
    expect(done(fresh, 'receipts'), isTrue);
    expect(done(fresh, 'q4'), isFalse);
    expect(done(fresh, 'personal'), isFalse);

    final later = run(
      attention: const [AttentionItem('no_receipt', 2, 30000)],
      payments: const [
        TaxPayment(id: 1, taxYear: 2026, quarter: 'Q4', date: '2026-12-09', amountCents: 1, method: '', notes: ''),
      ],
      backup: DateTime(2026, 12, 1),
      ticked: {'personal', 'forms'},
      drives: true,
      trips: const [Trip(id: 1, date: '2026-12-02', milesTenths: 10, purpose: '', route: '', businessId: 1)],
    );
    expect(done(later, 'backup'), isTrue);
    expect(done(later, 'receipts'), isFalse);
    expect(later.firstWhere((i) => i.id == 'receipts').detail, contains('2 still'));
    expect(done(later, 'q4'), isTrue);
    expect(done(later, 'personal'), isTrue);
    expect(done(later, 'mileage'), isTrue, reason: 'December trips logged');
    expect(done(later, 'forms'), isTrue);
    expect(done(run(backup: DateTime(2026, 10, 1)), 'backup'), isFalse, reason: 'over 30 days old');
  });
}
