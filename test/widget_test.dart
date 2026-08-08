// Widget smoke tests for a core, self-contained design-system widget.
// (The old default 'counter' test was a stale `flutter create` stub that pumped
// the whole Firebase/provider-backed app and could never pass.)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elefit_app/widgets/ef_components.dart';

void main() {
  testWidgets('EFButton renders its label and fires onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(child: EFButton(label: 'Continue', onTap: () => taps++)),
      ),
    ));

    expect(find.byType(EFButton), findsOneWidget);
    expect(find.text('CONTINUE'), findsOneWidget); // EFButton upper-cases the label

    await tester.tap(find.byType(EFButton));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('EFButton with a null onTap does not crash when tapped',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(child: EFButton(label: 'Disabled', onTap: null)),
      ),
    ));

    expect(find.byType(EFButton), findsOneWidget);
    await tester.tap(find.byType(EFButton), warnIfMissed: false);
    await tester.pump(); // no exception = pass
  });
}
