import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import 'edit_profile_screen.dart';
import 'comments_screen.dart';

// Inline capitalize function
String capitalize(String s) => s.isEmpty ? s : "${s[0].toUpperCase()}${s.substring(1).toLowerCase()}";

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  String _firstName = '';
  String _lastName = '';
  String _bio = '';
  String _profession = '';
  List<String> _socialLinks = [];
  List<String> _skills = [];
  List<String> _interests = [];
  String _profilePicUrl = '';
  int? _userId;
  List<dynamic> _publicIdeas = [];
  List<dynamic> _partialIdeas = [];
  List<dynamic> _privateIdeas = [];
  int _publicPage = 1;
  int _partialPage = 1;
  int _privatePage = 1;
  bool _publicHasMore = true;
  bool _partialHasMore = true;
  bool _privateHasMore = true;
  bool _publicIsLoadingMore = false;
  bool _partialIsLoadingMore = false;
  bool _privateIsLoadingMore = false;
  ScrollController _publicScrollController = ScrollController();
  ScrollController _partialScrollController = ScrollController();
  ScrollController _privateScrollController = ScrollController();
  static const String rootUrl = 'http://10.0.2.2:8000';
  late TabController _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });
    _loadProfile();
    _publicScrollController.addListener(() {
      if (_publicScrollController.position.pixels >= _publicScrollController.position.maxScrollExtent - 200 &&
          !_publicIsLoadingMore &&
          _publicHasMore) {
        _loadMoreIdeas('PUBLIC');
      }
    });
    _partialScrollController.addListener(() {
      if (_partialScrollController.position.pixels >= _partialScrollController.position.maxScrollExtent - 200 &&
          !_partialIsLoadingMore &&
          _partialHasMore) {
        _loadMoreIdeas('PARTIAL');
      }
    });
    _privateScrollController.addListener(() {
      if (_privateScrollController.position.pixels >= _privateScrollController.position.maxScrollExtent - 200 &&
          !_privateIsLoadingMore &&
          _privateHasMore) {
        _loadMoreIdeas('PRIVATE');
      }
    });
  }

  // Calculate time since idea was posted
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

  // Toggle like status
  Future<void> _toggleLike(int index, String visibility) async {
    final ideas = visibility == 'PUBLIC'
        ? _publicIdeas
        : visibility == 'PARTIAL'
        ? _partialIdeas
        : _privateIdeas;
    final idea = ideas[index];
    final ideaId = idea['id'] as int;
    print('Toggling like for idea $ideaId in $visibility tab');
    setState(() {
      if (visibility == 'PUBLIC') _publicIsLoadingMore = true;
      if (visibility == 'PARTIAL') _partialIsLoadingMore = true;
      if (visibility == 'PRIVATE') _privateIsLoadingMore = true;
    });
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
    } finally {
      setState(() {
        if (visibility == 'PUBLIC') _publicIsLoadingMore = false;
        if (visibility == 'PARTIAL') _partialIsLoadingMore = false;
        if (visibility == 'PRIVATE') _privateIsLoadingMore = false;
      });
    }
  }

  // Share idea placeholder
  Future<void> _shareIdea(int index) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Share functionality not implemented yet',
          style: TextStyle(color: Colors.white, fontSize: 14),
        ),
        backgroundColor: Colors.purple[800],
      ),
    );
  }

  // Load user profile
  Future<void> _loadProfile() async {
    try {
      print('Starting profile load');
      final response = await ApiService().makeAuthenticatedRequest(
        request: (token) => http.get(
          Uri.parse('${ApiService.baseUrl}profile/'),
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      print('Profile API response status: ${response.statusCode}');
      print('Profile API response body: ${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _firstName = data['first_name']?.toString() ?? '';
            _lastName = data['last_name']?.toString() ?? '';
            _bio = data['bio']?.toString() ?? '';
            _profession = data['profession']?.toString() ?? '';
            _socialLinks = (data['social_links'] as List<dynamic>?)?.map((link) {
              return link is String ? link : link is Map ? link['url'].toString() : '';
            }).where((link) => link.isNotEmpty).toList() ?? [];
            _skills = List<String>.from(data['skills'] ?? []);
            _interests = List<String>.from(data['interests'] ?? []);
            _profilePicUrl = (data['profile_pic'] != null && data['profile_pic'].startsWith('http'))
                ? data['profile_pic']
                : data['profile_pic'] != null
                ? '$rootUrl${data['profile_pic']}'
                : '';
            _userId = data['id'] is int ? data['id'] : null;
            print('Loaded userId: $_userId');
            print('Social links loaded: $_socialLinks');
          });
          _loadIdeas();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to load profile: ${response.body}',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              backgroundColor: Colors.purple[800],
            ),
          );
        }
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
                'Error loading profile: $e',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              backgroundColor: Colors.purple[800],
            ),
          );
        }
        print('Error loading profile: $e');
      }
    }
  }

  // Load ideas for all visibility types
  Future<void> _loadIdeas() async {
    if (_userId == null) {
      print('Skipping _loadIdeas: userId is null');
      return;
    }
    print('Loading ideas for userId: $_userId');
    setState(() {
      _publicPage = 1;
      _partialPage = 1;
      _privatePage = 1;
      _publicIdeas.clear();
      _partialIdeas.clear();
      _privateIdeas.clear();
      _publicHasMore = true;
      _partialHasMore = true;
      _privateHasMore = true;
      _publicIsLoadingMore = false;
      _partialIsLoadingMore = false;
      _privateIsLoadingMore = false;
    });
    await Future.wait([
      _loadIdeasPage('PUBLIC'),
      _loadIdeasPage('PARTIAL'),
      _loadIdeasPage('PRIVATE'),
    ]);
  }

  // Load ideas page for a specific visibility
  Future<void> _loadIdeasPage(String visibility) async {
    if (_userId == null) {
      print('Skipping _loadIdeasPage: userId is null');
      return;
    }
    bool hasMore = visibility == 'PUBLIC' ? _publicHasMore : visibility == 'PARTIAL' ? _partialHasMore : _privateHasMore;
    bool isLoadingMore = visibility == 'PUBLIC'
        ? _publicIsLoadingMore
        : visibility == 'PARTIAL'
        ? _partialIsLoadingMore
        : _privateIsLoadingMore;
    if (!hasMore || isLoadingMore) {
      print('Skipping _loadIdeasPage: visibility=$visibility, hasMore=$hasMore, isLoadingMore=$isLoadingMore');
      return;
    }
    setState(() {
      if (visibility == 'PUBLIC') _publicIsLoadingMore = true;
      if (visibility == 'PARTIAL') _partialIsLoadingMore = true;
      if (visibility == 'PRIVATE') _privateIsLoadingMore = true;
    });
    try {
      final page = visibility == 'PUBLIC' ? _publicPage : visibility == 'PARTIAL' ? _partialPage : _privatePage;
      final url = '${ApiService.baseUrl}ideas/list/?user=$_userId&visibility=$visibility&page=$page';
      print('Fetching ideas: $url');
      final response = await ApiService().makeAuthenticatedRequest(
        request: (token) => http.get(
          Uri.parse(url),
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      print('API response for $visibility (status: ${response.statusCode}): ${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> newIdeas = data['results'] ?? [];
        if (newIdeas.isEmpty) {
          print('No new $visibility ideas returned');
        }
        for (var idea in newIdeas) {
          if (idea['user'] is! Map) {
            print('Invalid user data for idea ${idea['id']}: ${idea['user']}');
            idea['user'] = {'username': 'Unknown', 'profile_pic': null};
          }
          print('Idea ${idea['id']}: visibility=${idea['visibility']}, created_at=${idea['created_at']}');
        }
        newIdeas.sort((a, b) {
          final aDate = a['created_at'] != null ? DateTime.tryParse(a['created_at'] as String) ?? DateTime(0) : DateTime(0);
          final bDate = b['created_at'] != null ? DateTime.tryParse(b['created_at'] as String) ?? DateTime(0) : DateTime(0);
          return bDate.compareTo(aDate);
        });
        setState(() {
          if (visibility == 'PUBLIC') {
            _publicIdeas = List.from(_publicIdeas)..addAll(newIdeas);
            _publicHasMore = data['next'] != null;
            _publicIsLoadingMore = false;
            print('Added ${newIdeas.length} PUBLIC ideas, total: ${_publicIdeas.length}');
            print('Updated PUBLIC ideas list: ${_publicIdeas.map((idea) => idea['title']).toList()}');
          } else if (visibility == 'PARTIAL') {
            _partialIdeas = List.from(_partialIdeas)..addAll(newIdeas);
            _partialHasMore = data['next'] != null;
            _partialIsLoadingMore = false;
            print('Added ${newIdeas.length} PARTIAL ideas, total: ${_partialIdeas.length}');
            print('Updated PARTIAL ideas list: ${_partialIdeas.map((idea) => idea['title']).toList()}');
          } else {
            _privateIdeas = List.from(_privateIdeas)..addAll(newIdeas);
            _privateHasMore = data['next'] != null;
            _privateIsLoadingMore = false;
            print('Added ${newIdeas.length} PRIVATE ideas, total: ${_privateIdeas.length}');
            print('Updated PRIVATE ideas list: ${_privateIdeas.map((idea) => idea['title']).toList()}');
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to load $visibility ideas: ${response.body}',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              backgroundColor: Colors.purple[800],
            ),
          );
        }
        print('API error for $visibility: ${response.statusCode} - ${response.body}');
        setState(() {
          if (visibility == 'PUBLIC') _publicIsLoadingMore = false;
          if (visibility == 'PARTIAL') _partialIsLoadingMore = false;
          if (visibility == 'PRIVATE') _privateIsLoadingMore = false;
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
                'Error loading $visibility ideas: $e',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              backgroundColor: Colors.purple[800],
            ),
          );
        }
        print('Error loading $visibility ideas: $e');
        setState(() {
          if (visibility == 'PUBLIC') _publicIsLoadingMore = false;
          if (visibility == 'PARTIAL') _partialIsLoadingMore = false;
          if (visibility == 'PRIVATE') _privateIsLoadingMore = false;
        });
      }
    }
  }

  // Load more ideas for a specific visibility
  Future<void> _loadMoreIdeas(String visibility) async {
    setState(() {
      if (visibility == 'PUBLIC') _publicPage++;
      if (visibility == 'PARTIAL') _partialPage++;
      if (visibility == 'PRIVATE') _privatePage++;
    });
    await _loadIdeasPage(visibility);
  }

  @override
  void dispose() {
    _publicScrollController.dispose();
    _partialScrollController.dispose();
    _privateScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // Build idea list for a specific visibility
  Widget _buildIdeaList(List<dynamic> ideas, String visibility, ScrollController scrollController, bool isLoadingMore) {
    print('Building $visibility list with ${ideas.length} ideas: ${ideas.map((idea) => idea['title']).toList()}');
    return RefreshIndicator(
      color: Colors.purple[800],
      onRefresh: () async {
        await _loadIdeas();
      },
      child: ideas.isEmpty && !isLoadingMore
          ? SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Container(
          height: MediaQuery.of(context).size.height - 200,
          child: Center(
            child: Text(
              'No $visibility posts available.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ),
        ),
      )
          : ListView.builder(
        controller: scrollController,
        shrinkWrap: true,
        physics: AlwaysScrollableScrollPhysics(),
        itemCount: ideas.length + (isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < ideas.length) {
            final idea = ideas[index];
            final user = idea['user'];
            String timeSince = _calculateTimeSince(idea['created_at'] ?? '');
            final selectedCategories = (idea['categories'] as List<dynamic>? ?? []).cast<String>();
            return Card(
              margin: EdgeInsets.symmetric(vertical: 8.0),
              elevation: 4,
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          child: CachedNetworkImage(
                            imageUrl: user['profile_pic'] != null && user['profile_pic'].startsWith('http')
                                ? user['profile_pic']
                                : user['profile_pic'] != null
                                ? '${ApiService.baseUrl}${user['profile_pic']}'
                                : '${ApiService.baseUrl}/media/profile_pics/default.jpg',
                            imageBuilder: (context, imageProvider) => Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
                              ),
                            ),
                            placeholder: (context, url) => CircularProgressIndicator(
                              color: Colors.purple[800],
                            ),
                            errorWidget: (context, url, error) => Image.asset('assets/default.png', fit: BoxFit.cover),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${user['username']} • $timeSince • ${capitalize(idea['visibility'])}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        print('Navigating to user_idea_details with idea: ${idea['id']}');
                        Navigator.pushNamed(context, '/user_idea_details', arguments: idea);
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            idea['title'],
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 6),
                          Text(
                            idea['short_description'] ?? '',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[700],
                            ),
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
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.black87,
                            ),
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
                              onPressed: () => _toggleLike(index, visibility),
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
                          onPressed: () => _shareIdea(index),
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
                child: CircularProgressIndicator(
                  color: Colors.purple[800],
                ),
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
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Profile Header
          Stack(
            children: [
              Container(
                width: double.infinity,
                margin: EdgeInsets.only(left: 12.0, top: 12.0, right: 12.0),
                padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.purple[800]!,
                      Colors.purple[600]!,
                      Colors.indigo[900]!,
                    ],
                    stops: [0.0, 0.7, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple[800]!.withOpacity(0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundImage: _profilePicUrl.isNotEmpty ? NetworkImage(_profilePicUrl) : null,
                          child: _profilePicUrl.isEmpty ? Icon(Icons.person, size: 30, color: Colors.grey[600]) : null,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$_firstName $_lastName',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                _profession.isNotEmpty ? _profession : 'No profession set',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    if (_bio.isNotEmpty)
                      Container(
                        padding: EdgeInsets.only(left: 8, top: 6, bottom: 6, right: 6),
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(color: Colors.white, width: 3),
                          ),
                        ),
                        child: Text(
                          _bio,
                          style: TextStyle(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.left,
                        ),
                      ),
                    if (_bio.isNotEmpty) SizedBox(height: 8),
                    if (_socialLinks.isNotEmpty)
                      Wrap(
                        spacing: 6.0,
                        children: _socialLinks.map((link) {
                          return GestureDetector(
                            onTap: () async {
                              final url = Uri.parse(link);
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url, mode: LaunchMode.externalApplication);
                              } else {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Cannot open URL: $link',
                                        style: TextStyle(color: Colors.white, fontSize: 12),
                                      ),
                                      backgroundColor: Colors.purple[800],
                                    ),
                                  );
                                }
                              }
                            },
                            child: Text(
                              link,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    if (_socialLinks.isNotEmpty) SizedBox(height: 8),
                    if (_skills.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Skills',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 6),
                          Wrap(
                            spacing: 4.0,
                            runSpacing: 2.0,
                            children: _skills.map((skill) {
                              return Chip(
                                label: Text(
                                  skill,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.purple[900],
                                  ),
                                ),
                                backgroundColor: Colors.transparent,
                                side: BorderSide(color: Colors.white, width: 1),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Positioned(
                top: 50,
                right: 30,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/edit_profile');
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  ),
                  child: Text(
                    'Edit Profile',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Tabs
          TabBar(
            controller: _tabController,
            labelColor: Colors.purple[800],
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: Colors.purple[800],
            tabs: [
              Tab(text: 'Public'),
              Tab(text: 'Partial'),
              Tab(text: 'Private'),
            ],
          ),
          // Tab Content
          Expanded(
            child: IndexedStack(
              index: _currentTabIndex,
              children: [
                _buildIdeaList(_publicIdeas, 'PUBLIC', _publicScrollController, _publicIsLoadingMore),
                _buildIdeaList(_partialIdeas, 'PARTIAL', _partialScrollController, _partialIsLoadingMore),
                _buildIdeaList(_privateIdeas, 'PRIVATE', _privateScrollController, _privateIsLoadingMore),
              ],
            ),
          ),
        ],
      ),
    );
  }
}