import 'dart:convert';
import 'dart:math';

import 'package:data_handler/data_handler.dart';
import 'package:example/model/post_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class PublicApiExample extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const PublicApiExample({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
  });

  @override
  State<PublicApiExample> createState() => _PublicApiExampleState();
}

class _PublicApiExampleState extends State<PublicApiExample>
    with TickerProviderStateMixin {
  late DataHandler<List<Post>> _dataHandler;
  late AnimationController _refreshController;
  late AnimationController _fabController;
  late Animation<double> _refreshAnimation;
  late Animation<double> _fabAnimation;

  final ScrollController _scrollController = ScrollController();
  bool _showFab = true;
  bool _isUseGlobleWidgets = false;

  @override
  void initState() {
    super.initState();
    _initializeDataHandler();
    _initializeAnimations();
    _setupScrollListener();
    _fetchPosts();
  }

  void _initializeDataHandler() {
    _dataHandler = DataHandler<List<Post>>();

    // Listen to state changes for animations
    _dataHandler.addListener(() {
      if (mounted) {
        setState(() {});
        _handleStateAnimation();
      }
    });
  }

  void _initializeAnimations() {
    _refreshController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fabController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _refreshAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _refreshController,
      curve: Curves.elasticOut,
    ));

    _fabAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fabController,
      curve: Curves.elasticOut,
    ));

    _fabController.forward();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      final bool shouldShow = _scrollController.offset <= 100;
      if (shouldShow != _showFab) {
        setState(() => _showFab = shouldShow);
        if (_showFab) {
          _fabController.forward();
        } else {
          _fabController.reverse();
        }
      }
    });
  }

  void _handleStateAnimation() {
    switch (_dataHandler.state) {
      case DataState.loading:
        _refreshController.repeat();
        break;
      case DataState.success:
        _refreshController.stop();
        _refreshController.reset();
        break;
      case DataState.error:
      case DataState.empty:
        _refreshController.stop();
        _refreshController.reset();
        break;
    }
  }

  Future<void> _fetchPosts() async {
    HapticFeedback.lightImpact();

    await _dataHandler.refresh(() async {
      // Simulate network delay with random time
      final delay = Random().nextInt(2) + 1;
      await Future.delayed(Duration(seconds: delay));

      final response = await http.get(
        Uri.parse('https://jsonplaceholder.typicode.com/posts'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        List<dynamic> jsonData = json.decode(response.body);
        List<Post> posts = jsonData
            .map((post) => Post.fromJson(post))
            .take(20) // Limit to 20 posts for better performance
            .toList();

        if (posts.isEmpty) {
          throw Exception("No posts found");
        }

        return posts;
      } else {
        throw Exception("Failed to load posts: HTTP ${response.statusCode}");
      }
    });
  }

  void _simulateLoading() {
    HapticFeedback.selectionClick();
    _dataHandler.startLoading();

    // Auto recover after 3 seconds for demo
    Future.delayed(const Duration(seconds: 3), () {
      if (_dataHandler.state == DataState.loading) {
        _fetchPosts();
      }
    });
  }

  void _simulateError() {
    HapticFeedback.heavyImpact();
    _dataHandler.onError(
        "Network connection failed. Please check your internet connection and try again.");
  }

  void _simulateEmpty() {
    HapticFeedback.mediumImpact();
    _dataHandler.onEmpty("No posts available at the moment. Check back later!");
  }

  void _clearData() {
    HapticFeedback.lightImpact();
    _dataHandler.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(theme),
      body: Column(
        children: [
          const SizedBox(height: kToolbarHeight + 40),
          _buildStatsHeader(theme),
          _buildMainContent(theme),
        ],
      ),
      bottomNavigationBar: _buildBottomActions(theme),
      floatingActionButton: _buildFloatingActionButton(theme),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: widget.isDarkMode
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      title: Text(
        'Posts Dashboard',
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
      ),
      centerTitle: true,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                _isUseGlobleWidgets
                    ? Icons.gps_not_fixed_rounded
                    : Icons.gps_fixed_rounded,
                key: ValueKey(widget.isDarkMode),
                color: theme.colorScheme.primary,
              ),
            ),
            onPressed: () {
              setState(() {
                _isUseGlobleWidgets = !_isUseGlobleWidgets;
              });
            },
            tooltip: !_isUseGlobleWidgets
                ? 'Use Global Widgets'
                : 'Use Local Widgets',
          ),
        ),
        Container(
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                widget.isDarkMode
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                key: ValueKey(widget.isDarkMode),
                color: theme.colorScheme.primary,
              ),
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              widget.toggleTheme();
            },
            tooltip: widget.isDarkMode
                ? 'Switch to Light Mode'
                : 'Switch to Dark Mode',
          ),
        ),
      ],
    );
  }

  Widget _buildStatsHeader(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.1),
            theme.colorScheme.secondary.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(child: _buildStatCard('Status', _getStatusInfo(), theme)),
          Container(
            width: 1,
            height: 50,
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
          Expanded(child: _buildStatCard('Posts', _getPostsCount(), theme)),
          Container(
            width: 1,
            height: 50,
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
          Expanded(child: _buildStatCard('State', _getStateInfo(), theme)),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String label, Map<String, dynamic> info, ThemeData theme) {
    return Column(
      children: [
        if (info['icon'] != null) ...[
          Icon(
            info['icon'],
            color: info['color'] ?? theme.colorScheme.primary,
            size: 24,
          ),
          const SizedBox(height: 8),
        ],
        Text(
          info['value'],
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: info['color'] ?? theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _getStatusInfo() {
    switch (_dataHandler.state) {
      case DataState.loading:
        return {
          'value': 'Loading',
          'icon': Icons.sync,
          'color': Colors.orange,
        };
      case DataState.success:
        return {
          'value': 'Online',
          'icon': Icons.check_circle,
          'color': Colors.green,
        };
      case DataState.error:
        return {
          'value': 'Error',
          'icon': Icons.error,
          'color': Colors.red,
        };
      case DataState.empty:
        return {
          'value': 'Empty',
          'icon': Icons.inbox,
          'color': Colors.grey,
        };
    }
  }

  Map<String, dynamic> _getPostsCount() {
    final count = _dataHandler.data?.length ?? 0;
    return {
      'value': count.toString(),
      'icon': Icons.article_outlined,
      'color': null,
    };
  }

  Map<String, dynamic> _getStateInfo() {
    return {
      'value': _dataHandler.state.name.toUpperCase(),
      'icon': null,
      'color': null,
    };
  }

  Widget _buildMainContent(ThemeData theme) {
    return Expanded(
      child: _dataHandler.whenList(
        useGlobalWidgets: _isUseGlobleWidgets,
        onSuccess: (posts) => _buildPostsList(posts, theme),
        onLoading:
            !_isUseGlobleWidgets ? () => _buildLoadingState(theme) : null,
        onError: !_isUseGlobleWidgets
            ? (error) => _buildErrorState(error, theme)
            : null,
        onEmptyList: !_isUseGlobleWidgets
            ? (empty) => _buildEmptyState(empty, theme)
            : null,
      ),
    );
  }

  Widget _buildPostsList(List<Post> posts, ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _fetchPosts,
      color: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.surface,
      strokeWidth: 3,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          return AnimatedContainer(
            duration: Duration(milliseconds: 100 + (index * 50)),
            curve: Curves.easeOutBack,
            child: _buildPostCard(posts[index], index, theme),
          );
        },
      ),
    );
  }

  Widget _buildPostCard(Post post, int index, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        shadowColor: theme.colorScheme.primary.withValues(alpha: 0.1),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.selectionClick();
            _showPostDetails(post, theme);
          },
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Hero(
                      tag: 'post_avatar_${post.id}',
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.secondary,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Center(
                          child: Text(
                            post.id.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Post #${post.id}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'By User ${post.userId}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  post.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  post.body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.6,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RotationTransition(
            turns: _refreshAnimation,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Icon(
                Icons.sync,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading amazing posts...',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait while we fetch the latest content',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error, ThemeData theme) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.error.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                size: 40,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Connection Problem',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.5,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: _fetchPosts,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                    side: BorderSide(color: theme.colorScheme.primary),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _clearData,
                  icon: const Icon(Icons.clear_rounded),
                  label: const Text('Clear'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(60),
            ),
            child: Icon(
              Icons.inbox_outlined,
              size: 60,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Posts Yet',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _fetchPosts,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Load Posts'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  "Loading",
                  Icons.hourglass_empty_rounded,
                  Colors.deepPurple,
                  _simulateLoading,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  "Error",
                  Icons.error_outline_rounded,
                  Colors.red,
                  _simulateError,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  "Empty",
                  Icons.inbox_outlined,
                  Colors.teal,
                  _simulateEmpty,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(height: 4),
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton(ThemeData theme) {
    return ScaleTransition(
      scale: _fabAnimation,
      child: FloatingActionButton.extended(
        onPressed: _fetchPosts,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 8,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text(
          'Refresh',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _showPostDetails(Post post, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Hero(
                          tag: 'post_avatar_${post.id}',
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  theme.colorScheme.primary,
                                  theme.colorScheme.secondary,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Center(
                              child: Text(
                                post.id.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Post #${post.id}',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'By User ${post.userId}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      post.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          post.body,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.6,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _dataHandler.dispose();
    _refreshController.dispose();
    _fabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
