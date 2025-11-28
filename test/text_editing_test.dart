import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_canvas/main.dart';

void main() {
  Future<void> addTextElement(WidgetTester tester) async {
    final addTextButton = find.byKey(const ValueKey('add-text-button'));
    expect(addTextButton, findsOneWidget);
    await tester.tap(addTextButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('text field reuses controller across rebuilds', (tester) async {
    await tester.pumpWidget(const PdfCanvasApp());

    await addTextElement(tester);

    final textField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Text',
    );
    expect(textField, findsOneWidget);

    final controller = tester.widget<TextField>(textField).controller;
    expect(controller, isNotNull);

    await tester.enterText(textField, 'Hello');
    await tester.pump();

    final afterFirstEdit =
        tester.widget<TextField>(textField).controller as TextEditingController;
    expect(identical(controller, afterFirstEdit), isTrue);
    expect(afterFirstEdit.text, 'Hello');

    await tester.enterText(textField, 'Hello!');
    await tester.pump();

    final afterSecondEdit =
        tester.widget<TextField>(textField).controller as TextEditingController;
    expect(identical(controller, afterSecondEdit), isTrue);
    expect(afterSecondEdit.text, 'Hello!');
    expect(find.text('Hello!'), findsWidgets); // inspector + canvas
  });

  testWidgets('deleting selected text removes inspector inputs',
      (tester) async {
    await tester.pumpWidget(const PdfCanvasApp());

    await addTextElement(tester);

    expect(find.text('Delete element'), findsOneWidget);
    await tester.ensureVisible(find.text('Delete element'));
    await tester.tap(find.text('Delete element'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.text('Select an element to edit properties'),
      findsOneWidget,
    );
  });
}
