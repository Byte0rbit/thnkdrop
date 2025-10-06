import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class Comment {
  final int id;
  final String content;
  final Map<String, dynamic> user;
  final String createdAt;

  Comment({
    required this.id,
    required this.content,
    required this.user,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'],
      content: json['content'],
      user: json['user'],
      createdAt: json['created_at'],
    );
  }
}
class ApiService {
  static const String baseUrl = 'http://10.0.2.2:8000/api/';

  Future<Map<String, dynamic>> register(Map<String, dynamic> data) async {
    print('Sending register data: $data');
    final response = await http.post(
      Uri.parse('${baseUrl}register/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    print('Register response status: ${response.statusCode}');
    print('Register response body: ${response.body}');
    if (response.statusCode == 201) {
      await _saveToken(json.decode(response.body));
      return json.decode(response.body);
    } else {
      throw Exception('Failed to register: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('${baseUrl}login/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );
    print('Login response status: ${response.statusCode}');
    print('Login response body: ${response.body}');
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is Map<String, dynamic> &&
          data.containsKey('access') &&
          data.containsKey('refresh') &&
          data.containsKey('user_id')) {
        await _saveToken(data);
        return data;
      } else {
        throw Exception('Invalid token response format: ${response.body}');
      }
    } else {
      throw Exception('Failed to login: ${response.body}');
    }
  }

  Future<List<String>> getCategories() async {
    try {
      final response = await makeAuthenticatedRequest(
        request: (token) => http.get(
          Uri.parse('${baseUrl}categories/'),
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => item['name'] as String).toList();
      } else {
        throw Exception('Failed to fetch categories: ${response.body}');
      }
    } catch (e) {
      print('Error fetching categories: $e');
      throw Exception('Error fetching categories: $e');
    }
  }

  Future<String> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('access_token');
    String? refreshToken = prefs.getString('refresh_token');

    if (accessToken == null || accessToken.isEmpty) {
      if (refreshToken == null || refreshToken.isEmpty) {
        await clearTokens();
        throw Exception('No valid tokens available');
      }
      return await _refreshAccessToken(refreshToken);
    }
    return accessToken;
  }

  Future<String> _refreshAccessToken(String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse('${baseUrl}token/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'refresh': refreshToken}),
      );
      print('Refresh token response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final newAccessToken = data['access'] as String?;
        if (newAccessToken != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('access_token', newAccessToken);
          return newAccessToken;
        }
        throw Exception('No access token in refresh response');
      } else {
        await clearTokens();
        throw Exception('Token refresh failed: ${response.body}');
      }
    } catch (e) {
      await clearTokens();
      print('Refresh failed: $e');
      throw Exception('Token refresh failed');
    }
  }

  Future<T> makeAuthenticatedRequest<T>({
    required Future<T> Function(String) request,
  }) async {
    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        final token = await getAccessToken();
        final response = await request(token);
        if ((response is http.Response && response.statusCode == 401) ||
            (response is http.StreamedResponse && response.statusCode == 401)) {
          if (attempt == 2) {
            await clearTokens();
            throw Exception('Authentication failed');
          }
          final newToken = await _refreshAccessToken((await SharedPreferences.getInstance()).getString('refresh_token') ?? '');
          return await request(newToken);
        }
        return response;
      } catch (e) {
        if (e.toString().contains('Token refresh failed') || e.toString().contains('No valid tokens')) {
          throw Exception('Authentication failed');
        }
        if (attempt == 2) {
          throw e;
        }
      }
    }
    throw Exception('Request failed after retries');
  }

  Future<void> _saveToken(Map<String, dynamic> tokens) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', tokens['access'] as String);
    await prefs.setString('refresh_token', tokens['refresh'] as String);
    if (tokens.containsKey('user_id')) {
      await prefs.setString('user_id', tokens['user_id'].toString());
      print('Saved user_id: ${tokens['user_id']}');
    }
  }

  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_id');
  }

  Future<void> updateIdea({
    required String ideaId,
    required String title,
    required String shortDescription,
    required String description,
    required String visibility,
    required List<String> categories,
    required List<File> files,
    required List<String> existingFiles,
  }) async {
    try {
      final response = await makeAuthenticatedRequest<http.StreamedResponse>(
        request: (token) async {
          var request = http.MultipartRequest(
            'PATCH',
            Uri.parse('${baseUrl}ideas/$ideaId/'),
          )..headers['Authorization'] = 'Bearer $token';
          request.fields['title'] = title;
          request.fields['short_description'] = shortDescription;
          request.fields['description'] = description;
          request.fields['visibility'] = visibility;
          request.fields['categories'] = json.encode(categories);
          request.fields['existing_files'] = json.encode(existingFiles);
          for (var file in files) {
            request.files.add(await http.MultipartFile.fromPath('files', file.path));
          }
          return await request.send();
        },
      );
      final respStr = await response.stream.bytesToString();
      print('Update idea response: ${response.statusCode}, $respStr');
      if (response.statusCode != 200) {
        throw Exception('Failed to update idea: $respStr');
      }
    } catch (e) {
      print('Error updating idea: $e');
      throw Exception('Error updating idea: $e');
    }
  }

  Future<void> deleteIdea(String ideaId) async {
    try {
      final response = await makeAuthenticatedRequest<http.Response>(
        request: (token) => http.delete(
          Uri.parse('${baseUrl}ideas/$ideaId/delete/'),
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      if (response.statusCode != 204) {
        throw Exception('Failed to delete idea: ${response.body}');
      }
    } catch (e) {
      print('Error deleting idea: $e');
      throw Exception('Error deleting idea: $e');
    }
  }

  Future<void> reportIdea(String ideaId, String reason) async {
    try {
      final response = await makeAuthenticatedRequest<http.Response>(
        request: (token) => http.post(
          Uri.parse('${baseUrl}reports/'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'idea': ideaId,
            'reason': reason,
          }),
        ),
      );
      if (response.statusCode != 201) {
        throw Exception('Failed to report idea: ${response.body}');
      }
    } catch (e) {
      print('Error reporting idea: $e');
      throw Exception('Error reporting idea: $e');
    }
  }

  Future<Map<String, dynamic>> likeIdea(int ideaId) async {
    try {
      final response = await makeAuthenticatedRequest<http.Response>(
        request: (token) => http.post(
          Uri.parse('${baseUrl}ideas/like/$ideaId/'),
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to like/unlike idea: ${response.body}');
      }
    } catch (e) {
      print('Error liking/unliking idea: $e');
      throw Exception('Error liking/unliking idea: $e');
    }
  }

  Future<Map<String, dynamic>> changePassword(String oldPassword, String newPassword) async {
    try {
      final response = await makeAuthenticatedRequest<http.Response>(
        request: (token) => http.post(
          Uri.parse('${baseUrl}auth/change-password/'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'old_password': oldPassword,
            'new_password': newPassword,
          }),
        ),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to change password: ${response.body}');
      }
    } catch (e) {
      print('Error changing password: $e');
      throw Exception('Error changing password: $e');
    }
  }

  Future<void> deleteAccount() async {
    try {
      final response = await makeAuthenticatedRequest<http.Response>(
        request: (token) => http.delete(
          Uri.parse('${baseUrl}auth/delete-account/'),
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      if (response.statusCode != 204) {
        throw Exception('Failed to delete account: ${response.body}');
      }
      await clearTokens();
    } catch (e) {
      print('Error deleting account: $e');
      throw Exception('Error deleting account: $e');
    }
  }

  Future<Map<String, dynamic>> search(String query) async {
    try {
      final response = await makeAuthenticatedRequest<http.Response>(
        request: (token) => http.get(
          Uri.parse('${baseUrl}search/?q=$query'),
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to search: ${response.body}');
      }
    } catch (e) {
      print('Error searching: $e');
      throw Exception('Error searching: $e');
    }
  }
  Future<List<Comment>> getComments(int ideaId) async {
    try {
      final response = await makeAuthenticatedRequest<http.Response>(
        request: (token) => http.get(
          Uri.parse('${baseUrl}ideas/$ideaId/comments/'),
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Comment.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load comments: ${response.body}');
      }
    } catch (e) {
      print('Error loading comments: $e');
      throw Exception('Error loading comments: $e');
    }
  }

  Future<Comment> postComment(int ideaId, String content) async {
    try {
      final response = await makeAuthenticatedRequest<http.Response>(
        request: (token) => http.post(
          Uri.parse('${baseUrl}ideas/$ideaId/comments/'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode({'content': content}),
        ),
      );
      if (response.statusCode == 201) {
        return Comment.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to post comment: ${response.body}');
      }
    } catch (e) {
      print('Error posting comment: $e');
      throw Exception('Error posting comment: $e');
    }
  }

  Future<void> deleteComment(int commentId) async {
    try {
      final response = await makeAuthenticatedRequest<http.Response>(
        request: (token) => http.delete(
          Uri.parse('${baseUrl}comments/$commentId/delete/'),
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      if (response.statusCode != 204) {
        throw Exception('Failed to delete comment: ${response.body}');
      }
    } catch (e) {
      print('Error deleting comment: $e');
      throw Exception('Error deleting comment: $e');
    }
  }
  Future<void> requestCollaboration(int ideaId) async {
    try {
      final response = await makeAuthenticatedRequest<http.Response>(
        request: (token) => http.post(
          Uri.parse('${baseUrl}ideas/$ideaId/collab/request/'),
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      if (response.statusCode != 201) {
        throw Exception('Failed to request collaboration: ${response.body}');
      }
    } catch (e) {
      print('Error requesting collaboration: $e');
      throw Exception('Error requesting collaboration: $e');
    }
  }

  Future<void> approveRejectCollaboration(int collabId, String action) async {  // action: 'approve' or 'reject'
    try {
      final response = await makeAuthenticatedRequest<http.Response>(
        request: (token) => http.post(
          Uri.parse('${baseUrl}collab/$collabId/action/'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode({'action': action}),
        ),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to $action collaboration: ${response.body}');
      }
    } catch (e) {
      print('Error $action collaboration: $e');
      throw Exception('Error $action collaboration: $e');
    }
  }

  Future<List<dynamic>> getNotifications() async {
    try {
      final response = await makeAuthenticatedRequest<http.Response>(
        request: (token) => http.get(
          Uri.parse('${baseUrl}notifications/'),
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load notifications: ${response.body}');
      }
    } catch (e) {
      print('Error loading notifications: $e');
      throw Exception('Error loading notifications: $e');
    }
  }

  Future<void> markNotificationRead(int notificationId) async {
    try {
      final response = await makeAuthenticatedRequest<http.Response>(
        request: (token) => http.post(
          Uri.parse('${baseUrl}notifications/$notificationId/read/'),
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to mark as read: ${response.body}');
      }
    } catch (e) {
      print('Error marking read: $e');
      throw Exception('Error marking read: $e');
    }
  }

  Future<List<dynamic>> getMessages(int ideaId) async {
    try {
      final response = await makeAuthenticatedRequest<http.Response>(
        request: (token) => http.get(
          Uri.parse('${baseUrl}ideas/$ideaId/messages/'),
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load messages: ${response.body}');
      }
    } catch (e) {
      print('Error loading messages: $e');
      throw Exception('Error loading messages: $e');
    }
  }

  Future<void> sendMessage(int ideaId, String content) async {
    try {
      print('Sending message to idea $ideaId: $content');
      final response = await makeAuthenticatedRequest<http.Response>(
        request: (token) => http.post(
          Uri.parse('${baseUrl}ideas/$ideaId/messages/'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode({'content': content}),
        ),
      );
      print('Send message response status: ${response.statusCode}');
      print('Send message response body: ${response.body}');
      if (response.statusCode != 201) {
        throw Exception('Failed to send message: ${response.body}');
      }
    } catch (e) {
      print('Error sending message: $e');
      throw Exception('Error sending message: $e');
    }
  }
  Future<List<dynamic>> getGroupMembers(int ideaId) async {
    try {
      final response = await makeAuthenticatedRequest<http.Response>(
        request: (token) => http.get(
          Uri.parse('${baseUrl}ideas/$ideaId/group-members/'),
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body)['members'] ?? [];
      } else {
        throw Exception('Failed to load group members: ${response.body}');
      }
    } catch (e) {
      print('Error loading group members: $e');
      throw Exception('Error loading group members: $e');
    }
  }

  Future<void> removeMemberFromGroup(int ideaId, int memberId) async {
    try {
      final response = await makeAuthenticatedRequest<http.Response>(
        request: (token) => http.post(
          Uri.parse('${baseUrl}collaborations/remove/'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'idea_id': ideaId,
            'member_id': memberId,
          }),
        ),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to remove member: ${response.body}');
      }
    } catch (e) {
      print('Error removing member: $e');
      throw Exception('Error removing member: $e');
    }
  }

  Future<void> leaveGroup(int ideaId) async {
    try {
      final response = await makeAuthenticatedRequest<http.Response>(
        request: (token) => http.post(
          Uri.parse('${baseUrl}collaborations/leave/'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode({'idea_id': ideaId}),
        ),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to leave group: ${response.body}');
      }
    } catch (e) {
      print('Error leaving group: $e');
      throw Exception('Error leaving group: $e');
    }
  }
}