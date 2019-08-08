/*
 * constants library for rps server (this does *not* get loaded in the browser)
 */

const DATA_PATH = '/data'; // path to data folder for writing output
const GAME_ROUNDS = 3; // number of rounds opponents play in each game (default 100)

exports.constants = {'DATAPATH': DATA_PATH, 'GAME_ROUNDS': GAME_ROUNDS};
