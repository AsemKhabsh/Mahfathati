import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/finance_models.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _database;

  Future<Database> get db async {
    if (_database != null) return _database!;
    final path = join(await getDatabasesPath(), 'mahfathati.db');
    _database = await openDatabase(path, version: 1, onCreate: _onCreate);
    return _database!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        kind TEXT NOT NULL,
        balance REAL NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        from_account INTEGER NOT NULL,
        to_account INTEGER NOT NULL,
        date TEXT NOT NULL,
        description TEXT,
        category_id INTEGER,
        linked_transaction_id INTEGER,
        FOREIGN KEY (from_account) REFERENCES accounts(id),
        FOREIGN KEY (to_account) REFERENCES accounts(id),
        FOREIGN KEY (category_id) REFERENCES categories(id),
        FOREIGN KEY (linked_transaction_id) REFERENCES transactions(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE debts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL,
        direction TEXT NOT NULL,
        amount REAL NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts(id)
      )
    ''');

    await _seed(db);
  }

  Future<void> _seed(Database db) async {
    await db.insert('accounts', {'name': 'محفظتي النقدية', 'kind': 'cash', 'balance': 0.0});
    await db.insert('accounts', {'name': 'مزود افتراضي', 'kind': 'provider', 'balance': 0.0});
    await db.insert('accounts', {'name': 'عميل تجريبي', 'kind': 'client', 'balance': 0.0});

    for (final item in [
      {'name': 'طعام', 'type': 'expense'},
      {'name': 'مواصلات', 'type': 'expense'},
      {'name': 'إنترنت', 'type': 'expense'},
      {'name': 'راتب', 'type': 'income'},
      {'name': 'عمل حر', 'type': 'income'},
    ]) {
      await db.insert('categories', item);
    }
  }

  Future<List<Account>> getAccounts() async {
    final rows = await (await db).query('accounts', orderBy: 'id DESC');
    return rows
        .map((e) => Account(
              id: e['id'] as int,
              name: e['name'] as String,
              kind: e['kind'] as String,
              balance: (e['balance'] as num).toDouble(),
            ))
        .toList();
  }

  Future<List<Category>> getCategories(String type) async {
    final rows = await (await db).query('categories', where: 'type=?', whereArgs: [type]);
    return rows
        .map((e) => Category(id: e['id'] as int, name: e['name'] as String, type: e['type'] as String))
        .toList();
  }

  Future<int> addAccount(Account account) async {
    return (await db).insert('accounts', {
      'name': account.name,
      'kind': account.kind,
      'balance': account.balance,
    });
  }

  Future<void> recordDoubleEntry({
    required FinanceTransaction debit,
    required FinanceTransaction credit,
  }) async {
    final database = await db;
    await database.transaction((txn) async {
      final debitId = await txn.insert('transactions', _txToMap(debit));
      final creditMap = _txToMap(credit)..['linked_transaction_id'] = debitId;
      final creditId = await txn.insert('transactions', creditMap);
      await txn.update(
        'transactions',
        {'linked_transaction_id': creditId},
        where: 'id=?',
        whereArgs: [debitId],
      );
      await _applyBalanceDelta(txn, debit.fromAccount, -debit.amount);
      await _applyBalanceDelta(txn, debit.toAccount, debit.amount);
      await _applyBalanceDelta(txn, credit.fromAccount, -credit.amount);
      await _applyBalanceDelta(txn, credit.toAccount, credit.amount);
    });
  }

  Future<void> transfer({
    required TransactionType type,
    required double amount,
    required int fromAccount,
    required int toAccount,
    required String description,
    int? categoryId,
  }) async {
    final database = await db;
    await database.transaction((txn) async {
      final fromBalance = await _accountBalance(txn, fromAccount);
      if (fromBalance - amount < -1000000) {
        throw Exception('Balance validation failed');
      }
      final txId = await txn.insert('transactions', {
        'type': type.name,
        'amount': amount,
        'from_account': fromAccount,
        'to_account': toAccount,
        'date': DateTime.now().toIso8601String(),
        'description': description,
        'category_id': categoryId,
      });
      await txn.update('transactions', {'linked_transaction_id': txId}, where: 'id=?', whereArgs: [txId]);
      await _applyBalanceDelta(txn, fromAccount, -amount);
      await _applyBalanceDelta(txn, toAccount, amount);
    });
  }

  Future<void> adjustDebt({required int accountId, required String direction, required double delta}) async {
    final database = await db;
    final existing = await database.query(
      'debts',
      where: 'account_id=? AND direction=?',
      whereArgs: [accountId, direction],
      limit: 1,
    );
    if (existing.isEmpty) {
      await database.insert('debts', {'account_id': accountId, 'direction': direction, 'amount': delta});
    } else {
      final row = existing.first;
      final updated = (row['amount'] as num).toDouble() + delta;
      await database.update('debts', {'amount': updated.clamp(0, 1e12)}, where: 'id=?', whereArgs: [row['id']]);
    }
  }

  Future<List<FinanceTransaction>> recentTransactions({int limit = 40}) async {
    final rows = await (await db).query('transactions', orderBy: 'date DESC', limit: limit);
    return rows
        .map((e) => FinanceTransaction(
              id: e['id'] as int,
              type: TransactionType.values.firstWhere((v) => v.name == e['type']),
              amount: (e['amount'] as num).toDouble(),
              fromAccount: e['from_account'] as int,
              toAccount: e['to_account'] as int,
              date: DateTime.parse(e['date'] as String),
              description: (e['description'] as String?) ?? '',
              categoryId: e['category_id'] as int?,
              linkedTransactionId: e['linked_transaction_id'] as int?,
            ))
        .toList();
  }

  Future<DashboardSummary> dashboardSummary() async {
    final database = await db;
    final income = Sqflite.firstIntValue(await database.rawQuery(
          "SELECT CAST(COALESCE(SUM(amount),0) AS INTEGER) FROM transactions WHERE type='income'",
        ))?.toDouble() ??
        0;
    final expense = Sqflite.firstIntValue(await database.rawQuery(
          "SELECT CAST(COALESCE(SUM(amount),0) AS INTEGER) FROM transactions WHERE type='expense'",
        ))?.toDouble() ??
        0;
    final totalBalance = Sqflite.firstIntValue(await database.rawQuery(
          'SELECT CAST(COALESCE(SUM(balance),0) AS INTEGER) FROM accounts',
        ))?.toDouble() ??
        0;

    final owedByMe = Sqflite.firstIntValue(await database.rawQuery(
          "SELECT CAST(COALESCE(SUM(amount),0) AS INTEGER) FROM debts WHERE direction='owed_by_me'",
        ))?.toDouble() ??
        0;
    final owedToMe = Sqflite.firstIntValue(await database.rawQuery(
          "SELECT CAST(COALESCE(SUM(amount),0) AS INTEGER) FROM debts WHERE direction='owed_to_me'",
        ))?.toDouble() ??
        0;

    return DashboardSummary(
      totalBalance: totalBalance,
      income: income,
      expense: expense,
      owedByMe: owedByMe,
      owedToMe: owedToMe,
    );
  }

  Map<String, dynamic> _txToMap(FinanceTransaction tx) => {
        'type': tx.type.name,
        'amount': tx.amount,
        'from_account': tx.fromAccount,
        'to_account': tx.toAccount,
        'date': tx.date.toIso8601String(),
        'description': tx.description,
        'category_id': tx.categoryId,
        'linked_transaction_id': tx.linkedTransactionId,
      };

  Future<void> _applyBalanceDelta(Transaction txn, int accountId, double delta) async {
    final balance = await _accountBalance(txn, accountId);
    await txn.update('accounts', {'balance': balance + delta}, where: 'id=?', whereArgs: [accountId]);
  }

  Future<double> _accountBalance(Transaction txn, int accountId) async {
    final rows = await txn.query('accounts', columns: ['balance'], where: 'id=?', whereArgs: [accountId], limit: 1);
    return (rows.first['balance'] as num).toDouble();
  }
}
