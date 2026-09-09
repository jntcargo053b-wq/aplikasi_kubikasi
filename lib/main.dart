import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/welcome_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KubikasiApp());
}

class KubikasiApp extends StatelessWidget {
  const KubikasiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'nextcube',
      theme: buildAppTheme(),
      home: const _LaunchGate(),
    );
  }
}

class _LaunchGate extends StatelessWidget {
  const _LaunchGate();

  Future<bool> _seen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('nextcube_welcome_seen') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _seen(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snapshot.data == true ? const HomeScreen() : const WelcomeScreen();
      },
    );
  }
}
