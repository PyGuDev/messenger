import 'dart:convert';

void main() {
  String token =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NzM5MTY2ODAsInN1YiI6IjQzNWJjZDc5LTlkNTgtNDFhZi04OGE2LWM0NDQzMDY4MTA2NCIsInVzZXJJRCI6IjQwZjdjMDU1LTk4OTctNGMwOS05MjViLWQ2Nzc2Y2E1Y2RmMyJ9.U9ZAkMrYcd6_ckZLOldhGg25Pdw0nOuwbAvR6vYPsWc';
  try {
    final parts = token.split('.');
    String payload = parts[1];
    switch (payload.length % 4) {
      case 2:
        payload += '==';
        break;
      case 3:
        payload += '=';
        break;
    }
    print('Payload: $payload');
    final decodedBytes = base64Url.decode(payload);
    final decoded = utf8.decode(decodedBytes);
    print('Decoded: $decoded');
    final json = jsonDecode(decoded) as Map<String, dynamic>;
    final res = (json['userID'] ?? json['user_id'] ?? json['sub']) as String?;
    print('Result ID: $res');
  } catch (e, st) {
    print('Error: $e');
    print(st);
  }
}
