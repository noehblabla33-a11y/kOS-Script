// Circularisation a l'apoapsis ou au periapsis
// Usage: RUN circularisation. ou RUN circularisation("per").

PARAMETER mode IS "apo".

RUNONCEPATH("0:/lib/bip.ks").
RUNONCEPATH("0:/lib/nav.ks").
RUNONCEPATH("0:/lib/manoeuvre.ks").

CLEARSCREEN.
PRINT "--- CIRCULARISATION ---" AT (0, 0).

LOCAL demiAxe IS SHIP:ORBIT:SEMIMAJORAXIS.

LOCAL rayPoint IS 0.
LOCAL etaPoint IS 0.
LOCAL labelPoint IS "".

IF mode = "per" {
    SET rayPoint TO BODY:RADIUS + SHIP:PERIAPSIS.
    SET etaPoint TO ETA:PERIAPSIS.
    SET labelPoint TO "periapsis".
} ELSE {
    SET rayPoint TO BODY:RADIUS + SHIP:APOAPSIS.
    SET etaPoint TO ETA:APOAPSIS.
    SET labelPoint TO "apoapsis".
}

// Vis-viva: vitesse au point choisi
LOCAL vitPoint IS SQRT(BODY:MU * (2 / rayPoint - 1 / demiAxe)).

// Vitesse circulaire a cette altitude
LOCAL vitCirc IS SQRT(BODY:MU / rayPoint).

// Delta-v pour circulariser
LOCAL dvCirc IS vitCirc - vitPoint.

PRINT "Mode: " + labelPoint AT (0, 1).
PRINT "Apo: " + ROUND(SHIP:APOAPSIS / 1000, 1) + " km" AT (0, 2).
PRINT "Per: " + ROUND(SHIP:PERIAPSIS / 1000, 1) + " km" AT (0, 3).
PRINT "Dv circ: " + ROUND(dvCirc, 1) + " m/s" AT (0, 4).
PRINT "---" AT (0, 5).

// Creer le node
LOCAL noeud IS NODE(TIME:SECONDS + etaPoint, 0, 0, dvCirc).
ADD noeud.

PRINT "Node cree a " + labelPoint + "." AT (0, 6).

// Executer
executerNode().

PRINT "Orbite finale:" AT (0, 11).
PRINT "Apo: " + ROUND(SHIP:APOAPSIS / 1000, 1) + " km" AT (0, 12).
PRINT "Per: " + ROUND(SHIP:PERIAPSIS / 1000, 1) + " km" AT (0, 13).
