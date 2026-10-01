import 'package:flutter/material.dart';

const ink = Color(0xFF172033);
const blue = Color(0xFF2F6BFF);
const pageTop = Color(0xFFD7EAFF);
const pageBottom = Color(0xFFF4F7FB);
const good = Color(0xFF178A4A);
const warn = Color(0xFFD14343);

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: blue).copyWith(
      primary: blue,
      onPrimary: Colors.white,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: pageBottom,
    fontFamily: 'Segoe UI',
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF3F5F8),
      hintStyle: const TextStyle(color: Color(0xFF9AA3B2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: blue, width: 1.4),
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
