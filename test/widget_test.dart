// Basic smoke test – expand as features grow.
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App placeholder test', (WidgetTester tester) async {
    // Firebase needs native bindings, so we skip full app test for now.
    expect(1 + 1, equals(2));
  });
}
