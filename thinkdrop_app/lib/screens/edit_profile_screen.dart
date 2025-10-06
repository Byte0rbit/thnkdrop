import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/api_service.dart';

class EditProfileScreen extends StatefulWidget {
  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _picker = ImagePicker();
  File? _newProfilePic;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _professionController = TextEditingController();
  final _socialLinksController = TextEditingController();
  List<String> _selectedSkills = [];
  List<String> _selectedInterests = [];
  List<String> _predefinedSkills = [
    "Coding", "Design", "Marketing", "Writing", "Photography", "Teaching", "Research",
    "Data Analysis", "Project Management", "Music", "Art", "Cooking"
  ];
  List<String> _categories = ["Education", "Technology", "Health", "Business", "Art", "Sports"];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null || token.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No authentication token found')));
        }
        return;
      }
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}profile/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _firstNameController.text = data['first_name'] ?? '';
          _lastNameController.text = data['last_name'] ?? '';
          _bioController.text = data['bio'] ?? '';
          _professionController.text = data['profession'] ?? '';
          _socialLinksController.text = (data['social_links'] as List<dynamic>?)?.map((e) => e.toString()).join(', ') ?? '';
          _selectedSkills = (data['skills'] as List<dynamic>?)?.whereType<String>().toList() ?? [];
          _selectedInterests = (data['interests'] as List<dynamic>?)?.whereType<String>().toList() ?? [];
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load profile: ${response.body}')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _saveProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = await ApiService().getAccessToken();
      print('Using token: $token'); // Debug log
      var request = http.MultipartRequest('PATCH', Uri.parse('${ApiService.baseUrl}profile/update/'))
        ..headers['Authorization'] = 'Bearer $token';
      request.fields['first_name'] = _firstNameController.text;
      request.fields['last_name'] = _lastNameController.text;
      request.fields['bio'] = _bioController.text;
      request.fields['profession'] = _professionController.text;
      request.fields['social_links'] = _socialLinksController.text;
      request.fields['skills'] = _selectedSkills.join(',');
      request.fields['interests'] = _selectedInterests.join(',');
      if (_newProfilePic != null) {
        request.files.add(await http.MultipartFile.fromPath('profile_pic', _newProfilePic!.path));
      }
      final response = await request.send();
      final respStr = await response.stream.bytesToString();
      print('Response status: ${response.statusCode}, Body: $respStr'); // Debug log
      if (response.statusCode == 200) {
        Navigator.pushReplacementNamed(context, '/profile');
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $respStr')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _newProfilePic = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit Profile')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: ListView(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: _newProfilePic != null ? FileImage(_newProfilePic!) : null,
                child: _newProfilePic == null ? Icon(Icons.camera_alt, size: 50) : null,
              ),
            ),
            TextField(controller: _firstNameController, decoration: InputDecoration(labelText: 'First Name')),
            TextField(controller: _lastNameController, decoration: InputDecoration(labelText: 'Last Name')),
            TextField(controller: _bioController, decoration: InputDecoration(labelText: 'Bio')),
            TextField(controller: _professionController, decoration: InputDecoration(labelText: 'Profession')),
            TextField(controller: _socialLinksController, decoration: InputDecoration(labelText: 'Social Links (comma-separated)')),
            SizedBox(height: 10),
            Text('Select Skills', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8.0,
              children: _predefinedSkills.map((skill) {
                return FilterChip(
                  label: Text(skill),
                  selected: _selectedSkills.contains(skill),
                  onSelected: (selected) {
                    setState(() {
                      if (selected && !_selectedSkills.contains(skill)) {
                        _selectedSkills.add(skill);
                      } else if (!selected && _selectedSkills.contains(skill)) {
                        _selectedSkills.remove(skill);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            SizedBox(height: 10),
            Text('Select Interests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8.0,
              children: _categories.map((category) {
                return FilterChip(
                  label: Text(category),
                  selected: _selectedInterests.contains(category),
                  onSelected: (selected) {
                    setState(() {
                      if (selected && !_selectedInterests.contains(category)) {
                        _selectedInterests.add(category);
                      } else if (!selected && _selectedInterests.contains(category)) {
                        _selectedInterests.remove(category);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveProfile,
              child: Text('Save Profile'),
            ),
          ],
        ),
      ),
    );
  }
}