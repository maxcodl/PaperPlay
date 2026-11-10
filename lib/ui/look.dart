/// How a part of the interface is drawn: solid Material 3 Expressive, or see-through glass.
enum Look {
  material('Material 3'),
  glass('Glass');

  const Look(this.label);
  final String label;
}

/// The parts of the interface that can each take either [Look].
enum LookGroup {
  nav('Navigation bar', 'The bar at the bottom'),
  bars('Top bars', 'Page titles and toolbars'),
  cards('Cards', 'Cards and tiles'),
  overlays('Dialogs, sheets and menus', 'Everything that opens over a page');

  const LookGroup(this.label, this.hint);
  final String label, hint;
}
