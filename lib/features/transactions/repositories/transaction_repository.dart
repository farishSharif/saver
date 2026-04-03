import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/transaction_model.dart';

class TransactionRepository {
  final SupabaseClient _supabase;

  TransactionRepository(this._supabase);

  // Users can see their own
  Stream<List<TransactionModel>> getUserTransactions(String userId) {
    return _supabase
        .from('transactions')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((maps) => maps.map((m) => TransactionModel.fromJson(m)).toList());
  }

  // Savers can see all pending
  Stream<List<TransactionModel>> getPendingTransactions() {
    return _supabase
        .from('transactions')
        .stream(primaryKey: ['id'])
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .map((maps) => maps.map((m) => TransactionModel.fromJson(m)).toList());
  }
  
  // Savers can see all transactions
  Stream<List<TransactionModel>> getAllTransactions() {
    return _supabase
        .from('transactions')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((maps) => maps.map((m) => TransactionModel.fromJson(m)).toList());
  }

  Future<void> createTransaction({
    required String userId,
    required double amount,
    required String type,
    String? note,
  }) async {
    await _supabase.from('transactions').insert({
      'user_id': userId,
      'amount': amount,
      'type': type,
      'status': 'pending',
      'note': note,
    });
  }

  Future<void> updateTransactionStatus(String id, String status) async {
    await _supabase.from('transactions').update({'status': status}).eq('id', id);
  }
}
