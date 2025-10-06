import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class ProfileUpdateScreen extends StatefulWidget {
  @override
  _ProfileUpdateScreenState createState() => _ProfileUpdateScreenState();
}

class _ProfileUpdateScreenState extends State<ProfileUpdateScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _professionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _profilePic;
  List<String> _selectedSkills = [];
  List<String> _selectedInterests = [];
  List<String> _categories = [];
  bool _isLoading = false;
  List<TextEditingController> _socialLinkControllers = [];
  List<String> predefinedSkills = [
    "Coding", "Design", "Marketing", "Writing", "Photography", "Teaching", "Research",
    "Data Analysis", "Project Management", "Music", "Art", "Cooking"
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _fetchCategories();
    _socialLinkControllers.add(TextEditingController()); // Initialize with one empty field
  }

  Future<void> _fetchCategories() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final categories = await ApiService().getCategories();
      if (mounted) {
        setState(() {
          _categories = categories
            ..sort((a, b) {
              if (a == 'Others') return 1;
              if (b == 'Others') return -1;
              return a.compareTo(b);
            });
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to load categories: $e',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ),
            ),
            backgroundColor: Color(0xFF281B60),
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

  Future<void> _loadProfile() async {
    try {
      final response = await ApiService().makeAuthenticatedRequest(
        request: (token) => http.get(
          Uri.parse('${ApiService.baseUrl}profile/'),
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _firstNameController.text = data['first_name'] ?? '';
            _lastNameController.text = data['last_name'] ?? '';
            _bioController.text = data['bio'] ?? '';
            _professionController.text = data['profession'] ?? '';
            _selectedSkills = (data['skills'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
            _selectedInterests = (data['interests'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
            // Handle social_links as a list of URLs
            final socialLinks = (data['social_links'] as List<dynamic>?)?.map((link) {
              // Check if link is a string (new format) or a map (old format)
              if (link is String) {
                return link;
              } else if (link is Map && link.containsKey('url')) {
                return link['url'].toString();
              }
              return '';
            }).where((link) => link.isNotEmpty).toList() ?? [];
            _socialLinkControllers = socialLinks.map((link) => TextEditingController(text: link)).toList();
            if (_socialLinkControllers.isEmpty) {
              _socialLinkControllers.add(TextEditingController());
            }
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to load profile: ${response.body}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                ),
              ),
              backgroundColor: Color(0xFF281B60),
            ),
          );
        }
      }
    } catch (e) {
      if (e.toString().contains('Authentication failed')) {
        await ApiService().clearTokens();
        Navigator.pushReplacementNamed(context, '/login');
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $e',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ),
            ),
            backgroundColor: Color(0xFF281B60),
          ),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profilePic = File(pickedFile.path);
      });
    }
  }

  void _addSocialLink() {
    setState(() {
      if (_socialLinkControllers.length < 3) {
        _socialLinkControllers.add(TextEditingController());
      }
    });
  }

  void _removeSocialLink(int index) {
    setState(() {
      _socialLinkControllers[index].dispose();
      _socialLinkControllers.removeAt(index);
      if (_socialLinkControllers.isEmpty) {
        _socialLinkControllers.add(TextEditingController());
      }
    });
  }

  Future<void> _updateProfile() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final socialLinks = _socialLinkControllers
          .map((controller) => controller.text.trim())
          .where((url) => url.isNotEmpty)
          .toList();
      final payload = {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'bio': _bioController.text.trim(),
        'profession': _professionController.text.trim(),
        'skills': json.encode(_selectedSkills),
        'interests': json.encode(_selectedInterests),
        'social_links': json.encode(socialLinks),
      };
      print('Sending profile update payload: $payload'); // Debug log
      final response = await ApiService().makeAuthenticatedRequest<http.StreamedResponse>(
        request: (token) async {
          var request = http.MultipartRequest(
            'PATCH',
            Uri.parse('${ApiService.baseUrl}profile/update/'),
          )..headers['Authorization'] = 'Bearer $token';
          request.fields['first_name'] = _firstNameController.text.trim();
          request.fields['last_name'] = _lastNameController.text.trim();
          request.fields['bio'] = _bioController.text.trim();
          request.fields['profession'] = _professionController.text.trim();
          request.fields['skills'] = json.encode(_selectedSkills);
          request.fields['interests'] = json.encode(_selectedInterests);
          request.fields['social_links'] = json.encode(socialLinks);
          if (_profilePic != null) {
            request.files.add(await http.MultipartFile.fromPath('profile_pic', _profilePic!.path));
          }
          return await request.send();
        },
      );
      final respStr = await response.stream.bytesToString();
      print('Profile update response: $respStr'); // Debug log
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Profile updated successfully!',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                ),
              ),
              backgroundColor: Color(0xFF281B60),
            ),
          );
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to update profile: $respStr',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                ),
              ),
              backgroundColor: Color(0xFF281B60),
            ),
          );
        }
      }
    } catch (e) {
      if (e.toString().contains('Authentication failed')) {
        await ApiService().clearTokens();
        Navigator.pushReplacementNamed(context, '/login');
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $e',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ),
            ),
            backgroundColor: Color(0xFF281B60),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Update Profile',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFF281B60),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: CircleAvatar(
                          radius: 60,
                          backgroundImage: _profilePic != null ? FileImage(_profilePic!) : null,
                          backgroundColor: Colors.grey[300],
                          child: _profilePic == null
                              ? Icon(Icons.camera_alt, size: 60, color: Colors.grey[600])
                              : null,
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    TextField(
                      controller: _firstNameController,
                      decoration: InputDecoration(
                        labelText: 'First Name',
                        labelStyle: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF281B60).withOpacity(0.6),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF281B60), width: 1.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF281B60), width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF281B60),
                      ),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: _lastNameController,
                      decoration: InputDecoration(
                        labelText: 'Last Name',
                        labelStyle: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF281B60).withOpacity(0.6),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF281B60), width: 1.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF281B60), width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF281B60),
                      ),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: _bioController,
                      decoration: InputDecoration(
                        labelText: 'Bio',
                        labelStyle: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF281B60).withOpacity(0.6),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF281B60), width: 1.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF281B60), width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                      maxLines: 4,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF281B60),
                      ),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: _professionController,
                      decoration: InputDecoration(
                        labelText: 'Profession',
                        labelStyle: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF281B60).withOpacity(0.6),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF281B60), width: 1.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF281B60), width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF281B60),
                      ),
                    ),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Social Links',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF281B60),
                          ),
                        ),
                        TextButton(
                          onPressed: _socialLinkControllers.length >= 3 ? null : _addSocialLink,
                          child: Text(
                            '+ Add Link',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _socialLinkControllers.length >= 3
                                  ? Colors.grey
                                  : Color(0xFF281B60),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    ..._socialLinkControllers.asMap().entries.map((entry) {
                      final index = entry.key;
                      final controller = entry.value;
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: controller,
                                  decoration: InputDecoration(
                                    labelText: 'Social Link URL',
                                    labelStyle: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      color: Color(0xFF281B60).withOpacity(0.6),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Color(0xFF281B60), width: 1.5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Color(0xFF281B60), width: 2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[100],
                                  ),
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFF281B60),
                                  ),
                                  keyboardType: TextInputType.url,
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.remove_circle, color: Colors.red),
                                onPressed: () => _removeSocialLink(index),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                        ],
                      );
                    }).toList(),
                    SizedBox(height: 20),
                    Text(
                      'Select Skills',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF281B60),
                      ),
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: predefinedSkills.map((skill) {
                        return FilterChip(
                          label: Text(
                            skill,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: _selectedSkills.contains(skill)
                                  ? Color(0xFF281B60)
                                  : Colors.black87,
                            ),
                          ),
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
                          selectedColor: Color(0xFF281B60).withOpacity(0.2),
                          checkmarkColor: Color(0xFF281B60),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Select Interests',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF281B60),
                      ),
                    ),
                    SizedBox(height: 8),
                    _categories.isEmpty
                        ? Text(
                      'Loading categories...',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF281B60).withOpacity(0.6),
                      ),
                    )
                        : Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: _categories.map((category) {
                        return FilterChip(
                          label: Text(
                            category,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: _selectedInterests.contains(category)
                                  ? Color(0xFF281B60)
                                  : Colors.black87,
                            ),
                          ),
                          selected: _selectedInterests.contains(category),
                          onSelected: (selected) {
                            setState(() {
                              if (selected && !_selectedInterests.contains(category)) {
                                if (_selectedInterests.length < 5) {
                                  _selectedInterests.add(category);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'You can select up to 5 interests',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w400,
                                          color: Colors.white,
                                        ),
                                      ),
                                      backgroundColor: Color(0xFF281B60),
                                    ),
                                  );
                                }
                              } else if (!selected && _selectedInterests.contains(category)) {
                                _selectedInterests.remove(category);
                              }
                            });
                          },
                          selectedColor: Color(0xFF281B60).withOpacity(0.2),
                          checkmarkColor: Color(0xFF281B60),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _updateProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF281B60),
                        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        _isLoading ? 'Saving...' : 'Save Profile',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF281B60)),
                  strokeWidth: 2.5,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _bioController.dispose();
    _professionController.dispose();
    for (var controller in _socialLinkControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}