# DataHandler 🚀✨📦

![Pub Version](https://img.shields.io/pub/v/data_handler) ![License](https://img.shields.io/badge/license-MIT-blue) ![Platform](https://img.shields.io/badge/platform-Flutter-blue)

**Effortless State Management for API Responses in Flutter Apps!** 🎯📱⚡

`DataHandler` is a **lightweight** and **efficient** state management utility designed to handle API responses **seamlessly** across all Flutter platforms (**Android, iOS, Web, Windows, macOS, and Linux**). It simplifies state handling, including **loading, success, error, and empty states**, ensuring a smooth UI experience. 🎉🚀

---

## 🌟 Features

✅ **Universal Compatibility** – Works across all platforms!
✅ **Easy API Response Management** – Handle different states effortlessly.
✅ **Built-in State Handlers** – Loading, Success, Error, and Empty states.
✅ **Flexible UI Rendering** – Provides dynamic builders for widgets and lists.
✅ **Works with Any Data Type (`T`)** – Highly versatile and reusable.
✅ **Minimal Setup, Maximum Productivity** – Get started in seconds!

---

## 📥 Installation

Add `DataHandler` to your `pubspec.yaml`:

```yaml
dependencies:
  data_handler: latest_version # Replace with the latest version
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
final handler = DataHandler<String>();
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

---

## 🖥️ UI Integration

### 🎭 Handle Different States Dynamically
```dart
Widget build(BuildContext context) {
  return handler.when(
    context: context,
    loadingBuilder: (ctx) => CircularProgressIndicator(),
    successBuilder: (data) => Text(data),
    errorBuilder: (error) => Text("Error: $error"),
    emptyBuilder: (message) => Text("No Data: $message"),
  );
}
```

### 📋 List Handling (Ideal for Fetching Lists)
```dart
List<Widget> buildList(BuildContext context) {
  return handler.whenListWidget(
    context: context,
    loadingBuilder: (ctx) => [CircularProgressIndicator()],
    successBuilder: (data) => [Text("Item: $data")],
    errorBuilder: (error) => [Text("Error: $error")],
    emptyBuilder: (message) => [Text("No items found")],
  );
}
```

---

## 📺 Preview

Here's a preview of how `DataHandler` works in a real Flutter app:

![DataHandler Preview](https://your-image-link-here.com/preview.gif)

---

## 🌍 Cross-Platform Compatibility
`DataHandler` is fully optimized for **Flutter’s multi-platform capabilities**, ensuring **smooth performance on:**

📱 Android  | 🍏 iOS  | 🖥️ Web  | 🏢 Windows  | 🍎 macOS  | 🐧 Linux  
✅ ✅ ✅ ✅ ✅ ✅ 

---

## 🤝 Contributing
We **love** contributions! 🚀

Feel free to **open issues**, **discuss features**, or **submit pull requests** to enhance `DataHandler`. Let’s build something amazing together! 🛠️✨

---

## 📜 License
This package is released under the **MIT License**. 🔓

Enjoy using `DataHandler`? **Give it a ⭐ on GitHub!** 😊🚀
