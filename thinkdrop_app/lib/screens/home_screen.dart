import 'package:flutter/material.dart';
import 'collaboration_screen.dart';
import 'post_idea_screen.dart';
import 'notification_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'search_screen.dart';
import 'profile_view_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'comments_screen.dart';
import 'ideas_details_screen.dart';
import 'idea_user_detail_screen.dart';

// Inline capitalize function
String capitalize(String s) => s.isEmpty ? s : "${s[0].toUpperCase()}${s.substring(1).toLowerCase()}";

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  List<dynamic> _ideas = [];
  int _currentPage = 1;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  ScrollController _scrollController = ScrollController();
  String? _userId;
  List<String> _userInterests = [];
  final Random _random = Random();

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('user_id');
      print('Logged-in user ID: $_userId');
    });
  }

  Future<void> _loadUserInterests() async {
    try {
      final response = await ApiService().makeAuthenticatedRequest(
        request: (token) => http.get(
          Uri.parse('${ApiService.baseUrl}profile/'),
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _userInterests = List<String>.from(data['interests'] ?? []);
          print('Loaded user interests: $_userInterests');
        });
      } else {
        print('Failed to load user interests: ${response.body}');
      }
    } catch (e) {
      print('Error loading user interests: $e');
    }
  }

  String _calculateTimeSince(String createdAt) {
    try {
      final createdAtDt = DateTime.parse(createdAt).toUtc();
      final now = DateTime.now().toUtc();
      final diff = now.difference(createdAtDt);
      final totalSeconds = diff.inSeconds;
      print('Local time calc: created_at=$createdAt, now=$now, total_seconds=$totalSeconds');
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

  Future<void> _toggleLike(int index) async {
    final idea = _ideas[index];
    final ideaId = idea['id'];
    try {
      final response = await ApiService().likeIdea(ideaId);
      setState(() {
        _ideas[index]['is_liked'] = response['is_liked'];
        _ideas[index]['like_count'] = response['like_count'];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Idea liked/unliked successfully',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          backgroundColor: Colors.purple,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: $e',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          backgroundColor: Colors.purple,
        ),
      );
    }
  }

  Widget _getWidgetOption(int index) {
    switch (index) {
      case 0:
        return _buildHomeContent();
      case 1:
        return CollaborationScreen();
      case 2:
        return IdeaPostScreen();
      case 3:
        return NotificationScreen();
      case 4:
        return ProfileScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildHomeContent() {
    if (_isLoadingMore && _ideas.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Colors.purple));
    }
    return RefreshIndicator(
      color: Colors.purple,
      onRefresh: _loadIdeas,
      child: _ideas.isEmpty
          ? const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No ideas available.',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ),
      )
          : ListView.builder(
        key: ValueKey(_ideas.length), // Force rebuild on list change
        controller: _scrollController,
        padding: const EdgeInsets.all(8.0),
        itemCount: _ideas.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < _ideas.length) {
            final idea = _ideas[index];
            final user = idea['user'];
            String timeSince = _calculateTimeSince(idea['created_at'] ?? '');
            final selectedCategories = (idea['categories'] as List<dynamic>? ?? []).cast<String>();
            print('Idea ${idea['id']}: Categories: $selectedCategories, Visibility: ${idea['visibility']}, time_since: $timeSince');
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              elevation: 6,
              shadowColor: Colors.black26,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
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
                              placeholder: (context, url) => const CircularProgressIndicator(color: Colors.purple),
                              errorWidget: (context, url, error) => Image.asset('assets/default.png', fit: BoxFit.cover),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${user['username']} • $timeSince • ${capitalize(idea['visibility'])}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          idea['user']['id'].toString() == _userId ? '/user_idea_details' : '/idea_details',
                          arguments: idea,
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            idea['title'],
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            idea['short_description'] ?? '',
                            style: const TextStyle(fontSize: 16, color: Colors.grey),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (selectedCategories.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4.0,
                        runSpacing: 2.0,
                        children: selectedCategories
                            .map<Widget>(
                              (cat) => Chip(
                            label: Text(
                              cat,
                              style: const TextStyle(fontSize: 10, color: Colors.black87),
                            ),
                            backgroundColor: Colors.blue[50],
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: -1),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                idea['is_liked'] ? Icons.favorite : Icons.favorite_border,
                                size: 18,
                                color: idea['is_liked'] ? Colors.purple : Colors.black87,
                              ),
                              onPressed: () => _toggleLike(index),
                              tooltip: 'Like',
                            ),
                            Text(
                              '${idea['like_count'] ?? 0}',
                              style: const TextStyle(fontSize: 14, color: Colors.black87),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Builder(
                              builder: (context) => IconButton(
                                icon: const Icon(Icons.comment, size: 18, color: Colors.black87),
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CommentsScreen(
                                        ideaId: idea['id'],
                                        ideaTitle: idea['title'],
                                      ),
                                    ),
                                  );
                                  if (result == true) {
                                    await _loadIdeas(); // Refresh ideas
                                  }
                                },
                                tooltip: 'Comment',
                              ),
                            ),
                            Text(
                              '${idea['comment_count'] ?? 0}',
                              style: const TextStyle(fontSize: 14, color: Colors.black87),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.group_add, size: 18, color: Colors.black87),
                          onPressed: () async {
                            try {
                              await ApiService().requestCollaboration(idea['id']);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Collaboration requested successfully!'),
                                  backgroundColor: Colors.purple,
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.purple,
                                ),
                              );
                            }
                          },
                          tooltip: 'Collaborate',
                        ),
                        IconButton(
                          icon: const Icon(Icons.share, size: 18, color: Colors.black87),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Share functionality not implemented yet',
                                  style: TextStyle(color: Colors.white, fontSize: 14),
                                ),
                                backgroundColor: Colors.purple,
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
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(color: Colors.purple),
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _loadIdeas() async {
    setState(() {
      _currentPage = 1;
      _ideas = [];
      _hasMore = true;
      _isLoadingMore = false;
    });
    await _loadUserInterests();
    await _loadIdeasPage();
    setState(() {
      if (_ideas.isNotEmpty) {
        final now = DateTime.now().toUtc();
        List<dynamic> recentIdeas = [];
        List<dynamic> interestIdeas = [];
        List<dynamic> otherIdeas = [];

        for (var idea in _ideas) {
          final createdAt = DateTime.tryParse(idea['created_at'] ?? '')?.toUtc();
          final categories = (idea['categories'] as List<dynamic>? ?? []).cast<String>();
          final isRecent = createdAt != null && now.difference(createdAt).inHours <= 24;
          final matchesInterest = _userInterests.isNotEmpty && categories.any((cat) => _userInterests.contains(cat));

          if (isRecent) {
            recentIdeas.add(idea);
          } else if (matchesInterest) {
            interestIdeas.add(idea);
          } else {
            otherIdeas.add(idea);
          }
        }

        // Sort with engagement and randomization
        recentIdeas.sort((a, b) {
          final aScore = (a['like_count'] ?? 0) + (a['comment_count'] ?? 0) + _random.nextInt(10);
          final bScore = (b['like_count'] ?? 0) + (b['comment_count'] ?? 0) + _random.nextInt(10);
          return bScore.compareTo(aScore); // Higher engagement first
        });
        interestIdeas.sort((a, b) {
          final aScore = (a['like_count'] ?? 0) + (a['comment_count'] ?? 0) + _random.nextInt(10);
          final bScore = (b['like_count'] ?? 0) + (b['comment_count'] ?? 0) + _random.nextInt(10);
          return bScore.compareTo(aScore);
        });
        otherIdeas.sort((a, b) {
          final aScore = (a['like_count'] ?? 0) + (a['comment_count'] ?? 0) + _random.nextInt(10);
          final bScore = (b['like_count'] ?? 0) + (b['comment_count'] ?? 0) + _random.nextInt(10);
          return bScore.compareTo(aScore);
        });

        _ideas = [
          ...recentIdeas,
          if (recentIdeas.isEmpty) ...interestIdeas,
          if (recentIdeas.isEmpty && interestIdeas.isEmpty) ...otherIdeas,
          if (recentIdeas.isNotEmpty) ...interestIdeas,
          if (recentIdeas.isNotEmpty || interestIdeas.isNotEmpty) ...otherIdeas,
        ];

        print('Sorted ideas: Recent=${recentIdeas.length}, Interest=${interestIdeas.length}, Other=${otherIdeas.length}');
        print('Final ideas list: ${_ideas.map((idea) => idea['id']).toList()}');
      }
    });
  }

  Future<void> _loadIdeasPage() async {
    if (!_hasMore || _isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
    });
    try {
      final response = await ApiService().makeAuthenticatedRequest(
        request: (token) => http.get(
          Uri.parse('${ApiService.baseUrl}ideas/list/?page=$_currentPage&t=${DateTime.now().millisecondsSinceEpoch}'),
          headers: {'Authorization': 'Bearer $token', 'Cache-Control': 'no-cache'},
        ),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> newIdeas = data['results'];
        print('API Response Categories: ${newIdeas.map((idea) => idea['categories']).toList()}');
        print('API Response Idea IDs: ${newIdeas.map((idea) => idea['id']).toList()}');
        setState(() {
          _ideas.addAll(newIdeas); // Include all ideas
          _hasMore = data['next'] != null;
          _isLoadingMore = false;
          for (var idea in newIdeas) {
            final user = idea['user'];
            print('User: ${user['username']}, Profile Pic: ${user['profile_pic']}');
            print('Constructed URL: ${user['profile_pic'] != null && user['profile_pic'].isNotEmpty && user['profile_pic'].startsWith('http') ? user['profile_pic'] : user['profile_pic'] != null && user['profile_pic'].isNotEmpty ? '${ApiService.baseUrl}${user['profile_pic'].startsWith('/') ? user['profile_pic'].substring(1) : user['profile_pic']}' : '${ApiService.baseUrl}media/profile_pics/default.jpg'}');
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to load ideas: ${response.body}',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              backgroundColor: Colors.purple,
            ),
          );
        }
        print('API error: ${response.statusCode} - ${response.body}');
        setState(() {
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (e.toString().contains('Authentication failed')) {
        await ApiService().clearTokens();
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error: $e',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              backgroundColor: Colors.purple,
            ),
          );
        }
        print('Error loading ideas: $e');
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMoreIdeas() async {
    setState(() {
      _currentPage++;
    });
    await _loadIdeasPage();
    setState(() {
      if (_ideas.isNotEmpty) {
        final now = DateTime.now().toUtc();
        List<dynamic> recentIdeas = [];
        List<dynamic> interestIdeas = [];
        List<dynamic> otherIdeas = [];

        for (var idea in _ideas) {
          final createdAt = DateTime.tryParse(idea['created_at'] ?? '')?.toUtc();
          final categories = (idea['categories'] as List<dynamic>? ?? []).cast<String>();
          final isRecent = createdAt != null && now.difference(createdAt).inHours <= 24;
          final matchesInterest = _userInterests.isNotEmpty && categories.any((cat) => _userInterests.contains(cat));

          if (isRecent) {
            recentIdeas.add(idea);
          } else if (matchesInterest) {
            interestIdeas.add(idea);
          } else {
            otherIdeas.add(idea);
          }
        }

        recentIdeas.sort((a, b) {
          final aScore = (a['like_count'] ?? 0) + (a['comment_count'] ?? 0) + _random.nextInt(10);
          final bScore = (b['like_count'] ?? 0) + (b['comment_count'] ?? 0) + _random.nextInt(10);
          return bScore.compareTo(aScore);
        });
        interestIdeas.sort((a, b) {
          final aScore = (a['like_count'] ?? 0) + (a['comment_count'] ?? 0) + _random.nextInt(10);
          final bScore = (b['like_count'] ?? 0) + (b['comment_count'] ?? 0) + _random.nextInt(10);
          return bScore.compareTo(aScore);
        });
        otherIdeas.sort((a, b) {
          final aScore = (a['like_count'] ?? 0) + (a['comment_count'] ?? 0) + _random.nextInt(10);
          final bScore = (b['like_count'] ?? 0) + (b['comment_count'] ?? 0) + _random.nextInt(10);
          return bScore.compareTo(aScore);
        });

        _ideas = [
          ...recentIdeas,
          if (recentIdeas.isEmpty) ...interestIdeas,
          if (recentIdeas.isEmpty && interestIdeas.isEmpty) ...otherIdeas,
          if (recentIdeas.isNotEmpty) ...interestIdeas,
          if (recentIdeas.isNotEmpty || interestIdeas.isNotEmpty) ...otherIdeas,
        ];

        print('Sorted ideas after loading more: Recent=${recentIdeas.length}, Interest=${interestIdeas.length}, Other=${otherIdeas.length}');
        print('Final ideas list: ${_ideas.map((idea) => idea['id']).toList()}');
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 0) _loadIdeas();
    });
  }

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _loadIdeas();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_isLoadingMore && _hasMore) {
        _loadMoreIdeas();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ThinkDrop',
          style: TextStyle(color: Color(0xFF281B60), fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.2),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFF281B60), size: 24),
            tooltip: 'Search',
            onPressed: () {
              Navigator.pushNamed(context, '/search');
            },
          ),
          IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFF281B60), size: 24),
            tooltip: 'Menu',
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      backgroundColor: Colors.white70,
      body: _getWidgetOption(_selectedIndex),
      bottomNavigationBar:  BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Collaboration'),
          BottomNavigationBarItem(icon: Icon(Icons.edit), label: 'Post'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Notification'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.purple,
        unselectedItemColor: Colors.black87,
        backgroundColor: Colors.white,
        elevation: 16,
        onTap: _onItemTapped,
      ),
    );
  }
}