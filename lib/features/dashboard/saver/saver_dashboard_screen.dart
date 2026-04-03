import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../transactions/providers/transaction_provider.dart';
import '../../transactions/models/transaction_model.dart';
import '../user/calendar_tab.dart'; // import the reusable calendar tab

class SaverDashboardScreen extends StatefulWidget {
  const SaverDashboardScreen({super.key});

  @override
  State<SaverDashboardScreen> createState() => _SaverDashboardScreenState();
}

class _SaverDashboardScreenState extends State<SaverDashboardScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const _SaverHomeTab(),
    const CalendarTab(isAdmin: true),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.admin_panel_settings_outlined),
            selectedIcon: Icon(Icons.admin_panel_settings),
            label: 'Admin',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Summary',
          ),
        ],
      ),
    );
  }
}

class _SaverHomeTab extends ConsumerWidget {
  const _SaverHomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingTxAsync = ref.watch(pendingTransactionsProvider);
    final allTxAsync = ref.watch(allTransactionsProvider);
    final userAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saver Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (profile) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24.0),
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome Admin, ${profile?.fullName ?? "Saver"}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (profile?.inviteCode != null) ...[
                    const SizedBox(height: 8),
                    SelectableText(
                      'Your Invite Code: ${profile!.inviteCode}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Pending Requests', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.orange)),
            ),
            Expanded(
              flex: 2,
              child: pendingTxAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
                data: (transactions) {
                  if (transactions.isEmpty) {
                    return const Center(child: Text('No pending requests.'));
                  }
                  return ListView.builder(
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      return _PendingTxItem(tx: transactions[index]);
                    },
                  );
                },
              ),
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('All Transactions History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            Expanded(
              flex: 3,
              child: allTxAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
                data: (transactions) {
                  if (transactions.isEmpty) {
                    return const Center(child: Text('No transactions yet.'));
                  }
                  return ListView.builder(
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      return _HistoryTxItem(tx: transactions[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingTxItem extends ConsumerStatefulWidget {
  final TransactionModel tx;
  const _PendingTxItem({required this.tx});

  @override
  ConsumerState<_PendingTxItem> createState() => _PendingTxItemState();
}

class _PendingTxItemState extends ConsumerState<_PendingTxItem> {
  bool _isProcessing = false;

  Future<void> _process(String targetStatus) async {
    setState(() => _isProcessing = true);
    try {
      await ref.read(transactionRepositoryProvider).updateTransactionStatus(widget.tx.id, targetStatus);
      // Item will naturally disappear when the stream updates.
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDeposit = widget.tx.type == 'deposit';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Colors.orange, width: 1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          ListTile(
            title: Text('${isDeposit ? "Deposit" : "Withdraw"} Request'),
            subtitle: Text('Amount: ₹${widget.tx.amount.toStringAsFixed(2)}\nNote: ${widget.tx.note ?? "N/A"}\nDate: ${DateFormat.yMd().add_jm().format(widget.tx.createdAt.toLocal())}'),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  onPressed: _isProcessing ? null : () => _process('approved'),
                ),
                IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  onPressed: _isProcessing ? null : () => _process('rejected'),
                ),
              ],
            ),
          ),
          if (_isProcessing)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryTxItem extends StatelessWidget {
  final TransactionModel tx;
  const _HistoryTxItem({required this.tx});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (tx.status) {
      case 'approved':
        statusColor = Colors.green;
        break;
      case 'rejected':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
    }
    final isDeposit = tx.type == 'deposit';

    return ListTile(
      leading: Icon(
        isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
        color: isDeposit ? Colors.green : Colors.red,
      ),
      title: Text('₹${tx.amount.toStringAsFixed(2)} - ${isDeposit ? "Deposit" : "Withdraw"}'),
      subtitle: Text(DateFormat.yMd().add_jm().format(tx.createdAt.toLocal())),
      trailing: Text(
        tx.status.toUpperCase(),
        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
      ),
    );
  }
}
