import 'package:flutter/material.dart';
import '../screens/home/home_screen.dart';

class CncPanel extends StatelessWidget {
  const CncPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CNC Panel',
      theme: ThemeData(
        brightness: Brightness.light, // jasne tło
        primarySwatch: Colors.blue,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
