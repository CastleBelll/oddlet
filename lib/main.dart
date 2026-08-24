import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'features/egg/home_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const OddletApp());
}

class OddletApp extends StatelessWidget {
  const OddletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ODDLET',
      // Dark only: the hatch sequence is staged against a dark room.
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C4DFF),
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
