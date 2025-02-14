# DataHandler ✨🚀🎯

`DataHandler` is a lightweight and efficient state management utility for handling API responses in Flutter applications. It simplifies managing different states like loading, success, error, and empty states, making UI updates seamless. 🎯📱🔥

## Features 🎨⚡🛠️

- Manage API response states easily.
- Built-in loading, success, error, and empty state handling.
- Provides flexible widget builders for UI rendering.
- Works with any data type (`T`).

## Installation 📥🔧📌

Add the following dependency to your `pubspec.yaml` file:

```yaml
dependencies:
  data_handler: latest_version # Replace with the latest version
```

Then, run:

```sh
flutter pub get
```

## Usage 📚🖥️🎯

### 1. Import the Package 📦✅🔗

```dart
import 'package:data_handler/data_handler.dart';
```

### 2. Initialize DataHandler 🎯🎉⚡

```dart
final handler = DataHandler<String>();
```

### 3. Manage API Responses 🌍📡⚡

#### Start Loading ⏳🔄🚀
```dart
handler.startLoading();
```

#### On Success 🎉✅📌
```dart
handler.onSuccess("Data loaded successfully");
```

#### On Error ❌⚠️🚨
```dart
handler.onError("Something went wrong");
```

#### On Empty Data 📭⚡🔍
```dart
handler.onEmpty("No data available");
```

### 4. Use `when` for UI Handling 🎭📱🌟

```dart
Widget build(BuildContext context) {
  return handler.when(
    context: context,
    loadingBuilder: (ctx) => CircularProgressIndicator(),
    successBuilder: (data) => Text(data),
    errorBuilder: (error) => Text("Error: $error"),
    emptyBuilder: (message) => Text("Empty: $message"),
  );
}
```

### 5. Use `whenListWidget` for Lists 📋🗂️⚡

```dart
List<Widget> buildList(BuildContext context) {
  return handler.whenListWidget(
    context: context,
    loadingBuilder: (ctx) => Center(child: CircularProgressIndicator()),
    successBuilder: (data) => [Text("Item: $data")],
    errorBuilder: (error) => [Text("Error: $error")],
    emptyBuilder: (message) => [Text("No items found")],
  );
}
```

## Contributing 🤝💡🌍

Contributions are welcome! Feel free to open issues or submit pull requests. 🚀✅🎯

## License 📜✅⚖️

This package is licensed under the MIT License. 🔒📄✅
