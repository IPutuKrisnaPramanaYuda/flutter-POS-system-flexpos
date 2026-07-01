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
    _isPinObscure = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
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
                  Text('Tambah Kasir Baru',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
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
                      color: AppColors.textMed, size: 20,
                    ),
                    onPressed: () => setSheet(() => _isPinObscure = !_isPinObscure),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _selectedRole,
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
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
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (_namaCtrl.text.trim().isEmpty || _pinCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nama dan PIN wajib diisi!'), backgroundColor: Colors.redAccent),
                      );
                      return;
                    }
                    DummyDatabase.addCashier(_namaCtrl.text.trim(), _pinCtrl.text.trim(), _selectedRole);
                    setState(() {});
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Kasir "${_namaCtrl.text.trim()}" ditambahkan!'), backgroundColor: AppColors.primary),
                    );
                  },
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text('Simpan', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
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

    return Scaffold(
      backgroundColor: AppColors.background,
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
                  Text('Belum ada data kasir', style: GoogleFonts.inter(color: AppColors.textMed)),
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
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: isAdmin ? const Color(0xFFFFF3E0) : AppColors.chipBg,
                      child: Icon(
                        isAdmin ? Icons.verified_rounded : Icons.badge_rounded,
                        color: isAdmin ? Colors.orange.shade700 : AppColors.primary,
                        size: 18,
                      ),
                    ),
                    title: Text(cashier['nama'],
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ID: ${cashier['id']}',
                            style: GoogleFonts.inter(color: AppColors.textMed, fontSize: 11)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isAdmin ? const Color(0xFFFFF3E0) : AppColors.chipBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            cashier['role'],
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isAdmin ? Colors.orange.shade700 : AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                      onPressed: () => _showDeleteDialog(cashier),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
