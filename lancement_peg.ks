// Lancement avec Powered Explicit Guidance (PEG)
// Guidage atmospherique par pitch programme, puis guidage terminal PEG
// pour injection orbitale optimale.
//
// Compatible Kerbalism : pas de coupure moteur inutile, throttle plancher.
//
// Phases :
//   1. Verticale        (0 -> seuilVit m/s)
//   2. Kick initial     (pitch a pitchKick)
//   3. Guidage atmo     (pitch interpole avec garde-fou AoA, -> altPeg)
//   4. PEG actif        (guidage terminal vers orbite cible)
//   5. MECO
//
// Usage: RUN lancement_peg.
//        RUN lancement_peg(90, 80000).
//        RUN lancement_peg(90, 120000, 30000).

PARAMETER capLancement IS 90.
PARAMETER apoapseCible IS 80000.
PARAMETER altPeg IS 35000.

RUNONCEPATH("0:/lib/bip.ks").
RUNONCEPATH("0:/lib/decompte.ks").
RUNONCEPATH("0:/lib/staging.ks").
RUNONCEPATH("0:/lib/peg.ks").

// === CONSTANTES ===
LOCAL seuilVit IS 65.
LOCAL pitchKick IS 80.
LOCAL pitchFin IS 25.
LOCAL aoaMax IS 5.
LOCAL altTransOrb IS 35000.
LOCAL throttlePlancher IS 0.10.
LOCAL periodeCyclePeg IS 1.
LOCAL periodeCycleFinPeg IS 0.2.
LOCAL seuilTgoFin IS 8.
LOCAL seuilTgoMeco IS 0.3.
LOCAL maxCyclesNonConv IS 30.

// === FONCTIONS ATMOSPHERIQUES ===

FUNCTION pitchPrograde {
    RETURN 90 - VANG(SHIP:SRFPROGRADE:VECTOR, UP:VECTOR).
}

FUNCTION aoa {
    RETURN VANG(SHIP:FACING:VECTOR, SHIP:SRFPROGRADE:VECTOR).
}

FUNCTION pitchAtmo {
    LOCAL frac IS MIN(1, MAX(0, SHIP:ALTITUDE / altPeg)).
    RETURN pitchKick - (pitchKick - pitchFin) * frac.
}

// === CIBLES PEG ===
LOCAL rayonCible IS BODY:RADIUS + apoapseCible.
LOCAL vitTanCible IS SQRT(BODY:MU / rayonCible).

// === AFFICHAGE ===
CLEARSCREEN.
PRINT "--- LANCEMENT PEG ---" AT (0, 0).
PRINT "Cap: " + capLancement + " deg" AT (0, 1).
PRINT "Apo cible: " + ROUND(apoapseCible / 1000) + " km" AT (0, 2).
PRINT "PEG a: " + ROUND(altPeg / 1000) + " km" AT (0, 3).
PRINT "V circ: " + ROUND(vitTanCible) + " m/s" AT (0, 4).
PRINT "---" AT (0, 5).

// === PREPARATION ===
SAS OFF.
RCS OFF.
LOCAL poussee IS 1.
LOCK THROTTLE TO poussee.
LOCK STEERING TO HEADING(capLancement, 90).

// === DECOMPTE + ALLUMAGE ===
decompte(5).
STAGE.
demarrerAutoStaging().

// =====================================================================
// PHASE 1 : MONTEE VERTICALE
// =====================================================================
PRINT "Phase: verticale       " AT (0, 7).
WAIT UNTIL SHIP:AIRSPEED > seuilVit.

// =====================================================================
// PHASE 2 : KICK INITIAL
// =====================================================================
PRINT "Phase: kick            " AT (0, 7).
LOCK STEERING TO HEADING(capLancement, pitchKick).
bipOk().
WAIT UNTIL pitchPrograde() <= pitchKick + 1.5.

// =====================================================================
// PHASE 3 : GUIDAGE ATMOSPHERIQUE
// =====================================================================
PRINT "Phase: guidage atmo    " AT (0, 7).
bipOk().

LOCAL enSuiviProg IS FALSE.

UNTIL SHIP:ALTITUDE >= altPeg {
    LOCAL pCmd IS pitchAtmo().
    IF aoa() > aoaMax {
        IF NOT enSuiviProg SET enSuiviProg TO TRUE.
        LOCK STEERING TO SHIP:SRFPROGRADE.
    } ELSE {
        IF enSuiviProg SET enSuiviProg TO FALSE.
        LOCK STEERING TO HEADING(capLancement, pCmd).
    }
    PRINT "Alt: " + ROUND(SHIP:ALTITUDE / 1000, 1) + " km   " AT (0, 9).
    PRINT "Pitch: " + ROUND(pitchPrograde(), 1) + " / "
        + ROUND(pCmd, 1) + " deg   " AT (0, 10).
    PRINT "AoA: " + ROUND(aoa(), 1) + " deg   " AT (0, 11).
    WAIT 0.1.
}

// =====================================================================
// PHASE 4 : PEG ACTIF
// =====================================================================
PRINT "Phase: PEG actif       " AT (0, 7).
bipOk().

reinitPeg().

LOCAL pousseePrec IS MAXTHRUST.
LOCAL dernierCycle IS 0.
LOCAL cyclesNonConv IS 0.
LOCAL repliPrograde IS FALSE.
LOCAL raisonMeco IS "".

UNTIL FALSE {
    // --- Detection staging : reinit DOUCE ---
    IF ABS(MAXTHRUST - pousseePrec) > 0.5 {
        reinitPegDoux().
        SET pousseePrec TO MAXTHRUST.
        SET cyclesNonConv TO 0.
        SET repliPrograde TO FALSE.
        PRINT "PEG: reinit (staging)  " AT (0, 7).
    }

    // --- Garde-fou : depassement orbital ---
    IF pegDepassement(vitTanCible) {
        SET raisonMeco TO "depassement".
        BREAK.
    }

    // --- Frequence de mise a jour PEG ---
    LOCAL periodeActuelle IS periodeCyclePeg.
    IF pegConverge AND tgoEstime() < seuilTgoFin {
        SET periodeActuelle TO periodeCycleFinPeg.
    }

    IF TIME:SECONDS - dernierCycle >= periodeActuelle {
        LOCAL conv IS cyclePeg(rayonCible, 0, vitTanCible).
        SET dernierCycle TO TIME:SECONDS.

        IF conv {
            SET cyclesNonConv TO 0.
            IF repliPrograde {
                SET repliPrograde TO FALSE.
                PRINT "Phase: PEG reconverge  " AT (0, 7).
                bipOk().
            }
        } ELSE {
            SET cyclesNonConv TO cyclesNonConv + 1.
            IF cyclesNonConv > maxCyclesNonConv AND NOT repliPrograde {
                SET repliPrograde TO TRUE.
                PRINT "Phase: repli prograde  " AT (0, 7).
                bipErreur().
            }
        }
    }

    // --- Pilotage ---
    IF pegConverge AND NOT repliPrograde {
        LOCK STEERING TO LOOKDIRUP(dirPeg(), SHIP:FACING:TOPVECTOR).
    } ELSE {
        IF SHIP:ALTITUDE > altTransOrb {
            LOCK STEERING TO SHIP:PROGRADE.
        } ELSE {
            LOCK STEERING TO SHIP:SRFPROGRADE.
        }
    }

    // --- Throttle ---
    LOCAL _tgo IS tgoEstime().
    IF pegConverge AND _tgo < 5 AND _tgo > 0 {
        SET poussee TO MAX(throttlePlancher, _tgo / 5).
    } ELSE {
        SET poussee TO 1.
    }

    // --- Telemetrie ---
    PRINT "Apo: " + ROUND(SHIP:APOAPSIS / 1000, 1) + " km   " AT (0, 9).
    PRINT "Per: " + ROUND(SHIP:PERIAPSIS / 1000, 1) + " km   " AT (0, 10).
    PRINT "Alt: " + ROUND(SHIP:ALTITUDE / 1000, 1) + " km   " AT (0, 11).
    PRINT "Vit: " + ROUND(SHIP:VELOCITY:ORBIT:MAG) + " m/s   " AT (0, 12).
    LOCAL convTxt IS "NON".
    IF pegConverge SET convTxt TO "OUI".
    PRINT "Tgo: " + ROUND(MAX(0, _tgo), 1) + " s  Conv: "
        + convTxt + "   " AT (0, 13).
    PRINT "A: " + ROUND(pegCoefA, 4)
        + "  B: " + ROUND(pegCoefB, 5) + "     " AT (0, 14).

    // --- CONDITIONS MECO ---

    // PEG converge et temps ecoule
    IF pegConverge AND _tgo <= seuilTgoMeco {
        SET raisonMeco TO "PEG nominal".
        BREAK.
    }

    // Securite : orbite circulaire atteinte
    IF SHIP:APOAPSIS >= apoapseCible * 0.98
       AND SHIP:PERIAPSIS >= apoapseCible * 0.95
       AND SHIP:APOAPSIS > 0 {
        SET raisonMeco TO "orbite atteinte".
        BREAK.
    }

    // Securite repli : apoapsis depassee
    IF repliPrograde AND SHIP:APOAPSIS >= apoapseCible AND SHIP:APOAPSIS > 0 {
        SET raisonMeco TO "apo atteinte (repli)".
        BREAK.
    }

    WAIT 0.05.
}

// =====================================================================
// PHASE 5 : MECO
// =====================================================================
SET poussee TO 0.
LOCK THROTTLE TO 0.
UNLOCK STEERING.
UNLOCK THROTTLE.
arreterAutoStaging().

bipDouble().
PRINT "---" AT (0, 16).
PRINT "MECO: " + raisonMeco AT (0, 17).
PRINT "Apo: " + ROUND(SHIP:APOAPSIS / 1000, 1) + " km" AT (0, 18).
PRINT "Per: " + ROUND(SHIP:PERIAPSIS / 1000, 1) + " km" AT (0, 19).
PRINT "Ecc: " + ROUND(SHIP:ORBIT:ECCENTRICITY, 4) AT (0, 20).

IF raisonMeco = "depassement" {
    bipErreur().
    PRINT "ALERTE: depassement orbital!" AT (0, 22).
    PRINT "Trop de dv pour cette orbite." AT (0, 23).
} ELSE IF SHIP:PERIAPSIS >= apoapseCible * 0.92 AND SHIP:APOAPSIS > 0 {
    bipDouble().
    PRINT "Orbite quasi-circulaire!" AT (0, 22).
} ELSE IF SHIP:PERIAPSIS > 0 AND SHIP:APOAPSIS > 0 {
    PRINT "Attente circularisation a l'apo." AT (0, 22).
} ELSE {
    bipErreur().
    PRINT "Trajectoire anormale." AT (0, 22).
}
