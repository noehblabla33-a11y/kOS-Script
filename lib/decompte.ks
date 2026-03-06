// Decompte avant lancement

FUNCTION decompte {
    PARAMETER secondes IS 5.

    FROM {LOCAL i IS secondes.} UNTIL i = 0 STEP {SET i TO i - 1.} DO {
        PRINT "T-" + i + "   " AT (0, TERMINAL:HEIGHT - 1).
        bip(660, 0.1).
        WAIT 1.
    }

    PRINT "LANCEMENT!   " AT (0, TERMINAL:HEIGHT - 1).
    bipDouble().
}
