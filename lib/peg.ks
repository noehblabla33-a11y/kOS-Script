// Powered Explicit Guidance (PEG)
// Guidage terminal a loi de tangente lineaire pour injection orbitale.
// Reference: algorithme du Space Shuttle, adapte pour kOS.
//
// Principe: on cherche les coefficients (A, B) d'une loi de braquage
//   fr(t) = A + B*t   (composante radiale de la poussee unitaire)
// telle que le vehicule atteigne l'etat orbital cible (rayon, vRad, vTan)
// au moment de la coupure moteur, en temps T.
//
// Le solveur itere sur T via la contrainte tangentielle, et resout
// un systeme lineaire 2x2 pour (A, B) via les contraintes radiales.
//
// Necessite: aucune dependance (autonome).

// === ETAT GLOBAL DU GUIDAGE ===
GLOBAL pegConverge IS FALSE.
GLOBAL pegCoefA IS 0.
GLOBAL pegCoefB IS 0.
GLOBAL pegTgo IS 0.
GLOBAL pegTempsRef IS 0.

// Parametres internes
LOCAL _pegIterMax IS 20.
LOCAL _pegTolConverge IS 0.5.
LOCAL _pegAmortissement IS 0.5.
LOCAL _pegCoefAMax IS 0.5.
LOCAL _pegCoefBMax IS 0.1.

// === PARAMETRES VEHICULE ===
FUNCTION paramVehicule {
    LOCAL pousseeN IS 0.
    LOCAL debitKg IS 0.
    LIST ENGINES IN _listeM.
    FOR _m IN _listeM {
        IF _m:IGNITION AND NOT _m:FLAMEOUT {
            LOCAL _pN IS _m:THRUST * 1000.
            SET pousseeN TO pousseeN + _pN.
            IF _m:ISP > 0 {
                SET debitKg TO debitKg + _pN / (_m:ISP * CONSTANT:G0).
            }
        }
    }
    LOCAL masseKg IS MASS * 1000.
    LOCAL veh IS LEXICON().
    veh:ADD("poussee", pousseeN).
    IF debitKg > 0.001 AND masseKg > 0 {
        veh:ADD("ve", pousseeN / debitKg).
        veh:ADD("accel", pousseeN / masseKg).
        veh:ADD("tau", masseKg / debitKg).
        veh:ADD("valide", TRUE).
    } ELSE {
        veh:ADD("ve", 1).
        veh:ADD("accel", 0.001).
        veh:ADD("tau", 99999).
        veh:ADD("valide", FALSE).
    }
    RETURN veh.
}

// === DECOMPOSITION PLAN ORBITAL ===
FUNCTION etatPlanOrb {
    LOCAL _pos IS SHIP:POSITION - BODY:POSITION.
    LOCAL _vel IS SHIP:VELOCITY:ORBIT.
    LOCAL _rayon IS _pos:MAG.
    LOCAL _unitRad IS _pos:NORMALIZED.
    LOCAL _unitNorm IS VCRS(_pos, _vel):NORMALIZED.
    LOCAL _unitTan IS VCRS(_unitNorm, _unitRad):NORMALIZED.
    IF VDOT(_unitTan, _vel) < 0 {
        SET _unitTan TO -_unitTan.
    }
    RETURN LEXICON(
        "rayon", _rayon,
        "vitRad", VDOT(_vel, _unitRad),
        "vitTan", VDOT(_vel, _unitTan),
        "unitRad", _unitRad,
        "unitTan", _unitTan,
        "unitNorm", _unitNorm
    ).
}

// === INTEGRALES DE POUSSEE ===
FUNCTION integralesPoussee {
    PARAMETER _ve.
    PARAMETER _tau.
    PARAMETER _tBurn.

    LOCAL _ratio IS _tBurn / _tau.
    LOCAL _b0 IS -_ve * LN(1 - _ratio).
    LOCAL _b1 IS _b0 * _tau - _ve * _tBurn.
    LOCAL _c0 IS _b0 * _tBurn - _b1.
    LOCAL _c1 IS _c0 * _tau - _ve * _tBurn^2 / 2.
    RETURN LEXICON("b0", _b0, "b1", _b1, "c0", _c0, "c1", _c1).
}

// === CYCLE DE CALCUL PEG ===
FUNCTION cyclePeg {
    PARAMETER rayonCib.
    PARAMETER vitRadCib IS 0.
    PARAMETER vitTanCib IS -1.

    IF vitTanCib < 0 {
        SET vitTanCib TO SQRT(BODY:MU / rayonCib).
    }

    LOCAL _etat IS etatPlanOrb().
    LOCAL _veh IS paramVehicule().
    IF NOT _veh["valide"] {
        SET pegConverge TO FALSE.
        RETURN FALSE.
    }

    LOCAL _r IS _etat["rayon"].
    LOCAL _vr IS _etat["vitRad"].
    LOCAL _vt IS _etat["vitTan"].
    LOCAL _ve IS _veh["ve"].
    LOCAL _tau IS _veh["tau"].

    // Deja au-dela de la vitesse cible : PEG ne sait pas freiner
    IF _vt >= vitTanCib {
        SET pegConverge TO FALSE.
        RETURN FALSE.
    }

    // Gravite effective moyenne (gravite - centripete)
    LOCAL _rMoy IS (_r + rayonCib) / 2.
    LOCAL _vtMoy IS (_vt + vitTanCib) / 2.
    LOCAL _gEff IS BODY:MU / _rMoy^2 - _vtMoy^2 / _rMoy.

    // Estimation initiale de T si non amorce
    IF pegTgo < 1 {
        LOCAL _dvEst IS SQRT((vitTanCib - _vt)^2 + (vitRadCib - _vr)^2).
        SET _dvEst TO MAX(5, _dvEst).
        SET pegTgo TO _tau * (1 - CONSTANT:E ^ (-_dvEst / _ve)).
        SET pegTgo TO MAX(3, MIN(pegTgo, _tau * 0.85)).
    }

    LOCAL _tEst IS MIN(pegTgo, _tau * 0.9).
    LOCAL _converge IS FALSE.
    LOCAL _aCalc IS pegCoefA.
    LOCAL _bCalc IS pegCoefB.

    FROM { LOCAL _it IS 0. } UNTIL _it >= _pegIterMax OR _converge
    STEP { SET _it TO _it + 1. } DO {
        SET _tEst TO MAX(1, MIN(_tEst, _tau * 0.9)).

        LOCAL _integ IS integralesPoussee(_ve, _tau, _tEst).
        LOCAL _b0 IS _integ["b0"].
        LOCAL _b1 IS _integ["b1"].
        LOCAL _c0 IS _integ["c0"].
        LOCAL _c1 IS _integ["c1"].

        LOCAL _qr IS vitRadCib - _vr + _gEff * _tEst.
        LOCAL _sr IS rayonCib - _r - _vr * _tEst + _gEff * _tEst^2 / 2.

        LOCAL _det IS _b0 * _c1 - _b1 * _c0.
        IF ABS(_det) < 0.01 {
            SET _tEst TO _tEst * 1.05.
        } ELSE {
            SET _aCalc TO (_c1 * _qr - _b1 * _sr) / _det.
            SET _bCalc TO (_b0 * _sr - _c0 * _qr) / _det.

            // Bornage strict des coefficients
            SET _aCalc TO MAX(-_pegCoefAMax, MIN(_pegCoefAMax, _aCalc)).
            SET _bCalc TO MAX(-_pegCoefBMax, MIN(_pegCoefBMax, _bCalc)).

            // Contrainte tangentielle -> mise a jour de T
            LOCAL _frMoy IS _aCalc + _bCalc * _tEst / 2.
            SET _frMoy TO MAX(-0.9, MIN(0.9, _frMoy)).
            LOCAL _ftMoy IS SQRT(MAX(0.01, 1 - _frMoy^2)).
            LOCAL _dvTanNec IS vitTanCib - _vt.

            IF _ftMoy > 0.05 AND _dvTanNec > 0 {
                LOCAL _b0Nec IS _dvTanNec / _ftMoy.
                LOCAL _tNouv IS _tau * (1 - CONSTANT:E ^ (-_b0Nec / _ve)).
                SET _tNouv TO MAX(1, MIN(_tNouv, _tau * 0.9)).

                IF ABS(_tNouv - _tEst) < _pegTolConverge {
                    SET _converge TO TRUE.
                }
                SET _tEst TO _tEst + _pegAmortissement * (_tNouv - _tEst).
            }
        }
    }

    // Validation finale : rejeter solutions incoherentes
    IF ABS(_aCalc) >= _pegCoefAMax AND ABS(_bCalc) >= _pegCoefBMax * 0.8 {
        SET _converge TO FALSE.
    }
    IF _tEst < 1 {
        SET _converge TO FALSE.
    }

    SET pegCoefA TO _aCalc.
    SET pegCoefB TO _bCalc.
    SET pegTgo TO _tEst.
    SET pegConverge TO _converge.
    SET pegTempsRef TO TIME:SECONDS.

    RETURN _converge.
}

// === DIRECTION DE POUSSEE ===
FUNCTION dirPeg {
    LOCAL _etat IS etatPlanOrb().
    LOCAL _dt IS TIME:SECONDS - pegTempsRef.
    LOCAL _fr IS pegCoefA + pegCoefB * _dt.
    SET _fr TO MAX(-0.5, MIN(0.5, _fr)).
    LOCAL _ft IS SQRT(MAX(0.01, 1 - _fr^2)).
    RETURN _fr * _etat["unitRad"] + _ft * _etat["unitTan"].
}

// === TEMPS RESTANT ESTIME ===
FUNCTION tgoEstime {
    RETURN pegTgo - (TIME:SECONDS - pegTempsRef).
}

// === REINITIALISATION DOUCE (post-staging) ===
// Conserve Tgo pour aider la reconvergence.
FUNCTION reinitPegDoux {
    SET pegConverge TO FALSE.
    SET pegCoefA TO 0.
    SET pegCoefB TO 0.
    SET pegTempsRef TO TIME:SECONDS.
}

// === REINITIALISATION COMPLETE ===
FUNCTION reinitPeg {
    SET pegConverge TO FALSE.
    SET pegCoefA TO 0.
    SET pegCoefB TO 0.
    SET pegTgo TO 0.
    SET pegTempsRef TO TIME:SECONDS.
}

// === DETECTION DEPASSEMENT ===
// TRUE si le vehicule a deja depasse l'orbite cible
// (vitesse > circulaire, ou trajectoire hyperbolique).
FUNCTION pegDepassement {
    PARAMETER vitTanCib.
    LOCAL _etat IS etatPlanOrb().
    IF _etat["vitTan"] >= vitTanCib RETURN TRUE.
    IF SHIP:ORBIT:ECCENTRICITY >= 1 RETURN TRUE.
    RETURN FALSE.
}
