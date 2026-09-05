import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../app_theme.dart';
import '../services/backup_service.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final _backupService = BackupService();
  bool _busy = false;

  Future<void> _backup() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await _backupService.createBackup();
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Backup data Nextcube',
        subject: 'Backup Nextcube',
      );
    } catch (e) {
      if (!mounted) return;
      _message('Gagal membuat backup: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ncbak'],
      withData: false,
    );
    if (picked == null || picked.files.single.path == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final backup = await _backupService.readBackup(
        File(picked.files.single.path!),
      );
      if (!mounted) return;
      final mode = await _chooseRestoreMode(backup);
      if (mode == null || !mounted) return;
      final result = await _backupService.restore(backup, merge: mode);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Restore berhasil'),
          content: Text(
            '${result.restoredShipments} pengiriman\n'
            '${result.restoredItems} barang\n'
            '${result.restoredPhotos} foto dipulihkan'
            '${result.skippedDuplicates > 0 ? '\n${result.skippedDuplicates} pengiriman duplikat dilewati' : ''}',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Selesai'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _message('Restore gagal: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _chooseRestoreMode(BackupData backup) {
    final created = backup.createdAt?.toLocal();
    final dateText = created == null
        ? 'tanggal tidak diketahui'
        : '${created.day.toString().padLeft(2, '0')}/'
            '${created.month.toString().padLeft(2, '0')}/${created.year} '
            '${created.hour.toString().padLeft(2, '0')}:'
            '${created.minute.toString().padLeft(2, '0')}';
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Pilih cara restore'),
        content: Text(
          'Backup: $dateText\n\n'
          '${backup.shipments.length} pengiriman dan '
          '${backup.shipments.fold<int>(0, (s, e) => s + e.barang.length)} barang.\n\n'
          'Ganti semua akan mengganti data saat ini. Gabungkan akan mempertahankan data saat ini dan melewati ID pengiriman yang sama.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Batal'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Gabungkan'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ganti Semua'),
          ),
        ],
      ),
    );
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Data & Backup',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Lindungi data operasional',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Backup menyimpan pengiriman, barang, foto, serta header laporan dalam satu file offline. Simpan file backup di tempat aman atau pindahkan ke perangkat lain.',
                    style: TextStyle(color: AppColors.muted, height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _backup,
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.backup_outlined),
                      label: const Text('Buat & Bagikan Backup'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _restore,
                      icon: const Icon(Icons.restore_outlined),
                      label: const Text('Restore dari Backup'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: const [
                ListTile(
                  leading: Icon(Icons.photo_library_outlined),
                  title: Text('Foto ikut dibackup'),
                  subtitle: Text('Path foto Android dipindahkan ke path baru saat restore.'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.merge_type_outlined),
                  title: Text('Restore dapat digabung'),
                  subtitle: Text('Data yang sudah ada tetap dipertahankan; ID pengiriman yang sama dilewati.'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.verified_outlined),
                  title: Text('Backup tervalidasi'),
                  subtitle: Text('File harus berformat Nextcube dan versi backup yang didukung.'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
