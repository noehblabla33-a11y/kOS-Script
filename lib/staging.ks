// Auto-staging : detecte flameout moteurs et SRB

GLOBAL stagingActif IS FALSE.

FUNCTION moteurEnFlameout {
    LIST ENGINES IN listeMoteurs.
    FOR m IN listeMoteurs {
        IF m:FLAMEOUT RETURN TRUE.
    }
    RETURN FALSE.
}

FUNCTION demarrerAutoStaging {
    SET stagingActif TO TRUE.

    WHEN stagingActif AND (MAXTHRUST < 0.1 OR moteurEnFlameout()) AND THROTTLE > 0 THEN {
        WAIT 0.3.
        // Double verification avant separation
        IF MAXTHRUST < 0.1 OR moteurEnFlameout() {
            STAGE.
            bip(550, 0.1).
            WAIT 0.5.
        }
        IF stagingActif PRESERVE.
    }
}

FUNCTION arreterAutoStaging {
    SET stagingActif TO FALSE.
}
