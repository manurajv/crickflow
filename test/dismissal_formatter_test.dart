import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/domain/services/commentary_service.dart';
import 'package:crickflow/domain/services/dismissal_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DismissalFormatter', () {
    test('formats professional dismissal text', () {
      expect(
        DismissalFormatter.format(
          type: WicketType.bowled,
          bowlerName: 'Fernando',
        ),
        'b Fernando',
      );
      expect(
        DismissalFormatter.format(
          type: WicketType.caught,
          fielderName: 'John Silva',
          bowlerName: 'Fernando',
        ),
        'c John Silva b Fernando',
      );
      expect(
        DismissalFormatter.format(
          type: WicketType.lbw,
          bowlerName: 'Fernando',
        ),
        'lbw b Fernando',
      );
      expect(
        DismissalFormatter.format(
          type: WicketType.runOut,
          fielderName: 'Kasun Perera',
        ),
        'run out (Kasun Perera)',
      );
      expect(
        DismissalFormatter.format(
          type: WicketType.stumped,
          fielderName: 'Ravi',
          bowlerName: 'Fernando',
        ),
        'st Ravi b Fernando',
      );
      expect(
        DismissalFormatter.format(type: WicketType.retiredHurt),
        'retired hurt',
      );
    });

    test('commentary for caught run out and stumped', () {
      expect(
        CommentaryService.forWicket(
          wicketType: WicketType.caught,
          fielderName: 'John Silva',
          bowlerName: 'Fernando',
        ),
        'Caught by John Silva! Fernando gets the wicket.',
      );
      expect(
        CommentaryService.forWicket(
          wicketType: WicketType.runOut,
          fielderName: 'Kasun Perera',
        ),
        'Excellent run out by Kasun Perera.',
      );
      expect(
        CommentaryService.forWicket(
          wicketType: WicketType.stumped,
          fielderName: 'Ravi',
        ),
        'Sharp work behind the stumps from Ravi.',
      );
    });

    test('run out needs dismissed batter picker not striker default', () {
      expect(DismissalFormatter.needsDismissedBatterPicker(WicketType.runOut), isTrue);
      expect(DismissalFormatter.needsFielderPicker(WicketType.runOut), isFalse);
      expect(
        DismissalFormatter.defaultDismissedPlayerId(
          type: WicketType.caught,
          strikerId: 's1',
        ),
        's1',
      );
    });
  });
}
