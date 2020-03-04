/*
 * constants library for rps server (this does *not* get loaded in the browser)
 */


// Game constants
const DATAPATH = "/../data"; // path to data folder for writing output (note .. because js files are in `/lib`)
const GAME_ROUNDS = 300; // number of rounds opponents play in each game
const VALID_MOVES = ["rock", "paper", "scissors", "none"]; // valid game moves
const OUTCOME_POINTS = {"win": 3, "loss": -1, "tie": 0}; // points awared for valid round outcomes

// Bot strategy constants
const BOT_FIXED_MOVE_PROB = 0.9; // probability of most likely transition or move choice
const BOT_STRATEGY_SET = [ // set of available strategies
    // "prev_move_positive", // high probability of positive transition (r -> p -> s) from own previous move (NB: equivalent to win-positive, lose-positive, tie-positive)
    // "prev_move_negative", // high probability of negative transition (r -> s -> p) from own previous move (NB: equivalent to win-negative, lose-negative, tie-negative)
    // "opponent_prev_move_positive", // high probability of positive transition from *opponent's* previous move (NB: equivalent to win-nil, lose-negative, tie-positive)
    // "opponent_prev_move_nil", // high probability of nil transition from *opponent's* previous move (copies opponent) (NB: equivalent to win-negative, lose-positive, tie-nil)
    // "win_nil_lose_positive", // high probability of win-nil (stay), lose-positive, tie-negative
    "win_positive_lose_negative", // high probability of win-positive, lose-negative, tie-nil
    "outcome_transition_dual_dependency" // high probability of transitions given both outcomes and previous transitions
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
                "scissors": (1 - BOT_FIXED_MOVE_PROB) / 2
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
    // Strategies that are not outcome-dependent
    "prev_move_positive": {"win": PREV_MOVE_POSITIVE_TRANSITIONS,
                            "loss": PREV_MOVE_POSITIVE_TRANSITIONS,
                            "tie": PREV_MOVE_POSITIVE_TRANSITIONS},
    "prev_move_negative": {"win": PREV_MOVE_NEGATIVE_TRANSITIONS,
                            "loss": PREV_MOVE_NEGATIVE_TRANSITIONS,
                            "tie": PREV_MOVE_NEGATIVE_TRANSITIONS},
    "opponent_prev_move_positive": {"win": PREV_MOVE_POSITIVE_TRANSITIONS,
                                    "loss": PREV_MOVE_POSITIVE_TRANSITIONS,
                                    "tie": PREV_MOVE_POSITIVE_TRANSITIONS},
    "opponent_prev_move_nil": {"win": PREV_MOVE_NIL_TRANSITIONS,
                                "loss": PREV_MOVE_NIL_TRANSITIONS,
                                "tie": PREV_MOVE_NIL_TRANSITIONS},
    // Strategies that are outcome-dependent
    "win_nil_lose_positive": {"win": PREV_MOVE_NIL_TRANSITIONS,
                                "loss": PREV_MOVE_POSITIVE_TRANSITIONS,
                                "tie": PREV_MOVE_NEGATIVE_TRANSITIONS},
    "win_positive_lose_negative": {"win": PREV_MOVE_POSITIVE_TRANSITIONS,
                                    "loss": PREV_MOVE_NEGATIVE_TRANSITIONS,
                                    "tie": PREV_MOVE_NIL_TRANSITIONS},
    // Strategies that are both outcome and previous transition dependent
    // NB: these are expressed in opposite order (outcome -> transition) from how they were whiteboarded (transition -> outcome)
    "outcome_transition_dual_dependency": {"win": {"+": PREV_MOVE_NEGATIVE_TRANSITIONS,
                                                    "0": PREV_MOVE_POSITIVE_TRANSITIONS,
                                                    "-": PREV_MOVE_NIL_TRANSITIONS},
                                            "loss": {"+": PREV_MOVE_NIL_TRANSITIONS,
                                                        "0": PREV_MOVE_NEGATIVE_TRANSITIONS,
                                                        "-": PREV_MOVE_POSITIVE_TRANSITIONS},
                                            "tie": {"+": PREV_MOVE_POSITIVE_TRANSITIONS,
                                                        "0": PREV_MOVE_NIL_TRANSITIONS,
                                                        "-": PREV_MOVE_NEGATIVE_TRANSITIONS}}
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
