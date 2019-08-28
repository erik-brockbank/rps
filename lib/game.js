/*
 * Core game logic
 * Note: exports new rps_game_server() for use by app.js when clients connect
 */

var fs = require("fs");
var UUID = require("uuid");
var server_constants = require("./server_constants.js"); // constants
const GAME_ROUNDS = server_constants.constants.GAME_ROUNDS;
const DATAPATH = server_constants.constants.DATAPATH;


// global objects for formalizing RPS outcomes
var rps_player_move = ["rock", "paper", "scissors", "none"]; // Valid rps_player moves
var rps_points = {"win": 3, "loss": -1, "tie": 0}; // points awared for valid rps_round outcomes


// object class for keeping track of each RPS "game", i.e. 100 rounds of RPS between two players
rps_game = function(game_id = null, istest = false, player1 = null, player2 = null, game_rounds = null) {
    this.game_id = game_id; // unique id for this game
    this.istest = istest; // whether this game is a test
    this.game_rounds = game_rounds; // total number of rounds to play in this game
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

// object class for keeping track of each RPS "round", i.e. one match between two players in a game
// NB: some of these fields are redundant with fields in rps_game but allow each round to stand alone if need be
rps_round = function(game) {
    this.game_id = game.game_id; // unique id for the game this round belongs to
    this.round_index = game.current_round_index; // numeric: round out of 100
    this.round_begin_ts = null; //numeric: unix timestamp when both players began the round
    this.player1_id = game.player1.client_id; // unique id for player 1 in this round
    this.player2_id = game.player2.client_id; // unique id for player 2 in this round
    this.player1_move = null; // rps_player_move item: player1's move
    this.player2_move = null; // rps_player_move item: player2's move
    this.player1_rt = 0; // numeric: time taken for player1 to select move
    this.player2_rt = 0; // numeric: time taken for player2 to select move
    this.player1_outcome = null; // rps_outcome item for player 1
    this.player2_outcome = null; // rps_outcome item for player 2
    this.player1_points = 0; // numeric: points for player1 in this round
    this.player2_points = 0; // numeric: points for player2 in this round
    this.player1_points_total = game.player1_points_total; // numeric: total points for player 1 *at beginning of round*
    this.player2_points_total = game.player2_points_total; // numeric: total points for player 2 *at beginning of round*
};

// object class for keeping track of each RPS "player"
rps_player = function(client) {
    this.client_id = client.userid; // unique id for this client
    this.status = null; // status encoding: current status for this player
};


// object class for keeping track of the RPS games being played
rps_game_server = function() {
    this.active_games = {}; // dict: mapping from game_id to rps_game objects currently in play or awaiting more players
};


// Admin function to return active game state of this game server.
// Returns a dictionary with each active game and the current round index in that game.
// Used for /admin requests to ensure clean game state before running participants and to
// monitor state of each game while running participants
rps_game_server.prototype.getState = function() {
    var stateObj = {};
    for (elem in this.active_games) {
        stateObj[elem] = this.active_games[elem].current_round_index;
    }
    return stateObj;
};


// Util function to copy over relevant game attributes for sending to client
// NB: to avoid copying large(ish) amounts of data, we don't copy previous_rounds array here
rps_game_server.prototype.copyGameVals = function(game) {
    return {
        game_id: game.game_id,
        istest: game.istest,
        game_rounds: game.game_rounds,
        game_begin_ts: game.game_begin_ts,
        player1: game.player1,
        player2: game.player2,
        current_round_index: game.current_round_index,
        current_round: game.current_round,
        player1_points_total: game.player1_points_total,
        player2_points_total: game.player2_points_total
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


// Util function to fetch the rps_player object that a particular client belongs to
rps_game_server.prototype.getCurrentPlayer = function(rps_game, client) {
    if (client.userid == rps_game.player1.client_id) {
        return rps_game.player1;
    } else if (client.userid == rps_game.player2.client_id) {
        return rps_game.player2;
    }
};


// Util function to fetch the rps_player object that a particular client *is matched up against*
rps_game_server.prototype.getOpponent = function(rps_game, client) {
    if (client.userid == rps_game.player1.client_id) {
        return rps_game.player2;
    } else if (client.userid == rps_game.player2.client_id) {
        return rps_game.player1;
    }
};


// Util function to fetch the socket connection for a given rps_player in the current rps_game
rps_game_server.prototype.getClient = function(rps_game, rps_player) {
    if (rps_player.client_id == rps_game.player1_client.userid) {
        return rps_game.player1_client;
    } else if (rps_player.client_id == rps_game.player2_client.userid) {
        return rps_game.player2_client;
    }
};


// Function to set a particular player's status within a game
rps_game_server.prototype.setPlayerStatus = function(rps_game, rps_player, status) {
    if (rps_player.client_id == rps_game.player1.client_id) {
        rps_game.player1.status = status;
        return rps_game;
    } else if (rps_player.client_id == rps_game.player2.client_id) {
        rps_game.player2.status = status;
        return rps_game;
    }
};


// Function to add new client to an existing game or create a new game with this client as the first player
rps_game_server.prototype.findGame = function(client, istest) {
    console.log("game.js:\t finding game for new client: ", client.userid);
    // Look for an existing game to add this client to
    if (Object.keys(this.active_games).length > 0) {
        for (game_id in this.active_games) {
            game = this.active_games[game_id];
            if (!game.player1 || !game.player2) {
                // Add client to this game, update both clients accordingly
                this.addPlayerToGame(game, client, istest);
                return;
            }
        }
    }
    // If unable to find an existing game for the client, create a new one
    this.createGame(client, istest);
};


// Function to create a new game and add this client as the first player
rps_game_server.prototype.createGame = function(client, istest) {
    console.log("game.js:\t creating new game for client: ", client.userid);
    // Create new player for this client
    newplayer = new rps_player(client);
    newplayer.status = "waiting_to_start"; // NB: setting status to "waiting_for_opponent" causes downstream issues in move processing
    // Create new game and add client
    newgame_id = UUID();
    var newgame = new rps_game(game_id = newgame_id, istest = istest,
                                player1 = newplayer, player2 = null, total_rounds = GAME_ROUNDS);
    newgame.player1_client = client;
    this.active_games[newgame_id] = newgame;
    // Update client telling them they're waiting and giving them the game id
    client.emit("newgame", {game_id: newgame_id});

};


// Function to add client to an existing game that needs an opponent
rps_game_server.prototype.addPlayerToGame = function(game, client, istest) {
    console.log("game.js:\t adding client to existing game");
    // Create new player for this client
    newplayer = new rps_player(client);
    // If this game was not a test game but the new client is a test, the game becomes a test game
    if (game.istest == false && istest == true) {game.istest = istest;}
    game.player2 = newplayer;
    game.player2_client = client;
    // Modify relevant fields in existing game
    game.current_round_index = 1;
    game.game_begin_ts = new Date().getTime(); // unix timestamp
    // Create new round and add to game
    // NB: rps_round constructor relies on certain fields in game passed in
    var newround = new rps_round(game);
    newround.round_begin_ts = new Date().getTime(); // unix timetamp for when this round began
    game.current_round = newround;
    // Update player status values for this game
    game.player1.status = "in_play";
    game.player2.status = "in_play";
    // Update both clients
    game.player1_client.emit("roundbegin", this.copyGameVals(game));
    game.player2_client.emit("roundbegin", this.copyGameVals(game));
};


// Find game that this client is playing and update state of the current round to reflect the new move.
// If waiting for other player's move, update status. If not, process winner and update both clients
rps_game_server.prototype.processMove = function(client, data) {
    console.log("game.js:\t received move: ", data.move, " from client: ", client.userid);
    // Find the game this client belongs to, update the game's move/rt fields with the values in `data`
    current_game = this.getCurrentGame(client);
    current_round = current_game.current_round;
    if (client.userid == current_game.player1.client_id) {
        current_round.player1_move = data.move;
        current_round.player1_rt = data.rt;
    } else if (client.userid == current_game.player2.client_id) {
        current_round.player2_move = data.move;
        current_round.player2_rt = data.rt;
    }
    // If this player is the first to choose a move, update the client that they're waiting for opponent
    if (!current_round.player1_move) {
        current_game.current_round = current_round;
        game.player2_client.emit("roundwaiting_move");
    } else if (!current_round.player2_move) {
        current_game.current_round = current_round;
        game.player1_client.emit("roundwaiting_move");
    }
    // If both players have chosen a move, determine winner and update players
    if (current_round.player1_move && current_round.player2_move) {
        current_round = this.evaluateRoundOutcome(current_round);
        current_game.current_round = current_round;
        current_game.player1_points_total += current_round.player1_points; // update game total points
        current_game.player2_points_total += current_round.player2_points; // update game total points
        // Update both clients
        game.player1_client.emit("roundcomplete", this.copyGameVals(current_game));
        game.player2_client.emit("roundcomplete", this.copyGameVals(current_game));
    }
};


// Take in an rps_round object and determine the winner, fill in other relevant data.
// Returns the rps_round filled in
rps_game_server.prototype.evaluateRoundOutcome = function(rps_round) {
    console.log("game.js:\t evaluating round outcome");
    if (rps_player_move.indexOf(rps_round.player1_move) != -1 && rps_player_move.indexOf(rps_round.player2_move) != -1) {
        // All possible tie outcomes
        if (rps_round.player1_move == rps_round.player2_move) {
            player1_outcome = "tie";
            player2_outcome = "tie";
        // Player 1 wins
        } else if ((rps_round.player1_move == "rock" && rps_round.player2_move == "scissors") ||
            (rps_round.player1_move == "paper" && rps_round.player2_move == "rock") ||
            (rps_round.player1_move == "scissors" && rps_round.player2_move == "paper") ||
            (rps_round.player2_move == "none")) {
            player1_outcome = "win";
            player2_outcome = "loss";
        } else {
        // All other: player 2 wins
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


// Received signal from client that we're ready for next round.
// Similar to receiving initial move, we tell the first client to wait for opponent.
// When both are ready, we update them accordingly.
rps_game_server.prototype.nextRound = function(client) {
    console.log("game.js:\t next round request from client: ", client.userid);
    // Identify game and round information based on the client
    current_game = this.getCurrentGame(client);
    current_round = current_game.current_round;
    this_player = this.getCurrentPlayer(current_game, client);
    this_opponent = this.getOpponent(current_game, client);
    // Update player's status locally and for game object
    if (current_game.current_round_index == GAME_ROUNDS) {
        this_player.status = "exited"; // end of game, client should see game over
        current_game = this.setPlayerStatus(current_game, this_player, "exited");
        this.endGame(current_game, this_player);
    } else {
        this_player.status = "waiting_for_opponent"; // still in game
        current_game = this.setPlayerStatus(current_game, this_player, "waiting_for_opponent");
    }
    // Based on player status(es) set above, respond accordingly
    // If both players have now finished, write the results to a file and remove game from active game list
    if (this_player.status == "exited" && this_opponent.status == "exited") {
        current_game.previous_rounds.push(current_round);
        this.writeData(current_game);
        delete this.active_games[current_game.game_id];
    // If only this client is ready, update them that they're waiting for opponent
    } else if (this_player.status == "waiting_for_opponent" &&
        this_opponent.status != "waiting_for_opponent") {
        client.emit("roundwaiting_continue");
    // If both clients are ready, update them by starting the next round
    } else if (this_player.status == "waiting_for_opponent" &&
        this_opponent.status == "waiting_for_opponent") {
        current_game.current_round_index += 1;
        // NB: rps_round constructor relies on certain fields in game passed in (e.g. current_round_index updated above)
        var newround = new rps_round(current_game);
        newround.round_begin_ts = new Date().getTime(); // unix timetamp for when this round began
        current_game.current_round = newround;
        current_game.previous_rounds.push(current_round);
        // Update player status values for this game
        current_game = this.setPlayerStatus(current_game, this_player, "in_play");
        current_game = this.setPlayerStatus(current_game, this_opponent, "in_play");
        // Update both clients
        current_game.player1_client.emit("roundbegin", this.copyGameVals(current_game));
        current_game.player2_client.emit("roundbegin", this.copyGameVals(current_game));
    }
};


// One of the clients disconnected
// If this was unexpected, notify the other client and end this game
// If the game was already over, don't do anything
rps_game_server.prototype.clientDisconnect = function(client) {
    console.log("game.js:\t unexpected disconnect from client: ", client.userid);
    current_game = this.getCurrentGame(client);
    // If there's still a game in progress, notify the other player
    if (current_game) {
        this_player = this.getCurrentPlayer(current_game, client);
        this_opponent = this.getOpponent(current_game, client);
        if (this_player.status != "exited") {
            this.endGame(current_game, this_opponent);
            this.writeData(current_game);
            delete this.active_games[current_game.game_id];
        }
    }
};


// Send game over signal to the client that matches rps_player in current_game
rps_game_server.prototype.endGame = function(current_game, rps_player) {
    if (rps_player) {
        console.log("game.js:\t sending gameover for client: ", rps_player.client_id);
        player_socket = this.getClient(current_game, rps_player);
        player_socket.emit("gameover");
    }
};


// Write results of this game to json
// NB: conversion of this json to long format csv is handled by a separate python script outside this repo
rps_game_server.prototype.writeData = function(current_game) {
    var filename = __dirname + DATAPATH + "/";
    if (current_game.istest == true) {
        filename += "TEST_";
    }
    filename += current_game.game_id.toString() + ".json";
    // Make sure we have baseline data to write to file
    if (current_game.game_id && current_game.player1 && current_game.player2) {
        console.log("game.js:\t writing results to file: ", filename);
        data_obj = {
            game_id: current_game.game_id,
            player1_id: current_game.player1.client_id,
            player2_id: current_game.player2.client_id,
            rounds: []
        };
        for (round_idx in current_game.previous_rounds) {
            round = current_game.previous_rounds[round_idx];
            round_obj = {
                game_id: round.game_id, // this is the same as current_game.game_id
                game_begin_ts: round.game_begin_ts, // this is the same as current_game.game_begin_ts
                round_index: round.round_index,
                player1_id: round.player1_id, // this is the same as current_game.player1.client_id
                player2_id: round.player2_id, // this is the same as current_game.player2.client_id
                round_begin_ts: round.round_begin_ts,
                player1_move: round.player1_move,
                player2_move: round.player2_move,
                player1_rt: round.player1_rt,
                player2_rt: round.player2_rt,
                player1_outcome: round.player1_outcome,
                player2_outcome: round.player2_outcome,
                player1_points: round.player1_points,
                player2_points: round.player2_points,
                player1_total: round.player1_points_total,
                player2_total: round.player2_points_total
            };
            data_obj.rounds.push(round_obj);
        }
        data_str = JSON.stringify(data_obj, null, 2);
        console.log("game.js\t results string: ", data_str);
        fs.writeFile(filename, data_str, (err) => {
            if (err) throw err;
            console.log("game.js:\t game data successfully written to file.");
        });
    }
};



var game_server = new rps_game_server();
module.exports = game_server;
