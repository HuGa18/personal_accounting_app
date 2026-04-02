import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  Future<void> initialize() async {
    await database;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'accounting.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createTables(db);
    await _seedData(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Version upgrade logic
    }
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE accounts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        balance REAL DEFAULT 0,
        currency TEXT DEFAULT 'CNY',
        color TEXT DEFAULT '#2563EB',
        created_at TEXT DEFAULT (datetime('now')),
        updated_at TEXT DEFAULT (datetime('now')),
        is_deleted INTEGER DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_accounts_type ON accounts(type)');
    await db.execute('CREATE INDEX idx_accounts_is_deleted ON accounts(is_deleted)');

    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        account_id TEXT NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        category_id TEXT,
        sub_category_id TEXT,
        merchant_name TEXT,
        description TEXT,
        transaction_date TEXT NOT NULL,
        source TEXT,
        location TEXT,
        tags TEXT,
        created_at TEXT DEFAULT (datetime('now')),
        updated_at TEXT DEFAULT (datetime('now')),
        is_deleted INTEGER DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_transactions_account_id ON transactions(account_id)');
    await db.execute('CREATE INDEX idx_transactions_category_id ON transactions(category_id)');
    await db.execute('CREATE INDEX idx_transactions_date ON transactions(transaction_date)');
    await db.execute('CREATE INDEX idx_transactions_is_deleted ON transactions(is_deleted)');

    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon TEXT,
        color TEXT,
        parent_id TEXT,
        type TEXT NOT NULL,
        keywords TEXT,
        is_system INTEGER DEFAULT 1,
        created_at TEXT DEFAULT (datetime('now')),
        updated_at TEXT DEFAULT (datetime('now')),
        is_deleted INTEGER DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_categories_parent_id ON categories(parent_id)');
    await db.execute('CREATE INDEX idx_categories_type ON categories(type)');
    await db.execute('CREATE INDEX idx_categories_is_deleted ON categories(is_deleted)');

    await db.execute('''
      CREATE TABLE budgets (
        id TEXT PRIMARY KEY,
        category_id TEXT NOT NULL,
        amount REAL NOT NULL,
        period TEXT NOT NULL,
        start_day INTEGER DEFAULT 1,
        created_at TEXT DEFAULT (datetime('now')),
        updated_at TEXT DEFAULT (datetime('now')),
        is_deleted INTEGER DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_budgets_category_id ON budgets(category_id)');
    await db.execute('CREATE INDEX idx_budgets_is_deleted ON budgets(is_deleted)');

    await db.execute('''
      CREATE TABLE import_records (
        id TEXT PRIMARY KEY,
        source TEXT NOT NULL,
        external_id TEXT,
        import_date TEXT NOT NULL,
        record_count INTEGER,
        created_at TEXT DEFAULT (datetime('now')),
        updated_at TEXT DEFAULT (datetime('now')),
        is_deleted INTEGER DEFAULT 0,
        UNIQUE(source, external_id)
      )
    ''');
    await db.execute('CREATE INDEX idx_import_records_source ON import_records(source)');
    await db.execute('CREATE INDEX idx_import_records_external_id ON import_records(external_id)');
    await db.execute('CREATE INDEX idx_import_records_is_deleted ON import_records(is_deleted)');
  }

  Future<void> _seedData(Database db) async {
    final now = DateTime.now().toIso8601String();

    final expenseCategories = [
      {'name': '餐饮美食', 'icon': 'restaurant', 'color': '#FF6B6B', 'keywords': '餐,饭,吃,外卖,美团,饿了么,肯德基,KFC,麦当劳,星巴克,奶茶,咖啡'},
      {'name': '购物消费', 'icon': 'shopping_cart', 'color': '#45B7D1', 'keywords': '淘宝,京东,拼多多,超市,商场,网购,天猫'},
      {'name': '交通出行', 'icon': 'directions_car', 'color': '#4ECDC4', 'keywords': '滴滴,打车,地铁,公交,出行,加油,停车,高铁,火车,飞机,出租车'},
      {'name': '娱乐休闲', 'icon': 'movie', 'color': '#96CEB4', 'keywords': '电影,游戏,KTV,酒吧,演唱会,旅游,景点,门票'},
      {'name': '医疗健康', 'icon': 'local_hospital', 'color': '#FFEAA7', 'keywords': '医院,药店,诊所,体检,药品,挂号'},
      {'name': '教育学习', 'icon': 'school', 'color': '#DDA0DD', 'keywords': '培训,课程,书籍,学习,学费,网课'},
      {'name': '生活缴费', 'icon': 'home', 'color': '#F39C12', 'keywords': '水费,电费,燃气费,物业费,房租,宽带,话费'},
      {'name': '其他支出', 'icon': 'more_horiz', 'color': '#BDC3C7', 'keywords': ''},
    ];

    for (var i = 0; i < expenseCategories.length; i++) {
      final cat = expenseCategories[i];
      await db.insert('categories', {
        'id': 'cat_expense_$i',
        'name': cat['name'],
        'type': 'expense',
        'icon': cat['icon'],
        'color': cat['color'],
        'keywords': cat['keywords'],
        'is_system': 1,
        'created_at': now,
        'updated_at': now,
        'is_deleted': 0,
      });
    }

    final incomeCategories = [
      {'name': '工资收入', 'icon': 'account_balance_wallet', 'color': '#98D8C8', 'keywords': '工资,薪资,薪水'},
      {'name': '兼职外快', 'icon': 'work', 'color': '#F7DC6F', 'keywords': '兼职,外快,副业,兼职收入'},
      {'name': '投资收益', 'icon': 'trending_up', 'color': '#85C1E9', 'keywords': '股票,基金,理财,投资,分红'},
      {'name': '红包礼金', 'icon': 'card_giftcard', 'color': '#E74C3C', 'keywords': '红包,礼金,转账,收款'},
      {'name': '其他收入', 'icon': 'more_horiz', 'color': '#BDC3C7', 'keywords': ''},
    ];

    for (var i = 0; i < incomeCategories.length; i++) {
      final cat = incomeCategories[i];
      await db.insert('categories', {
        'id': 'cat_income_$i',
        'name': cat['name'],
        'type': 'income',
        'icon': cat['icon'],
        'color': cat['color'],
        'keywords': cat['keywords'],
        'is_system': 1,
        'created_at': now,
        'updated_at': now,
        'is_deleted': 0,
      });
    }

    final accounts = [
      {'id': 'acc_alipay', 'name': '支付宝', 'type': 'alipay', 'color': '#1677FF'},
      {'id': 'acc_wechat', 'name': '微信支付', 'type': 'wechat', 'color': '#07C160'},
      {'id': 'acc_cash', 'name': '现金', 'type': 'cash', 'color': '#FFD700'},
    ];

    for (var acc in accounts) {
      await db.insert('accounts', {
        'id': acc['id'],
        'name': acc['name'],
        'type': acc['type'],
        'color': acc['color'],
        'balance': 0.0,
        'currency': 'CNY',
        'created_at': now,
        'updated_at': now,
        'is_deleted': 0,
      });
    }
  }
}