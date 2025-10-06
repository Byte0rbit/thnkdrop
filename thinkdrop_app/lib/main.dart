import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/profile_update_screen.dart';
import 'screens/home_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/post_idea_screen.dart';
import 'screens/idea_edit_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/profile_view_screen.dart';
import 'screens/ideas_details_screen.dart';
import 'screens/idea_user_detail_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/comments_screen.dart'; // Add this import
import 'screens/collaboration_screen.dart';
import 'screens/group_details_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => SplashScreen(),
        '/login': (context) => LoginScreen(),
        '/signup': (context) => SignupScreen(),
        '/profile_update': (context) => ProfileUpdateScreen(),
        '/home': (context) => HomeScreen(),
        '/edit_profile': (context) => ProfileUpdateScreen(),
        '/profile': (context) => ProfileScreen(),
        '/idea_post': (context) => IdeaPostScreen(), // Fixed typo
        '/edit_idea': (context) => IdeaEditScreen(),
        '/search': (context) => SearchScreen(),
        '/settings': (context) => SettingsScreen(),
        '/profile_view': (context) => ProfileViewScreen(
          user: ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>,
        ),
        '/idea_details': (context) => IdeaDetailsScreen(
          idea: ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>,
        ),
        '/user_idea_details': (context) => UserIdeaDetailsScreen(
          idea: ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>,
        ),
        '/chat': (context) => ChatScreen(
          ideaId: (ModalRoute.of(context)!.settings.arguments as Map)['ideaId'] as int,
          ideaTitle: (ModalRoute.of(context)!.settings.arguments as Map)['ideaTitle'] as String,
        ),
        '/comments': (context) => CommentsScreen(
          ideaId: (ModalRoute.of(context)!.settings.arguments as Map)['ideaId'] as int,
          ideaTitle: (ModalRoute.of(context)!.settings.arguments as Map)['ideaTitle'] as String,
        ),
        '/collaboration': (context) => CollaborationScreen(),
        '/group_details': (context) => GroupDetailsScreen(
          ideaId: (ModalRoute.of(context)!.settings.arguments as Map)['ideaId'] as int,
          ideaTitle: (ModalRoute.of(context)!.settings.arguments as Map)['ideaTitle'] as String,
        ),
      },
    );
  }
}