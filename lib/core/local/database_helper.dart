import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'messenger.db');

    return await openDatabase(path, version: 1, onCreate: _onCreate);
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
  }
}
