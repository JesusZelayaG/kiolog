// test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiolog/main.dart';
import 'package:kiolog/core/router/app_router.dart';
import 'package:kiolog/core/theme/app_theme.dart';

void main() {
  testWidgets('KiologApp smoke test — renders NavigationBar', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: appRouter,
        theme: AppTheme.light,
      ),
    );

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(KiologApp), findsNothing); // KiologApp itself not used here
  });
}
