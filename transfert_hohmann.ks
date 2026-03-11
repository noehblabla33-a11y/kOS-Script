// Transfert vers une lune et capture en orbite
// Usage: RUN transfert_hohmann. ou RUN transfert_hohmann("Mun").
//        RUN transfert_hohmann("Mun", 25000).

PARAMETER nomCible IS "Mun".
PARAMETER peCible IS 25000.

RUNONCEPATH("0:/lib/bip.ks").
RUNONCEPATH("0:/lib/nav.ks").
RUNONCEPATH("0:/lib/staging.ks").
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
PRINT "Pe cible: " + ROUND(peCible / 1000, 1) + " km" AT (0,4).
PRINT "---" AT (0,5).

// === CALCUL TEMPS FENETRE ===
LOCAL phaseCourante IS anglePhase().
LOCAL diffPhase IS MOD(phaseCourante - phaseIdeale + 360, 360).
LOCAL tempsFenetre IS diffPhase / vitAngRel.

// Si negatif ou passe, prochaine fenetre
IF tempsFenetre < 30 {
    SET tempsFenetre TO tempsFenetre + 360 / vitAngRel.
}

LOCAL tempsNode IS TIME:SECONDS + tempsFenetre.

PRINT "Fenetre dans: " + ROUND(tempsFenetre) + " s" AT (0,6).
PRINT "---" AT (0,7).

// === CREATION NODE ===
PRINT "Phase: attente fenetre " AT (0,9).

LOCAL noeudTransf IS NODE(tempsNode, 0, 0, dvTransf).
ADD noeudTransf.
WAIT 0.

// === AJUSTEMENT FIN ===
// On minimise l'ecart entre le Pe predit et le Pe cible.
// IMPORTANT: on lit noeudTransf:ORBIT (l'orbite APRES le burn)
// et non SHIP:ORBIT (l'orbite actuelle, avant le node).
PRINT "Phase: ajustement node " AT (0,9).

// Ecart actuel au Pe cible (scope script pour acces dans affinerTransf)
GLOBAL ecartPeTransf IS 999999999.

IF noeudTransf:ORBIT:HASNEXTPATCH {
    LOCAL peActuel IS noeudTransf:ORBIT:NEXTPATCH:PERIAPSIS.
    IF peActuel > 0 {
        SET ecartPeTransf TO ABS(peActuel - peCible).
    }
}

// Fonction d'affinage generique sur un champ du noeud
// Minimise |Pe - peCible| pour viser une orbite de capture propre
FUNCTION affinerTransf {
    PARAMETER noeud.
    PARAMETER champ.
    PARAMETER pasInit.
    PARAMETER pasMin.
    PARAMETER maxIter.

    LOCAL pas IS pasInit.
    LOCAL tentative IS 0.

    UNTIL tentative > maxIter OR pas < pasMin {
        LOCAL ameliore IS FALSE.
        LOCAL valeur IS 0.

        IF champ = "PROGRADE"   SET valeur TO noeud:PROGRADE.
        ELSE IF champ = "ETA"   SET valeur TO noeud:ETA.
        ELSE                    SET valeur TO noeud:RADIALOUT.

        // Essai +pas
        IF champ = "PROGRADE"   SET noeud:PROGRADE TO valeur + pas.
        ELSE IF champ = "ETA"   SET noeud:ETA TO valeur + pas.
        ELSE                    SET noeud:RADIALOUT TO valeur + pas.
        WAIT 0.

        IF noeud:ORBIT:HASNEXTPATCH {
            LOCAL nouvPe IS noeud:ORBIT:NEXTPATCH:PERIAPSIS.
            LOCAL nouvEcart IS ABS(nouvPe - peCible).
            IF nouvPe > 0 AND nouvEcart < ecartPeTransf {
                SET ecartPeTransf TO nouvEcart.
                SET ameliore TO TRUE.
            } ELSE {
                IF champ = "PROGRADE"   SET noeud:PROGRADE TO valeur.
                ELSE IF champ = "ETA"   SET noeud:ETA TO valeur.
                ELSE                    SET noeud:RADIALOUT TO valeur.
                WAIT 0.
            }
        } ELSE {
            IF champ = "PROGRADE"   SET noeud:PROGRADE TO valeur.
            ELSE IF champ = "ETA"   SET noeud:ETA TO valeur.
            ELSE                    SET noeud:RADIALOUT TO valeur.
            WAIT 0.
        }

        // Essai -pas
        IF NOT ameliore {
            IF champ = "PROGRADE"   SET noeud:PROGRADE TO valeur - pas.
            ELSE IF champ = "ETA"   SET noeud:ETA TO valeur - pas.
            ELSE                    SET noeud:RADIALOUT TO valeur - pas.
            WAIT 0.

            IF noeud:ORBIT:HASNEXTPATCH {
                LOCAL nouvPe IS noeud:ORBIT:NEXTPATCH:PERIAPSIS.
                LOCAL nouvEcart IS ABS(nouvPe - peCible).
                IF nouvPe > 0 AND nouvEcart < ecartPeTransf {
                    SET ecartPeTransf TO nouvEcart.
                    SET ameliore TO TRUE.
                } ELSE {
                    IF champ = "PROGRADE"   SET noeud:PROGRADE TO valeur.
                    ELSE IF champ = "ETA"   SET noeud:ETA TO valeur.
                    ELSE                    SET noeud:RADIALOUT TO valeur.
                    WAIT 0.
                }
            } ELSE {
                IF champ = "PROGRADE"   SET noeud:PROGRADE TO valeur.
                ELSE IF champ = "ETA"   SET noeud:ETA TO valeur.
                ELSE                    SET noeud:RADIALOUT TO valeur.
                WAIT 0.
            }
        }

        IF NOT ameliore SET pas TO pas / 2.
        SET tentative TO tentative + 1.
    }
}

// Etape 1 : prograde (gros pas)
affinerTransf(noeudTransf, "PROGRADE", 5, 0.05, 60).
PRINT "Ajust prograde ok      " AT (0,10).

// Etape 2 : timing
affinerTransf(noeudTransf, "ETA", 10, 0.5, 40).
PRINT "Ajust timing ok        " AT (0,10).

// Etape 3 : radial (compense orbite non-circulaire)
affinerTransf(noeudTransf, "RADIALOUT", 2, 0.05, 40).
PRINT "Ajust radial ok        " AT (0,10).

// Etape 4 : prograde fin
affinerTransf(noeudTransf, "PROGRADE", 0.5, 0.01, 30).
PRINT "Ajust fin ok           " AT (0,10).

// === RESULTAT AJUSTEMENT ===
IF NOT noeudTransf:ORBIT:HASNEXTPATCH {
    PRINT "Pas d'encounter trouvee!" AT (0,11).
    PRINT "Verifier le node sur la map." AT (0,12).
    bipErreur().
} ELSE {
    LOCAL peArrivee IS noeudTransf:ORBIT:NEXTPATCH:PERIAPSIS.
    PRINT "Encounter trouvee!" AT (0,10).
    PRINT "Pe a " + nomCible + ": " + ROUND(peArrivee / 1000, 1) + " km" AT (0,11).
    bipOk().

    // === EXECUTION DU BURN ===
    PRINT "Phase: burn transfert  " AT (0,9).
    demarrerAutoStaging().
    executerNode().
    arreterAutoStaging().

    // === COAST VERS SOI ===
    PRINT "Phase: coast           " AT (0,9).

    IF SHIP:ORBIT:HASNEXTPATCH {
        LOCAL tempsSOI IS SHIP:ORBIT:NEXTPATCHETA.
        IF tempsSOI > 60 {
            KUNIVERSE:TIMEWARP:WARPTO(TIME:SECONDS + tempsSOI - 30).
        }
    }

    WAIT UNTIL SHIP:BODY:NAME = nomCible.
    PRINT "SOI: " + BODY:NAME AT (0,11).
    bipOk().

    // === CAPTURE AU PERIAPSIS ===
    RUNPATH("0:/circularisation", "per").

    bipDouble().
    WAIT 0.5.
    bipDouble().

    PRINT "En orbite de " + BODY:NAME + "!" AT (0,13).
    PRINT "Apo: " + ROUND(SHIP:APOAPSIS / 1000, 1) + " km" AT (0,14).
    PRINT "Per: " + ROUND(SHIP:PERIAPSIS / 1000, 1) + " km" AT (0,15).
}

// Nettoyage variable globale
UNSET ecartPeTransf.
