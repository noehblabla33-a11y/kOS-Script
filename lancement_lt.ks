// Lancement avec apoapsis tracking et circularisation
// Usage: RUN lancement_apo. ou RUN lancement_apo(90, 80000).

PARAMETER capLancement IS 90.
PARAMETER apoapseCible IS 80000.

RUNONCEPATH("0:/lib/bip.ks").
RUNONCEPATH("0:/lib/decompte.ks").
RUNONCEPATH("0:/lib/staging.ks").
RUNONCEPATH("0:/lib/nav.ks").

// Pitch prograde par rapport a l'horizon
FUNCTION pitchPrograde {
    RETURN 90 - VANG(SHIP:SRFPROGRADE:VECTOR, UP:VECTOR).
}

CLEARSCREEN.
PRINT "--- LANCEMENT APO ---" AT (0, 0).
PRINT "Cap: " + capLancement + " deg" AT (0, 1).
PRINT "Orbite cible: " + ROUND(apoapseCible / 1000) + " km" AT (0, 2).
PRINT "---" AT (0, 3).

// Preparation
SAS OFF.
RCS OFF.
LOCK THROTTLE TO 1.
LOCK STEERING TO HEADING(capLancement, 90).

// Decompte puis allumage
decompte(5).
STAGE.
demarrerAutoStaging().

// === PHASE 1: MONTEE VERTICALE ===
PRINT "Phase: verticale       " AT (0, 5).
WAIT UNTIL SHIP:AIRSPEED > 65.

// === PHASE 2: GRAVITY TURN ===
PRINT "Phase: gravity turn    " AT (0, 5).
LOCK STEERING TO HEADING(capLancement, 85).
bipOk().

LOCAL toleranceDeg IS 1.5.
WAIT UNTIL pitchPrograde() <= 85 + toleranceDeg.

// Suivi prograde surface dans l'atmosphere
PRINT "Phase: srf prograde    " AT (0, 5).
LOCK STEERING TO SHIP:SRFPROGRADE.
bipOk().

// Plein gaz jusqu'a sortie de l'atmosphere
UNTIL SHIP:ALTITUDE > 70000 {
    // Bascule orb prograde a 35 km
    IF SHIP:ALTITUDE > 35000 {
        LOCK STEERING TO SHIP:PROGRADE.
    }
    PRINT "Apo: " + ROUND(SHIP:APOAPSIS / 1000, 1) + " km   " AT (0, 7).
    PRINT "Alt: " + ROUND(SHIP:ALTITUDE / 1000, 1) + " km   " AT (0, 8).
    PRINT "Vit: " + ROUND(SHIP:AIRSPEED) + " m/s   " AT (0, 9).
    WAIT 0.2.
}

// === PHASE 3: APOAPSIS TRACKING ===
PRINT "Phase: apo tracking    " AT (0, 5).
LOCK STEERING TO SHIP:PROGRADE.
bipOk().

LOCAL etaCible IS 45.

UNTIL SHIP:APOAPSIS >= apoapseCible {
    // Throttle pour maintenir ETA:APOAPSIS autour de la cible
    LOCAL errEta IS ETA:APOAPSIS - etaCible.
    LOCAL throt IS 0.5 - errEta * 0.02.
    LOCK THROTTLE TO MAX(0.01, MIN(1, throt)).

    PRINT "Apo: " + ROUND(SHIP:APOAPSIS / 1000, 1) + " km   " AT (0, 7).
    PRINT "ETA apo: " + ROUND(ETA:APOAPSIS) + " s   " AT (0, 8).
    PRINT "Thr: " + ROUND(THROTTLE * 100) + " %   " AT (0, 9).
    WAIT 0.1.
}

// === PHASE 4: CIRCULARISATION ===
PRINT "Phase: circularisation " AT (0, 5).
bipOk().

LOCAL margeCirc IS apoapseCible * 0.02.

UNTIL SHIP:PERIAPSIS >= apoapseCible - margeCirc {
    // Throttle pour maintenir l'apo proche de la cible
    LOCAL errApo IS (SHIP:APOAPSIS - apoapseCible) / 1000.
    LOCAL throt IS 0.5 - errApo * 0.1.
    LOCK THROTTLE TO MAX(0.01, MIN(1, throt)).

    LOCK STEERING TO SHIP:PROGRADE.

    PRINT "Apo: " + ROUND(SHIP:APOAPSIS / 1000, 1) + " km   " AT (0, 7).
    PRINT "Per: " + ROUND(SHIP:PERIAPSIS / 1000, 1) + " km   " AT (0, 8).
    PRINT "Thr: " + ROUND(THROTTLE * 100) + " %   " AT (0, 9).
    PRINT "Vit: " + ROUND(SHIP:VELOCITY:ORBIT:MAG) + " m/s   " AT (0, 10).
    WAIT 0.1.
}

// === EN ORBITE ===
LOCK THROTTLE TO 0.
UNLOCK STEERING.
UNLOCK THROTTLE.
arreterAutoStaging().

bipDouble().
WAIT 0.5.
bipDouble().

PRINT "Orbite atteinte!                  " AT (0, 5).
PRINT "Apo: " + ROUND(SHIP:APOAPSIS / 1000, 1) + " km   " AT (0, 7).
PRINT "Per: " + ROUND(SHIP:PERIAPSIS / 1000, 1) + " km   " AT (0, 8).
PRINT "                              " AT (0, 9).
PRINT "                              " AT (0, 10).
