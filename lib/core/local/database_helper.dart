import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'database_provider.dart';

class DatabaseHelper implements DatabaseProvider {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Database? _database;

  @override
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'messenger.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        chat_id TEXT NOT NULL,
        author_id TEXT NOT NULL,
        text TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        status INTEGER NOT NULL,
        client_message_id TEXT,
        reply_to_message_id TEXT,
        forwarded_from_message_id TEXT,
        attached_content TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_messages_chat_id_created_at ON messages(chat_id, created_at DESC)',
    );

    await db.execute('''
      CREATE TABLE chats (
        id TEXT PRIMARY KEY,
        type INTEGER NOT NULL,
        title TEXT,
        members TEXT,
        last_message TEXT,
        unread_count INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add local_path if not exists based on previous conversations, but I'll focus on chats table here
      // But actually, there was a migration in the past adding local_path to messages. I should wrap it in try-catch to avoid duplicate column.
      try {
        await db.execute('ALTER TABLE messages ADD COLUMN local_path TEXT');
      } catch (_) {}

      await db.execute('''
        CREATE TABLE chats (
          id TEXT PRIMARY KEY,
          type INTEGER NOT NULL,
          title TEXT,
          members TEXT,
          last_message TEXT,
          unread_count INTEGER NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
    }
  }
}
