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
    RCS ON.
    LOCK STEERING TO noeud:DELTAV.

    LOCAL tempsLimite IS TIME:SECONDS + 60.
    WAIT UNTIL VANG(SHIP:FACING:VECTOR, noeud:DELTAV) < 5 OR TIME:SECONDS > tempsLimite.

    IF VANG(SHIP:FACING:VECTOR, noeud:DELTAV) > 5 {
        PRINT "Alignement partiel!    " AT (0, 9).
        bipErreur().
    }
    bipOk().

    // Warp jusqu'a avant l'ignition
    LOCAL tempsIgnition IS TIME:SECONDS + noeud:ETA - dureeBurn / 2.
    IF tempsIgnition - TIME:SECONDS > 30 {
        KUNIVERSE:TIMEWARP:WARPTO(tempsIgnition - 20).
        WAIT UNTIL KUNIVERSE:TIMEWARP:ISSETTLED.
    }

    // Reorienter apres warp (non bloquant, converge pendant l'attente)
    LOCK STEERING TO noeud:DELTAV.

    // Recalculer le temps d'ignition apres le warp
    SET tempsIgnition TO TIME:SECONDS + noeud:ETA - dureeBurn / 2.

    // Attendre le moment d'ignition
    UNTIL TIME:SECONDS >= tempsIgnition {
        PRINT "T-" + ROUND(tempsIgnition - TIME:SECONDS) + " s   " AT (0, 9).
        WAIT 0.1.
    }

    // Burn
    LOCAL dirInitiale IS noeud:DELTAV.
    LOCK THROTTLE TO 1.

    UNTIL FALSE {
        LOCAL dvRestant IS noeud:DELTAV:MAG.

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
    RCS OFF.
    REMOVE noeud.

    bipDouble().
    PRINT "Node execute.              " AT (0, 9).
}
