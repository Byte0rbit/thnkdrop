import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';  // For _loadUserId
import 'chat_screen.dart';

class GroupDetailsScreen extends StatefulWidget {
  final int ideaId;
  final String ideaTitle;

  const GroupDetailsScreen({
    super.key,
    required this.ideaId,
    required this.ideaTitle,
  });

  @override
  _GroupDetailsScreenState createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  List<dynamic> _members = [];
  bool _isLoading = true;
  String? _currentUserId;
  bool _isGroupOwner = false;

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _loadMembers();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id');
    setState(() {});
  }

  Future<void> _loadMembers() async {
    try {
      setState(() { _isLoading = true; });
      _members = await ApiService().getGroupMembers(widget.ideaId);

      // Set owner flag: Check if current user is group owner
      if (_currentUserId != null) {
        _isGroupOwner = _members.any((member) =>
        (member['id'] as int).toString() == _currentUserId && (member['is_owner'] as bool) == true
        );
      }

      setState(() { _isLoading = false; });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading members: $e')),
      );
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _removeMember(int memberId) async {
    // Find collab_id for this member (loop through collaborations or call API)
    try {
      await ApiService().removeMemberFromGroup(widget.ideaId, memberId);
      _loadMembers();  // Refresh list
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Member removed')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing member: $e')),
      );
    }
  }

  Future<void> _leaveGroup() async {
    try {
      await ApiService().leaveGroup(widget.ideaId);
      // Redirect to CollaborationScreen instead of pop
      Navigator.pushReplacementNamed(context, '/collaboration');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You left the group')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error leaving group: $e')),
      );
    }
  }

  Widget _buildMemberTile(dynamic member) {
    final memberIsOwner = member['is_owner'] as bool;  // For star badge only
    final isCurrentUser = (_currentUserId != null && (member['id'] as int).toString() == _currentUserId);
    final showRemove = _isGroupOwner && !isCurrentUser;  // Show remove if CURRENT USER is owner, member is not self

    return ListTile(
      leading: CircleAvatar(
        child: Text((member['username'] as String)[0].toUpperCase()),  // First letter avatar
      ),
      title: Text(member['username'] as String),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (memberIsOwner) ...[  // Star badge for the actual owner member
            Icon(Icons.star, color: Colors.amber, size: 20),
            SizedBox(width: 8),
          ],
          if (showRemove)  // Remove button for owner on other members
            IconButton(
              icon: Icon(Icons.remove_circle, color: Colors.red),
              onPressed: () => _removeMember(member['id'] as int),
              tooltip: 'Remove Member',
            ),
          if (isCurrentUser && !_isGroupOwner)  // Leave button for non-owners only
            IconButton(
              icon: Icon(Icons.exit_to_app, color: Colors.grey),
              onPressed: _leaveGroup,
              tooltip: 'Leave Group',
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.ideaTitle),
        backgroundColor: Colors.white,
        foregroundColor: Colors.purple[800],
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.chat),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    ideaId: widget.ideaId,
                    ideaTitle: widget.ideaTitle,
                  ),
                ),
              );
            },
            tooltip: 'Open Chat',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Group Members (${_members.length})',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _members.length,
              itemBuilder: (context, index) {
                return _buildMemberTile(_members[index]);
              },
            ),
          ),
          if (_currentUserId != null && !_isGroupOwner)  // Only show for non-owners
            Padding(
              padding: EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: _leaveGroup,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text('Leave Group', style: TextStyle(color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }
}