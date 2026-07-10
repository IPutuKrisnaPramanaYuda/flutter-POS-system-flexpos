import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/dummy_data.dart';
import '../main.dart';

class ManageCashierScreen extends StatefulWidget {
  const ManageCashierScreen({super.key});

  @override
  State<ManageCashierScreen> createState() => _ManageCashierScreenState();
}

class _ManageCashierScreenState extends State<ManageCashierScreen> {
  final _namaCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  String _selectedRole = 'KASIR';
  bool _isPinObscure = true;

  @override
  void dispose() {
    _namaCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  void _showAddCashierSheet() {
    _namaCtrl.clear();
    _pinCtrl.clear();
    _selectedRole = 'KASIR';
    _showCashierFormSheet(isEdit: false);
  }

  void _showEditCashierDialog(Map<String, dynamic> cashier) {
    _namaCtrl.text = cashier['nama'] ?? '';
    _pinCtrl.text = cashier['pin'] ?? '';
    _selectedRole = cashier['role'] ?? 'KASIR';
    _showCashierFormSheet(isEdit: true, existingCashier: cashier);
  }

  void _showCashierFormSheet({required bool isEdit, Map<String, dynamic>? existingCashier}) {
    _isPinObscure = true;
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheet) {
          final isDarkSheet = Theme.of(context).brightness == Brightness.dark;
          final sheetTextColor = isDarkSheet ? Colors.white : AppColors.textDark;
          final sheetTextMedColor = isDarkSheet ? Colors.white60 : AppColors.textMed;

          return Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(isEdit ? 'Edit Data Kasir' : 'Tambah Kasir Baru',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: sheetTextColor)),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded, size: 20)),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _namaCtrl,
                  style: GoogleFonts.inter(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Nama Kasir',
                    prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.primary, size: 20),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _pinCtrl,
                  obscureText: _isPinObscure,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.inter(fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'PIN (4-6 digit)',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPinObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: sheetTextMedColor, size: 20,
                      ),
                      onPressed: () => setSheet(() => _isPinObscure = !_isPinObscure),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _selectedRole,
                  style: GoogleFonts.inter(fontSize: 13, color: sheetTextColor),
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    prefixIcon: Icon(Icons.admin_panel_settings_outlined, color: AppColors.primary, size: 20),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'KASIR', child: Text('KASIR')),
                    DropdownMenuItem(value: 'ADMIN', child: Text('ADMIN')),
                  ],
                  onChanged: (val) => setSheet(() => _selectedRole = val ?? 'KASIR'),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDarkSheet ? Colors.red.withAlpha(20) : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDarkSheet ? Colors.red.withAlpha(40) : Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMessage!,
                            style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final nama = _namaCtrl.text.trim();
                    final pin = _pinCtrl.text.trim();

                    if (nama.isEmpty || pin.isEmpty) {
                      setSheet(() {
                        errorMessage = 'Nama dan PIN wajib diisi!';
                      });
                      return;
                    }

                    final nameExists = DummyDatabase.cashierList.any((c) {
                      if (isEdit && existingCashier != null) {
                        if (c['id'] == existingCashier['id']) return false;
                      }
                      return c['nama'].toString().toLowerCase() == nama.toLowerCase();
                    });

                    if (nameExists) {
                      setSheet(() {
                        errorMessage = 'Nama kasir "$nama" sudah terdaftar!';
                      });
                      return;
                    }
                    errorMessage = null;

                    if (isEdit && existingCashier != null) {
                      DummyDatabase.updateCashier(existingCashier['id'], nama, pin, _selectedRole);
                    } else {
                      DummyDatabase.addCashier(nama, pin, _selectedRole);
                    }

                    setState(() {});
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEdit ? 'Data kasir diperbarui!' : 'Kasir "$nama" ditambahkan!'),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  },
                  icon: Icon(isEdit ? Icons.save_rounded : Icons.check_rounded, size: 18),
                  label: Text(isEdit ? 'Simpan Perubahan' : 'Simpan', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

  void _showDeleteDialog(Map<String, dynamic> cashier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus Kasir?', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
        content: Text('Yakin ingin menghapus kasir "${cashier['nama']}"?', style: GoogleFonts.inter(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal', style: GoogleFonts.inter())),
          ElevatedButton(
            onPressed: () {
              DummyDatabase.deleteCashier(cashier['id']);
              setState(() {});
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Kasir "${cashier['nama']}" dihapus.'), backgroundColor: Colors.redAccent),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text('Hapus', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cashiers = DummyDatabase.cashierList;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;
    final cardBorder = isDark ? Colors.white.withAlpha(15) : Colors.grey.shade200;
    final textColor = isDark ? Colors.white : AppColors.textDark;
    final textMedColor = isDark ? Colors.white60 : AppColors.textMed;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Kelola Kasir')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCashierSheet,
        icon: const Icon(Icons.person_add_rounded, size: 18),
        label: Text('Tambah Kasir', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
      ),
      body: cashiers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.manage_accounts_rounded, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  Text('Belum ada data kasir', style: GoogleFonts.inter(color: textMedColor)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
              itemCount: cashiers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final cashier = cashiers[index];
                final isAdmin = cashier['role'] == 'ADMIN';
                final avatarBg = isAdmin 
                    ? (isDark ? Colors.orange.shade900.withAlpha(40) : const Color(0xFFFFF3E0)) 
                    : (isDark ? AppColors.primary.withAlpha(40) : AppColors.chipBg);
                final avatarFg = isAdmin 
                    ? (isDark ? Colors.orange.shade300 : Colors.orange.shade700) 
                    : (isDark ? AppColors.primaryLight : AppColors.primary);

                return Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cardBorder),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: avatarBg,
                      child: Icon(
                        isAdmin ? Icons.verified_rounded : Icons.badge_rounded,
                        color: avatarFg,
                        size: 18,
                      ),
                    ),
                    title: Text(cashier['nama'],
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: textColor)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ID: ${cashier['id']}',
                            style: GoogleFonts.inter(color: textMedColor, fontSize: 11)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: avatarBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            cashier['role'],
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: avatarFg,
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit_outlined, color: isDark ? AppColors.primaryLight : AppColors.primary, size: 20),
                          onPressed: () => _showEditCashierDialog(cashier),
                        ),
                        if (!isAdmin)
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                            onPressed: () => _showDeleteDialog(cashier),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
