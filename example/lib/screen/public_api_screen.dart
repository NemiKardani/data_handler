import 'dart:async';
import 'dart:convert';

import 'package:data_handler/data_handler.dart';
import 'package:example/interceptor/logging_interceptor.dart';
import 'package:example/model/post_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Model for the real-time stream demonstration
class StreamEvent {
  final int id;
  final String title;
  final String category;
  final DateTime timestamp;

  StreamEvent({
    required this.id,
    required this.title,
    required this.category,
    required this.timestamp,
  });
}

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
  // Navigation
  int _currentTabIndex = 0;

  // Handlers
  late DataHandler<List<Post>> _dataHandler;
  late DataHandler<List<StreamEvent>> _streamHandler;

  // Stream simulation controller
  StreamController<List<StreamEvent>>? _streamController;
  Timer? _streamTimer;
  final List<StreamEvent> _streamEvents = [];
  bool _isStreamPaused = false;
  int _streamSequence = 0;

  // Search & Pagination
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  int _currentPage = 1;
  static const int _pageSize = 10;
  List<Post> _cachedFullPosts = [];

  // Options & Toggles
  bool _isUseGlobalWidgets = false;
  bool _isSliverMode = false;
  bool _simulateRollbackFailure = false;
  bool _showFab = true;

  // Animations
  late AnimationController _refreshController;
  late AnimationController _fabController;
  late Animation<double> _refreshAnimation;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _initializeHandlers();
    _initializeAnimations();
    _setupScrollListener();
    _fetchPosts(preserveData: false);
    _startStreamSimulation();
  }

  void _initializeHandlers() {
    _dataHandler = DataHandler<List<Post>>();
    _streamHandler = DataHandler<List<StreamEvent>>();

    // Listen to state changes to trigger animations
    _dataHandler.addListener(() {
      if (mounted) {
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

    _refreshAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _refreshController, curve: Curves.elasticOut),
    );

    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabController, curve: Curves.elasticOut),
    );

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

      // Low-Memory Infinite Pagination Trigger
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        if (!_isLoadingMore &&
            _dataHandler.hasSuccess &&
            _searchController.text.isEmpty) {
          _loadMorePosts();
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
      case DataState.error:
      case DataState.empty:
        _refreshController.stop();
        _refreshController.reset();
        break;
    }
  }

  // ==========================================
  // Post Data Operations (Debounce, Soft Refresh, Pagination)
  // ==========================================

  Future<void> _fetchPosts({bool preserveData = false}) async {
    HapticFeedback.lightImpact();
    _currentPage = 1;

    // Uses soft refresh (preserveData: true) when pull-to-refresh is used
    await _dataHandler.refresh(() async {
      final response = await http.get(
        Uri.parse('https://jsonplaceholder.typicode.com/posts'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        _cachedFullPosts =
            jsonData.map((post) => Post.fromJson(post)).toList();

        final initialBatch = _cachedFullPosts.take(_pageSize).toList();
        if (initialBatch.isEmpty) {
          throw Exception("No posts found from server");
        }
        return initialBatch;
      } else {
        throw Exception("Failed to load posts (HTTP ${response.statusCode})");
      }
    }, preserveData: preserveData);
  }

  /// Built-in Debounced Search with automatic stale-response cancellation
  void _onSearchChanged(String query) {
    _dataHandler.refresh(() async {
      final q = query.trim().toLowerCase();
      if (q.isEmpty) {
        return _cachedFullPosts.take(_currentPage * _pageSize).toList();
      }

      // Simulate small query processing
      await Future.delayed(const Duration(milliseconds: 100));

      final filtered =
          _cachedFullPosts.where((post) {
            return post.title.toLowerCase().contains(q) ||
                post.body.toLowerCase().contains(q) ||
                post.id.toString() == q;
          }).toList();

      if (filtered.isEmpty) {
        _dataHandler.onEmpty('No posts matching "$query"');
      }

      return filtered;
    }, debounce: const Duration(milliseconds: 350));
  }

  /// Low-Memory List Pagination using appendData
  Future<void> _loadMorePosts() async {
    final currentList = _dataHandler.data;
    if (currentList == null || _isLoadingMore) return;

    final startIndex = _currentPage * _pageSize;
    if (startIndex >= _cachedFullPosts.length) return; // No more posts

    setState(() => _isLoadingMore = true);

    await Future.delayed(const Duration(milliseconds: 800)); // Simulate delay

    final nextBatch =
        _cachedFullPosts.skip(startIndex).take(_pageSize).toList();

    if (nextBatch.isNotEmpty && mounted) {
      _currentPage++;
      // Directly appends data with minimal allocation overhead
      _dataHandler.appendData(nextBatch);
    }

    if (mounted) {
      setState(() => _isLoadingMore = false);
    }
  }

  // ==========================================
  // Optimistic Updates & Rollback Demo
  // ==========================================

  Future<void> _toggleFavorite(Post post) async {
    final currentPosts = _dataHandler.data ?? [];
    final targetFav = !post.isFavorite;

    // Immediately update in memory for 120fps UI responsiveness
    final optimisticList =
        currentPosts.map((p) {
          return p.id == post.id ? p.copyWith(isFavorite: targetFav) : p;
        }).toList();

    HapticFeedback.selectionClick();

    await _dataHandler.optimisticUpdate(
      optimisticList,
      action: () async {
        // Simulate remote server latency
        await Future.delayed(const Duration(milliseconds: 700));

        if (_simulateRollbackFailure) {
          throw Exception(
            "Server 500: Failed to toggle favorite. Rolled back!",
          );
        }

        return optimisticList;
      },
      rollbackOnError: true,
    );
  }

  Future<void> _deletePost(Post post) async {
    final currentPosts = _dataHandler.data ?? [];
    final optimisticList =
        currentPosts.where((p) => p.id != post.id).toList();

    HapticFeedback.mediumImpact();

    await _dataHandler.optimisticUpdate(
      optimisticList,
      action: () async {
        await Future.delayed(const Duration(milliseconds: 700));

        if (_simulateRollbackFailure) {
          throw Exception(
            "Server 403: Unauthorized to delete post #${post.id}! Rolled back.",
          );
        }

        return optimisticList;
      },
      rollbackOnError: true,
    );
  }

  // ==========================================
  // Real-Time Stream Binding Demo (bindStream)
  // ==========================================

  void _startStreamSimulation() {
    _streamController = StreamController<List<StreamEvent>>.broadcast();

    // Bind handler directly to the stream with automatic subscription & disposal management
    _streamHandler.bindStream(
      _streamController!.stream,
      errorFormatter: (err) => 'Stream exception: $err',
    );

    _streamTimer = Timer.periodic(const Duration(milliseconds: 1800), (timer) {
      if (_isStreamPaused || _streamController == null || _streamController!.isClosed) {
        return;
      }

      _streamSequence++;
      final categories = ['Analytics', 'Payment', 'User Auth', 'Database', 'Cloud Worker'];
      final chosenCategory = categories[_streamSequence % categories.length];

      final newEvent = StreamEvent(
        id: _streamSequence,
        title: 'Event #$_streamSequence: $chosenCategory activity dispatched',
        category: chosenCategory,
        timestamp: DateTime.now(),
      );

      _streamEvents.insert(0, newEvent);
      if (_streamEvents.length > 30) {
        _streamEvents.removeLast();
      }

      _streamController?.add(List.from(_streamEvents));
    });
  }

  void _toggleStreamPause() {
    setState(() {
      _isStreamPaused = !_isStreamPaused;
    });
  }

  void _injectStreamError() {
    _streamController?.addError("WebSocket disconnect: ECONNRESET");
  }

  void _clearStream() {
    _streamEvents.clear();
    _streamController?.add([]);
  }

  // ==========================================
  // Simulations (Loading, Error, Empty, Clear)
  // ==========================================

  void _simulateLoading() {
    HapticFeedback.selectionClick();
    _dataHandler.startLoading();
  }

  void _simulateError() {
    HapticFeedback.heavyImpact();
    _dataHandler.onError(
      Exception("Network connection failed. Please check your internet connection."),
    );
  }

  void _simulateEmpty() {
    HapticFeedback.mediumImpact();
    _dataHandler.onEmpty("No posts available right now. Tap refresh to load.");
  }

  void _clearData() {
    HapticFeedback.lightImpact();
    _dataHandler.clear();
  }

  // ==========================================
  // UI Building
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: _buildAppBar(theme),
      body: SizedBox.expand(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: _currentTabIndex == 0
                ? _buildPostsTab(theme)
                : (_currentTabIndex == 1
                    ? _buildStreamTab(theme)
                    : _buildInterceptorTab(theme)),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(theme),
      floatingActionButton:
          _currentTabIndex == 0 ? _buildFloatingActionButton(theme) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      elevation: 0,
      systemOverlayStyle:
          widget.isDarkMode ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      title: Text(
        _currentTabIndex == 0
            ? 'Enterprise DataHandler'
            : (_currentTabIndex == 1 ? 'Live Stream Binding' : 'Team Interceptor'),
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
      ),
      actions: [
        if (_currentTabIndex == 0) ...[
          // Sliver vs ListView Toggle
          IconButton(
            icon: Icon(
              _isSliverMode ? Icons.view_day_rounded : Icons.view_agenda_rounded,
            ),
            tooltip: _isSliverMode ? 'Switch to ListView' : 'Switch to SliverList',
            onPressed: () {
              setState(() => _isSliverMode = !_isSliverMode);
            },
          ),
          // Global vs Local Widgets Toggle
          IconButton(
            icon: Icon(
              _isUseGlobalWidgets
                  ? Icons.travel_explore_rounded
                  : Icons.widgets_outlined,
            ),
            tooltip:
                _isUseGlobalWidgets ? 'Using Global Widgets' : 'Using Local Widgets',
            onPressed: () {
              setState(() => _isUseGlobalWidgets = !_isUseGlobalWidgets);
            },
          ),
        ],
        // Dark / Light Mode Toggle
        IconButton(
          icon: Icon(
            widget.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          ),
          tooltip: widget.isDarkMode ? 'Light Mode' : 'Dark Mode',
          onPressed: () {
            HapticFeedback.selectionClick();
            widget.toggleTheme();
          },
        ),
      ],
    );
  }

  // ----------------------------------------------------
  // Tab 0: Posts Dashboard (Search, Optimistic, Pagination)
  // ----------------------------------------------------

  Widget _buildPostsTab(ThemeData theme) {
    return Column(
      children: [
        // Selective Micro-Rebuilds Stats Header
        _buildStatsHeader(theme),

        // Prominent Interactive State Simulation Bar (Loading, Error, Empty, Success, Clear)
        _buildStateControlBar(theme),

        // Debounced Search Bar
        _buildSearchBar(theme),

        // Rollback Simulator & Feature Pill
        _buildFeatureToolbar(theme),

        // Background Refresh indicator via maybeWhen
        _buildBackgroundSyncBanner(theme),

        // Main List Content (List or Sliver)
        Expanded(
          child: _isSliverMode ? _buildSliverContent(theme) : _buildListContent(theme),
        ),
      ],
    );
  }

  /// Demonstrates selective micro-rebuilds via `select<R>()`
  Widget _buildStatsHeader(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 1. Status Selector
          Expanded(
            child: _dataHandler.select<DataState>(
              selector: (_) => _dataHandler.state,
              builder: (context, state) {
                final statusInfo = _getStatusInfo(state);
                return _buildStatCard(
                  'State',
                  statusInfo['value'] as String,
                  statusInfo['icon'] as IconData,
                  statusInfo['color'] as Color,
                  theme,
                );
              },
            ),
          ),
          Container(
            width: 1,
            height: 38,
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
          // 2. Total Count Selector (Only redraws when count changes!)
          Expanded(
            child: _dataHandler.select<int>(
              selector: (posts) => posts.length,
              builder: (context, count) {
                return _buildStatCard(
                  'Posts',
                  count.toString(),
                  Icons.article_outlined,
                  theme.colorScheme.primary,
                  theme,
                );
              },
              onEmpty: (_) => _buildStatCard(
                'Posts',
                '0',
                Icons.article_outlined,
                Colors.grey,
                theme,
              ),
              onLoading: () => _buildStatCard(
                'Posts',
                '...',
                Icons.sync,
                Colors.orange,
                theme,
              ),
            ),
          ),
          Container(
            width: 1,
            height: 38,
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
          // 3. Favorites Selector (Demonstrates micro-rebuild on optimistic updates!)
          Expanded(
            child: _dataHandler.select<int>(
              selector: (posts) => posts.where((p) => p.isFavorite).length,
              builder: (context, favCount) {
                return _buildStatCard(
                  'Favorites',
                  favCount.toString(),
                  Icons.favorite_rounded,
                  Colors.pinkAccent,
                  theme,
                );
              },
              onEmpty: (_) => _buildStatCard(
                'Favorites',
                '0',
                Icons.favorite_border_rounded,
                Colors.grey,
                theme,
              ),
              onLoading: () => _buildStatCard(
                'Favorites',
                '-',
                Icons.favorite_border_rounded,
                Colors.grey,
                theme,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    ThemeData theme,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStateControlBar(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStateActionButton(
              label: 'Loading',
              icon: Icons.hourglass_empty_rounded,
              color: Colors.deepPurple,
              onPressed: _simulateLoading,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildStateActionButton(
              label: 'Error',
              icon: Icons.error_outline_rounded,
              color: Colors.red,
              onPressed: _simulateError,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildStateActionButton(
              label: 'Empty',
              icon: Icons.inbox_outlined,
              color: Colors.teal,
              onPressed: _simulateEmpty,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildStateActionButton(
              label: 'Success',
              icon: Icons.check_circle_outline_rounded,
              color: Colors.green,
              onPressed: () => _fetchPosts(preserveData: false),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.clear_all_rounded, size: 20),
            color: Colors.blueGrey,
            tooltip: 'Clear State',
            onPressed: _clearData,
          ),
        ],
      ),
    );
  }

  Widget _buildStateActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Debounced search (350ms) & stale-killer...',
          hintStyle: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: theme.colorScheme.surface,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: theme.colorScheme.primary,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureToolbar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // Simulate Rollback Failure switch
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _simulateRollbackFailure
                    ? Colors.red.withValues(alpha: 0.1)
                    : theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _simulateRollbackFailure
                      ? Colors.red.withValues(alpha: 0.3)
                      : theme.colorScheme.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _simulateRollbackFailure
                        ? Icons.warning_amber_rounded
                        : Icons.speed_rounded,
                    size: 16,
                    color: _simulateRollbackFailure
                        ? Colors.red
                        : theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _simulateRollbackFailure
                          ? 'Rollback Demo: Errors Fail & Revert'
                          : 'Optimistic Updates: 120fps Instant',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _simulateRollbackFailure
                            ? Colors.red.shade700
                            : theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  Transform.scale(
                    scale: 0.75,
                    child: Switch(
                      value: _simulateRollbackFailure,
                      onChanged: (val) {
                        setState(() => _simulateRollbackFailure = val);
                      },
                      activeThumbColor: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Pattern Matching (maybeWhen) Banner during background soft-refresh
  Widget _buildBackgroundSyncBanner(ThemeData theme) {
    return _dataHandler.maybeWhen(
      onLoading: () {
        // Only show subtle banner if we already have existing data (soft refresh)
        if (_dataHandler.data != null && _dataHandler.data!.isNotEmpty) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.secondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Soft Refresh: Retaining data on-screen while updating...',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _buildListContent(ThemeData theme) {
    return _dataHandler.whenList(
      useGlobalWidgets: _isUseGlobalWidgets,
      onSuccess: (posts) => _buildPostsListView(posts, theme),
      onLoading: !_isUseGlobalWidgets ? () => _buildLoadingState(theme) : null,
      onError:
          !_isUseGlobalWidgets ? (error) => _buildErrorState(error, theme) : null,
      onEmptyList:
          !_isUseGlobalWidgets
              ? (empty) => _buildEmptyState(empty, theme)
              : null,
    );
  }

  Widget _buildPostsListView(List<Post> posts, ThemeData theme) {
    return RefreshIndicator(
      // Soft Refresh: preserveData keeps data visible without blanking
      onRefresh: () => _fetchPosts(preserveData: true),
      color: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.surface,
      strokeWidth: 3,
      child: Scrollbar(
        controller: _scrollController,
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
          itemCount: posts.length + (_isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == posts.length) {
              return _buildPaginationLoading(theme);
            }
            return _buildPostCard(posts[index], index, theme);
          },
        ),
      ),
    );
  }

  Widget _buildSliverContent(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: () => _fetchPosts(preserveData: true),
      child: Scrollbar(
        controller: _scrollController,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // whenSliverList provides seamless integration with CustomScrollView
            _dataHandler.whenSliverList(
              useGlobalWidgets: _isUseGlobalWidgets,
              itemCount: (posts) => posts.length + (_isLoadingMore ? 1 : 0),
              itemBuilder: (posts, index) {
                if (index == posts.length) {
                  return _buildPaginationLoading(theme);
                }
                return _buildPostCard(posts[index], index, theme);
              },
              onLoading:
                  !_isUseGlobalWidgets ? () => _buildLoadingState(theme) : null,
              onError:
                  !_isUseGlobalWidgets
                      ? (error) => _buildErrorState(error, theme)
                      : null,
              onEmpty:
                  !_isUseGlobalWidgets
                      ? (empty) => _buildEmptyState(empty, theme)
                      : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationLoading(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Appending next page (appendData)...',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(Post post, int index, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.selectionClick();
            _showPostDetails(post, theme);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Post ID Badge
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.secondary,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          post.id.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
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
                          Text(
                            'User ${post.userId}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Optimistic Favorite Button
                    IconButton(
                      icon: Icon(
                        post.isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color:
                            post.isFavorite
                                ? Colors.pinkAccent
                                : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.4,
                                ),
                        size: 22,
                      ),
                      tooltip: 'Optimistic Favorite (with rollback)',
                      onPressed: () => _toggleFavorite(post),
                    ),
                    // Optimistic Delete Button
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.red.shade400,
                        size: 20,
                      ),
                      tooltip: 'Optimistic Delete (with rollback)',
                      onPressed: () => _deletePost(post),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  post.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  post.body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    height: 1.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // Tab 1: Real-Time Stream Binding (bindStream)
  // ----------------------------------------------------

  Widget _buildStreamTab(ThemeData theme) {
    return Column(
      children: [
        // Information Banner
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.stream_rounded, color: theme.colorScheme.primary, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Real-Time Stream Binding (bindStream)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Binds directly to WebSockets or Firebase Streams. Automatic subscription cleanup eliminates memory leaks on dispose.',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Stream Control Buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _toggleStreamPause,
                  icon: Icon(_isStreamPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                  label: Text(_isStreamPaused ? 'Resume' : 'Pause'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _injectStreamError,
                  icon: const Icon(Icons.error_outline_rounded, color: Colors.red),
                  label: const Text('Error', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                icon: const Icon(Icons.clear_all_rounded),
                tooltip: 'Clear Stream',
                onPressed: _clearStream,
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Stream Event List
        Expanded(
          child: _streamHandler.when(
            onSuccess: (events) {
              if (events.isEmpty) {
                return Center(
                  child: Text(
                    'No events emitted yet. Stream is listening...',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final event = events[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.2),
                        child: Icon(Icons.bolt_rounded, color: theme.colorScheme.secondary),
                      ),
                      title: Text(
                        event.title,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      subtitle: Text(
                        'Category: ${event.category} • ${event.timestamp.toIso8601String().split('T').last.substring(0, 8)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  );
                },
              );
            },
            onLoading: () => const Center(child: CircularProgressIndicator()),
            onError: (err) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stream_rounded, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(err, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        _startStreamSimulation();
                      },
                      child: const Text('Reconnect Stream'),
                    ),
                  ],
                ),
              ),
            ),
            onEmpty: (msg) => Center(child: Text(msg)),
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------
  // Tab 2: Enterprise Interceptor & Diagnostics
  // ----------------------------------------------------

  Widget _buildInterceptorTab(ThemeData theme) {
    return ValueListenableBuilder<List<InterceptorLog>>(
      valueListenable: AppLoggingInterceptor.instance.logsNotifier,
      builder: (context, logs, _) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.hub_rounded, color: theme.colorScheme.primary, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Team Interceptors & Diagnostics',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'DataHandlerInterceptor monitors state hooks across your whole codebase. Centralized error formatter formats all exceptions.',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recorded Events (${logs.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.bolt_rounded, size: 16),
                        label: const Text('Test Formatter'),
                        onPressed: () {
                          _dataHandler.onError(Exception("TimeoutException: Host took 15000ms"));
                        },
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                        label: const Text('Clear'),
                        onPressed: () {
                          AppLoggingInterceptor.instance.clearLogs();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: logs.isEmpty
                  ? Center(
                      child: Text(
                        'No interceptor events recorded yet. Perform actions to see hooks.',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        final timeStr = log.timestamp.toIso8601String().split('T').last.substring(0, 8);
                        final badgeColor = _getHookBadgeColor(log.eventType);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.outline.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: badgeColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      log.eventType,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: badgeColor,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    timeStr,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                log.message,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Color _getHookBadgeColor(String eventType) {
    switch (eventType) {
      case 'onRequest':
        return Colors.orange;
      case 'onSuccess':
        return Colors.green;
      case 'onError':
        return Colors.red;
      case 'onStateChanged':
        return const Color(0xFF6C5CE7);
      default:
        return Colors.blueGrey;
    }
  }

  // ----------------------------------------------------
  // Bottom Navigation Bar
  // ----------------------------------------------------

  Widget _buildBottomNav(ThemeData theme) {
    return NavigationBar(
      selectedIndex: _currentTabIndex,
      onDestinationSelected: (index) {
        setState(() => _currentTabIndex = index);
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard_rounded),
          label: 'Feed & Ops',
        ),
        NavigationDestination(
          icon: Icon(Icons.stream_outlined),
          selectedIcon: Icon(Icons.stream_rounded),
          label: 'Live Stream',
        ),
        NavigationDestination(
          icon: Icon(Icons.hub_outlined),
          selectedIcon: Icon(Icons.hub_rounded),
          label: 'Interceptors',
        ),
      ],
    );
  }

  // ----------------------------------------------------
  // Status Helpers & States
  // ----------------------------------------------------

  Map<String, dynamic> _getStatusInfo(DataState state) {
    switch (state) {
      case DataState.loading:
        return {'value': 'Loading', 'icon': Icons.sync, 'color': Colors.orange};
      case DataState.success:
        return {
          'value': 'Success',
          'icon': Icons.check_circle_rounded,
          'color': Colors.green,
        };
      case DataState.error:
        return {
          'value': 'Error',
          'icon': Icons.error_outline_rounded,
          'color': Colors.red,
        };
      case DataState.empty:
        return {
          'value': 'Empty',
          'icon': Icons.inbox_outlined,
          'color': Colors.grey,
        };
    }
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RotationTransition(
            turns: _refreshAnimation,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(35),
              ),
              child: const Icon(Icons.sync, color: Colors.white, size: 36),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Fetching latest posts...',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error, ThemeData theme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.error.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 40, color: theme.colorScheme.error),
              const SizedBox(height: 12),
              Text(
                'Connection Error',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.error,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _fetchPosts(preserveData: false),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Try Again'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _clearData,
                    icon: const Icon(Icons.clear_rounded, size: 16),
                    label: const Text('Clear'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, ThemeData theme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(45),
            ),
            child: Icon(
              Icons.inbox_outlined,
              size: 45,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No Posts Found',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _fetchPosts(preserveData: false),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Fetch Posts'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildFloatingActionButton(ThemeData theme) {
    return ScaleTransition(
      scale: _fabAnimation,
      child: FloatingActionButton.extended(
        onPressed: () => _fetchPosts(preserveData: true),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 6,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text(
          'Soft Refresh',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
    );
  }

  void _showPostDetails(Post post, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.65,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
              children: [
                Container(
                  width: 36,
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
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    theme.colorScheme.primary,
                                    theme.colorScheme.secondary,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: Center(
                                child: Text(
                                  post.id.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Post #${post.id}',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Created by User ${post.userId}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                post.isFavorite
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: post.isFavorite ? Colors.pinkAccent : null,
                              ),
                              onPressed: () {
                                _toggleFavorite(post);
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          post.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Text(
                              post.body,
                              style: theme.textTheme.bodyMedium?.copyWith(
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
          ),
          ),
    );
  }

  @override
  void dispose() {
    _streamTimer?.cancel();
    _streamController?.close();
    _dataHandler.dispose();
    _streamHandler.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _refreshController.dispose();
    _fabController.dispose();
    super.dispose();
  }
}
