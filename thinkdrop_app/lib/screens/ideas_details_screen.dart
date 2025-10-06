import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'comments_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class IdeaDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> idea; // Required initial idea data

  const IdeaDetailsScreen({Key? key, required this.idea}) : super(key: key);

  @override
  _IdeaDetailsScreenState createState() => _IdeaDetailsScreenState();
}

class _IdeaDetailsScreenState extends State<IdeaDetailsScreen> {
  String? _userId;
  bool _isLoading = false;
  late Map<String, dynamic> _idea;

  @override
  void initState() {
    super.initState();
    _idea = Map<String, dynamic>.from(widget.idea); // Deep copy to avoid modifying original
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('user_id');
      print('Loaded userId from SharedPreferences: $_userId');
    });
  }

  Future<void> _refreshCommentCount() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await ApiService().makeAuthenticatedRequest(
        request: (token) => http.get(
          Uri.parse('${ApiService.baseUrl}ideas/list/'),
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      print('API response for comment count: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final ideas = data['results'] as List<dynamic>;
        final idea = ideas.firstWhere(
              (i) => i['id'] == _idea['id'],
          orElse: () => _idea,
        );
        setState(() {
          _idea['comment_count'] = idea['comment_count'] ?? _idea['comment_count'] ?? 0;
          _isLoading = false;
        });
      } else {
        print('Failed to refresh comment count: ${response.body}');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error refreshing comment count: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleLike() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await ApiService().likeIdea(_idea['id'] as int);
      setState(() {
        _idea['is_liked'] = response['is_liked'];
        _idea['like_count'] = response['like_count'];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['message'],
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          backgroundColor: Colors.purple[800],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: $e',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          backgroundColor: Colors.purple[800],
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not open file: ${url.split('/').last}',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            backgroundColor: Colors.purple[800],
          ),
        );
      }
    }
  }

  Future<void> _reportIdea(String ideaId) async {
    TextEditingController reasonController = TextEditingController();
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Idea'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for reporting this idea:'),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: Colors.purple[800])),
          ),
          TextButton(
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.of(context).pop(true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please enter a reason'),
                    backgroundColor: Colors.purple[800],
                  ),
                );
              }
            },
            child: const Text('Submit', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });
      try {
        await ApiService().reportIdea(ideaId, reasonController.text.trim());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Idea reported successfully'),
              backgroundColor: Colors.purple[800],
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to report idea: $e'),
              backgroundColor: Colors.purple[800],
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
    reasonController.dispose();
  }

  Future<void> _collaborateIdea(String ideaId) async {
    try {
      await ApiService().requestCollaboration(int.parse(ideaId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Collaboration requested successfully! Check notifications.'),
          backgroundColor: Colors.purple[800],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error requesting collaboration: $e'),
          backgroundColor: Colors.purple[800],
        ),
      );
    }
  }

  Future<void> _shareIdea() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Share functionality not implemented yet',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        backgroundColor: Colors.purple[800],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPublic = _idea['visibility']?.toString().toUpperCase() == 'PUBLIC';
    final isPoster = _userId != null && _idea['user_id']?.toString() == _userId;
    print('Idea user_id: ${_idea['user_id']} (type: ${_idea['user_id'].runtimeType})');
    print('Stored userId: $_userId (type: ${_userId.runtimeType})');
    print('isPoster: $isPoster');
    final canViewDetails = isPoster || isPublic;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _idea['title'] ?? 'Idea Details',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.purple[800],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!isPoster)
            IconButton(
              icon: Icon(
                Icons.group_add,
                size: 18,
                color: isPoster ? Colors.grey : Colors.black87,
              ),
              onPressed: isPoster ? null : () => _collaborateIdea(_idea['id'].toString()),
              tooltip: isPoster ? 'Cannot collaborate on your own idea' : 'Collaborate',
            ),
          if (!isPoster)
            IconButton(
              icon: const Icon(Icons.report, color: Colors.red),
              onPressed: () => _reportIdea(_idea['id'].toString()),
              tooltip: 'Report Idea',
            ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                Text(
                  _idea['title'] ?? '',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                if (_idea['short_description'] != null && _idea['short_description'].isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _idea['short_description'],
                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                  ),
                const SizedBox(height: 12),
                if ((_idea['categories'] as List<dynamic>?)?.isNotEmpty ?? false)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Categories',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: (_idea['categories'] as List<dynamic>)
                            .cast<String>()
                            .map((cat) => Chip(
                          label: Text(
                            cat,
                            style: const TextStyle(color: Colors.black87),
                          ),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Colors.purple),
                        ))
                            .toList(),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                if (canViewDetails && _idea['description'] != null && _idea['description'].isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _idea['description'],
                          style: const TextStyle(fontSize: 16, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                if (canViewDetails && _idea['files'] != null && (_idea['files'] as List<dynamic>).isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      const Text(
                        'Attached Files',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: (_idea['files'] as List<dynamic>)
                            .cast<String>()
                            .map((fileUrl) => ActionChip(
                          label: Text(
                            fileUrl.split('/').last,
                            style: const TextStyle(color: Colors.black87),
                          ),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Colors.purple),
                          onPressed: () => _launchUrl(fileUrl),
                        ))
                            .toList(),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (_isLoading)
            Center(
              child: CircularProgressIndicator(
                color: Colors.purple[800],
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        elevation: 8,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _idea['is_liked'] ?? false ? Icons.favorite : Icons.favorite_border,
                      size: 18,
                      color: _idea['is_liked'] ?? false ? Colors.purple[800] : Colors.black87,
                    ),
                    onPressed: _toggleLike,
                    tooltip: 'Like',
                  ),
                  Text(
                    '${_idea['like_count'] ?? 0}',
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.comment, size: 18, color: Colors.black87),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CommentsScreen(
                            ideaId: _idea['id'],
                            ideaTitle: _idea['title'],
                          ),
                        ),
                      );
                      if (result == true) {
                        await _refreshCommentCount();
                      }
                    },
                    tooltip: 'Comment',
                  ),
                  Text(
                    '${_idea['comment_count'] ?? 0}',
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: Icon(
                  Icons.group_add,
                  size: 18,
                  color: isPoster ? Colors.grey : Colors.black87,
                ),
                onPressed: isPoster ? null : () => _collaborateIdea(_idea['id'].toString()),
                tooltip: isPoster ? 'Cannot collaborate on your own idea' : 'Collaborate',
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.share, size: 18, color: Colors.black87),
                onPressed: _shareIdea,
                tooltip: 'Share',
              ),
            ],
          ),
        ),
      ),
    );
  }
}