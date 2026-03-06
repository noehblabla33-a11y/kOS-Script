// Atterrissage guide sur corps sans atmosphere
// Usage: RUN atterrissage. ou RUN atterrissage(5000, 1.15).

PARAMETER altDeorbit IS 5000.
PARAMETER marge IS 1.15.

RUNONCEPATH("0:/lib/bip.ks").
RUNONCEPATH("0:/lib/staging.ks").
RUNONCEPATH("0:/lib/nav.ks").

// Vitesse verticale cible selon altitude radar
FUNCTION vitesseDescCible {
    PARAMETER altSol.
    IF altSol > 1000 RETURN -40.
    IF altSol > 200  RETURN -15.
    IF altSol > 50   RETURN -5.
    IF altSol > 10   RETURN -2.
    RETURN -0.5.
}

CLEARSCREEN.
PRINT "--- ATTERRISSAGE ---" AT (0,0).
PRINT "Corps: " + BODY:NAME AT (0,1).
PRINT "PE deorbit: " + altDeorbit + " m" AT (0,2).

// Verif atmosphere
IF BODY:ATM:EXISTS {
    PRINT "ATTENTION: atmosphere detectee!" AT (0,4).
    bipErreur().
}

// Verif TWR
LOCAL twr IS twrLocal().
PRINT "TWR local: " + ROUND(twr, 2) AT (0,3).
IF twr < 1.5 {
    PRINT "ATTENTION: TWR faible!" AT (0,4).
    bipErreur().
}

SAS OFF.

// === PHASE 1: DEORBIT ===
PRINT "Phase: deorbit         " AT (0,6).

LOCAL rayDep IS BODY:RADIUS + SHIP:ALTITUDE.
LOCAL rayArr IS BODY:RADIUS + altDeorbit.
LOCAL demiAxe IS (rayDep + rayArr) / 2.
LOCAL vOrbite IS SHIP:VELOCITY:ORBIT:MAG.
LOCAL vTransfert IS SQRT(BODY:MU * (2/rayDep - 1/demiAxe)).
LOCAL dvDeorbit IS vOrbite - vTransfert.

PRINT "Dv deorbit: " + ROUND(dvDeorbit, 1) + " m/s" AT (0,7).

LOCK STEERING TO RETROGRADE.
WAIT UNTIL VANG(SHIP:FACING:VECTOR, RETROGRADE:VECTOR) < 2.
bipOk().

LOCAL vitDep IS SHIP:VELOCITY:ORBIT:MAG.
LOCK THROTTLE TO 1.
WAIT UNTIL vitDep - SHIP:VELOCITY:ORBIT:MAG >= dvDeorbit.
LOCK THROTTLE TO 0.

PRINT "PE: " + ROUND(SHIP:PERIAPSIS) + " m   " AT (0,8).
bipDouble().

// === PHASE 2: COAST VERS PE ===
PRINT "Phase: coast           " AT (0,6).

// Warp avec marge genereuse
LOCAL tempsAvantPe IS dureeFreinage() * 3.
IF ETA:PERIAPSIS > tempsAvantPe + 30 {
    KUNIVERSE:TIMEWARP:WARPTO(TIME:SECONDS + ETA:PERIAPSIS - tempsAvantPe).
}

LOCK STEERING TO SRFRETROGRADE.

// Attendre d'etre en descente
WAIT UNTIL SHIP:VERTICALSPEED < -1.

// Attendre le point de freinage
WAIT UNTIL distFreinage() * marge >= ALT:RADAR.

// === PHASE 3: FREINAGE ===
PRINT "Phase: freinage        " AT (0,6).
demarrerAutoStaging().
bipOk().

LOCK THROTTLE TO 1.
LOCK STEERING TO SRFRETROGRADE.

// Freiner jusqu'a vitesse gerable
UNTIL SHIP:VELOCITY:SURFACE:MAG < 50 OR ALT:RADAR < 500 {
    PRINT "Alt: " + ROUND(ALT:RADAR) + " m    " AT (0,10).
    PRINT "Vit: " + ROUND(SHIP:VELOCITY:SURFACE:MAG) + " m/s    " AT (0,11).
    WAIT 0.1.
}

// === PHASE 4: DESCENTE GUIDEE ===
PRINT "Phase: descente finale " AT (0,6).
GEAR ON.
bipOk().

UNTIL SHIP:STATUS = "LANDED" OR SHIP:STATUS = "SPLASHED" {
    LOCAL altSol IS ALT:RADAR.
    LOCAL vCible IS vitesseDescCible(altSol).
    LOCAL vVert IS SHIP:VERTICALSPEED.
    LOCAL grv IS graviteLocale().
    LOCAL acc IS accelMax().

    // Throttle: compenser gravite + corriger vers vitesse cible
    LOCAL erreur IS vCible - vVert.
    LOCAL throt IS (grv + erreur * 0.8) / acc.
    LOCK THROTTLE TO MAX(0, MIN(1, throt)).

    // Direction: tuer l'horizontal si besoin, sinon vertical
    IF GROUNDSPEED > 2 {
        LOCK STEERING TO SRFRETROGRADE.
    } ELSE {
        LOCK STEERING TO LOOKDIRUP(UP:VECTOR, SHIP:FACING:TOPVECTOR).
    }

    PRINT "Alt: " + ROUND(altSol) + " m    " AT (0,10).
    PRINT "Vv: " + ROUND(vVert, 1) + " m/s    " AT (0,11).
    PRINT "Vh: " + ROUND(GROUNDSPEED, 1) + " m/s    " AT (0,12).
    WAIT 0.05.
}

// === TOUCHDOWN ===
LOCK THROTTLE TO 0.
UNLOCK THROTTLE.
UNLOCK STEERING.
arreterAutoStaging().

bipDouble().
WAIT 0.5.
bipDouble().

PRINT "Pose reussie sur " + BODY:NAME + "!" AT (0,14).
