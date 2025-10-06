import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class CommentsScreen extends StatefulWidget {
  final int ideaId;
  final String ideaTitle;

  CommentsScreen({required this.ideaId, required this.ideaTitle});

  @override
  _CommentsScreenState createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  List<Comment> _comments = [];
  bool _isLoading = true;
  final TextEditingController _commentController = TextEditingController();
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _loadComments();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('user_id');
    });
  }

  Future<void> _loadComments() async {
    try {
      final comments = await ApiService().getComments(widget.ideaId);
      setState(() {
        _comments = comments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading comments: $e')),
      );
    }
  }

  Future<void> _addComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    try {
      final newComment = await ApiService().postComment(widget.ideaId, content);
      setState(() {
        _comments.add(newComment);
        _commentController.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding comment: $e')),
      );
    }
  }

  Future<void> _deleteComment(int commentId) async {
    // Show confirmation dialog
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Comment'),
        content: Text('Are you sure you want to delete this comment? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: Colors.purple[800])),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return; // Exit if user cancels

    try {
      await ApiService().deleteComment(commentId);
      setState(() {
        _comments.removeWhere((comment) => comment.id == commentId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Comment deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting comment: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Comments on "${widget.ideaTitle}"'),
        backgroundColor: Colors.purple[800],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.purple[800]))
          : Column(
        children: [
          Expanded(
            child: _comments.isEmpty
                ? Center(child: Text('No comments yet. Be the first!'))
                : ListView.builder(
              itemCount: _comments.length,
              itemBuilder: (context, index) {
                final comment = _comments[index];
                final isOwnComment = comment.user['id'].toString() == _userId;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: comment.user['profile_pic'] != null &&
                        comment.user['profile_pic'].isNotEmpty
                        ? NetworkImage(comment.user['profile_pic'])
                        : AssetImage('assets/default_profile_pic.png') as ImageProvider,
                    onBackgroundImageError: (error, stackTrace) {
                      // Log error for debugging
                      print('Image load error: $error');
                    },
                    backgroundColor: Colors.grey[300], // Fallback color
                  ),
                  title: Text(
                    comment.user['username'] ?? 'Unknown',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(comment.content),
                  trailing: isOwnComment
                      ? IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteComment(comment.id),
                  )
                      : null,
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send, color: Colors.purple[800]),
                  onPressed: _addComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}