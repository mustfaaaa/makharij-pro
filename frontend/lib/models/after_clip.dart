/// What the Qari player does when a clip reaches its end (FR-18).
///
/// The replay button restarts a clip once. Neither of the two things people
/// actually do while memorising was possible before this: hearing one ayah
/// over and over without touching the phone, and hearing the passage run on
/// from where it is. Both are how a student uses a reciter, so both are modes
/// the player holds rather than buttons they keep pressing.
///
/// Its own file because the cycle order is user-visible -- it is what the
/// button does on each tap -- and a three-line enum buried in a screen is
/// exactly the kind of thing that gets reordered by accident.
enum AfterClip {
  /// Stop at the end of this clip. The default: the player does not decide to
  /// keep going on its own.
  stop,

  /// Play on through the rest of the passage, then stop. Never wraps back to
  /// the first ayah -- that would be the app starting the surah again by
  /// itself.
  continueOn,

  /// Play this one ayah over and over. The memorisation loop.
  repeatOne;

  /// The next mode on a tap. Ordered by how much the player is being asked to
  /// do, so one tap gets you the common case (play on) and two the intensive
  /// one (loop) -- rather than the other way round.
  AfterClip get next => switch (this) {
        AfterClip.stop => AfterClip.continueOn,
        AfterClip.continueOn => AfterClip.repeatOne,
        AfterClip.repeatOne => AfterClip.stop,
      };

  /// Whether the player advances past this clip when it ends.
  bool get advances => this == AfterClip.continueOn;

  /// Whether it plays the same clip again.
  bool get loops => this == AfterClip.repeatOne;
}
