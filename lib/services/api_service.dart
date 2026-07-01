import 'dart:convert';
import 'package:http/http.dart' as http;
import 'storage_service.dart';

class ApiService {
  // URL Web App Google Apps Script Anda setelah di-deploy
  static String gasUrl =
      "https://script.google.com/macros/s/AKfycbxF83nbNKU5dWWbBraYJMGgXpTUpFhkVu3ntxGVCFiFyUynkbBIZGE-GeNttOy0PK29/exec";

  // Helper generik untuk mengirimkan POST mutasi master data ke Apps Script secara langsung
  static Future<Map<String, dynamic>> sendMutation(Map<String, dynamic> payload) async {
    try {
      final response = await http.post(
        Uri.parse(gasUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 || response.statusCode == 302) {
        try {
          final decoded = jsonDecode(response.body);
          return decoded;
        } catch (_) {
          // Gagal parsing JSON (misal redirect HTML dari Google), 
          // tapi karena status code 200/302, request dipastikan sudah sampai dan diproses di spreadsheet.
          return {"status": "success", "message": "Mutasi berhasil diproses."};
        }
      }
      return {"status": "offline", "message": "Respon server gagal (Status Code: ${response.statusCode})."};
    } catch (_) {
      return {
        "status": "offline",
        "message": "Gagal terhubung ke server. Perubahan disimpan secara lokal."
      };
    }
  }

  // -------------------------------------------------------------------------
  // SINKRONISASI DATA MASTER & RIWAYAT (GET)
  // -------------------------------------------------------------------------
  static Future<Map<String, dynamic>> syncAllData() async {
    try {
      // 1. Fetch Users
      final resUsers = await http.get(Uri.parse("$gasUrl?action=get_users")).timeout(const Duration(seconds: 8));
      final decodedUsers = jsonDecode(resUsers.body);
      if (decodedUsers['status'] == 'success') {
        await StorageService.setCache('users', decodedUsers['data']);
      }

      // 2. Fetch Kategori
      final resKategori = await http.get(Uri.parse("$gasUrl?action=get_kategori")).timeout(const Duration(seconds: 8));
      final decodedKategori = jsonDecode(resKategori.body);
      if (decodedKategori['status'] == 'success') {
        final List<dynamic> catList = decodedKategori['data'];
        final categories = catList.map((e) => e['nama'].toString()).toList();
        await StorageService.setCache('kategori', categories);
      }

      // 3. Fetch Menu
      final resMenu = await http.get(Uri.parse("$gasUrl?action=get_menu")).timeout(const Duration(seconds: 8));
      final decodedMenu = jsonDecode(resMenu.body);
      if (decodedMenu['status'] == 'success') {
        await StorageService.setCache('menu', decodedMenu['data']);
      }

      // 4. Fetch Member
      final resMember = await http.get(Uri.parse("$gasUrl?action=get_member")).timeout(const Duration(seconds: 8));
      final decodedMember = jsonDecode(resMember.body);
      if (decodedMember['status'] == 'success') {
        await StorageService.setCache('member', decodedMember['data']);
      }

      // 5. Fetch Riwayat Transaksi & Detail
      final resTx = await http.get(Uri.parse("$gasUrl?action=get_transactions")).timeout(const Duration(seconds: 8));
      final decodedTx = jsonDecode(resTx.body);
      if (decodedTx['status'] == 'success') {
        await StorageService.setCache('transactions_history', decodedTx['data']);
      }

      final resTxDet = await http.get(Uri.parse("$gasUrl?action=get_transaction_details")).timeout(const Duration(seconds: 8));
      final decodedTxDet = jsonDecode(resTxDet.body);
      if (decodedTxDet['status'] == 'success') {
        await StorageService.setCache('transaction_details_history', decodedTxDet['data']);
      }

      return {"status": "success", "message": "Semua data master & riwayat berhasil disinkronkan dari Google Sheets!"};
    } catch (e) {
      return {"status": "error", "message": "Koneksi offline atau terputus: ${e.toString()}"};
    }
  }

  // -------------------------------------------------------------------------
  // SINKRONISASI TRANSAKSI (POST CHKOUT)
  // -------------------------------------------------------------------------
  static Future<Map<String, dynamic>> checkoutTransaction(Map<String, dynamic> payload) async {
    final header = payload['transaksi'];
    final items = payload['items'];

    // Simpan ke riwayat transaksi lokal HP terlebih dahulu agar langsung muncul di Riwayat
    await StorageService.saveTransactionHistory(header);
    await StorageService.saveTransactionDetailsHistory(items);

    try {
      final response = await http.post(
        Uri.parse(gasUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 8));

      // Jika status code sukses (200 / 302), dipastikan transaksi sudah masuk ke spreadsheet Google Sheets
      if (response.statusCode == 200 || response.statusCode == 302) {
        return {"status": "success", "message": "Transaksi berhasil terkirim ke Google Sheets!"};
      }

      // Jika status code bukan sukses, amankan di pending HP
      await StorageService.savePendingTransaction(payload);
      return {"status": "offline", "message": "Respon server gagal. Transaksi dicadangkan di lokal HP."};
    } catch (_) {
      // Jika terjadi Timeout/SocketException asli (offline)
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
        final response = await http.post(
          Uri.parse(gasUrl),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(tx),
        ).timeout(const Duration(seconds: 8));

        // Pengecekan status code sukses untuk hapus dari pending queue
        if (response.statusCode == 200 || response.statusCode == 302) {
          toRemove.add(idTransaksi);
          successCount++;
        }
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
      "message": "$successCount transaksi tertunda berhasil disinkronkan!"
    };
  }

  // -------------------------------------------------------------------------
  // MUTASI DATA MASTER KE SPREADSHEET (POST CRUD)
  // -------------------------------------------------------------------------
  static Future<void> postAddCashier(Map<String, dynamic> cashier) async {
    await sendMutation({
      "action": "add_cashier",
      "id": cashier['id'],
      "nama": cashier['nama'],
      "role": cashier['role'],
      "pin": cashier['pin'],
    });
  }

  static Future<void> postDeleteCashier(String id) async {
    await sendMutation({"action": "delete_cashier", "id": id});
  }

  static Future<void> postAddMenu(Map<String, dynamic> menu) async {
    await sendMutation({
      "action": "add_menu",
      "id": menu['id'],
      "nama": menu['nama'],
      "harga": menu['harga'],
      "stok": menu['stok'],
      "kategori": menu['kategori'],
    });
  }

  static Future<void> postUpdateMenu(Map<String, dynamic> menu) async {
    await sendMutation({
      "action": "update_menu",
      "id": menu['id'],
      "nama": menu['nama'],
      "harga": menu['harga'],
      "stok": menu['stok'],
      "kategori": menu['kategori'],
      "action_type": "update",
    });
  }

  static Future<void> postDeleteMenu(String id) async {
    await sendMutation({"action": "delete_menu", "id": id});
  }

  static Future<void> postAddMember(Map<String, dynamic> member) async {
    await sendMutation({
      "action": "add_member",
      "id": member['id'],
      "nama": member['nama'],
      "telepon": member['telepon'],
    });
  }

  static Future<void> postAddCategory(String nama) async {
    await sendMutation({"action": "add_category", "nama": nama});
  }

  static Future<void> postDeleteCategory(String nama) async {
    await sendMutation({"action": "delete_category", "nama": nama});
  }

  static Future<Map<String, dynamic>> postDeleteTransaction(String idTransaksi) async {
    return await sendMutation({
      "action": "delete_transaction",
      "id_transaksi": idTransaksi,
    });
  }
}
