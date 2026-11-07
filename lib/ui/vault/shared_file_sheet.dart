// "Share > LedgerLock": what to do with a file another app sent (SECURITY.md T44). Asked after unlock; until the
// user picks, the file is only in memory.
import 'package:flutter/material.dart';

import '../../platform/launch_inbox.dart';
import '../design/theme.dart';

enum SharedChoice { expense, vault }

String _size(int b) => b < 1024 * 1024 ? '${(b / 1024).ceil()} KB' : '${(b / 1024 / 1024).toStringAsFixed(1)} MB';

Future<SharedChoice?> askSharedFile(BuildContext context, SharedFile f) => showModalBottomSheet<SharedChoice>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (c) => SafeArea(
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            child: Text('Add this to LedgerLock?', style: c.text.titleMedium),
          ),
          ListTile(
            leading: Icon(f.isImage ? Icons.image_outlined : Icons.picture_as_pdf_outlined),
            title: Text(f.name, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text('${f.isImage ? 'Photo' : 'PDF'} · ${_size(f.bytes.length)} · shared from another app'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: const Text('New expense with this receipt'),
            subtitle: Text(f.isImage ? 'Read on this phone to fill in the amount' : 'Attached to the new record'),
            onTap: () => Navigator.pop(c, SharedChoice.expense),
          ),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('Save to the Vault only'),
            subtitle: const Text('Match it to a record later'),
            onTap: () => Navigator.pop(c, SharedChoice.vault),
          ),
          ListTile(
            leading: const Icon(Icons.close_rounded),
            title: const Text('Discard'),
            subtitle: const Text('Nothing is kept'),
            onTap: () => Navigator.pop(c),
          ),
          const SizedBox(height: Space.sm),
        ],
      ),
    ),
  ),
);
