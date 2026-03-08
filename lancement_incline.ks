// Lancement dans le plan orbital d'une cible inclinee (Minmus, etc.)
// Attend la fenetre de passage dans le plan puis lance avec le bon cap.
// Le decalage compense le temps d'ascension (~90s) pour etre dans le plan
// au moment de l'injection orbitale plutot qu'au moment du decollage.
// Usage: RUN lancement_incline.
//        RUN lancement_incline("Minmus", 80000, 120).

PARAMETER nomCible IS "Minmus".
PARAMETER apoapseCible IS 80000.
PARAMETER decalageAscension IS 90.     // secondes avant la fenetre (compense la montee)

RUNONCEPATH("0:/lib/bip.ks").
RUNONCEPATH("0:/lib/nav.ks").
RUNONCEPATH("0:/lib/fenetre.ks").

SET TARGET TO nomCible.

LOCAL incCible IS TARGET:ORBIT:INCLINATION.

CLEARSCREEN.
PRINT "--- LANCEMENT INCLINE ---" AT (0,0).
PRINT "Cible: " + nomCible AT (0,1).
PRINT "Inc: " + ROUND(incCible, 2) + " deg" AT (0,2).
PRINT "Apo cible: " + ROUND(apoapseCible / 1000) + " km" AT (0,3).

// Verification: inclinaison accessible
IF ABS(SHIP:LATITUDE) > incCible AND incCible > 0.1 {
    PRINT "ATTENTION: lat > inc cible!" AT (0,4).
    PRINT "Correction de plan necessaire." AT (0,5).
    bipErreur().
}

PRINT "---" AT (0,6).

// === RECHERCHE DES FENETRES ===
PRINT "Calcul fenetres..." AT (0,8).
LOCAL fenetres IS chercherFenetres(apoapseCible).

// Afficher les fenetres trouvees
LOCAL idx IS 0.
FOR f IN fenetres {
    LOCAL typeN IS "ASC".
    IF NOT f["ascendant"] SET typeN TO "DESC".
    PRINT "F" + idx + ": " + typeN
        + "  cap " + ROUND(f["cap"], 1) + " deg"
        + "  dans " + ROUND(f["delai"]) + " s"
        AT (0, 8 + idx).
    SET idx TO idx + 1.
}

// Choisir la premiere fenetre avec assez de delai
LOCAL fenetre IS fenetres[0].
IF fenetre["delai"] < decalageAscension AND fenetres:LENGTH > 1 {
    SET fenetre TO fenetres[1].
}

LOCAL delaiLancement IS fenetre["delai"] - decalageAscension.
IF delaiLancement < 0 SET delaiLancement TO 0.

LOCAL capLancement IS fenetre["cap"].
LOCAL typeNoeud IS "ascendant".
IF NOT fenetre["ascendant"] SET typeNoeud TO "descendant".

PRINT "---" AT (0, 10).
PRINT "Selection: noeud " + typeNoeud AT (0, 11).
PRINT "Cap: " + ROUND(capLancement, 1) + " deg" AT (0, 12).
PRINT "Lancement dans: " + ROUND(delaiLancement) + " s"
    + " (" + ROUND(delaiLancement / 60, 1) + " min)" AT (0, 13).

// === ATTENTE FENETRE ===
IF delaiLancement > 30 {
    // Pas de WARPTO sur le pas de tir : les clamps + physics warp = catastrophe
    // On utilise le warp rails manuellement, palier par palier
    PRINT "Attente fenetre...     " AT (0, 15).

    LOCAL tempsCible IS TIME:SECONDS + delaiLancement - 45.

    // Paliers de warp rails (indices kOS: 0=1x, 1=5x, 2=10x, 3=50x, 4=100x...)
    UNTIL TIME:SECONDS >= tempsCible {
        LOCAL reste IS tempsCible - TIME:SECONDS.
        LOCAL palier IS 0.
        IF reste > 600     SET palier TO 4.
        ELSE IF reste > 120 SET palier TO 3.
        ELSE IF reste > 30  SET palier TO 2.
        ELSE IF reste > 10  SET palier TO 1.

        SET KUNIVERSE:TIMEWARP:WARP TO palier.
        PRINT "T-" + ROUND(reste) + " s  (x" + KUNIVERSE:TIMEWARP:RATE + ")   " AT (0, 16).
        WAIT 0.2.
    }

    SET KUNIVERSE:TIMEWARP:WARP TO 0.
    WAIT UNTIL KUNIVERSE:TIMEWARP:ISSETTLED.
    PRINT "                                   " AT (0, 16).
}

// Attente fine avec suivi de l'angle hors-plan
// normOrb est recalculee a chaque iteration (la cible bouge apres warp)
LOCAL seuilPlan IS 1.7.     // degres
LOCAL limiteTemps IS TIME:SECONDS + 600.    // timeout 10 min

LOCAL angleHP IS 99.

UNTIL ABS(angleHP) < seuilPlan OR TIME:SECONDS > limiteTemps {
    LOCAL normOrb IS normaleOrbCible().
    LOCAL projSite IS VDOT((SHIP:POSITION - BODY:POSITION):NORMALIZED, normOrb).
    SET angleHP TO ARCSIN(MAX(-1, MIN(1, projSite))).
    PRINT "Hors-plan: " + ROUND(angleHP, 2) + " deg   " AT (0, 15).
    WAIT 0.5.
}

IF TIME:SECONDS > limiteTemps {
    PRINT "Timeout! Lancement au mieux." AT (0, 16).
    bipErreur().
} ELSE {
    bipOk().
}

PRINT "Fenetre! Lancement...              " AT (0, 15).

// === DELEGATION AU SCRIPT DE MONTEE ===
RUNPATH("0:/lancement_peg", capLancement, apoapseCible).
