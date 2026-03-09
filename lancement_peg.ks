// Lancement avec Powered Explicit Guidance (PEG)
// Gravity turn classique (kick + suivi prograde), puis phase de
// transition qui stabilise la trajectoire, puis guidage terminal
// PEG pour injection orbitale optimale.
//
// Compatible Kerbalism : throttle plancher, pas de coupure inutile.
//
// Phases :
//   1. Verticale        (0 -> 65 m/s)
//   2. Kick initial     (5 deg, puis suivi prograde)
//   3. Suivi prograde   (srf puis orbital a 35 km)
//   4. Transition       (prograde, throttle module sur apoapsis)
//   5. PEG actif        (guidage terminal vers orbite cible)
//   6. MECO
//
// Usage: RUN lancement_peg.
//        RUN lancement_peg(90, 80000).

PARAMETER capLancement IS 90.
PARAMETER apoapseCible IS 80000.

RUNONCEPATH("0:/lib/bip.ks").
RUNONCEPATH("0:/lib/decompte.ks").
RUNONCEPATH("0:/lib/staging.ks").
RUNONCEPATH("0:/lib/peg.ks").

// === CONSTANTES ===
LOCAL seuilVit IS 50.
LOCAL pitchKick IS 85.
LOCAL throttlePlancher IS 0.10.
LOCAL periodeCyclePeg IS 1.
LOCAL periodeCycleFinPeg IS 0.25.
LOCAL seuilTgoFin IS 8.
LOCAL seuilTgoMeco IS 0.3.

// === FONCTIONS ===

FUNCTION pitchPrograde {
    RETURN 90 - VANG(SHIP:SRFPROGRADE:VECTOR, UP:VECTOR).
}

// === CIBLES ===
LOCAL rayonCible IS BODY:RADIUS + apoapseCible.
LOCAL vitTanCible IS SQRT(BODY:MU / rayonCible).

// === AFFICHAGE ===
CLEARSCREEN.
PRINT "--- LANCEMENT PEG ---" AT (0, 0).
PRINT "Cap: " + capLancement + " deg" AT (0, 1).
PRINT "Apo cible: " + ROUND(apoapseCible / 1000) + " km" AT (0, 2).
PRINT "V circ: " + ROUND(vitTanCible) + " m/s" AT (0, 3).
PRINT "---" AT (0, 4).

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
PRINT "Phase: verticale       " AT (0, 6).
WAIT UNTIL SHIP:AIRSPEED > seuilVit.

// =====================================================================
// PHASE 2 : KICK INITIAL
// Inclinaison de 5 deg pour amorcer le gravity turn.
// =====================================================================
PRINT "Phase: kick            " AT (0, 6).
LOCK STEERING TO HEADING(capLancement, pitchKick).
bipOk().

// Attendre que le prograde rattrape le pitch commande
WAIT UNTIL pitchPrograde() <= pitchKick + 1.5.

// =====================================================================
// PHASE 3 : SUIVI PROGRADE
// On suit le prograde surface (AoA ~0) : la gravite fait tourner
// la trajectoire naturellement. Bascule vers prograde orbital
// au-dessus de 35 km.
// =====================================================================
PRINT "Phase: srf prograde    " AT (0, 6).
LOCK STEERING TO SHIP:SRFPROGRADE.
bipOk().

LOCAL transOrb IS FALSE.

UNTIL SHIP:ALTITUDE >= BODY:ATM:HEIGHT * 0.5 {
    // Bascule vers prograde orbital a 35 km
    IF NOT transOrb AND SHIP:ALTITUDE > 35000 {
        SET transOrb TO TRUE.
        LOCK STEERING TO SHIP:PROGRADE.
        PRINT "Phase: orb prograde    " AT (0, 6).
        bipOk().
    }
    PRINT "Alt: " + ROUND(SHIP:ALTITUDE / 1000, 1) + " km   " AT (0, 8).
    PRINT "Pitch: " + ROUND(pitchPrograde(), 1) + " deg   " AT (0, 9).
    PRINT "Apo: " + ROUND(SHIP:APOAPSIS / 1000, 1) + " km   " AT (0, 10).
    WAIT 0.1.
}

// =====================================================================
// PHASE 4 : TRANSITION
// La fusee suit le prograde orbital. Le throttle est module pour
// garder l'apoapsis pres de la cible sans la depasser.
// PEG ne s'engage que quand la trajectoire est quasi-horizontale.
// =====================================================================
PRINT "Phase: transition      " AT (0, 6).
bipOk().

LOCK STEERING TO SHIP:PROGRADE.

UNTIL pegEtatPret(apoapseCible) {

    // Throttle proportionnel : freiner en approchant de l'apo cible
    LOCAL ratioApo IS SHIP:APOAPSIS / apoapseCible.
    IF ratioApo > 1.0 {
        // Apo au-dessus de la cible : plancher
        SET poussee TO throttlePlancher.
    } ELSE IF ratioApo > 0.85 {
        // Proche de la cible : degressif
        SET poussee TO MAX(throttlePlancher,
            1 - (ratioApo - 0.85) / (1.0 - 0.85)).
    } ELSE {
        SET poussee TO 1.
    }

    // Securite : si l'apo depasse de beaucoup, couper
    IF SHIP:APOAPSIS > apoapseCible * 1.5 {
        SET poussee TO throttlePlancher.
    }

    // Securite : depassement orbital
    IF pegDepassement(vitTanCible) {
        BREAK.
    }

    PRINT "Apo: " + ROUND(SHIP:APOAPSIS / 1000, 1) + " km   " AT (0, 8).
    PRINT "Alt: " + ROUND(SHIP:ALTITUDE / 1000, 1) + " km   " AT (0, 9).
    PRINT "Vit: " + ROUND(SHIP:VELOCITY:ORBIT:MAG) + " m/s   " AT (0, 10).
    LOCAL etat IS etatPlanOrb().
    LOCAL ratioVr IS 0.
    IF etat["vitTan"] > 100 {
        SET ratioVr TO ABS(etat["vitRad"]) / etat["vitTan"].
    }
    PRINT "Vr/Vt: " + ROUND(ratioVr, 3) + "       " AT (0, 11).
    PRINT "Thr: " + ROUND(poussee * 100) + " %   " AT (0, 12).
    WAIT 0.1.
}

// Verif depassement avant PEG
IF pegDepassement(vitTanCible) {
    SET poussee TO 0.
    LOCK THROTTLE TO 0.
    UNLOCK STEERING.
    UNLOCK THROTTLE.
    arreterAutoStaging().
    bipErreur().
    PRINT "---" AT (0, 14).
    PRINT "ALERTE: depassement en transition!" AT (0, 15).
    PRINT "Fusee trop puissante pour PEG." AT (0, 16).
    PRINT "Apo: " + ROUND(SHIP:APOAPSIS / 1000, 1) + " km" AT (0, 17).
    // On ne fait pas de RETURN car c'est le script principal
    // L'utilisateur devra circulariser manuellement ou via circularisation.ks
}

// =====================================================================
// PHASE 5 : PEG ACTIF
// A ce stade, la trajectoire est quasi-horizontale et l'apoapsis
// est proche de la cible. PEG n'a qu'a affiner pour circulariser.
// =====================================================================
IF NOT pegDepassement(vitTanCible) {

PRINT "Phase: PEG actif       " AT (0, 6).
bipOk().

reinitPeg().
SET poussee TO 1.

LOCAL pousseePrec IS MAXTHRUST.
LOCAL dernierCycle IS 0.
LOCAL cyclesNonConv IS 0.
LOCAL repliPrograde IS FALSE.
LOCAL raisonMeco IS "".

UNTIL FALSE {
    // Detection staging
    IF ABS(MAXTHRUST - pousseePrec) > 0.5 {
        reinitPegDoux().
        SET pousseePrec TO MAXTHRUST.
        SET cyclesNonConv TO 0.
        PRINT "PEG: reinit (staging)  " AT (0, 6).
    }

    // Garde-fou depassement
    IF pegDepassement(vitTanCible) {
        SET raisonMeco TO "depassement".
        BREAK.
    }

    // Frequence de mise a jour PEG
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
                PRINT "Phase: PEG reconverge  " AT (0, 6).
                bipOk().
            }
        } ELSE {
            SET cyclesNonConv TO cyclesNonConv + 1.
            IF cyclesNonConv > 40 AND NOT repliPrograde {
                SET repliPrograde TO TRUE.
                PRINT "Phase: repli prograde  " AT (0, 6).
                bipErreur().
            }
        }
    }

    // Pilotage
    IF pegConverge AND NOT repliPrograde {
        LOCK STEERING TO LOOKDIRUP(dirPeg(), SHIP:FACING:TOPVECTOR).
    } ELSE {
        LOCK STEERING TO SHIP:PROGRADE.
    }

    // Throttle
    LOCAL _tgo IS tgoEstime().
    IF pegConverge AND _tgo < 5 AND _tgo > 0 {
        SET poussee TO MAX(throttlePlancher, _tgo / 5).
    } ELSE IF repliPrograde {
        // En repli, moduler le throttle sur l'apoapsis
        LOCAL ratioApo IS SHIP:APOAPSIS / apoapseCible.
        IF ratioApo > 1.0 {
            SET poussee TO throttlePlancher.
        } ELSE {
            SET poussee TO 1.
        }
    } ELSE {
        SET poussee TO 1.
    }

    // Telemetrie
    PRINT "Apo: " + ROUND(SHIP:APOAPSIS / 1000, 1) + " km   " AT (0, 8).
    PRINT "Per: " + ROUND(SHIP:PERIAPSIS / 1000, 1) + " km   " AT (0, 9).
    PRINT "Alt: " + ROUND(SHIP:ALTITUDE / 1000, 1) + " km   " AT (0, 10).
    PRINT "Vit: " + ROUND(SHIP:VELOCITY:ORBIT:MAG) + " m/s   " AT (0, 11).
    LOCAL convTxt IS "NON".
    IF pegConverge SET convTxt TO "OUI".
    PRINT "Tgo: " + ROUND(MAX(0, _tgo), 1) + " s  Conv: "
        + convTxt + "   " AT (0, 12).
    PRINT "A: " + ROUND(pegCoefA, 4)
        + "  B: " + ROUND(pegCoefB, 5) + "     " AT (0, 13).

    // Conditions MECO
    IF pegConverge AND _tgo <= seuilTgoMeco {
        SET raisonMeco TO "PEG nominal".
        BREAK.
    }

    IF SHIP:APOAPSIS > 0 AND SHIP:PERIAPSIS > 0
       AND SHIP:APOAPSIS >= apoapseCible * 0.97
       AND SHIP:PERIAPSIS >= apoapseCible * 0.93 {
        SET raisonMeco TO "orbite atteinte".
        BREAK.
    }

    IF repliPrograde AND SHIP:APOAPSIS >= apoapseCible AND SHIP:APOAPSIS > 0 {
        SET raisonMeco TO "apo atteinte (repli)".
        BREAK.
    }

    WAIT 0.05.
}

// =====================================================================
// PHASE 6 : MECO
// =====================================================================
SET poussee TO 0.
LOCK THROTTLE TO 0.
UNLOCK STEERING.
UNLOCK THROTTLE.
arreterAutoStaging().

bipDouble().
PRINT "---" AT (0, 15).
PRINT "MECO: " + raisonMeco AT (0, 16).
PRINT "Apo: " + ROUND(SHIP:APOAPSIS / 1000, 1) + " km" AT (0, 17).
PRINT "Per: " + ROUND(SHIP:PERIAPSIS / 1000, 1) + " km" AT (0, 18).
PRINT "Ecc: " + ROUND(SHIP:ORBIT:ECCENTRICITY, 4) AT (0, 19).

IF raisonMeco = "depassement" {
    bipErreur().
    PRINT "Depassement orbital." AT (0, 21).
} ELSE IF SHIP:PERIAPSIS >= apoapseCible * 0.90 AND SHIP:APOAPSIS > 0 {
    bipDouble().
    PRINT "Orbite quasi-circulaire!" AT (0, 21).
} ELSE IF SHIP:APOAPSIS > 0 {
    PRINT "Circulariser a l'apo." AT (0, 21).
} ELSE {
    bipErreur().
    PRINT "Trajectoire anormale." AT (0, 21).
}

} // fin du IF NOT pegDepassement
