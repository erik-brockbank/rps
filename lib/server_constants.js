/*
 * constants library for rps server (this does *not* get loaded in the browser)
 */


// Game constants
const DATAPATH = "/../data"; // path to data folder for writing output (note .. because js files are in `/lib`)
const GAME_ROUNDS = 12; // number of rounds opponents play in each game
const VALID_MOVES = ["rock", "paper", "scissors", "none"]; // valid game moves
const OUTCOME_POINTS = {"win": 3, "loss": -1, "tie": 0}; // points awared for valid round outcomes

// Bot strategy constants
const BOT_FIXED_MOVE_PROB = 0.9; // probability of most likely transition or move choice
const BOT_STRATEGY_SET = [ // set of available strategies
    "prev_move_positive", // high probability of positive transition (r -> p -> s) from own previous move
    "prev_move_negative", // high probability of negative transition (r -> s -> p) from own previous move
    "opponent_prev_move_positive", // high probability of positive transition from *opponent's* previous move
    "opponent_prev_move_nil" // high probability of nil transition from *opponent's* previous move (copies opponent)
];

// Maps from each previous move (bot or opponent's) to a dictionary with lookup probabilities for each possible move choice
const PREV_MOVE_POSITIVE_TRANSITIONS = {
    "rock": {
                "rock": (1 - BOT_FIXED_MOVE_PROB) / 2,
                "paper": BOT_FIXED_MOVE_PROB,
                "scissors": (1 - BOT_FIXED_MOVE_PROB) / 2
            },
    "paper": {
                "rock": (1 - BOT_FIXED_MOVE_PROB) / 2,
                "paper": (1 - BOT_FIXED_MOVE_PROB) / 2,
                "scissors": BOT_FIXED_MOVE_PROB
            },
    "scissors": {
                "rock": BOT_FIXED_MOVE_PROB,
                "paper": (1 - BOT_FIXED_MOVE_PROB) / 2,
                "scissors": (1 - BOT_FIXED_MOVE_PROB) / 2,
            }
};

const PREV_MOVE_NEGATIVE_TRANSITIONS = {
    "rock": {
                "rock": (1 - BOT_FIXED_MOVE_PROB) / 2,
                "paper": (1 - BOT_FIXED_MOVE_PROB) / 2,
                "scissors": BOT_FIXED_MOVE_PROB
            },
    "paper": {
                "rock": BOT_FIXED_MOVE_PROB,
                "paper": (1 - BOT_FIXED_MOVE_PROB) / 2,
                "scissors": (1 - BOT_FIXED_MOVE_PROB) / 2
            },
    "scissors": {
                "rock": (1 - BOT_FIXED_MOVE_PROB) / 2,
                "paper": BOT_FIXED_MOVE_PROB,
                "scissors": (1 - BOT_FIXED_MOVE_PROB) / 2
            }
};


const PREV_MOVE_NIL_TRANSITIONS = {
    "rock": {
                "rock": BOT_FIXED_MOVE_PROB,
                "paper": (1 - BOT_FIXED_MOVE_PROB) / 2,
                "scissors": (1 - BOT_FIXED_MOVE_PROB) / 2
            },
    "paper": {
                "rock": (1 - BOT_FIXED_MOVE_PROB) / 2,
                "paper": BOT_FIXED_MOVE_PROB,
                "scissors": (1 - BOT_FIXED_MOVE_PROB) / 2
            },
    "scissors": {
                "rock": (1 - BOT_FIXED_MOVE_PROB) / 2,
                "paper": (1 - BOT_FIXED_MOVE_PROB) / 2,
                "scissors": BOT_FIXED_MOVE_PROB
            }
};

const RANDOM_MOVE_TRANSITIONS = {
    "rock": 1 / 3,
    "paper": 1 / 3,
    "scissors": 1 / 3
};

// Map from bot strategy name to transition probabilities defined above
const BOT_STRATEGY_LOOKUP = {
    "prev_move_positive": PREV_MOVE_POSITIVE_TRANSITIONS,
    "prev_move_negative": PREV_MOVE_NEGATIVE_TRANSITIONS,
    "opponent_prev_move_positive": PREV_MOVE_POSITIVE_TRANSITIONS,
    "opponent_prev_move_nil": PREV_MOVE_NIL_TRANSITIONS
};

// node export structure for constants
exports.constants = {"DATAPATH": DATAPATH,
                        "GAME_ROUNDS": GAME_ROUNDS,
                        "VALID_MOVES": VALID_MOVES,
                        "POINTS": OUTCOME_POINTS,
                        "BOT_STRATEGY_SET": BOT_STRATEGY_SET,
                        "BOT_STRATEGY_LOOKUP": BOT_STRATEGY_LOOKUP,
                        "BOT_RANDOM_MOVES": RANDOM_MOVE_TRANSITIONS
                    };
