"""Thresholds and model choices (PRD section 14: nothing inline elsewhere).

Values marked (eval) are compared in phase 1 and locked at the phase 2 decision gate.
"""

from typing import Final

# --- Audio limits (FR-3, FR-5, pipeline step 1) ---
MAX_AUDIO_SECONDS: Final = 5 * 60
SAMPLE_RATE_HZ: Final = 44_100
CHANNELS: Final = 1

# --- Model choices (eval) ---
SEPARATION_MODEL: Final = "htdemucs_6s"  # (eval) vs "htdemucs" 4-stem "other"
LYRICS_MODEL: Final = "whisperx-large-v3"
CHORD_MODEL: Final = "btc"  # (eval) vs "chordino"
NOTE_MODEL_GUITAR: Final = "basic-pitch"
NOTE_MODEL_PIANO: Final = "basic-pitch"  # (eval) vs piano-specific transcription model

# --- Section detection (PRD section 5; tuned in phase 1) ---
INSTRUMENTAL_MIN_BARS: Final = 2
INSTRUMENTAL_VOCAL_ENERGY_THRESHOLD: Final = 0.02  # placeholder, tuned in phase 1
FINGERPICKED_MAX_SIMULTANEOUS_NOTES: Final = 2
FINGERPICKED_MIN_ONSET_SHARE: Final = 0.60

# --- Alignment (PRD section 11, step 10) ---
ALIGN_MAX_OFFSET_BEATS: Final = 0.5

# --- Defaults ---
DEFAULT_TIME_SIGNATURE: Final = "4/4"
