/*
 * Core client-side functionality
 * Some of this is borrowed from https://github.com/hawkrobe/MWERT/blob/master/game.client.js
 */

// A window global for our game root variable.
var game = {};
// global for keeping track of the player object for this client
var player = {};

$(window).ready(function() {
    $("body").load("consent.html");
});

clickConsent = function() {
    console.log("client.js:\t Consent form agree");
    // Get instructions and click through, *then* connect to server
    // use instruction click-through in go_fish
    // start timer at onset of instructions, store time on instructions in game state just as a sanity check
    $("body").load("instructions.html"); // TODO replace this with instructions

    // Once instructions are done, connect to server (this call will probably go elsewhere)
    connectToServer(game);
}

connectToServer = function(game) {
    // TODO Initialize client game object (may need to initialize other aspects of the game)
    game = new rps_game();
    initialize_game(game);

    // Store a local reference to our connection to the server
    game.socket = io.connect();

    // Map out function bindings for various messages from the server
    // TODO consider replacing these with a generic message handler that does all parsing
    // OR have a separate function that keeps track of this stuff, or a data structure or something
    game.socket.on('onconnected', client_onconnected.bind(game));
    game.socket.on('newgame', client_waitingroom_enter.bind(game));
    game.socket.on('roundbegin', client_begin_round.bind(game));
}

initialize_game = function(game) {
    // TODO do the stuff here to set the table for the game (load relevant modules, set game params)
    // see e.g. https://github.com/hawkrobe/MWERT/blob/master/game.client.js#L265
    console.log("client.js:\t initializing game:\n", game);
}

// The server responded that we are now connected, this lets us store the information about ourselves
// We then load a page saying "waiting for server" while we're assigned to a game
client_onconnected = function(data) {
    player = new rps_player(data.id); // create a new player with this information
    player.status = data.status;
    player.game = this;
    // TODO load "waiting for server" page
};

// The server told us we've been assigned to a game but are waiting for a partner.
// We update the state of our game to reflect that, and load a page saying "waiting for partner"
client_waitingroom_enter = function(data) {
    console.log("Entered waiting room");
    console.log("Game status: ", data.game_status);
    // TODO update the local game with all relevant info in data
    this.game_status = data.game_status;
    //console.log(player.game.game_status); // confirms that the player's game is properly bound based on assignment above

    // TODO load "waiting for opponent" page
};

// The server told us we can start the next round and sent along the current game state.
// Load a page showing all relevant game state and asking the user to choose a move, count down 10s
client_begin_round = function(data) {
    console.log("Beginning round: ", data.current_round);

    // TODO load "choose your move" page

};
