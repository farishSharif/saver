import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../transactions/providers/transaction_provider.dart';
import '../../transactions/models/transaction_model.dart';
import 'package:intl/intl.dart';

class CalendarTab extends ConsumerStatefulWidget {
  final bool isAdmin;
  const CalendarTab({super.key, this.isAdmin = false});

  @override
  ConsumerState<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends ConsumerState<CalendarTab> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  bool isSameWeek(DateTime date1, DateTime date2) {
    final diff = date1.difference(date2).inDays;
    if (diff.abs() >= 7) return false;
    
    // Check if they are in the same ISO week
    DateTime startOfWeek1 = date1.subtract(Duration(days: date1.weekday - 1));
    DateTime startOfWeek2 = date2.subtract(Duration(days: date2.weekday - 1));
    return startOfWeek1.year == startOfWeek2.year && startOfWeek1.month == startOfWeek2.month && startOfWeek1.day == startOfWeek2.day;
  }

  @override
  Widget build(BuildContext context) {
    final txAsync = widget.isAdmin
        ? ref.watch(allTransactionsProvider)
        : ref.watch(userTransactionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: txAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (transactions) {
          // Group transactions by day for calendar markers
          final transactionsByDay = <DateTime, List<TransactionModel>>{};
          for (final tx in transactions) {
            if (tx.status != 'approved') continue;
            
            final date = DateTime(tx.createdAt.year, tx.createdAt.month, tx.createdAt.day);
            if (!transactionsByDay.containsKey(date)) {
              transactionsByDay[date] = [];
            }
            transactionsByDay[date]!.add(tx);
          }

          // Calculate weekly stats based on the selected day.
          double weeklyDeposit = 0;
          double weeklyWithdraw = 0;
          Set<String> activeDays = {};

          if (_selectedDay != null) {
            for (final tx in transactions) {
              if (tx.status != 'approved') continue;
              if (isSameWeek(tx.createdAt, _selectedDay!)) {
                if (tx.type == 'deposit') {
                  weeklyDeposit += tx.amount;
                } else if (tx.type == 'withdraw') {
                  weeklyWithdraw += tx.amount;
                }
                activeDays.add(DateFormat('yyyy-MM-dd').format(tx.createdAt));
              }
            }
          }

          return Column(
            children: [
              TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  if (!isSameDay(_selectedDay, selectedDay)) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  }
                },
                onFormatChanged: (format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                },
                eventLoader: (day) {
                  final dateOnly = DateTime(day.year, day.month, day.day);
                  return transactionsByDay[dateOnly] ?? [];
                },
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, date, events) {
                    if (events.isEmpty) return null;
                    return Positioned(
                      bottom: 1,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Weekly Summary',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _selectedDay != null ? 'Week of ${DateFormat.yMd().format(_selectedDay!)}' : 'Select a day',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 24),
                      _StatRow(
                        icon: Icons.calendar_today,
                        color: Colors.blue,
                        label: 'Days active this week',
                        value: '${activeDays.length} days',
                      ),
                      const Divider(height: 32),
                      _StatRow(
                        icon: Icons.arrow_downward,
                        color: Colors.green,
                        label: 'Total Given (Deposit)',
                        value: '₹${weeklyDeposit.toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: 16),
                      _StatRow(
                        icon: Icons.arrow_upward,
                        color: Colors.red,
                        label: 'Total Withdrawn',
                        value: '₹${weeklyWithdraw.toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _StatRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 16)),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
