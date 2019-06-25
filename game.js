/*
 * Core game logic
 * Note: exports new rps_game_server() for use by app.js when clients connect
 */


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
    this.player2 = player2; // rps_player object: second player to join
    this.current_round = 0; // numeric: current round
    this.player1_points_total = 0; // numeric: total points for player1
    this.player2_points_total = 0; // numeric: total points for player2
    this.previous_rounds = []; // list: previous rps_round objects for this game
};

// Object for keeping track of each RPS "round", i.e. one match between two players in a game
rps_round = function(game) {
    this.game = game; // rps_game object: parent game for this round
    this.round = game.current_round; // numeric: round out of 100
    this.round_status = null;
    this.round_begin_ts = 0; //numeric: unix timestamp when both players began the round
    this.player1 = game.player1; // rps_player object: game player1
    this.player2 = game.player2; // rps_player object: game player2
    this.player1_move = null; // rps_player_move item: player1's move
    this.player2_move = null; // rps_player_move item: player2's move
    this.player1_rt = 0; // numeric: time taken for player1 to select move
    this.player2_rt = 0; // numeric: time taken for player2 to select move
    this.outcome = null; // rps_outcome item: player1_win, player2_win, or tie
    this.player1_points = 0; // numeric: points for player1 in this round
    this.player2_points = 0; // numeric: points for player2 in this round
};

// Object for keeping track of each RPS "player"
rps_player = function(client_id) {
    this.client_id = client_id; // numeric: id for this client
    this.status = null; // status encoding: current status for this player
};

// Objects for formalizing RPS outcomes
var rps_player_move = ["rock", "paper", "scissors", "none"]; // Valid rps_player moves
var rps_outcome = ["player1_win", "player2_win", "tie"]; // Valid rps_round outcomes

// Objects for formalizing client and server state
var game_status = ["player_waiting", "in_play", "complete"]; // Valid rps_game status values
var client_status = ["connected", "waiting_for_partner", "in_play"]; // Valid rps_player status values
var round_status = ["waiting_for_player1", "waiting_for_player2"]; // Valid rps_round status values



rps_game_server.prototype.findGame = function(client) {
    console.log("game.js:\t Finding game for new client");
    // Look for an existing game to add this client to
    if (Object.keys(this.active_games).length > 0) {
        for (game_id in this.active_games) {
            game = this.active_games[game_id];
            if (game.game_status == "player_waiting" && (!game.player1 || !game.player2)) {
                // Add client to this game, update both clients accordingly
                this.addPlayerToGame(game_id, client);
                console.log(this);
                return;
            }
        }
    }
    // If unable to find an existing game for the client, create a new one
    this.createGame(client);
    console.log(this);
}


rps_game_server.prototype.createGame = function(client) {
    console.log("game.js:\t Creating new game");
    // Create new player for this client
    newplayer = new rps_player(client.userid);
    newplayer.status = "waiting_for_partner";

    // Create new game and add client
    newgame_id = Date.now(); // use unix timestamp as unique identifier (not totally safe if two people join at the same second)
    var newgame = new rps_game(game_id = newgame_id, player1 = newplayer, player2 = null);
    newgame.game_status = "player_waiting";
    if (newgame_id in this.active_games) {console.error("HASH COLLISION IN GAME SERVER");}
    else {this.active_games[newgame_id] = newgame;}

    // Update client

}

rps_game_server.prototype.addPlayerToGame = function(game_id, client) {
    console.log("game.js:\t Adding player to existing game");
    // Create new player for this client
    newplayer = new rps_player(client.userid);
    newplayer.status = "in_play";
    // Add new player to existing game
    game = this.active_games[game_id];
    game.player2 = newplayer;
    // Modify relevant fields in existing game
    game.player1.status = "in_play";
    game.game_status = "in_play";
    game.current_round = 1;
    game.game_begin_ts = Date.now();

    // Update both clients
}



// NB: this causes a reference error in the browser because module.exports is a node thing,
//      not a standard js browser thing. Doesn't seem to break anything so far...
var game_server = new rps_game_server();
module.exports = game_server;
