import 'package:data_handler/data_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DataHandler smoke test in example app', (WidgetTester tester) async {
    final handler = DataHandler<String>('Test Message');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: handler.when(
            onSuccess: (data) => Text(data),
          ),
        ),
      ),
    );

    expect(find.text('Test Message'), findsOneWidget);
  });
}
