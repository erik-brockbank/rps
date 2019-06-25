/*
 * Core application logic (handles web requests from client, detects new client initializations via socket.io)
 * Much of this code borrowed from https://github.com/hawkrobe/MWERT/blob/master/app.js
 */

/*
 * To run this locally:
 * 1. cd /rps
 * 2. `node app.js`
 * 3. in browser, visit http://localhost:8000/index.html
 */


// GLOBALS
var UUID = require('uuid');

// Initializing server
var app = require("express")(); // initialize express server
var server = app.listen(8000); // listen on port 8000
var io = require("socket.io")(server); // initialize socket.io

game_server = require(__dirname + "/" + "game.js"); // object for keeping track of games


// General purpose getter for html files
app.get("/*", function(req, res) {
    var file = req.params[0];
    res.sendFile(__dirname + "/" + file);
});

// socket.io will call this function when a client connects
io.on("connection", function (client) {
    console.log("app.js:\t New user connected");
    client.userid = UUID()
    // tell the client it connected successfully (pass along data in subsequent object)
    client.emit("onconnected", {id: client.userid, status: "connected"}); // TODO does the app need to know any statuses?

    // Assign client to an existing game or start a new one
    game_server.findGame(client);

});
