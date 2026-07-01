import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static SharedPreferences? _prefs;

  // Inisialisasi awal shared_preferences
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // -------------------------------------------------------------------------
  // CACHE DATA MASTER (USERS, KATEGORI, MENU, MEMBER)
  // -------------------------------------------------------------------------
  static Future<void> setCache(String key, List<dynamic> data) async {
    if (_prefs == null) await init();
    final jsonStr = jsonEncode(data);
    await _prefs!.setString(key, jsonStr);
  }

  static Future<List<Map<String, dynamic>>> getCache(String key) async {
    if (_prefs == null) await init();
    final jsonStr = _prefs!.getString(key);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // -------------------------------------------------------------------------
  // CACHE ANTREAN TRANSAKSI PENDING (OFFLINE QUEUE)
  // -------------------------------------------------------------------------
  static Future<List<Map<String, dynamic>>> getPendingTransactions() async {
    if (_prefs == null) await init();
    final jsonStr = _prefs!.getString('pending_transactions');
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> savePendingTransaction(Map<String, dynamic> txData) async {
    if (_prefs == null) await init();
    final currentList = await getPendingTransactions();
    currentList.add(txData);
    final jsonStr = jsonEncode(currentList);
    await _prefs!.setString('pending_transactions', jsonStr);
  }

  static Future<void> removePendingTransaction(String idTransaksi) async {
    if (_prefs == null) await init();
    final currentList = await getPendingTransactions();
    currentList.removeWhere((tx) => tx['transaksi']['id_transaksi'] == idTransaksi);
    final jsonStr = jsonEncode(currentList);
    await _prefs!.setString('pending_transactions', jsonStr);
  }

  // -------------------------------------------------------------------------
  // CACHE RIWAYAT TRANSAKSI (TRANSACTION HISTORY)
  // -------------------------------------------------------------------------
  static Future<List<Map<String, dynamic>>> getTransactionsHistory() async {
    return getCache('transactions_history');
  }

  static Future<void> saveTransactionHistory(Map<String, dynamic> txData) async {
    if (_prefs == null) await init();
    final history = await getTransactionsHistory();
    // Tambahkan data transaksi di awal list agar urutan terbaru muncul paling atas
    history.insert(0, txData);
    await setCache('transactions_history', history);
  }

  static Future<List<Map<String, dynamic>>> getTransactionDetailsHistory() async {
    return getCache('transaction_details_history');
  }

  static Future<void> saveTransactionDetailsHistory(List<dynamic> items) async {
    if (_prefs == null) await init();
    final details = await getTransactionDetailsHistory();
    details.addAll(items.map((e) => Map<String, dynamic>.from(e)).toList());
    await setCache('transaction_details_history', details);
  }

  static Future<void> deleteTransactionFromLocalHistory(String idTransaksi) async {
    if (_prefs == null) await init();
    
    // Hapus header transaksi
    final history = await getTransactionsHistory();
    history.removeWhere((tx) => tx['id_transaksi'] == idTransaksi);
    await setCache('transactions_history', history);

    // Hapus detail transaksi
    final details = await getTransactionDetailsHistory();
    details.removeWhere((det) => det['id_transaksi'] == idTransaksi);
    await setCache('transaction_details_history', details);
  }
}
