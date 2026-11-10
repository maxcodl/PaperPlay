import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teleplayer/ui/bot_setup.dart';
import 'package:teleplayer/ui/widgets.dart';

void main() {
  testWidgets('a settings section starts closed and toggles from its heading', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CollapsibleSection(title: 'Section', children: [Text('Inside')]),
        ),
      ),
    );
    expect(find.text('Inside'), findsNothing);

    await tester.tap(find.text('Section'));
    await tester.pumpAndSettle();
    expect(find.text('Inside'), findsOneWidget);

    await tester.tap(find.text('Section'));
    await tester.pumpAndSettle();
    expect(find.text('Inside'), findsNothing);
  });

  testWidgets('malformed keys show an error instead of continuing', (tester) async {
    // Tall enough to show the whole form.
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: BotSetupScreen()));
    expect(find.text('Open my.telegram.org'), findsOneWidget);
    expect(find.text('Restore a backup'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'api_id'), 'abc');
    await tester.enterText(find.widgetWithText(TextField, 'api_hash'), 'short');
    await tester.tap(find.widgetWithText(FilledButton, 'Start'));
    await tester.pump();

    expect(find.textContaining('Check api_id'), findsOneWidget);
  });
}
