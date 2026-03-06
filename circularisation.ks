// Circularisation a l'apoapsis
// Usage: RUN circularisation.

RUNONCEPATH("0:/lib/bip.ks").
RUNONCEPATH("0:/lib/nav.ks").
RUNONCEPATH("0:/lib/manoeuvre.ks").

CLEARSCREEN.
PRINT "--- CIRCULARISATION ---" AT (0, 0).

// Vis-viva: vitesse a l'apoapsis sur orbite actuelle
LOCAL rayApo IS BODY:RADIUS + SHIP:APOAPSIS.
LOCAL demiAxe IS BODY:RADIUS + (SHIP:APOAPSIS + SHIP:PERIAPSIS) / 2.
LOCAL vitApo IS SQRT(BODY:MU * (2 / rayApo - 1 / demiAxe)).

// Vitesse circulaire a cette altitude
LOCAL vitCirc IS SQRT(BODY:MU / rayApo).

// Delta-v prograde pour circulariser
LOCAL dvCirc IS vitCirc - vitApo.

PRINT "Apo: " + ROUND(SHIP:APOAPSIS / 1000, 1) + " km" AT (0, 1).
PRINT "Per: " + ROUND(SHIP:PERIAPSIS / 1000, 1) + " km" AT (0, 2).
PRINT "Dv circ: " + ROUND(dvCirc, 1) + " m/s" AT (0, 3).
PRINT "---" AT (0, 4).

// Creer le node a l'apoapsis
LOCAL noeud IS NODE(TIME:SECONDS + ETA:APOAPSIS, 0, 0, dvCirc).
ADD noeud.

PRINT "Node cree a l'apoapsis." AT (0, 5).

// Executer
executerNode().

PRINT "Orbite finale:" AT (0, 11).
PRINT "Apo: " + ROUND(SHIP:APOAPSIS / 1000, 1) + " km" AT (0, 12).
PRINT "Per: " + ROUND(SHIP:PERIAPSIS / 1000, 1) + " km" AT (0, 13).
