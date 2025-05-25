import 'package:flutter/material.dart';
import 'login_page.dart';
import 'inbox_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IITK Mail App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LoginPage(),
      routes: {
        '/inbox': (_) => const InboxPage(),
      },
    );
  }
}
