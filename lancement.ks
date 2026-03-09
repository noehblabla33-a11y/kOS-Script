// Lancement depuis Kerbin avec gravity turn
// Usage: RUN lancement. ou RUN lancement(90, 80000).

PARAMETER capLancement IS 90.
PARAMETER apoapseCible IS 80000.

RUNONCEPATH("0:/lib/bip.ks").
RUNONCEPATH("0:/lib/decompte.ks").
RUNONCEPATH("0:/lib/staging.ks").

// Pitch prograde par rapport a l'horizon
FUNCTION pitchPrograde {
    RETURN 90 - VANG(SHIP:SRFPROGRADE:VECTOR, UP:VECTOR).
}

CLEARSCREEN.
PRINT "--- LANCEMENT ---" AT (0, 0).
PRINT "Cap: " + capLancement + " deg" AT (0, 1).
PRINT "Apo cible: " + ROUND(apoapseCible / 1000) + " km" AT (0, 2).
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

// Montee verticale
PRINT "Phase: verticale" AT (0, 5).
WAIT UNTIL SHIP:AIRSPEED > 50.

// Gravity turn : pitch 85, cap vers direction choisie
PRINT "Phase: gravity turn    " AT (0, 5).
LOCK STEERING TO HEADING(capLancement, 85).
bipOk().

// Attente que le prograde s'aligne sur le pitch cible
LOCAL toleranceDeg IS 1.5.
WAIT UNTIL pitchPrograde() <= 85 + toleranceDeg.

// Suivi prograde surface
PRINT "Phase: srf prograde    " AT (0, 5).
LOCK STEERING TO SHIP:SRFPROGRADE.
bipOk().

LOCAL transitionOrb IS FALSE.

// Montee jusqu'a l'apoapsis cible
UNTIL SHIP:APOAPSIS >= apoapseCible {
    // Bascule vers prograde orbital a 35 km
    IF NOT transitionOrb AND SHIP:ALTITUDE > 35000 {
        LOCK STEERING TO SHIP:PROGRADE.
        SET transitionOrb TO TRUE.
        PRINT "Phase: orb prograde    " AT (0, 5).
        bipOk().
    }
    PRINT "Apo: " + ROUND(SHIP:APOAPSIS / 1000, 1) + " km   " AT (0, 7).
    PRINT "Alt: " + ROUND(SHIP:ALTITUDE / 1000, 1) + " km   " AT (0, 8).
    PRINT "Vit: " + ROUND(SHIP:AIRSPEED) + " m/s   " AT (0, 9).
    WAIT 0.2.
}

// Coupure moteur
LOCK THROTTLE TO 0.
UNLOCK STEERING.
UNLOCK THROTTLE.
arreterAutoStaging().

bipDouble().
PRINT "Apo atteinte: " + ROUND(SHIP:APOAPSIS / 1000, 1) + " km" AT (0, 11).
PRINT "En attente circularisation." AT (0, 13).
