import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _air;
  late final AnimationController _bar;

  @override
  void initState() {
    super.initState();
    _air = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))
      ..repeat();
    _bar = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..forward();
  }

  @override
  void dispose() {
    _air.dispose();
    _bar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageBackdrop(
        child: SafeArea(
          child: AnimatedBuilder(
            animation: Listenable.merge([_air, _bar]),
            builder: (context, _) {
              return Column(
                children: [
                  SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: ClipRect(
                      child: Stack(
                        children: [
                          _Cloud(left: _drift(0.1, 160), top: 18, scale: 1),
                          _Cloud(left: _drift(0.55, 160), top: 62, scale: 0.72),
                          _Gust(left: _drift(0.2, 100), top: 36, width: 70),
                          _Gust(left: _drift(0.48, 120), top: 78, width: 46),
                          _Gust(left: _drift(0.78, 90), top: 28, width: 58),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  const _Mark(),
                  const SizedBox(height: 18),
                  const Text(
                    'TravelEquality',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: ink),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Preparando tu viaje',
                    style: TextStyle(color: Color(0xFF667085), fontSize: 15),
                  ),
                  const SizedBox(height: 22),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 88),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: _bar.value,
                        minHeight: 5,
                        backgroundColor: const Color(0xFFE3ECF8),
                        color: blue,
                      ),
                    ),
                  ),
                  const Spacer(flex: 2),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  double _drift(double shift, double span) {
    final width = MediaQuery.sizeOf(context).width;
    final travel = (_air.value + shift) % 1;
    return -span + (width + span * 2) * travel;
  }
}

class _Mark extends StatelessWidget {
  const _Mark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5B8CFF), Color(0xFF2F6BFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(color: Color(0x332F6BFF), blurRadius: 22, offset: Offset(0, 10)),
        ],
      ),
      child: const Icon(Icons.flight_takeoff_rounded, color: Colors.white, size: 40),
    );
  }
}

class _Cloud extends StatelessWidget {
  const _Cloud({required this.left, required this.top, required this.scale});

  final double left;
  final double top;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.topLeft,
        child: const SizedBox(
          width: 58,
          height: 24,
          child: Stack(
            children: [
              Positioned(left: 6, child: _Puff(size: 16)),
              Positioned(left: 18, child: _Puff(size: 22)),
              Positioned(left: 34, top: 4, child: _Puff(size: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Puff extends StatelessWidget {
  const _Puff({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
    );
  }
}

class _Gust extends StatelessWidget {
  const _Gust({required this.left, required this.top, required this.width});

  final double left;
  final double top;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: width,
        height: 3,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          gradient: const LinearGradient(
            colors: [Color(0x002F6BFF), Color(0x88FFFFFF), Color(0x002F6BFF)],
          ),
        ),
      ),
    );
  }
}
