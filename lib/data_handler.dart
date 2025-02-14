import 'package:flutter/material.dart';

class DataHandler<T> {
  late bool _isLoading;
  late bool _hasError;
  late bool _hasEmpty;
  late T? _data;
  late String _error;
  late String _emptyError;

  DataHandler([T? data]) {
    if (data != null) {
      _data = data;
      _hasEmpty = false;
      _isLoading = false;
      _hasError = false;
      _data = null;
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

  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  T? get data => _data;
  String get error => _error;
  String get empty => _emptyError;

  void startLoading() {
    _isLoading = true;
    _hasError = false;
    _data = null;
    _error = '';
  }

  void onSuccess(T newData) {
    _isLoading = false;
    _hasError = false;
    _data = newData;
    _error = '';
  }

  void onError(String errorMessage) {
    _isLoading = false;
    _hasError = true;
    _data = null;
    _error = errorMessage;
  }

  void onEmpty(String errorMessage, {bool hasError = true}) {
    _isLoading = false;
    _hasEmpty = hasError;
    _hasError = false;
    _data = null;
    _error = errorMessage;
    _emptyError = errorMessage;
  }

  Widget when({
    required BuildContext context,
    Widget Function(BuildContext)? loadingBuilder,
    required Widget Function(T) successBuilder,
    Widget Function(String)? errorBuilder,
    Widget Function(String)? emptyBuilder,
  }) {
    if (_isLoading) {
      return loadingBuilder?.call(context) ??
          Center(
            child: CircularProgressIndicator(),
          );
    } else if (_hasError) {
      return errorBuilder?.call(_error) ?? Text(_error);
    } else if (_data != null) {
      return successBuilder.call(_data as T);
    } else if (_hasEmpty) {
      return emptyBuilder?.call(_emptyError) ?? Text(_emptyError);
    } else {
      return const Text(
          'No data found'); // You can return a default widget for empty state
    }
  }

  List<Widget> whenListWidget({
    required BuildContext context,
    Widget Function(BuildContext)? loadingBuilder,
    required List<Widget> Function(T) successBuilder,
    Widget Function(String)? errorBuilder,
    Widget Function(String)? emptyBuilder,
  }) {
    if (_isLoading) {
      return [
        loadingBuilder?.call(context) ??
            Center(
              child: CircularProgressIndicator(),
            )
      ];
    } else if (_hasError) {
      return [errorBuilder?.call(_error) ?? Text(_error)];
    } else if (_data != null) {
      return successBuilder.call(_data as T);
    } else if (_hasEmpty) {
      return [emptyBuilder?.call(_emptyError) ?? Text(_emptyError)];
    } else {
      return [
        const Text('No data found')
      ]; // You can return a default widget for empty state
    }
  }
}
