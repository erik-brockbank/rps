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



// Initializing server
var app = require("express")(); // initialize express server
var server = app.listen(8000); // listen on port 8000
var io = require("socket.io")(server); // initialize socket.io



// General purpose getter for html files
app.get("/*", function(req, res) {
    var file = req.params[0];
    res.sendFile(__dirname + "/" + file);
});

// socket.io will call this function when a client connects
io.on("connection", function (client) {
    console.log("New user connected!");

    // TODO give the client an ID, tell the client it's connected, find a game!
    // see https://github.com/hawkrobe/MWERT/blob/master/app.js#L67
    // and possibly https://github.com/hawkrobe/MWERT/blob/master/game.client.js#L302
});
