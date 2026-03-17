import 'package:flutter_test/flutter_test.dart';
import 'package:messenger/features/messages/data/models/message_model.dart';

void main() {
  group('MessageModel Parsing Tests', () {
    test('should parse message correctly when updated_at is missing', () {
      final json = {
        "id": "9189d874-8033-4830-bbca-75b614695d30",
        "chat_id": "ce2b1ab7-0253-4113-b7a9-8748ee23d214",
        "author_id": "40f7c055-9897-4c09-925b-d6776ca5cdf3",
        "body": "Привет",
        "client_message_id": "88b811f9-b43d-4706-b698-4678365c537e",
        "attached_content": [],
        "created_at": "2026-03-17T18:20:33Z"
      };

      final model = MessageModel.fromJson(json);

      expect(model.id, equals("9189d874-8033-4830-bbca-75b614695d30"));
      expect(model.text, equals("Привет"));
      expect(model.updatedAt, equals(model.createdAt));
    });

    test('should parse message correctly when updated_at is present', () {
      final json = {
        "id": "170e7e30-a533-4831-88f6-fea22f289f1e",
        "chat_id": "ce2b1ab7-0253-4113-b7a9-8748ee23d214",
        "author_id": "40f7c055-9897-4c09-925b-d6776ca5cdf3",
        "body": "Hi, my friends",
        "client_message_id": "temp-1",
        "attached_content": [],
        "created_at": "2026-03-14T08:18:39Z",
        "updated_at": "2026-03-14T08:20:06Z"
      };

      final model = MessageModel.fromJson(json);

      expect(model.id, equals("170e7e30-a533-4831-88f6-fea22f289f1e"));
      expect(model.createdAt, equals(DateTime.parse("2026-03-14T08:18:39Z")));
      expect(model.updatedAt, equals(DateTime.parse("2026-03-14T08:20:06Z")));
    });
  });
}
