// Utilitaires de navigation partages

// Gravite locale en m/s2
FUNCTION graviteLocale {
    RETURN BODY:MU / (BODY:RADIUS + SHIP:ALTITUDE)^2.
}

// Acceleration max du vaisseau en m/s2
FUNCTION accelMax {
    IF MAXTHRUST < 0.01 RETURN 0.01.
    RETURN MAXTHRUST / MASS.
}

// TWR par rapport a la gravite locale
FUNCTION twrLocal {
    RETURN accelMax() / graviteLocale().
}

// Distance pour freiner a 0 depuis la vitesse surface actuelle
FUNCTION distFreinage {
    LOCAL grv IS graviteLocale().
    LOCAL acc IS accelMax().
    LOCAL dec IS MAX(0.1, acc - grv).
    LOCAL vit IS SHIP:VELOCITY:SURFACE:MAG.
    RETURN vit^2 / (2 * dec).
}

// Duree estimee du freinage en secondes
FUNCTION dureeFreinage {
    LOCAL grv IS graviteLocale().
    LOCAL acc IS accelMax().
    LOCAL dec IS MAX(0.1, acc - grv).
    LOCAL vit IS SHIP:VELOCITY:SURFACE:MAG.
    RETURN vit / dec.
}

// Vitesse orbitale circulaire a une altitude donnee
FUNCTION vitOrbiteCible {
    PARAMETER altCible.
    LOCAL ray IS BODY:RADIUS + altCible.
    RETURN SQRT(BODY:MU / ray).
}

// Angle de phase vers TARGET dans le sens orbital (0-360)
FUNCTION anglePhase {
    LOCAL posNav IS SHIP:POSITION - BODY:POSITION.
    LOCAL posCib IS TARGET:POSITION - BODY:POSITION.
    LOCAL angle IS VANG(posNav, posCib).
    LOCAL momAng IS VCRS(posNav, SHIP:VELOCITY:ORBIT).
    LOCAL croix IS VCRS(posNav, posCib).
    IF VDOT(croix, momAng) > 0 {
        RETURN angle.
    }
    RETURN 360 - angle.
}

// Excentricite de l'orbite actuelle
FUNCTION excentricite {
    RETURN SHIP:ORBIT:ECCENTRICITY.
}
