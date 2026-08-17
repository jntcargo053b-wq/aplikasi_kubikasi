import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const VolumeCalculatorApp());
}

class VolumeCalculatorApp extends StatelessWidget {
  const VolumeCalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aplikasi Kubikasi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.red,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
        ),
      ),
      // PENTING: home di sini WAJIB HomeScreen (lib/screens/home_screen.dart),
      // bukan widget statis lain. HomeScreen inilah yang berisi tombol
      // tambah (FAB), tap-untuk-edit, tekan lama untuk hapus, dan
      // penyimpanan data. Kalau main.dart menunjuk ke layar lain,
      // semua fitur input/edit/hapus tidak akan pernah muncul walau
      // kodenya ada di project.
      home: const HomeScreen(),
    );
  }
}
