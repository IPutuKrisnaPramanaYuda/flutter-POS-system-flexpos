import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'storage_service.dart';

class ApiService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // -------------------------------------------------------------------------
  // SINKRONISASI DATA MASTER & RIWAYAT (GET)
  // -------------------------------------------------------------------------
  static Future<Map<String, dynamic>> syncAllData() async {
    try {
      // 1. Fetch Users/Cashier
      final usersSnapshot = await _firestore.collection('users').get().timeout(const Duration(seconds: 8));
      final usersList = usersSnapshot.docs.map((doc) => doc.data()).toList();
      await StorageService.setCache('users', usersList);

      // 2. Fetch Kategori
      final kategoriSnapshot = await _firestore.collection('kategori').get().timeout(const Duration(seconds: 8));
      final categories = kategoriSnapshot.docs.map((doc) => doc.data()['nama'].toString()).toList();
      await StorageService.setCache('kategori', categories);

      // 3. Fetch Menu
      final menuSnapshot = await _firestore.collection('menu').get().timeout(const Duration(seconds: 8));
      final menuList = menuSnapshot.docs.map((doc) => doc.data()).toList();
      await StorageService.setCache('menu', menuList);

      // 4. Fetch Member
      final memberSnapshot = await _firestore.collection('member').get().timeout(const Duration(seconds: 8));
      final memberList = memberSnapshot.docs.map((doc) => doc.data()).toList();
      await StorageService.setCache('member', memberList);

      // 5. Fetch Riwayat Transaksi & Detail
      final txSnapshot = await _firestore.collection('transactions').get().timeout(const Duration(seconds: 8));
      final txList = txSnapshot.docs.map((doc) => doc.data()).toList();
      await StorageService.setCache('transactions_history', txList);

      final txDetSnapshot = await _firestore.collection('transaction_details').get().timeout(const Duration(seconds: 8));
      final txDetList = txDetSnapshot.docs.map((doc) => doc.data()).toList();
      await StorageService.setCache('transaction_details_history', txDetList);

      return {
        "status": "success",
        "message": "Semua data master & riwayat berhasil disinkronkan dari Firestore!"
      };
    } catch (e) {
      return {
        "status": "error",
        "message": "Koneksi offline atau terputus: ${e.toString()}"
      };
    }
  }

  // -------------------------------------------------------------------------
  // SINKRONISASI TRANSAKSI (POST CHKOUT)
  // -------------------------------------------------------------------------
  static Future<Map<String, dynamic>> checkoutTransaction(Map<String, dynamic> payload) async {
    final header = payload['transaksi'] as Map<String, dynamic>;
    final items = payload['items'] as List;

    // Simpan ke riwayat transaksi lokal HP terlebih dahulu agar langsung muncul di Riwayat
    await StorageService.saveTransactionHistory(header);
    await StorageService.saveTransactionDetailsHistory(items);

    try {
      // 1. Simpan header transaksi ke Firestore
      await _firestore
          .collection('transactions')
          .doc(header['id_transaksi'])
          .set(header)
          .timeout(const Duration(seconds: 8));

      // 2. Simpan setiap item detail ke Firestore menggunakan Batch Write
      final batch = _firestore.batch();
      for (final item in items) {
        final itemMap = item as Map<String, dynamic>;
        final docRef = _firestore
            .collection('transaction_details')
            .doc('${itemMap['id_transaksi']}_${itemMap['id_menu']}');
        batch.set(docRef, itemMap);
      }
      await batch.commit().timeout(const Duration(seconds: 8));

      return {
        "status": "success",
        "message": "Transaksi berhasil terkirim ke Firestore!"
      };
    } catch (_) {
      // Jika offline, amankan di pending HP
      await StorageService.savePendingTransaction(payload);
      return {
        "status": "offline",
        "message": "Koneksi internet offline/tidak stabil. Transaksi dicadangkan di lokal HP."
      };
    }
  }

  // -------------------------------------------------------------------------
  // SINKRONISASI TRANSAKSI PENDING MASSAL
  // -------------------------------------------------------------------------
  static Future<Map<String, dynamic>> syncPendingTransactions() async {
    final pendingList = await StorageService.getPendingTransactions();
    if (pendingList.isEmpty) {
      return {"status": "success", "count": 0, "message": "Tidak ada transaksi tertunda."};
    }

    int successCount = 0;
    List<String> toRemove = [];

    for (final tx in pendingList) {
      String? idTransaksi;
      try {
        if (tx['transaksi'] != null) {
          idTransaksi = tx['transaksi']['id_transaksi']?.toString();
        }
      } catch (_) {}

      // Jika format transaksi rusak/corrupt di local storage
      if (idTransaksi == null) {
        try {
          final rawId = tx['id_transaksi']?.toString();
          if (rawId != null) {
            toRemove.add(rawId);
          }
        } catch (_) {}
        continue;
      }

      try {
        final header = tx['transaksi'] as Map<String, dynamic>;
        final items = tx['items'] as List;

        // Kirim ke Firestore
        await _firestore
            .collection('transactions')
            .doc(idTransaksi)
            .set(header)
            .timeout(const Duration(seconds: 8));

        final batch = _firestore.batch();
        for (final item in items) {
          final itemMap = item as Map<String, dynamic>;
          final docRef = _firestore
              .collection('transaction_details')
              .doc('${itemMap['id_transaksi']}_${itemMap['id_menu']}');
          batch.set(docRef, itemMap);
        }
        await batch.commit().timeout(const Duration(seconds: 8));

        toRemove.add(idTransaksi);
        successCount++;
      } catch (_) {
        break; // Hentikan loop jika koneksi terputus
      }
    }

    for (final id in toRemove) {
      await StorageService.removePendingTransaction(id);
    }

    // Bersihkan cache jika seluruh item yang nyangkut memiliki format rusak total
    if (toRemove.isEmpty && pendingList.isNotEmpty) {
      await StorageService.setCache('pending_transactions', []);
    }

    return {
      "status": "success",
      "count": successCount,
      "message": "$successCount transaksi tertunda berhasil disinkronkan ke Firestore!"
    };
  }

  // -------------------------------------------------------------------------
  // MUTASI DATA MASTER KE SPREADSHEET (POST CRUD)
  // -------------------------------------------------------------------------
  static Future<void> postAddCashier(Map<String, dynamic> cashier) async {
    await _firestore.collection('users').doc(cashier['id']).set({
      "id": cashier['id'],
      "nama": cashier['nama'],
      "role": cashier['role'],
      "pin": cashier['pin'],
    });
  }

  static Future<void> postDeleteCashier(String id) async {
    await _firestore.collection('users').doc(id).delete();
  }

  static Future<void> postAddMenu(Map<String, dynamic> menu) async {
    await _firestore.collection('menu').doc(menu['id']).set({
      "id": menu['id'],
      "nama": menu['nama'],
      "harga": menu['harga'],
      "stok": menu['stok'],
      "kategori": menu['kategori'],
    });
  }

  static Future<void> postUpdateMenu(Map<String, dynamic> menu) async {
    await _firestore.collection('menu').doc(menu['id']).update({
      "nama": menu['nama'],
      "harga": menu['harga'],
      "stok": menu['stok'],
      "kategori": menu['kategori'],
    });
  }

  static Future<void> postDeleteMenu(String id) async {
    await _firestore.collection('menu').doc(id).delete();
  }

  static Future<void> postAddMember(Map<String, dynamic> member) async {
    await _firestore.collection('member').doc(member['id']).set({
      "id": member['id'],
      "nama": member['nama'],
      "telepon": member['telepon'],
    });
  }

  static Future<void> postAddCategory(String nama) async {
    await _firestore.collection('kategori').doc(nama).set({
      "nama": nama,
    });
  }

  static Future<void> postDeleteCategory(String nama) async {
    await _firestore.collection('kategori').doc(nama).delete();
  }

  static Future<Map<String, dynamic>> postDeleteTransaction(String idTransaksi) async {
    try {
      await _firestore.collection('transactions').doc(idTransaksi).delete();
      
      // Hapus detail transaksinya juga
      final detailsQuery = await _firestore
          .collection('transaction_details')
          .where('id_transaksi', isEqualTo: idTransaksi)
          .get();
          
      final batch = _firestore.batch();
      for (final doc in detailsQuery.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      return {"status": "success", "message": "Transaksi berhasil dihapus dari Firestore."};
    } catch (e) {
      return {"status": "error", "message": "Gagal menghapus transaksi: ${e.toString()}"};
    }
  }

  static Future<void> checkAndSeedFirestore() async {
    try {
      final usersSnapshot = await _firestore
          .collection('users')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 8));

      if (usersSnapshot.docs.isEmpty) {
        debugPrint('[Firestore Seeder] Database kosong. Mulai seeding data default...');

        // 1. Seed Cashier/Users
        final defaultCashiers = [
          {'id': 'K001', 'nama': 'ADMIN', 'role': 'ADMIN', 'pin': '12345'},
          {'id': 'K002', 'nama': 'Budi', 'role': 'KASIR', 'pin': '4321'},
        ];
        for (final cashier in defaultCashiers) {
          await _firestore.collection('users').doc(cashier['id']).set(cashier);
        }

        // 2. Seed Kategori
        final defaultCategories = ['Coffee', 'Milk Series', 'Bakery'];
        for (final cat in defaultCategories) {
          await _firestore.collection('kategori').doc(cat).set({'nama': cat});
        }

        // 3. Seed Menu
        final defaultMenus = [
          {'id': 'M001', 'nama': 'Espresso Single', 'harga': 18000, 'stok': 30, 'kategori': 'Coffee'},
          {'id': 'M002', 'nama': 'Caramel Macchiato', 'harga': 28000, 'stok': 20, 'kategori': 'Coffee'},
          {'id': 'M003', 'nama': 'Cafe Latte', 'harga': 24000, 'stok': 25, 'kategori': 'Coffee'},
          {'id': 'M004', 'nama': 'Avocado Coffee', 'harga': 26000, 'stok': 15, 'kategori': 'Milk Series'},
          {'id': 'M005', 'nama': 'Croissant Chocolate', 'harga': 22000, 'stok': 10, 'kategori': 'Bakery'},
          {'id': 'M006', 'nama': 'Cheese Danish', 'harga': 20000, 'stok': 12, 'kategori': 'Bakery'},
        ];
        for (final menu in defaultMenus) {
          final String menuId = menu['id'] as String;
          await _firestore.collection('menu').doc(menuId).set(menu);
        }

        // 4. Seed Member
        final defaultMembers = [
          {'id': 'MB001', 'nama': 'Andi Wijaya', 'telepon': '081234567890'},
          {'id': 'MB002', 'nama': 'Siti Rahma', 'telepon': '089876543210'},
          {'id': 'MB003', 'nama': 'Joko Susilo', 'telepon': '085712345678'},
        ];
        for (final member in defaultMembers) {
          await _firestore.collection('member').doc(member['id']).set(member);
        }

        debugPrint('[Firestore Seeder] Seeding data default selesai!');
      } else {
        debugPrint('[Firestore Seeder] Database sudah berisi data. Seeding dilewati.');
      }
    } catch (e) {
      debugPrint('[Firestore Seeder] Gagal melakukan seeder: $e');
    }
  }
}
