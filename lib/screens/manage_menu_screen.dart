import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/dummy_data.dart';
import '../main.dart';

class ManageMenuScreen extends StatefulWidget {
  const ManageMenuScreen({super.key});

  @override
  State<ManageMenuScreen> createState() => _ManageMenuScreenState();
}

class _ManageMenuScreenState extends State<ManageMenuScreen> {
  final _namaCtrl = TextEditingController();
  final _hargaCtrl = TextEditingController();
  final _stokCtrl = TextEditingController();
  String _selectedCategory = 'Coffee';

  @override
  void dispose() {
    _namaCtrl.dispose();
    _hargaCtrl.dispose();
    _stokCtrl.dispose();
    super.dispose();
  }

  String _formatRupiah(int amount) {
    final str = amount.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      if (count != 0 && count % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
      count++;
    }
    return 'Rp ${buffer.toString().split('').reversed.join()}';
  }

  // Dialog untuk mengelola Kategori (Tambah/Hapus)
  void _showManageCategoriesDialog() {
    final TextEditingController newCatCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final categories = DummyDatabase.categoryList;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'Kelola Kategori',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Form tambah kategori
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: newCatCtrl,
                          style: GoogleFonts.inter(fontSize: 12),
                          decoration: const InputDecoration(
                            labelText: 'Kategori Baru',
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.add_box_rounded, color: AppColors.primary, size: 32),
                        onPressed: () {
                          final name = newCatCtrl.text.trim();
                          if (name.isNotEmpty) {
                            DummyDatabase.addCategory(name);
                            newCatCtrl.clear();
                            setDialogState(() {});
                            setState(() {}); // refresh screen utama juga
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 6),
                  // Daftar kategori saat ini
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: categories.length,
                      itemBuilder: (ctx, index) {
                        final cat = categories[index];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(cat, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                            onPressed: () {
                              DummyDatabase.deleteCategory(cat);
                              setDialogState(() {});
                              setState(() {}); // refresh screen utama
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Tutup', style: GoogleFonts.inter()),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddMenuDialog() {
    _namaCtrl.clear();
    _hargaCtrl.clear();
    _stokCtrl.clear();
    if (DummyDatabase.categoryList.isNotEmpty) {
      _selectedCategory = DummyDatabase.categoryList.first;
    } else {
      _selectedCategory = 'Uncategorized';
      DummyDatabase.addCategory('Uncategorized');
    }
    _showMenuFormSheet(isEdit: false);
  }

  void _showEditMenuDialog(Map<String, dynamic> menu) {
    _namaCtrl.text = menu['nama'];
    _hargaCtrl.text = menu['harga'].toString();
    _stokCtrl.text = menu['stok'].toString();
    _selectedCategory = menu['kategori'] ?? 'Uncategorized';
    _showMenuFormSheet(isEdit: true, existingMenu: menu);
  }

  void _showMenuFormSheet({required bool isEdit, Map<String, dynamic>? existingMenu}) {
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
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
                    isEdit ? 'Edit Menu' : 'Tambah Menu Baru',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
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
                  labelText: 'Nama Menu / Produk',
                  prefixIcon: Icon(Icons.restaurant_menu_rounded, color: AppColors.primary, size: 20),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _hargaCtrl,
                keyboardType: TextInputType.number,
                style: GoogleFonts.inter(fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Harga (Rupiah)',
                  prefixIcon: Icon(Icons.attach_money_rounded, color: AppColors.primary, size: 20),
                  prefixText: 'Rp ',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _stokCtrl,
                keyboardType: TextInputType.number,
                style: GoogleFonts.inter(fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Jumlah Stok',
                  prefixIcon: Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 20),
                ),
              ),
              const SizedBox(height: 10),
              // Dropdown Kategori
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                decoration: const InputDecoration(
                  labelText: 'Kategori',
                  prefixIcon: Icon(Icons.category_rounded, color: AppColors.primary, size: 20),
                ),
                items: DummyDatabase.categoryList.map((cat) {
                  return DropdownMenuItem(value: cat, child: Text(cat));
                }).toList(),
                onChanged: (val) {
                  setSheetState(() {
                    _selectedCategory = val ?? 'Uncategorized';
                  });
                },
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
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
                    final harga = int.tryParse(_hargaCtrl.text.trim()) ?? 0;
                    final stok = int.tryParse(_stokCtrl.text.trim()) ?? 0;

                    if (nama.isEmpty || harga <= 0 || stok < 0) {
                      setSheetState(() {
                        errorMessage = 'Isi semua field dengan benar!';
                      });
                      return;
                    }
                    errorMessage = null;

                    if (isEdit && existingMenu != null) {
                      DummyDatabase.updateMenu(existingMenu['id'], nama, harga, stok, _selectedCategory);
                    } else {
                      DummyDatabase.addMenu(nama, harga, stok, _selectedCategory);
                    }
                    setState(() {});
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEdit ? 'Menu diperbarui!' : 'Menu "$nama" ditambahkan!'),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  },
                  icon: Icon(isEdit ? Icons.save_rounded : Icons.check_rounded, size: 18),
                  label: Text(
                    isEdit ? 'Simpan Perubahan' : 'Tambah Menu',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(Map<String, dynamic> menu) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus Menu?', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
        content: Text('Apakah Anda yakin ingin menghapus "${menu['nama']}"?', style: GoogleFonts.inter(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal', style: GoogleFonts.inter())),
          ElevatedButton(
            onPressed: () {
              DummyDatabase.deleteMenu(menu['id']);
              setState(() {});
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('"${menu['nama']}" berhasil dihapus.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: Text('Hapus', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Color _stokColor(int stok) {
    if (stok <= 0) return Colors.red;
    if (stok <= 5) return Colors.orange;
    return AppColors.accent;
  }

  @override
  Widget build(BuildContext context) {
    final menus = DummyDatabase.menuList;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Kelola Menu / Produk'),
        actions: [
          IconButton(
            icon: const Icon(Icons.category_rounded),
            onPressed: _showManageCategoriesDialog,
            tooltip: 'Kelola Kategori',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMenuDialog,
        icon: const Icon(Icons.add_rounded, size: 18),
        label: Text('Tambah Menu', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
      ),
      body: menus.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.restaurant_menu_rounded, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  Text('Belum ada data menu', style: GoogleFonts.inter(color: AppColors.textMed)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
              itemCount: menus.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final menu = menus[index];
                final stok = menu['stok'] as int;
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // Menghapus logo kopi bulat, langsung menampilkan teks
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                menu['nama'],
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    _formatRupiah(menu['harga']),
                                    style: GoogleFonts.inter(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.chipBg,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      menu['kategori'] ?? 'Uncategorized',
                                      style: GoogleFonts.inter(
                                        fontSize: 9,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.inventory_2_outlined, size: 12, color: _stokColor(stok)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Stok: $stok',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: _stokColor(stok),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (stok <= 5) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: stok <= 0 ? Colors.red.withAlpha(20) : Colors.orange.withAlpha(20),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        stok <= 0 ? 'Habis' : 'Menipis',
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          color: stok <= 0 ? Colors.red : Colors.orange,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: AppColors.textMed, size: 20),
                              onPressed: () => _showEditMenuDialog(menu),
                              tooltip: 'Edit Menu',
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(8),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                              onPressed: () => _showDeleteDialog(menu),
                              tooltip: 'Hapus Menu',
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(8),
                            ),
                          ],
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
