import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database_service.dart';
import '../models/finance_models.dart';

class AppState extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;

  List<Account> accounts = [];
  List<FinanceTransaction> transactions = [];
  DashboardSummary summary = const DashboardSummary(
    totalBalance: 0,
    income: 0,
    expense: 0,
    owedByMe: 0,
    owedToMe: 0,
  );

  bool pinEnabled = false;

  Future<void> bootstrap() async {
    await refresh();
    final pref = await SharedPreferences.getInstance();
    pinEnabled = pref.getBool('pin_enabled') ?? false;
    notifyListeners();
  }

  Future<void> refresh() async {
    accounts = await _db.getAccounts();
    transactions = await _db.recentTransactions();
    summary = await _db.dashboardSummary();
    notifyListeners();
  }

  Future<void> addIncome({required double amount, required int toAccount, required String description, int? categoryId}) async {
    await _db.transfer(
      type: TransactionType.income,
      amount: amount,
      fromAccount: toAccount,
      toAccount: toAccount,
      description: description,
      categoryId: categoryId,
    );
    await refresh();
  }

  Future<void> addExpense({required double amount, required int fromAccount, required String description, int? categoryId}) async {
    await _db.transfer(
      type: TransactionType.expense,
      amount: amount,
      fromAccount: fromAccount,
      toAccount: fromAccount,
      description: description,
      categoryId: categoryId,
    );
    await refresh();
  }

  Future<void> addPerson(String name, String kind) async {
    await _db.addAccount(Account(name: name, kind: kind, balance: 0));
    await refresh();
  }

  Future<void> recordCardPurchase({required int providerAccountId, required int cashAccountId, required double amount}) async {
    await _db.transfer(
      type: TransactionType.cardPurchase,
      amount: amount,
      fromAccount: cashAccountId,
      toAccount: providerAccountId,
      description: 'شراء كروت من مزود',
    );
    await _db.adjustDebt(accountId: providerAccountId, direction: 'owed_by_me', delta: amount);
    await refresh();
  }

  Future<void> recordCardSale({required int clientAccountId, required int cashAccountId, required double amount}) async {
    await _db.transfer(
      type: TransactionType.cardSale,
      amount: amount,
      fromAccount: clientAccountId,
      toAccount: cashAccountId,
      description: 'بيع كروت لعميل',
    );
    await _db.adjustDebt(accountId: clientAccountId, direction: 'owed_to_me', delta: amount);
    await refresh();
  }

  Future<void> settleClientAndProvider({
    required int clientAccountId,
    required int providerAccountId,
    required int cashAccountId,
    required double amount,
  }) async {
    final now = DateTime.now();
    await _db.recordDoubleEntry(
      debit: FinanceTransaction(
        type: TransactionType.settlement,
        amount: amount,
        fromAccount: clientAccountId,
        toAccount: cashAccountId,
        date: now,
        description: 'تحصيل من العميل',
      ),
      credit: FinanceTransaction(
        type: TransactionType.settlement,
        amount: amount,
        fromAccount: cashAccountId,
        toAccount: providerAccountId,
        date: now,
        description: 'تسديد للمزود تلقائيًا',
      ),
    );
    await _db.adjustDebt(accountId: clientAccountId, direction: 'owed_to_me', delta: -amount);
    await _db.adjustDebt(accountId: providerAccountId, direction: 'owed_by_me', delta: -amount);
    await refresh();
  }

  Future<void> personLoan({required int personAccountId, required int cashAccountId, required double amount}) async {
    await _db.transfer(
      type: TransactionType.loan,
      amount: amount,
      fromAccount: personAccountId,
      toAccount: cashAccountId,
      description: 'سلفة من الشخص',
    );
    await _db.adjustDebt(accountId: personAccountId, direction: 'owed_by_me', delta: amount);
    await refresh();
  }

  Future<String> exportJsonBackup() async {
    final payload = {
      'accounts': accounts
          .map((a) => {'id': a.id, 'name': a.name, 'kind': a.kind, 'balance': a.balance})
          .toList(),
      'transactions': transactions
          .map((t) => {
                'id': t.id,
                'type': t.type.name,
                'amount': t.amount,
                'from': t.fromAccount,
                'to': t.toAccount,
                'date': t.date.toIso8601String(),
                'description': t.description,
              })
          .toList(),
      'summary': {
        'totalBalance': summary.totalBalance,
        'income': summary.income,
        'expense': summary.expense,
        'owedByMe': summary.owedByMe,
        'owedToMe': summary.owedToMe,
      },
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }
}
