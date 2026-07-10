import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/dummy_data.dart';
import '../main.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isSyncing = false;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _checkPendingTransactions();
  }

  Future<void> _checkPendingTransactions() async {
    final list = await StorageService.getPendingTransactions();
    if (mounted) {
      setState(() {
        _pendingCount = list.length;
      });
    }
  }

  Future<void> _handleSync() async {
    setState(() => _isSyncing = true);
    final messenger = ScaffoldMessenger.of(context);

    final syncTxRes = await ApiService.syncPendingTransactions();
    final syncDataRes = await ApiService.syncAllData();

    await DummyDatabase.initLocalData();
    await _checkPendingTransactions();

    if (mounted) setState(() => _isSyncing = false);

    if (syncDataRes['status'] == 'success') {
      var msg = syncDataRes['message'];
      if (syncTxRes['count'] != null && syncTxRes['count'] > 0) {
        msg += " Serta ${syncTxRes['count']} transaksi offline terkirim.";
      }
      messenger.showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.accent));
    } else {
      messenger.showSnackBar(SnackBar(
        content: Text(syncDataRes['message'] ?? 'Gagal sinkronisasi data.'),
        backgroundColor: Colors.orange,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = DummyDatabase.currentUser;
    final isAdmin = user?['role'] == 'ADMIN';

    final bgColor = isDark ? AppColors.darkBackground : AppColors.background;
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;
    final cardBorder = isDark ? Colors.white.withAlpha(15) : Colors.grey.shade200;
    final barBorder = isDark ? Colors.white.withAlpha(15) : Colors.grey.shade200;
    final textDark = isDark ? Colors.white : AppColors.textDark;
    final textMed = isDark ? Colors.white60 : AppColors.textMed;
    
    // Gunakan warna biru primer untuk admin, biru gelap kustom untuk kasir
    final headerColor = isAdmin ? AppColors.primary : AppColors.primaryDark;
    final chipBg = isDark
        ? (isAdmin ? AppColors.primary.withAlpha(50) : AppColors.primaryDark.withAlpha(60))
        : AppColors.chipBg;

    // Susun menu utama secara dinamis berdasarkan role user
    final List<Map<String, dynamic>> menuItems = [
      {
        'title': isAdmin ? 'Buka Kasir' : 'Transaksi Baru',
        'subtitle': isAdmin ? 'Mulai transaksi' : 'Proses penjualan',
        'icon': Icons.point_of_sale_rounded,
        'route': '/transaction',
      },
      if (isAdmin) ...[
        {
          'title': 'Kelola Kasir',
          'subtitle': 'Atur data akun',
          'icon': Icons.manage_accounts_rounded,
          'route': '/manage_cashier',
        },
        {
          'title': 'Kelola Menu',
          'subtitle': 'Produk & stok',
          'icon': Icons.restaurant_menu_rounded,
          'route': '/manage_menu',
        },
      ],
      {
        'title': isAdmin ? 'Kelola Member' : 'Daftarkan Member',
        'subtitle': isAdmin ? 'Data pelanggan' : 'Tambah pelanggan',
        'icon': Icons.people_alt_rounded,
        'route': '/manage_member',
      },
      {
        'title': 'Riwayat Transaksi',
        'subtitle': 'Laporan penjualan',
        'icon': Icons.receipt_long_rounded,
        'route': '/history',
      },
    ];

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              color: headerColor,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAdmin ? 'Selamat datang,' : 'Selamat bertugas,',
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?['nama'] ?? (isAdmin ? 'Admin' : 'Kasir'),
                          style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                        if (user?['id'] != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            'ID: ${user!['id']}',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.white70),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Badge Role
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(40),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isAdmin ? Icons.verified_rounded : Icons.badge_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isAdmin ? 'ADMIN' : 'KASIR',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Tombol Settings
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/settings'),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.settings_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),

            // ── Subheader ──
            Container(
              color: headerColor,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.business_center_outlined, color: Colors.white70, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Flex POS — Flexible Point of Sale',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),

            // ── Sync & Cloud Status Bar ──
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                border: Border(bottom: BorderSide(color: barBorder)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    _pendingCount > 0 ? Icons.cloud_queue_rounded : Icons.cloud_done_rounded,
                    color: _pendingCount > 0 ? Colors.orange : AppColors.accent,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _pendingCount > 0
                        ? '$_pendingCount Transaksi tertunda di HP'
                        : 'Semua transaksi tersinkronisasi',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _pendingCount > 0 ? Colors.orange.shade800 : textMed,
                    ),
                  ),
                  const Spacer(),
                  _isSyncing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        )
                      : TextButton.icon(
                          onPressed: _handleSync,
                          icon: const Icon(Icons.sync_rounded, size: 14),
                          label: Text(
                            'Sync',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Menu Utama',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: textMed),
              ),
            ),
            const SizedBox(height: 10),

            // ── Grid Menu ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: menuItems.length,
                  itemBuilder: (context, index) {
                    final item = menuItems[index];
                    return _buildMenuCard(
                      context,
                      item,
                      cardColor: cardColor,
                      cardBorder: cardBorder,
                      chipBg: chipBg,
                      textDark: textDark,
                      textMed: textMed,
                    );
                  },
                ),
              ),
            ),

            // ── Tombol Logout ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
              child: OutlinedButton.icon(
                onPressed: () => _showLogoutDialog(context),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: Text('Keluar', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: BorderSide(color: headerColor),
                  foregroundColor: headerColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context,
    Map<String, dynamic> item, {
    required Color cardColor,
    required Color cardBorder,
    required Color chipBg,
    required Color textDark,
    required Color textMed,
  }) {
    return GestureDetector(
      onTap: () async {
        await Navigator.pushNamed(context, item['route']);
        _checkPendingTransactions();
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  item['icon'] as IconData,
                  color: DummyDatabase.currentUser?['role'] == 'ADMIN'
                      ? AppColors.primary
                      : AppColors.primaryDark,
                  size: 22,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title'],
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: textDark),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item['subtitle'],
                    style: GoogleFonts.inter(fontSize: 11, color: textMed),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Konfirmasi Logout', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
        content: Text('Yakin ingin keluar dari akun ini?', style: GoogleFonts.inter(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: GoogleFonts.inter()),
          ),
          ElevatedButton(
            onPressed: () {
              DummyDatabase.currentUser = null;
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
            child: Text('Logout', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
