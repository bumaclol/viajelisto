import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'services/cloud_api.dart';
import 'services/storage_service.dart';
import 'state/app_controller.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ViajeListoApp(cloud: CloudApi('http://127.0.0.1:8088')));
}

class ViajeListoApp extends StatelessWidget {
  const ViajeListoApp({super.key, this.cloud});

  final CloudApi? cloud;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
        create: (_) => AppController(StorageService(cloud: cloud))..load(),
      child: MaterialApp(
        title: 'TravelEquality',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const _BootScreen(),
      ),
    );
  }
}

class _BootScreen extends StatefulWidget {
  const _BootScreen();

  @override
  State<_BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<_BootScreen> {
  var _hold = true;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _hold = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    if (controller.loading || _hold) return const SplashScreen();
    if (!controller.signedIn) return const LoginScreen();
    return const HomeShell();
  }
}
