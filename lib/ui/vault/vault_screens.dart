// Documents vault per year (SPEC §2.8) and receipts (§2.4). Everything shown is
// decrypted in memory only.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/app_controller.dart';
import '../../data/database.dart';
import '../../media/documents.dart';
import '../../platform/document_picker.dart';
import '../design/components.dart';
import '../design/theme.dart';
import '../ledger/category_icons.dart';
import 'capture_screen.dart';

final attachmentsProvider = StreamProvider.family<List<Attachment>, int>((ref, year) {
  final db = ref.watch(appControllerProvider.select((a) => a.db));
  return db == null ? Stream.value(const []) : db.watchAttachments(year);
});

final entryAttachmentsProvider = StreamProvider.family<List<Attachment>, int>((ref, entryId) {
  final db = ref.watch(appControllerProvider.select((a) => a.db));
  return db == null ? Stream.value(const []) : db.watchEntryAttachments(entryId);
});

String _size(int b) => b < 1024 * 1024 ? '${(b / 1024).ceil()} KB' : '${(b / 1024 / 1024).toStringAsFixed(1)} MB';

IconData _folderIcon(String f) => switch (f) {
  'tax_form' => Icons.work_outline_rounded,
  'receipt' => Icons.receipt_rounded,
  'prior_return' => Icons.history_edu_rounded,
  'letter' => Icons.mail_outline_rounded,
  _ => Icons.folder_outlined,
};

/// Decrypts and shows a thumbnail (in memory only).
class EncryptedThumb extends ConsumerWidget {
  final Attachment a;
  final double size;
  const EncryptedThumb(this.a, {super.key, this.size = 96});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(appControllerProvider.select((x) => x.documents));
    final ll = context.ll;
    Widget icon() => Container(
      color: ll.surfaceAlt,
      alignment: Alignment.center,
      child: Icon(
        a.mime == 'application/pdf' ? Icons.picture_as_pdf_outlined : Icons.insert_drive_file_outlined,
        color: ll.muted,
        size: size * 0.4,
      ),
    );
    if (docs == null || a.thumbId == null) return icon();
    return FutureBuilder<Uint8List?>(
      future: docs.thumbnail(a),
      builder: (_, s) => s.data == null
          ? Container(color: ll.surfaceAlt)
          : Image.memory(s.data!, fit: BoxFit.cover, gaplessPlayback: true, cacheWidth: (size * 3).round()),
    );
  }
}

class VaultTab extends ConsumerWidget {
  const VaultTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(appControllerProvider.select((a) => a.selectedYear));
    final items = ref.watch(attachmentsProvider(year)).value ?? const [];
    final counts = <String, int>{};
    for (final a in items) {
      counts[a.folder] = (counts[a.folder] ?? 0) + 1;
    }
    final unmatched = items.where((a) => a.folder == 'receipt' && a.entryId == null).toList();
    final ll = context.ll;
    // Folder identity: one soft hue each, so folders are recognised, not read.
    Color tint(String f) => switch (f) {
      'tax_form' => ll.accent,
      'receipt' => ll.warning,
      'prior_return' =>
        Theme.of(context).brightness == Brightness.dark ? const Color(0xFF86AEE0) : const Color(0xFF3F6FAA),
      'letter' => ll.expense,
      _ => ll.muted,
    };
    final sections = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, Space.xs),
        child: Row(
          children: [
            Icon(Icons.verified_user_outlined, size: 16, color: ll.accent),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Text(
                items.isEmpty
                    ? 'Sealed with AES-256, on this phone only.'
                    : '${items.length} file${items.length == 1 ? '' : 's'}, sealed with AES-256 on this phone.',
                style: context.text.bodySmall,
              ),
            ),
          ],
        ),
      ),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: Space.md,
        crossAxisSpacing: Space.md,
        childAspectRatio: 1.45,
        children: [
          for (final f in vaultFolders.entries.where((f) => f.key != 'other' || (counts['other'] ?? 0) > 0))
            LLCard(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FolderScreen(folder: f.key, year: year),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: tint(f.key).withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_folderIcon(f.key), size: 20, color: tint(f.key)),
                      ),
                      const Spacer(),
                      if ((counts[f.key] ?? 0) > 0)
                        Text(
                          '${counts[f.key]}',
                          style: context.text.titleLarge?.copyWith(fontFeatures: tabular, color: ll.text),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(f.value, style: context.text.titleSmall),
                  Text(
                    (counts[f.key] ?? 0) == 0 ? 'Empty' : '${counts[f.key]} ${counts[f.key] == 1 ? 'file' : 'files'}',
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
        ],
      ),
      if (unmatched.isNotEmpty)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader('Receipts to match', trailing: Pill('${unmatched.length}', color: ll.warning)),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: unmatched.length,
                separatorBuilder: (_, _) => const SizedBox(width: Space.md),
                itemBuilder: (_, i) => _Tile(unmatched[i], width: 92),
              ),
            ),
          ],
        ),
      if (items.isEmpty)
        EmptyState(
          icon: Icons.document_scanner_rounded,
          title: 'Scan your first receipt',
          body:
              'Tap the scan button below. Every photo and document is encrypted on this phone and never '
              'shows up in your gallery.',
          actionLabel: 'Import a W-2 or 1099',
          onAction: () => importInto(context, ref, folder: 'tax_form', year: year),
        )
      else
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [const SectionHeader('Recently added'), _Grid(items.take(9).toList())],
        ),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxl),
      children: [
        for (final (i, w) in sections.indexed)
          Padding(
            padding: EdgeInsets.only(bottom: i == sections.length - 1 ? 0 : Space.md),
            child: Reveal(index: i, child: w),
          ),
      ],
    );
  }
}

/// Imports a file through the platform picker (no plaintext copies) into [folder].
Future<void> importInto(BuildContext context, WidgetRef ref, {required String folder, required int year}) async {
  final app = ref.read(appControllerProvider);
  final docs = app.documents;
  if (docs == null) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final f = await app.picker.pick();
    if (f == null) return;
    await docs.importFile(name: f.name, mime: f.mime, bytes: f.bytes, folder: folder, year: year);
    messenger.showSnackBar(SnackBar(content: Text('${f.name} saved encrypted')));
  } on PickTooLarge {
    messenger.showSnackBar(const SnackBar(content: Text('That file is over 30 MB.')));
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('That file couldn\'t be read.')));
  }
}

class _Grid extends StatelessWidget {
  final List<Attachment> items;
  const _Grid(this.items);

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 3,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: Space.md,
    crossAxisSpacing: Space.md,
    childAspectRatio: 0.78,
    children: [for (final a in items) _Tile(a)],
  );
}

class _Tile extends StatelessWidget {
  final Attachment a;
  final double? width;
  const _Tile(this.a, {this.width});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Semantics(
      button: true,
      label: '${a.name.isEmpty ? vaultFolders[a.folder] : a.name}, ${DateFormat.yMMMd().format(a.createdAt)}',
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ViewerScreen(a))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              EncryptedThumb(a),
              if (a.folder == 'receipt' && a.entryId == null)
                Positioned(left: 6, top: 6, child: Pill('Unmatched', color: context.ll.warning)),
            ],
          ),
        ),
      ),
    ),
  );
}

class FolderScreen extends ConsumerWidget {
  final String folder;
  final int year;
  const FolderScreen({super.key, required this.folder, required this.year});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = (ref.watch(attachmentsProvider(year)).value ?? const []).where((a) => a.folder == folder).toList();
    return Scaffold(
      appBar: AppBar(title: Text('${vaultFolders[folder]} · $year')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => folder == 'receipt'
            ? captureReceipt(context, year: year)
            : importInto(context, ref, folder: folder, year: year),
        icon: Icon(folder == 'receipt' ? Icons.document_scanner_outlined : Icons.upload_file_rounded),
        label: Text(folder == 'receipt' ? 'Scan' : 'Import'),
      ),
      body: items.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(Space.gutter),
              child: EmptyState(
                icon: _folderIcon(folder),
                title: 'Nothing here yet',
                body: 'Import a photo or PDF. It\'s encrypted on this phone the moment it\'s added.',
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 96),
              children: [_Grid(items)],
            ),
    );
  }
}

class ViewerScreen extends ConsumerStatefulWidget {
  final Attachment a;
  const ViewerScreen(this.a, {super.key});
  @override
  ConsumerState<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends ConsumerState<ViewerScreen> {
  Future<Uint8List>? _bytes;
  late Attachment _a = widget.a;

  @override
  void initState() {
    super.initState();
    _bytes = ref.read(appControllerProvider).documents?.read(_a);
  }

  Future<void> _delete() async {
    final docs = ref.read(appControllerProvider).documents;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Delete this file?', style: ctx.text.titleMedium),
              const SizedBox(height: Space.sm),
              Text(
                'It\'s removed from this phone for good. Records stay; they just lose the attachment.',
                style: ctx.text.bodySmall,
              ),
              const SizedBox(height: Space.lg),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: ctx.ll.expense),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
            ],
          ),
        ),
      ),
    );
    if (ok == true && docs != null) {
      await docs.delete(_a);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _attach() async {
    final db = ref.read(appControllerProvider).db;
    if (db == null) return;
    final rules = ref.read(taxRulesProvider(_a.year)).value;
    final entries = await db.watchYear(_a.year).first;
    if (!mounted) return;
    final picked = await showModalBottomSheet<LedgerEntry>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, scroll) => ListView(
          controller: scroll,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.sm),
              child: Text('Attach to a record', style: ctx.text.titleMedium),
            ),
            if (entries.isEmpty) const ListTile(title: Text('No records this year yet. Add one first.')),
            for (final e in entries)
              ListTile(
                leading: Icon(categoryIcon(e.category)),
                title: Text(e.party.isNotEmpty ? e.party : (rules?.category(e.category)?.name ?? e.category)),
                subtitle: Text(DateFormat.yMMMd().format(e.day)),
                trailing: Text(formatCents(e.amountCents), style: ctx.text.titleSmall?.copyWith(fontFeatures: tabular)),
                onTap: () => Navigator.pop(ctx, e),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await db.linkAttachment(_a.id, picked.id);
    final updated = await db.attachment(_a.id);
    if (updated != null && mounted) setState(() => _a = updated);
  }

  @override
  Widget build(BuildContext context) {
    final a = _a;
    final isImage = a.mime.startsWith('image/');
    return Scaffold(
      backgroundColor: isImage ? Colors.black : null,
      appBar: AppBar(
        backgroundColor: isImage ? Colors.black : null,
        foregroundColor: isImage ? Colors.white : null,
        title: Text(a.name.isEmpty ? vaultFolders[a.folder]! : a.name, overflow: TextOverflow.ellipsis),
        actions: [
          if (a.folder == 'receipt')
            IconButton(
              tooltip: a.entryId == null ? 'Attach to a record' : 'Attached. Change record',
              icon: Icon(a.entryId == null ? Icons.link_rounded : Icons.link_off_rounded),
              onPressed: _attach,
            ),
          IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline_rounded), onPressed: _delete),
        ],
      ),
      body: FutureBuilder<Uint8List>(
        future: _bytes,
        builder: (context, s) {
          if (s.hasError) return const Center(child: Text('This file couldn\'t be decrypted.'));
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          if (isImage) {
            return InteractiveViewer(maxScale: 6, child: Center(child: Image.memory(s.data!)));
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(Space.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.picture_as_pdf_outlined, size: 64, color: context.ll.accent),
                  const SizedBox(height: Space.lg),
                  Text(a.name, style: context.text.titleMedium, textAlign: TextAlign.center),
                  const SizedBox(height: Space.sm),
                  Text(
                    '${_size(a.sizeBytes)} · stored encrypted · added ${DateFormat.yMMMd().format(a.createdAt)}',
                    style: context.text.bodySmall,
                  ),
                  const SizedBox(height: Space.sm),
                  Text('In-app PDF preview arrives with the PDF tools (M6).', style: context.text.bodySmall),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
