/*
 * Core client-side functionality
 * Some of this is borrowed from https://github.com/hawkrobe/MWERT/blob/master/game.client.js
 */

// global for our game root variable.
var game = {};
// global for keeping track of the player object for this client
var player = {};

$(window).ready(function() {
    $("body").load("consent.html");
});

clickConsent = function() {
    console.log("client.js:\t consent form agree");
    // Get instructions and click through, *then* connect to server
    // use instruction click-through in go_fish
    // start timer at onset of instructions, store time on instructions in game state just as a sanity check

    // TODO replace this with actual instruction flow
    $("body").load("instructions.html", function() {
        $("#next-inst").click(function() {
            connectToServer(window.game);
        });
    });

}

connectToServer = function(game) {
    // TODO Initialize client game object (may need to initialize other aspects of the game)
    game = new rps_game();
    initialize_game(game);

    // store a local reference to our connection to the server
    game.socket = io.connect();

    // Map out function bindings for various messages from the server
    // TODO consider replacing these with a generic message handler that does all parsing
    // OR have a separate function that keeps track of this stuff, or a data structure or something
    game.socket.on('onconnected', client_onconnected.bind(game));
    game.socket.on('newgame', client_waitingroom_enter.bind(game));
    game.socket.on('roundbegin', client_begin_round.bind(game));
    game.socket.on('roundwaiting', client_waiting.bind(game));
    game.socket.on('roundcomplete', client_display_results.bind(game));

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
    //player.game = this;
    // load "waiting for server" page
    client_wait_for_server();
};

// Util function to tell client that it's waiting for opponent
// (client calls this function when the server tells it it's waiting)
client_wait_for_opponent = function() {
    $("body").load("opponent_wait.html");
};

// Util function to tell client that it's waiting for opponent
// (client calls this function when the server tells it it's waiting)
client_wait_for_server = function() {
    $("body").load("server_wait.html");
};


// The server told us we've been assigned to a game but are waiting for a partner.
// We update the state of our game to reflect that, and load a page saying "waiting for partner"
client_waitingroom_enter = function(data) {
    console.log("client.js:\t entered waiting room");
    console.log("client.js:\t game: ", data);
    // TODO update the local game with all relevant info in data
    this.game_id = data.game_id;
    this.game_status = data.game_status;
    this.current_round = JSON.parse(JSON.stringify(data.current_round));
    //console.log(player.game.game_status); // confirms that the player's game is properly bound based on assignment above
    client_wait_for_opponent();
};

// The server told us we can start the next round and sent along the current game state.
// Load a page showing all relevant game state and asking the user to choose a move, count down 10s
client_begin_round = function(data) {
    console.log("client.js:\t beginning round: ", data);
    // TODO update the local game with all relevant info in data if this is the second player and the first round of the game
    if (data.current_round_index == 1) {
        console.log("client.js:\t first round of a new game: ", data)
        this.game_id = data.game_id;
        this.game_status = data.game_status;
    }

    that = this; // copy game object to pass in to move handling code below
    // load "choose your move" page
    $("body").load("round_begin.html", function() {
        // TODO figure out a better way to do this...
        $("#rock-button").click(function() {
            client_submit_move('rock', that);
        });
        $("#paper-button").click(function() {
            client_submit_move('paper', that);
        });
        $("#scissors-button").click(function() {
            client_submit_move('scissors', that);
        });
    });
};

// We've chosen a move, send it to the server and wait until we hear back
client_submit_move = function(move, game) {
    console.log("client.js:\t move chosen: ", move);
    // send move to server
    game.socket.emit("player_move", {"game_id": game.game_id, "move": move});
    // load "waiting for server" page until server updates otherwise
    client_wait_for_server();
};

// The server told us we're waiting for our opponent's move.
// Display the "Waiting for opponent" page
client_waiting = function(data) {
    console.log("client.js:\t waiting for opponent");
    console.log("client.js:\t data: ", data);
    // TODO update the local game with all relevant info in data
    // this.current_round.round_status = data.round_status; // TODO is this necessary??
    client_wait_for_opponent();
};

// We've heard back from the server that the round is complete
// Display the results
client_display_results = function(data) {
    // Determine outcome for this client based on round results
    console.log("results of round: ", data);
    if (player.client_id == data.player1.client_id) {
        client_move = data.current_round.player1_move;
        opponent_move = data.current_round.player2_move;
        client_outcome = data.current_round.player1_outcome;
    } else if (player.client_id == data.player2.client_id) {
        client_move = data.current_round.player2_move;
        opponent_move = data.current_round.player1_move;
        client_outcome = data.current_round.player2_outcome;
    }
    if (client_outcome == "win") {
        outcome_text = "You won this round!";
    } else if (client_outcome == "loss") {
        outcome_text = "You lost this round.";
    } else if (client_outcome == "tie") {
        outcome_text = "This round was a tie.";
    }

    // Display results and transition to next round
    var that = this;
    $("body").load("round_results.html", function() {
        $("#next-round").click(function() {
            client_finish_round(that);
        });
        // Display results
        $("#client-move").text(client_move);
        $("#opponent-move").text(opponent_move);
        $("#result").text(outcome_text);
    });
};

// Tell server that we're ready for the next round and wait to hear back
client_finish_round = function(game) {
    console.log("client.js:\t ready for next round.");
    // send status to server
    game.socket.emit("player_round_complete", {"game_id": game.game_id});
    // load "waiting for server" page until server updates otherwise
    client_wait_for_server();
};
