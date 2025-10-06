import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class IdeaPostScreen extends StatefulWidget {
  @override
  _IdeaPostScreenState createState() => _IdeaPostScreenState();
}

class _IdeaPostScreenState extends State<IdeaPostScreen> {
  final _titleController = TextEditingController();
  final _shortDescriptionController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _visibility = 'private';
  List<String> _selectedCategories = [];
  List<String> _categories = [];
  List<File> _selectedFiles = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
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
              style: TextStyle(color: Colors.white, fontSize: 14),
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

  Future<void> _pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png'],
    );
    if (result != null && mounted) {
      setState(() {
        _selectedFiles.addAll(result.files.map((file) => File(file.path!)));
      });
      print('Selected files: ${_selectedFiles.map((f) => f.path).toList()}'); // Debug log
    }
  }

  Future<void> _postIdea() async {
    if (_titleController.text.trim().isEmpty || _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Title and description are required',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          backgroundColor: Color(0xFF281B60),
        ),
      );
      return;
    }

    final description = _descriptionController.text.trim();
    if (description.contains('class ') || description.contains('def ') || description.contains('import ')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Description contains invalid content (e.g., code)',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          backgroundColor: Color(0xFF281B60),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService().makeAuthenticatedRequest<http.StreamedResponse>(
        request: (token) async {
          var request = http.MultipartRequest(
            'POST',
            Uri.parse('${ApiService.baseUrl}ideas/'),
          )..headers['Authorization'] = 'Bearer $token';
          request.fields['title'] = _titleController.text.trim();
          request.fields['short_description'] = _shortDescriptionController.text.trim();
          request.fields['description'] = description;
          request.fields['visibility'] = _visibility;
          request.fields['categories'] = json.encode(_selectedCategories);
          print('Sending files: ${_selectedFiles.map((f) => f.path.split('/').last).toList()}');
          for (var file in _selectedFiles) {
            request.files.add(await http.MultipartFile.fromPath('files', file.path));
          }
          return await request.send();
        },
      );
      final respStr = await response.stream.bytesToString();
      print('Post idea response: ${response.statusCode}, $respStr'); // Debug log
      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Idea posted successfully!',
                style: TextStyle(color: Colors.white, fontSize: 14),
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
                'Failed to post idea: $respStr',
                style: TextStyle(color: Colors.white, fontSize: 14),
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
              style: TextStyle(color: Colors.white, fontSize: 14),
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
  void dispose() {
    _titleController.dispose();
    _shortDescriptionController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Post an Idea'),
        backgroundColor: Color(0xFF281B60),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: ListView(
              children: [
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Idea Title',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: _shortDescriptionController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Short Description',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Overview/Description',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                ),
                SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Visibility',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  value: _visibility,
                  items: ['private', 'public', 'partial'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value[0].toUpperCase() + value.substring(1)),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _visibility = newValue;
                      });
                    }
                  },
                ),
                SizedBox(height: 20),
                Text(
                  'Select Categories',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF281B60),
                  ),
                ),
                SizedBox(height: 8),
                _categories.isEmpty
                    ? Text(
                  'Loading categories...',
                  style: TextStyle(color: Color(0xFF281B60).withOpacity(0.6)),
                )
                    : Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: _categories.map((category) {
                    return FilterChip(
                      label: Text(category),
                      selected: _selectedCategories.contains(category),
                      onSelected: (selected) {
                        setState(() {
                          if (selected && !_selectedCategories.contains(category)) {
                            if (_selectedCategories.length < 5) {
                              _selectedCategories.add(category);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'You can select up to 5 categories',
                                    style: TextStyle(color: Colors.white, fontSize: 14),
                                  ),
                                  backgroundColor: Color(0xFF281B60),
                                ),
                              );
                            }
                          } else if (!selected && _selectedCategories.contains(category)) {
                            _selectedCategories.remove(category);
                          }
                        });
                      },
                      selectedColor: Color(0xFF281B60).withOpacity(0.2),
                      checkmarkColor: Color(0xFF281B60),
                      labelStyle: TextStyle(
                        color: _selectedCategories.contains(category)
                            ? Color(0xFF281B60)
                            : Colors.black87,
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 20),
                Text(
                  'Attach Files',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF281B60),
                  ),
                ),
                SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _pickFiles,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF281B60),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('Pick Files (PDF, JPG, PNG)'),
                ),
                SizedBox(height: 8),
                if (_selectedFiles.isNotEmpty)
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: _selectedFiles.map((file) {
                      return Chip(
                        label: Text(
                          file.path.split('/').last,
                          style: TextStyle(color: Color(0xFF281B60)),
                        ),
                        backgroundColor: Colors.white,
                        side: BorderSide(color: Color(0xFF281B60)),
                        deleteIconColor: Color(0xFF281B60),
                        onDeleted: () {
                          setState(() {
                            _selectedFiles.remove(file);
                          });
                        },
                      );
                    }).toList(),
                  ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _postIdea,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF281B60),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    textStyle: TextStyle(fontSize: 16),
                  ),
                  child: Text(_isLoading ? 'Submitting...' : 'Submit Idea'),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Center(
              child: CircularProgressIndicator(
                color: Color(0xFF281B60),
              ),
            ),
        ],
      ),
    );
  }
}