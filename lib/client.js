/*
 * Core client-side functionality
 * Some of this is borrowed from https://github.com/hawkrobe/MWERT/blob/master/game.client.js
 */


// global for keeping track of the player object for this client
var THIS_PLAYER = {};

// Start up: load consent page with callback to start instructions
$(window).ready(function() {
    $("body").load(HTML_LOOKUP["consent"], function() {
        $("#consent-button").click(start_instructions);
    });
});



// Run through instructions with callback to begin socket.io connection for game play
start_instructions = function() {
    console.log("client.js:\t consent form agree");
    // get instructions and click through, then connect to rps game server to be paired with an opponent
    inst = new Instructions(HTML_LOOKUP["instructions"], INSTRUCTION_ARRAY, connect_to_server);
    inst.run();
};


// callback after completion of instructions
connect_to_server = function() {
    var game = {};
    initialize_game(game);
    // store a local reference to our connection to the server
    game.socket = io.connect("", {query: "istest=" + game.istest.toString()});

    // Map out function bindings for various messages from the server
    game.socket.on("onconnected", client_onconnected.bind(THIS_PLAYER)); // message noting that we're connected
    game.socket.on("newgame", waitingroom_enter.bind(game)); // message that we're the first to join a new game
    game.socket.on("roundbegin", begin_round.bind(game)); // message that we're starting a new round (also joining an existing game)
    game.socket.on("roundwaiting_move", waiting_for_move); // message that we're waiting for the opponent to choose a move
    game.socket.on("roundwaiting_continue", waiting_next_round); // message that we're waiting for the opponent to continue to the next round
    game.socket.on("roundcomplete", display_results.bind(game)); // message that we've completed the current round
    game.socket.on("gameover", finish_game); // message that we've completed the game
};


initialize_game = function(game) {
    // URL parsing
    // ex. http://localhost:3000/index.html?&mode=test
    game.istest = false;
    var urlParams = new URLSearchParams(window.location.href);
    if (urlParams.has("mode") && urlParams.get("mode").includes("test")) {
        game.istest = true;
    }
    console.log("client.js:\t initializing game. TEST: ", game.istest);
    // Load game html
    $("body").load(HTML_LOOKUP["experiment"]);
};


// The server responded that we are now connected, this lets us store the information about ourselves
// We then load a page saying "waiting for server" while we're assigned to a game
client_onconnected = function(data) {
    this.client_id = data.id;
    display_message(SERVER_WAIT, hideall = true);
};


// The server told us we've been assigned to a game but are waiting for a partner.
// We update the state of our game to reflect that, and load a page saying "waiting for partner"
waitingroom_enter = function(data) {
    console.log("client.js:\t entered waiting room");
    this.game_id = data.game_id;
    display_message(OPPONENT_WAIT_JOIN, hideall=true);
};


// The server told us we can start the next round and sent along the current game state.
// Load a page showing all relevant game state and asking the user to choose a move, count down 10s
// data passed in here is a copy of the rps_game object
begin_round = function(data) {
    console.log("client.js:\t beginning round with game: ", data);
    if (data.current_round_index == 1) {
        console.log("client.js:\t first round of a new game");
        this.game_id = data.game_id;
    }

    if (THIS_PLAYER.client_id == data.player1.client_id) {
        client_total_points = data.player1_points_total;
        opponent_total_points = data.player2_points_total;
    } else if (THIS_PLAYER.client_id == data.player2.client_id) {
        client_total_points = data.player2_points_total;
        opponent_total_points = data.player1_points_total;
    }
    // functions to handle html transitions for beginning of round
    hide_points();
    hide_next_button();
    reset_move_elements();
    display_message(ROUND_BEGIN, hideall = false);
    initialize_banner_elements(data.current_round_index, data.game_rounds, client_total_points, opponent_total_points);

    // Add button interactivity and start move countdown
    that = this; // copy game object to pass in to move handling code below
    start_countdown(ROUND_TIMEOUT, that);
};


// We've chosen a move, send it to the server and wait until we hear back
submit_move = function(move, rt, game) {
    console.log("client.js:\t move chosen: ", move);
    game.socket.emit("player_move", {"move": move, "rt": rt});
    display_message(SERVER_WAIT, hideall=false);
};


// The server told us we're waiting for our opponent's move.
// Display the "Waiting for opponent" page
waiting_for_move = function() {
    console.log("client.js:\t waiting for opponent to select a move");
    display_message(OPPONENT_WAIT_MOVE, hideall=false);
};


// We've heard back from the server that the round is complete: display the results
// data passed in here is a copy of the rps_game object
display_results = function(data) {
    // Determine outcome for this client based on round results
    console.log("client.js:\t displaying results of round with game: ", data);
    if (THIS_PLAYER.client_id == data.player1.client_id) {
        client_move = data.current_round.player1_move;
        opponent_move = data.current_round.player2_move;
        client_outcome = data.current_round.player1_outcome;
        client_round_points = data.current_round.player1_points;
        client_total_points = data.player1_points_total;
        opponent_round_points = data.current_round.player2_points;
        opponent_total_points = data.player2_points_total;
    } else if (THIS_PLAYER.client_id == data.player2.client_id) {
        client_move = data.current_round.player2_move;
        opponent_move = data.current_round.player1_move;
        client_outcome = data.current_round.player2_outcome;
        client_round_points = data.current_round.player2_points;
        client_total_points = data.player2_points_total;
        opponent_round_points = data.current_round.player1_points;
        opponent_total_points = data.player1_points_total;
    }
    if (client_outcome == "win") {
        outcome_text = "You won this round!";
    } else if (client_outcome == "loss") {
        outcome_text = "You lost this round.";
    } else if (client_outcome == "tie") {
        outcome_text = "This round was a tie.";
    }

    // Display html elements relevant to the results
    clear_countdown();
    display_message(outcome_text, hideall = false);
    display_points_update(client_total_points, opponent_total_points, client_round_points, opponent_round_points);
    highlight_opponent_move();
    show_next_button(finish_round.bind(this));
};


// Tell server that we're ready for the next round and wait to hear back
finish_round = function() {
    console.log("client.js:\t ready for next round");
    this.socket.emit("player_round_complete");
    display_message(SERVER_WAIT, hideall=false);
};


// The server told us we're waiting for our opponent to continue to next round
// Display the "Waiting for opponent" page
waiting_next_round = function() {
    console.log("client.js:\t waiting for opponent to continue");
    hide_next_button();
    display_message(OPPONENT_WAIT_CONTINUE, hideall=false);
};


// Received message from server that game is complete (or opponent left unexpectedly):
// take participant to relevant termination page
finish_game = function() {
    console.log("client.js:\t received game over.");
    hide_points();
    hide_next_button();
    clear_countdown();
    display_message(EXIT_MESSAGE, hideall=true);
};
