import 'dart:async';

import 'package:data_handler/data_handler.dart';
import 'package:example/interceptor/logging_interceptor.dart';
import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    DataHandlerConfig.resetGlobalWidgets();
    AppLoggingInterceptor.instance.clearLogs();
    DataHandlerConfig.addInterceptor(AppLoggingInterceptor.instance);
  });

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

  testWidgets('AppLoggingInterceptor records DataHandler lifecycle events', (WidgetTester tester) async {
    final handler = DataHandler<int>();

    handler.startLoading();
    expect(AppLoggingInterceptor.instance.logsNotifier.value.any((l) => l.eventType == 'onRequest'), isTrue);

    handler.onSuccess(42);
    expect(AppLoggingInterceptor.instance.logsNotifier.value.any((l) => l.eventType == 'onSuccess'), isTrue);

    handler.onError('Failed');
    expect(AppLoggingInterceptor.instance.logsNotifier.value.any((l) => l.eventType == 'onError'), isTrue);
  });

  testWidgets('Selective rebuild with select<R>() in example widgets', (WidgetTester tester) async {
    final handler = DataHandler<List<String>>(['Apple', 'Banana']);
    int rebuildCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: handler.select<int>(
            selector: (list) => list.length,
            builder: (context, count) {
              rebuildCount++;
              return Text('Count: $count');
            },
          ),
        ),
      ),
    );

    expect(find.text('Count: 2'), findsOneWidget);
    expect(rebuildCount, 1);

    // Mutate an element without changing length -> Should NOT rebuild
    handler.updateData(['Avocado', 'Banana']);
    await tester.pump();
    expect(rebuildCount, 1);

    // Change length -> Should rebuild
    handler.updateData(['Avocado', 'Banana', 'Cherry']);
    await tester.pump();
    expect(find.text('Count: 3'), findsOneWidget);
    expect(rebuildCount, 2);
  });

  testWidgets('bindStream and pattern matching maybeWhen in example widgets', (WidgetTester tester) async {
    final handler = DataHandler<int>();
    final controller = StreamController<int>();

    handler.bindStream(controller.stream);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: handler.maybeWhen(
            onSuccess: (val) => Text('Stream value: $val'),
            orElse: () => const Text('Waiting for stream...'),
          ),
        ),
      ),
    );

    expect(find.text('Waiting for stream...'), findsOneWidget);

    controller.add(100);
    await tester.pump();

    expect(find.text('Stream value: 100'), findsOneWidget);

    await controller.close();
    handler.dispose();
  });

  testWidgets('MyApp renders tabs and navigation smoothly', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    // Verify NavigationBar destinations exist
    expect(find.text('Feed & Ops'), findsOneWidget);
    expect(find.text('Live Stream'), findsOneWidget);
    expect(find.text('Interceptors'), findsOneWidget);

    // Switch to Live Stream tab
    await tester.tap(find.text('Live Stream'));
    await tester.pumpAndSettle();
    expect(find.text('Real-Time Stream Binding (bindStream)'), findsOneWidget);

    // Switch to Interceptors tab
    await tester.tap(find.text('Interceptors'));
    await tester.pumpAndSettle();
    expect(find.text('Team Interceptors & Diagnostics'), findsOneWidget);
  });
}
