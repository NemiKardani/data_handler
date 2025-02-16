import 'dart:convert';

import 'package:data_handler/data_handler.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Data Handler Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: PublicApiExample(),
    );
  }
}

class PublicApiExample extends StatefulWidget {
  const PublicApiExample({super.key});

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
      await Future.delayed(Duration(seconds: 5));
      final response = await http.get(
        Uri.parse('https://jsonplaceholder.typicode.com/posts'),
      );

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Data Handler Example',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 4,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade100, Colors.blue.shade300],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _dataHandler.when(
          context: context,
          loadingBuilder: (context) =>
              Center(child: CircularProgressIndicator()),
          successBuilder: (data) => RefreshIndicator(
            onRefresh: _fetchPosts,
            child: ListView.builder(
              padding: EdgeInsets.all(12),
              itemCount: data.length,
              itemBuilder: (context, index) => Card(
                elevation: 5,
                margin: EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.all(16),
                  title: Text(
                    data[index].title,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  subtitle: Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      data[index].body,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade700,
                    child: Text(
                      data[index].id.toString(),
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
          ),
          errorBuilder: (error) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, color: Colors.red, size: 50),
                SizedBox(height: 10),
                Text(error,
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _fetchPosts,
                  child: Text("Retry"),
                ),
              ],
            ),
          ),
          emptyBuilder: (empty) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, color: Colors.grey, size: 50),
                SizedBox(height: 10),
                Text(empty, style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Post {
  final int userId;
  final int id;
  final String title;
  final String body;

  Post({
    required this.userId,
    required this.id,
    required this.title,
    required this.body,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      userId: json['userId'],
      id: json['id'],
      title: json['title'],
      body: json['body'],
    );
  }
}
