import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatelessWidget {
  final _changePasswordFormKey = GlobalKey<FormState>();
  final _deleteAccountFormKey = GlobalKey<FormState>();

  // Show Change Password dialog
  Future<void> _showChangePasswordDialog(BuildContext context) async {
    String oldPassword = '';
    String newPassword = '';
    String confirmPassword = '';
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Change Password'),
              content: Form(
                key: _changePasswordFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Old Password',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      onChanged: (value) => oldPassword = value,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your old password';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      onChanged: (value) => newPassword = value,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a new password';
                        }
                        if (value.length < 8) {
                          return 'Password must be at least 8 characters';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      onChanged: (value) => confirmPassword = value,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your new password';
                        }
                        if (value != newPassword) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                    if (_changePasswordFormKey.currentState!.validate()) {
                      setState(() => isLoading = true);
                      try {
                        final response = await ApiService().changePassword(oldPassword, newPassword);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('access_token', response['access']);
                        await prefs.setString('refresh_token', response['refresh']);
                        Navigator.pop(context);
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
                        setState(() => isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Error: $e',
                              style: TextStyle(color: Colors.white, fontSize: 14),
                            ),
                            backgroundColor: Colors.purple[800],
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple[800],
                    foregroundColor: Colors.white,
                  ),
                  child: isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text('Change Password'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Handle Log Out
  Future<void> _handleLogOut(BuildContext context) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Log Out'),
        content: Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService().clearTokens();
        Navigator.pushReplacementNamed(context, '/login');
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Logout failed: $e',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            backgroundColor: Colors.purple[800],
          ),
        );
      }
    }
  }

  // Show Delete Account dialog
  Future<void> _showDeleteAccountDialog(BuildContext context) async {
    String email = '';
    String password = '';
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Delete Account'),
              content: Form(
                key: _deleteAccountFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Are you sure you want to delete your account? This action cannot be undone.',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => email = value,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      onChanged: (value) => password = value,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                    if (_deleteAccountFormKey.currentState!.validate()) {
                      setState(() => isLoading = true);
                      try {
                        // Verify credentials
                        await ApiService().login(email, password);
                        await ApiService().deleteAccount();
                        Navigator.pushReplacementNamed(context, '/login');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Account deleted successfully',
                              style: TextStyle(color: Colors.white, fontSize: 14),
                            ),
                            backgroundColor: Colors.purple[800],
                          ),
                        );
                      } catch (e) {
                        setState(() => isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Error: $e',
                              style: TextStyle(color: Colors.white, fontSize: 14),
                            ),
                            backgroundColor: Colors.purple[800],
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text('Delete Account'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.2),
      ),
      body: ListView(
        padding: EdgeInsets.all(16.0),
        children: [
          ListTile(
            leading: Icon(Icons.edit, color: Colors.purple[800]),
            title: Text(
              'Edit Profile',
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
            onTap: () {
              Navigator.pushNamed(context, '/edit_profile');
            },
          ),
          ListTile(
            leading: Icon(Icons.lock, color: Colors.purple[800]),
            title: Text(
              'Change Password',
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
            onTap: () => _showChangePasswordDialog(context),
          ),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.purple[800]),
            title: Text(
              'Log Out',
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
            onTap: () => _handleLogOut(context),
          ),
          ListTile(
            leading: Icon(Icons.delete, color: Colors.redAccent),
            title: Text(
              'Delete Account',
              style: TextStyle(fontSize: 16, color: Colors.redAccent),
            ),
            onTap: () => _showDeleteAccountDialog(context),
          ),
        ],
      ),
    );
  }
}