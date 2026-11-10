import 'package:flutter/foundation.dart';

enum NavLayout {
  pill('Pill', 'The selected item expands to show its name.'),
  icons('Icons', 'Icons only.'),
  labels('Labels', 'Each icon has its name under it.'),
  dock('Dock', 'Like Labels, but the bar spans the whole width.');

  const NavLayout(this.label, this.hint);
  final String label, hint;
}

enum SelectionLook {
  fill('Fill', 'A solid highlight behind the selected item.'),
  ring('Ring', 'An outline around the selected item.'),
  soft('Soft', 'A faint highlight behind the selected item.'),
  dot('Dot', 'A small dot under the selected item.'),
  text('Text', 'Only the colour of the selected item changes.');

  const SelectionLook(this.label, this.hint);
  final String label, hint;
}

/// How the floating bar is laid out. Radii are percentages of half the shape's height, so
/// 100 is a full pill.
@immutable
class NavStyle {
  const NavStyle({
    this.layout = NavLayout.pill,
    this.barRadius = 100,
    this.selectionRadius = 100,
    this.look = SelectionLook.fill,
  });

  final NavLayout layout;
  final double barRadius, selectionRadius;
  final SelectionLook look;

  NavStyle copyWith({NavLayout? layout, double? barRadius, double? selectionRadius, SelectionLook? look}) => NavStyle(
        layout: layout ?? this.layout,
        barRadius: (barRadius ?? this.barRadius).clamp(0, 100),
        selectionRadius: (selectionRadius ?? this.selectionRadius).clamp(0, 100),
        look: look ?? this.look,
      );

  Map<String, dynamic> toJson() => {
        'layout': layout.name,
        'barRadius': barRadius,
        'selectionRadius': selectionRadius,
        'look': look.name,
      };

  /// Anything missing or of the wrong type takes its default.
  factory NavStyle.fromJson(Map<String, dynamic> json) {
    const d = NavStyle();
    return NavStyle(
      layout: NavLayout.values.where((e) => e.name == json['layout']).firstOrNull ?? d.layout,
      look: SelectionLook.values.where((e) => e.name == json['look']).firstOrNull ?? d.look,
    ).copyWith(
      barRadius: json['barRadius'] is num ? (json['barRadius'] as num).toDouble() : d.barRadius,
      selectionRadius: json['selectionRadius'] is num ? (json['selectionRadius'] as num).toDouble() : d.selectionRadius,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NavStyle &&
      other.layout == layout &&
      other.barRadius == barRadius &&
      other.selectionRadius == selectionRadius &&
      other.look == look;

  @override
  int get hashCode => Object.hash(layout, barRadius, selectionRadius, look);
}
