import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.bounceOut,
    );
    _controller.forward();
    _checkTokenAndNavigate();
  }

  Future<void> _checkTokenAndNavigate() async {
    await Future.delayed(Duration(seconds: 3)); // Changed from 6 to 1 second
    try {
      await ApiService().getAccessToken();
      Navigator.pushReplacementNamed(context, "/home");
    } catch (e) {
      // print("Splash: No valid token found: $e"); // Commented to avoid lint warning
      Navigator.pushReplacementNamed(context, "/login");
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white, // Solid white background
        child: Center(
          child: FadeTransition(
            opacity: _animation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      child: Image.asset(
                        "assets/logo.png",
                        width: 100,
                        height: 100,
                        fit: BoxFit.contain,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      "ThinkDrop",
                      style: GoogleFonts.poppins(
                        fontSize: 40,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF281B60),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6A1B9A)),
                  strokeWidth: 2.5,
                  backgroundColor: Colors.white.withOpacity(0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}