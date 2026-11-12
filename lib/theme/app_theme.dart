import 'package:flutter/material.dart';

const ink = Color(0xFF172033);
const blue = Color(0xFF2F6BFF);
const pageTop = Color(0xFFD7EAFF);
const pageBottom = Color(0xFFF4F7FB);
const good = Color(0xFF178A4A);
const warn = Color(0xFFD14343);

const forest = Color(0xFF268565);
const forestDeep = Color(0xFF252A27);
const lime = Color(0xFFD8EEE3);
const paper = Color(0xFFF1F4F2);
const moss = Color(0xFF636B66);
const line = Color(0xFFDBDFDD);

const displayFamily = 'Sora';

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: forest).copyWith(
      primary: forest,
      onPrimary: Colors.white,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: paper,
    fontFamily: 'Manrope',
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(color: moss),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: forest, width: 1.4),
      ),
    ),
  );
}

class PageBackdrop extends StatelessWidget {
  const PageBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [pageTop, pageBottom, pageBottom],
          stops: [0, 0.22, 1],
        ),
      ),
      child: child,
    );
  }
}
