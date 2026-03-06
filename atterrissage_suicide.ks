// Atterrissage suicide burn sur corps sans atmosphere
// Usage: RUN atterrissage_sb. ou RUN atterrissage_sb(5000, 1.05).

PARAMETER altDeorbit IS 5000.
PARAMETER marge IS 1.05.

RUNONCEPATH("0:/lib/bip.ks").
RUNONCEPATH("0:/lib/staging.ks").
RUNONCEPATH("0:/lib/nav.ks").

CLEARSCREEN.
PRINT "--- ATTERRISSAGE SB ---" AT (0,0).
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

LOCAL tempsAvantPe IS dureeFreinage() * 3.
IF ETA:PERIAPSIS > tempsAvantPe + 30 {
    KUNIVERSE:TIMEWARP:WARPTO(TIME:SECONDS + ETA:PERIAPSIS - tempsAvantPe).
}

LOCK STEERING TO SRFRETROGRADE.

// Attendre d'etre en descente
WAIT UNTIL SHIP:VERTICALSPEED < -1.

// Attendre le point de freinage
WAIT UNTIL distFreinage() * marge >= ALT:RADAR.

// === PHASE 3: SUICIDE BURN ===
PRINT "Phase: suicide burn    " AT (0,6).
demarrerAutoStaging().
GEAR ON.
bipOk().

LOCK THROTTLE TO 1.
LOCK STEERING TO SRFRETROGRADE.

// Plein gaz jusqu'a vitesse faible
UNTIL SHIP:VELOCITY:SURFACE:MAG < 30 OR SHIP:STATUS = "LANDED" OR SHIP:STATUS = "SPLASHED" {
    PRINT "Alt: " + ROUND(ALT:RADAR) + " m    " AT (0,10).
    PRINT "Vit: " + ROUND(SHIP:VELOCITY:SURFACE:MAG) + " m/s    " AT (0,11).
    PRINT "Vv: " + ROUND(SHIP:VERTICALSPEED, 1) + " m/s    " AT (0,12).
    WAIT 0.05.
}

// Coussin final: pointer vertical, freiner jusqu'au sol
PRINT "Phase: coussin final   " AT (0,6).
LOCK STEERING TO LOOKDIRUP(UP:VECTOR, SHIP:FACING:TOPVECTOR).

UNTIL SHIP:STATUS = "LANDED" OR SHIP:STATUS = "SPLASHED" {
    LOCAL grv IS graviteLocale().
    LOCAL acc IS accelMax().
    LOCAL erreur IS -1 - SHIP:VERTICALSPEED.
    LOCAL throt IS (grv + erreur * 0.8) / acc.
    LOCK THROTTLE TO MAX(0.01, MIN(1, throt)).

    PRINT "Alt: " + ROUND(ALT:RADAR) + " m    " AT (0,10).
    PRINT "Vv: " + ROUND(SHIP:VERTICALSPEED, 1) + " m/s    " AT (0,12).
    WAIT 0.05.
}

// === TOUCHDOWN ===
UNLOCK THROTTLE.
UNLOCK STEERING.
arreterAutoStaging().

bipDouble().
WAIT 0.5.
bipDouble().

PRINT "Pose reussie sur " + BODY:NAME + "!" AT (0,14).
