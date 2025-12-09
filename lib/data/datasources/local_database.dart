import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../core/constants/app_constants.dart';

class LocalDatabase {
  static Database? _database;
  static final LocalDatabase instance = LocalDatabase._init();

  LocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);

    return await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Tabla de categorías
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        parent_id TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Tabla de productos
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        code TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        category_id TEXT,
        unit_price REAL NOT NULL DEFAULT 0,
        cost_price REAL NOT NULL DEFAULT 0,
        stock REAL DEFAULT 0,
        min_stock REAL DEFAULT 0,
        unit TEXT DEFAULT 'UND',
        is_active INTEGER DEFAULT 1,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (category_id) REFERENCES categories(id)
      )
    ''');

    // Tabla de movimientos de stock
    await db.execute('''
      CREATE TABLE stock_movements (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        type TEXT NOT NULL,
        quantity REAL NOT NULL,
        reason TEXT,
        reference TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        created_by TEXT,
        FOREIGN KEY (product_id) REFERENCES products(id)
      )
    ''');

    // Tabla de clientes
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        document_type TEXT NOT NULL,
        document_number TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        trade_name TEXT,
        address TEXT,
        phone TEXT,
        email TEXT,
        credit_limit REAL DEFAULT 0,
        current_balance REAL DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Tabla de facturas
    await db.execute('''
      CREATE TABLE invoices (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        series TEXT NOT NULL,
        number TEXT NOT NULL,
        customer_id TEXT,
        customer_name TEXT NOT NULL,
        customer_document TEXT NOT NULL,
        issue_date TEXT NOT NULL,
        due_date TEXT,
        subtotal REAL NOT NULL DEFAULT 0,
        tax_amount REAL NOT NULL DEFAULT 0,
        discount REAL DEFAULT 0,
        total REAL NOT NULL DEFAULT 0,
        paid_amount REAL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'draft',
        payment_method TEXT,
        notes TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (customer_id) REFERENCES customers(id),
        UNIQUE(series, number)
      )
    ''');

    // Tabla de items de factura
    await db.execute('''
      CREATE TABLE invoice_items (
        id TEXT PRIMARY KEY,
        invoice_id TEXT NOT NULL,
        product_id TEXT,
        product_name TEXT NOT NULL,
        product_code TEXT,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        discount REAL DEFAULT 0,
        tax_rate REAL DEFAULT 18,
        subtotal REAL NOT NULL,
        total REAL NOT NULL,
        FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products(id)
      )
    ''');

    // Tabla de pagos
    await db.execute('''
      CREATE TABLE payments (
        id TEXT PRIMARY KEY,
        invoice_id TEXT NOT NULL,
        amount REAL NOT NULL,
        payment_method TEXT NOT NULL,
        reference TEXT,
        notes TEXT,
        payment_date TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (invoice_id) REFERENCES invoices(id)
      )
    ''');

    // Tabla de sincronización
    await db.execute('''
      CREATE TABLE sync_queue (
        id TEXT PRIMARY KEY,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        data TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        synced_at TEXT,
        status TEXT DEFAULT 'pending'
      )
    ''');

    // Índices para mejor rendimiento
    await db.execute('CREATE INDEX idx_products_code ON products(code)');
    await db.execute('CREATE INDEX idx_products_category ON products(category_id)');
    await db.execute('CREATE INDEX idx_customers_document ON customers(document_number)');
    await db.execute('CREATE INDEX idx_invoices_customer ON invoices(customer_id)');
    await db.execute('CREATE INDEX idx_invoices_date ON invoices(issue_date)');
    await db.execute('CREATE INDEX idx_invoices_status ON invoices(status)');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // Migraciones futuras aquí
  }

  // Métodos de utilidad
  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    final db = await database;
    return db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
  }

  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> update(
    String table,
    Map<String, dynamic> data, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await database;
    return db.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await database;
    return db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
