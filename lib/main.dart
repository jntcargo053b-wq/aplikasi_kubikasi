import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KubikasiApp());
}

class KubikasiApp extends StatelessWidget {
  const KubikasiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kalkulator Kubikasi',
      theme: buildAppTheme(),
      home: const HomeScreen(),
    );
  }
}
