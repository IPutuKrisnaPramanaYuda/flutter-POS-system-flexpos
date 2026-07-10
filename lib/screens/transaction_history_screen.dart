import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/dummy_data.dart';
import '../main.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  String _searchQuery = '';
  String _activeDayFilter = 'Semua'; // Pilihan: Semua, Hari Ini, 7 Hari, 30 Hari
  final TextEditingController _searchCtrl = TextEditingController();

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

  // Cek apakah suatu tanggal transaksi masuk dalam jangkauan filter hari
  bool _filterByDate(String dateStr) {
    try {
      final txDate = DateTime.parse(dateStr.split(' ')[0]); // yyyy-MM-dd
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final difference = today.difference(txDate).inDays;

      if (_activeDayFilter == 'Hari Ini') {
        return difference == 0;
      } else if (_activeDayFilter == '7 Hari') {
        return difference >= 0 && difference < 7;
      } else if (_activeDayFilter == '30 Hari') {
        return difference >= 0 && difference < 30;
      }
    } catch (_) {}
    return true; // default 'Semua'
  }

  // Menghitung menu terlaris secara dinamis berdasarkan transaksi yang terfilter
  List<Map<String, dynamic>> _calculateTopSellingMenus(List<Map<String, dynamic>> filteredTx) {
    final Map<String, int> qtyMap = {};

    // Ambil semua ID Transaksi yang telah difilter hari & pencarian
    final filteredTxIds = filteredTx.map((tx) => tx['id_transaksi'].toString()).toSet();

    // Akumulasikan quantity terjual untuk setiap menu dari detail transaksi
    for (final det in DummyDatabase.transactionDetailsHistory) {
      final String txId = det['id_transaksi'].toString();
      if (filteredTxIds.contains(txId)) {
        final String menuId = det['id_menu'].toString();
        final int qty = int.tryParse(det['qty'].toString()) ?? 0;
        qtyMap[menuId] = (qtyMap[menuId] ?? 0) + qty;
      }
    }

    // Ubah map menjadi list untuk diurutkan
    final List<Map<String, dynamic>> topMenus = [];
    qtyMap.forEach((menuId, qty) {
      // Cari detail nama menu & kategori
      final menuInfo = DummyDatabase.menuList.firstWhere(
        (m) => m['id'] == menuId,
        orElse: () => {"nama": "Produk Terhapus", "kategori": "-"},
      );
      topMenus.add({
        "id": menuId,
        "nama": menuInfo['nama'],
        "kategori": menuInfo['kategori'],
        "qty_terjual": qty
      });
    });

    // Urutkan secara descending (qty_terjual terbesar dahulu)
    topMenus.sort((a, b) => (b['qty_terjual'] as int).compareTo(a['qty_terjual'] as int));
    return topMenus;
  }

  // Teks salinan struk untuk reprint
  String _rebuildReceiptText(Map<String, dynamic> tx, List<Map<String, dynamic>> items) {
    final cashier = DummyDatabase.cashierList.firstWhere(
      (c) => c['id'] == tx['id_user'],
      orElse: () => {"nama": "Kasir"},
    )['nama'];
    
    var customerName = 'Guest';
    if (tx['id_pelanggan'] != 'Guest') {
      final member = DummyDatabase.memberList.firstWhere(
        (m) => m['id'] == tx['id_pelanggan'],
        orElse: () => {},
      );
      if (member.isNotEmpty) {
        customerName = member['nama'];
      } else {
        customerName = tx['id_pelanggan'].toString();
      }
    }

    final dateStr = tx['tanggal'].toString();
    final total = int.tryParse(tx['total_harga'].toString()) ?? 0;
    final bayar = int.tryParse(tx['bayar'].toString()) ?? 0;
    final kembalian = int.tryParse(tx['kembalian'].toString()) ?? 0;

    final buffer = StringBuffer();
    buffer.writeln('========================================');
    buffer.writeln('                FlexPOS                 ');
    buffer.writeln('         Flexible Point of Sale         ');
    buffer.writeln('========================================');
    buffer.writeln('Waktu   : $dateStr');
    buffer.writeln('Kasir   : $cashier');
    buffer.writeln('Member  : $customerName');
    buffer.writeln('Invoice : ${tx['id_transaksi']}');
    buffer.writeln('----------------------------------------');
    
    for (final item in items) {
      final menuName = DummyDatabase.menuList.firstWhere(
        (m) => m['id'] == item['id_menu'],
        orElse: () => {"nama": "Item Terhapus"},
      )['nama'];

      buffer.writeln(menuName);
      final int qty = int.tryParse(item['qty'].toString()) ?? 0;
      final int sub = int.tryParse(item['subtotal'].toString()) ?? 0;
      final int unitPrice = qty > 0 ? (sub ~/ qty) : sub;

      final priceDetail = '$qty x ${_formatRupiah(unitPrice)}';
      final subStr = _formatRupiah(sub);
      final spaceLen = 40 - priceDetail.length - subStr.length;
      final spaces = spaceLen > 0 ? ' ' * spaceLen : ' ';
      buffer.writeln('$priceDetail$spaces$subStr');
    }
    buffer.writeln('----------------------------------------');
    
    final gtLine = 'Grand Total : ${_formatRupiah(total)}';
    buffer.writeln(' ' * (40 - gtLine.length) + gtLine);

    final byrLine = 'Bayar       : ${_formatRupiah(bayar)}';
    buffer.writeln(' ' * (40 - byrLine.length) + byrLine);

    final kemLine = 'Kembalian   : ${_formatRupiah(kembalian)}';
    buffer.writeln(' ' * (40 - kemLine.length) + kemLine);
    buffer.writeln('========================================');
    buffer.writeln('     SALINAN STRUK / REPRINT RECEIPT    ');
    buffer.writeln('       Terima kasih atas kunjungan      ');
    buffer.writeln('                Anda!                   ');
    buffer.writeln('========================================');
    return buffer.toString();
  }

  void _showReprintDialog(Map<String, dynamic> tx, List<Map<String, dynamic>> items) {
    final receiptText = _rebuildReceiptText(tx, items);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Salinan Struk',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                            content: Text('Salinan struk disimpan ke ${file.absolute.path}'),
                            backgroundColor: AppColors.accent,
                          ),
                        );
                      } catch (e) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Gagal menyimpan file struk.'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.download_rounded, size: 14),
                    label: Text('Unduh TXT', style: GoogleFonts.inter(fontSize: 10)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Mengirim salinan struk ke printer termal...'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    },
                    icon: const Icon(Icons.print_rounded, size: 14),
                    label: Text('Cetak Struk', style: GoogleFonts.inter(fontSize: 10)),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Tutup', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );
  }

  void _showDetailDialog(Map<String, dynamic> tx) {
    final user = DummyDatabase.currentUser;
    final isAdmin = user?['role'] == 'ADMIN';
    final idTransaksi = tx['id_transaksi'];

    final details = DummyDatabase.transactionDetailsHistory
        .where((d) => d['id_transaksi'] == idTransaksi)
        .toList();

    showDialog(
      context: context,
      builder: (ctx) {
        final isDarkDlg = Theme.of(ctx).brightness == Brightness.dark;
        final dlgTextColor = isDarkDlg ? Colors.white : AppColors.textDark;
        final dlgTextMedColor = isDarkDlg ? Colors.white60 : AppColors.textMed;
        final dlgPrimaryColor = isDarkDlg ? AppColors.primaryLight : AppColors.primary;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Detail Penjualan',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Invoice: $idTransaksi', style: GoogleFonts.inter(fontSize: 12, color: dlgTextMedColor)),
                Text('Tanggal: ${tx['tanggal']}', style: GoogleFonts.inter(fontSize: 11, color: dlgTextMedColor)),
                const SizedBox(height: 8),
                const Divider(),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: details.length,
                    itemBuilder: (context, i) {
                      final item = details[i];
                      final menuName = DummyDatabase.menuList.firstWhere(
                        (m) => m['id'] == item['id_menu'],
                        orElse: () => {"nama": "Produk Terhapus"},
                      )['nama'];
                      final qty = item['qty'];
                      final sub = int.tryParse(item['subtotal'].toString()) ?? 0;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '$menuName (x$qty)',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: dlgTextColor),
                              ),
                            ),
                            Text(
                              _formatRupiah(sub),
                              style: GoogleFonts.inter(fontSize: 12, color: dlgTextMedColor),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Belanja:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                    Text(
                      _formatRupiah(int.tryParse(tx['total_harga'].toString()) ?? 0),
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: dlgPrimaryColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _showReprintDialog(tx, details);
              },
              icon: const Icon(Icons.receipt_long_rounded, size: 14),
              label: Text('Salinan Struk', style: GoogleFonts.inter(fontSize: 11)),
            ),
            if (isAdmin)
              ElevatedButton.icon(
                onPressed: () => _confirmDeleteTransaction(tx),
                icon: const Icon(Icons.delete_forever_rounded, size: 14),
                label: Text('Hapus', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Tutup', style: GoogleFonts.inter(fontSize: 12)),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteTransaction(Map<String, dynamic> tx) {
    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Batalkan Transaksi?', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
        content: Text(
          'Membatalkan invoice "${tx['id_transaksi']}" akan memulihkan stok produk HP lokal Anda dan menghapusnya dari Google Sheets.',
          style: GoogleFonts.inter(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: GoogleFonts.inter()),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              
              await DummyDatabase.deleteTransaction(tx['id_transaksi']);
              setState(() {});

              messenger.showSnackBar(
                SnackBar(
                  content: Text('Transaksi "${tx['id_transaksi']}" dibatalkan. Stok barang dipulihkan.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: Text('Ya, Batalkan', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Saring transaksi berdasarkan filter hari dan query pencarian
    final filteredHistory = DummyDatabase.transactionHistory.where((tx) {
      final idLower = tx['id_transaksi'].toString().toLowerCase();
      final customerLower = tx['id_pelanggan'].toString().toLowerCase();
      
      final matchesSearch = idLower.contains(_searchQuery.toLowerCase()) || customerLower.contains(_searchQuery.toLowerCase());
      final matchesDate = _filterByDate(tx['tanggal'].toString());

      return matchesSearch && matchesDate;
    }).toList();

    // 2. Hitung total pendapatan/omset dari transaksi terfilter
    final int totalOmset = filteredHistory.fold(0, (sum, tx) => sum + (int.tryParse(tx['total_harga'].toString()) ?? 0));
    
    // 3. Kalkulasikan daftar menu terlaris secara dinamis
    final topSellingMenus = _calculateTopSellingMenus(filteredHistory);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;
    final cardBorder = isDark ? Colors.white.withAlpha(15) : Colors.grey.shade200;
    final textColor = isDark ? Colors.white : AppColors.textDark;
    final textMedColor = isDark ? Colors.white60 : AppColors.textMed;
    final primaryColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final chipBg = isDark ? AppColors.primary.withAlpha(40) : AppColors.chipBg;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Riwayat & Laporan'),
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [
              Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'Transaksi'),
              Tab(icon: Icon(Icons.bar_chart_rounded, size: 18), text: 'Statistik'),
            ],
          ),
        ),
        body: Column(
          children: [
            // ── Horizontal Days Filter (Berlaku global untuk kedua tab) ──
            Container(
              color: cardColor,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  children: ['Semua', 'Hari Ini', '7 Hari', '30 Hari'].map((day) {
                    final isActive = day == _activeDayFilter;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        label: Text(
                          day,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: isActive ? Colors.white : textColor,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        selected: isActive,
                        selectedColor: AppColors.primary,
                        checkmarkColor: Colors.white,
                        backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                        side: BorderSide(color: isActive ? Colors.transparent : cardBorder),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        onSelected: (_) {
                          setState(() {
                            _activeDayFilter = day;
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const Divider(height: 1),

            // Tab Views
            Expanded(
              child: TabBarView(
                children: [
                  // ==========================================
                  // TAB 1: RIWAYAT TRANSAKSI
                  // ==========================================
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: SizedBox(
                          height: 38,
                          child: TextField(
                            controller: _searchCtrl,
                            style: GoogleFonts.inter(fontSize: 12),
                            decoration: InputDecoration(
                              hintText: 'Cari invoice / ID pelanggan...',
                              prefixIcon: const Icon(Icons.search_rounded, size: 18),
                              contentPadding: EdgeInsets.zero,
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16),
                                      onPressed: () {
                                        setState(() {
                                          _searchCtrl.clear();
                                          _searchQuery = '';
                                        });
                                      },
                                    )
                                  : null,
                            ),
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val;
                              });
                            },
                          ),
                        ),
                      ),
                      Expanded(
                        child: filteredHistory.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.receipt_long_rounded, size: 48, color: Colors.grey.shade300),
                                    const SizedBox(height: 10),
                                    Text('Tidak ada riwayat transaksi', style: GoogleFonts.inter(color: textMedColor)),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                                itemCount: filteredHistory.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final tx = filteredHistory[index];
                                  final int total = int.tryParse(tx['total_harga'].toString()) ?? 0;
                                  final isQris = tx['bayar'].toString() == tx['total_harga'].toString() && tx['kembalian'].toString() == '0';
                                  
                                  var customerName = 'Guest';
                                  if (tx['id_pelanggan'] != 'Guest') {
                                    final member = DummyDatabase.memberList.firstWhere(
                                      (m) => m['id'] == tx['id_pelanggan'],
                                      orElse: () => {},
                                    );
                                    if (member.isNotEmpty) {
                                      customerName = member['nama'];
                                    } else {
                                      customerName = tx['id_pelanggan'].toString();
                                    }
                                  }

                                  return Container(
                                    decoration: BoxDecoration(
                                      color: cardColor,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: cardBorder),
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      title: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            tx['id_transaksi'],
                                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                                          ),
                                          Text(
                                            _formatRupiah(total),
                                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: primaryColor),
                                          ),
                                        ],
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Pelanggan: $customerName',
                                                style: GoogleFonts.inter(fontSize: 11, color: textColor),
                                              ),
                                              Text(
                                                tx['tanggal'].toString().split(' ')[0],
                                                style: GoogleFonts.inter(fontSize: 10, color: textMedColor),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: chipBg,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  isQris ? 'QRIS' : 'Cash',
                                                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: primaryColor),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      onTap: () => _showDetailDialog(tx),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),

                  // ==========================================
                  // TAB 2: STATISTIK PENJUALAN
                  // ==========================================
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card metrik
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: cardBorder),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Total Omset', style: GoogleFonts.inter(fontSize: 11, color: textMedColor)),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatRupiah(totalOmset),
                                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: primaryColor),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: cardBorder),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Transaksi', style: GoogleFonts.inter(fontSize: 11, color: textMedColor)),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${filteredHistory.length} Invoice',
                                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Judul Top Menu
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.orange, size: 20),
                            const SizedBox(width: 6),
                            Text(
                              'Menu Terlaris (Urutan)',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // List Menu Terlaris secara Descending
                        topSellingMenus.isEmpty
                            ? Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: cardBorder),
                                ),
                                child: Center(
                                  child: Text(
                                    'Belum ada data penjualan pada periode ini',
                                    style: GoogleFonts.inter(fontSize: 12, color: textMedColor),
                                  ),
                                ),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: cardBorder),
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: topSellingMenus.length,
                                  separatorBuilder: (_, _) => const Divider(height: 1, indent: 14, endIndent: 14),
                                  itemBuilder: (ctx, index) {
                                    final item = topSellingMenus[index];
                                    final rank = index + 1;
                                    
                                    // Beri warna khusus untuk top 3
                                    Color medalColor = Colors.grey.shade400;
                                    if (rank == 1) medalColor = const Color(0xFFFFD700); // Emas
                                    if (rank == 2) medalColor = const Color(0xFFC0C0C0); // Perak
                                    if (rank == 3) medalColor = const Color(0xFFCD7F32); // Perunggu

                                    return ListTile(
                                      dense: true,
                                      leading: CircleAvatar(
                                        radius: 12,
                                        backgroundColor: rank <= 3 ? medalColor.withAlpha(40) : (isDark ? Colors.white10 : Colors.grey.shade100),
                                        child: Text(
                                          '$rank',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: rank <= 3 ? medalColor : textMedColor,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        item['nama'],
                                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                                      ),
                                      subtitle: Text(
                                        item['kategori'] ?? 'Uncategorized',
                                        style: GoogleFonts.inter(fontSize: 11, color: textMedColor),
                                      ),
                                      trailing: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: chipBg,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${item['qty_terjual']} Terjual',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: primaryColor,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
