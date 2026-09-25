import 'dart:async';
import 'package:flutter/material.dart';

/// Enum to represent different data states in the application
///
/// This enum is used to track the current state of data operations:
/// - [loading]: Data is being fetched or processed
/// - [success]: Data has been successfully loaded
/// - [error]: An error occurred during data loading
/// - [empty]: No data is available or data is empty
enum DataState { loading, success, error, empty }

/// Interceptor interface for cross-cutting concerns across all DataHandler instances.
///
/// Implement this to inject app-wide behavior such as:
/// - Analytics / performance tracking
/// - Automatic authentication handling (e.g. redirect on 401 Unauthorized)
/// - Centralized debug logging and diagnostics
abstract class DataHandlerInterceptor {
  /// Called when a data operation starts loading
  void onRequest(DataHandler handler) {}

  /// Called when a data operation succeeds with [data]
  void onSuccess(DataHandler handler, dynamic data) {}

  /// Called when an error occurs during data handling
  void onError(DataHandler handler, dynamic error) {}

  /// Called whenever a DataHandler transitions from [oldState] to [newState]
  void onStateChanged(
    DataHandler handler,
    DataState oldState,
    DataState newState,
  ) {}
}

/// Global configuration singleton for managing default widgets and team policies across the app
///
/// This class provides a centralized way to set default loading, error, and empty
/// state widgets, centralized error formatting, and global interceptors that can be used
/// throughout the application.
///
/// Example usage:
/// ```dart
/// DataHandlerConfig.setGlobalLoadingWidget(() => const CustomLoadingSpinner());
/// DataHandlerConfig.setGlobalErrorWidget((error) => CustomErrorWidget(error));
/// DataHandlerConfig.setErrorFormatter((error) => 'Friendly error: $error');
/// DataHandlerConfig.addInterceptor(MyLoggingInterceptor());
/// ```
class DataHandlerConfig {
  static final DataHandlerConfig _instance = DataHandlerConfig._internal();
  factory DataHandlerConfig() => _instance;
  DataHandlerConfig._internal();

  /// Global default loading widget factory function
  Widget Function()? _globalLoadingWidget;

  /// Global default error widget factory function that receives error message
  Widget Function(String error)? _globalErrorWidget;

  /// Global default empty state widget factory function that receives message
  Widget Function(String message)? _globalEmptyWidget;

  /// Global error formatter converting arbitrary exceptions to user-friendly messages
  String Function(Object error)? _globalErrorFormatter;

  /// List of registered global interceptors
  final List<DataHandlerInterceptor> _interceptors = [];

  /// Sets the global loading widget that will be used across all DataHandler instances
  static void setGlobalLoadingWidget(Widget Function() widget) {
    _instance._globalLoadingWidget = widget;
  }

  /// Sets the global error widget that will be used across all DataHandler instances
  static void setGlobalErrorWidget(Widget Function(String error) widget) {
    _instance._globalErrorWidget = widget;
  }

  /// Sets the global empty widget that will be used across all DataHandler instances
  static void setGlobalEmptyWidget(Widget Function(String message) widget) {
    _instance._globalEmptyWidget = widget;
  }

  /// Sets the global error formatter to standardize error messages across all handlers
  static void setErrorFormatter(String Function(Object error) formatter) {
    _instance._globalErrorFormatter = formatter;
  }

  /// Adds a global interceptor for logging, analytics, or error handling
  static void addInterceptor(DataHandlerInterceptor interceptor) {
    if (!_instance._interceptors.contains(interceptor)) {
      _instance._interceptors.add(interceptor);
    }
  }

  /// Removes a previously registered global interceptor
  static void removeInterceptor(DataHandlerInterceptor interceptor) {
    _instance._interceptors.remove(interceptor);
  }

  /// Clears all registered global interceptors
  static void clearInterceptors() {
    _instance._interceptors.clear();
  }

  /// Getter for the global loading widget factory function
  Widget Function()? get globalLoadingWidget => _globalLoadingWidget;

  /// Getter for the global error widget factory function
  Widget Function(String error)? get globalErrorWidget => _globalErrorWidget;

  /// Getter for the global empty widget factory function
  Widget Function(String message)? get globalEmptyWidget => _globalEmptyWidget;

  /// Getter for the global error formatter
  String Function(Object error)? get globalErrorFormatter =>
      _globalErrorFormatter;

  /// Unmodifiable view of registered interceptors
  List<DataHandlerInterceptor> get interceptors =>
      List.unmodifiable(_interceptors);

  /// Formats an error using the registered global formatter, or falls back to toString()
  String formatError(Object error) {
    if (_globalErrorFormatter != null) {
      try {
        return _globalErrorFormatter!(error);
      } catch (_) {
        return error.toString();
      }
    }
    return error.toString();
  }

  /// Resets all global widgets and policies to defaults
  static void resetGlobalWidgets() {
    _instance._globalLoadingWidget = null;
    _instance._globalErrorWidget = null;
    _instance._globalEmptyWidget = null;
    _instance._globalErrorFormatter = null;
    _instance._interceptors.clear();
  }

  /// Convenience method to set all global widgets at once
  static void setGlobalWidgets({
    Widget Function()? loadingWidget,
    Widget Function(String error)? errorWidget,
    Widget Function(String message)? emptyWidget,
    String Function(Object error)? errorFormatter,
  }) {
    if (loadingWidget != null) setGlobalLoadingWidget(loadingWidget);
    if (errorWidget != null) setGlobalErrorWidget(errorWidget);
    if (emptyWidget != null) setGlobalEmptyWidget(emptyWidget);
    if (errorFormatter != null) setErrorFormatter(errorFormatter);
  }
}

/// A generic ChangeNotifier class to handle data states with ultra-low memory consumption
/// and high performance.
///
/// This class manages the state of data operations (loading, success, error, empty)
/// with race-condition prevention, debouncing, optimistic updates, stream binding,
/// and selective widget rebuilding.
///
/// Type parameter [T] represents the type of data being managed.
class DataHandler<T> extends ChangeNotifier {
  /// Current state of the data operation
  DataState _state;

  /// The actual data being managed
  T? _data;

  /// Error message when state is error, or custom message for empty state
  String _errorMessage = '';

  /// Reference to the global configuration instance
  final DataHandlerConfig _config = DataHandlerConfig();

  /// Generation counter to discard stale async requests and race conditions
  int _currentFetchId = 0;

  /// Timer for debounced refresh calls
  Timer? _debounceTimer;

  /// Active stream subscription when bound to a real-time stream
  StreamSubscription<T>? _streamSubscription;

  /// Tracks if this handler has been disposed to eliminate memory leaks and errors
  bool _isDisposed = false;

  /// Creates a new DataHandler instance with optional initial data
  DataHandler([T? initialData])
    : _state = initialData != null ? DataState.success : DataState.empty,
      _data = initialData;

  /// Gets the current data state
  DataState get state => _state;

  /// Returns true if this handler has been disposed
  bool get isDisposed => _isDisposed;

  /// Returns true if data is currently being loaded
  bool get isLoading => _state == DataState.loading;

  /// Returns true if an error occurred during data loading
  bool get hasError => _state == DataState.error;

  /// Returns true if data was successfully loaded and is not null
  bool get hasSuccess => _state == DataState.success && _data != null;

  /// Returns true if no data is available (empty state)
  bool get isEmpty => _state == DataState.empty;

  /// Gets the current data (may be null)
  T? get data => _data;

  /// Gets the current error message or empty state message
  String get errorMessage => _errorMessage;

  @override
  void notifyListeners() {
    if (!_isDisposed && hasListeners) {
      super.notifyListeners();
    }
  }

  /// Internal helper to notify listeners and trigger interceptor state changes
  void _notifyStateChange(DataState oldState, DataState newState) {
    for (final interceptor in _config.interceptors) {
      interceptor.onStateChanged(this, oldState, newState);
    }
    notifyListeners();
  }

  /// Sets the state to loading.
  ///
  /// Set [preserveData] to true to keep existing data in memory and on screen
  /// during background refreshes or pull-to-refresh (avoiding screen flicker and re-allocations).
  void startLoading({bool preserveData = false}) {
    if (_isDisposed) return;
    if (_state != DataState.loading) {
      final oldState = _state;
      _state = DataState.loading;
      if (!preserveData) {
        _data = null;
      }
      _errorMessage = '';
      for (final interceptor in _config.interceptors) {
        interceptor.onRequest(this);
      }
      _notifyStateChange(oldState, DataState.loading);
    } else if (!preserveData && _data != null) {
      _data = null;
      notifyListeners();
    }
  }

  /// Sets the state to success with the provided data.
  ///
  /// Optimized to only notify listeners if the state or data actually changes.
  void onSuccess(T newData) {
    if (_isDisposed) return;
    final hasChanged = _state != DataState.success || _data != newData;
    if (hasChanged) {
      final oldState = _state;
      _state = DataState.success;
      _data = newData;
      _errorMessage = '';
      for (final interceptor in _config.interceptors) {
        interceptor.onSuccess(this, newData);
      }
      _notifyStateChange(oldState, DataState.success);
    }
  }

  /// Sets the state to error with the provided error.
  ///
  /// Accepts either a [String] message or an [Object] exception.
  /// Automatically applies the global error formatter from [DataHandlerConfig].
  /// Set [preserveData] to true to retain existing data (e.g. during optimistic rollback).
  void onError(dynamic error, {bool preserveData = false}) {
    if (_isDisposed) return;
    final formattedMessage =
        error is String
            ? error
            : (error is Object
                ? _config.formatError(error)
                : error?.toString() ?? 'Unknown error');

    if (_state != DataState.error || _errorMessage != formattedMessage) {
      final oldState = _state;
      _state = DataState.error;
      if (!preserveData) {
        _data = null;
      }
      _errorMessage = formattedMessage;
      for (final interceptor in _config.interceptors) {
        interceptor.onError(this, error);
      }
      _notifyStateChange(oldState, DataState.error);
    }
  }

  /// Sets the state to empty with an optional message.
  void onEmpty([String message = 'No data available']) {
    if (_isDisposed) return;
    if (_state != DataState.empty || _errorMessage != message) {
      final oldState = _state;
      _state = DataState.empty;
      _data = null;
      _errorMessage = message;
      _notifyStateChange(oldState, DataState.empty);
    }
  }

  /// Refreshes data by calling the provided async [dataFetcher].
  ///
  /// - [preserveData]: If true, retains current data during loading (soft refresh).
  /// - [debounce]: Optional duration to debounce rapid consecutive calls (e.g. search input).
  /// - Automatically cancels/discards stale responses if multiple calls are made.
  /// - Guaranteed memory-safe: will not throw if disposed during execution.
  Future<void> refresh(
    Future<T> Function() dataFetcher, {
    bool preserveData = false,
    Duration? debounce,
  }) async {
    if (_isDisposed) return;

    if (debounce != null) {
      _debounceTimer?.cancel();
      final completer = Completer<void>();
      final fetchId = ++_currentFetchId;

      _debounceTimer = Timer(debounce, () async {
        if (_isDisposed || fetchId != _currentFetchId) {
          completer.complete();
          return;
        }
        await _executeFetch(dataFetcher, fetchId, preserveData: preserveData);
        if (!completer.isCompleted) completer.complete();
      });
      return completer.future;
    }

    final fetchId = ++_currentFetchId;
    await _executeFetch(dataFetcher, fetchId, preserveData: preserveData);
  }

  Future<void> _executeFetch(
    Future<T> Function() dataFetcher,
    int fetchId, {
    required bool preserveData,
  }) async {
    startLoading(preserveData: preserveData);
    try {
      final newData = await dataFetcher();
      if (_isDisposed || fetchId != _currentFetchId) return;
      onSuccess(newData);
    } catch (e) {
      if (_isDisposed || fetchId != _currentFetchId) return;
      onError(e);
    }
  }

  /// Optimistically updates data in the UI immediately, then runs [action].
  ///
  /// If [action] throws an error and [rollbackOnError] is true, the handler
  /// automatically rolls back to its prior data and state before reporting the error.
  Future<void> optimisticUpdate(
    T optimisticData, {
    required Future<T> Function() action,
    bool rollbackOnError = true,
  }) async {
    if (_isDisposed) return;

    final previousData = _data;
    final previousState = _state;
    final previousError = _errorMessage;
    final fetchId = ++_currentFetchId;

    updateData(optimisticData);

    try {
      final serverData = await action();
      if (_isDisposed || fetchId != _currentFetchId) return;
      onSuccess(serverData);
    } catch (e) {
      if (_isDisposed || fetchId != _currentFetchId) return;
      if (rollbackOnError) {
        _data = previousData;
        _state = previousState;
        _errorMessage = previousError;
        onError(e, preserveData: true);
      } else {
        onError(e);
      }
    }
  }

  /// Binds this handler directly to a real-time [stream] (e.g. WebSockets, Firebase, Supabase).
  ///
  /// Automatically manages subscription lifecycle, updates states on events/errors,
  /// and automatically cancels the subscription upon [dispose].
  void bindStream(
    Stream<T> stream, {
    bool cancelOnError = false,
    String Function(dynamic error)? errorFormatter,
  }) {
    if (_isDisposed) return;
    _streamSubscription?.cancel();
    startLoading();

    _streamSubscription = stream.listen(
      (newData) {
        if (!_isDisposed) onSuccess(newData);
      },
      onError: (err) {
        if (!_isDisposed) {
          final msg =
              errorFormatter != null
                  ? errorFormatter(err)
                  : (err is Object
                      ? _config.formatError(err)
                      : err?.toString() ?? 'Stream error');
          onError(msg);
        }
      },
      cancelOnError: cancelOnError,
    );
  }

  /// Updates the data directly without triggering a loading state.
  void updateData(T newData) {
    if (_isDisposed) return;
    if (_data != newData) {
      final oldState = _state;
      _data = newData;
      _state = DataState.success;
      _errorMessage = '';
      _notifyStateChange(oldState, DataState.success);
    }
  }

  /// Builds a widget based on the current data state.
  Widget when({
    required Widget Function(T data) onSuccess,
    Widget Function()? onLoading,
    Widget Function(String error)? onError,
    Widget Function(String message)? onEmpty,
    bool enabled = true,
    bool useGlobalWidgets = true,
  }) {
    if (!enabled && _data != null) {
      return onSuccess(_data as T);
    }

    return AnimatedBuilder(
      animation: this,
      builder:
          (context, _) => _buildStateWidget(
            onSuccess: onSuccess,
            onLoading: onLoading,
            onError: onError,
            onEmpty: onEmpty,
            useGlobalWidgets: useGlobalWidgets,
          ),
    );
  }

  /// Flexible builder that requires only desired states, falling back to [orElse].
  Widget maybeWhen({
    Widget Function(T data)? onSuccess,
    Widget Function()? onLoading,
    Widget Function(String error)? onError,
    Widget Function(String message)? onEmpty,
    required Widget Function() orElse,
    bool enabled = true,
    bool useGlobalWidgets = true,
  }) {
    return when(
      enabled: enabled,
      useGlobalWidgets: useGlobalWidgets,
      onSuccess: (data) => onSuccess != null ? onSuccess(data) : orElse(),
      onLoading:
          onLoading ?? () => _config.globalLoadingWidget?.call() ?? orElse(),
      onError:
          onError ??
          (err) => _config.globalErrorWidget?.call(err) ?? orElse(),
      onEmpty:
          onEmpty ??
          (msg) => _config.globalEmptyWidget?.call(msg) ?? orElse(),
    );
  }

  /// Granular selector that only rebuilds its sub-widget when the [selector] value changes.
  ///
  /// This drastically reduces CPU and RAM consumption for large or complex data models [T],
  /// since the surrounding widget tree is not rebuilt when unrelated fields mutate.
  Widget select<R>({
    required R Function(T data) selector,
    required Widget Function(BuildContext context, R value) builder,
    Widget Function()? onLoading,
    Widget Function(String error)? onError,
    Widget Function(String message)? onEmpty,
    bool useGlobalWidgets = true,
  }) {
    return _SelectedDataWidget<T, R>(
      handler: this,
      selector: selector,
      builder: builder,
      onLoading: onLoading,
      onError: onError,
      onEmpty: onEmpty,
      useGlobalWidgets: useGlobalWidgets,
    );
  }

  /// Builds a SliverList widget based on the current data state.
  Widget whenSliverList({
    required Widget Function(T data, int index) itemBuilder,
    required int Function(T data) itemCount,
    Widget Function()? onLoading,
    Widget Function(String error)? onError,
    Widget Function(String message)? onEmpty,
    bool enabled = true,
    bool useGlobalWidgets = true,
  }) {
    if (!enabled && _data != null) {
      final count = itemCount(_data as T);
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => itemBuilder(_data as T, index),
          childCount: count,
        ),
      );
    }

    return AnimatedBuilder(
      animation: this,
      builder: (context, _) {
        switch (_state) {
          case DataState.loading:
            return SliverToBoxAdapter(
              child: _getLoadingWidget(onLoading, useGlobalWidgets),
            );

          case DataState.success:
            if (_data != null) {
              final count = itemCount(_data as T);
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => itemBuilder(_data as T, index),
                  childCount: count,
                ),
              );
            }
            return const SliverToBoxAdapter(child: SizedBox.shrink());

          case DataState.error:
            return SliverToBoxAdapter(
              child: _getErrorWidget(onError, useGlobalWidgets),
            );

          case DataState.empty:
            return SliverToBoxAdapter(
              child: _getEmptyWidget(onEmpty, useGlobalWidgets),
            );
        }
      },
    );
  }

  Widget _buildStateWidget({
    required Widget Function(T data) onSuccess,
    Widget Function()? onLoading,
    Widget Function(String error)? onError,
    Widget Function(String message)? onEmpty,
    bool useGlobalWidgets = true,
  }) {
    switch (_state) {
      case DataState.loading:
        return _getLoadingWidget(onLoading, useGlobalWidgets);

      case DataState.success:
        return _data != null ? onSuccess(_data as T) : const SizedBox.shrink();

      case DataState.error:
        return _getErrorWidget(onError, useGlobalWidgets);

      case DataState.empty:
        return _getEmptyWidget(onEmpty, useGlobalWidgets);
    }
  }

  Widget _getLoadingWidget(
    Widget Function()? onLoading,
    bool useGlobalWidgets,
  ) {
    if (onLoading != null) {
      return onLoading();
    }
    if (useGlobalWidgets && _config.globalLoadingWidget != null) {
      return _config.globalLoadingWidget!();
    }
    return const Center(child: CircularProgressIndicator());
  }

  Widget _getErrorWidget(
    Widget Function(String error)? onError,
    bool useGlobalWidgets,
  ) {
    if (onError != null) {
      return onError(_errorMessage);
    }
    if (useGlobalWidgets && _config.globalErrorWidget != null) {
      return _config.globalErrorWidget!(_errorMessage);
    }
    return Center(child: Text('Error: $_errorMessage'));
  }

  Widget _getEmptyWidget(
    Widget Function(String message)? onEmpty,
    bool useGlobalWidgets,
  ) {
    final message = _errorMessage.isEmpty ? 'No data available' : _errorMessage;
    if (onEmpty != null) {
      return onEmpty(message);
    }
    if (useGlobalWidgets && _config.globalEmptyWidget != null) {
      return _config.globalEmptyWidget!(message);
    }
    return Center(child: Text(message));
  }

  /// Clears all data, timers, and resets to empty state.
  void clear() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _state = DataState.empty;
    _data = null;
    _errorMessage = '';
    notifyListeners();
  }

  /// Disposes resources, cancels timers and stream subscriptions, and frees memory.
  @override
  void dispose() {
    _isDisposed = true;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _data = null;
    _errorMessage = '';
    super.dispose();
  }
}

/// Private helper widget implementing selective micro-rebuilds
class _SelectedDataWidget<T, R> extends StatefulWidget {
  final DataHandler<T> handler;
  final R Function(T data) selector;
  final Widget Function(BuildContext context, R value) builder;
  final Widget Function()? onLoading;
  final Widget Function(String error)? onError;
  final Widget Function(String message)? onEmpty;
  final bool useGlobalWidgets;

  const _SelectedDataWidget({
    super.key,
    required this.handler,
    required this.selector,
    required this.builder,
    this.onLoading,
    this.onError,
    this.onEmpty,
    this.useGlobalWidgets = true,
  });

  @override
  State<_SelectedDataWidget<T, R>> createState() =>
      _SelectedDataWidgetState<T, R>();
}

class _SelectedDataWidgetState<T, R> extends State<_SelectedDataWidget<T, R>> {
  DataState? _lastState;
  R? _lastSelectedValue;

  @override
  void initState() {
    super.initState();
    _lastState = widget.handler.state;
    if (widget.handler.data != null) {
      _lastSelectedValue = widget.selector(widget.handler.data as T);
    }
    widget.handler.addListener(_handleUpdate);
  }

  @override
  void didUpdateWidget(covariant _SelectedDataWidget<T, R> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.handler != widget.handler) {
      oldWidget.handler.removeListener(_handleUpdate);
      widget.handler.addListener(_handleUpdate);
      _lastState = widget.handler.state;
      if (widget.handler.data != null) {
        _lastSelectedValue = widget.selector(widget.handler.data as T);
      }
    }
  }

  void _handleUpdate() {
    if (!mounted) return;
    final currentState = widget.handler.state;
    if (currentState != _lastState) {
      _lastState = currentState;
      if (widget.handler.data != null) {
        _lastSelectedValue = widget.selector(widget.handler.data as T);
      }
      setState(() {});
    } else if (currentState == DataState.success &&
        widget.handler.data != null) {
      final newSelectedValue = widget.selector(widget.handler.data as T);
      if (_lastSelectedValue != newSelectedValue) {
        _lastSelectedValue = newSelectedValue;
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    widget.handler.removeListener(_handleUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.handler.state) {
      case DataState.loading:
        return widget.handler._getLoadingWidget(
          widget.onLoading,
          widget.useGlobalWidgets,
        );
      case DataState.success:
        if (widget.handler.data != null) {
          return widget.builder(context, _lastSelectedValue as R);
        }
        return const SizedBox.shrink();
      case DataState.error:
        return widget.handler._getErrorWidget(
          widget.onError,
          widget.useGlobalWidgets,
        );
      case DataState.empty:
        return widget.handler._getEmptyWidget(
          widget.onEmpty,
          widget.useGlobalWidgets,
        );
    }
  }
}

/// Extension for enhanced list handling capabilities
extension DataHandlerList<E> on DataHandler<List<E>> {
  /// Returns true if the list data is null or empty
  bool get isListEmpty => _data?.isEmpty ?? true;

  /// Returns the length of the list data, or 0 if null
  int get listLength => _data?.length ?? 0;

  /// Appends [items] to the existing list with minimal allocation overhead.
  ///
  /// Ideal for low-memory infinite pagination.
  void appendData(Iterable<E> items) {
    if (items.isEmpty) return;
    final currentList = _data;
    if (currentList == null) {
      onSuccess(items.toList());
    } else {
      onSuccess([...currentList, ...items]);
    }
  }

  /// Builds a widget specifically designed for list data with empty list handling.
  Widget whenList({
    required Widget Function(List<E> data) onSuccess,
    Widget Function()? onLoading,
    Widget Function(String error)? onError,
    Widget Function(String message)? onEmptyList,
    bool enabled = true,
    bool useGlobalWidgets = true,
  }) {
    return when(
      enabled: enabled,
      useGlobalWidgets: useGlobalWidgets,
      onSuccess: (data) => onSuccess(data),
      onLoading: onLoading,
      onError: onError,
      onEmpty:
          (message) =>
              onEmptyList?.call(message) ?? Center(child: Text(message)),
    );
  }
}
