# Switch sound provenance

**These are not Klack's samples.** Klack's switch sets are the paid product —
their FAQ describes each set as "over 100 audio files that need to be recorded
and mastered individually". The site's per-switch preview buttons play that
same library, so recording those would be taking the product rather than
cloning it. Nothing here comes from tryklack.com.

Every sound the clone plays comes from a **CC0 (public domain)** recording of a
real mechanical keyboard uploaded to Freesound, sliced into individual down-
and up-strokes by `tools/slice-switches.py`. The licence on each was verified
by reading it off the sound's own page, not taken from a search filter.

The mapping onto Klack's switch names is **nominal**: each recording was chosen
because its character (clicky / linear / thocky) is the nearest available match.
It is not a recording of that switch.

| Klack name | actually recorded | source | licence |
|---|---|---|---|
| Japanese Black | Corsair K95, Cherry MX Red (linear) | [freesound #499773 by handygaber](https://freesound.org/people/handygaber/sounds/499773/) | CC0 1.0 (public domain) |
| Crystal Purple | Pok3r, Cherry MX Blue (clicky) | [freesound #400699 by jameslovescode](https://freesound.org/people/jameslovescode/sounds/400699/) | CC0 1.0 (public domain) |
| Oreo | Glorious Panda (tactile, thocky) | [freesound #581070 by quasifandango](https://freesound.org/people/quasifandango/sounds/581070/) | CC0 1.0 (public domain) |
| Cardboard | Cherry MX Brown (tactile) | [freesound #400167 by majod](https://freesound.org/people/majod/sounds/400167/) | CC0 1.0 (public domain) |
| Milky Yellow | Keychron K7 Pro, Gateron Brown | [freesound #833612 by bangcorrupt](https://freesound.org/people/bangcorrupt/sounds/833612/) | CC0 1.0 (public domain) |
| Super Red | Ducky X Varmilo, brown switches | [freesound #757638 by eclectic-kitty](https://freesound.org/people/eclectic-kitty/sounds/757638/) | CC0 1.0 (public domain) |
| Cream | Thermaltake Poseidon Z, Cherry MX Blue | [freesound #269713 by seth-m](https://freesound.org/people/seth-m/sounds/269713/) | CC0 1.0 (public domain) |

## Extraction

1. Public preview MP3 (160-236 kbps) fetched from Freesound; originals are login-gated.
2. Decoded to 48 kHz mono.
3. Onset detection on a 2 ms RMS envelope; a down-stroke is paired with the
   quieter onset 40-150 ms after it, which is its release.
4. **Isolation filter.** A first pass took the ten loudest strokes per switch and
   shipped them; measurement then showed **16 of 70** slices had a neighbouring
   keystroke inside the window — roughly a quarter of the library played as a
   double-tap. Candidates are now required to have silence before them, each
   window is **sized to the gap actually available** rather than fixed at 95 ms,
   and any slice that still contains a second transient is discarded. Result:
   **0 of 70**, with a full ten variants per direction retained.
5. Each set is loudness-matched to a common RMS target. Peak-normalising each
   slice instead left the sets 2.4x apart and clipped the mix on overlap.

## Sources changed after measurement

**Super Red** was first taken from a WhiteFox / Hako Violet recording
(freesound #546167). Once the set was loudness-matched its slices carried a
**-14.7 dB** noise floor — audible hiss. Swapped for the Ducky X Varmilo
recording, which measures **-31.3 dB**. Every set now sits between -24 and
-41 dB.

## The ding

The return-key ding is synthesised (a two-partial bell) rather than sourced. It
is a UI sound rather than a switch.
