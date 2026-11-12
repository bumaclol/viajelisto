import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _bar;

  @override
  void initState() {
    super.initState();
    _bar = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..forward();
  }

  @override
  void dispose() {
    _bar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: forest,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _bar,
          builder: (context, _) {
            return Column(
              children: [
                const Spacer(),
                const _Mark(),
                const SizedBox(height: 18),
                const Text(
                  'TravelEquality',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Preparando tu viaje',
                  style: TextStyle(color: Color(0xFFD5E2D2), fontSize: 15),
                ),
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 88),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: _bar.value,
                      minHeight: 5,
                      backgroundColor: forestDeep,
                      color: lime,
                    ),
                  ),
                ),
                const Spacer(flex: 2),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: lime,
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Icon(Icons.luggage_rounded, color: forestDeep, size: 42),
    );
  }
}
