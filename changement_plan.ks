// Changement de plan orbital
// Mode cible: aligner sur le plan orbital d'un astre
// Mode custom: changer l'inclinaison a une valeur precise
//
// Usage:
//   RUN changement_plan("Minmus").       aligner sur Minmus
//   RUN changement_plan("Mun").          aligner sur la Mun
//   RUN changement_plan("", 0).          orbite equatoriale
//   RUN changement_plan("", 6.5).        inclinaison 6.5 deg

PARAMETER nomCible IS "".
PARAMETER incCustom IS -1.

RUNONCEPATH("0:/lib/bip.ks").
RUNONCEPATH("0:/lib/nav.ks").
RUNONCEPATH("0:/lib/manoeuvre.ks").
RUNONCEPATH("0:/lib/staging.ks").

// --- Fonctions locales ---

// Inclinaison relative entre deux plans orbitaux (formule spherique)
FUNCTION incRelative {
    PARAMETER inc1. PARAMETER lan1.
    PARAMETER inc2. PARAMETER lan2.
    LOCAL cosIR IS COS(inc1) * COS(inc2)
                 + SIN(inc1) * SIN(inc2) * COS(lan1 - lan2).
    RETURN ARCCOS(MAX(-1, MIN(1, cosIR))).
}

LOCAL modeCible IS (nomCible <> "").

// Ecart au plan vise apres execution du node courant
FUNCTION coutPlan {
    IF NOT HASNODE RETURN 999.
    LOCAL orbAp IS NEXTNODE:ORBIT.
    IF modeCible {
        RETURN incRelative(orbAp:INCLINATION, orbAp:LAN,
                           TARGET:ORBIT:INCLINATION, TARGET:ORBIT:LAN).
    }
    RETURN ABS(orbAp:INCLINATION - incCustom).
}

// Pas generique de hill-climbing sur un champ du node
// Modifie le champ, garde si meilleur, sinon essaie l'autre sens
FUNCTION affiner {
    PARAMETER noeud.
    PARAMETER champ.      // "NORMAL", "ETA", "PROGRADE"
    PARAMETER pasInit.
    PARAMETER pasMin.
    PARAMETER maxIter.

    LOCAL ecartRef IS coutPlan().
    LOCAL pas IS pasInit.
    LOCAL it IS 0.

    UNTIL it > maxIter OR pas < pasMin {
        LOCAL ameliore IS FALSE.
        LOCAL val IS 0.

        IF champ = "NORMAL" SET val TO noeud:NORMAL.
        ELSE IF champ = "ETA" SET val TO noeud:ETA.
        ELSE SET val TO noeud:PROGRADE.

        // Essai +pas
        IF champ = "NORMAL" SET noeud:NORMAL TO val + pas.
        ELSE IF champ = "ETA" SET noeud:ETA TO val + pas.
        ELSE SET noeud:PROGRADE TO val + pas.

        IF coutPlan() < ecartRef {
            SET ecartRef TO coutPlan().
            SET ameliore TO TRUE.
        } ELSE {
            // Annuler
            IF champ = "NORMAL" SET noeud:NORMAL TO val.
            ELSE IF champ = "ETA" SET noeud:ETA TO val.
            ELSE SET noeud:PROGRADE TO val.
        }

        // Essai -pas si pas d'amelioration
        IF NOT ameliore {
            IF champ = "NORMAL" SET noeud:NORMAL TO val - pas.
            ELSE IF champ = "ETA" SET noeud:ETA TO val - pas.
            ELSE SET noeud:PROGRADE TO val - pas.

            IF coutPlan() < ecartRef {
                SET ecartRef TO coutPlan().
                SET ameliore TO TRUE.
            } ELSE {
                IF champ = "NORMAL" SET noeud:NORMAL TO val.
                ELSE IF champ = "ETA" SET noeud:ETA TO val.
                ELSE SET noeud:PROGRADE TO val.
            }
        }

        IF NOT ameliore SET pas TO pas / 2.
        SET it TO it + 1.
    }

    RETURN ecartRef.
}

// --- Initialisation ---
CLEARSCREEN.
PRINT "--- CHANGEMENT DE PLAN ---" AT (0,0).

LOCAL incRel IS 0.

IF modeCible {
    SET TARGET TO nomCible.
    SET incRel TO incRelative(SHIP:ORBIT:INCLINATION, SHIP:ORBIT:LAN,
                              TARGET:ORBIT:INCLINATION, TARGET:ORBIT:LAN).
    PRINT "Cible: " + nomCible AT (0,1).
    PRINT "Inc relative: " + ROUND(incRel, 2) + " deg" AT (0,2).
} ELSE IF incCustom >= 0 {
    SET incRel TO ABS(SHIP:ORBIT:INCLINATION - incCustom).
    PRINT "Inc actuelle: " + ROUND(SHIP:ORBIT:INCLINATION, 2) + " deg" AT (0,1).
    PRINT "Inc cible: " + ROUND(incCustom, 2) + " deg" AT (0,2).
} ELSE {
    PRINT "Usage:" AT (0,1).
    PRINT "  changement_plan(cible)" AT (0,2).
    PRINT "  changement_plan('', inc)" AT (0,3).
    bipErreur().
}

IF incRel < 0.05 AND (modeCible OR incCustom >= 0) {
    PRINT "Plan deja aligne!" AT (0,4).
    bipOk().
}

IF incRel >= 0.05 AND (modeCible OR incCustom >= 0) {

    // Dv approximatif
    LOCAL rayMoy IS BODY:RADIUS + (SHIP:APOAPSIS + SHIP:PERIAPSIS) / 2.
    LOCAL vitOrb IS SQRT(BODY:MU / rayMoy).
    LOCAL dvApprox IS 2 * vitOrb * SIN(incRel / 2).

    PRINT "Ecart: " + ROUND(incRel, 2) + " deg" AT (0,3).
    PRINT "Dv estime: " + ROUND(dvApprox, 1) + " m/s" AT (0,4).

    // === SCAN : position et signe optimaux ===
    PRINT "Phase: scan            " AT (0,6).

    LOCAL periodeOrb IS SHIP:ORBIT:PERIOD.
    LOCAL nbScan IS 36.
    LOCAL dtScan IS periodeOrb / nbScan.
    LOCAL meilleurEcart IS 999.
    LOCAL meilleurETA IS 60.
    LOCAL meilleurDvN IS dvApprox.

    FROM {LOCAL k IS 0.} UNTIL k >= nbScan STEP {SET k TO k + 1.} DO {
        LOCAL tempsETA IS 30 + dtScan * k.

        FOR signe IN LIST(1, -1) {
            LOCAL dvTest IS signe * dvApprox.
            LOCAL nTest IS NODE(TIME:SECONDS + tempsETA, 0, dvTest, 0).
            ADD nTest.
            WAIT 0.
            LOCAL ec IS coutPlan().
            IF ec < meilleurEcart {
                SET meilleurEcart TO ec.
                SET meilleurETA TO tempsETA.
                SET meilleurDvN TO dvTest.
            }
            REMOVE nTest.
            WAIT 0.
        }

        PRINT "Scan: " + ROUND(100 * (k + 1) / nbScan) + " %   " AT (0,7).
    }

    // === CREATION NODE + HILL-CLIMBING ===
    PRINT "Phase: ajustement node " AT (0,6).
    PRINT "                       " AT (0,7).

    LOCAL noeudPlan IS NODE(TIME:SECONDS + meilleurETA, 0, meilleurDvN, 0).
    ADD noeudPlan.

    // Affinage: normal, timing, prograde, puis re-normal fin
    affiner(noeudPlan, "NORMAL",   1,    0.01,  50).
    affiner(noeudPlan, "ETA",      5,    0.5,   40).
    affiner(noeudPlan, "PROGRADE", 0.5,  0.01,  30).
    affiner(noeudPlan, "NORMAL",   0.2,  0.005, 30).

    LOCAL ecartFinal IS coutPlan().
    PRINT "Inc apres: " + ROUND(NEXTNODE:ORBIT:INCLINATION, 2) + " deg" AT (0,8).
    PRINT "Ecart resid: " + ROUND(ecartFinal, 3) + " deg" AT (0,9).
    PRINT "Dv total: " + ROUND(noeudPlan:DELTAV:MAG, 1) + " m/s" AT (0,10).

    bipOk().

    // === EXECUTION ===
    PRINT "Phase: burn correction " AT (0,6).
    demarrerAutoStaging().
    executerNode().
    arreterAutoStaging().

    bipDouble().
    PRINT "Plan corrige!" AT (0,12).
    PRINT "Inc: " + ROUND(SHIP:ORBIT:INCLINATION, 2) + " deg" AT (0,13).
    IF modeCible {
        LOCAL ecartPost IS incRelative(SHIP:ORBIT:INCLINATION, SHIP:ORBIT:LAN,
                                       TARGET:ORBIT:INCLINATION, TARGET:ORBIT:LAN).
        PRINT "Ecart a " + nomCible + ": " + ROUND(ecartPost, 2) + " deg" AT (0,14).
    }
}
