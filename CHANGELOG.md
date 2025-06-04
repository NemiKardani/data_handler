## 0.0.4

### 🚨 BREAKING CHANGES
This version introduces a complete architectural redesign. **All existing code using v0.0.3 will need to be updated.**

#### API Changes
- **`when()` method signature completely changed:**
  ```dart
  // OLD (v0.0.3)
  dataHandler.when(
    context: context,
    loadingBuilder: (context) => Loading(),
    successBuilder: (data) => Success(data),
    progressIndicatorColor: Colors.blue,
    errorWidget: ErrorWidget(),
  )
  
  // NEW (v0.0.4)
  dataHandler.when(
    onLoading: () => Loading(),
    onSuccess: (data) => Success(data),
    onError: (error) => Error(error),
    onEmpty: (message) => Empty(message),
  )
  ```

- **`whenList()` method redesigned:**
  - Now returns `Widget` instead of `List<Widget>`
  - Removed automatic Column wrapping
  - Added `whenSliverList()` for Sliver widgets

#### Removed Parameters
- `context` parameter (no longer required)
- `progressIndicatorColor`
- `progressIndicator`
- `errorWidget`
- `emptyWidget`
- `errorStyle`
- `emptyStyle`
- `isEnabled` → renamed to `enabled`

### ✨ New Features

#### Global Widget Configuration
```dart
// Set global defaults for your entire app
DataHandlerConfig.setGlobalWidgets(
  loadingWidget: () => CustomLoader(),
  errorWidget: (error) => CustomError(error),
  emptyWidget: (message) => CustomEmpty(message),
);
```

#### Enhanced Performance
- **Smart rebuild optimization** - Only rebuilds when state actually changes
- **AnimatedBuilder** integration for smoother transitions
- **Memory optimization** with automatic cleanup

#### New Methods
```dart
// Convenient data refresh
await dataHandler.refresh(() => apiService.getData());

// Direct data updates without loading state
dataHandler.updateData(newData);

// Reset to empty state
dataHandler.clear();

// Check if data exists and is successful
if (dataHandler.hasSuccess) { ... }
```

#### List Handling Enhancement
```dart
// Enhanced list support
DataHandler<List<User>> users = DataHandler();

// Check list properties
print(users.isListEmpty);  // true if null or empty
print(users.listLength);   // 0 if null, length otherwise

// Specialized list widget builder
users.whenList(
  onSuccess: (list) => ListView.builder(...),
  onEmptyList: (message) => EmptyListWidget(),
);
```

#### Sliver Support
```dart
// Perfect for CustomScrollView
CustomScrollView(
  slivers: [
    dataHandler.whenSliverList(
      itemBuilder: (data, index) => ListTile(...),
      itemCount: (data) => data.length,
    ),
  ],
)
```

### 🔧 Migration Guide

1. **Update `when()` calls:**
   ```dart
   // Remove context parameter
   // Change builder names: loadingBuilder → onLoading, etc.
   // Remove widget properties, use callbacks instead
   ```

2. **Update widget configuration:**
   ```dart
   // Instead of passing widgets as parameters
   // Set them globally or use callbacks
   ```

3. **Update `whenList()` usage:**
   ```dart
   // Now returns single Widget, not List<Widget>
   // Remove manual Column wrapping
   ```

### 📚 Documentation
- Added comprehensive inline documentation
- Included usage examples for all methods
- Performance optimization guidelines

---

## 0.0.3

### Added
- Support for `when` and `whenList` parameters
- New widget customization properties:
  - `progressIndicatorColor` - Custom loading indicator color
  - `progressIndicator` - Custom loading widget
  - `errorWidget` - Custom error display widget
  - `emptyWidget` - Custom empty state widget
  - `errorStyle` - Custom text styling for errors
  - `emptyStyle` - Custom text styling for empty state
  - `isEnabled` - Toggle to enable/disable state handling
- Updated examples with new features
- Added screenshots for documentation

---

## 0.0.2

### Added
- Example implementation for `data_handler` plugin
- Enhanced widget support for better UI handling

### Fixed
- Resolved critical issue with `data_handler` plugin functionality
- Improved stability and performance

---

## 0.0.1

### Added
- Initial release of `data_handler` plugin
- Basic state management for loading, success, error, and empty states
- Core `DataHandler<T>` class with `ChangeNotifier` integration
- Basic `when()` method for conditional widget rendering

---

## Migration from 0.0.3 to 0.0.4

### Quick Migration Steps:

1. **Remove context parameter:**
   ```dart
   // Before
   handler.when(context: context, ...)
   // After  
   handler.when(...)
   ```

2. **Update callback names:**
   ```dart
   // Before
   loadingBuilder: (context) => Widget()
   successBuilder: (data) => Widget()
   
   // After
   onLoading: () => Widget()
   onSuccess: (data) => Widget()
   ```

3. **Replace widget properties with callbacks:**
   ```dart
   // Before
   errorWidget: MyErrorWidget()
   
   // After
   onError: (error) => MyErrorWidget(error)
   ```

4. **Consider using global configuration:**
   ```dart
   // Set once in main.dart
   DataHandlerConfig.setGlobalLoadingWidget(() => MyLoader());
   ```

### Need Help?
Check the updated documentation and examples in the repository for detailed migration guidance.