import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/app/app_controller.dart';
import 'package:ledgerlock/data/attention.dart';
import 'package:ledgerlock/data/database.dart';
import 'package:ledgerlock/platform/launch_inbox.dart';
import 'package:ledgerlock/security/biometric_reset.dart';

class FakeBiometrics implements BiometricSecretStore {
  @override
  Future<bool> isAvailable() async => false;
  @override
  Future<void> save(Uint8List s) async {}
  @override
  Future<Uint8List?> read() async => null;
  @override
  Future<void> delete() async {}
}

class FakeLaunchSource implements LaunchSource {
  final List<Object?> queue;
  FakeLaunchSource(this.queue);
  @override
  Future<LaunchAction?> take() async => queue.isEmpty ? null : parseLaunch(queue.removeAt(0));
  @override
  void listen(void Function() onReady) {}
}

Uint8List b(List<int> x) => Uint8List.fromList(x);
final pdf = b([...ascii.encode('%PDF-1.7\n'), 1, 2, 3]);

LedgerEntry e(int id, String date, int cents, {bool income = false, bool paid = true, String party = ''}) =>
    LedgerEntry(
      id: id,
      isIncome: income,
      date: date,
      amountCents: cents,
      feeCents: 0,
      businessPct: 100,
      category: income ? 'gross_receipts' : 'supplies',
      party: party,
      platform: '',
      notes: '',
      paid: paid,
      tags: '',
      businessId: 1,
      createdAt: DateTime(2026),
    );

void main() {
  group('shared files are checked by content (T44)', () {
    test('sniffs receipt types and rejects everything else', () {
      expect(sniffReceiptMime(b([0xFF, 0xD8, 0xFF, 0xE0])), 'image/jpeg');
      expect(sniffReceiptMime(b([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0])), 'image/png');
      expect(sniffReceiptMime(b([...ascii.encode('RIFF'), 0, 0, 0, 0, ...ascii.encode('WEBPVP8 ')])), 'image/webp');
      expect(sniffReceiptMime(pdf), 'application/pdf');
      expect(sniffReceiptMime(b([0, 0, 0, 24, ...ascii.encode('ftypheic'), 0, 0])), 'image/heic');
      expect(sniffReceiptMime(b(ascii.encode('<html><script>'))), isNull);
      expect(sniffReceiptMime(b([0x50, 0x4B, 3, 4])), isNull, reason: 'zip / apk');
      expect(sniffReceiptMime(b([0xFF, 0xD8])), isNull, reason: 'too short');
    });

    test('a share claiming to be a photo but holding anything else is refused', () {
      final a = parseLaunch({'kind': 'share', 'name': 'x.png', 'mime': 'image/png', 'bytes': b(ascii.encode('MZ..'))});
      expect(a, isA<ShareFailed>());
    });

    test('type comes from the bytes, not the sender; names are cleaned, capped and defaulted', () {
      final a =
          parseLaunch({'kind': 'share', 'name': 'inv\u202Efdp.exe\u0007${'x' * 300}', 'mime': 'image/jpeg', 'bytes': pdf})!
              as SharedFile;
      expect(a.mime, 'application/pdf');
      expect(a.name.contains('\u202E'), isFalse);
      expect(a.name.contains('\u0007'), isFalse);
      expect(a.name.length, 120);
      final d = parseLaunch({'kind': 'share', 'name': null, 'bytes': pdf})! as SharedFile;
      expect(d.name, 'Shared receipt.pdf');
    });

    test('size cap, empty files, native errors and junk', () {
      expect(parseLaunch({'kind': 'share', 'bytes': Uint8List(maxSharedBytes + 1)}), isA<ShareFailed>());
      expect(parseLaunch({'kind': 'share', 'bytes': Uint8List(0)}), isA<ShareFailed>());
      expect(parseLaunch({'kind': 'share', 'bytes': 'not bytes'}), isA<ShareFailed>());
      expect((parseLaunch({'kind': 'share_error', 'why': 'too_large'})! as ShareFailed).why, contains('30 MB'));
      expect(parseLaunch({'kind': 'share_error', 'why': 'unsupported'}), isA<ShareFailed>());
      expect(parseLaunch(null), isNull);
      expect(parseLaunch('scan'), isNull);
      expect(parseLaunch({'kind': 'settings'}), isNull, reason: 'only the four shortcut kinds');
      for (final k in ShortcutAction.kinds) {
        expect((parseLaunch({'kind': k})! as ShortcutAction).kind, k);
      }
    });
  });

  test('a waiting action is taken once, and expires if nobody unlocks within 10 minutes', () async {
    final dir = Directory.systemTemp.createTempSync('ll_launch');
    addTearDown(() => dir.deleteSync(recursive: true));
    final app = AppController(
      dataDir: dir,
      biometrics: FakeBiometrics(),
      launches: FakeLaunchSource([
        {'kind': 'scan'},
        {'kind': 'income'},
      ]),
    );
    var signals = 0;
    app.launchSignal.addListener(() => signals++);
    await app.pullLaunch();
    expect(signals, 1);
    expect((app.takeLaunch()! as ShortcutAction).kind, 'scan');
    expect(app.takeLaunch(), isNull, reason: 'taken once');
    await app.pullLaunch();
    expect(app.takeLaunch(now: DateTime.now().add(const Duration(minutes: 11))), isNull);
    expect(app.pendingLaunch, isNull);
  });

  group('needs attention', () {
    final today = DateTime(2026, 11, 1);
    test('expenses over \$75 without a receipt; \$75 exactly and receipted ones are fine', () {
      final items = attentionItems(
        entries: [
          e(1, '2026-10-01', 7500),
          e(2, '2026-10-02', 7501),
          e(3, '2026-10-03', 20000),
          e(4, '2026-10-04', 9000),
        ],
        withReceipt: {3},
        forms: const [],
        today: today,
      );
      expect(items.single.kind, 'no_receipt');
      expect((items.single.count, items.single.cents), (2, 16501));
    });

    test('invoices unpaid for over 30 days; recent ones and received ones are fine', () {
      final items = attentionItems(
        entries: [
          e(1, '2026-09-15', 50000, income: true, paid: false),
          e(2, '2026-10-10', 30000, income: true, paid: false),
          e(3, '2026-08-01', 10000, income: true),
        ],
        withReceipt: const {},
        forms: const [],
        today: today,
      );
      expect((items.single.kind, items.single.count, items.single.cents), ('old_invoice', 1, 50000));
    });

    test('1099s higher than recorded income from that payer (same rule as the 1099 screen)', () {
      Form1099 f(String payer, int c) =>
          Form1099(id: c, year: 2026, kind: '1099-NEC', payer: payer, amountCents: c, businessId: 1);
      final items = attentionItems(
        entries: [e(1, '2026-05-01', 100000, income: true, party: 'Acme')],
        withReceipt: const {},
        forms: [f('Acme', 100050), f('ACME ', 150000), f('Other', 1000)],
        today: today,
      );
      expect((items.single.kind, items.single.count, items.single.cents), ('form_1099', 2, 50000 + 1000));
    });

    test('nothing to say: empty', () {
      expect(attentionItems(entries: const [], withReceipt: const {}, forms: const [], today: today), isEmpty);
    });
  });
}
