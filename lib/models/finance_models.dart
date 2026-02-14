enum TransactionType {
  expense,
  income,
  debt,
  settlement,
  transfer,
  cardPurchase,
  cardSale,
  deposit,
  withdrawal,
  loan,
}

class Account {
  final int? id;
  final String name;
  final String kind; // cash, provider, client, person, owner
  final double balance;

  const Account({
    this.id,
    required this.name,
    required this.kind,
    required this.balance,
  });

  Account copyWith({int? id, String? name, String? kind, double? balance}) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      balance: balance ?? this.balance,
    );
  }
}

class Category {
  final int? id;
  final String name;
  final String type; // expense, income

  const Category({this.id, required this.name, required this.type});
}

class FinanceTransaction {
  final int? id;
  final TransactionType type;
  final double amount;
  final int fromAccount;
  final int toAccount;
  final DateTime date;
  final String description;
  final int? categoryId;
  final int? linkedTransactionId;

  const FinanceTransaction({
    this.id,
    required this.type,
    required this.amount,
    required this.fromAccount,
    required this.toAccount,
    required this.date,
    required this.description,
    this.categoryId,
    this.linkedTransactionId,
  });
}

class Debt {
  final int? id;
  final int accountId;
  final String direction; // owed_by_me / owed_to_me
  final double amount;

  const Debt({
    this.id,
    required this.accountId,
    required this.direction,
    required this.amount,
  });
}

class DashboardSummary {
  final double totalBalance;
  final double income;
  final double expense;
  final double owedByMe;
  final double owedToMe;

  const DashboardSummary({
    required this.totalBalance,
    required this.income,
    required this.expense,
    required this.owedByMe,
    required this.owedToMe,
  });
}
