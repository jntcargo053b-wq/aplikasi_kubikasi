import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';
import 'home_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _start(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('nextcube_welcome_seen', true);
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 34, 28, 24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x222563EB),
                      blurRadius: 28,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: const Icon(Icons.view_in_ar_rounded, color: Colors.white, size: 58),
              ),
              const SizedBox(height: 28),
              RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 42, fontWeight: FontWeight.w800, letterSpacing: -1.8),
                  children: [
                    TextSpan(text: 'next', style: TextStyle(color: AppColors.text)),
                    TextSpan(text: 'cube', style: TextStyle(color: AppColors.primary)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Hitung volume, kelola pengiriman,\ndan buat laporan dengan lebih mudah.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, height: 1.5, fontSize: 15),
              ),
              const SizedBox(height: 34),
              _Feature(icon: Icons.view_in_ar_outlined, title: 'Hitung Kubikasi', subtitle: 'Cepat, akurat, praktis'),
              const SizedBox(height: 12),
              _Feature(icon: Icons.local_shipping_outlined, title: 'Kelola Pengiriman', subtitle: 'Simpan dan pantau data'),
              const SizedBox(height: 12),
              _Feature(icon: Icons.bar_chart_outlined, title: 'Laporan Lengkap', subtitle: 'Ekspor dan bagikan dengan mudah'),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: () => _start(context),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Mulai Sekarang', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Solusi logistik untuk bisnis Anda', style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _Feature({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
