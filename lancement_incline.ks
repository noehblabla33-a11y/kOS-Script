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
IF delaiLancement > 120 {
    PRINT "Warp..." AT (0, 15).
    KUNIVERSE:TIMEWARP:WARPTO(TIME:SECONDS + delaiLancement - 45).
    WAIT UNTIL KUNIVERSE:TIMEWARP:ISSETTLED.
}

// Attente fine avec suivi de l'angle hors-plan
LOCAL normOrb IS normaleOrbCible().
LOCAL seuilPlan IS 0.015.   // ~0.9 deg

UNTIL ABS(VDOT((SHIP:POSITION - BODY:POSITION):NORMALIZED, normOrb)) < seuilPlan {
    LOCAL angleHP IS ARCSIN(
        MIN(1, MAX(-1, VDOT((SHIP:POSITION - BODY:POSITION):NORMALIZED, normOrb)))
    ).
    PRINT "Hors-plan: " + ROUND(angleHP, 2) + " deg   " AT (0, 15).
    WAIT 0.5.
}

bipOk().
PRINT "Fenetre! Lancement...              " AT (0, 15).

// === DELEGATION AU SCRIPT DE MONTEE ===
RUNPATH("0:/lancement_lt", capLancement, apoapseCible).
