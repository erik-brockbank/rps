/*
 * Core game logic
 * Note: exports new rps_game_server() for use by app.js when clients connect
 */


// TODO is there a better solution for constants? separate constants.js doesn't seem to be available to this module...
const GAME_ROUNDS = 3; // number of rounds opponents play in each game (default 100)

// Object for keeping track of the RPS games being played
rps_game_server = function() {
    this.active_games = {}; // dict: mapping from game_id to rps_game objects currently in play or awaiting more players
};

// Object for keeping track of each RPS "game", i.e. 100 rounds of RPS between two players
rps_game = function(game_id = null, player1 = null, player2 = null) {
    this.game_id = game_id; // numeric: unique id for this game
    this.game_status = ""; // game_status item: current status of game (e.g. in play, completed)
    this.game_begin_ts = 0; // numeric: unix timestamp when both players began the game
    this.player1 = player1; // rps_player object: first player to join
    this.player1_client = null; // client connection to player 1 (used by server for passing messages)
    this.player2 = player2; // rps_player object: second player to join
    this.player2_client = null; // client connection to player 2 (used by server for passing messages)
    this.current_round_index = 0; // numeric: current round
    this.current_round = null; // rps_round object: depicts round currently in play
    this.player1_points_total = 0; // numeric: total points for player1
    this.player2_points_total = 0; // numeric: total points for player2
    this.previous_rounds = []; // list: previous rps_round objects for this game
};

// Object for keeping track of each RPS "round", i.e. one match between two players in a game
rps_round = function(game) {
    //this.game = game; // rps_game object: parent game for this round
    this.round = game.current_round_index; // numeric: round out of 100
    this.round_status = null;
    this.round_begin_ts = 0; //numeric: unix timestamp when both players began the round
    this.player1 = game.player1; // rps_player object: game player1
    this.player2 = game.player2; // rps_player object: game player2
    this.player1_move = null; // rps_player_move item: player1's move
    this.player2_move = null; // rps_player_move item: player2's move
    this.player1_rt = 0; // numeric: time taken for player1 to select move
    this.player2_rt = 0; // numeric: time taken for player2 to select move
    this.player1_outcome = null; // rps_outcome item for player 1
    this.player2_outcome = null; // rps_outcome item for player 2
    this.player1_points = 0; // numeric: points for player1 in this round
    this.player2_points = 0; // numeric: points for player2 in this round
};

// Object for keeping track of each RPS "player"
rps_player = function(client_id) {
    this.client_id = client_id; // numeric: id for this client
    this.status = null; // status encoding: current status for this player
    //this.game = null; // game this player is part of
    //this.client_connection = null; // used by the server only to send messages to the client
};

// Objects for formalizing RPS outcomes
var rps_player_move = ["rock", "paper", "scissors", "none"]; // Valid rps_player moves
var rps_outcome = ["win", "loss", "tie"]; // Valid rps_round outcomes
var rps_points = {"win": 3, "loss": -1, "tie": 0}; // points awared for valid rps_round outcomes

// Objects for formalizing client and server state
var game_status = ["player_waiting", "in_play", "complete"]; // Valid rps_game status values
var client_status = ["connected", "waiting_for_opponent", "in_play"]; // Valid rps_player status values
var round_status = ["waiting_for_player1", "waiting_for_player2", "complete"]; // Valid rps_round status values


// Util function to copy over relevant game attributes for sending to client
rps_game_server.prototype.copyGameVals = function(game) {
    return {
        "game_id": game.game_id,
        "game_status": game.game_status,
        "game_begin_ts": game.game_begin_ts,
        "player1": game.player1,
        "player2": game.player2,
        "current_round_index": game.current_round_index,
        "current_round": game.current_round,
        "player1_points_total": game.player1_points_total,
        "player2_points_total": game.player2_points_total,
        "previous_rounds": game.previous_rounds,
    };
};

// Util function to fetch the current game that a particular client belongs to
rps_game_server.prototype.getCurrentGame = function(client) {
    for (game_id in this.active_games) {
        game = this.active_games[game_id];
        if ((game.player1 && game.player1.client_id == client.userid) ||
            (game.player2 && game.player2.client_id == client.userid)) {
            return game;
        }
    }
};

rps_game_server.prototype.findGame = function(client) {
    console.log("game.js:\t Finding game for new client");
    // Look for an existing game to add this client to
    if (Object.keys(this.active_games).length > 0) {
        for (game_id in this.active_games) {
            game = this.active_games[game_id];
            if (game.game_status == "player_waiting" && (!game.player1 || !game.player2)) {
                // Add client to this game, update both clients accordingly
                this.addPlayerToGame(game_id, client);
                console.log("game.js:\t adding player to new existing game: ", this);
                return;
            }
        }
    }
    // If unable to find an existing game for the client, create a new one
    this.createGame(client);
};


rps_game_server.prototype.createGame = function(client) {
    console.log("game.js:\t Creating new game");
    // Create new player for this client
    newplayer = new rps_player(client.userid);
    newplayer.status = "waiting_for_opponent";
    //newplayer.client_connection = client;

    // Create new game and add client
    newgame_id = Date.now(); // use unix timestamp as unique identifier (not totally safe if two people join at the same second)
    var newgame = new rps_game(game_id = newgame_id, player1 = newplayer, player2 = null);
    newgame.game_id = newgame_id;
    newgame.game_status = "player_waiting";
    newgame.player1_client = client;
    // Create new round and add to game
    var newround = new rps_round(newgame);
    newgame.current_round = newround;

    if (newgame_id in this.active_games) {console.error("game.js:\t HASH COLLISION IN GAME SERVER");}
    else {this.active_games[newgame_id] = newgame;}

    // Update client telling them they're waiting and giving them latest game status
    client.emit('newgame', this.copyGameVals(newgame));

};

rps_game_server.prototype.addPlayerToGame = function(game_id, client) {
    console.log("game.js:\t adding player to existing game");
    // Create new player for this client
    newplayer = new rps_player(client.userid);
    newplayer.status = "in_play";
    // Add new player to existing game
    game = this.active_games[game_id];
    game.player2 = newplayer;
    game.player2_client = client;
    // Modify relevant fields in existing game
    game.player1.status = "in_play";
    game.game_status = "in_play";
    game.current_round_index = 1;
    game.game_begin_ts = Date.now();

    // Update same info in current round
    // TODO this is probably unnecessary
    game.current_round.player2 = newplayer;

    // Update both clients
    // TODO send along all relevant info to clients
    game.player1_client.emit('roundbegin', this.copyGameVals(game));
    game.player2_client.emit('roundbegin', this.copyGameVals(game));
};

rps_game_server.prototype.processMove = function(client, data) {
    console.log("game.js:\t received move: ", data.move, " from client: ", client.userid);
    // find game that this client is playing and update state of the current round to reflect the new move
    // if waiting for other player's move, update status. If not, process winner and update both clients
    // TODO this probably should find the game_id based on the client rather than having the client send that along...
    if (!data.hasOwnProperty("move") || (rps_player_move.indexOf(data.move) == -1)) {
        console.error("ERROR game.js:\t Invalid move in data: ", data); // TODO validate conditions above work
    }
    if (data.game_id in this.active_games) {
        current_game = this.active_games[data.game_id];
        current_round = current_game.current_round;
        if (client.userid == current_game.player1.client_id) {
            console.log("game.js:\t player 1 submitted move");
            current_round.player1_move = data.move;
        } else if (client.userid == current_game.player2.client_id) {
            console.log("game.js:\t player 2 submitted move");
            current_round.player2_move = data.move;
        }

        // TODO set status as needed
        if (!current_round.player1_move) {
            console.log("game.js:\t waiting for player 1 move");
            current_round.round_status = "waiting_for_player1";
            current_game.current_round = current_round;
            game.player2_client.emit('roundwaiting', {"round_status": current_game.current_round.round_status});
        } else if (!current_round.player2_move) {
            console.log("game.js:\t waiting for player 2 move");
            current_round.round_status = "waiting_for_player2";
            current_game.current_round = current_round;
            game.player1_client.emit('roundwaiting', {"round_status": current_game.current_round.round_status});
        }

        // If both players have chosen a move, determine winner and update players
        if (current_round.player1_move && current_round.player2_move) {
            console.log("game.js:\t evaluating round outcome");
            current_round = this.evaluateRoundOutcome(current_round);
            // TODO move the below into a separate updateGame function
            current_round.round_status = "complete";
            current_game.current_round = current_round;
            current_game.player1_points_total += current_round.player1_points;
            current_game.player2_points_total += current_round.player2_points;

            game.player1_client.emit('roundcomplete', this.copyGameVals(current_game));
            game.player2_client.emit('roundcomplete', this.copyGameVals(current_game));
        }

        console.log(current_round);
    }
};

// Take in an rps_round object and determine the winner, fill in other relevant data.
// Returns the rps_round filled in.
rps_game_server.prototype.evaluateRoundOutcome = function(rps_round) {
    if (rps_player_move.indexOf(rps_round.player1_move) != -1 && rps_player_move.indexOf(rps_round.player2_move) != -1) {
        // all possible tie outcomes
        if (rps_round.player1_move == rps_round.player2_move) {
            player1_outcome = "tie";
            player2_outcome = "tie";
        // player 1 wins
        } else if ((rps_round.player1_move == "rock" && rps_round.player2_move == "scissors") ||
            (rps_round.player1_move == "paper" && rps_round.player2_move == "rock") ||
            (rps_round.player1_move == "scissors" && rps_round.player2_move == "paper") ||
            (rps_round.player2_move == "no_choice")) {
            player1_outcome = "win";
            player2_outcome = "loss";
        } else {
        // all other: player 2 wins
            player1_outcome = "loss";
            player2_outcome = "win";
        }

        rps_round.player1_outcome = player1_outcome;
        rps_round.player2_outcome = player2_outcome;
        rps_round.player1_points = rps_points[player1_outcome];
        rps_round.player2_points = rps_points[player2_outcome];
    }

    return rps_round;
};

// Gets signal from client that we're ready for next round.
// Similar to receiving initial move, we tell the first client to wait for opponent and when both are in,
// we update them accordingly.
rps_game_server.prototype.nextRound = function(client, data) {
    console.log("game.js:\t received next round call from client: ", client.userid);
    // Identify game and round information based on the client
    current_game = this.getCurrentGame(client);
    current_round = current_game.current_round;

    // Determine which player the client represents and update status accordingly
    if (client.userid == current_game.player1.client_id) {
        console.log("game.js:\t player 1 submitted next round call");
        if (current_game.current_round_index == GAME_ROUNDS) {
            current_game.player1.status = "exited";
        } else {
            current_game.player1.status = "waiting_for_opponent"; // TODO should this be unique? or any time we're waiting?
        }
    } else if (client.userid == current_game.player2.client_id) {
        console.log("game.js:\t player 2 submitted next round call");
        if (current_game.current_round_index == GAME_ROUNDS) {
            current_game.player2.status = "exited";
        } else {
            current_game.player2.status = "waiting_for_opponent"; // TODO should this be unique? or any time we're waiting?
        }
    }

    // Based on player status(es) set above, respond accordingly
    // If this was the final round of the game, notify client that the game is over
    if (current_game.current_round_index == GAME_ROUNDS) {
        this.endGame(client);
        // If both players have now finished, write the results to a file and remove game from active game list
        if (current_game.player1.status == "exited" && current_game.player2.status == "exited") {
            console.log("game.js:\t writing results to file");
            // TODO write results to file

            // Remove game from game_server
            delete this.active_games[current_game.game_id];
        }
    // If this wasn't the final round of the game, proceed to next round as usual
    } else {
        // If only one client is ready, update that client that they're waiting for opponent
        if (current_game.player1.status != "waiting_for_opponent") {
            game.player2_client.emit('roundwaiting', {"status": current_game.player2.status});
            return;
        } else if (current_game.player2.status != "waiting_for_opponent") {
            game.player1_client.emit('roundwaiting', {"status": current_game.player1.status});
            return;
        // If both clients are ready, update them by starting the next round
        } else if (current_game.player1.status == "waiting_for_opponent" &&
            current_game.player2.status == "waiting_for_opponent") {
            // Create new round and add to game, send current round to previous_rounds object
            var newround = new rps_round(current_game);
            current_game.current_round = newround;
            current_game.previous_rounds.push(current_round);
            // Update relevant variables for current game
            game.player1.status = "in_play";
            game.player2.status = "in_play";
            game.game_status = "in_play";
            game.current_round_index += 1;

            // Update both clients
            // TODO send along all relevant info to clients
            current_game.player1_client.emit('roundbegin', this.copyGameVals(current_game));
            current_game.player2_client.emit('roundbegin', this.copyGameVals(current_game));
            return;
        }
    }
};

// One of the clients disconnected
// If this was unexpected, notify the other client and end this game
// If the game was already over, don't do anything
// TODO stress test this function a bit by ensuring that a client can leave at any time
rps_game_server.prototype.clientDisconnect = function(client) {
    console.log("game.js:\t received disconnect call from client: ", client.userid);
    // Identify game and round information based on the client
    current_game = this.getCurrentGame(client);

    // If there's still a game in progress, notify the other player
    if (current_game) {
        // Determine which player the client represents and update *other* player if needed
        if (client.userid == current_game.player1.client_id) {
            // Only notify player 2 if this isn't a normal disconnect at the end of the game
            if (current_game.player1.status != "exited") {
                console.log("game.js:\t unexpected disconnect from player 1.");
                this.endGame(current_game.player2_client);
                // Remove game from game_server
                delete this.active_games[current_game.game_id];
            }
        } else if (client.userid == current_game.player2.client_id) {
            // Only notify player 1 if this isn't a normal disconnect at the end of the game
            if (current_game.player2.status != "exited") {
                console.log("game.js:\t unexpected disconnect from player 2.");
                this.endGame(current_game.player1_client);
                // Remove game from game_server
                delete this.active_games[current_game.game_id];
            }
        }

    }
};

// Send game over signal to client
rps_game_server.prototype.endGame = function(client) {
    client.emit('gameover', {});
};





/*
TODO (clean up):
1. review statuses (game, player, etc.) and have a more systematic approach
2. clean up circularity of objects (game.current_round.player1 has a game field that's null, etc.)

TODO (process):
1. Add time constraint, show time remaining
2. Add points calculation, show points
2. Write each round (or whole game) to file
3. Add instructions
4. Make things look nice...
*/

// NB: this causes a reference error in the browser because module.exports is a node thing,
//      not a standard js browser thing. Doesn't seem to break anything so far...
var game_server = new rps_game_server();
module.exports = game_server;
