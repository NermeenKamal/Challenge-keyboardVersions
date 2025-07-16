import 'dart:ui';
import 'package:flutter/material.dart';
import 'src/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('ar'),
    theme: ThemeData(
      scaffoldBackgroundColor: Colors.transparent,
    ),
    home: Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/backgrounds/telegram_bg.png',
            fit: BoxFit.cover,
          ),
        ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            child: Container(
              color: Colors.white.withOpacity(0.10),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: HomeScreen(),
        ),
      ],
    ),
  ));
}
