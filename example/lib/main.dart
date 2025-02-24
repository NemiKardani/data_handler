import 'dart:convert';
import 'package:data_handler/data_handler.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Data Handler Example',
      debugShowCheckedModeBanner: false,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      home: PublicApiExample(toggleTheme: _toggleTheme, isDarkMode: _isDarkMode),
    );
  }

  /// Builds the light theme with soft, harmonious colors.
  ThemeData _buildLightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF6C5CE7), // Soft purple
        secondary: Color(0xFF00B894), // Soft teal
        surface: Color(0xFFF5F5F5), // Light gray
        // background: Color(0xFFFFFFFF), // White
        onSurface: Color(0xFF2D3436), // Dark gray for text
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF6C5CE7),
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF2D3436)),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2D3436)),
        bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF2D3436)),
        bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF2D3436)),
        labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  /// Builds the dark theme with soft, harmonious colors.
  ThemeData _buildDarkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF6C5CE7), // Soft purple
        secondary: Color(0xFF00B894), // Soft teal
        surface: Color(0xFF2D3436), // Dark gray
        // background: Color(0xFF121212), // Dark background
        onSurface: Color(0xFFF5F5F5), // Light gray for text
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF2D3436),
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFFF5F5F5)),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFF5F5F5)),
        bodyLarge: TextStyle(fontSize: 16, color: Color(0xFFF5F5F5)),
        bodyMedium: TextStyle(fontSize: 14, color: Color(0xFFF5F5F5)),
        labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }
}

class PublicApiExample extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const PublicApiExample({super.key, required this.toggleTheme, required this.isDarkMode});

  @override
  State<PublicApiExample> createState() => _PublicApiExampleState();
}

class _PublicApiExampleState extends State<PublicApiExample> {
  late DataHandler<List<Post>> _dataHandler;

  @override
  void initState() {
    super.initState();
    _dataHandler = DataHandler<List<Post>>();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    _dataHandler.startLoading();
    try {
      await Future.delayed(const Duration(seconds: 2)); // Simulate network delay
      final response = await http.get(Uri.parse('https://jsonplaceholder.typicode.com/posts'));

      if (response.statusCode == 200) {
        List<dynamic> jsonData = json.decode(response.body);
        List<Post> posts = jsonData.map((post) => Post.fromJson(post)).toList();

        if (posts.isNotEmpty) {
          _dataHandler.onSuccess(posts);
        } else {
          _dataHandler.onEmpty("No posts found");
        }
      } else {
        _dataHandler.onError("Failed to load posts: ${response.statusCode}");
      }
    } catch (e) {
      _dataHandler.onError("An error occurred: $e");
    }
  }

  void _showLoading() {
    _dataHandler.startLoading();
  }

  void _showError() {
    _dataHandler.onError("This is a simulated error.");
  }

  void _showEmpty() {
    _dataHandler.onEmpty("This is a simulated empty state.");
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Handler Example'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.toggleTheme,
          ),
        ],
      ),
      body: _dataHandler.when(
        context: context,
        loadingBuilder: (context) => _buildLoadingPlaceholder(theme),
        successBuilder: (data) => RefreshIndicator(
          onRefresh: _fetchPosts,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: data.length,
            itemBuilder: (context, index) => _buildPostCard(data[index], theme),
          ),
        ),
        errorBuilder: (error) => _buildErrorState(error, theme),
        emptyBuilder: (empty) => _buildEmptyState(empty, theme),
      ),
      bottomNavigationBar: _buildBottomActions(theme),
    );
  }

  /// Builds a themed post card.
  Widget _buildPostCard(Post post, ThemeData theme) {
    return Card(
      elevation: 4,
      color: theme.colorScheme.surface,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          post.title,
          style: theme.textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(post.body, style: theme.textTheme.bodyMedium),
        ),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary,
          child: Text(
            post.id.toString(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  /// Builds a themed loading placeholder.
  Widget _buildLoadingPlaceholder(ThemeData theme) {
    return Center(
      child: CircularProgressIndicator(color: theme.colorScheme.primary),
    );
  }

  /// Builds the error state UI.
  Widget _buildErrorState(String error, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error, color: theme.colorScheme.error, size: 50),
          const SizedBox(height: 16),
          Text(error, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchPosts,
            style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary),
            child: Text("Retry", style: theme.textTheme.labelLarge),
          ),
        ],
      ),
    );
  }

  /// Builds the empty state UI.
  Widget _buildEmptyState(String empty, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, color: theme.colorScheme.onSurface, size: 50),
          const SizedBox(height: 16),
          Text(empty, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }

  /// Builds the bottom action buttons.
  Widget _buildBottomActions(ThemeData theme) {
    return BottomAppBar(
      color: theme.colorScheme.surface,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildActionButton("Loading", theme, _showLoading, const Color(0xFF6C5CE7)),
            _buildActionButton("Error", theme, _showError, const Color(0xFFE74C3C)),
            _buildActionButton("Empty", theme, _showEmpty, const Color(0xFF00B894)),
          ],
        ),
      ),
    );
  }

  /// Creates a reusable action button.
  Widget _buildActionButton(String text, ThemeData theme, VoidCallback onPressed, Color color) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(backgroundColor: color),
      child: Text(text, style: theme.textTheme.labelLarge),
    );
  }
}

/// Post model class.
class Post {
  final int userId;
  final int id;
  final String title;
  final String body;

  Post({required this.userId, required this.id, required this.title, required this.body});

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      userId: json['userId'],
      id: json['id'],
      title: json['title'],
      body: json['body'],
    );
  }
}