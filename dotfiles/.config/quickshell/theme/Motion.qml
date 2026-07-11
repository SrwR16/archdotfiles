pragma Singleton
import QtQuick

// Central motion language for the shell. Every panel and animation should pull
// its durations / easings from here so the whole UI feels like one coherent
// system instead of a pile of mismatched timings.
//
// Design notes (from researching Apple's Dynamic Island + Material motion):
//  - Expansion / morph: a gentle spring-like overshoot reads as "alive" but
//    must never jump. OutBack gives a subtle 1-2px overshoot without risking
//    layout breakage the way a true SpringAnimation can on fixed-size panels.
//  - Content swaps: crossfade, never hard cut. New content fades+slides in
//    ~40ms after the old fades out so they never overlap as solid blocks.
//  - Micro-interactions (hover, toggle): fast (120-180ms) so the UI feels
//    instant. Press feedback should be near-immediate.
QtObject {
  // --- Durations (ms) ---
  readonly property int durInstant: 90
  readonly property int durXS:      130
  readonly property int durS:       190
  readonly property int durM:       280
  readonly property int durL:       380
  readonly property int durXL:      520

  // --- Easings ---
  // Standard "settle" curve for most morphs / fades.
  readonly property int easeStandard: Easing.OutCubic
  // Slightly springy overshoot for the island morph + pop-ins.
  readonly property int easeEmphatic: Easing.OutBack
  // For things that should accelerate in (lists collapsing, panels closing).
  readonly property int easeDecelerate: Easing.InOutCubic
  // iOS-flavoured quart for the big island reshape.
  readonly property int easeIsland: Easing.OutQuart

  // --- Spring preset (for Behaviour on width/height of the island) ---
  // Tuned so the panel springs to size without violent overshoot.
  readonly property real springStiffness: 260
  readonly property real springDamping:   26
  readonly property real springMass:      1.0
  readonly property real springEpsilon:   0.5

  // --- Content crossfade offset (ms) ---
  // New content begins entering this long after old content starts leaving.
  readonly property int stagger: 50

  // Convenience: a reusable "pop in" scale used by cards/buttons on appear.
  readonly property real popScale: 0.96
}
