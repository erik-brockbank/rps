/*
 * Core client-side functionality
 * Some of this is borrowed from https://github.com/hawkrobe/MWERT/blob/master/game.client.js
 */

// A window global for our game root variable.
var game = {};

$(window).ready(function() {
    $("body").load("consent.html");
});

clickConsent = function() {
    console.log("Consent form agree");
    connectToServer(game);
}

connectToServer = function(game) {
    //Store a local reference to our connection to the server
    game.socket = io.connect();
}

