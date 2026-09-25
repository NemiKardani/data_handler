import 'package:data_handler/data_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DataHandler Tests', () {
    tearDown(() {
      DataHandlerConfig.resetGlobalWidgets();
    });

    test('Initializes with default empty state when no data provided', () {
      final handler = DataHandler<String>();
      expect(handler.state, equals(DataState.empty));
      expect(handler.isEmpty, isTrue);
      expect(handler.isLoading, isFalse);
      expect(handler.hasError, isFalse);
      expect(handler.hasSuccess, isFalse);
      expect(handler.data, isNull);
      expect(handler.errorMessage, isEmpty);
    });

    test('Initializes with success state when initial data provided', () {
      final handler = DataHandler<String>('Initial Value');
      expect(handler.state, equals(DataState.success));
      expect(handler.hasSuccess, isTrue);
      expect(handler.data, equals('Initial Value'));
    });

    test('State transitions: startLoading, onSuccess, onError, onEmpty', () {
      final handler = DataHandler<int>();
      int notifyCount = 0;
      handler.addListener(() {
        notifyCount++;
      });

      // Loading
      handler.startLoading();
      expect(handler.isLoading, isTrue);
      expect(handler.data, isNull);
      expect(notifyCount, equals(1));

      // Re-calling startLoading should not trigger another notification if state has not changed
      handler.startLoading();
      expect(notifyCount, equals(1));

      // Success
      handler.onSuccess(42);
      expect(handler.hasSuccess, isTrue);
      expect(handler.data, equals(42));
      expect(notifyCount, equals(2));

      // Error
      handler.onError('Network timeout');
      expect(handler.hasError, isTrue);
      expect(handler.errorMessage, equals('Network timeout'));
      expect(handler.data, isNull);
      expect(notifyCount, equals(3));

      // Empty
      handler.onEmpty('No items found');
      expect(handler.isEmpty, isTrue);
      expect(handler.errorMessage, equals('No items found'));
      expect(notifyCount, equals(4));

      // Clear
      handler.clear();
      expect(handler.isEmpty, isTrue);
      expect(handler.errorMessage, isEmpty);
      expect(notifyCount, equals(5));
    });

    test('updateData updates value without triggering loading', () {
      final handler = DataHandler<String>('Initial');
      expect(handler.data, equals('Initial'));

      handler.updateData('Updated');
      expect(handler.data, equals('Updated'));
      expect(handler.state, equals(DataState.success));
    });

    test('refresh executes async fetcher and manages state', () async {
      final handler = DataHandler<String>();

      await handler.refresh(() async {
        return 'Fetched Data';
      });

      expect(handler.hasSuccess, isTrue);
      expect(handler.data, equals('Fetched Data'));

      // Error in refresh
      await handler.refresh(() async {
        throw Exception('Server failure');
      });

      expect(handler.hasError, isTrue);
      expect(handler.errorMessage, contains('Server failure'));
    });
  });

  group('DataHandler UI Tests', () {
    tearDown(() {
      DataHandlerConfig.resetGlobalWidgets();
    });

    testWidgets('when renders correct widgets for states', (tester) async {
      final handler = DataHandler<String>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: handler.when(
              onLoading: () => const Text('Custom Loading'),
              onSuccess: (data) => Text('Success: $data'),
              onError: (error) => Text('Error: $error'),
              onEmpty: (message) => Text('Empty: $message'),
            ),
          ),
        ),
      );

      // Initially empty
      expect(find.text('Empty: No data available'), findsOneWidget);

      // Switch to loading
      handler.startLoading();
      await tester.pump();
      expect(find.text('Custom Loading'), findsOneWidget);

      // Switch to success
      handler.onSuccess('Hello World');
      await tester.pump();
      expect(find.text('Success: Hello World'), findsOneWidget);

      // Switch to error
      handler.onError('Failed');
      await tester.pump();
      expect(find.text('Error: Failed'), findsOneWidget);
    });

    testWidgets('Global config fallback works correctly', (tester) async {
      DataHandlerConfig.setGlobalWidgets(
        loadingWidget: () => const Text('Global Loading'),
        errorWidget: (err) => Text('Global Error: $err'),
        emptyWidget: (msg) => Text('Global Empty: $msg'),
      );

      final handler = DataHandler<String>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: handler.when(
              onSuccess: (data) => Text('Success: $data'),
            ),
          ),
        ),
      );

      // Global empty
      expect(find.text('Global Empty: No data available'), findsOneWidget);

      // Global loading
      handler.startLoading();
      await tester.pump();
      expect(find.text('Global Loading'), findsOneWidget);

      // Global error
      handler.onError('404');
      await tester.pump();
      expect(find.text('Global Error: 404'), findsOneWidget);
    });
  });

  group('DataHandlerList Extension Tests', () {
    test('isListEmpty and listLength properties work as expected', () {
      final emptyListHandler = DataHandler<List<int>>([]);
      expect(emptyListHandler.isListEmpty, isTrue);
      expect(emptyListHandler.listLength, equals(0));

      final populatedHandler = DataHandler<List<int>>([1, 2, 3]);
      expect(populatedHandler.isListEmpty, isFalse);
      expect(populatedHandler.listLength, equals(3));
    });

    testWidgets('whenList renders empty list callback on empty list data', (tester) async {
      final handler = DataHandler<List<String>>(['item1']);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: handler.whenList(
              onSuccess: (list) => Text('Count: ${list.length}'),
              onEmptyList: (msg) => Text('Empty List: $msg'),
            ),
          ),
        ),
      );

      expect(find.text('Count: 1'), findsOneWidget);

      handler.onEmpty('List cleared');
      await tester.pump();
      expect(find.text('Empty List: List cleared'), findsOneWidget);
    });
  });
}
