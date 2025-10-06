import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'comments_screen.dart';

class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _ideas = [];
  List<dynamic> _initialIdeas = [];
  String? _userId;
  int _initialPage = 1;
  bool _initialHasMore = true;
  bool _initialIsLoadingMore = false;
  bool _isLoading = false;
  Timer? _debounce;
  ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _isLoading = true; // Set loading true initially
    _loadUserId().then((_) => _loadInitialIdeas());
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
          !_initialIsLoadingMore &&
          _initialHasMore &&
          _searchController.text.isEmpty) {
        _loadMoreInitialIdeas();
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  // Load user ID
  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('user_id');
      print('Logged-in user ID: $_userId');
    });
  }

  // Load initial public ideas (randomized)
  Future<void> _loadInitialIdeas() async {
    if (_userId == null) {
      print('Skipping _loadInitialIdeas: userId is null');
      setState(() {
        _isLoading = false;
      });
      return;
    }
    setState(() {
      _initialPage = 1;
      _initialIdeas.clear();
      _initialHasMore = true;
      _initialIsLoadingMore = false;
      _isLoading = true;
    });
    await _loadInitialIdeasPage();
  }

  // Load a page of initial public ideas
  Future<void> _loadInitialIdeasPage() async {
    if (!_initialHasMore || _initialIsLoadingMore) {
      print('Skipping _loadInitialIdeasPage: hasMore=$_initialHasMore, isLoadingMore=$_initialIsLoadingMore');
      setState(() {
        _isLoading = false;
      });
      return;
    }
    setState(() {
      _initialIsLoadingMore = true;
    });
    try {
      final url = '${ApiService.baseUrl}ideas/list/?visibility=PUBLIC&page=$_initialPage';
      print('Fetching initial ideas: $url');
      final response = await ApiService().makeAuthenticatedRequest(
        request: (token) => http.get(
          Uri.parse(url),
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      print('API response for initial ideas (status: ${response.statusCode}): ${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> newIdeas = data['results'] ?? [];
        if (newIdeas.isEmpty) {
          print('No new initial PUBLIC ideas returned from API');
        }
        for (var idea in newIdeas) {
          if (idea['user'] is! Map) {
            print('Invalid user data for idea ${idea['id']}: ${idea['user']}');
            idea['user'] = {'username': 'Unknown', 'profile_pic': null, 'id': null};
          }
          print('Idea ${idea['id']}: title=${idea['title']}, visibility=${idea['visibility']}, created_at=${idea['created_at']}, user_id=${idea['user']['id']}');
        }
        setState(() {
          // Filter out user's own ideas to match HomeScreen
          final filteredIdeas = newIdeas.where((idea) {
            final ideaUserId = idea['user']['id']?.toString();
            final isExcluded = _userId != null && ideaUserId == _userId;
            if (isExcluded) {
              print('Excluding idea ${idea['id']} (title: ${idea['title']}) as it belongs to user $_userId');
            }
            return _userId == null || ideaUserId != _userId;
          }).toList();
          _initialIdeas.addAll(filteredIdeas);
          _initialIdeas.shuffle(Random()); // Randomize the ideas list
          _initialHasMore = data['next'] != null;
          _initialIsLoadingMore = false;
          _isLoading = false;
          print('Added ${filteredIdeas.length} initial PUBLIC ideas, total: ${_initialIdeas.length}');
          print('Randomized initial ideas list: ${_initialIdeas.map((idea) => idea['title']).toList()}');
          if (_initialIdeas.isEmpty && !_initialHasMore) {
            print('No public ideas available after filtering');
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to load initial ideas: ${response.body}',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              backgroundColor: Colors.purple[800],
            ),
          );
        }
        print('API error for initial ideas: ${response.statusCode} - ${response.body}');
        setState(() {
          _initialIsLoadingMore = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (e.toString().contains('Authentication failed')) {
        await ApiService().clearTokens();
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error loading initial ideas: $e',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              backgroundColor: Colors.purple[800],
            ),
          );
        }
        print('Error loading initial ideas: $e');
        setState(() {
          _initialIsLoadingMore = false;
          _isLoading = false;
        });
      }
    }
  }

  // Load more initial public ideas
  Future<void> _loadMoreInitialIdeas() async {
    setState(() {
      _initialPage++;
      print('Loading more initial ideas, page: $_initialPage');
    });
    await _loadInitialIdeasPage();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(Duration(milliseconds: 300), () {
      _performSearch(_searchController.text);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _ideas = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService().search(query);
      List<dynamic> searchIdeas = response['ideas'] ?? [];

      // Filter out private ideas from other users
      searchIdeas = searchIdeas.where((idea) {
        final isPublic = idea['visibility']?.toString().toUpperCase() == 'PUBLIC';
        final isOwnPrivate = idea['visibility']?.toString().toUpperCase() == 'PRIVATE' &&
            idea['user'] is Map &&
            idea['user']['id']?.toString() == _userId;
        if (!isPublic && !isOwnPrivate) {
          print('Excluding idea ${idea['id']} (title: ${idea['title']}, visibility: ${idea['visibility']}, user_id: ${idea['user']['id']}) from search results');
        }
        return isPublic || isOwnPrivate;
      }).toList();

      for (var idea in searchIdeas) {
        if (idea['user'] is! Map) {
          print('Invalid user data for idea ${idea['id']}: ${idea['user']}');
          idea['user'] = {'username': 'Unknown', 'profile_pic': null, 'id': null};
        }
        print('Search result idea ${idea['id']}: title=${idea['title']}, categories=${idea['categories']}, visibility=${idea['visibility']}');
      }

      // Prioritize ideas by category match, then title match, then created_at
      final queryLower = query.toLowerCase();
      searchIdeas.sort((a, b) {
        final aCategories = (a['categories'] as List<dynamic>? ?? []).cast<String>().map((c) => c.toLowerCase());
        final bCategories = (b['categories'] as List<dynamic>? ?? []).cast<String>().map((c) => c.toLowerCase());
        final aMatchesCategory = aCategories.any((c) => c.contains(queryLower));
        final bMatchesCategory = bCategories.any((c) => c.contains(queryLower));
        final aMatchesTitle = a['title']?.toString().toLowerCase().contains(queryLower) ?? false;
        final bMatchesTitle = b['title']?.toString().toLowerCase().contains(queryLower) ?? false;

        if (aMatchesCategory && !bMatchesCategory) return -1;
        if (!aMatchesCategory && bMatchesCategory) return 1;
        if (aMatchesCategory && bMatchesCategory || aMatchesTitle && bMatchesTitle) {
          final aDate = a['created_at'] != null ? DateTime.tryParse(a['created_at'] as String) ?? DateTime(0) : DateTime(0);
          final bDate = b['created_at'] != null ? DateTime.tryParse(b['created_at'] as String) ?? DateTime(0) : DateTime(0);
          return bDate.compareTo(aDate);
        }
        if (aMatchesTitle && !bMatchesTitle) return 1;
        if (!aMatchesTitle && bMatchesTitle) return -1;
        return 0;
      });

      setState(() {
        _ideas = searchIdeas;
        _isLoading = false;
        print('Search results: ${_ideas.map((idea) => idea['title']).toList()}');
      });
    } catch (e) {
      if (e.toString().contains('Authentication failed')) {
        await ApiService().clearTokens();
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $e',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            backgroundColor: Colors.purple[800],
          ),
        );
        print('Error performing search: $e');
      }
    }
  }

  Future<void> _toggleLike(int index, List<dynamic> ideas) async {
    final idea = ideas[index];
    final ideaId = idea['id'];
    try {
      final response = await ApiService().likeIdea(ideaId);
      setState(() {
        ideas[index]['is_liked'] = response['is_liked'];
        ideas[index]['like_count'] = response['like_count'];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['message'],
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          backgroundColor: Colors.purple[800],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: $e',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          backgroundColor: Colors.purple[800],
        ),
      );
      print('Error toggling like for idea ${idea['id']}: $e');
    }
  }

  String _calculateTimeSince(String createdAt) {
    try {
      final createdAtDt = DateTime.parse(createdAt).toUtc();
      final now = DateTime.now().toUtc();
      final diff = now.difference(createdAtDt);
      final totalSeconds = diff.inSeconds;
      print('Time calc for created_at=$createdAt, now=$now, total_seconds=$totalSeconds');
      if (totalSeconds < 60) {
        return '${totalSeconds}s';
      } else if (totalSeconds < 3600) {
        return '${totalSeconds ~/ 60}m';
      } else if (totalSeconds < 86400) {
        return '${totalSeconds ~/ 3600}h';
      } else if (totalSeconds < 604800) {
        return '${totalSeconds ~/ 86400}d';
      } else {
        return '${totalSeconds ~/ 604800}w';
      }
    } catch (e) {
      print('Error parsing created_at: $createdAt, error: $e');
      return 'Just now';
    }
  }

  String capitalize(String s) => s.isEmpty ? s : "${s[0].toUpperCase()}${s.substring(1).toLowerCase()}";

  Widget _buildSearchResults() {
    final ideas = _searchController.text.isEmpty ? _initialIdeas : _ideas;

    if (_isLoading && ideas.isEmpty) {
      return Center(child: CircularProgressIndicator(color: Colors.purple[800]));
    }

    return RefreshIndicator(
      color: Colors.purple[800],
      onRefresh: () async {
        if (_searchController.text.isEmpty) {
          await _loadInitialIdeas();
        } else {
          await _performSearch(_searchController.text);
        }
      },
      child: ideas.isEmpty
          ? SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Container(
          height: MediaQuery.of(context).size.height - 200,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                _searchController.text.isEmpty ? 'No ideas available.' : 'No results found.',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
            ),
          ),
        ),
      )
          : ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.all(8.0),
        itemCount: ideas.length + (_initialIsLoadingMore && _searchController.text.isEmpty ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < ideas.length) {
            final idea = ideas[index];
            final user = idea['user'] is Map ? idea['user'] : {'username': 'Unknown', 'profile_pic': null, 'id': null};
            String timeSince = _calculateTimeSince(idea['created_at'] ?? '');
            final selectedCategories = (idea['categories'] as List<dynamic>? ?? []).cast<String>();
            print('Rendering idea ${idea['id']}: title=${idea['title']}, categories=$selectedCategories, visibility=${idea['visibility']}, time_since=$timeSince');
            return Card(
              margin: EdgeInsets.symmetric(vertical: 8.0),
              elevation: 6,
              shadowColor: Colors.black26,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
                        print('Navigating to profile_view with user: ${user['username']}');
                        Navigator.pushNamed(context, '/profile_view', arguments: user);
                      },
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            child: CachedNetworkImage(
                              imageUrl: user['profile_pic'] != null && user['profile_pic'].isNotEmpty && user['profile_pic'].startsWith('http')
                                  ? user['profile_pic']
                                  : user['profile_pic'] != null && user['profile_pic'].isNotEmpty
                                  ? '${ApiService.baseUrl}${user['profile_pic'].startsWith('/') ? user['profile_pic'].substring(1) : user['profile_pic']}'
                                  : '${ApiService.baseUrl}media/profile_pics/default.jpg',
                              imageBuilder: (context, imageProvider) => Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
                                ),
                              ),
                              placeholder: (context, url) => CircularProgressIndicator(color: Colors.purple[800]),
                              errorWidget: (context, url, error) => Image.asset('assets/default.png', fit: BoxFit.cover),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${user['username']} • $timeSince • ${capitalize(idea['visibility'])}',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        print('Navigating to idea_details with idea: ${idea['id']}');
                        Navigator.pushNamed(context, '/idea_details', arguments: idea);
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            idea['title'],
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 6),
                          Text(
                            idea['short_description'] ?? '',
                            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (selectedCategories.isNotEmpty) ...[
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 4.0,
                        runSpacing: 2.0,
                        children: selectedCategories.map<Widget>((cat) => Chip(
                          label: Text(
                            cat,
                            style: TextStyle(fontSize: 10, color: Colors.black87),
                          ),
                          backgroundColor: Colors.blue[50],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          padding: EdgeInsets.symmetric(horizontal: 2.5, vertical: -1),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        )).toList(),
                      ),
                    ],
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                idea['is_liked'] ? Icons.favorite : Icons.favorite_border,
                                size: 18,
                                color: idea['is_liked'] ? Colors.purple[800] : Colors.black87,
                              ),
                              onPressed: () => _toggleLike(index, ideas),
                              tooltip: 'Like',
                            ),
                            Text(
                              '${idea['like_count'] ?? 0}',
                              style: TextStyle(fontSize: 14, color: Colors.black87),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.comment, size: 18, color: Colors.black87),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CommentsScreen(
                                      ideaId: idea['id'],
                                      ideaTitle: idea['title'],
                                    ),
                                  ),
                                );
                              },
                              tooltip: 'Comment',
                            ),
                            Text(
                              '${idea['comment_count'] ?? 0}',
                              style: TextStyle(fontSize: 14, color: Colors.black87),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.group_add, size: 18, color: Colors.black87),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Collaborate functionality not implemented yet',
                                  style: TextStyle(color: Colors.white, fontSize: 14),
                                ),
                                backgroundColor: Colors.purple[800],
                              ),
                            );
                          },
                          tooltip: 'Collaborate',
                        ),
                        IconButton(
                          icon: Icon(Icons.share, size: 18, color: Colors.black87),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Share functionality not implemented yet',
                                  style: TextStyle(color: Colors.white, fontSize: 14),
                                ),
                                backgroundColor: Colors.purple[800],
                              ),
                            );
                          },
                          tooltip: 'Share',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          } else {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(color: Colors.purple[800]),
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ThinkDrop',
          style: TextStyle(
            color: Color(0xFF281B60),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.2),
        centerTitle: false,
        automaticallyImplyLeading: false,
        titleSpacing: 16.0,
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Color(0xFF281B60), size: 24),
            tooltip: 'Search',
            onPressed: () {
              FocusScope.of(context).requestFocus(FocusNode());
            },
          ),
          IconButton(
            icon: Icon(Icons.menu, color: Color(0xFF281B60), size: 24),
            tooltip: 'Menu',
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search ideas by title or category...',
                prefixIcon: Icon(Icons.search, color: Colors.purple[800]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.purple[800]!, width: 2),
                ),
              ),
            ),
          ),
          // Search Results or Initial Ideas
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }
}