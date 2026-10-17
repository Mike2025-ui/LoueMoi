import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/core/constants/app_constants.dart';
import 'package:louemoi/core/widgets/app_logo.dart';

void main() {
  group('AppLogo Widget Tests', () {
    testWidgets('renders default AppLogo with badge and app title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppLogo(),
          ),
        ),
      );

      expect(find.text(AppConstants.appDisplayName), findsOneWidget);
      expect(find.byIcon(Icons.apartment_rounded), findsOneWidget);
      expect(find.byType(Container), findsOneWidget);
    });

    testWidgets('renders AppLogo without text when showText is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppLogo(showText: false),
          ),
        ),
      );

      expect(find.text(AppConstants.appDisplayName), findsNothing);
      expect(find.byIcon(Icons.apartment_rounded), findsOneWidget);
    });

    testWidgets('renders flat AppLogo without badge when useBadge is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppLogo(useBadge: false),
          ),
        ),
      );

      expect(find.text(AppConstants.appDisplayName), findsOneWidget);
      expect(find.byIcon(Icons.apartment_rounded), findsOneWidget);
      expect(find.byType(Container), findsNothing);
    });
  });
}

