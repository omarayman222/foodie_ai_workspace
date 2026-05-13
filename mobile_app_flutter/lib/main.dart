import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/auth_screen.dart';

void main() {
  runApp(const FoodieAiApp());
}

class FoodieAiApp extends StatelessWidget {
  const FoodieAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Foodie AI',
      debugShowCheckedModeBanner: false, // Removes the red "DEBUG" banner
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        textTheme: GoogleFonts.poppinsTextTheme(), // Gives it a modern startup look
        useMaterial3: true,
      ),
      home: const AuthScreen(),
    );
  }
}