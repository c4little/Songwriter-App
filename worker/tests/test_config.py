import config


def test_audio_limits_match_prd():
    assert config.MAX_AUDIO_SECONDS == 300
    assert config.SAMPLE_RATE_HZ == 44_100
    assert config.CHANNELS == 1


def test_section_rules_match_prd():
    assert config.INSTRUMENTAL_MIN_BARS == 2
    assert config.FINGERPICKED_MAX_SIMULTANEOUS_NOTES == 2
    assert config.FINGERPICKED_MIN_ONSET_SHARE == 0.60
