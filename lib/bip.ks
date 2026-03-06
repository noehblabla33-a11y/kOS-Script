// Systeme de bip sonore

FUNCTION bip {
    PARAMETER frequence IS 440.
    PARAMETER duree IS 0.15.
    LOCAL voix IS GETVOICE(0).
    SET voix:VOLUME TO 0.3.
    voix:PLAY(NOTE(frequence, duree)).
}

FUNCTION bipOk {
    bip(880, 0.1).
}

FUNCTION bipErreur {
    bip(220, 0.3).
}

FUNCTION bipDouble {
    bip(880, 0.08).
    WAIT 0.12.
    bip(880, 0.08).
}
