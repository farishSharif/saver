import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../repositories/transaction_repository.dart';
import '../models/transaction_model.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(supabaseClientProvider));
});

final userTransactionsProvider = StreamProvider<List<TransactionModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(transactionRepositoryProvider).getUserTransactions(user.id);
});

final pendingTransactionsProvider = StreamProvider<List<TransactionModel>>((ref) {
  return ref.watch(transactionRepositoryProvider).getPendingTransactions();
});

final allTransactionsProvider = StreamProvider<List<TransactionModel>>((ref) {
  return ref.watch(transactionRepositoryProvider).getAllTransactions();
});

final balanceProvider = Provider<double>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return 0.0;
  
  // Calculate balance from user's transactions
  final txList = ref.watch(userTransactionsProvider).value ?? [];
  double balance = 0.0;
  for (final tx in txList) {
    if (tx.status == 'approved') {
      if (tx.type == 'deposit') {
        balance += tx.amount;
      } else if (tx.type == 'withdraw') {
        balance -= tx.amount;
      }
    }
  }
  return balance;
});
