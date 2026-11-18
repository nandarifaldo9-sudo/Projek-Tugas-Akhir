import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:projek_tugas_akhir/data/database_helper.dart';
import 'package:projek_tugas_akhir/models/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late DatabaseFactory factory;
  late String databasePath;

  setUpAll(() {
    sqfliteFfiInit();
    factory = databaseFactoryFfi;
  });

  setUp(() async {
    databasePath = path.join(
      await factory.getDatabasesPath(),
      'flowly_migration_${DateTime.now().microsecondsSinceEpoch}.db',
    );
  });

  tearDown(() async {
    await factory.deleteDatabase(databasePath);
  });

  test('upgrades a version 1 database and reads nullable categories', () async {
    final versionOne = await factory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE accounts (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL UNIQUE,
              initial_balance INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE categories (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              type TEXT NOT NULL,
              UNIQUE (name, type)
            )
          ''');
          await db.execute('''
            CREATE TABLE transactions (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              type TEXT NOT NULL,
              amount INTEGER NOT NULL CHECK (amount > 0),
              account_id INTEGER NOT NULL REFERENCES accounts(id),
              to_account_id INTEGER REFERENCES accounts(id),
              category_id INTEGER REFERENCES categories(id),
              date TEXT NOT NULL,
              note TEXT NOT NULL DEFAULT ''
            )
          ''');
          await db.insert('accounts', {'id': 1, 'name': 'Tunai'});
          await db.insert('accounts', {'id': 2, 'name': 'Bank'});
          await db.insert('transactions', {
            'type': 'expense',
            'amount': 100,
            'account_id': 1,
            'category_id': null,
            'date': '2025-03-10',
          });
        },
      ),
    );
    await versionOne.close();

    final helper = DatabaseHelper(factory: factory, databasePath: databasePath);
    final transactions = await helper.getTransactions();
    final db = await helper.database;
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );

    expect(transactions.single.categoryId, isNull);
    expect(
      tables.map((row) => row['name']),
      containsAll(['goals', 'deposits']),
    );
    expect(await helper.isAccountUsed(2), isFalse);

    await db.insert('transactions', {
      'type': TxType.transfer.name,
      'amount': 25,
      'account_id': 1,
      'to_account_id': 2,
      'category_id': null,
      'date': '2025-03-11',
    });
    expect(await helper.isAccountUsed(2), isTrue);
  });
}
