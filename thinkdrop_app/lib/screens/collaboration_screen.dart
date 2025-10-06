import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';

class CollaborationScreen extends StatefulWidget {
  @override
  _CollaborationScreenState createState() => _CollaborationScreenState();
}

class _CollaborationScreenState extends State<CollaborationScreen> {
  String _userName = 'User';
  String? _userId;
  List<dynamic> _collaborations = [];
  Map<int, Map<String, dynamic>> _groupedIdeas = {};

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadUserId();
    _loadCollaborations();
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null || token.isEmpty) return;
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}profile/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _userName = '${data['first_name'] ?? 'User'} ${data['last_name'] ?? ''}'.trim();
        });
      }
    } catch (e) {
      print('Error loading username: $e');
    }
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('user_id');
    });
  }

  Future<void> _loadCollaborations() async {
    try {
      final response = await ApiService().makeAuthenticatedRequest<http.Response>(
        request: (token) => http.get(
          Uri.parse('${ApiService.baseUrl}collaborations/'),
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      if (response.statusCode == 200) {
        _collaborations = json.decode(response.body);
        _groupCollaborations();
        setState(() {});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load collaborations: ${response.body}')),
        );
      }
    } catch (e) {
      print('Error loading collabs: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading collaborations: $e')),
      );
    }
  }

  void _groupCollaborations() {
    _groupedIdeas.clear();
    Set<String> allCollaborators = {};  // Track unique collaborators for the idea
    for (var col in _collaborations) {
      final idea = col['idea'] as Map<String, dynamic>?;
      if (idea != null && col['status'] == 'accepted') {
        final ideaId = idea['id'] as int;
        if (!_groupedIdeas.containsKey(ideaId)) {
          _groupedIdeas[ideaId] = {
            'idea': idea,
            'collaborators': <String>[],  // Will populate below
            'isOwner': _userId != null && idea['user']?['id']?.toString() == _userId,
          };
        }
        // Always add collaborator username (now backend returns all)
        final collabUsername = col['collaborator']['username'] ?? 'Unknown';
        allCollaborators.add(collabUsername);
      }
    }

    // For each group, set collaborators (all unique except current user)
    _groupedIdeas.forEach((ideaId, group) {
      final currentUser = _userName;  // Or use _userId to compare
      final idea = group['idea'] as Map<String, dynamic>;
      final ownerUsername = idea['user']?['username'] ?? 'Unknown';

      List<String> finalCollabs = allCollaborators
          .where((username) => username != currentUser && username != ownerUsername)  // Exclude self and owner
          .toList();

      // If viewing as collaborator, include owner in display (handled in ChatScreen)
      group['allMembers'] = [...finalCollabs, ownerUsername];  // All members for ChatScreen
      group['collaborators'] = finalCollabs;  // Only non-owner collaborators
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Collaborations'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.purple[800],
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadCollaborations,
        child: _groupedIdeas.isEmpty
            ? Center(child: Text('No collaborations yet'))
            : ListView.builder(
          itemCount: _groupedIdeas.length,
          itemBuilder: (context, index) {
            final ideaId = _groupedIdeas.keys.elementAt(index);
            final group = _groupedIdeas[ideaId]!;
            final idea = group['idea'] as Map<String, dynamic>;
            final collaborators = group['collaborators'] as List;
            final isOwner = group['isOwner'] as bool;
            final ownerName = idea['user']?['username'] ?? 'Unknown';
            return ListTile(
              title: Text(idea['title'] ?? 'Unknown Idea'),
              trailing: Icon(Icons.chat, color: Colors.purple[800]),
              onTap: () {
                final group = _groupedIdeas[ideaId]!;
                final idea = group['idea'] as Map<String, dynamic>;
                final collaborators = group['collaborators'] as List<String>;
                final isOwner = group['isOwner'] as bool;
                final ownerName = idea['user']?['username'] ?? 'Unknown';
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      ideaId: ideaId,
                      ideaTitle: idea['title'] as String,
                      collaborators: collaborators,
                      ownerName: ownerName,
                      isOwner: isOwner,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}