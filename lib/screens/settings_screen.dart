import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF121212) : AppColors.background;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textDark = isDark ? Colors.white : AppColors.textDark;
    final textMed = isDark ? Colors.white70 : AppColors.textMed;
    final dividerColor = isDark ? Colors.white12 : Colors.grey.shade200;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Pengaturan'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Header Section ──
          _sectionLabel('Tampilan', textMed),
          const SizedBox(height: 8),

          // Card tema
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: dividerColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 30 : 8),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header card
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.palette_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mode Tema',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: textDark,
                            ),
                          ),
                          Text(
                            'Pilih tampilan aplikasi',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: textMed,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: dividerColor),
                const SizedBox(height: 12),

                // 3 opsi tema
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      _themeOptionCard(
                        context,
                        icon: Icons.light_mode_rounded,
                        label: 'Light',
                        sublabel: 'Terang',
                        selected: theme.isLight,
                        isDark: isDark,
                        onTap: () => theme.setThemeMode(ThemeMode.light),
                        activeColor: const Color(0xFFFFC107),
                        activeBg: const Color(0xFFFFF8E1),
                      ),
                      const SizedBox(width: 8),
                      _themeOptionCard(
                        context,
                        icon: Icons.dark_mode_rounded,
                        label: 'Dark',
                        sublabel: 'Gelap',
                        selected: theme.isDark,
                        isDark: isDark,
                        onTap: () => theme.setThemeMode(ThemeMode.dark),
                        activeColor: const Color(0xFF7C4DFF),
                        activeBg: const Color(0xFFEDE7F6),
                      ),
                      const SizedBox(width: 8),
                      _themeOptionCard(
                        context,
                        icon: Icons.contrast_rounded,
                        label: 'Auto',
                        sublabel: 'Sistem',
                        selected: theme.isSystem,
                        isDark: isDark,
                        onTap: () => theme.setThemeMode(ThemeMode.system),
                        activeColor: AppColors.primary,
                        activeBg: AppColors.chipBg,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Info App ──
          _sectionLabel('Tentang Aplikasi', textMed),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: dividerColor),
            ),
            child: Column(
              children: [
                _infoTile(
                  icon: Icons.info_outline_rounded,
                  label: 'Versi Aplikasi',
                  value: '1.0.0',
                  textDark: textDark,
                  textMed: textMed,
                  dividerColor: dividerColor,
                  showDivider: true,
                ),
                _infoTile(
                  icon: Icons.business_center_outlined,
                  label: 'Nama Aplikasi',
                  value: 'Flex POS',
                  textDark: textDark,
                  textMed: textMed,
                  dividerColor: dividerColor,
                  showDivider: true,
                ),
                _infoTile(
                  icon: Icons.code_rounded,
                  label: 'Platform',
                  value: 'Flutter (Android)',
                  textDark: textDark,
                  textMed: textMed,
                  dividerColor: dividerColor,
                  showDivider: false,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Footer
          Center(
            child: Text(
              'Flex POS © 2026 Made in Bali UNDIKSHA',
              style: GoogleFonts.inter(fontSize: 10, color: textMed),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _themeOptionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String sublabel,
    required bool selected,
    required bool isDark,
    required VoidCallback onTap,
    required Color activeColor,
    required Color activeBg,
  }) {
    final cardColor = isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade50;
    final borderColor = selected
        ? activeColor
        : (isDark ? Colors.white12 : Colors.grey.shade200);
    final bgColor = selected
        ? (isDark ? activeColor.withAlpha(40) : activeBg)
        : cardColor;
    final iconColor = selected ? activeColor : Colors.grey;
    final labelColor = selected
        ? activeColor
        : (isDark ? Colors.white60 : Colors.grey);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: activeColor.withAlpha(40),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Column(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: labelColor,
                ),
              ),
              Text(
                sublabel,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: labelColor.withAlpha(180),
                ),
              ),
              if (selected) ...[
                const SizedBox(height: 6),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: activeColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    required Color textDark,
    required Color textMed,
    required Color dividerColor,
    required bool showDivider,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 12),
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 13, color: textDark),
              ),
              const Spacer(),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: textMed,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (showDivider) Divider(height: 1, color: dividerColor),
      ],
    );
  }
}
