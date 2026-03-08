// Lancement low-thrust avec circularisation continue
// Une seule ignition du decollage a l'orbite circulaire.
// Compatible Kerbalism (throttle plancher, ignition unique).
// Usage: RUN lancement_lt. ou RUN lancement_lt(90, 80000, 45).

PARAMETER capLancement IS 90.
PARAMETER apoapseCible IS 80000.
PARAMETER etaCible IS 45.

RUNONCEPATH("0:/lib/bip.ks").
RUNONCEPATH("0:/lib/decompte.ks").
RUNONCEPATH("0:/lib/staging.ks").

// --- Constantes ---
LOCAL seuilVitesse IS 65.
LOCAL pitchDepart IS 80.
LOCAL pitchFinGuide IS 45.
LOCAL altFinGuide IS 10000.
LOCAL aoaMax IS 5.
LOCAL altTransOrb IS 35000.
LOCAL throttlePlancher IS 0.01.
LOCAL toleranceCirc IS 2000.

// --- Fonctions ---

FUNCTION pitchPrograde {
    RETURN 90 - VANG(SHIP:SRFPROGRADE:VECTOR, UP:VECTOR).
}

FUNCTION angleAttaque {
    RETURN VANG(SHIP:FACING:VECTOR, SHIP:SRFPROGRADE:VECTOR).
}

FUNCTION pitchGuide {
    LOCAL fraction IS MIN(1, MAX(0, SHIP:ALTITUDE / altFinGuide)).
    RETURN pitchDepart - (pitchDepart - pitchFinGuide) * fraction.
}

// --- Affichage ---
CLEARSCREEN.
PRINT "--- LANCEMENT LOW-THRUST ---" AT (0, 0).
PRINT "Cap: " + capLancement + " deg" AT (0, 1).
PRINT "Apo cible: " + ROUND(apoapseCible / 1000) + " km" AT (0, 2).
PRINT "ETA cible: " + etaCible + " s" AT (0, 3).

// --- Preparation ---
SAS OFF.
RCS OFF.
LOCAL poussee IS 1.
LOCK THROTTLE TO poussee.
LOCK STEERING TO HEADING(capLancement, 90).

// --- Decompte + allumage ---
decompte(5).
STAGE.
demarrerAutoStaging().

// === PHASE 1 : montee verticale ===
PRINT "Phase: verticale       " AT (0, 5).
WAIT UNTIL SHIP:AIRSPEED > seuilVitesse.

// === PHASE 2 : kick initial ===
PRINT "Phase: kick            " AT (0, 5).
LOCK STEERING TO HEADING(capLancement, pitchDepart).
bipOk().

WAIT UNTIL pitchPrograde() <= pitchDepart + 1.5.

// === PHASE 3 : pitch guide jusqu'a altFinGuide ===
PRINT "Phase: pitch guide     " AT (0, 5).
bipOk().

LOCAL enPrograde IS FALSE.

UNTIL SHIP:ALTITUDE >= altFinGuide {
    LOCAL pitchCmd IS pitchGuide().

    IF angleAttaque() > aoaMax {
        IF NOT enPrograde SET enPrograde TO TRUE.
        LOCK STEERING TO SHIP:SRFPROGRADE.
    } ELSE {
        IF enPrograde SET enPrograde TO FALSE.
        LOCK STEERING TO HEADING(capLancement, pitchCmd).
    }

    PRINT "Alt: " + ROUND(SHIP:ALTITUDE / 1000, 1) + " km   " AT (0, 7).
    PRINT "Pitch cmd: " + ROUND(pitchCmd, 1) + " deg   " AT (0, 8).
    PRINT "Pitch reel: " + ROUND(pitchPrograde(), 1) + " deg   " AT (0, 9).
    PRINT "AoA: " + ROUND(angleAttaque(), 1) + " deg   " AT (0, 10).
    WAIT 0.1.
}

// === PHASE 4 : suivi prograde surface ===
PRINT "Phase: srf prograde    " AT (0, 5).
LOCK STEERING TO SHIP:SRFPROGRADE.
bipOk().

// === PHASE 5 : plein gaz jusqu'a ETA:APOAPSIS proche de la cible ===
PRINT "Phase: accel pleine    " AT (0, 5).
SET poussee TO 1.

WAIT UNTIL ETA:APOAPSIS >= etaCible - 5.

// === PHASE 6 : croisiere PID throttle ===
PRINT "Phase: croisiere PID   " AT (0, 5).
bipOk().

LOCAL pidThrottle IS PIDLOOP(0.8, 0.4, 0.05, 0, 1).
SET pidThrottle:SETPOINT TO etaCible.

LOCAL transitionOrb IS FALSE.

UNTIL SHIP:APOAPSIS >= apoapseCible {
    IF NOT transitionOrb AND SHIP:ALTITUDE > altTransOrb {
        LOCK STEERING TO SHIP:PROGRADE.
        SET transitionOrb TO TRUE.
        PRINT "Phase: orb prograde PID" AT (0, 5).
        bipOk().
    }

    SET poussee TO pidThrottle:UPDATE(TIME:SECONDS, ETA:APOAPSIS).
    IF poussee < throttlePlancher SET poussee TO throttlePlancher.

    PRINT "Apo: " + ROUND(SHIP:APOAPSIS / 1000, 1) + " km   " AT (0, 7).
    PRINT "Alt: " + ROUND(SHIP:ALTITUDE / 1000, 1) + " km   " AT (0, 8).
    PRINT "Vit: " + ROUND(SHIP:AIRSPEED) + " m/s   " AT (0, 9).
    PRINT "ETA apo: " + ROUND(ETA:APOAPSIS, 1) + " s   " AT (0, 10).
    PRINT "Throttle: " + ROUND(poussee * 100) + " %   " AT (0, 11).
    WAIT 0.1.
}

// === PHASE 7 : circularisation continue ===
// Bruler fort pres de l'apo (monte le peri), rien loin (evite gonfler l'apo).
PRINT "Phase: circularisation " AT (0, 5).
bipOk().

LOCK STEERING TO SHIP:PROGRADE.

UNTIL SHIP:PERIAPSIS >= apoapseCible - toleranceCirc {
    // Modulation par position orbitale : cos = 1 a l'apo, 0 a 90 deg, -1 au peri
    LOCAL fractionOrb IS ETA:APOAPSIS / SHIP:ORBIT:PERIOD.
    LOCAL modulateur IS MAX(0.01, COS(fractionOrb * 360)).

    // Freiner si l'apo depasse la cible (1 km au-dessus -> correction de 20%)
    LOCAL erreurApo IS (SHIP:APOAPSIS - apoapseCible) / 1000.
    LOCAL correction IS MAX(0, 1 - erreurApo * 0.2).

    SET poussee TO modulateur * correction.

    PRINT "Apo: " + ROUND(SHIP:APOAPSIS / 1000, 1) + " km   " AT (0, 7).
    PRINT "Per: " + ROUND(SHIP:PERIAPSIS / 1000, 1) + " km   " AT (0, 8).
    PRINT "Alt: " + ROUND(SHIP:ALTITUDE / 1000, 1) + " km   " AT (0, 9).
    PRINT "Ecc: " + ROUND(SHIP:ORBIT:ECCENTRICITY, 4) AT (0, 10).
    PRINT "Throttle: " + ROUND(poussee * 100) + " %   " AT (0, 11).
    PRINT "ETA apo: " + ROUND(ETA:APOAPSIS) + " s   " AT (0, 12).
    WAIT 0.1.
}

// === COUPURE ===
LOCK THROTTLE TO 0.
UNLOCK STEERING.
UNLOCK THROTTLE.
arreterAutoStaging().

bipDouble().
WAIT 0.5.
bipDouble().

PRINT "Orbite circulaire!" AT (0, 13).
PRINT "Apo: " + ROUND(SHIP:APOAPSIS / 1000, 1) + " km" AT (0, 14).
PRINT "Per: " + ROUND(SHIP:PERIAPSIS / 1000, 1) + " km" AT (0, 15).
