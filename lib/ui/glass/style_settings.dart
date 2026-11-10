import 'dart:io';

import 'package:flutter/material.dart';

import '../../app.dart';
import '../look.dart';

/// Material 3 Expressive or glass: all at once, or each part of the interface on its own.
class StyleSettings extends StatelessWidget {
  const StyleSettings({super.key});

  // The bottom bar is phone-only; the PC has a sidebar.
  static final _groups = [
    for (final g in LookGroup.values)
      if (g != LookGroup.nav || Platform.isAndroid || Platform.isIOS) g,
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: app.ui.lookChanges,
      builder: (context, _) {
        final all = {for (final g in _groups) app.ui.look(g)};
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<Look?>(
                  showSelectedIcon: false,
                  emptySelectionAllowed: true,
                  segments: [
                    for (final l in Look.values) ButtonSegment<Look?>(value: l, label: Text(l.label)),
                  ],
                  selected: all.length == 1 ? {all.first} : <Look?>{},
                  onSelectionChanged: (s) => s.isEmpty ? null : app.ui.setAllLooks(s.first!),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                all.length == 1 ? 'The whole app.' : 'Mixed: each part below has its own look.',
                style: text.bodySmall,
              ),
            ),
            for (final g in _groups)
              ListTile(
                title: Text(g.label),
                subtitle: Text(g.hint),
                trailing: SegmentedButton<Look>(
                  showSelectedIcon: false,
                  segments: [for (final l in Look.values) ButtonSegment(value: l, label: Text(l.label))],
                  selected: {app.ui.look(g)},
                  onSelectionChanged: (s) => app.ui.setLook(g, s.first),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text(
                'Glass is see-through with a light rim. Only the navigation bar also blurs and bends '
                'what is behind it; tune that under Glass.',
                style: text.bodySmall,
              ),
            ),
          ],
        );
      },
    );
  }
}
