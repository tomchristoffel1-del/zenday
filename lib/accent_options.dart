import 'package:flutter/material.dart';

/// Freischaltbare Akzentfarben – die echte Belohnung fürs Punktesammeln.
/// Der erste Eintrag (Graphit) ist immer verfügbar, alle weiteren werden
/// erst ab der jeweiligen Punktzahl wählbar.
class AccentOption {
  final String name;
  final Color light;
  final Color dark;
  final int unlockPoints;

  const AccentOption({
    required this.name,
    required this.light,
    required this.dark,
    required this.unlockPoints,
  });
}

const accentOptions = [
  AccentOption(name: 'Graphit', light: Color(0xFF3A3A3C), dark: Color(0xFFE5E5E7), unlockPoints: 0),
  AccentOption(name: 'Terracotta', light: Color(0xFFC1613D), dark: Color(0xFFE08A63), unlockPoints: 10),
  AccentOption(name: 'Ozean', light: Color(0xFF2B6CB0), dark: Color(0xFF6AA8E8), unlockPoints: 25),
  AccentOption(name: 'Wald', light: Color(0xFF2F7A4F), dark: Color(0xFF5CC189), unlockPoints: 50),
  AccentOption(name: 'Amethyst', light: Color(0xFF6B4E9E), dark: Color(0xFFAE8AE8), unlockPoints: 100),
  AccentOption(name: 'Gold', light: Color(0xFFA6791F), dark: Color(0xFFE0B04A), unlockPoints: 250),
];
