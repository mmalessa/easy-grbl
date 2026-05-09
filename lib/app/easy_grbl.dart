import 'package:flutter/material.dart';
import '../screens/home/home_screen.dart';

class EasyGrbl extends StatelessWidget {
  const EasyGrbl({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EasyGRBL',
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
