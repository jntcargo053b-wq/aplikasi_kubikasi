import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../app_theme.dart';
import '../models/report_settings.dart';
import '../services/report_logo_storage_service.dart';
import '../services/settings_service.dart';

/// Layar untuk mengatur header kustom yang tampil pada laporan
/// PDF/Excel saat share report (nama usaha, catatan, dan logo).
class ReportHeaderSettingsScreen extends StatefulWidget {
  const ReportHeaderSettingsScreen({super.key});

  @override
  State<ReportHeaderSettingsScreen> createState() => _ReportHeaderSettingsScreenState();
}

class _ReportHeaderSettingsScreenState extends State<ReportHeaderSettingsScreen> {
  final _settingsService = SettingsService();
  final _companyController = TextEditingController();
  final _noteController = TextEditingController();
  final _picker = ImagePicker();
  bool _loading = true;
  bool _saving = false;
  String? _originalLogoPath;
  String? _logoPath;
  String? _pendingLogoPath;
  bool _logoRemoved = false;
  bool _logoAvailable = false;
  bool _committed = false;
  final Set<Future<void>> _pendingLogoCopies = <Future<void>>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    unawaited(_cleanupUnsavedLogo());
    _companyController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _cleanupUnsavedLogo() async {
    if (_committed) return;
    final copies = List<Future<void>>.from(_pendingLogoCopies);
    if (copies.isNotEmpty) {
      await Future.wait(copies, eagerError: false);
    }
    final pending = _pendingLogoPath;
    if (pending != null && pending != _originalLogoPath) {
      await ReportLogoStorageService.delete(pending);
    }
  }

  Future<void> _load() async {
    final settings = await _settingsService.loadReportSettings();
    var logoAvailable = false;
    final savedLogo = settings.logoPath?.trim();
    if (savedLogo != null && savedLogo.isNotEmpty) {
      logoAvailable = await File(savedLogo).exists();
    }
    if (!mounted) return;
    _companyController.text = settings.companyName;
    _noteController.text = settings.headerNote;
    _originalLogoPath = settings.logoPath;
    _logoPath = settings.logoPath;
    _logoAvailable = logoAvailable;
    setState(() => _loading = false);
  }

  Future<void> _pickLogo() async {
    if (_saving || _loading) return;
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 90,
      );
      if (picked == null || !mounted) return;

      final previousPending = _pendingLogoPath;
      final target = await ReportLogoStorageService.prepareTargetPath(picked.path);
      // Register ownership before the copy starts. dispose() will wait for
      // the in-flight copy before deleting the target, closing the async race.
      _pendingLogoPath = target;
      final copyFuture = File(picked.path).copy(target);
      _pendingLogoCopies.add(copyFuture);
      try {
        await copyFuture;
      } catch (_) {
        if (mounted) {
          await ReportLogoStorageService.delete(target);
          if (_pendingLogoPath == target) _pendingLogoPath = previousPending;
        }
        rethrow;
      } finally {
        _pendingLogoCopies.remove(copyFuture);
      }
      if (!mounted) {
        await ReportLogoStorageService.delete(target);
        return;
      }
      _logoPath = target;
      _logoAvailable = true;
      _logoRemoved = false;
      if (previousPending != null && previousPending != _originalLogoPath) {
        await ReportLogoStorageService.delete(previousPending);
      }
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memilih logo: $e')),
      );
    }
  }

  void _removeLogo() {
    if (_saving || _loading) return;
    setState(() {
      _logoPath = null;
      _logoAvailable = false;
      _logoRemoved = true;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    final settings = ReportSettings(
      companyName: _companyController.text.trim(),
      headerNote: _noteController.text.trim(),
      logoPath: _logoRemoved ? null : _logoPath,
    );

    try {
      await _settingsService.saveReportSettings(settings);

      final oldLogo = _originalLogoPath;
      final pendingLogo = _pendingLogoPath;
      if (oldLogo != null && oldLogo != settings.logoPath) {
        await ReportLogoStorageService.delete(oldLogo);
      }
      if (pendingLogo != null && pendingLogo != settings.logoPath) {
        await ReportLogoStorageService.delete(pendingLogo);
      }

      _committed = true;
      _pendingLogoPath = null;
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.of(context).pop(settings);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan pengaturan header. Perubahan tidak diterapkan.')),
      );
    }
  }

  String _previewHeaderText() {
    final company = _companyController.text.trim();
    final note = _noteController.text.trim();
    final title = company.isEmpty ? 'Laporan Kubikasi Pengiriman' : company;
    if (note.isEmpty) return 'Preview header: $title';
    return 'Preview header: $title\n$note';
  }

  @override
  Widget build(BuildContext context) {
    final logo = _logoPath;
    final logoExists = _logoAvailable && logo != null && logo.isNotEmpty;

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Header Laporan', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Atur nama usaha, logo, dan catatan yang akan tampil pada laporan PDF/Excel saat share report. Kosongkan untuk memakai judul default.',
                    style: TextStyle(color: AppColors.muted, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: AppColors.background,
                            ),
                            child: logoExists
                                ? Image.file(File(logo), fit: BoxFit.contain)
                                : const Icon(Icons.business, size: 32, color: AppColors.muted),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Logo Perusahaan', style: TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                const Text('Logo disimpan di storage aplikasi dan digunakan pada header PDF.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: _pickLogo,
                                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                                      label: Text(logoExists ? 'Ganti Logo' : 'Pilih Logo'),
                                    ),
                                    if (logoExists)
                                      TextButton.icon(
                                        onPressed: _removeLogo,
                                        icon: const Icon(Icons.delete_outline, size: 18),
                                        label: const Text('Hapus'),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _companyController,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Nama Usaha / Ekspedisi',
                      hintText: 'Contoh: Ekspedisi Jaya Logistik',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _noteController,
                    maxLines: 3,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Catatan Header (opsional)',
                      hintText: 'Contoh: alamat, nomor telepon, atau slogan',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    margin: EdgeInsets.zero,
                    color: AppColors.background,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, size: 18, color: AppColors.muted),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _companyController.text.trim().isEmpty && !logoExists
                                  ? 'Preview: judul laporan default akan tetap dipakai.'
                                  : _previewHeaderText(),
                              style: const TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _saving || _loading ? null : _save,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check),
            label: const Text('Simpan'),
          ),
        ),
      ),
    );
  }
}
