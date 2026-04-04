import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decentralized_library/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: DecentralizedLibraryApp()));

    // Verify that the splash text is present.
    expect(find.text('Decentralized Library - Auth Setup Pending'), findsOneWidget);
  });
}
