class_name Combat
extends RefCounted
## Shared combat vocabulary, in its own file on purpose.
##
## Fighter already holds exported references to Hitbox and Hurtbox, and both of
## those need to reference Fighter back. Putting these enums and constants on
## Fighter would mean Hitbox reading a constant off a class that is mid-resolve,
## which is exactly the cyclic-dependency parse error GDScript trips on.
## Combat depends on nothing, so everyone can safely depend on it.
## Never instantiated.

## Which vertical band an attack occupies. A defender whose stance sits in the
## opposite band is missed entirely. MID cannot be stance-dodged at all: you
## avoid those by leaning out of range, which keeps horizontal spacing relevant.
##
##   attack \ stance | CROUCHED | NEUTRAL | RAISED
##   LOW             |   hit    |   hit   |  WHIFF
##   MID             |   hit    |   hit   |   hit
##   HIGH            |  WHIFF   |   hit   |   hit
enum Height {LOW, MID, HIGH}

enum Stance {CROUCHED, NEUTRAL, RAISED}

## How long a defender is invulnerable after being hit. Deliberately NOT the
## same value as attack recovery: sharing one constant meant a fast move handed
## the opponent two full seconds of immunity.
const HITSTUN_TIME := 0.6

## Fraction of max vertical lean that counts as raised or crouched.
const STANCE_THRESHOLD := 0.55

## Fraction of stick deflection needed to select a directional move.
const STICK_DIR_THRESHOLD := 0.5
