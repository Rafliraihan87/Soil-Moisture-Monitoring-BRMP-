import 'package:flutter/material.dart';
import 'login.dart'; // Import file login

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Auth Screen',
      theme: ThemeData(fontFamily: 'sans-serif'),
      home: const AuthScreen(), // Memanggil widget dari login.dart
    );
  }
}