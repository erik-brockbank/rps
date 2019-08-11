/*
 * Core client-side functionality
 * Some of this is borrowed from https://github.com/hawkrobe/MWERT/blob/master/game.client.js
 */

// global for keeping track of the player object for this client
var player = {};


// Start up
$(window).ready(function() {
    $("body").load(HTMLPATH + "/" + "consent.html", function() {
        $("#consent-button").click(clickConsent);
    });
});

// Proceed from consent form to instructions
clickConsent = function() {
    console.log("client.js:\t consent form agree");
    // Get instructions and click through, *then* connect to server
    inst_path = HTMLPATH + "/" + "instructions.html";
    inst = new Instructions(inst_path, INSTRUCTION_ARRAY, connectToServer);
    inst.run();

};

// callback after completion of instructions
connectToServer = function() {
    var game = {};
    initializeGame(game);
    // store a local reference to our connection to the server
    game.socket = io.connect("", {query: "istest=" + game.istest.toString()});

    // Map out function bindings for various messages from the server
    // TODO consider replacing these with a generic message handler that does all parsing
    // OR have a separate function that keeps track of this stuff, or a data structure or something
    game.socket.on("onconnected", client_onconnected);
    game.socket.on("newgame", client_waitingroom_enter.bind(game));
    game.socket.on("roundbegin", client_begin_round.bind(game));
    game.socket.on("roundwaiting", client_waiting);
    game.socket.on("roundcomplete", client_display_results.bind(game));
    game.socket.on("gameover", client_finish_game);
};

initializeGame = function(game) {
    // URL parsing
    // ex. http://localhost:8000/exp.html?&mode=test
    game.istest = false;
    var urlParams = new URLSearchParams(window.location.href);
    if (urlParams.has("mode") && urlParams.get("mode").includes("test")) {
        console.log("client.js\t TEST");
        game.istest = true;
    }
    console.log("client.js:\t initializing game:\n", game);
    // Load game html
    $("body").load(HTMLPATH + "/" + "round_template.html"); // TODO make a lookup table with parse-able names and html pages/paths
    $("game-container").css({visibility:"hidden"});
};

// Util function to display a message in the message container
clientDisplayMessage = function(msg, hideall) {
    if (hideall) {
        $("#game-container").css({visibility:"hidden"});
    }
    $("#message-container").text(msg);
}

// The server responded that we are now connected, this lets us store the information about ourselves
// We then load a page saying "waiting for server" while we're assigned to a game
client_onconnected = function(data) {
    player.client_id = data.id;
    player.status = data.status;
    // load "waiting for server" message
    var wait_msg = "Waiting for server...";
    clientDisplayMessage(wait_msg, hideall=true);
};


// Function to dynamically load/populate html elements for showing the beginning of a round
client_begin_round_html = function(current_round_index, game_rounds, client_total_points, opponent_total_points) {
    // Hide elements that shouldn't be shown
    // TODO make a separate function e.g. reset_elements()
    $("#exp-button-container").css({visibility: "hidden"});
    $("#client-points-update").css({visibility: "hidden"});
    $("#opponent-points-update").css({visibility: "hidden"});
    $(".move-button-container").css({background:"none"});
    $(".opponent-move").css({border:"none"});

    // Message information for beginning round
    $("#message-container").text("Choose a move!"); // TODO make this message global? Make all messages global/constants?

    // Banner information for beginning round (round index, time remaining)
    $("#round-index").text(current_round_index + "/" + game_rounds);
    $("#client-points-total").text("Total: " + client_total_points);
    $("#opponent-points-total").text("Total: " + opponent_total_points);
    $("#game-container").css({visibility:"visible"});
};


// Function to dynamically load/populate html elements for showing round results
client_display_results_html = function(outcome, opponent_move, client_points, opponent_points,
    client_total_points, opponent_total_points) {
    // Hide relevant elements
    clearInterval(interval);
    $("#time-info").css({visibility: "hidden"});
    // Show relevant information
    $("#message-container").text(outcome);
    $("#client-points-total").text("Total: " + client_total_points);
    $("#opponent-points-total").text("Total: " + opponent_total_points);
    if (client_points >= 0) {client_points = "+" + client_points;}
    if (opponent_points >= 0) {opponent_points = "+" + opponent_points;}
    $("#client-points-update").text(client_points);
    $("#opponent-points-update").text(opponent_points);
    // Highlight opponent move
    if (opponent_move == "none") {
        $("#opponent-move-rock").css({background:"gray"});
        $("#opponent-move-paper").css({background:"gray"});
        $("#opponent-move-scissors").css({background:"gray"});
    } else {
        $("#opponent-move-" + opponent_move).css({background:"f44336"});
    }

    $("#exp-button-container").css({visibility: "visible"});
    $("#client-points-update").css({visibility: "visible"});
    $("#opponent-points-update").css({visibility: "visible"});
}

// The server told us we've been assigned to a game but are waiting for a partner.
// We update the state of our game to reflect that, and load a page saying "waiting for partner"
client_waitingroom_enter = function(data) {
    console.log("client.js:\t entered waiting room");
    this.game_id = data.game_id;
    this.game_status = data.game_status;
    this.current_round = JSON.parse(JSON.stringify(data.current_round)); // TODO this seems unnecessary
    var wait_msg = "Waiting for another opponent to join...";
    clientDisplayMessage(wait_msg, hideall=true);
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

    if (player.client_id == data.player1.client_id) {
        client_total_points = data.player1_points_total;
        opponent_total_points = data.player2_points_total;
    } else if (player.client_id == data.player2.client_id) {
        client_total_points = data.player2_points_total;
        opponent_total_points = data.player1_points_total;
    }

    var moveChosen = false;
    client_begin_round_html(data.current_round_index, data.game_rounds, client_total_points, opponent_total_points);
    // Add button interactivity
    // TODO figure out how to make this more streamlined (basically the same code thrice...)
    that = this; // copy game object to pass in to move handling code below
    $("#client-move-rock").click(function() {
        moveChosen = true;
        $(this).css({background:"#4CAF50"});
        // make this and other buttons unclickable
        $(this).unbind("click");
        $("#client-move-paper").unbind("click");
        $("#client-move-scissors").unbind("click");
        resp_time = new Date().getTime() - start_time_ms; // ms since start_time_ms
        client_submit_move("rock", resp_time, that);
    });
    $("#client-move-paper").click(function() {
        moveChosen = true;
        $(this).css({background:"#4CAF50"});
        // make this and other buttons unclickable
        $(this).unbind("click");
        $("#client-move-rock").unbind("click");
        $("#client-move-scissors").unbind("click");
        resp_time = new Date().getTime() - start_time_ms; // ms since start_time_ms
        client_submit_move("paper", resp_time, that);
    });
    $("#client-move-scissors").click(function() {
        moveChosen = true;
        $(this).css({background:"#4CAF50"});
        // make this and other buttons unclickable
        $(this).unbind("click");
        $("#client-move-rock").unbind("click");
        $("#client-move-paper").unbind("click");
        resp_time = new Date().getTime() - start_time_ms; // ms since start_time_ms
        client_submit_move("scissors", resp_time, that);
    });

    // Start the countdown clock for selecting a move
    start_time = Date.parse(new Date()); // timer for ROUND_TIMEOUT countdown (rounds to nearest second)
    start_time_ms = new Date().getTime(); // more accurate timer for participant responses
    end_time = start_time + (1000 * ROUND_TIMEOUT); // number of seconds for each round * 1000 since timestamp includes ms
    remaining = (end_time - (Date.parse(new Date()))) / 1000; // calculate seconds remaining (rounds to nearest second)
    $("#countdown").text(remaining);
    interval = setInterval(function() {
        remaining = (end_time - (Date.parse(new Date()))) / 1000; // calculate seconds remaining
        $("#countdown").text(remaining);
        if (remaining <= 0) {
            clearInterval(interval);
            if (!moveChosen) {
                $("#client-move-rock").unbind("click");
                $("#client-move-paper").unbind("click");
                $("#client-move-scissors").unbind("click");
                resp_time = ROUND_TIMEOUT * 1000 // max response time (ms)
                client_submit_move("none", resp_time, that);
            }
        }
    }, 1000);
    $("#time-info").css({visibility:"visible"});
};

// We've chosen a move, send it to the server and wait until we hear back
client_submit_move = function(move, rt, game) {
    console.log("client.js:\t move chosen: ", move);
    // send move to server
    game.socket.emit("player_move", {"move": move, "rt": rt});
    // load "waiting for server" message until server updates otherwise
    var wait_msg = "Waiting for server...";
    clientDisplayMessage(wait_msg, hideall=false);
};

// The server told us we're waiting for our opponent's move.
// Display the "Waiting for opponent" page
client_waiting = function(data) {
    console.log("client.js:\t waiting for opponent");
    $("#exp-button-container").css({visibility: "hidden"});
    var wait_msg = data.status + "...";
    clientDisplayMessage(wait_msg, hideall=false);
};

// We've heard back from the server that the round is complete: display the results
client_display_results = function(data) {
    // Determine outcome for this client based on round results
    console.log("results of round: ", data);
    if (player.client_id == data.player1.client_id) {
        client_move = data.current_round.player1_move;
        opponent_move = data.current_round.player2_move;
        client_outcome = data.current_round.player1_outcome;
        client_round_points = data.current_round.player1_points;
        client_total_points = data.player1_points_total;
        opponent_round_points = data.current_round.player2_points;
        opponent_total_points = data.player2_points_total;
    } else if (player.client_id == data.player2.client_id) {
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

    client_display_results_html(outcome_text, opponent_move,
        client_round_points, opponent_round_points,
        client_total_points, opponent_total_points);

    var that = this;
    $("#next-round").unbind().click(function() {
        client_finish_round(that);
    });
};

// Tell server that we're ready for the next round and wait to hear back
client_finish_round = function(game) {
    console.log("client.js:\t ready for next round.");
    // send status to server
    game.socket.emit("player_round_complete", {});
    // load "waiting for server" message until server updates otherwise
    var wait_msg = "Waiting for server...";
    clientDisplayMessage(wait_msg, hideall=false);
};

// Received message from server that game is complete (or opponent left unexpectedly)
// Take participant to relevant termination page
client_finish_game = function(data) {
    console.log("client.js:\t received game over.");
    var exit_msg = "All done. Thanks for playing!";
    clientDisplayMessage(exit_msg, hideall=true);
    // TODO this is hacky, not sure why we need this here...
    $("#client-points-update").css({visibility: "hidden"});
    $("#opponent-points-update").css({visibility: "hidden"});
    $("#exp-button-container").css({visibility: "hidden"});
};
