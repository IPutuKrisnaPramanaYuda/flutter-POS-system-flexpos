import '../services/storage_service.dart';
import '../services/api_service.dart';

class DummyDatabase {
  // Simpan siapa yang sedang login saat ini
  static Map<String, dynamic>? currentUser;

  // Data Kategori
  static List<String> categoryList = ['Coffee', 'Milk Series', 'Bakery'];

  // Data Kasir (default)
  static List<Map<String, dynamic>> cashierList = [
    {'id': 'K001', 'nama': 'ADMIN', 'role': 'ADMIN', 'pin': '12345'},
    {'id': 'K002', 'nama': 'Budi', 'role': 'KASIR', 'pin': '4321'},
  ];

  // Data Menu
  static List<Map<String, dynamic>> menuList = [
    {
      'id': 'M001',
      'nama': 'Espresso Single',
      'harga': 18000,
      'stok': 30,
      'kategori': 'Coffee',
    },
    {
      'id': 'M002',
      'nama': 'Caramel Macchiato',
      'harga': 28000,
      'stok': 20,
      'kategori': 'Coffee',
    },
    {
      'id': 'M003',
      'nama': 'Cafe Latte',
      'harga': 24000,
      'stok': 25,
      'kategori': 'Coffee',
    },
    {
      'id': 'M004',
      'nama': 'Avocado Coffee',
      'harga': 26000,
      'stok': 15,
      'kategori': 'Milk Series',
    },
    {
      'id': 'M005',
      'nama': 'Croissant Chocolate',
      'harga': 22000,
      'stok': 10,
      'kategori': 'Bakery',
    },
    {
      'id': 'M006',
      'nama': 'Cheese Danish',
      'harga': 20000,
      'stok': 12,
      'kategori': 'Bakery',
    },
  ];

  // Data Member
  static List<Map<String, dynamic>> memberList = [
    {'id': 'MB001', 'nama': 'Andi Wijaya', 'telepon': '081234567890'},
    {'id': 'MB002', 'nama': 'Siti Rahma', 'telepon': '089876543210'},
    {'id': 'MB003', 'nama': 'Joko Susilo', 'telepon': '085712345678'},
  ];

  // Riwayat Transaksi Lokal HP
  static List<Map<String, dynamic>> transactionHistory = [];
  static List<Map<String, dynamic>> transactionDetailsHistory = [];

  // ==========================================
  // METODE INTI: Inisialisasi Data dari Cache Lokal
  // ==========================================
  static Future<void> initLocalData() async {
    await StorageService.init();

    // 1. Muat Kasir/Users
    // Selalu gunakan default jika cache kosong ATAU jika akun K001 (Krisna) PIN-nya lama
    final cachedUsers = await StorageService.getCache('users');
    bool cacheValid = false;
    if (cachedUsers.isNotEmpty) {
      final adminUser = cachedUsers.where((u) => u['id'] == 'K001').firstOrNull;
      // Reset cache jika nama atau PIN admin tidak sesuai default
      final namaOk = adminUser?['nama']?.toString() == 'ADMIN';
      final pinOk = adminUser?['pin']?.toString() == '12345';
      if (adminUser != null && namaOk && pinOk) {
        cacheValid = true;
        cashierList = cachedUsers
            .map(
              (e) => <String, dynamic>{
                'id': e['id']?.toString() ?? '',
                'nama': e['nama']?.toString() ?? '',
                'role': e['role']?.toString() ?? '',
                'pin': e['pin']?.toString() ?? '',
              },
            )
            .toList();
      }
    }

    if (!cacheValid) {
      // Gunakan default + simpan ke cache
      cashierList = [
        <String, dynamic>{
          'id': 'K001',
          'nama': 'ADMIN',
          'role': 'ADMIN',
          'pin': '12345',
        },
        <String, dynamic>{
          'id': 'K002',
          'nama': 'Budi',
          'role': 'KASIR',
          'pin': '4321',
        },
      ];
      await StorageService.setCache('users', cashierList);
    }

    // Safety Net: Jika data kasir kosong
    if (cashierList.isEmpty) {
      cashierList = [
        <String, dynamic>{
          'id': 'K001',
          'nama': 'Krisna',
          'role': 'ADMIN',
          'pin': '12345',
        },
        <String, dynamic>{
          'id': 'K002',
          'nama': 'Budi',
          'role': 'KASIR',
          'pin': '4321',
        },
      ];
      await StorageService.setCache('users', cashierList);
    }

    // 2. Muat Kategori
    final cachedCat = await StorageService.getCache('kategori');
    if (cachedCat.isNotEmpty) {
      categoryList = cachedCat.map((e) => e.toString()).toList();
    } else {
      await StorageService.setCache('kategori', categoryList);
    }

    // 3. Muat Menu
    final cachedMenu = await StorageService.getCache('menu');
    if (cachedMenu.isNotEmpty) {
      menuList = cachedMenu
          .map(
            (e) => <String, dynamic>{
              'id': e['id']?.toString() ?? '',
              'nama': e['nama']?.toString() ?? '',
              'harga': int.tryParse(e['harga'].toString()) ?? 0,
              'stok': int.tryParse(e['stok'].toString()) ?? 0,
              'kategori': e['kategori']?.toString() ?? 'Uncategorized',
            },
          )
          .toList();
    } else {
      await StorageService.setCache('menu', menuList);
    }

    // 4. Muat Member
    final cachedMember = await StorageService.getCache('member');
    if (cachedMember.isNotEmpty) {
      memberList = cachedMember
          .map(
            (e) => <String, dynamic>{
              'id': e['id']?.toString() ?? '',
              'nama': e['nama']?.toString() ?? '',
              'telepon': e['telepon']?.toString() ?? '',
            },
          )
          .toList();
    } else {
      await StorageService.setCache('member', memberList);
    }

    // 5. Muat Riwayat Transaksi
    final rawHistory = await StorageService.getTransactionsHistory();
    transactionHistory = rawHistory
        .map(
          (e) => <String, dynamic>{
            'id_transaksi': e['id_transaksi']?.toString() ?? '',
            'id_user': e['id_user']?.toString() ?? '',
            'id_pelanggan': e['id_pelanggan']?.toString() ?? 'Guest',
            'total_harga': int.tryParse(e['total_harga'].toString()) ?? 0,
            'bayar': int.tryParse(e['bayar'].toString()) ?? 0,
            'kembalian': int.tryParse(e['kembalian'].toString()) ?? 0,
            'tanggal': e['tanggal']?.toString() ?? '',
          },
        )
        .toList();

    final rawDetails = await StorageService.getTransactionDetailsHistory();
    transactionDetailsHistory = rawDetails
        .map(
          (e) => <String, dynamic>{
            'id_transaksi': e['id_transaksi']?.toString() ?? '',
            'id_menu': e['id_menu']?.toString() ?? '',
            'qty': int.tryParse(e['qty'].toString()) ?? 0,
            'subtotal': int.tryParse(e['subtotal'].toString()) ?? 0,
          },
        )
        .toList();
  }

  // ==========================================
  // HELPER METHODS (KATEGORI)
  // ==========================================
  static Future<void> addCategory(String name) async {
    final formattedName = name.trim();
    if (formattedName.isNotEmpty && !categoryList.contains(formattedName)) {
      categoryList.add(formattedName);
      await StorageService.setCache('kategori', categoryList);
      // Kirim mutasi secara asinkron ke server
      ApiService.postAddCategory(formattedName);
    }
  }

  static Future<void> deleteCategory(String name) async {
    categoryList.remove(name);
    for (var menu in menuList) {
      if (menu['kategori'] == name) {
        menu['kategori'] = 'Uncategorized';
      }
    }
    if (!categoryList.contains('Uncategorized')) {
      categoryList.add('Uncategorized');
    }
    await StorageService.setCache('kategori', categoryList);
    await StorageService.setCache('menu', menuList);
    // Kirim mutasi secara asinkron ke server
    ApiService.postDeleteCategory(name);
  }

  // ==========================================
  // HELPER METHODS (KASIR)
  // ==========================================
  static Future<void> addCashier(String nama, String pin, String role) async {
    final newId = 'K00${cashierList.length + 1}';
    final cashier = <String, dynamic>{
      'id': newId,
      'nama': nama,
      'role': role,
      'pin': pin,
    };
    cashierList.add(cashier);
    await StorageService.setCache('users', cashierList);
    // Kirim mutasi secara asinkron ke server
    ApiService.postAddCashier(cashier);
  }

  static Future<void> deleteCashier(String id) async {
    cashierList.removeWhere((cashier) => cashier['id'] == id);
    await StorageService.setCache('users', cashierList);
    // Kirim mutasi secara asinkron ke server
    ApiService.postDeleteCashier(id);
  }

  // ==========================================
  // HELPER METHODS (MENU)
  // ==========================================
  static Future<void> addMenu(
    String nama,
    int harga,
    int stok,
    String kategori,
  ) async {
    final newId = 'M00${menuList.length + 1}';
    final newMenu = <String, dynamic>{
      'id': newId,
      'nama': nama,
      'harga': harga,
      'stok': stok,
      'kategori': kategori,
    };
    menuList.add(newMenu);
    await StorageService.setCache('menu', menuList);
    // Kirim mutasi secara asinkron ke server
    ApiService.postAddMenu(newMenu);
  }

  static Future<void> updateMenu(
    String id,
    String nama,
    int harga,
    int stok,
    String kategori,
  ) async {
    final index = menuList.indexWhere((menu) => menu['id'] == id);
    if (index != -1) {
      final updatedMenu = <String, dynamic>{
        'id': id,
        'nama': nama,
        'harga': harga,
        'stok': stok,
        'kategori': kategori,
      };
      menuList[index] = updatedMenu;
      await StorageService.setCache('menu', menuList);
      // Kirim mutasi secara asinkron ke server
      ApiService.postUpdateMenu(updatedMenu);
    }
  }

  static Future<void> deleteMenu(String id) async {
    menuList.removeWhere((menu) => menu['id'] == id);
    await StorageService.setCache('menu', menuList);
    // Kirim mutasi secara asinkron ke server
    ApiService.postDeleteMenu(id);
  }

  // ==========================================
  // HELPER METHODS (MEMBER)
  // ==========================================
  static Future<void> addMember(String nama, String telepon) async {
    final newId = 'MB00${memberList.length + 1}';
    final member = <String, dynamic>{
      'id': newId,
      'nama': nama,
      'telepon': telepon,
    };
    memberList.add(member);
    await StorageService.setCache('member', memberList);
    // Kirim mutasi secara asinkron ke server
    ApiService.postAddMember(member);
  }

  // ==========================================
  // TRANSAKSI & STOK UPDATE LOKAL
  // ==========================================
  static Future<void> updateProductStock(
    String id,
    int quantityPurchased,
  ) async {
    final index = menuList.indexWhere((menu) => menu['id'] == id);
    if (index != -1) {
      final currentStock = menuList[index]['stok'] as int;
      menuList[index]['stok'] = (currentStock - quantityPurchased).clamp(
        0,
        99999,
      );
      await StorageService.setCache('menu', menuList);
    }
  }

  // ==========================================
  // HAPUS / BATALKAN TRANSAKSI LOKAL & BALIKKAN STOK
  // ==========================================
  static Future<void> deleteTransaction(String idTransaksi) async {
    final List<Map<String, dynamic>> itemsToRestore = transactionDetailsHistory
        .where((det) => det['id_transaksi'] == idTransaksi)
        .toList();

    for (final item in itemsToRestore) {
      final String menuId = item['id_menu'];
      final int qty = int.tryParse(item['qty'].toString()) ?? 0;

      final index = menuList.indexWhere((menu) => menu['id'] == menuId);
      if (index != -1) {
        final currentStock = menuList[index]['stok'] as int;
        menuList[index]['stok'] = currentStock + qty;
      }
    }
    await StorageService.setCache('menu', menuList);

    await StorageService.deleteTransactionFromLocalHistory(idTransaksi);

    transactionHistory.removeWhere((tx) => tx['id_transaksi'] == idTransaksi);
    transactionDetailsHistory.removeWhere(
      (det) => det['id_transaksi'] == idTransaksi,
    );

    ApiService.postDeleteTransaction(idTransaksi);
  }
}
