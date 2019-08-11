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
client_begin_round_html = function(current_round_index, game_rounds) {
    // Message information for beginning round
    $("#message-container").text("Choose a move!"); // TODO make this message global? Make all messages global/constants?

    // Banner information for beginning round (round index, time remaining)
    $("#round-index").text(current_round_index + "/" + game_rounds);

    // Client info for beginning round
    // $("#client-header").text("You");
    // $("#client-body").html(
    //     "<img class='move-button' id='rock-button' src='" + IMGPATH + "/" + "rock-individ.jpg'/>" +
    //     "<img class='move-button' id='paper-button' src='" + IMGPATH + "/" + "paper-individ.jpg'/>" +
    //     "<img class='move-button' id='scissors-button' src='" + IMGPATH + "/" + "scissors-individ.jpg'/>"
    // );

    // Opponent info for beginning round
    // $("#opponent-header").text("Opponent");
    // $("#opponent-body").html(
    //     "<div class='opponent-choice'>?</div>" +
    //     "<div class='opponent-choice'>?</div>" +
    //     "<div class='opponent-choice'>?</div>"
    // );

    // $("#game-info").html(
    //     "<img class='game-info' id='schematic' src='" + IMGPATH + "/" + "schematic.jpg'/>"
    // )
    $("#game-container").css({visibility:"visible"});
};


// Function to dynamically load/populate html elements for showing round results
client_display_results_html = function() {
    $("#message-container").text("Results:");
    $("#game-container").css({visibility:"visible"});

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

    that = this; // copy game object to pass in to move handling code below
    // load "choose your move" page
    // $("body").load(HTMLPATH + "/" + "round_begin.html", function() {
    // $("body").load(HTMLPATH + "/" + "round_template.html", function() {
        // Display relevant status info
        if (player.client_id == data.player1.client_id) {
            client_total_points = data.player1_points_total;
            opponent_total_points = data.player2_points_total;
        } else if (player.client_id == data.player2.client_id) {
            client_total_points = data.player2_points_total;
            opponent_total_points = data.player1_points_total;
        }

        client_begin_round_html(data.current_round_index, data.game_rounds);
        // $("#current-round").text(data.current_round_index + "/" + data.game_rounds);
        // $("#client-total-points").text(client_total_points);
        // $("#opponent-total-points").text(opponent_total_points);

        // Start the countdown clock for selecting a move
        start_time = Date.parse(new Date()); // timer for ROUND_TIMEOUT countdown (rounds to nearest second)
        start_time_ms = new Date().getTime(); // more accurate timer for participant responses
        end_time = start_time + (1000 * ROUND_TIMEOUT); // number of seconds for each round * 1000 since timestamp includes ms
        remaining = (end_time - (Date.parse(new Date()))) / 1000; // calculate seconds remaining (rounds to nearest second)
        $("#countdown").text(remaining);
        var interval = setInterval(function() {
            remaining = (end_time - (Date.parse(new Date()))) / 1000; // calculate seconds remaining
            $("#countdown").text(remaining);
            if (remaining <= 0) {
                resp_time = ROUND_TIMEOUT * 1000 // max response time (ms)
                clearInterval(interval);
                $("#time-info").css({visibility:"hidden"});
                client_submit_move("none", resp_time, that);
            }
        }, 1000);

        // Add button interactivity
        // TODO figure out how to make this more streamlined (basically the same code thrice...)
        // TODO gray out all others after clicking one, make them unclickable
        $("#client-move-rock").click(function() {
            $(this).css({border:"5px solid green"});
            resp_time = new Date().getTime() - start_time_ms; // ms since start_time_ms
            clearInterval(interval);
            $("#time-info").css({visibility:"hidden"});
            client_submit_move("rock", resp_time, that);
        });
        $("#client-move-paper").click(function() {
            $(this).css({border:"5px solid green"});
            resp_time = new Date().getTime() - start_time_ms; // ms since start_time_ms
            clearInterval(interval);
            $("#time-info").css({visibility:"hidden"});
            client_submit_move("paper", resp_time, that);
        });
        $("#client-move-scissors").click(function() {
            $(this).css({border:"5px solid green"});
            resp_time = new Date().getTime() - start_time_ms; // ms since start_time_ms
            clearInterval(interval);
            $("#time-info").css({visibility:"hidden"});
            client_submit_move("scissors", resp_time, that);
        });

    // });
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
    console.log("client.js:\t data: ", data);
    // TODO update the local game with all relevant info in data
    var wait_msg = "Waiting for opponent to select a move...";
    clientDisplayMessage(wait_msg, hideall=false);
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
        client_round_points = data.current_round.player1_points;
        client_total_points = data.player1_points_total;
        opponent_total_points = data.player2_points_total;
    } else if (player.client_id == data.player2.client_id) {
        client_move = data.current_round.player2_move;
        opponent_move = data.current_round.player1_move;
        client_outcome = data.current_round.player2_outcome;
        client_round_points = data.current_round.player2_points;
        client_total_points = data.player2_points_total;
        opponent_total_points = data.player1_points_total;
    }
    if (client_outcome == "win") {
        outcome_text = "You won this round!";
    } else if (client_outcome == "loss") {
        outcome_text = "You lost this round.";
    } else if (client_outcome == "tie") {
        outcome_text = "This round was a tie.";
    }

    client_display_results_html();

    // Display results and transition to next round
    var that = this;
    // $("body").load(HTMLPATH + "/" + "round_results.html", function() {

        $("#next-round").click(function() {
            client_finish_round(that);
        });
        // Display results
        // TODO move this to another function that shows stuff on every screen
        $("#current-round").text(data.current_round_index + "/" + data.game_rounds);
        $("#client-total-points").text(client_total_points);
        $("#opponent-total-points").text(opponent_total_points);
        // TODO move this to another function that shows stuff on every results
        $("#client-move").text(client_move);
        $("#opponent-move").text(opponent_move);
        $("#result").text(outcome_text);
        $("#client-points").text(client_round_points);
    // });
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
};
