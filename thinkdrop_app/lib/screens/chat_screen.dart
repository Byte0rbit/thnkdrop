import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';
import 'group_details_screen.dart';

class ChatScreen extends StatefulWidget {
  final int ideaId;
  final String ideaTitle;
  final List<String>? collaborators;  // Optional: List of collaborator usernames
  final String? ownerName;  // Optional: Owner username
  final bool? isOwner;  // Optional: Whether current user is owner

  const ChatScreen({
    super.key,
    required this.ideaId,
    required this.ideaTitle,
    this.collaborators,
    this.ownerName,
    this.isOwner,
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<dynamic> _messages = [];
  final TextEditingController _controller = TextEditingController();
  Timer? _timer;

  Future<void> _loadMessages() async {
    try {
      _messages = await ApiService().getMessages(widget.ideaId);
      setState(() {});
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading messages: $e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _timer = Timer.periodic(Duration(seconds: 10), (timer) => _loadMessages());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Clean, safe logic for group members (no duplication)
    Widget membersWidget;
    if (widget.collaborators != null || widget.ownerName != null) {
      final ownerText = widget.ownerName ?? 'Unknown';
      // Safe null handling: Treat null as empty list
      final collabsList = widget.collaborators ?? <String>[];
      final collabsText = collabsList.isEmpty
          ? 'None'
          : collabsList.join(', ');
      final membersText = 'Owner: $ownerText • Collaborators: $collabsText';

      membersWidget = Container(
        width: double.infinity,
        padding: EdgeInsets.all(12.0),
        color: Colors.grey[100],
        child: Center(
          child: Text(
            membersText,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else {
      // Fallback for existing routes (no group info)
      membersWidget = Container(
        width: double.infinity,
        padding: EdgeInsets.all(8.0),
        color: Colors.grey[100],
        child: Center(
          child: Text(
            'Group Chat',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            // Tap title to go to GroupDetailsScreen
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GroupDetailsScreen(
                  ideaId: widget.ideaId,
                  ideaTitle: widget.ideaTitle,
                ),
              ),
            );
          },
          child: Text(
            'Chat for ${widget.ideaTitle}',
            style: TextStyle(color: Colors.purple[800]),
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.purple[800],
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return ListTile(
                  title: Text(msg['sender']['username'] ?? 'Unknown'),
                  subtitle: Text(msg['content'] ?? ''),
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
                    controller: _controller,
                    decoration: InputDecoration(hintText: 'Type message...'),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () async {
                    if (_controller.text.isNotEmpty) {
                      await ApiService().sendMessage(widget.ideaId, _controller.text);
                      _controller.clear();
                      _loadMessages();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}