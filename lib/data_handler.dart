import 'package:flutter/material.dart';

/// Enum to represent different data states in the application
///
/// This enum is used to track the current state of data operations:
/// - [loading]: Data is being fetched or processed
/// - [success]: Data has been successfully loaded
/// - [error]: An error occurred during data loading
/// - [empty]: No data is available or data is empty
enum DataState { loading, success, error, empty }

/// Global configuration singleton for managing default widgets across the app
///
/// This class provides a centralized way to set default loading, error, and empty
/// state widgets that can be used throughout the application. Use this to maintain
/// consistent UI patterns across different screens.
///
/// Example usage:
/// ```dart
/// DataHandlerConfig.setGlobalLoadingWidget(() => CustomLoadingSpinner());
/// DataHandlerConfig.setGlobalErrorWidget((error) => CustomErrorWidget(error));
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

  /// Sets the global loading widget that will be used across all DataHandler instances
  ///
  /// [widget] - Factory function that returns a Widget for loading state
  /// This widget will be displayed whenever data is being fetched
  static void setGlobalLoadingWidget(Widget Function() widget) {
    _instance._globalLoadingWidget = widget;
  }

  /// Sets the global error widget that will be used across all DataHandler instances
  ///
  /// [widget] - Factory function that returns a Widget for error state
  /// The function receives the error message as a parameter
  static void setGlobalErrorWidget(Widget Function(String error) widget) {
    _instance._globalErrorWidget = widget;
  }

  /// Sets the global empty widget that will be used across all DataHandler instances
  ///
  /// [widget] - Factory function that returns a Widget for empty state
  /// The function receives the empty message as a parameter
  static void setGlobalEmptyWidget(Widget Function(String message) widget) {
    _instance._globalEmptyWidget = widget;
  }

  /// Getter for the global loading widget factory function
  Widget Function()? get globalLoadingWidget => _globalLoadingWidget;

  /// Getter for the global error widget factory function
  Widget Function(String error)? get globalErrorWidget => _globalErrorWidget;

  /// Getter for the global empty widget factory function
  Widget Function(String message)? get globalEmptyWidget => _globalEmptyWidget;

  /// Resets all global widgets to null, reverting to default system widgets
  ///
  /// Use this method to clear all custom global widgets and return to
  /// the default loading, error, and empty state widgets
  static void resetGlobalWidgets() {
    _instance._globalLoadingWidget = null;
    _instance._globalErrorWidget = null;
    _instance._globalEmptyWidget = null;
  }

  /// Convenience method to set all global widgets at once
  ///
  /// [loadingWidget] - Optional loading widget factory function
  /// [errorWidget] - Optional error widget factory function
  /// [emptyWidget] - Optional empty widget factory function
  ///
  /// Only non-null parameters will be set, others remain unchanged
  static void setGlobalWidgets({
    Widget Function()? loadingWidget,
    Widget Function(String error)? errorWidget,
    Widget Function(String message)? emptyWidget,
  }) {
    if (loadingWidget != null) setGlobalLoadingWidget(loadingWidget);
    if (errorWidget != null) setGlobalErrorWidget(errorWidget);
    if (emptyWidget != null) setGlobalEmptyWidget(emptyWidget);
  }
}

/// A generic ChangeNotifier class to handle data states with optimized performance
///
/// This class manages the state of data operations (loading, success, error, empty)
/// and provides widgets to display appropriate UI based on the current state.
///
/// Type parameter [T] represents the type of data being managed.
///
/// Example usage:
/// ```dart
/// class UserController extends ChangeNotifier {
///   final DataHandler<List<User>> users = DataHandler<List<User>>();
///
///   Future<void> loadUsers() async {
///     users.startLoading();
///     try {
///       final userList = await userService.getUsers();
///       users.onSuccess(userList);
///     } catch (e) {
///       users.onError(e.toString());
///     }
///   }
/// }
/// ```
class DataHandler<T> extends ChangeNotifier {
  /// Current state of the data operation
  DataState _state;

  /// The actual data being managed
  T? _data;

  /// Error message when state is error, or custom message for empty state
  String _errorMessage = '';

  /// Reference to the global configuration instance
  final DataHandlerConfig _config = DataHandlerConfig();

  /// Creates a new DataHandler instance with optional initial data
  ///
  /// [initialData] - Optional initial data to set. If provided, state will be
  /// set to [DataState.success], otherwise [DataState.empty]
  DataHandler([T? initialData])
    : _state = initialData != null ? DataState.success : DataState.empty,
      _data = initialData;

  /// Gets the current data state
  DataState get state => _state;

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

  /// Sets the state to loading and clears previous data and errors
  ///
  /// This method is optimized to only notify listeners if the state actually changes.
  /// Use this method when starting a data fetch operation.
  void startLoading() {
    if (_state != DataState.loading) {
      _state = DataState.loading;
      _data = null;
      _errorMessage = '';
      notifyListeners();
    }
  }

  /// Sets the state to success with the provided data
  ///
  /// [newData] - The successfully loaded data
  ///
  /// This method is optimized to only notify listeners if the state or data
  /// actually changes, improving performance by avoiding unnecessary rebuilds.
  void onSuccess(T newData) {
    final hasChanged = _state != DataState.success || _data != newData;
    if (hasChanged) {
      _state = DataState.success;
      _data = newData;
      _errorMessage = '';
      notifyListeners();
    }
  }

  /// Sets the state to error with the provided error message
  ///
  /// [errorMessage] - Description of the error that occurred
  ///
  /// This method clears any existing data and is optimized to only notify
  /// listeners if the state or error message actually changes.
  void onError(String errorMessage) {
    if (_state != DataState.error || _errorMessage != errorMessage) {
      _state = DataState.error;
      _data = null;
      _errorMessage = errorMessage;
      notifyListeners();
    }
  }

  /// Sets the state to empty with an optional message
  ///
  /// [message] - Optional message to display in empty state.
  /// Defaults to 'No data available'
  ///
  /// This method clears any existing data and is optimized to only notify
  /// listeners if the state or message actually changes.
  void onEmpty([String message = 'No data available']) {
    if (_state != DataState.empty || _errorMessage != message) {
      _state = DataState.empty;
      _data = null;
      _errorMessage = message;
      notifyListeners();
    }
  }

  /// Builds a widget based on the current data state with high performance
  ///
  /// This is the main method for rendering UI based on data state. It uses
  /// AnimatedBuilder for efficient rebuilds and supports both local and global widgets.
  ///
  /// [onSuccess] - Required callback that returns widget when data is successfully loaded
  /// [onLoading] - Optional callback for loading state widget
  /// [onError] - Optional callback for error state widget (receives error message)
  /// [onEmpty] - Optional callback for empty state widget (receives empty message)
  /// [enabled] - If false and data exists, shows success widget regardless of state
  /// [useGlobalWidgets] - If true, falls back to global widgets when local ones aren't provided
  ///
  /// Returns a Widget that automatically updates when the data state changes.
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

  /// Internal method to build widgets based on current state
  ///
  /// This method handles the logic for determining which widget to show
  /// based on the current state and available widget builders.
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

  /// Helper method to resolve loading widget (local or global fallback)
  ///
  /// Priority order: local widget -> global widget -> default CircularProgressIndicator
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

  /// Helper method to resolve error widget (local or global fallback)
  ///
  /// Priority order: local widget -> global widget -> default Text widget
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

  /// Helper method to resolve empty widget (local or global fallback)
  ///
  /// Priority order: local widget -> global widget -> default Text widget
  Widget _getEmptyWidget(
    Widget Function(String message)? onEmpty,
    bool useGlobalWidgets,
  ) {
    if (onEmpty != null) {
      return onEmpty(_errorMessage);
    }
    if (useGlobalWidgets && _config.globalEmptyWidget != null) {
      return _config.globalEmptyWidget!(
        _errorMessage.isEmpty ? 'No data available' : _errorMessage,
      );
    }
    return Center(
      child: Text(_errorMessage.isEmpty ? 'No data available' : _errorMessage),
    );
  }

  /// Builds a SliverList widget based on the current data state
  ///
  /// This method is optimized for use in CustomScrollView and similar widgets
  /// that require Sliver widgets. It handles all data states appropriately.
  ///
  /// [itemBuilder] - Required callback to build individual list items
  /// [itemCount] - Required callback to determine the number of items in the data
  /// [onLoading] - Optional callback for loading state widget
  /// [onError] - Optional callback for error state widget
  /// [onEmpty] - Optional callback for empty state widget
  /// [enabled] - If false and data exists, shows list regardless of state
  /// [useGlobalWidgets] - If true, falls back to global widgets when local ones aren't provided
  ///
  /// Returns a Sliver widget that automatically updates when the data state changes.
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

  /// Updates the data without triggering a loading state
  ///
  /// [newData] - The new data to set
  ///
  /// Use this method when you want to update the data directly without
  /// showing a loading state. This is useful for real-time updates or
  /// when appending data to existing data.
  ///
  /// Note: The equality check used in this method relies on proper equality
  /// behavior for type [T]. If [T] is a custom type, ensure that it overrides
  /// the equality operator (`==`) and hashCode for meaningful comparisons.
  void updateData(T newData) {
    if (_data != newData) {
      _data = newData;
      _state = DataState.success;
      notifyListeners();
    }
  }

  /// Refreshes data by calling the provided async function
  ///
  /// [dataFetcher] - Async function that returns the new data
  ///
  /// This method automatically handles the loading state and error handling.
  /// It's a convenient way to refresh data with proper state management.
  ///
  /// Example usage:
  /// ```dart
  /// await userHandler.refresh(() => userService.getUsers());
  /// ```
  Future<void> refresh(Future<T> Function() dataFetcher) async {
    startLoading();
    try {
      final newData = await dataFetcher();
      onSuccess(newData);
    } catch (e) {
      onError(e.toString());
    }
  }

  /// Clears all data and resets to empty state
  ///
  /// This method removes all data, clears error messages, and sets the
  /// state to empty. Use this when you want to reset the handler to
  /// its initial empty state.
  void clear() {
    _state = DataState.empty;
    _data = null;
    _errorMessage = '';
    notifyListeners();
  }

  /// Disposes of resources and clears data
  ///
  /// This method is called automatically when the DataHandler is disposed.
  /// It clears the data reference to help with garbage collection.
  @override
  void dispose() {
    _data = null;
    super.dispose();
  }
}

/// Extension for enhanced list handling capabilities
///
/// This extension provides additional methods and properties specifically
/// designed for working with DataHandler instances that manage List data.
///
/// Example usage:
/// ```dart
/// final DataHandler<List<String>> names = DataHandler<List<String>>();
///
/// Widget build(BuildContext context) {
///   return names.whenList(
///     onSuccess: (list) => ListView.builder(...),
///     onEmptyList: () => Text('No names available'),
///   );
/// }
/// ```
extension DataHandlerList<T extends List> on DataHandler<T> {
  /// Returns true if the list data is null or empty
  bool get isListEmpty => _data?.isEmpty ?? true;

  /// Returns the length of the list data, or 0 if null
  int get listLength => _data?.length ?? 0;

  /// Builds a widget specifically designed for list data with empty list handling
  ///
  /// This method extends the basic [when] method with special handling for empty lists.
  /// It will show the empty list widget even when the state is success but the list is empty.
  ///
  /// [onSuccess] - Required callback for when list has data
  /// [onLoading] - Optional callback for loading state
  /// [onError] - Optional callback for error state
  /// [onEmptyList] - Optional callback for when list is empty (overrides onEmpty)
  /// [enabled] - If false and data exists, shows success widget regardless of state
  /// [useGlobalWidgets] - If true, falls back to global widgets when local ones aren't provided
  ///
  /// Returns a Widget that automatically handles empty list cases.
  Widget whenList({
    required Widget Function(T data) onSuccess,
    Widget Function()? onLoading,
    Widget Function(String error)? onError,
    Widget Function(String message)? onEmptyList,
    bool enabled = true,
    bool useGlobalWidgets = true,
  }) {
    return when(
      enabled: enabled,
      useGlobalWidgets: useGlobalWidgets,
      onSuccess: (data) {
        return onSuccess(data);
      },
      onLoading: onLoading,
      onError: onError,
      onEmpty:
          (message) =>
              onEmptyList?.call(message) ?? Center(child: Text(message)),
    );
  }
}
