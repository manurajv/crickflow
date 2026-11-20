import 'package:crickflow/shared/widgets/announcement_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sanitize strips tags and javascript', () {
    expect(stripAnnouncementHtml('<script>alert(1)</script>Hello'), 'alert(1)Hello');
    expect(sanitizeAnnouncementText('<img src=x onerror=alert(1)>Safe'), 'Safe');
    expect(sanitizeAnnouncementText('javascript:alert(1) hi'), isNot(contains('javascript')));
  });

  test('safe hrefs', () {
    expect(isSafeAnnouncementHref('https://example.com'), isTrue);
    expect(isSafeAnnouncementHref('/series/abc'), isTrue);
    expect(isSafeAnnouncementHref('//evil.com'), isFalse);
    expect(isSafeAnnouncementHref('javascript:alert(1)'), isFalse);
    expect(isSafeAnnouncementHref('data:text/html,hi'), isFalse);
  });

  testWidgets('renders bold instead of raw asterisks', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AnnouncementBody(body: 'Hello **world**')),
      ),
    );
    expect(find.text('Hello **world**', findRichText: true), findsNothing);
    final rich = tester.widget<RichText>(find.byType(RichText).first);
    final text = rich.text.toPlainText();
    expect(text, contains('world'));
    expect(text, isNot(contains('**')));
  });
}
