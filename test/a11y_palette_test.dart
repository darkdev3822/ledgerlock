// WCAG 2.1 AA text contrast (4.5:1) for every text colour on every surface it is drawn on, in both themes,
// including the 12% tinted pills (Pill, StatTile icon tiles). Exact, unlike pixel sampling (M8 a11y pass).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/ui/design/theme.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final (name, c) in [('light', LLColors.light), ('dark', LLColors.dark)]) {
    test('$name: text colours meet 4.5:1 on all surfaces and their own pills', () {
      final surfaces = {'background': c.background, 'surface': c.surface, 'surfaceAlt': c.surfaceAlt};
      final texts = {
        'text': c.text,
        'muted': c.muted,
        'accent': c.accent,
        'warning': c.warning,
        'expense': c.expense,
        'income': c.income,
      };
      for (final t in texts.entries) {
        for (final s in surfaces.entries) {
          expect(contrast(t.value, s.value), greaterThanOrEqualTo(4.5), reason: '${t.key} on ${s.key}');
          final pill = Color.alphaBlend(t.value.withValues(alpha: 0.12), s.value);
          expect(contrast(t.value, pill), greaterThanOrEqualTo(4.5), reason: '${t.key} on its 12% pill over ${s.key}');
        }
      }
      // Accent-coloured text on accentSoft chips (selected segment, "in N days").
      expect(contrast(c.accent, c.accentSoft), greaterThanOrEqualTo(4.5));
      expect(contrast(c.onAccent, c.accent), greaterThanOrEqualTo(4.5), reason: 'buttons');
    });
  }
}
