import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'profile_view_screen.dart';
import 'collaboration_screen.dart'; // Add this import

class NotificationScreen extends StatefulWidget {
  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<dynamic> _notifications = [];
  String? _userId;

  Future<void> _loadNotifications() async {
    try {
      _notifications = await ApiService().getNotifications();
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading notifications: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id');
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.purple[800],
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        child: _notifications.isEmpty
            ? Center(child: Text('No notifications yet'))
            : ListView.builder(
          itemCount: _notifications.length,
          itemBuilder: (context, index) {
            final notif = _notifications[index];
            return Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),  // Modern spacing
              elevation: 2,  // Subtle shadow
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),  // Rounded corners
              child: InkWell(  // Tap for popup
                onTap: () {
                  _showNotificationPopup(context, notif);  // New: Show popup on tile tap
                },
                child: ListTile(
                  contentPadding: EdgeInsets.all(16),  // Inner padding
                  title: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (notif['sender'] != null && notif['sender']['id'] != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProfileViewScreen(user: notif['sender']),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Sender profile unavailable')),
                            );
                          }
                        },
                        child: Text(
                          notif['sender']?['username'] ?? 'Unknown',
                          style: TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(child: Text(notif['message'] ?? 'No message')),
                    ],
                  ),
                  subtitle: Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      notif['type'] ?? 'Unknown',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                  trailing: notif['type'] == 'collab_request' &&
                      !notif['is_read'] &&
                      notif['collab_id'] != null
                      ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          try {
                            await ApiService().approveRejectCollaboration(
                                notif['collab_id'] as int, 'approve');
                            await ApiService().markNotificationRead(notif['id']);
                            _loadNotifications();
                            await Future.delayed(Duration(milliseconds: 500));
                            try {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CollaborationScreen(),
                                ),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Collaboration approved!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Navigation error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error approving: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: Text('Approve', style: TextStyle(fontSize: 12)),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          try {
                            await ApiService().approveRejectCollaboration(
                                notif['collab_id'] as int, 'reject');
                            await ApiService().markNotificationRead(notif['id']);
                            _loadNotifications();
                            await Future.delayed(Duration(milliseconds: 500));
                            try {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CollaborationScreen(),
                                ),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Collaboration rejected!'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Navigation error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error rejecting: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: Text('Reject', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  )
                      : null,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
  void _showNotificationPopup(BuildContext context, dynamic notif) async {
    // Mark as read if unread
    if (!notif['is_read']) {
      try {
        await ApiService().markNotificationRead(notif['id']);
        _loadNotifications();  // Refresh list
      } catch (e) {
        print('Error marking read in popup: $e');
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),  // Rounded
          backgroundColor: Colors.white,
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.purple[100],
                child: Text(
                  (notif['sender']?['username'] ?? 'U')[0].toUpperCase(),
                  style: TextStyle(color: Colors.purple[800]),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notif['sender']?['username'] ?? 'Unknown',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.purple[800],
                      ),
                    ),
                    Text(
                      notif['type'] ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  notif['message'] ?? 'No message',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Time: ${notif['created_at'] ?? 'Unknown'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close', style: TextStyle(color: Colors.purple[800])),
            ),
          ],
        );
      },
    );
  }
}