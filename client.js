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
    console.log("client.js:\t Consent form agree");
    // TODO get instructions and click through, *then* connect to server
    // use instruction click-through in go_fish
    // start timer at onset of instructions, store time on instructions in game state just as a sanity check
    $("body").load("instructions.html"); // TODO replace this with instructions

    connectToServer(game);
}

connectToServer = function(game) {
    // TODO Initialize client game object (may need to initialize other aspects of the game)
    game = new rps_game();
    initialize_game(game);

    // Store a local reference to our connection to the server
    game.socket = io.connect();
    // Handle when we connect to the server, showing state and storing id's.
    game.socket.on('onconnected', client_onconnected.bind(game));
}

client_onconnected = function(data) {
    //The server responded that we are now connected, this lets us store the information about ourselves
    var player = new rps_player(data.id); // create a new player with this information
    player.status = data.status; // TODO do we need to know status here?
    this.player1 = player; // TODO is it hacky to assume we're player1? We need to do something here to keep track of which player we are for future reference
};

initialize_game = function(game) {
    // TODO do the stuff here to set the table for the game (load relevant modules, set game params)
    // see e.g. https://github.com/hawkrobe/MWERT/blob/master/game.client.js#L265
    console.log("client.js:\t initializing game:\n", game);
}
