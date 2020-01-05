/*
 * constants library for rps server (this does *not* get loaded in the browser)
 */

const DATAPATH = "/../data"; // path to data folder for writing output (note .. because js files are in `/lib`)
const GAME_ROUNDS = 3; // number of rounds opponents play in each game

// node export structure for constants
exports.constants = {"DATAPATH": DATAPATH, "GAME_ROUNDS": GAME_ROUNDS};
