import 'dart:async';
import 'package:data_handler/data_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestInterceptor extends DataHandlerInterceptor {
  int requestCount = 0;
  int successCount = 0;
  int errorCount = 0;
  int stateChangeCount = 0;

  @override
  void onRequest(DataHandler handler) {
    requestCount++;
  }

  @override
  void onSuccess(DataHandler handler, dynamic data) {
    successCount++;
  }

  @override
  void onError(DataHandler handler, dynamic error) {
    errorCount++;
  }

  @override
  void onStateChanged(
    DataHandler handler,
    DataState oldState,
    DataState newState,
  ) {
    stateChangeCount++;
  }
}

class _UserModel {
  final String name;
  final int unreadCount;
  _UserModel(this.name, this.unreadCount);
}

void main() {
  group('DataHandler Core Tests', () {
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
      expect(handler.isDisposed, isFalse);
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

    test('startLoading with preserveData retains current data in memory', () {
      final handler = DataHandler<String>('Active Data');
      expect(handler.data, equals('Active Data'));

      handler.startLoading(preserveData: true);
      expect(handler.isLoading, isTrue);
      expect(handler.data, equals('Active Data')); // Not wiped!

      handler.startLoading(preserveData: false);
      expect(handler.isLoading, isTrue);
      expect(handler.data, isNull); // Wiped as requested
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

    test('refresh race condition discards stale out-of-order responses', () async {
      final handler = DataHandler<String>();
      final completer1 = Completer<String>();
      final completer2 = Completer<String>();

      // Launch request 1 (slow)
      final future1 = handler.refresh(() => completer1.future);

      // Launch request 2 (fast)
      final future2 = handler.refresh(() => completer2.future);

      // Request 2 completes first with 'New Data'
      completer2.complete('New Data');
      await future2;
      expect(handler.data, equals('New Data'));

      // Request 1 completes later with 'Old Data'
      completer1.complete('Old Data');
      await future1;

      // Old data MUST NOT overwrite new data
      expect(handler.data, equals('New Data'));
    });

    test('refresh with debounce delays execution and merges rapid calls', () async {
      final handler = DataHandler<String>();
      int fetchCount = 0;

      handler.refresh(() async {
        fetchCount++;
        return 'Search 1';
      }, debounce: const Duration(milliseconds: 50));

      handler.refresh(() async {
        fetchCount++;
        return 'Search 2';
      }, debounce: const Duration(milliseconds: 50));

      handler.refresh(() async {
        fetchCount++;
        return 'Search Final';
      }, debounce: const Duration(milliseconds: 50));

      expect(fetchCount, equals(0));

      await Future.delayed(const Duration(milliseconds: 100));

      expect(fetchCount, equals(1));
      expect(handler.data, equals('Search Final'));
    });

    test('optimisticUpdate immediately updates and auto-rolls back on failure', () async {
      final handler = DataHandler<int>(10);

      // Successful optimistic action
      await handler.optimisticUpdate(
        11,
        action: () async => 11,
      );
      expect(handler.data, equals(11));

      // Failing optimistic action with auto-rollback
      await handler.optimisticUpdate(
        12,
        action: () async {
          throw Exception('Backend validation error');
        },
        rollbackOnError: true,
      );

      // Should have rolled back to 11
      expect(handler.data, equals(11));
      expect(handler.hasError, isTrue);
      expect(handler.errorMessage, contains('Backend validation error'));
    });

    test('bindStream updates state reactively and cancels on dispose', () async {
      final handler = DataHandler<int>();
      final streamController = StreamController<int>();

      handler.bindStream(streamController.stream);
      expect(handler.isLoading, isTrue);

      streamController.add(100);
      await Future.delayed(Duration.zero);
      expect(handler.hasSuccess, isTrue);
      expect(handler.data, equals(100));

      streamController.addError(Exception('Stream disconnected'));
      await Future.delayed(Duration.zero);
      expect(handler.hasError, isTrue);
      expect(handler.errorMessage, contains('Stream disconnected'));

      handler.dispose();
      expect(handler.isDisposed, isTrue);
      await streamController.close();
    });

    test('Disposed handler safely ignores subsequent callbacks without throwing', () async {
      final handler = DataHandler<String>();
      final completer = Completer<String>();

      final future = handler.refresh(() => completer.future);
      handler.dispose();

      expect(handler.isDisposed, isTrue);

      // Completing after dispose should not throw
      completer.complete('Too late');
      await future;

      expect(handler.data, isNull);
    });
  });

  group('DataHandlerConfig & Team Interceptors', () {
    tearDown(() {
      DataHandlerConfig.resetGlobalWidgets();
    });

    test('Interceptors receive lifecycle events', () {
      final interceptor = _TestInterceptor();
      DataHandlerConfig.addInterceptor(interceptor);

      final handler = DataHandler<String>();
      handler.startLoading();
      expect(interceptor.requestCount, equals(1));
      expect(interceptor.stateChangeCount, equals(1));

      handler.onSuccess('Data');
      expect(interceptor.successCount, equals(1));
      expect(interceptor.stateChangeCount, equals(2));

      handler.onError('Error occurred');
      expect(interceptor.errorCount, equals(1));
      expect(interceptor.stateChangeCount, equals(3));
    });

    test('Global error formatter formats custom exceptions', () {
      DataHandlerConfig.setErrorFormatter((err) {
        return 'CustomFormatted: $err';
      });

      final handler = DataHandler<String>();
      handler.onError(Exception('500 Server'));

      expect(handler.errorMessage, equals('CustomFormatted: Exception: 500 Server'));
    });
  });

  group('DataHandler UI & Selective Rebuilding Tests', () {
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

    testWidgets('maybeWhen falls back to orElse', (tester) async {
      final handler = DataHandler<String>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: handler.maybeWhen(
              onSuccess: (data) => Text('Success: $data'),
              orElse: () => const Text('Fallback State'),
            ),
          ),
        ),
      );

      expect(find.text('Fallback State'), findsOneWidget);

      handler.onSuccess('Success data');
      await tester.pump();
      expect(find.text('Success: Success data'), findsOneWidget);
    });

    testWidgets('select only rebuilds sub-widget when selected field changes', (tester) async {
      final handler = DataHandler<_UserModel>(_UserModel('Alice', 5));
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: handler.select<int>(
              selector: (user) => user.unreadCount,
              builder: (context, unread) {
                buildCount++;
                return Text('Unread: $unread');
              },
            ),
          ),
        ),
      );

      expect(find.text('Unread: 5'), findsOneWidget);
      expect(buildCount, equals(1));

      // Update name only; unreadCount remains 5
      handler.onSuccess(_UserModel('Alice Cooper', 5));
      await tester.pump();

      // buildCount should STILL be 1 because unreadCount didn't change!
      expect(buildCount, equals(1));

      // Update unreadCount to 6
      handler.onSuccess(_UserModel('Alice Cooper', 6));
      await tester.pump();

      // buildCount should now be 2
      expect(buildCount, equals(2));
      expect(find.text('Unread: 6'), findsOneWidget);
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

    test('appendData appends items with minimal allocations', () {
      final listHandler = DataHandler<List<int>>([1, 2]);
      listHandler.appendData([3, 4]);

      expect(listHandler.data, equals([1, 2, 3, 4]));
      expect(listHandler.listLength, equals(4));

      // Appending to empty/null list
      final nullListHandler = DataHandler<List<String>>();
      nullListHandler.appendData(['first', 'second']);
      expect(nullListHandler.data, equals(['first', 'second']));
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
