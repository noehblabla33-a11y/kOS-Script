// Transfert vers une lune et capture en orbite
// Usage: RUN transfert_hohmann. ou RUN transfert_hohmann("Mun").

PARAMETER nomCible IS "Mun".

RUNONCEPATH("0:/lib/bip.ks").
RUNONCEPATH("0:/lib/nav.ks").
RUNONCEPATH("0:/lib/manoeuvre.ks").

SET TARGET TO nomCible.

CLEARSCREEN.
PRINT "--- TRANSFERT ---" AT (0,0).
PRINT "Cible: " + nomCible AT (0,1).

// Verif excentricite
IF excentricite() > 0.1 {
    PRINT "Orbite trop excentrique!" AT (0,3).
    PRINT "Ecc: " + ROUND(excentricite(), 3) AT (0,4).
    bipErreur().
}

// Rayon moyen de l'orbite actuelle
LOCAL rayDep IS BODY:RADIUS + (SHIP:APOAPSIS + SHIP:PERIAPSIS) / 2.
// Rayon de l'orbite de la cible
LOCAL rayArr IS TARGET:ORBIT:SEMIMAJORAXIS.

// Hohmann: demi-axe du transfert
LOCAL demiAxeTransf IS (rayDep + rayArr) / 2.

// Delta-v de depart (vis-viva)
LOCAL vitDep IS SQRT(BODY:MU * (2 / rayDep - 1 / demiAxeTransf)).
LOCAL vitCircDep IS SQRT(BODY:MU / rayDep).
LOCAL dvTransf IS vitDep - vitCircDep.

// Duree du transfert (demi-orbite)
LOCAL dureeTransf IS CONSTANT:PI * SQRT(demiAxeTransf^3 / BODY:MU).

// Angle de phase ideal
LOCAL angleMvt IS (dureeTransf / TARGET:ORBIT:PERIOD) * 360.
LOCAL phaseIdeale IS 180 - angleMvt.
IF phaseIdeale < 0 SET phaseIdeale TO phaseIdeale + 360.

// Vitesse angulaire pour predire la fenetre
LOCAL vitAngNav IS SQRT(BODY:MU / rayDep^3) * 180 / CONSTANT:PI.
LOCAL vitAngCib IS 360 / TARGET:ORBIT:PERIOD.
LOCAL vitAngRel IS vitAngNav - vitAngCib.

PRINT "Dv transfert: " + ROUND(dvTransf, 1) + " m/s" AT (0,2).
PRINT "Phase ideale: " + ROUND(phaseIdeale, 1) + " deg" AT (0,3).
PRINT "---" AT (0,4).

// === CALCUL TEMPS FENETRE ===
LOCAL phaseCourante IS anglePhase().
LOCAL diffPhase IS MOD(phaseCourante - phaseIdeale + 360, 360).
LOCAL tempsFenetre IS diffPhase / vitAngRel.

// Si negatif ou passe, prochaine fenetre
IF tempsFenetre < 30 {
    SET tempsFenetre TO tempsFenetre + 360 / vitAngRel.
}

LOCAL tempsNode IS TIME:SECONDS + tempsFenetre.

PRINT "Fenetre dans: " + ROUND(tempsFenetre) + " s" AT (0,5).
PRINT "---" AT (0,6).

// === CREATION NODE ===
PRINT "Phase: attente fenetre " AT (0,8).

LOCAL noeudTransf IS NODE(tempsNode, 0, 0, dvTransf).
ADD noeudTransf.

// === AJUSTEMENT FIN ===
PRINT "Phase: ajustement node " AT (0,8).

LOCAL pas IS 5.
LOCAL meilleurPe IS 999999999.
LOCAL tentative IS 0.

IF SHIP:ORBIT:HASNEXTPATCH {
    SET meilleurPe TO SHIP:ORBIT:NEXTPATCH:PERIAPSIS.
}

// Etape 1 : balayage en prograde
UNTIL tentative > 60 OR pas < 0.05 {
    LOCAL ameliore IS FALSE.

    SET noeudTransf:PROGRADE TO noeudTransf:PROGRADE + pas.
    IF SHIP:ORBIT:HASNEXTPATCH {
        LOCAL nouvPe IS SHIP:ORBIT:NEXTPATCH:PERIAPSIS.
        IF nouvPe > 0 AND nouvPe < meilleurPe {
            SET meilleurPe TO nouvPe.
            SET ameliore TO TRUE.
        } ELSE {
            SET noeudTransf:PROGRADE TO noeudTransf:PROGRADE - pas.
        }
    } ELSE {
        SET noeudTransf:PROGRADE TO noeudTransf:PROGRADE - pas.
    }

    IF NOT ameliore {
        SET noeudTransf:PROGRADE TO noeudTransf:PROGRADE - pas.
        IF SHIP:ORBIT:HASNEXTPATCH {
            LOCAL nouvPe IS SHIP:ORBIT:NEXTPATCH:PERIAPSIS.
            IF nouvPe > 0 AND nouvPe < meilleurPe {
                SET meilleurPe TO nouvPe.
                SET ameliore TO TRUE.
            } ELSE {
                SET noeudTransf:PROGRADE TO noeudTransf:PROGRADE + pas.
            }
        } ELSE {
            SET noeudTransf:PROGRADE TO noeudTransf:PROGRADE + pas.
        }
    }

    IF NOT ameliore {
        SET pas TO pas / 2.
    }

    SET tentative TO tentative + 1.
}

// Etape 2 : balayage en timing
SET pas TO 10.
SET tentative TO 0.
UNTIL tentative > 40 OR pas < 0.5 {
    LOCAL ameliore IS FALSE.

    SET noeudTransf:ETA TO noeudTransf:ETA + pas.
    IF SHIP:ORBIT:HASNEXTPATCH {
        LOCAL nouvPe IS SHIP:ORBIT:NEXTPATCH:PERIAPSIS.
        IF nouvPe > 0 AND nouvPe < meilleurPe {
            SET meilleurPe TO nouvPe.
            SET ameliore TO TRUE.
        } ELSE {
            SET noeudTransf:ETA TO noeudTransf:ETA - pas.
        }
    } ELSE {
        SET noeudTransf:ETA TO noeudTransf:ETA - pas.
    }

    IF NOT ameliore {
        SET noeudTransf:ETA TO noeudTransf:ETA - pas.
        IF SHIP:ORBIT:HASNEXTPATCH {
            LOCAL nouvPe IS SHIP:ORBIT:NEXTPATCH:PERIAPSIS.
            IF nouvPe > 0 AND nouvPe < meilleurPe {
                SET meilleurPe TO nouvPe.
                SET ameliore TO TRUE.
            } ELSE {
                SET noeudTransf:ETA TO noeudTransf:ETA + pas.
            }
        } ELSE {
            SET noeudTransf:ETA TO noeudTransf:ETA + pas.
        }
    }

    IF NOT ameliore {
        SET pas TO pas / 2.
    }

    SET tentative TO tentative + 1.
}

// === RESULTAT AJUSTEMENT ===
IF NOT SHIP:ORBIT:HASNEXTPATCH {
    PRINT "Pas d'encounter trouvee!" AT (0,10).
    PRINT "Verifier le node sur la map." AT (0,11).
    bipErreur().
} ELSE {
    LOCAL peArrivee IS SHIP:ORBIT:NEXTPATCH:PERIAPSIS.
    PRINT "Encounter trouvee!" AT (0,9).
    PRINT "Pe a " + nomCible + ": " + ROUND(peArrivee / 1000, 1) + " km" AT (0,10).
    bipOk().

    // === EXECUTION DU BURN ===
    PRINT "Phase: burn transfert  " AT (0,8).
    executerNode().

    // === COAST VERS SOI ===
    PRINT "Phase: coast           " AT (0,8).

    LOCAL tempsSOI IS SHIP:ORBIT:NEXTPATCHETA.
    IF tempsSOI > 60 {
        KUNIVERSE:TIMEWARP:WARPTO(TIME:SECONDS + tempsSOI - 30).
    }

    WAIT UNTIL SHIP:BODY:NAME = nomCible.
    PRINT "SOI: " + BODY:NAME AT (0,10).
    bipOk().

    // === CAPTURE AU PERIAPSIS ===
    RUNPATH("0:/circularisation", "per").

    bipDouble().
    WAIT 0.5.
    bipDouble().

    PRINT "En orbite de " + BODY:NAME + "!" AT (0,12).
    PRINT "Apo: " + ROUND(SHIP:APOAPSIS / 1000, 1) + " km" AT (0,13).
    PRINT "Per: " + ROUND(SHIP:PERIAPSIS / 1000, 1) + " km" AT (0,14).
}
