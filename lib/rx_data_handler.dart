// import 'package:flutter/material.dart';
// import 'package:get/get_rx/src/rx_types/rx_types.dart';
//
// class RxDataHandler<T> extends Rxn<T?> {
//   final RxBool _isLoading = false.obs;
//   final RxBool _hasError = false.obs;
//   final RxBool _hasEmpty = false.obs;
//   final RxString _error = ''.obs;
//   final RxString _emptyError = ''.obs;
//
//   RxDataHandler([T? data]) : super(data) {
//     if (data != null) {
//       value = data; // Set Rxn value
//       _hasEmpty.value = false;
//       _isLoading.value = false;
//       _hasError.value = false;
//       _error.value = '';
//       _emptyError.value = '';
//       refresh();
//     } else {
//       _hasEmpty.value = true;
//       _isLoading.value = false;
//       _hasError.value = false;
//       _error.value = '';
//       _emptyError.value = '';
//       refresh();
//     }
//   }
//
//   bool get isLoading => _isLoading.value;
//   bool get hasError => _hasError.value;
//   T? get data => value; // Use Rxn value directly
//   String get error => _error.value;
//   String get empty => _emptyError.value;
//
//   void startLoading() {
//     _isLoading.value = true;
//     _hasError.value = false;
//     value = null; // Update Rxn value
//     _error.value = '';
//     refresh();
//   }
//
//   void onSuccess(T newData) {
//     _isLoading.value = false;
//     _hasError.value = false;
//     value = newData; // Update Rxn value
//     _error.value = '';
//     refresh();
//   }
//
//   void onError(String errorMessage) {
//     _isLoading.value = false;
//     _hasError.value = true;
//     value = null; // Update Rxn value
//     _error.value = errorMessage;
//     refresh();
//   }
//
//   void onEmpty(String errorMessage, {bool hasError = true}) {
//     _isLoading.value = false;
//     _hasEmpty.value = hasError;
//     _hasError.value = false;
//     value = null; // Update Rxn value
//     _error.value = errorMessage;
//     _emptyError.value = errorMessage;
//     refresh();
//   }
//
//   void onUpdate(T newData) {
//     _isLoading.value = false;
//     _hasError.value = false;
//     value = newData; // Update Rxn value
//     _error.value = '';
//     refresh();
//   }
//
//   Widget when({
//     required BuildContext context,
//     Widget Function(BuildContext)? loadingBuilder,
//     required Widget Function(T) successBuilder,
//     Widget Function(String)? errorBuilder,
//     Widget Function(String)? emptyBuilder,
//   }) {
//     if (_isLoading.value) {
//       return loadingBuilder?.call(context) ??
//           Center(
//             child: CircularProgressIndicator(),
//           );
//     } else if (_hasError.value) {
//       return errorBuilder?.call(_error.value) ?? Text(_error.value);
//     } else if (value != null) {
//       // Check Rxn value
//       return successBuilder(value as T);
//     } else if (_hasEmpty.value) {
//       return emptyBuilder?.call(_emptyError.value) ?? Text(_emptyError.value);
//     } else {
//       return const Text('No data found');
//     }
//   }
//
//   List<Widget> whenListWidget({
//     required BuildContext context,
//     Widget Function(BuildContext)? loadingBuilder,
//     required List<Widget> Function(T) successBuilder,
//     Widget Function(String)? errorBuilder,
//     Widget Function(String)? emptyBuilder,
//   }) {
//     if (_isLoading.value) {
//       return [
//         loadingBuilder?.call(context) ??
//             Center(
//               child: CircularProgressIndicator(),
//             )
//       ];
//     } else if (_hasError.value) {
//       return [errorBuilder?.call(_error.value) ?? Text(_error.value)];
//     } else if (value != null) {
//       // Check Rxn value
//       return successBuilder(value as T);
//     } else if (_hasEmpty.value) {
//       return [emptyBuilder?.call(_emptyError.value) ?? Text(_emptyError.value)];
//     } else {
//       return [const Text('No data found')];
//     }
//   }
// }
