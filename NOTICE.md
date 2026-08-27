# What this repo does and does not contain

This is a clone of [Klack](https://tryklack.com) written from measurements. It
is an independent reimplementation and a study in measured UI reproduction. It
is **not affiliated with, authorised by, or endorsed by** Klack or its authors,
and "Klack" is their name, not mine.

## Not included, on purpose

- **Klack's sound library.** Their FAQ describes each switch set as "over 100
  audio files that need to be recorded and mastered individually", and the
  site's per-switch preview buttons play that same library. Recording those
  would be taking the product rather than cloning it. Every sound here comes
  from a CC0 recording of a real mechanical keyboard, sliced by
  `tools/slice-switches.py`, with each licence verified on the sound's own page.
  See [`assets/switches/CREDITS.md`](assets/switches/CREDITS.md).
- **Klack's app icon and artwork.** The mark in `assets/logo/` is original —
  see the rationale at the top of `tools/make-icon.py`.
- **Reference material.** The captures this clone was measured against — the
  tryklack.com site bundle, App Store screenshots, press images and YouTube
  review video — are third-party copyright. They are gitignored and stay local.
  `assets/wallpaper.jpg` came from `cdn.tryklack.com` and is excluded too; the
  demo backdrop falls back to a solid fill without it.
- **Any Klack code.** None was available and none was used. Every pixel is
  drawn by `app/Sources/`.

## Names

The app bundle identifies itself as "Klack" because reproducing the interface
faithfully is the point of the exercise, and the interface says Klack. The
bundle identifier is `com.clone.klack`. If you plan to distribute a build to
anyone, rename it first.
