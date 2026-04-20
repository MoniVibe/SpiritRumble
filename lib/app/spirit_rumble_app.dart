import 'package:bullethole_shared/bullethole_shared.dart';
import 'package:flutter/material.dart';

import '../battle/presentation/screens/battle_screen.dart';

class SpritRumbleApp extends StatelessWidget {
  const SpritRumbleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sprit Rumble',
      theme: buildBulletholeGameTheme(
        palette: const BulletholeThemePalette(
          primary: Color(0xFFDC4A3D),
          secondary: Color(0xFF4FA1E2),
          tertiary: Color(0xFF61BF78),
        ),
      ),
      home: const SpritRumbleScreen(),
    );
  }
}
