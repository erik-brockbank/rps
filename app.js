/*
 * Core application logic (handles web requests from client, detects new client initializations via socket.io)
 * Much of this code borrowed from https://github.com/hawkrobe/MWERT/blob/master/app.js
 */

/*
 * To run this locally:
 * 1. cd /rps
 * 2. `node app.js`
 * 3. in browser, visit http://localhost:3000/index.html
 */


// GLOBALS
const JSPATH = '/lib'; // path to static js files
var UUID = require('uuid');

// Initializing server
var app = require("express")(); // initialize express server
var server = app.listen(3000); // listen on port 3000 (nginx will proxy requests on 80 to 3000)
var io = require("socket.io").listen(server); // initialize socket.io

// internal requirements
game_server = require(__dirname + JSPATH + "/" + "game.js"); // object for keeping track of games


// General purpose getter for js files
app.get("/*", function(req, res) {
    var file = req.params[0];
    res.sendFile(__dirname + "/" + file);
});

// socket.io will call this function when a client connects
io.on("connection", function (client) {
    console.log("app.js:\t new user connected");
    client.userid = UUID()
    // tell the client it connected successfully (pass along data in subsequent object)
    client.emit("onconnected", {id: client.userid, status: "connected"}); // TODO does the app need to know any statuses?
    initializeClient(client);
});

var initializeClient = function(client) {
    // Determine whether this is a test run
    var istest = client.handshake.query.istest == "true";
    console.log("app.js:\t istest:");
    console.log(istest);
    // Assign client to an existing game or start a new one
    game_server.findGame(client, istest);

    // handle player move submissions
    client.on("player_move", function(data) {
        console.log("app.js:\t detected player move: ", data);
        game_server.processMove(client, data);
    });

    // handle player signal that they're ready for the next round
    client.on("player_round_complete", function(data) {
        console.log("app.js:\t detected player round complete: ", data);
        game_server.nextRound(client, data);
    });

    // handle disconnect
    client.on('disconnect', function() {
        console.log("app.js:\t detected client disconnect");
        game_server.clientDisconnect(client);
    });

};
