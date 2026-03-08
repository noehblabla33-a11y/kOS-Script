// Ajustement d'orbite : modifier apoapsis, periapsis, ou les deux
// Burn prograde/retrograde au point oppose pour atteindre la valeur cible.
//
// Usage:
//   RUN ajustement_orbite("apo", 100000).     apo a 100 km
//   RUN ajustement_orbite("per", 15000).      peri a 15 km
//   RUN ajustement_orbite("both", 80000).     circulariser a 80 km (2 burns)

PARAMETER mode IS "apo".
PARAMETER altCible IS 80000.

RUNONCEPATH("0:/lib/bip.ks").
RUNONCEPATH("0:/lib/nav.ks").
RUNONCEPATH("0:/lib/manoeuvre.ks").
RUNONCEPATH("0:/lib/staging.ks").

// --- Fonctions locales ---

// Dv vis-viva pour changer un apse depuis le point oppose
// rayBurn : rayon au point de burn
// rayActuel : rayon de l'apse qu'on veut garder (= rayBurn)
// rayAvant : rayon de l'apse a changer (avant manoeuvre)
// rayApres : rayon de l'apse a changer (apres manoeuvre)
FUNCTION dvVisViva {
    PARAMETER rayBurn.
    PARAMETER rayAvant.
    PARAMETER rayApres.

    LOCAL demiAxeAv IS (rayBurn + rayAvant) / 2.
    LOCAL demiAxeAp IS (rayBurn + rayApres) / 2.
    LOCAL vitAv IS SQRT(BODY:MU * (2 / rayBurn - 1 / demiAxeAv)).
    LOCAL vitAp IS SQRT(BODY:MU * (2 / rayBurn - 1 / demiAxeAp)).
    RETURN vitAp - vitAv.
}

// Ecart entre l'apse visee et la cible apres le node
FUNCTION ecartApse {
    PARAMETER cible.
    PARAMETER quoi.   // "apo" ou "per"
    IF NOT HASNODE RETURN 9999999.
    LOCAL orbAp IS NEXTNODE:ORBIT.
    IF quoi = "apo" RETURN ABS(orbAp:APOAPSIS - cible).
    RETURN ABS(orbAp:PERIAPSIS - cible).
}

// Hill-climbing generique sur un champ du node
FUNCTION affiner {
    PARAMETER noeud.
    PARAMETER champ.
    PARAMETER pasInit.
    PARAMETER pasMin.
    PARAMETER maxIter.
    PARAMETER cible.
    PARAMETER quoi.

    LOCAL ecartRef IS ecartApse(cible, quoi).
    LOCAL pas IS pasInit.
    LOCAL it IS 0.

    UNTIL it > maxIter OR pas < pasMin {
        LOCAL ameliore IS FALSE.
        LOCAL val IS 0.

        IF champ = "PROGRADE" SET val TO noeud:PROGRADE.
        ELSE SET val TO noeud:ETA.

        // Essai +pas
        IF champ = "PROGRADE" SET noeud:PROGRADE TO val + pas.
        ELSE SET noeud:ETA TO val + pas.

        IF ecartApse(cible, quoi) < ecartRef {
            SET ecartRef TO ecartApse(cible, quoi).
            SET ameliore TO TRUE.
        } ELSE {
            IF champ = "PROGRADE" SET noeud:PROGRADE TO val.
            ELSE SET noeud:ETA TO val.
        }

        IF NOT ameliore {
            IF champ = "PROGRADE" SET noeud:PROGRADE TO val - pas.
            ELSE SET noeud:ETA TO val - pas.

            IF ecartApse(cible, quoi) < ecartRef {
                SET ecartRef TO ecartApse(cible, quoi).
                SET ameliore TO TRUE.
            } ELSE {
                IF champ = "PROGRADE" SET noeud:PROGRADE TO val.
                ELSE SET noeud:ETA TO val.
            }
        }

        IF NOT ameliore SET pas TO pas / 2.
        SET it TO it + 1.
    }

    RETURN ecartRef.
}

// Creer, affiner et executer un node pour un ajustement
FUNCTION executerAjustement {
    PARAMETER cible.
    PARAMETER quoi.   // "apo" ou "per"

    LOCAL labelQuoi IS "apoapsis".
    IF quoi = "per" SET labelQuoi TO "periapsis".

    LOCAL rayBurn IS 0.
    LOCAL rayApse IS 0.
    LOCAL etaBurn IS 0.

    IF quoi = "apo" {
        // Changer l'apo = burn au periapsis
        SET rayBurn TO BODY:RADIUS + SHIP:PERIAPSIS.
        SET rayApse TO BODY:RADIUS + SHIP:APOAPSIS.
        SET etaBurn TO ETA:PERIAPSIS.
    } ELSE {
        // Changer le peri = burn a l'apoapsis
        SET rayBurn TO BODY:RADIUS + SHIP:APOAPSIS.
        SET rayApse TO BODY:RADIUS + SHIP:PERIAPSIS.
        SET etaBurn TO ETA:APOAPSIS.
    }

    LOCAL rayCible IS BODY:RADIUS + cible.
    LOCAL dvCalc IS dvVisViva(rayBurn, rayApse, rayCible).

    PRINT "Dv estime: " + ROUND(dvCalc, 1) + " m/s" AT (0,6).

    // Creation du node
    LOCAL noeud IS NODE(TIME:SECONDS + etaBurn, 0, 0, dvCalc).
    ADD noeud.

    // Hill-climbing : prograde puis timing
    PRINT "Phase: ajustement node " AT (0,8).
    affiner(noeud, "PROGRADE", 1, 0.01, 50, cible, quoi).
    affiner(noeud, "ETA",      5, 0.5,  30, cible, quoi).
    affiner(noeud, "PROGRADE", 0.1, 0.005, 30, cible, quoi).

    LOCAL orbAp IS noeud:ORBIT.
    PRINT "Apo apres: " + ROUND(orbAp:APOAPSIS / 1000, 1) + " km" AT (0,9).
    PRINT "Per apres: " + ROUND(orbAp:PERIAPSIS / 1000, 1) + " km" AT (0,10).
    PRINT "Dv total: " + ROUND(noeud:DELTAV:MAG, 1) + " m/s" AT (0,11).
    bipOk().

    // Execution
    PRINT "Phase: burn            " AT (0,8).
    demarrerAutoStaging().
    executerNode().
    arreterAutoStaging().

    bipDouble().
}

// --- Initialisation ---
CLEARSCREEN.
PRINT "--- AJUSTEMENT ORBITE ---" AT (0,0).
PRINT "Apo: " + ROUND(SHIP:APOAPSIS / 1000, 1) + " km" AT (0,1).
PRINT "Per: " + ROUND(SHIP:PERIAPSIS / 1000, 1) + " km" AT (0,2).
PRINT "---" AT (0,3).

IF mode = "apo" {
    PRINT "Cible: apoapsis a " + ROUND(altCible / 1000, 1) + " km" AT (0,4).
    executerAjustement(altCible, "apo").
} ELSE IF mode = "per" {
    PRINT "Cible: periapsis a " + ROUND(altCible / 1000, 1) + " km" AT (0,4).
    executerAjustement(altCible, "per").
} ELSE IF mode = "both" {
    PRINT "Cible: circ a " + ROUND(altCible / 1000, 1) + " km" AT (0,4).

    // Burn 1 : amener l'apo a la cible (burn au peri)
    PRINT "--- Burn 1/2 : apo ---" AT (0,5).
    executerAjustement(altCible, "apo").

    // Attente demi-orbite
    PRINT "Phase: coast           " AT (0,8).
    PRINT "                           " AT (0,9).
    PRINT "                           " AT (0,10).
    PRINT "                           " AT (0,11).

    IF ETA:APOAPSIS > 60 {
        KUNIVERSE:TIMEWARP:WARPTO(TIME:SECONDS + ETA:APOAPSIS - 30).
        WAIT UNTIL KUNIVERSE:TIMEWARP:ISSETTLED.
    }

    // Burn 2 : amener le peri a la cible (burn a l'apo)
    PRINT "--- Burn 2/2 : per ---" AT (0,5).
    PRINT "                       " AT (0,6).
    executerAjustement(altCible, "per").
} ELSE {
    PRINT "Mode inconnu: " + mode AT (0,4).
    PRINT "Modes: apo, per, both" AT (0,5).
    bipErreur().
}

PRINT "Orbite finale:" AT (0,13).
PRINT "Apo: " + ROUND(SHIP:APOAPSIS / 1000, 1) + " km" AT (0,14).
PRINT "Per: " + ROUND(SHIP:PERIAPSIS / 1000, 1) + " km" AT (0,15).
