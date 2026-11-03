import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/features/exercise/domain/reps.dart';

void main() {
  test('a plain number has no label', () {
    expect(parseReps('12'), (12, null));
  });

  test('a range keeps its text and prefills the top value', () {
    expect(parseReps('6-8'), (8, '6-8'));
    expect(parseReps('12 y 15'), (15, '12 y 15'));
  });

  test('text without numbers prefills zero', () {
    expect(parseReps('Las que salgan'), (0, 'Las que salgan'));
  });

  test('blank is rejected', () {
    expect(parseReps('  '), isNull);
  });
}
