import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../logic/app_state.dart';
import '../../models/finance_models.dart';
import '../widgets/expense_pie_chart.dart';
import '../widgets/summary_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _HomeTab(),
      const _TransactionsTab(type: TransactionType.expense),
      const _TransactionsTab(type: TransactionType.income),
      const _PeopleTab(),
      const _DebtsTab(),
      const _ReportsTab(),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('محفظتي - إدارة مالية ذكية')),
      body: pages[currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) => setState(() => currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.money_off), label: 'النفقات'),
          NavigationDestination(icon: Icon(Icons.attach_money), label: 'الدخل'),
          NavigationDestination(icon: Icon(Icons.people), label: 'الأشخاص'),
          NavigationDestination(icon: Icon(Icons.balance), label: 'الديون'),
          NavigationDestination(icon: Icon(Icons.analytics), label: 'التقارير'),
        ],
      ),
      floatingActionButton: currentIndex == 1 || currentIndex == 2
          ? FloatingActionButton.extended(
              onPressed: () => _showAddTransaction(context, currentIndex == 1),
              icon: const Icon(Icons.add),
              label: const Text('إضافة عملية'),
            )
          : null,
    );
  }

  Future<void> _showAddTransaction(BuildContext context, bool expense) async {
    final state = context.read<AppState>();
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    int? selectedAccount = state.accounts.isEmpty ? null : state.accounts.first.id;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: StatefulBuilder(builder: (context, setLocal) {
          return ListView(
            padding: const EdgeInsets.all(16),
            shrinkWrap: true,
            children: [
              Text(expense ? 'إضافة مصروف' : 'إضافة دخل', style: Theme.of(context).textTheme.titleLarge),
              TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ')),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'الوصف')),
              DropdownButtonFormField<int>(
                value: selectedAccount,
                items: state.accounts
                    .map((a) => DropdownMenuItem(value: a.id, child: Text('${a.name} (${a.kind})')))
                    .toList(),
                onChanged: (value) => setLocal(() => selectedAccount = value),
                decoration: const InputDecoration(labelText: 'الحساب'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: selectedAccount == null
                    ? null
                    : () async {
                        final amount = double.tryParse(amountCtrl.text) ?? 0;
                        if (expense) {
                          await state.addExpense(amount: amount, fromAccount: selectedAccount!, description: descCtrl.text);
                        } else {
                          await state.addIncome(amount: amount, toAccount: selectedAccount!, description: descCtrl.text);
                        }
                        if (context.mounted) Navigator.pop(context);
                      },
                child: const Text('حفظ'),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final f = NumberFormat.currency(locale: 'ar', symbol: 'ر.س');
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SummaryCard(title: 'الرصيد الحالي', value: f.format(state.summary.totalBalance), icon: Icons.account_balance_wallet),
        SummaryCard(title: 'إجمالي الدخل', value: f.format(state.summary.income), icon: Icons.trending_up),
        SummaryCard(title: 'إجمالي المصروف', value: f.format(state.summary.expense), icon: Icons.trending_down),
        SummaryCard(title: 'ديون عليّ', value: f.format(state.summary.owedByMe), icon: Icons.call_received),
        SummaryCard(title: 'ديون لي', value: f.format(state.summary.owedToMe), icon: Icons.call_made),
        ExpensePieChart(expense: state.summary.expense, income: state.summary.income),
      ],
    );
  }
}

class _TransactionsTab extends StatelessWidget {
  final TransactionType type;
  const _TransactionsTab({required this.type});

  @override
  Widget build(BuildContext context) {
    final rows = context.watch<AppState>().transactions.where((t) => t.type == type).toList();
    final f = NumberFormat.currency(locale: 'ar', symbol: 'ر.س');
    if (rows.isEmpty) return const Center(child: Text('لا توجد بيانات بعد'));
    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (_, i) {
        final tx = rows[i];
        return ListTile(
          leading: CircleAvatar(child: Text('${i + 1}')),
          title: Text(tx.description.isEmpty ? tx.type.name : tx.description),
          subtitle: Text(DateFormat('yyyy/MM/dd - HH:mm').format(tx.date)),
          trailing: Text(f.format(tx.amount)),
        );
      },
    );
  }
}

class _PeopleTab extends StatelessWidget {
  const _PeopleTab();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final people = state.accounts.where((a) => a.kind == 'person' || a.kind == 'provider' || a.kind == 'client').toList();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        FilledButton.icon(
          onPressed: () => _showAddPerson(context),
          icon: const Icon(Icons.person_add),
          label: const Text('إضافة شخص/مزود/عميل'),
        ),
        const SizedBox(height: 8),
        ...people.map((p) => Card(
              child: ListTile(
                title: Text(p.name),
                subtitle: Text('النوع: ${p.kind}'),
                trailing: Text(p.balance.toStringAsFixed(2)),
              ),
            )),
      ],
    );
  }

  Future<void> _showAddPerson(BuildContext context) async {
    final state = context.read<AppState>();
    final nameCtrl = TextEditingController();
    String kind = 'person';
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إضافة حساب شخصي'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'الاسم')),
            DropdownButtonFormField(
              value: kind,
              items: const [
                DropdownMenuItem(value: 'person', child: Text('شخص')),
                DropdownMenuItem(value: 'provider', child: Text('مزود')),
                DropdownMenuItem(value: 'client', child: Text('عميل')),
              ],
              onChanged: (v) => kind = (v ?? 'person'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              await state.addPerson(nameCtrl.text.trim(), kind);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

class _DebtsTab extends StatelessWidget {
  const _DebtsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: const [
        Card(
          child: ListTile(
            leading: Icon(Icons.swap_horiz),
            title: Text('نظام التسوية المزدوجة مفعل'),
            subtitle: Text('عند التحصيل من عميل يتم توجيه نفس المبلغ تلقائيًا لتسديد المزود.'),
          ),
        ),
      ],
    );
  }
}

class _ReportsTab extends StatelessWidget {
  const _ReportsTab();

  @override
  Widget build(BuildContext context) {
    final tx = context.watch<AppState>().transactions;
    final now = DateTime.now();
    int daily = tx.where((e) => e.date.day == now.day && e.date.month == now.month).length;
    int weekly = tx.where((e) => now.difference(e.date).inDays <= 7).length;
    int monthly = tx.where((e) => e.date.month == now.month).length;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(child: ListTile(title: const Text('تقرير يومي'), trailing: Text('$daily عملية'))),
        Card(child: ListTile(title: const Text('تقرير أسبوعي'), trailing: Text('$weekly عملية'))),
        Card(child: ListTile(title: const Text('تقرير شهري'), trailing: Text('$monthly عملية'))),
        const Card(
          child: ListTile(
            title: Text('دفتر الأستاذ Ledger (اقتراح احترافي)'),
            subtitle: Text('يمكن إضافة صفحة قيود يومية مع تصدير PDF/Excel عبر syncfusion_flutter_pdf وexcel.'),
          ),
        ),
      ],
    );
  }
}
