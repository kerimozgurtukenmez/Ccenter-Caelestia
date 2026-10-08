import QtQuick
import Caelestia.Config

// Colour transition: duration and easing from Caelestia's tokens
ColorAnimation {
    duration: Tokens.anim.durations.expressiveDefaultEffects
    easing: Tokens.anim.expressiveDefaultEffects
}
