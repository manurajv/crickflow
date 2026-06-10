import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/ball_event_model.dart';
import 'package:crickflow/data/models/dismissal_fielder.dart';
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
          type: WicketType.caught,
          bowlerName: 'Fernando',
        ),
        'b Fernando',
      );
      expect(
        DismissalFormatter.format(
          type: WicketType.runOut,
          bowlerName: 'Fernando',
        ),
        'run out',
      );
      expect(
        DismissalFormatter.fromWicketEvent(
          BallEventModel(
            id: 'e1',
            matchId: 'm1',
            inningsNumber: 1,
            overNumber: 0,
            ballInOver: 1,
            eventType: BallEventType.wicket,
            runs: 0,
            batsmanRuns: 0,
            extraRuns: 0,
            isLegalDelivery: true,
            isFreeHit: false,
            isWicket: true,
            wicketType: WicketType.caught,
            dismissedPlayerId: 'b1',
            fielderId: 'f1',
            fielders: const [
              DismissalFielder(playerId: 'f1', playerName: 'John Silva'),
            ],
            bowlerId: 'bowl1',
            bowlerName: 'Fernando',
            dismissalText: 'c & b Fernando',
            sequence: 1,
          ),
        ),
        'c John Silva b Fernando',
      );
      expect(
        DismissalFormatter.format(
          type: WicketType.caughtAndBowled,
          bowlerName: 'Fernando',
        ),
        'c & b Fernando',
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
          bowlerName: 'Fernando',
        ),
        'run out Kasun Perera',
      );
      expect(
        DismissalFormatter.format(
          type: WicketType.runOut,
          fielderName: 'Shivam Chowdhry',
          secondaryFielderName: 'Himanshu',
        ),
        'run out Shivam Chowdhry / Himanshu',
      );
      expect(
        DismissalFormatter.format(
          type: WicketType.stumped,
          fielderName: 'Ravi',
          bowlerName: 'Fernando',
        ),
        'st b Fernando',
      );
      expect(
        DismissalFormatter.format(type: WicketType.retiredHurt),
        'retired hurt',
      );
      expect(
        DismissalFormatter.format(
          type: WicketType.mankad,
          bowlerName: 'Ashok Rawat',
        ),
        'run out Ashok Rawat',
      );
      expect(DismissalFormatter.creditsBowlerWicket(WicketType.bowled), isTrue);
      expect(DismissalFormatter.creditsBowlerWicket(WicketType.runOut), isFalse);
      expect(
        DismissalFormatter.creditsBowlerWicket(WicketType.runOut, isMankad: true),
        isFalse,
      );
      expect(DismissalFormatter.creditsBowlerWicket(WicketType.retiredOut), isFalse);
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
