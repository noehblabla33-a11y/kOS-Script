// Atterrissage suicide burn sur corps sans atmosphere
// Optimise pour minimiser le carburant (freinage tardif, pas de hover).
// Compatible Kerbalism (ignition unique phase freinage).
// Usage: RUN atterrissage_suicide. ou RUN atterrissage_suicide(5000, 1.08).

PARAMETER altDeorbit IS 5000.
PARAMETER marge IS 1.08.

RUNONCEPATH("0:/lib/bip.ks").
RUNONCEPATH("0:/lib/staging.ks").
RUNONCEPATH("0:/lib/nav.ks").

// --- Fonctions locales ---

// Altitude perdue pendant un freinage retrograde complet
// Sur un corps sans atmo, pres du PE la vitesse est quasi horizontale.
// Pendant le burn retrograde :
//   - la vitesse verticale initiale fait perdre de l'altitude
//   - la gravite accelere la chute MAIS la poussee retrograde pivote
//     progressivement vers le vertical et compense de plus en plus
// On applique un facteur 0.4 sur la gravite pour refleter cette compensation.
FUNCTION altPerdueDurantFreinage {
    IF SHIP:VERTICALSPEED >= 0 RETURN 0.

    LOCAL grv IS graviteLocale().
    LOCAL acc IS accelMax().
    LOCAL vit IS SHIP:VELOCITY:SURFACE:MAG.
    LOCAL vitVert IS ABS(SHIP:VERTICALSPEED).

    // Temps pour freiner toute la vitesse surface
    LOCAL tempsFrein IS vit / MAX(0.1, acc).

    // Altitude perdue par la composante verticale (diminue pendant le burn)
    LOCAL hVitesse IS vitVert * tempsFrein * 0.5.

    // Altitude perdue par la gravite (attenuee par la poussee qui pivote)
    LOCAL hGravite IS 0.5 * grv * tempsFrein^2 * 0.4.

    RETURN hVitesse + hGravite.
}

// Vitesse de descente cible selon altitude (agressive pour suicide burn)
FUNCTION vitDescCible {
    PARAMETER altSol.
    IF altSol > 100 RETURN -8.
    IF altSol > 30  RETURN -4.
    IF altSol > 10  RETURN -2.
    IF altSol > 3   RETURN -1.
    RETURN -0.5.
}

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
UNLOCK THROTTLE.
bipDouble().

// === PHASE 2: COAST VERS PE ===
PRINT "Phase: coast           " AT (0,6).

// Attendre stabilisation avant warp (pas d'accel residuelle)
WAIT 2.

LOCAL tempsAvantPe IS dureeFreinage() * 3.
IF ETA:PERIAPSIS > tempsAvantPe + 30 {
    KUNIVERSE:TIMEWARP:WARPTO(TIME:SECONDS + ETA:PERIAPSIS - tempsAvantPe).
    WAIT UNTIL KUNIVERSE:TIMEWARP:ISSETTLED.
}

LOCK STEERING TO SRFRETROGRADE.

// Attendre d'etre en descente
WAIT UNTIL SHIP:VERTICALSPEED < -1.

// Attendre le point de freinage
WAIT UNTIL altPerdueDurantFreinage() * marge >= ALT:RADAR.

// === PHASE 3: SUICIDE BURN ===
PRINT "Phase: suicide burn    " AT (0,6).
demarrerAutoStaging().
GEAR ON.
RCS ON.
bipOk().

// Direction de freinage capturee, mise a jour seulement quand
// le vaisseau est aligne. Empeche les pirouettes quand le vecteur
// retrograde pivote plus vite que le vaisseau ne peut tourner.
LOCAL dirFreinage IS SHIP:SRFRETROGRADE:VECTOR.
LOCK STEERING TO dirFreinage.
LOCK THROTTLE TO 1.

// Freinage principal : plein gaz retrograde jusqu'a vitesse faible
UNTIL SHIP:VELOCITY:SURFACE:MAG < 8 OR SHIP:STATUS = "LANDED" OR SHIP:STATUS = "SPLASHED" {
    // Mettre a jour la cible seulement si le vaisseau suit bien
    IF VANG(SHIP:FACING:VECTOR, dirFreinage) < 15 {
        SET dirFreinage TO SHIP:SRFRETROGRADE:VECTOR.
    }

    PRINT "Alt: " + ROUND(ALT:RADAR) + " m    " AT (0,10).
    PRINT "Vit: " + ROUND(SHIP:VELOCITY:SURFACE:MAG) + " m/s    " AT (0,11).
    PRINT "Vv: " + ROUND(SHIP:VERTICALSPEED, 1) + " m/s    " AT (0,12).
    WAIT 0.05.
}

// === PHASE 4: COUSSIN FINAL ===
// Descente rapide avec vitesse cible progressive, pas de hover
PRINT "Phase: coussin final   " AT (0,6).
LOCK STEERING TO LOOKDIRUP(UP:VECTOR, SHIP:FACING:TOPVECTOR).

UNTIL SHIP:STATUS = "LANDED" OR SHIP:STATUS = "SPLASHED" {
    LOCAL altSol IS ALT:RADAR.
    LOCAL grv IS graviteLocale().
    LOCAL acc IS accelMax().
    LOCAL vCible IS vitDescCible(altSol).
    LOCAL erreur IS vCible - SHIP:VERTICALSPEED.

    // Tuer aussi l'horizontale residuelle
    LOCAL corrHoriz IS 0.
    IF GROUNDSPEED > 0.5 AND altSol > 5 {
        SET corrHoriz TO MIN(0.15, GROUNDSPEED * 0.05).
    }

    LOCAL throt IS (grv + erreur * 1.2) / acc + corrHoriz.
    LOCK THROTTLE TO MAX(0.01, MIN(1, throt)).

    // Retrograde si encore de l'horizontale, vertical sinon
    IF GROUNDSPEED > 2 AND altSol > 10 {
        LOCK STEERING TO SRFRETROGRADE.
    } ELSE {
        LOCK STEERING TO LOOKDIRUP(UP:VECTOR, SHIP:FACING:TOPVECTOR).
    }

    PRINT "Alt: " + ROUND(altSol) + " m    " AT (0,10).
    PRINT "Vv: " + ROUND(SHIP:VERTICALSPEED, 1) + " m/s    " AT (0,11).
    PRINT "Vh: " + ROUND(GROUNDSPEED, 1) + " m/s    " AT (0,12).
    WAIT 0.05.
}

// === TOUCHDOWN ===
UNLOCK THROTTLE.
UNLOCK STEERING.
RCS OFF.
arreterAutoStaging().

bipDouble().
WAIT 0.5.
bipDouble().

PRINT "Pose reussie sur " + BODY:NAME + "!" AT (0,14).
