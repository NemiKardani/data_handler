import 'package:flutter/material.dart';

/// A generic ChangeNotifier class to handle data states (loading, success, error, empty).
class DataHandler<T> extends ChangeNotifier {
  // Private variables to track the state of the data.
  bool _isLoading = true;
  bool _hasError = false;
  bool _hasEmpty = false;
  T? _data;
  String _error = '';
  String _emptyError = '';

  /// Constructor to initialize the DataHandler with optional initial data.
  DataHandler([T? data]) {
    if (data != null) {
      _data = data;
      _hasEmpty = false;
      _isLoading = true;
      _hasError = false;
      _error = '';
      _emptyError = '';
    } else {
      _hasEmpty = true;
      _isLoading = false;
      _hasError = false;
      _data = null;
      _error = '';
      _emptyError = '';
    }
  }

  // Getters to access private variables.
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  bool get hasEmpty => _hasEmpty;
  T? get data => _data;
  String get error => _error;
  String get emptyError => _emptyError;

  /// Method to start the loading state.
  void startLoading() {
    _isLoading = true;
    _hasError = false;
    _hasEmpty = false;
    _data = null;
    _error = '';
    _emptyError = '';
    notifyListeners();
  }

  /// Method to handle successful data fetch.
  void onSuccess(T newData) {
    _isLoading = false;
    _hasError = false;
    _hasEmpty = false;
    _data = newData;
    _error = '';
    _emptyError = '';
    notifyListeners();
  }

  /// Method to handle errors during data fetch.
  void onError(String errorMessage) {
    _isLoading = false;
    _hasError = true;
    _hasEmpty = false;
    _data = null;
    _error = errorMessage;
    _emptyError = '';
    notifyListeners();
  }

  /// Method to handle empty data state.
  void onEmpty(String errorMessage, {bool hasError = true}) {
    _isLoading = false;
    _hasEmpty = true;
    _hasError = hasError;
    _data = null;
    _error = errorMessage;
    _emptyError = errorMessage;
    notifyListeners();
  }

  /// A builder method to handle different states (loading, success, error, empty).
  Widget when({
    required BuildContext context,
    Widget Function(BuildContext)? loadingBuilder,
    required Widget Function(T) successBuilder,
    Widget Function(String)? errorBuilder,
    Widget Function(String)? emptyBuilder,
    Color? progressIndicatorColor,
    Widget? progressIndicator,
    Widget? errorWidget,
    Widget? emptyWidget,
    TextStyle? errorStyle,
    TextStyle? emptyStyle,
    bool isEnabled = true,
  }) {
    if (!isEnabled) {
      return successBuilder(_data as T);
    }

    return ListenableBuilder(
      listenable: this,
      builder: (context, child) {
        if (_isLoading) {
          return loadingBuilder?.call(context) ??
              Center(
                child: progressIndicator ??
                    CircularProgressIndicator(
                      color: progressIndicatorColor,
                    ),
              );
        } else if (_hasError) {
          return errorBuilder?.call(_error) ??
              errorWidget ??
              Center(
                child: Text(
                  _error,
                  style: errorStyle,
                ),
              );
        } else if (_data != null) {
          return successBuilder(_data as T);
        } else if (_hasEmpty) {
          return emptyBuilder?.call(_emptyError) ??
              emptyWidget ??
              Center(
                child: Text(
                  _emptyError,
                  style: emptyStyle,
                ),
              );
        } else {
          return child ?? const SizedBox(); // Default widget for unknown state.
        }
      },
    );
  }

  /// A builder method to handle different states and return a list of widgets.
List<Widget> whenList({
  required BuildContext context,
  Widget Function(BuildContext)? loadingBuilder,
  required List<Widget> Function(T) successBuilder,
  Widget Function(String)? errorBuilder,
  Widget Function(String)? emptyBuilder,
  Color? progressIndicatorColor,
  Widget? progressIndicator,
  Widget? errorWidget,
  Widget? emptyWidget,
  TextStyle? errorStyle,
  TextStyle? emptyStyle,
  bool isEnabled = true,
}) {
  if (!isEnabled) {
    return successBuilder(_data as T);
  }

  return [
    ListenableBuilder(
      listenable: this,
      builder: (context, child) {
        if (_isLoading) {
          return loadingBuilder?.call(context) ??
              Center(
                child: progressIndicator ??
                    CircularProgressIndicator(
                      color: progressIndicatorColor,
                    ),
              );
        } else if (_hasError) {
          return errorBuilder?.call(_error) ??
              errorWidget ??
              Center(
                child: Text(
                  _error,
                  style: errorStyle,
                ),
              );
        } else if (_data != null) {
          return Column(
            children: successBuilder(_data as T),
          );
        } else if (_hasEmpty) {
          return emptyBuilder?.call(_emptyError) ??
              emptyWidget ??
              Center(
                child: Text(
                  _emptyError,
                  style: emptyStyle,
                ),
              );
        } else {
          return child ?? const SizedBox(); // Default widget for unknown state.
        }
      },
    ),
  ];
}
}