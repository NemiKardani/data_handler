import 'package:data_handler/data_handler.dart';
import 'package:flutter/foundation.dart';

/// Interceptor event model for visualizing interceptor calls in the example UI
class InterceptorLog {
  final DateTime timestamp;
  final String eventType;
  final String message;
  final DataState? state;

  InterceptorLog({
    required this.timestamp,
    required this.eventType,
    required this.message,
    this.state,
  });
}

/// Global interceptor demonstrating enterprise team tooling and diagnostics.
class AppLoggingInterceptor extends DataHandlerInterceptor {
  static final AppLoggingInterceptor instance = AppLoggingInterceptor._internal();
  factory AppLoggingInterceptor() => instance;
  AppLoggingInterceptor._internal();

  final ValueNotifier<List<InterceptorLog>> logsNotifier =
      ValueNotifier<List<InterceptorLog>>([]);

  void _addLog(String eventType, String message, [DataState? state]) {
    final entry = InterceptorLog(
      timestamp: DateTime.now(),
      eventType: eventType,
      message: message,
      state: state,
    );
    final updated = [entry, ...logsNotifier.value];
    if (updated.length > 80) {
      updated.removeLast();
    }
    logsNotifier.value = updated;
    debugPrint('⚡ [DataHandlerInterceptor] $eventType: $message');
  }

  @override
  void onRequest(DataHandler handler) {
    _addLog('onRequest', 'Handler started loading (current state: ${handler.state.name})', handler.state);
  }

  @override
  void onSuccess(DataHandler handler, dynamic data) {
    final info = data is List ? '${data.length} items' : data.runtimeType.toString();
    _addLog('onSuccess', 'Handler succeeded with $info', DataState.success);
  }

  @override
  void onError(DataHandler handler, dynamic error) {
    _addLog('onError', 'Handler encountered error: $error', DataState.error);
  }

  @override
  void onStateChanged(DataHandler handler, DataState oldState, DataState newState) {
    _addLog('onStateChanged', 'Transitioned: ${oldState.name} ➔ ${newState.name}', newState);
  }

  void clearLogs() {
    logsNotifier.value = [];
  }
}
