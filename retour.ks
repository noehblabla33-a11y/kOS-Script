// Retour depuis une lune vers le corps parent (Mun/Minmus -> Kerbin)
// Calcule le burn d'ejection optimal et warpe jusqu'au retour en SOI.
// Usage: RUN retour. ou RUN retour(30000).

PARAMETER periCible IS 30000.

RUNONCEPATH("0:/lib/bip.ks").
RUNONCEPATH("0:/lib/nav.ks").
RUNONCEPATH("0:/lib/manoeuvre.ks").
RUNONCEPATH("0:/lib/staging.ks").

// Ecart entre le periapsis predit au parent et la cible
FUNCTION ecartPe {
    IF NOT SHIP:ORBIT:HASNEXTPATCH RETURN 9999999999.
    LOCAL pe IS SHIP:ORBIT:NEXTPATCH:PERIAPSIS.
    IF pe < 0 RETURN 9999999999.
    RETURN ABS(pe - periCible).
}

LOCAL nomLune IS BODY:NAME.
LOCAL nomParent IS BODY:BODY:NAME.

CLEARSCREEN.
PRINT "--- RETOUR ---" AT (0,0).
PRINT "Depuis: " + nomLune AT (0,1).
PRINT "Vers: " + nomParent AT (0,2).
PRINT "Pe cible: " + ROUND(periCible / 1000, 1) + " km" AT (0,3).
PRINT "---" AT (0,4).

// Verif excentricite
IF excentricite() > 0.15 {
    PRINT "Orbite excentrique! Ecc: " + ROUND(excentricite(), 3) AT (0,5).
    bipErreur().
}

// === CALCUL DV EJECTION ===
LOCAL muParent IS BODY:BODY:MU.
LOCAL muLune IS BODY:MU.
LOCAL rayLune IS BODY:ORBIT:SEMIMAJORAXIS.
LOCAL rayPeCible IS BODY:BODY:RADIUS + periCible.
LOCAL rayOrbite IS BODY:RADIUS + (SHIP:APOAPSIS + SHIP:PERIAPSIS) / 2.

// Orbite de transfert retour (cadre parent)
LOCAL demiAxeRetour IS (rayLune + rayPeCible) / 2.
LOCAL vitTransfert IS SQRT(muParent * (2 / rayLune - 1 / demiAxeRetour)).
LOCAL vitLune IS SQRT(muParent / rayLune).
LOCAL vExces IS vitLune - vitTransfert.

// Ejection hyperbolique (vis-viva au rayon orbital)
LOCAL vitEjection IS SQRT(vExces^2 + 2 * muLune / rayOrbite).
LOCAL vitOrbLune IS SQRT(muLune / rayOrbite).
LOCAL dvEjection IS vitEjection - vitOrbLune.

PRINT "Dv ejection: " + ROUND(dvEjection, 1) + " m/s" AT (0,5).

// === SCAN FENETRE D'EJECTION ===
PRINT "Phase: scan            " AT (0,7).

LOCAL periodeOrb IS 2 * CONSTANT:PI * SQRT(rayOrbite^3 / muLune).
LOCAL nbScan IS 36.
LOCAL dtScan IS periodeOrb / nbScan.
LOCAL meilleurEcart IS 9999999999.
LOCAL meilleurETA IS -1.

FROM {LOCAL k IS 0.} UNTIL k >= nbScan STEP {SET k TO k + 1.} DO {
    LOCAL tempsETA IS 60 + dtScan * k.
    LOCAL nTest IS NODE(TIME:SECONDS + tempsETA, 0, 0, dvEjection).
    ADD nTest.
    WAIT 0.

    LOCAL ec IS ecartPe().
    IF ec < meilleurEcart {
        SET meilleurEcart TO ec.
        SET meilleurETA TO tempsETA.
    }

    REMOVE nTest.
    WAIT 0.
    PRINT "Scan: " + ROUND(100 * (k + 1) / nbScan) + " %   " AT (0,8).
}

IF meilleurETA < 0 {
    PRINT "Aucune trajectoire trouvee!" AT (0,10).
    PRINT "Verifier l'orbite." AT (0,11).
    bipErreur().
}

IF meilleurETA >= 0 {

    // === CREATION + AJUSTEMENT NODE ===
    PRINT "Phase: ajustement node " AT (0,7).

    LOCAL noeudRetour IS NODE(TIME:SECONDS + meilleurETA, 0, 0, dvEjection).
    ADD noeudRetour.

    LOCAL ecartActuel IS ecartPe().

    // Etape 1 : balayage prograde
    LOCAL pas IS 2.
    LOCAL tentative IS 0.
    UNTIL tentative > 50 OR pas < 0.05 {
        LOCAL ameliore IS FALSE.

        SET noeudRetour:PROGRADE TO noeudRetour:PROGRADE + pas.
        IF ecartPe() < ecartActuel {
            SET ecartActuel TO ecartPe().
            SET ameliore TO TRUE.
        } ELSE {
            SET noeudRetour:PROGRADE TO noeudRetour:PROGRADE - pas.
        }

        IF NOT ameliore {
            SET noeudRetour:PROGRADE TO noeudRetour:PROGRADE - pas.
            IF ecartPe() < ecartActuel {
                SET ecartActuel TO ecartPe().
                SET ameliore TO TRUE.
            } ELSE {
                SET noeudRetour:PROGRADE TO noeudRetour:PROGRADE + pas.
            }
        }

        IF NOT ameliore SET pas TO pas / 2.
        SET tentative TO tentative + 1.
    }

    // Etape 2 : balayage timing
    SET pas TO 5.
    SET tentative TO 0.
    UNTIL tentative > 40 OR pas < 0.5 {
        LOCAL ameliore IS FALSE.

        SET noeudRetour:ETA TO noeudRetour:ETA + pas.
        IF ecartPe() < ecartActuel {
            SET ecartActuel TO ecartPe().
            SET ameliore TO TRUE.
        } ELSE {
            SET noeudRetour:ETA TO noeudRetour:ETA - pas.
        }

        IF NOT ameliore {
            SET noeudRetour:ETA TO noeudRetour:ETA - pas.
            IF ecartPe() < ecartActuel {
                SET ecartActuel TO ecartPe().
                SET ameliore TO TRUE.
            } ELSE {
                SET noeudRetour:ETA TO noeudRetour:ETA + pas.
            }
        }

        IF NOT ameliore SET pas TO pas / 2.
        SET tentative TO tentative + 1.
    }

    // Etape 3 : balayage normal (correction de plan)
    SET pas TO 2.
    SET tentative TO 0.
    UNTIL tentative > 50 OR pas < 0.05 {
        LOCAL ameliore IS FALSE.

        SET noeudRetour:NORMAL TO noeudRetour:NORMAL + pas.
        IF ecartPe() < ecartActuel {
            SET ecartActuel TO ecartPe().
            SET ameliore TO TRUE.
        } ELSE {
            SET noeudRetour:NORMAL TO noeudRetour:NORMAL - pas.
        }

        IF NOT ameliore {
            SET noeudRetour:NORMAL TO noeudRetour:NORMAL - pas.
            IF ecartPe() < ecartActuel {
                SET ecartActuel TO ecartPe().
                SET ameliore TO TRUE.
            } ELSE {
                SET noeudRetour:NORMAL TO noeudRetour:NORMAL + pas.
            }
        }

        IF NOT ameliore SET pas TO pas / 2.
        SET tentative TO tentative + 1.
    }

    // === RESULTAT AJUSTEMENT ===
    IF NOT SHIP:ORBIT:HASNEXTPATCH {
        PRINT "Trajectoire perdue!" AT (0,10).
        bipErreur().
        REMOVE noeudRetour.
    } ELSE {
        LOCAL peFinale IS SHIP:ORBIT:NEXTPATCH:PERIAPSIS.
        PRINT "Pe " + nomParent + ": " + ROUND(peFinale / 1000, 1) + " km" AT (0,9).
        bipOk().

        // === EXECUTION ===
        PRINT "Phase: burn ejection   " AT (0,7).
        demarrerAutoStaging().
        executerNode().
        arreterAutoStaging().

        // === COAST VERS SOI PARENT ===
        PRINT "Phase: coast           " AT (0,7).

        IF SHIP:ORBIT:HASNEXTPATCH {
            LOCAL tempsSOI IS SHIP:ORBIT:NEXTPATCHETA.
            IF tempsSOI > 60 {
                KUNIVERSE:TIMEWARP:WARPTO(TIME:SECONDS + tempsSOI - 30).
            }
        }

        WAIT UNTIL BODY:NAME = nomParent.

        bipDouble().
        WAIT 0.5.
        bipDouble().

        PRINT "SOI: " + BODY:NAME + "              " AT (0,7).
        PRINT "Pe: " + ROUND(SHIP:PERIAPSIS / 1000, 1) + " km" AT (0,11).
        PRINT "Retour en cours!" AT (0,13).
    }
}
