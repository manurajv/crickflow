import 'package:crickflow/core/theme/app_theme.dart';
import 'package:crickflow/data/models/series/series.dart';
import 'package:crickflow/features/series/presentation/widgets/series_registration_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('locked identity fields are prefilled and not editable',
      (tester) async {
    final fullName = TextEditingController(text: 'Real Player');
    final playerId = TextEditingController(text: 'CF-1001');
    final phone = TextEditingController();
    final address = TextEditingController();
    final nationalId = TextEditingController();
    final passport = TextEditingController();
    addTearDown(() {
      fullName.dispose();
      playerId.dispose();
      phone.dispose();
      address.dispose();
      nationalId.dispose();
      passport.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: SeriesRegistrationFields(
                settings: const SeriesSettingsModel(),
                seriesId: 's1',
                lockIdentity: true,
                fullName: fullName,
                playerId: playerId,
                phone: phone,
                address: address,
                nationalId: nationalId,
                passport: passport,
                dob: null,
                onDobChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    TextField field(Key key) => tester.widget<TextField>(
          find.descendant(
            of: find.byKey(key),
            matching: find.byType(TextField),
          ),
        );
    final nameField = field(const Key('org_registration_full_name'));
    final idField = field(const Key('org_registration_player_id'));
    expect(nameField.controller!.text, 'Real Player');
    expect(idField.controller!.text, 'CF-1001');
    expect(nameField.readOnly, isTrue);
    expect(idField.readOnly, isTrue);
    expect(find.byIcon(Icons.lock_outline), findsNWidgets(2));

    await tester.enterText(
      find.byKey(const Key('org_registration_full_name')),
      'Hacker Alias',
    );
    await tester.enterText(
      find.byKey(const Key('org_registration_player_id')),
      'FAKE-999',
    );
    await tester.pump();
    expect(fullName.text, 'Real Player');
    expect(playerId.text, 'CF-1001');
  });
}
