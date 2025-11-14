// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:puzzles_arcade/main.dart';

void main() {
  testWidgets('Home screen shows games and snackbar on tap', (WidgetTester tester) async {
    // Build the app and wait for frames to settle.
    await tester.pumpWidget(const PuzzleApp());
    await tester.pumpAndSettle();

  // The app bar title should be present and a known game should be listed.
  expect(find.text('Puzzle Hub'), findsWidgets);
    expect(find.text('Sudoku'), findsOneWidget);

  // Tap the Sudoku list item and confirm we navigate to the Sudoku page.
  await tester.tap(find.text('Sudoku'));
  await tester.pumpAndSettle();

  // The Sudoku page app bar title should be visible.
  expect(find.text('Sudoku'), findsOneWidget);
  });
}
