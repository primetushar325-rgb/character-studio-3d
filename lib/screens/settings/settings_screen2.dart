import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/section_header.dart';

/// Minimal, honest settings for the 2D studio (everything here is real).
class SettingsScreen2 extends StatelessWidget {
  const SettingsScreen2({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          children: [
            const Text('Settings', style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('2D Character Studio v2.0', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SectionHeader(title: 'Canvas'),
            GlassCard(
              child: Column(
                children: const [
                  ListTile(dense: true, leading: Icon(Icons.aspect_ratio_rounded, color: AppColors.textSecondary), title: Text('Default canvas', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)), subtitle: Text('1920×1080 (16:9) — change it per project in the editor', style: TextStyle(color: AppColors.textMuted, fontSize: 11.5))),
                  ListTile(dense: true, leading: Icon(Icons.monitor_rounded, color: AppColors.textSecondary), title: Text('Presets', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)), subtitle: Text('1920×1080 · 1280×720 · 854×480', style: TextStyle(color: AppColors.textMuted, fontSize: 11.5))),
                ],
              ),
            ),
            const SectionHeader(title: 'Export'),
            GlassCard(
              child: Column(
                children: const [
                  ListTile(dense: true, leading: Icon(Icons.movie_creation_rounded, color: AppColors.textSecondary), title: Text('Video engine', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)), subtitle: Text('Frame-based rendering + H.264 (libx264) — never screen recording', style: TextStyle(color: AppColors.textMuted, fontSize: 11.5))),
                  ListTile(dense: true, leading: Icon(Icons.image_rounded, color: AppColors.textSecondary), title: Text('Formats', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)), subtitle: Text('MP4 · GIF · PNG · PNG sequence', style: TextStyle(color: AppColors.textMuted, fontSize: 11.5))),
                  ListTile(dense: true, leading: Icon(Icons.folder_rounded, color: AppColors.textSecondary), title: Text('Saved location', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)), subtitle: Text('Movies/2DCharacterStudio (MediaStore)', style: TextStyle(color: AppColors.textMuted, fontSize: 11.5))),
                ],
              ),
            ),
            const SectionHeader(title: 'Character System'),
            GlassCard(
              child: Column(
                children: const [
                  ListTile(dense: true, leading: Icon(Icons.accessibility_new_rounded, color: AppColors.textSecondary), title: Text('Rig', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)), subtitle: Text('humanoid_v1 (20 bones) · quadruped_v1 (22 bones)', style: TextStyle(color: AppColors.textMuted, fontSize: 11.5))),
                  ListTile(dense: true, leading: Icon(Icons.animation_rounded, color: AppColors.textSecondary), title: Text('Animations', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)), subtitle: Text('Idle Walk Run Sit Sleep Talk Jump Wave Action Happy Sad Think Turn Fall', style: TextStyle(color: AppColors.textMuted, fontSize: 11.5))),
                ],
              ),
            ),
            const SizedBox(height: 8),
            PremiumButton(
              label: 'About',
              icon: Icons.info_rounded,
              onPressed: () => showAboutDialog(
                context: context,
                applicationName: '2D Character Studio',
                applicationVersion: '2.0.0',
                applicationIcon: const Icon(Icons.animation_rounded, color: AppColors.accent, size: 40),
                children: const [Text('A 100% offline 2D character rigging & animation editor. No 3D pipeline, no tracking, no network usage.')],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
