import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'comments_screen.dart';

class UserIdeaDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> idea; // Required idea data

  const UserIdeaDetailsScreen({required this.idea, super.key});

  @override
  _UserIdeaDetailsScreenState createState() => _UserIdeaDetailsScreenState();
}

class _UserIdeaDetailsScreenState extends State<UserIdeaDetailsScreen> {
  String? _userId;
  bool _isLoading = false;
  late Map<String, dynamic> _idea;

  @override
  void initState() {
    super.initState();
    _idea = widget.idea; // Use passed idea
    _loadUserId();
  }

  // Load user ID from SharedPreferences
  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('user_id');
      print('Loaded userId from SharedPreferences: $_userId');
    });
  }

  // Calculate time_since locally from created_at
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
        final minutes = totalSeconds ~/ 60;
        return '${minutes}m';
      } else if (totalSeconds < 86400) {
        final hours = totalSeconds ~/ 3600;
        return '${hours}h';
      } else {
        final days = totalSeconds ~/ 86400;
        return '${days}d';
      }
    } catch (e) {
      print('Error parsing created_at: $createdAt, error: $e');
      return 'Just now';
    }
  }

  // Launch file URL
  Future<void> _launchUrl(String url) async {
    print('Attempting to launch URL: $url');
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Could not open file',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            backgroundColor: Colors.purple[800],
          ),
        );
      }
    }
  }

  // Delete idea with confirmation dialog
  Future<void> _deleteIdea(String ideaId) async {
    print('Delete button pressed for idea ID: $ideaId');
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => const AlertDialog(
        title: Text('Delete Idea'),
        content: Text('Are you sure you want to delete this idea? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: null,
            child: Text('Cancel', style: TextStyle(color: Colors.purple)),
          ),
          TextButton(
            onPressed: null,
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });
      try {
        print('Calling ApiService.deleteIdea for idea ID: $ideaId');
        await ApiService().deleteIdea(ideaId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Idea deleted successfully',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              backgroundColor: Colors.purple[800],
            ),
          );
          print('Idea deleted successfully, navigating back');
          Navigator.pop(context, true); // Return to ProfileScreen to refresh
        }
      } catch (e) {
        print('Error deleting idea: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to delete idea: $e',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
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
  }

  // Toggle like status
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

  // Share idea placeholder
  Future<void> _shareIdea() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Share functionality not implemented yet',
          style: TextStyle(color: Colors.white, fontSize: 14),
        ),
        backgroundColor: Colors.purple[800],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String timeSince = _idea['time_since'] ?? 'Just now';
    if (timeSince == '0h' || timeSince == 'Just now') {
      timeSince = _calculateTimeSince(_idea['created_at'] ?? '');
    }
    print('Idea ${_idea['id']}: created_at: ${_idea['created_at']}, time_since: $timeSince');

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
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              print('Edit button pressed');
              Navigator.pushNamed(context, '/edit_idea', arguments: _idea);
            },
            tooltip: 'Edit Idea',
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _deleteIdea(_idea['id'].toString()),
            tooltip: 'Delete Idea',
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
                Text(
                  '${_idea['user']?['username'] ?? 'Unknown'} • $timeSince',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
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
                            style: TextStyle(color: Colors.purple[800]),
                          ),
                          backgroundColor: Colors.white,
                          side: BorderSide(color: Colors.purple[800]!),
                        ))
                            .toList(),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                if (_idea['description'] != null && _idea['description'].isNotEmpty)
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
                if (_idea['files'] != null && (_idea['files'] as List<dynamic>).isNotEmpty)
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
                            style: TextStyle(color: Colors.purple[800]),
                          ),
                          backgroundColor: Colors.white,
                          side: BorderSide(color: Colors.purple[800]!),
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
                      _idea['is_liked'] ? Icons.favorite : Icons.favorite_border,
                      size: 18,
                      color: _idea['is_liked'] ? Colors.purple[800] : Colors.black87,
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
              IconButton(
                icon: const Icon(Icons.comment, size: 18, color: Colors.black87),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CommentsScreen(
                        ideaId: _idea['id'],
                        ideaTitle: _idea['title'],
                      ),
                    ),
                  );
                },
                tooltip: 'Comment',
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.group_add, size: 18, color: Colors.black87),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Collaborate functionality not implemented yet',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      backgroundColor: Colors.purple[800],
                    ),
                  );
                },
                tooltip: 'Collaborate',
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