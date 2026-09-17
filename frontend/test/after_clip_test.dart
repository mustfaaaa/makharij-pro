import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/after_clip.dart';

/// FR-18's playback modes.
///
/// The cycle order is the whole of what the button does, and it is the kind of
/// three-line switch that gets reordered by accident during an unrelated edit.
/// The default matters just as much: a player that starts in a mode where it
/// keeps going on its own would surprise someone who only wanted to hear one
/// ayah.
void main() {
  group('AfterClip', () {
    test('starts at stop, so the player never runs on unasked', () {
      expect(AfterClip.values.first, AfterClip.stop);
      expect(AfterClip.stop.advances, isFalse);
      expect(AfterClip.stop.loops, isFalse);
    });

    test('one tap plays on, two taps loop, three taps stop', () {
      expect(AfterClip.stop.next, AfterClip.continueOn);
      expect(AfterClip.stop.next.next, AfterClip.repeatOne);
      expect(AfterClip.stop.next.next.next, AfterClip.stop);
    });

    test('the cycle returns to where it started from every mode', () {
      for (final mode in AfterClip.values) {
        expect(mode.next.next.next, mode, reason: 'starting from $mode');
      }
    });

    test('the cycle visits every mode', () {
      final visited = <AfterClip>{};
      var mode = AfterClip.stop;
      for (var i = 0; i < AfterClip.values.length; i++) {
        visited.add(mode);
        mode = mode.next;
      }
      expect(visited, AfterClip.values.toSet());
    });

    test('exactly one mode advances and exactly one loops', () {
      expect(AfterClip.values.where((m) => m.advances), [AfterClip.continueOn]);
      expect(AfterClip.values.where((m) => m.loops), [AfterClip.repeatOne]);
    });

    test('no mode both advances and loops', () {
      for (final mode in AfterClip.values) {
        expect(mode.advances && mode.loops, isFalse, reason: '$mode');
      }
    });
  });
}
