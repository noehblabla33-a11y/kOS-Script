// Executeur de maneuver node

// Execute le prochain node du plan de vol
FUNCTION executerNode {
    IF NOT HASNODE {
        PRINT "Pas de node a executer!".
        bipErreur().
        RETURN.
    }

    LOCAL noeud IS NEXTNODE.
    LOCAL dvTotal IS noeud:DELTAV:MAG.
    LOCAL acc IS accelMax().
    LOCAL dureeBurn IS dvTotal / acc.

    PRINT "Dv: " + ROUND(dvTotal, 1) + " m/s" AT (0, 7).
    PRINT "Burn: " + ROUND(dureeBurn, 1) + " s" AT (0, 8).

    // Orienter vers le node
    LOCK STEERING TO noeud:DELTAV.
    WAIT UNTIL VANG(SHIP:FACING:VECTOR, noeud:DELTAV) < 1.
    bipOk().

    // Warp jusqu'a T - dureeBurn/2
    LOCAL tempsIgnition IS TIME:SECONDS + noeud:ETA - dureeBurn / 2.
    IF tempsIgnition - TIME:SECONDS > 10 {
        KUNIVERSE:TIMEWARP:WARPTO(tempsIgnition - 5).
    }
    WAIT UNTIL TIME:SECONDS >= tempsIgnition.

    // Burn
    LOCAL dvRestant IS 0.
    LOCAL dirInitiale IS noeud:DELTAV.
    LOCK THROTTLE TO 1.

    UNTIL FALSE {
        SET dvRestant TO noeud:DELTAV:MAG.

        // Throttle fin pour precision
        IF dvRestant < 5 {
            LOCK THROTTLE TO MAX(0.01, dvRestant / accelMax()).
        }

        PRINT "Dv restant: " + ROUND(dvRestant, 1) + " m/s   " AT (0, 9).

        // Arreter si le vecteur dv a bascule (on a depasse)
        IF VANG(noeud:DELTAV, dirInitiale) > 90 {
            BREAK.
        }
        // Arreter si quasi nul
        IF dvRestant < 0.1 {
            BREAK.
        }
        WAIT 0.01.
    }

    LOCK THROTTLE TO 0.
    UNLOCK STEERING.
    UNLOCK THROTTLE.
    REMOVE noeud.

    bipDouble().
    PRINT "Node execute.              " AT (0, 9).
}
