import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/dummy_data.dart';
import '../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isObscure = true;

  void _handleLogin() {
    if (_formKey.currentState!.validate()) {
      final nameInput = _nameController.text.trim();
      final pinInput = _pinController.text.trim();

      final matchedUser = DummyDatabase.cashierList.firstWhere(
        (cashier) =>
            cashier['nama'].toString().toLowerCase() == nameInput.toLowerCase() &&
            cashier['pin'].toString() == pinInput,
        orElse: () => {},
      );

      if (matchedUser.isNotEmpty) {
        DummyDatabase.currentUser = matchedUser;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Selamat datang, ${matchedUser['nama']}!'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (matchedUser['role'] == 'ADMIN') {
          Navigator.pushReplacementNamed(context, '/admin_dashboard');
        } else {
          Navigator.pushReplacementNamed(context, '/cashier_dashboard');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nama atau PIN salah. Silakan coba lagi.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.background;
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;
    final cardBorder = isDark ? Colors.white.withAlpha(15) : Colors.grey.shade200;
    final titleColor = isDark ? Colors.white : AppColors.textDark;
    final subtitleColor = isDark ? Colors.white60 : AppColors.textMed;
    final chipBg = isDark ? AppColors.darkCard : AppColors.chipBg;
    final chipText = isDark ? Colors.white70 : AppColors.primary;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Logo teks FlexPOS ──
                Column(
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Flex',
                            style: GoogleFonts.inter(
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                              letterSpacing: -1,
                            ),
                          ),
                          TextSpan(
                            text: 'POS',
                            style: GoogleFonts.inter(
                              fontSize: 40,
                              fontWeight: FontWeight.w300,
                              color: subtitleColor,
                              letterSpacing: -1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Flexible Point of Sale',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: subtitleColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // ── Card Form Login ──
                Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cardBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(isDark ? 40 : 8),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(22),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Masuk ke Akun',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Gunakan nama dan PIN yang terdaftar',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: subtitleColor,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Input Nama
                        TextFormField(
                          controller: _nameController,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: titleColor,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Nama Kasir / Admin',
                            prefixIcon: Icon(Icons.person_outline_rounded,
                                color: AppColors.primary, size: 20),
                          ),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                                  ? 'Nama tidak boleh kosong'
                                  : null,
                        ),
                        const SizedBox(height: 12),

                        // Input PIN
                        TextFormField(
                          controller: _pinController,
                          obscureText: _isObscure,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: titleColor,
                          ),
                          decoration: InputDecoration(
                            labelText: 'PIN Keamanan',
                            prefixIcon: const Icon(Icons.lock_outline_rounded,
                                color: AppColors.primary, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isObscure
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: subtitleColor,
                                size: 20,
                              ),
                              onPressed: () =>
                                  setState(() => _isObscure = !_isObscure),
                            ),
                          ),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                                  ? 'PIN tidak boleh kosong'
                                  : null,
                        ),
                        const SizedBox(height: 20),

                        // Tombol Login
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: _handleLogin,
                            child: Text(
                              'Masuk',
                              style: GoogleFonts.inter(
                                  fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Info default login (diperbarui)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Demo: ADMIN / 12345 (Admin) · Budi / 4321 (Kasir)',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: chipText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
