import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/dummy_data.dart';
import '../main.dart';

class ManageMemberScreen extends StatefulWidget {
  const ManageMemberScreen({super.key});

  @override
  State<ManageMemberScreen> createState() => _ManageMemberScreenState();
}

class _ManageMemberScreenState extends State<ManageMemberScreen> {
  final _namaCtrl = TextEditingController();
  final _teleponCtrl = TextEditingController();

  @override
  void dispose() {
    _namaCtrl.dispose();
    _teleponCtrl.dispose();
    super.dispose();
  }

  void _showAddMemberSheet() {
    _namaCtrl.clear();
    _teleponCtrl.clear();
    _showMemberFormSheet(isEdit: false);
  }

  void _showEditMemberDialog(Map<String, dynamic> member) {
    _namaCtrl.text = member['nama'] ?? '';
    _teleponCtrl.text = member['telepon'] ?? '';
    _showMemberFormSheet(isEdit: true, existingMember: member);
  }

  void _showDeleteDialog(Map<String, dynamic> member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus Member?', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
        content: Text('Yakin ingin menghapus member "${member['nama']}"?', style: GoogleFonts.inter(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal', style: GoogleFonts.inter())),
          ElevatedButton(
            onPressed: () {
              DummyDatabase.deleteMember(member['id']);
              setState(() {});
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Member "${member['nama']}" dihapus.'), backgroundColor: Colors.redAccent),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: Text('Hapus', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showMemberFormSheet({required bool isEdit, Map<String, dynamic>? existingMember}) {
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

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEdit ? 'Edit Data Member' : 'Daftarkan Member Baru',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: sheetTextColor,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _namaCtrl,
                  style: GoogleFonts.inter(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Nama Lengkap Pelanggan',
                    prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.primary, size: 20),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _teleponCtrl,
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.inter(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Nomor Telepon (WhatsApp)',
                    prefixIcon: Icon(Icons.phone_outlined, color: AppColors.primary, size: 20),
                  ),
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
                    final telepon = _teleponCtrl.text.trim();

                    if (nama.isEmpty || telepon.isEmpty) {
                      setSheet(() {
                        errorMessage = 'Nama dan nomor telepon wajib diisi!';
                      });
                      return;
                    }
                    errorMessage = null;

                    if (isEdit && existingMember != null) {
                      DummyDatabase.updateMember(existingMember['id'], nama, telepon);
                    } else {
                      DummyDatabase.addMember(nama, telepon);
                    }
                    setState(() {});
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEdit ? 'Data member diperbarui!' : 'Member "$nama" didaftarkan!'),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  },
                  icon: Icon(isEdit ? Icons.save_rounded : Icons.person_add_rounded, size: 18),
                  label: Text(isEdit ? 'Simpan Perubahan' : 'Daftarkan Member', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final members = DummyDatabase.memberList;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;
    final cardBorder = isDark ? Colors.white.withAlpha(15) : Colors.grey.shade200;
    final textColor = isDark ? Colors.white : AppColors.textDark;
    final textMedColor = isDark ? Colors.white60 : AppColors.textMed;
    final primaryColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final chipBg = isDark ? AppColors.primary.withAlpha(40) : AppColors.chipBg;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Kelola Member'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMemberSheet,
        icon: const Icon(Icons.person_add_rounded, size: 18),
        label: Text('Tambah Member', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
      ),
      body: Column(
        children: [
          // Stats summary
          Container(
            margin: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(5),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.people_alt_rounded, color: primaryColor, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Member Terdaftar', style: GoogleFonts.inter(color: textMedColor, fontSize: 11)),
                    Text(
                      '${members.length} Pelanggan',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: members.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_alt_rounded, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        Text('Belum ada member terdaftar', style: GoogleFonts.inter(color: textMedColor)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 90),
                    itemCount: members.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final member = members[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cardBorder),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: chipBg,
                            child: Text(
                              member['nama'].toString().substring(0, 1).toUpperCase(),
                              style: GoogleFonts.inter(
                                color: primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          title: Text(
                            member['nama'],
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ID: ${member['id']}', style: GoogleFonts.inter(color: textMedColor, fontSize: 10)),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.phone_outlined, size: 12, color: primaryColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    member['telepon'].toString(),
                                    style: GoogleFonts.inter(fontSize: 11, color: textColor),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit_outlined, color: primaryColor, size: 20),
                                onPressed: () => _showEditMemberDialog(member),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                onPressed: () => _showDeleteDialog(member),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
