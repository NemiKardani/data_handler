# DataHandler 🚀✨📦

![Pub Version](https://img.shields.io/pub/v/data_handler) ![License](https://img.shields.io/badge/license-MIT-blue) ![Platform](https://img.shields.io/badge/platform-Flutter-blue)

**Effortless State Management for API Responses in Flutter Apps!** 🎯📱⚡

`DataHandler` is a **lightweight** and **efficient** state management utility designed to handle API responses **seamlessly** across all Flutter platforms (**Android, iOS, Web, Windows, macOS, and Linux**). It simplifies state handling, including **loading, success, error, and empty states**, ensuring a smooth UI experience with **performance optimization** and **global configuration**. 🎉🚀

---

## 🌟 Features

✅ **Universal Compatibility** – Works across all platforms!  
✅ **Smart State Management** – Loading, Success, Error, and Empty states with enum-based tracking  
✅ **Performance Optimized** – Only rebuilds when state actually changes  
✅ **Global Widget Configuration** – Set app-wide defaults for consistent UI  
✅ **Sliver Support** – Perfect integration with CustomScrollView  
✅ **List Enhancement** – Specialized handling for list data with empty detection  
✅ **Works with Any Data Type (`T`)** – Highly versatile and reusable  
✅ **Modern Architecture** – Built with latest Flutter best practices  
✅ **Minimal Setup, Maximum Productivity** – Get started in seconds!

---

## 📥 Installation

Add `DataHandler` to your `pubspec.yaml`:

```yaml
dependencies:
  data_handler: ^0.0.5  # Use the latest version
```

Then, run:

```sh
flutter pub get
```

---

## 🚀 Quick Start

### 1️⃣ Import the Package
```dart
import 'package:data_handler/data_handler.dart';
```

### 2️⃣ Initialize DataHandler
```dart
final DataHandler<String> handler = DataHandler<String>();
// Or with initial data
final DataHandler<List<User>> users = DataHandler<List<User>>(initialUserList);
```

### 3️⃣ Manage API States

#### 🔄 Loading State
```dart
handler.startLoading();
```

#### ✅ Success State
```dart
handler.onSuccess("Data loaded successfully");
```

#### ❌ Error State
```dart
handler.onError("Something went wrong");
```

#### 📭 Empty State
```dart
handler.onEmpty("No data available");
```

#### 🔄 Convenient Refresh
```dart
await handler.refresh(() => apiService.fetchData());
```

---

## 🖥️ UI Integration

### 🎭 Handle Different States Dynamically
```dart
Widget build(BuildContext context) {
  return handler.when(
    onLoading: () => const CircularProgressIndicator(),
    onSuccess: (data) => Text(data),
    onError: (error) => Text("Error: $error", style: TextStyle(color: Colors.red)),
    onEmpty: (message) => Text("No Data: $message"),
  );
}
```

### 📋 List Handling (Perfect for API Lists)
```dart
Widget build(BuildContext context) {
  return userHandler.whenList(
    onSuccess: (users) => ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) => UserTile(users[index]),
    ),
    onLoading: () => const Center(child: CircularProgressIndicator()),
    onError: (error) => ErrorWidget(error),
    onEmptyList: (message) => const EmptyUsersWidget(),
  );
}
```

### 🎢 Sliver Support for CustomScrollView
```dart
Widget build(BuildContext context) {
  return CustomScrollView(
    slivers: [
      const SliverAppBar(title: Text('Users')),
      userHandler.whenSliverList(
        itemBuilder: (users, index) => UserTile(users[index]),
        itemCount: (users) => users.length,
        onLoading: () => const LoadingWidget(),
        onError: (error) => ErrorWidget(error),
        onEmpty: (message) => const EmptyWidget(),
      ),
    ],
  );
}
```

---

## 🌍 Global Configuration

Set app-wide defaults for consistent UI across your entire application:

```dart
void main() {
  // Configure global widgets once
  DataHandlerConfig.setGlobalWidgets(
    loadingWidget: () => const CustomLoadingSpinner(),
    errorWidget: (error) => CustomErrorWidget(error),
    emptyWidget: (message) => CustomEmptyWidget(message),
  );
  
  runApp(MyApp());
}
```

Now all your `DataHandler` instances will automatically use these widgets when local ones aren't provided!

### App Preview
[![bSVbD.gif](https://s3.gifyu.com/images/bSVbD.gif)](https://gifyu.com/image/bSVbD)

### Web Preview
![DataHandler Preview](https://raw.githubusercontent.com/NemiKardani/data_handler/refs/heads/main/previews/data_handler_web_preview.gif)

---

## 🚀 Advanced Usage

### 🔍 State Checking
```dart
if (handler.isLoading) {
  // Show loading indicator
}

if (handler.hasSuccess) {
  // Data is available and valid
  print('Data: ${handler.data}');
}

if (handler.hasError) {
  // Handle error case
  print('Error: ${handler.errorMessage}');
}
```

### 📊 List-Specific Properties
```dart
DataHandler<List<String>> listHandler = DataHandler();

// Check list state
print('Is empty: ${listHandler.isListEmpty}');
print('Length: ${listHandler.listLength}');
```

### 🔄 Direct Data Updates
```dart
// Update data without loading state (for real-time updates)
handler.updateData(newData);

// Clear all data and reset to empty
handler.clear();
```

### 🎯 Performance Optimization
```dart
// Disable automatic state handling when needed
handler.when(
  enabled: false,  // Always shows success widget if data exists
  onSuccess: (data) => SuccessWidget(data),
  // ... other callbacks
);

// Control global widget fallback
handler.when(
  useGlobalWidgets: false,  // Only use local widgets
  onSuccess: (data) => SuccessWidget(data),
  // ... other callbacks
);
```

### ⚡ Selective Rebuilds (`select`)
Prevents unnecessary subtree rebuilds when large models mutate. Only rebuilds the specific widget when the selected field changes:
```dart
handler.select<int>(
  selector: (user) => user.unreadCount,
  builder: (context, count) => BadgeCounter(count),
);
```

### ⚡ Debounced Search & Stale Response Killer
Eliminates out-of-order race conditions and delays execution while user types:
```dart
await searchHandler.refresh(
  () => api.search(query),
  debounce: const Duration(milliseconds: 300),
);
```

### ⚡ Optimistic Updates & Auto-Rollback
Instantly updates the UI and automatically reverts if the server call fails:
```dart
await postHandler.optimisticUpdate(
  likedPost,
  action: () => api.likePost(postId),
  rollbackOnError: true, // Automatically reverts if network throws!
);
```

### ⚡ Real-Time Stream Binding
Binds directly to WebSockets, Firebase, or Supabase streams with leak-free auto-disposal:
```dart
chatHandler.bindStream(chatService.messagesStream);
```

### ⚡ Low-Memory List Pagination
Directly appends paginated items without cloning large collections in RAM:
```dart
listHandler.appendData(nextPageItems);
```

### 🏢 Team Interceptors & Error Formatter
Centralized telemetry, auth-token expiry, and exception mapping across all team members:
```dart
DataHandlerConfig.setErrorFormatter((error) {
  if (error is DioException) return error.response?.data['message'] ?? 'Network Error';
  return error.toString();
});

DataHandlerConfig.addInterceptor(MyLoggingAndAuthInterceptor());
```

---

## 🌍 Cross-Platform Compatibility
`DataHandler` is fully optimized for **Flutter's multi-platform capabilities**, ensuring **smooth performance on:**

| Platform | Status |
|----------|---------|
| 📱 Android | ✅ |
| 🍏 iOS | ✅ |
| 🖥️ Web | ✅ |
| 🏢 Windows | ✅ |
| 🍎 macOS | ✅ |
| 🐧 Linux | ✅ |

---

## 🔄 Migration from v0.0.3

If you're upgrading from v0.0.3, here's what changed:

```dart
// OLD (v0.0.3)
handler.when(
  context: context,
  loadingBuilder: (context) => Loading(),
  successBuilder: (data) => Success(data),
  errorWidget: ErrorWidget(),
)

// NEW (v0.0.4)
handler.when(
  onLoading: () => Loading(),
  onSuccess: (data) => Success(data),
  onError: (error) => ErrorWidget(error),
)
```

**Key Changes:**
- Removed `context` parameter
- Changed builder names (`loadingBuilder` → `onLoading`)
- Replaced widget properties with callbacks
- Added global configuration system

---

## 🤝 Contributing
We **love** contributions! 🚀

Feel free to **open issues**, **discuss features**, or **submit pull requests** to enhance `DataHandler`. Let's build something amazing together! 🛠️✨

---

## 📜 License
This package is released under the **MIT License**. 🔓

---

**Enjoying DataHandler? Give it a ⭐ on GitHub and help others discover it!** 😊🚀

Made with ❤️ for the Flutter community