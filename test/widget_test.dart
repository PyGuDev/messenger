import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messenger/core/network/configuration_error_state.dart';
import 'package:messenger/main.dart';

void main() {
  testWidgets('renders the blocking configuration error screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ConfigurationErrorScreen(
          error: ConfigurationErrorState(
            code: 'runtime_configuration_invalid',
            message: 'Runtime configuration is invalid.',
            missingKeys: <String>['APP_CHAT_BASE_URL', 'APP_WS_BASE_URL'],
            affectedFlows: <String>['chat messaging', 'websocket updates'],
          ),
        ),
      ),
    );

    expect(find.text('Configuration Error'), findsOneWidget);
    expect(find.textContaining('APP_CHAT_BASE_URL'), findsOneWidget);
    expect(find.textContaining('websocket updates'), findsOneWidget);
  });
}
