// Calcul de fenetre et cap pour lancement en plan orbital incline
// Necessite: lib/nav.ks, TARGET defini

// Normale au plan orbital de la cible
FUNCTION normaleOrbCible {
    RETURN VCRS(
        TARGET:POSITION - BODY:POSITION,
        TARGET:VELOCITY:ORBIT
    ):NORMALIZED.
}

// Cap de lancement corrige pour la rotation du corps
// incDeg: inclinaison cible, altOrb: altitude orbitale visee
// ascendant: TRUE = noeud ascendant, FALSE = descendant
FUNCTION capPourInclinaison {
    PARAMETER incDeg.
    PARAMETER altOrb.
    PARAMETER ascendant IS TRUE.

    LOCAL lat IS SHIP:LATITUDE.
    LOCAL rapport IS COS(incDeg) / COS(lat).
    SET rapport TO MAX(-1, MIN(1, rapport)).
    LOCAL azInertiel IS ARCSIN(rapport).

    IF NOT ascendant SET azInertiel TO 180 - azInertiel.

    LOCAL vitOrb IS SQRT(BODY:MU / (BODY:RADIUS + altOrb)).
    LOCAL vitRot IS (2 * CONSTANT:PI * BODY:RADIUS * COS(lat))
                    / BODY:ROTATIONPERIOD.

    LOCAL vEst  IS vitOrb * SIN(azInertiel) - vitRot.
    LOCAL vNord IS vitOrb * COS(azInertiel).

    LOCAL cap IS ARCTAN2(vEst, vNord).
    IF cap < 0 SET cap TO cap + 360.
    RETURN cap.
}

// Recherche les deux prochaines traversees du plan orbital de TARGET
// Retourne une LIST de LEXICON("delai", s, "ascendant", bool, "cap", deg)
// triee par delai croissant
FUNCTION chercherFenetres {
    PARAMETER altOrb IS 80000.

    LOCAL normOrb IS normaleOrbCible().
    LOCAL posSite IS SHIP:POSITION - BODY:POSITION.
    LOCAL axeRot IS BODY:ANGULARVEL:NORMALIZED.
    LOCAL vitAngDeg IS BODY:ANGULARVEL:MAG * 180 / CONSTANT:PI.
    LOCAL incCible IS TARGET:ORBIT:INCLINATION.

    LOCAL nbPas IS 180.
    LOCAL dt IS BODY:ROTATIONPERIOD / nbPas.
    LOCAL projPrec IS VDOT(posSite:NORMALIZED, normOrb).

    LOCAL resultat IS LIST().

    FROM {LOCAL k IS 1.} UNTIL k > nbPas OR resultat:LENGTH >= 2
    STEP {SET k TO k + 1.} DO {
        LOCAL angleDeg IS vitAngDeg * k * dt.
        LOCAL posFut IS ANGLEAXIS(angleDeg, axeRot) * posSite.
        LOCAL projFut IS VDOT(posFut:NORMALIZED, normOrb).

        IF projPrec * projFut <= 0 {
            LOCAL frac IS ABS(projPrec) / (ABS(projPrec) + ABS(projFut)).
            LOCAL delai IS (k - 1 + frac) * dt.
            LOCAL asc IS projPrec < projFut.

            resultat:ADD(LEXICON(
                "delai", delai,
                "ascendant", asc,
                "cap", capPourInclinaison(incCible, altOrb, asc)
            )).
        }
        SET projPrec TO projFut.
    }

    // Cas orbite equatoriale: lancer immediatement cap ~90
    IF resultat:LENGTH = 0 {
        resultat:ADD(LEXICON(
            "delai", 0,
            "ascendant", TRUE,
            "cap", capPourInclinaison(incCible, altOrb, TRUE)
        )).
    }

    RETURN resultat.
}
