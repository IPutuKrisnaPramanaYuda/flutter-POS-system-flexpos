import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import '../data/dummy_data.dart';
import '../main.dart';
import '../services/api_service.dart';

class CartItem {
  final String menuId;
  final String nama;
  final int harga;
  int qty;

  CartItem({required this.menuId, required this.nama, required this.harga, required this.qty});

  int get subtotal => harga * qty;
}

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key});

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  // State transaksi
  Map<String, dynamic>? _selectedCustomer; // null = Guest
  bool _isGuest = true;
  final List<CartItem> _cart = [];
  bool _showCart = false;
  
  // Fitur pencarian, meja & kategori
  String _searchQuery = '';
  String _activeCategory = 'Semua';
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _tableCtrl = TextEditingController();

  int get _grandTotal => _cart.fold(0, (sum, item) => sum + item.subtotal);

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

  // ========================
  // TAHAP 2: Tambah ke Keranjang Instan
  // ========================
  void _addToCartInstantly(Map<String, dynamic> menu) {
    final int stokTersedia = menu['stok'] as int;
    final existingItem = _cart.where((c) => c.menuId == menu['id']).firstOrNull;
    final int alreadyInCart = existingItem?.qty ?? 0;

    if (alreadyInCart >= stokTersedia) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stok "${menu['nama']}" tidak mencukupi! Tersedia: $stokTersedia'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      if (existingItem != null) {
        existingItem.qty++;
      } else {
        _cart.add(CartItem(
          menuId: menu['id'],
          nama: menu['nama'],
          harga: menu['harga'],
          qty: 1,
        ));
      }
      _showCart = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${menu['nama']} masuk keranjang'),
        backgroundColor: AppColors.accent,
        duration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _processCheckout(int bayar, int kembalian, String method, Map<String, dynamic>? selectedCustomer, bool isGuestMode) async {
    final messenger = ScaffoldMessenger.of(context);
    final String idTransaksi = 'TRX-${DateTime.now().millisecondsSinceEpoch}';
    final String idUser = DummyDatabase.currentUser?['id'] ?? 'K001';
    final String idPelanggan = isGuestMode ? 'Guest' : (selectedCustomer?['id'] ?? 'Guest');
    final String tanggal = DateTime.now().toString().split('.')[0];

    final Map<String, dynamic> transaksiPayload = {
      "transaksi": {
        "id_transaksi": idTransaksi,
        "id_user": idUser,
        "id_pelanggan": idPelanggan,
        "total_harga": _grandTotal,
        "bayar": bayar,
        "kembalian": kembalian,
        "tanggal": tanggal
      },
      "items": _cart.map((item) => {
        "id_transaksi": idTransaksi,
        "id_menu": item.menuId,
        "qty": item.qty,
        "subtotal": item.subtotal
      }).toList()
    };

    // 1. Simpan/potong stok lokal HP
    for (final item in _cart) {
      await DummyDatabase.updateProductStock(item.menuId, item.qty);
    }

    setState(() {
      _isGuest = isGuestMode;
      _selectedCustomer = selectedCustomer;
    });

    // 2. Kirim ke API GAS / Simpan pending
    final res = await ApiService.checkoutTransaction(transaksiPayload);
    
    if (res['status'] == 'success') {
      messenger.showSnackBar(
        SnackBar(content: Text(res['message']), backgroundColor: AppColors.accent),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(res['message']), backgroundColor: Colors.orange),
      );
    }

    _showReceiptDialog(bayar, kembalian, method);
  }

  // ========================
  // TAHAP 3 & 4: Dialog Pembayaran Terkoneksi Member
  // ========================
  void _showPaymentDialog() {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keranjang masih kosong!'), backgroundColor: Colors.orange),
      );
      return;
    }

    final TextEditingController bayarCtrl = TextEditingController();
    final TextEditingController memberIdCtrl = TextEditingController();
    
    // Default state saat dialog dibuka (menggunakan state lokal dialog)
    bool isGuestMode = _isGuest;
    Map<String, dynamic>? selectedCustomer = _selectedCustomer;
    int kembalian = 0;
    String selectedMethod = 'Cash';
    String searchError = '';
    String? dialogError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setD) {
          final isDarkDlg = Theme.of(context).brightness == Brightness.dark;
          final dlgTextColor = isDarkDlg ? Colors.white : AppColors.textDark;
          final dlgTextMedColor = isDarkDlg ? Colors.white60 : AppColors.textMed;
          final dlgCardColor = isDarkDlg ? AppColors.darkCard : Colors.white;
          final dlgCardBorder = isDarkDlg ? Colors.white.withAlpha(15) : Colors.grey.shade200;
          final optionBgColor = isDarkDlg ? Colors.white10 : Colors.grey.shade100;
          final optionBorderColor = isDarkDlg ? Colors.white.withAlpha(15) : Colors.grey.shade300;
          final chipBg = isDarkDlg ? AppColors.primary.withAlpha(40) : AppColors.chipBg;

          return AlertDialog(
            scrollable: true,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Pembayaran & Pelanggan',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: dlgTextColor, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Pilih Pelanggan (Guest vs Member)
                Text('Pilih Tipe Pelanggan:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: dlgTextMedColor)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setD(() {
                            isGuestMode = true;
                            selectedCustomer = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isGuestMode ? AppColors.primary : optionBgColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isGuestMode ? Colors.transparent : optionBorderColor),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.person_outline_rounded,
                                  color: isGuestMode ? Colors.white : Colors.grey, size: 18),
                              const SizedBox(height: 2),
                              Text(
                                'Guest',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  color: isGuestMode ? Colors.white : Colors.grey,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setD(() {
                            isGuestMode = false;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: !isGuestMode ? AppColors.primary : optionBgColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: !isGuestMode ? Colors.transparent : optionBorderColor),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.card_membership_rounded,
                                  color: !isGuestMode ? Colors.white : Colors.grey, size: 18),
                              const SizedBox(height: 2),
                              Text(
                                'Member',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  color: !isGuestMode ? Colors.white : Colors.grey,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Jika mode member, tampilkan input pencarian member
                if (!isGuestMode) ...[
                  if (selectedCustomer != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(selectedCustomer?['nama'], style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                              Text('ID: ${selectedCustomer?['id']}', style: GoogleFonts.inter(fontSize: 10, color: dlgTextMedColor)),
                            ],
                          ),
                          GestureDetector(
                            onTap: () {
                              setD(() {
                                selectedCustomer = null;
                              });
                            },
                            child: const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 20),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    TextField(
                      controller: memberIdCtrl,
                      style: GoogleFonts.inter(fontSize: 12),
                      decoration: InputDecoration(
                        labelText: 'Cari Nama / ID Member',
                        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 18),
                        errorText: searchError.isEmpty ? null : searchError,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 80,
                      decoration: BoxDecoration(
                        border: Border.all(color: dlgCardBorder),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: DummyDatabase.memberList.length,
                        itemBuilder: (ctx, i) {
                          final m = DummyDatabase.memberList[i];
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                            title: Text(m['nama'], style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                            subtitle: Text(m['id'], style: GoogleFonts.inter(fontSize: 10)),
                            onTap: () {
                              setD(() {
                                selectedCustomer = m;
                                searchError = '';
                                memberIdCtrl.clear();
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                ],
                
                const Divider(),
                const SizedBox(height: 6),

                // 2. Info Grand Total
                Container(
                  padding: const EdgeInsets.all(10),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text('Grand Total', style: GoogleFonts.inter(fontSize: 11, color: dlgTextMedColor)),
                      const SizedBox(height: 2),
                      Text(
                        _formatRupiah(_grandTotal),
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 3. Pilihan Metode Pembayaran
                Text('Pilih Metode Pembayaran:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: dlgTextMedColor)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setD(() {
                            selectedMethod = 'Cash';
                          });
                        },
                        icon: Icon(Icons.money_rounded, size: 16, color: selectedMethod == 'Cash' ? Colors.white : AppColors.primary),
                        label: Text('Tunai / Cash', style: GoogleFonts.inter(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: selectedMethod == 'Cash' ? AppColors.primary : (isDarkDlg ? Colors.white10 : Colors.white),
                          foregroundColor: selectedMethod == 'Cash' ? Colors.white : AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setD(() {
                            selectedMethod = 'QRIS';
                            bayarCtrl.text = _grandTotal.toString();
                            kembalian = 0;
                          });
                        },
                        icon: Icon(Icons.qr_code_scanner_rounded, size: 16, color: selectedMethod == 'QRIS' ? Colors.white : AppColors.primary),
                        label: Text('QRIS Digital', style: GoogleFonts.inter(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: selectedMethod == 'QRIS' ? AppColors.primary : (isDarkDlg ? Colors.white10 : Colors.white),
                          foregroundColor: selectedMethod == 'QRIS' ? Colors.white : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (selectedMethod == 'Cash') ...[
                  TextField(
                    controller: bayarCtrl,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.inter(fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Uang Tunai Diterima',
                      prefixIcon: Icon(Icons.payments_outlined, color: AppColors.primary, size: 20),
                      prefixText: 'Rp ',
                    ),
                    onChanged: (val) {
                      final bayar = int.tryParse(val.replaceAll('.', '')) ?? 0;
                      setD(() => kembalian = bayar - _grandTotal);
                    },
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kembalian >= 0 ? Colors.green.withAlpha(20) : Colors.red.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: kembalian >= 0 ? Colors.green.shade200 : Colors.red.shade200,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Kembalian:', style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 12)),
                        Text(
                          kembalian < 0 ? 'Kurang Rp ${-kembalian}' : _formatRupiah(kembalian),
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: kembalian >= 0 ? Colors.green.shade700 : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // QRIS TANPA GAMBAR QR
                  Container(
                    padding: const EdgeInsets.all(14),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: dlgCardColor,
                      border: Border.all(color: dlgCardBorder),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.qr_code_scanner_rounded, size: 40, color: AppColors.primary),
                        const SizedBox(height: 6),
                        Text(
                          'Silakan scan QRIS di layar EDC/Monitor Anda.',
                          style: GoogleFonts.inter(fontSize: 11, color: dlgTextMedColor),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Transaksi akan otomatis lunas sebesar:',
                          style: GoogleFonts.inter(fontSize: 10, color: dlgTextMedColor),
                        ),
                        Text(
                          _formatRupiah(_grandTotal),
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ],
                if (dialogError != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDarkDlg ? Colors.red.withAlpha(20) : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDarkDlg ? Colors.red.withAlpha(40) : Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            dialogError!,
                            style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Batal', style: GoogleFonts.inter()),
              ),
              if (selectedMethod == 'Cash')
                ElevatedButton.icon(
                  onPressed: () {
                    if (!isGuestMode && selectedCustomer == null) {
                      setD(() {
                        dialogError = 'Pilih member terlebih dahulu!';
                      });
                      return;
                    }
                    final bayar = int.tryParse(bayarCtrl.text.replaceAll('.', '')) ?? 0;
                    if (bayar < _grandTotal) {
                      setD(() {
                        dialogError = 'Uang tunai tidak mencukupi!';
                      });
                      return;
                    }
                    dialogError = null;
                    Navigator.pop(ctx);
                    _processCheckout(bayar, kembalian, 'Cash', selectedCustomer, isGuestMode);
                  },
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                  label: Text('Bayar Tunai', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                )
              else
                ElevatedButton.icon(
                  onPressed: () {
                    if (!isGuestMode && selectedCustomer == null) {
                      setD(() {
                        dialogError = 'Pilih member terlebih dahulu!';
                      });
                      return;
                    }
                    dialogError = null;
                    _handleQrisPayment(
                      dialogCtx: ctx,
                      selectedCustomer: selectedCustomer,
                      isGuestMode: isGuestMode,
                    );
                  },
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                  label: Text('Bayar QRIS', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return PopScope(
          canPop: false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
                const SizedBox(height: 20),
                Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.textDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleQrisPayment({
    required BuildContext dialogCtx,
    required Map<String, dynamic>? selectedCustomer,
    required bool isGuestMode,
  }) async {
    final picker = ImagePicker();
    try {
      // Buka kamera untuk menjepret bukti pembayaran QRIS
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70, // Kompres sedikit agar ukuran gambar hemat memori
      );

      if (photo == null) {
        // Kasir membatalkan pengambilan foto
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pembayaran QRIS dibatalkan: Foto bukti pembayaran harus diambil!'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      // Tutup dialog pembayaran secara instan
      if (dialogCtx.mounted) {
        Navigator.pop(dialogCtx);
      }

      // Tampilkan dialog loading verifikasi agar tidak ambigu
      if (mounted) {
        _showLoadingDialog(context, 'Memverifikasi Pembayaran & Menyimpan Bukti QRIS...');
      }

      // Simpan foto bukti di latar belakang (background task)
      _saveQrisPhotoInBackground(photo);

      // Berikan delay animasi loading selama 1.5 detik
      await Future.delayed(const Duration(milliseconds: 1500));

      // Tutup dialog loading
      if (mounted) {
        Navigator.pop(context);
      }

      // Lanjutkan ke proses checkout & cetak struk
      _processCheckout(_grandTotal, 0, 'QRIS', selectedCustomer, isGuestMode);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan kamera: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _saveQrisPhotoInBackground(XFile photo) async {
    try {
      // 1. Simpan langsung ke Galeri Sistem (DCIM/Pictures) menggunakan package Gal (MediaStore API)
      await Gal.putImage(photo.path);
      debugPrint('[QRIS Photo] Berhasil disimpan langsung ke Galeri HP (DCIM/Pictures) via MediaStore.');
    } catch (e) {
      debugPrint('[QRIS Photo] Gagal menyimpan ke Galeri HP: $e. Mencoba fallback ke penyimpanan lokal.');
      
      // Fallback: simpan di direktori privat aplikasi jika Galeri gagal
      try {
        final Directory? extDir = await getExternalStorageDirectory();
        final Directory appDir = extDir ?? await getApplicationDocumentsDirectory();
        
        final String saveDirPath = '${appDir.path}/FlexPOS_QRIS';
        final Directory saveDir = Directory(saveDirPath);
        if (!await saveDir.exists()) {
          await saveDir.create(recursive: true);
        }

        final String fileName = 'QRIS_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final String destinationPath = '$saveDirPath/$fileName';
        
        final File localImageFile = File(photo.path);
        await localImageFile.copy(destinationPath);
        
        debugPrint('[QRIS Photo Fallback] Berhasil disimpan di: $destinationPath');
      } catch (err) {
        debugPrint('[QRIS Photo Fallback] Gagal menyimpan foto cadangan: $err');
      }
    }
  }

  // ========================
  // TAHAP 5: Struk & Download (Scroll Overflow Fix)
  // ========================
  String _generateReceiptText(int bayar, int kembalian, String method) {
    final cashier = DummyDatabase.currentUser?['nama'] ?? 'Kasir';
    final customer = _isGuest ? 'Guest' : _selectedCustomer?['nama'] ?? 'Guest';
    final dateStr = DateTime.now().toString().split('.')[0];
    final tableNo = _tableCtrl.text.trim();

    final buffer = StringBuffer();
    buffer.writeln('========================================');
    buffer.writeln('                FlexPOS                 ');
    buffer.writeln('         Flexible Point of Sale         ');
    buffer.writeln('========================================');
    buffer.writeln('Waktu   : $dateStr');
    buffer.writeln('Kasir   : $cashier');
    buffer.writeln('Member  : $customer');
    if (tableNo.isNotEmpty) {
      buffer.writeln('Meja    : No. $tableNo');
    }
    buffer.writeln('----------------------------------------');
    for (final item in _cart) {
      buffer.writeln(item.nama);
      final priceDetail = '${item.qty} x ${_formatRupiah(item.harga)}';
      final sub = _formatRupiah(item.subtotal);
      final spaceLen = 40 - priceDetail.length - sub.length;
      final spaces = spaceLen > 0 ? ' ' * spaceLen : ' ';
      buffer.writeln('$priceDetail$spaces$sub');
    }
    buffer.writeln('----------------------------------------');
    
    final gtStr = _formatRupiah(_grandTotal);
    final gtLine = 'Grand Total : $gtStr';
    buffer.writeln(' ' * (40 - gtLine.length) + gtLine);

    final mtdLine = 'Metode      : $method';
    buffer.writeln(' ' * (40 - mtdLine.length) + mtdLine);

    final byrStr = _formatRupiah(bayar);
    final byrLine = 'Bayar       : $byrStr';
    buffer.writeln(' ' * (40 - byrLine.length) + byrLine);

    final kemStr = _formatRupiah(kembalian);
    final kemLine = 'Kembalian   : $kemStr';
    buffer.writeln(' ' * (40 - kemLine.length) + kemLine);
    buffer.writeln('========================================');
    buffer.writeln('       Terima kasih atas kunjungan      ');
    buffer.writeln('                Anda!                   ');
    buffer.writeln('========================================');
    return buffer.toString();
  }

  void _showReceiptDialog(int bayar, int kembalian, String method) {
    final receiptText = _generateReceiptText(bayar, kembalian, method);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        // Set scrollable ke true agar dialog menyesuaikan layar
        scrollable: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Transaksi Berhasil!',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview Struk dengan Scroll Mandiri (Fixed Height Constraint)
            // Ini untuk mencegah Bottom Overflow jika item belanja sangat banyak
            Container(
              height: 220,
              width: double.maxFinite,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: Text(
                  receiptText,
                  style: GoogleFonts.robotoMono(fontSize: 10, color: Colors.black87, height: 1.3),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Tombol download & print dikelompokkan rapat
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final file = File('receipt.txt');
                        await file.writeAsString(receiptText);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Struk disimpan ke ${file.absolute.path}'),
                            backgroundColor: AppColors.accent,
                          ),
                        );
                      } catch (e) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Simulasi download berhasil (TXT Struk dibuat di memori)'),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.download_rounded, size: 14),
                    label: Text('Unduh TXT', style: GoogleFonts.inter(fontSize: 10)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Mengirim struk ke printer...'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    },
                    icon: const Icon(Icons.print_rounded, size: 14),
                    label: Text('Cetak Struk', style: GoogleFonts.inter(fontSize: 10)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _cart.clear();
                _showCart = false;
                _isGuest = true;
                _selectedCustomer = null;
                _tableCtrl.clear();
                _searchCtrl.clear();
                _searchQuery = '';
                _activeCategory = 'Semua';
              });
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 38),
              backgroundColor: AppColors.primary,
            ),
            child: Text('Transaksi Baru', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(height: 4),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 38),
            ),
            child: Text('Kembali ke Dashboard', style: GoogleFonts.inter(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Widget pembangun item kartu menu (dipakai ulang)
  // ──────────────────────────────────────────────
  Widget _buildMenuCard(Map<String, dynamic> menu) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;
    final cardBorder = isDark ? Colors.white.withAlpha(15) : Colors.grey.shade200;
    final textColor = isDark ? Colors.white : AppColors.textDark;
    final textMedColor = isDark ? Colors.white60 : AppColors.textMed;
    final habisColor = isDark ? Colors.white30 : Colors.grey.shade100;
    final habisText = isDark ? Colors.white38 : Colors.grey;

    final stok = menu['stok'] as int;
    final isHabis = stok <= 0;
    final inCart = _cart.where((c) => c.menuId == menu['id']).firstOrNull;

    return GestureDetector(
      onTap: isHabis ? null : () => _addToCartInstantly(menu),
      child: Container(
        decoration: BoxDecoration(
          color: isHabis ? habisColor : cardColor,
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
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                menu['nama'],
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isHabis ? habisText : textColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                _formatRupiah(menu['harga']),
                style: GoogleFonts.inter(
                  color: isHabis ? habisText : AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isHabis ? 'Habis' : 'Stok: $stok',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: isHabis ? Colors.red : textMedColor,
                    ),
                  ),
                  if (inCart != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'x${inCart.qty}',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Panel keranjang — dapat dipakai di portrait maupun landscape
  // ──────────────────────────────────────────────
  Widget _buildCartPanel({bool isLandscape = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelColor = isDark ? AppColors.darkSurface : Colors.white;
    final panelBorder = isDark ? Colors.white.withAlpha(15) : Colors.grey.shade200;
    final textColor = isDark ? Colors.white : AppColors.textDark;
    final textMedColor = isDark ? Colors.white60 : AppColors.textMed;
    final emptyIconColor = isDark ? Colors.white24 : Colors.grey.shade300;
    final emptyTextColor = isDark ? Colors.white38 : Colors.grey.shade400;

    if (_cart.isEmpty) {
      if (isLandscape) {
        return Container(
          decoration: BoxDecoration(
            color: panelColor,
            border: Border(left: BorderSide(color: panelBorder)),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shopping_cart_outlined, size: 40, color: emptyIconColor),
                const SizedBox(height: 8),
                Text(
                  'Keranjang kosong',
                  style: GoogleFonts.inter(fontSize: 12, color: textMedColor),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ketuk produk untuk\nmenambahkannya',
                  style: GoogleFonts.inter(fontSize: 11, color: emptyTextColor),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: panelColor,
        boxShadow: isLandscape
            ? [BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 8, offset: const Offset(-2, 0))]
            : [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 15, offset: const Offset(0, -4))],
        borderRadius: isLandscape
            ? null
            : const BorderRadius.vertical(top: Radius.circular(20)),
        border: isLandscape ? Border(left: BorderSide(color: panelBorder)) : null,
      ),
      child: Column(
        children: [
          // Header keranjang
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Row(
              children: [
                const Icon(Icons.shopping_cart_rounded, color: AppColors.primary, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Keranjang Belanja',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: textColor,
                    ),
                  ),
                ),
                if (!isLandscape)
                  TextButton(
                    onPressed: () => setState(() => _showCart = false),
                    child: Text('Tutup',
                        style: GoogleFonts.inter(color: textMedColor, fontSize: 12)),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Daftar item
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: _cart.length,
              itemBuilder: (ctx, i) {
                final item = _cart[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.nama,
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: textColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded,
                            size: 18, color: AppColors.primary),
                        onPressed: () {
                          setState(() {
                            if (item.qty > 1) {
                              item.qty--;
                            } else {
                              _cart.removeAt(i);
                              if (_cart.isEmpty) _showCart = false;
                            }
                          });
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '${item.qty}',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: textColor),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline_rounded,
                            size: 18, color: AppColors.primary),
                        onPressed: () {
                          final menu =
                              DummyDatabase.menuList.firstWhere((m) => m['id'] == item.menuId);
                          if (item.qty < (menu['stok'] as int)) {
                            setState(() => item.qty++);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Batas maksimum stok tercapai!'),
                                backgroundColor: Colors.orange,
                                duration: Duration(milliseconds: 500),
                              ),
                            );
                          }
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatRupiah(item.subtotal),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Footer: Grand Total + Tombol Bayar
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Grand Total',
                        style: GoogleFonts.inter(color: textMedColor, fontSize: 11)),
                    Text(
                      _formatRupiah(_grandTotal),
                      style: GoogleFonts.inter(
                        fontSize: isLandscape ? 15 : 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: _showPaymentDialog,
                    icon: const Icon(Icons.payments_rounded, size: 16),
                    label: Text('Bayar Sekarang',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // ──────────────────────────────────────────────
  // Panel katalog menu (kiri/atas)
  // ──────────────────────────────────────────────
  Widget _buildCatalogPanel(
    List<Map<String, dynamic>> filteredMenus, {
    bool isLandscape = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textDark;

    return Column(
      children: [
        // ── Search & Table input berdampingan ──
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _searchCtrl,
                    style: GoogleFonts.inter(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Cari menu...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 16),
                      contentPadding: EdgeInsets.zero,
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 14),
                              onPressed: () {
                                setState(() {
                                  _searchCtrl.clear();
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _tableCtrl,
                    keyboardType: TextInputType.text,
                    style: GoogleFonts.inter(fontSize: 12),
                    decoration: const InputDecoration(
                      labelText: 'No. Meja',
                      prefixIcon:
                          Icon(Icons.table_restaurant_rounded, size: 16),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Horizontal Kategori Chips ──
        SizedBox(
          height: 34,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: DummyDatabase.categoryList.length + 1,
            itemBuilder: (ctx, index) {
              final catName =
                  index == 0 ? 'Semua' : DummyDatabase.categoryList[index - 1];
              final isActive = catName == _activeCategory;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FilterChip(
                  label: Text(
                    catName,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isActive ? Colors.white : textColor,
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: isActive,
                  selectedColor: AppColors.primary,
                  checkmarkColor: Colors.white,
                  backgroundColor: isDark ? Colors.white10 : Colors.white,
                  side: BorderSide(
                      color: isActive
                          ? Colors.transparent
                          : (isDark ? Colors.white.withAlpha(15) : Colors.grey.shade300)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  onSelected: (selected) {
                    setState(() => _activeCategory = catName);
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),

        // ── Grid produk ──
        Expanded(
          child: filteredMenus.isEmpty
              ? Center(
                  child: Text(
                    'Produk tidak ditemukan',
                    style: GoogleFonts.inter(color: AppColors.textMed),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(10),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    // Landscape: 3 kolom agar katalog lebih kompak
                    crossAxisCount: isLandscape ? 3 : 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: isLandscape ? 1.1 : 1.25,
                  ),
                  itemCount: filteredMenus.length,
                  itemBuilder: (context, index) =>
                      _buildMenuCard(filteredMenus[index]),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredMenus = DummyDatabase.menuList.where((menu) {
      final nameLower = menu['nama'].toString().toLowerCase();
      final category = menu['kategori'] ?? 'Uncategorized';
      final matchesSearch = nameLower.contains(_searchQuery.toLowerCase());
      final matchesCategory =
          _activeCategory == 'Semua' || category == _activeCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    return OrientationBuilder(
      builder: (context, orientation) {
        final isLandscape = orientation == Orientation.landscape;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text('Transaksi Baru'),
            actions: [
              // Ikon keranjang di AppBar hanya tampil saat portrait
              if (!isLandscape && _cart.isNotEmpty)
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.shopping_cart_rounded),
                      onPressed: () =>
                          setState(() => _showCart = !_showCart),
                    ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${_cart.length}',
                          style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // ═══════════════════════════════════════════
          // LANDSCAPE: Row — katalog (kiri) | keranjang (kanan)
          // PORTRAIT : Column — katalog atas, keranjang bawah
          // ═══════════════════════════════════════════
          body: isLandscape
              ? Row(
                  children: [
                    // Kiri: Katalog
                    Expanded(
                      flex: 3,
                      child: _buildCatalogPanel(
                        filteredMenus,
                        isLandscape: true,
                      ),
                    ),
                    // Kanan: Keranjang (selalu terlihat)
                    SizedBox(
                      width: 280,
                      child: _buildCartPanel(isLandscape: true),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Expanded(
                      child: _buildCatalogPanel(
                        filteredMenus,
                        isLandscape: false,
                      ),
                    ),

                    // Keranjang slide-up (portrait)
                    if (_showCart && _cart.isNotEmpty)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight:
                              MediaQuery.of(context).size.height * 0.42,
                        ),
                        child: _buildCartPanel(isLandscape: false),
                      ),

                    // Floating bar (portrait, keranjang tersembunyi)
                    if (!_showCart && _cart.isNotEmpty)
                      GestureDetector(
                        onTap: () => setState(() => _showCart = true),
                        child: Container(
                          margin:
                              const EdgeInsets.fromLTRB(10, 0, 10, 10),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withAlpha(50),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.shopping_cart_rounded,
                                  color: Colors.white, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                '${_cart.length} item',
                                style: GoogleFonts.inter(
                                    color: Colors.white70, fontSize: 12),
                              ),
                              const Spacer(),
                              Text(
                                _formatRupiah(_grandTotal),
                                style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                  Icons.keyboard_arrow_up_rounded,
                                  color: Colors.white,
                                  size: 18),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}
