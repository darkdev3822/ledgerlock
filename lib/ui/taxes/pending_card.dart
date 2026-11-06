import 'package:flutter/material.dart';

import '../../app/build_info.dart';
import '../../data/tax_rules.dart';
import '../design/components.dart';
import '../design/theme.dart';

/// Taxes tab: the year's figures still waiting for their IRS source (review.pending), and what the app does
/// meanwhile. Nothing to show once the year's review is complete.
class PendingFiguresCard extends StatelessWidget {
  final TaxRules rules;
  const PendingFiguresCard({super.key, required this.rules});

  @override
  Widget build(BuildContext context) {
    final ll = context.ll;
    return LLCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Waiting on the IRS',
                  style: context.text.titleSmall?.copyWith(fontFamily: Fonts.voice, fontWeight: FontWeight.w600),
                ),
              ),
              if (isBeta) Pill('Beta', color: ll.warning, icon: Icons.science_outlined),
            ],
          ),
          const SizedBox(height: Space.xs),
          Text(
            'These ${rules.year} figures aren\'t published yet. LedgerLock will be updated when they are.',
            style: context.text.bodySmall,
          ),
          for (final p in rules.pending) ...[
            const SizedBox(height: Space.md),
            MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.what, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  if (p.expected.isNotEmpty || p.source.isNotEmpty)
                    Text(
                      [if (p.expected.isNotEmpty) 'Expected ${p.expected}', if (p.source.isNotEmpty) p.source].join(' · '),
                      style: context.text.bodySmall?.copyWith(color: ll.muted),
                    ),
                  if (p.meanwhile.isNotEmpty) Text(p.meanwhile, style: context.text.bodySmall),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
