#'
#' This script contains the final analysis for the rps journal submission
#' 


#### SETUP ####

rm(list = ls())
setwd("/Users/erikbrockbank/web/vullab/rps/analysis")

library(tidyverse)
library(viridis)
library(patchwork)

# CITATATIONS
citation(package = 'patchwork') # repeat for all the above




#### GLOBALS ####

# Experiment 1 data
E1_DATA_FILE = "rps_v1_data.csv" # name of file containing full dataset for all rounds
E1_FREE_RESP_FILE = "rps_v1_data_freeResp.csv" # name of file containing free response data by participant
E1_SLIDER_FILE = "rps_v1_data_sliderData.csv" # name of file containing slider Likert data by participant
# Experiment 2 data
E2_DATA_FILE = "rps_v2_data.csv" # name of file containing full dataset for all rounds
E2_FREE_RESP_FILE = "rps_v2_data_freeResp.csv" # name of file containing free response data by participant
E2_SLIDER_FILE = "rps_v2_data_sliderData.csv" # name of file containing slider Likert data by participant


GAME_ROUNDS = 300
NULL_SAMPLES = 10000 
MAX_LAG = 10 # lag for autocorrelation analysis
MOVE_SET = c("rock", "paper", "scissors")
TRANSITION_SET = c("+", "-", "0")

OUTCOME_SET = c("win", "loss", "tie")

# Win count differential outcome for each move combination (player in rows, opponent in cols)
OUTCOME_MATRIX = matrix(c(0, -1, 1, 1, 0, -1, -1, 1, 0), nrow = 3, byrow = T)
rownames(OUTCOME_MATRIX) = c("rock", "paper", "scissors")
colnames(OUTCOME_MATRIX) = c("opp_rock", "opp_paper", "opp_scissors")

# Bot analysis globals
STRATEGY_LEVELS = c("prev_move_positive", "prev_move_negative",
                    "opponent_prev_move_positive", "opponent_prev_move_nil",
                    "win_nil_lose_positive", "win_positive_lose_negative",
                    "outcome_transition_dual_dependency")
STRATEGY_LOOKUP = list("prev_move_positive" = "Previous move (+)",
                       "prev_move_negative" = "Previous move (-)",
                       "opponent_prev_move_positive" = "Opponent previous move (+)",
                       "opponent_prev_move_nil" = "Opponent previous move (0)",
                       "win_nil_lose_positive" = "Win-stay-lose-positive",
                       "win_positive_lose_negative" = "Win-positive-lose-negative",
                       # "outcome_transition_dual_dependency" = "Outcome-transition dual dependency")
                       "outcome_transition_dual_dependency" = "Previous outcome, previous transition")




#### DATA PROCESSING FUNCTIONS ####

# Function to read in and structure data appropriately
read_dyad_data = function(filename, game_rounds) {
  data = read_csv(filename)
  incomplete_data = data %>%
    group_by(player_id) %>%
    summarize(rounds = max(round_index)) %>%
    filter(rounds < game_rounds) %>%
    select(player_id)
  
  data = data %>%
    filter(!(player_id %in% incomplete_data$player_id))
  
  return(data)
}

read_bot_data = function(filename, strategies, game_rounds) {
  data = read_csv(filename)
  data$bot_strategy = factor(data$bot_strategy, levels = strategies)
  
  # Remove all incomplete games
  incomplete_games = data %>%
    group_by(game_id, player_id) %>%
    summarize(rounds = max(round_index)) %>%
    filter(rounds < game_rounds) %>%
    select(game_id) %>%
    unique()
  
  data = data %>%
    filter(!(game_id %in% incomplete_games$game_id))
  
  # Remove any duplicate complete games that have the same SONA survey code
  # NB: this can happen if somebody played all the way through but exited before receiving credit
  # First, fetch sona survey codes with multiple complete games
  repeat_codes = data %>%
    group_by(sona_survey_code) %>%
    filter(is_bot == 0) %>%
    summarize(trials = n()) %>%
    filter(trials > 300) %>%
    select(sona_survey_code)
  
  # Next, get game id for the earlier complete game
  # NB: commented out code checks that we have slider/free resp data for at least one of the games
  duplicate_games = data %>%
    filter(sona_survey_code %in% repeat_codes$sona_survey_code &
             is_bot == 0  &
             round_index == game_rounds) %>%
    select(sona_survey_code, game_id, player_id, round_begin_ts) %>%
    # remove the earlier one since the later one has free response and slider data (confirm with joins below)
    group_by(sona_survey_code) %>%
    filter(round_begin_ts == min(round_begin_ts)) %>%
    # inner_join(fr_data, by = c("game_id", "player_id")) %>%
    # inner_join(slider_data, by = c("game_id", "player_id")) %>%
    distinct(game_id)
  
  data = data %>%
    filter(!game_id %in% duplicate_games$game_id)
  
  return(data)
}


##### Win Count Differential Analysis Functions #####

# Function to extract win count differentials from empirical game data
get_empirical_win_count_differential = function(data) {
  win_diff = data %>%
    group_by(game_id, player_id) %>%
    count(win_count = player_outcome == "win") %>%
    filter(win_count == TRUE) %>%
    group_by(game_id) %>%
    mutate(opp_win_count = lag(n, 1)) %>%
    filter(!is.na(opp_win_count)) %>%
    summarize(win_diff = abs(n - opp_win_count))
  return(win_diff)
}

# Function to generate null sample win count differentials
get_sample_win_count_differential = function(reps, game_rounds) {
  win_diff_sample = data.frame(
    game_id = seq(1:reps),
    win_diff = replicate(reps, abs(sum(sample(c(-1, 0, 1), game_rounds, replace = T))))
  )
  return(win_diff_sample)
}


#### Autocorrelation Analysis Functions ####

# Function for selecting a single player's data from each game
# (avoids duplcate auto-correlation calculations for each game since outcomes 
# for each player in a given game are complementary)
get_unique_game_data = function(data) {
  data %>%
    group_by(game_id, round_index) %>%
    filter(row_number() == 1)
}

# Get auto-correlation of game outcomes at increasing round lags
get_game_acf = function(unique_game_data, max_lag) {
  # data frame for keeping track of auto-correlation by game
  acf_agg = data.frame(game = character(),
                       lag = numeric(),
                       acf = numeric())
  # code outcomes as numeric
  unique_game_data = unique_game_data %>%
    mutate(points_symmetric = case_when(player_outcome == "win" ~ 1,
                                        player_outcome == "loss" ~ -1,
                                        player_outcome == "tie" ~ 0)) %>%
    filter(!is.na(points_symmetric)) # TODO: why do we have NA outcomes?
  # fill in data frame
  for (game in unique(unique_game_data$game_id)) {
    game_data = unique_game_data %>%
      filter(game_id == game)
    game_acf = acf(game_data$points_symmetric, lag.max = max_lag, plot = F)
    
    acf_agg = rbind(acf_agg, data.frame(game = game, lag = seq(0, max_lag), acf = game_acf[[1]]))
  }
  return(acf_agg)
}

# Function to generate a sample set of `rounds` outcomes
get_sample_game = function(rounds) {
  sample(c("loss", "tie", "win"), rounds, replace = T)
}

# Function to add a winning and losing streak of length `streak_length` to the `sample_game`
add_game_streaks = function(sample_game, streak_length) {
  # randomly set first streak_length games to be wins and middle streak_length games to be losses
  sample_game[1:streak_length] = "win"
  sample_game[101:(100 + streak_length)] = "loss"
  return(sample_game)
}

# Function to generate acf of simulated games for `n_particpants` playing `rounds`
get_sample_acf = function(streak_length, rounds, n_participants) {
  sample_df = data.frame(game_id = numeric(), round_index = numeric(), player_outcome = character(),
                         stringsAsFactors = F)
  
  for (game in seq(1, n_participants)) {
    sample_game = get_sample_game(rounds)
    sample_game = add_game_streaks(sample_game, streak_length)
    
    sample_df = rbind(sample_df, 
                      data.frame(game_id = game, round_index = seq(1, rounds), player_outcome = sample_game,
                                 stringsAsFactors = F))
  }
  
  return(sample_df)
}


#### Max. Expected Win Count Differential Analysis Functions ####

# Function to get marginal probability of each move for each participant
get_player_move_dist = function(data, moves) {
  data %>%
    filter(player_move != "none") %>% # ignore "none" moves for this aggregation
    group_by(game_id, player_id) %>%
    count(player_move) %>%
    mutate(total = sum(n),
           pmove = n / total) %>%
    # order by "rock", "paper", "scissors"
    arrange(game_id, player_id, factor(player_move, levels = moves))
}

# Function to get marginal probability of each transition (+/-/0) for each participant
get_player_transition_dist = function(data) {
  data %>%
    group_by(game_id, player_id) %>%
    mutate(prev.move = lag(player_move, 1)) %>%
    filter(!is.na(prev.move), # lag call above sets NA for lag on first move: ignore it here
           prev.move != "none", player_move != "none") %>%
    # NB: this can be slow to execute
    mutate(player.transition = case_when(prev.move == player_move ~ "0",
                                         ((prev.move == "rock" & player_move == "paper") |
                                            (prev.move == "paper" & player_move == "scissors") |
                                            (prev.move == "scissors" & player_move == "rock")) ~ "+",
                                         ((prev.move == "rock" & player_move == "scissors") |
                                            (prev.move == "paper" & player_move == "rock") |
                                            (prev.move == "scissors" & player_move == "paper")) ~ "-")) %>%
    count(player.transition) %>%
    mutate(total.transitions = sum(n),
           p.transition = n / total.transitions)
}

# Function to get marginal probability of each transition (+/-/0) *relative to opponent's previous move* for each player
get_player_transition_cournot_dist = function(data) {
  data %>%
    group_by(game_id, player_id) %>%
    mutate(prev.move = lag(player_move, 1)) %>%
    filter(!is.na(prev.move)) %>% # lag call above sets NA for lag on first move: ignore it here
    group_by(game_id, round_index) %>%
    # opponent's previous move is previous row's prev.move for one of the players, next row's prev.move for the other
    mutate(opponent.prev.move = ifelse(is.na(lag(player_move, 1)), lead(prev.move, 1), lag(prev.move, 1))) %>% # opponent's one move back (previous move)
    filter(opponent.prev.move != "none" & player_move != "none") %>% # ignore "none" moves for this aggregation
    group_by(game_id, player_id) %>%
    # NB: this can be slow to execute
    mutate(player.transition.cournot = case_when(opponent.prev.move == player_move ~ "0",
                                                 ((opponent.prev.move == "rock" & player_move == "paper") |
                                                    (opponent.prev.move == "paper" & player_move == "scissors") |
                                                    (opponent.prev.move == "scissors" & player_move == "rock")) ~ "+",
                                                 ((opponent.prev.move == "rock" & player_move == "scissors") |
                                                    (opponent.prev.move == "paper" & player_move == "rock") |
                                                    (opponent.prev.move == "scissors" & player_move == "paper")) ~ "-")) %>%
    count(player.transition.cournot) %>%
    mutate(total.transitions = sum(n),
           p.transition = n / total.transitions)
}

# Function to summarize probability of each move for each participant, conditioned on their *opponent's* previous move 
get_opponent_prev_move_cond = function(data) {
  data %>%
    # add each player's previous move, then use that when referencing opponent's previous move
    group_by(game_id, player_id) %>%
    mutate(prev.move = lag(player_move, 1)) %>%
    filter(!is.na(prev.move)) %>% # lag call above sets NA for lag on very first move: ignore it here
    group_by(game_id, round_index) %>%
    # opponent's previous move is previous row's prev.move for one of the players, next row's prev.move for the other
    mutate(opponent.prev.move = ifelse(is.na(lag(player_move, 1)), lead(prev.move, 1), lag(prev.move, 1)),
           # category of move given opponent previous move, e.g. "rock-paper"
           move_opponent.prev.move = paste(player_move, opponent.prev.move, sep = "-")) %>%
    filter(player_move != "none", opponent.prev.move != "none") %>% # ignore "none" moves for this aggregation
    group_by(game_id, player_id) %>%
    count(move_opponent.prev.move) %>%
    group_by(game_id, player_id, move_opponent.prev.move) %>%
    mutate(player_move = strsplit(move_opponent.prev.move, "-")[[1]][1], # add player_move back in because we lose it in the count() call above
           opponent.prev.move = strsplit(move_opponent.prev.move, "-")[[1]][2]) %>% # add opponent.prev.move back in because we lose it in the count() call above
    group_by(game_id, player_id, opponent.prev.move) %>%
    mutate(row.totals = sum(n),
           # probability of this player move, conditioned on opponent previous move
           pmove_opponent.prev.move = n / row.totals)
}

# Function to summarize probability of each move for each participant, conditioned on their *own* previous move
get_player_prev_move_cond = function(data) {
  data %>%
    group_by(game_id, player_id) %>%
    mutate(prev.move = lag(player_move, 1),
           # category of move given previous move, e.g. "rock-paper"
           move_prev.move = paste(player_move, prev.move, sep = "-")) %>%
    filter(!is.na(prev.move), # lag call above sets NA for lag on very first move: ignore it here
           player_move != "none", prev.move != "none") %>% # ignore "none" moves for this aggregation
    count(move_prev.move) %>%
    group_by(game_id, player_id, move_prev.move) %>%
    mutate(player_move = strsplit(move_prev.move, "-")[[1]][1], # add player_move back in because we lose it in the count() call above
           prev.move = strsplit(move_prev.move, "-")[[1]][2]) %>% # add prev.move back in because we lose it in the count() call above
    group_by(game_id, player_id, prev.move) %>%
    mutate(row.totals = sum(n),
           # probability of this player move, conditioned on previous move
           pmove_prev.move = n / row.totals)
}

# Function to get conditional distribution of each player's transition (+/-/0), given their previous outcome (win, tie, loss)
get_player_transition_outcome_cond = function(data) {
  sep = "_"
  data %>%
    group_by(game_id, player_id) %>%
    mutate(prev.move = lag(player_move, 1),
           prev.outcome = lag(player_outcome, 1)) %>%
    filter(!is.na(prev.outcome), # lag call above sets NA for lag on first oucome: ignore it here
           !is.na(prev.move), # lag call above sets NA for lag on first move: ignore it here
           prev.move != "none", player_move != "none") %>%
    # NB: this can be slow to execute
    mutate(player.transition = case_when(prev.move == player_move ~ "0",
                                         ((prev.move == "rock" & player_move == "paper") |
                                            (prev.move == "paper" & player_move == "scissors") |
                                            (prev.move == "scissors" & player_move == "rock")) ~ "+",
                                         ((prev.move == "rock" & player_move == "scissors") |
                                            (prev.move == "paper" & player_move == "rock") |
                                            (prev.move == "scissors" & player_move == "paper")) ~ "-"),
           player.outcome.transition = paste(prev.outcome, player.transition, sep = sep)) %>%
    count(player.outcome.transition) %>%
    group_by(game_id, player_id, player.outcome.transition) %>%
    mutate(prev.outcome = strsplit(player.outcome.transition, sep)[[1]][1], # add prev.outcome back in because we lose it in the count() call above
           player.transition = strsplit(player.outcome.transition, sep)[[1]][2]) %>% # add player.transition back in because we lose it in the count() call above
    group_by(game_id, player_id, prev.outcome) %>%
    mutate(row.totals = sum(n),
           # probability of this player transition, conditioned on previous outcome
           p.transition.outcome = n / row.totals)
}

# Function to summarize probability of each move for each participant, conditioned on their *own* previous *two* moves.
get_player_prev_2move_cond = function(data, moves) {
  game_player_set = data %>% distinct(game_id, player_id)
  prev.2move.df = data.frame(game_id = character(), player_id = character(), 
                             player_move = character(), prev.move = character(), prev.move2 = character(),
                             n = numeric(), row.totals = numeric(),
                             stringsAsFactors = F)
  # TODO can we do this without a nested loop....
  # Bayesian smoothing, put count of 1 in each combination before adding true counts
  for (player.move in moves) {
    for (prev.move in moves) {
      for (prev.move2 in moves) {
        prev.2move.df = rbind(prev.2move.df, data.frame(game_id = game_player_set$game_id,
                                                        player_id = game_player_set$player_id,
                                                        player_move = player.move,
                                                        prev.move = prev.move,
                                                        prev.move2 = prev.move2,
                                                        n = 1, row.totals = length(moves),
                                                        stringsAsFactors = F))
        
      }
    }
  }
  tmp = data %>%
    group_by(game_id, player_id) %>%
    mutate(prev.move = lag(player_move, 1), # one move back (previous move)
           prev.move2 = lag(player_move, 2), # two moves back
           move_2prev.move = paste(player_move, prev.move, prev.move2, sep = "-")) %>% # category of move given previous two moves, e.g. "rock-paper-rock"
    filter(!is.na(prev.move), !is.na(prev.move2), # lag calls above set NA for lag on first move and second moves: ignore it here
           player_move != "none", prev.move != "none", prev.move2 != "none") %>% # ignore "none" moves for this aggregation
    count(move_2prev.move) %>%
    group_by(game_id, player_id, move_2prev.move) %>%
    mutate(player_move = strsplit(move_2prev.move, "-")[[1]][1], # add player_move back in because we lose it in the count() call above
           prev.move = strsplit(move_2prev.move, "-")[[1]][2], # add prev.move back in because we lose it in the count() call above
           prev.move2 = strsplit(move_2prev.move, "-")[[1]][3]) %>% # add prev.move2 back in because we lose it in the count() call above
    group_by(game_id, player_id, prev.move, prev.move2) %>%
    mutate(row.totals = sum(n))
  
  # return initial counts set to 1 in prev.2move.df plus counts calculated in tmp above
  left_join(prev.2move.df, tmp, by = c("game_id", "player_id", "player_move", "prev.move", "prev.move2")) %>%
    mutate(n.agg = ifelse(is.na(n.y), n.x, n.x + n.y),
           row.totals.agg = ifelse(is.na(row.totals.y), row.totals.x, row.totals.x + row.totals.y),
           pmove_2prev.move = n.agg / row.totals.agg) %>%
    select(game_id, player_id, player_move, prev.move, prev.move2, 
           n.agg, row.totals.agg, pmove_2prev.move) %>%
    arrange(game_id, player_id, player_move, prev.move, prev.move2)
}

# Function to summarize probability of each move for each participant, conditioned on the combination of their previous move *and* their opponent's previous move
get_player_opponent_prev_move_cond = function(data, moves) {
  game_player_set = data %>% distinct(game_id, player_id)
  prev.2move.df = data.frame(game_id = character(), player_id = character(), 
                             player_move = character(), opponent.prev.move = character(), opponent.prev.move2 = character(),
                             n = numeric(), row.totals = numeric(),
                             stringsAsFactors = F)
  # TODO can we do this without a nested loop....
  # Bayesian smoothing, put count of 1 in each combination before adding true counts
  for (player.move in moves) {
    for (prev.move in moves) {
      for (prev.move2 in moves) {
        prev.2move.df = rbind(prev.2move.df, data.frame(game_id = game_player_set$game_id,
                                                        player_id = game_player_set$player_id,
                                                        player_move = player.move,
                                                        prev.move = prev.move,
                                                        opponent.prev.move = prev.move2,
                                                        n = 1, row.totals = length(moves),
                                                        stringsAsFactors = F))
        
      }
    }
  }
  
  tmp = data %>%
    # add each player's previous move, then use that when referencing opponent's previous move
    group_by(game_id, player_id) %>%
    mutate(prev.move = lag(player_move, 1)) %>%
    filter(!is.na(prev.move)) %>% # lag call above sets NA for lag on very first move: ignore it here
    group_by(game_id, round_index) %>%
    # opponent's previous move is previous row's prev.move for one of the players, next row's prev.move for the other
    mutate(opponent.prev.move = ifelse(is.na(lag(player_move, 1)), lead(prev.move, 1), lag(prev.move, 1)),
           # add category of move given previous move, opponent previous move (e.g. "rock-scissors-scissors")
           move_prev.move_opponent.prev.move = paste(player_move, prev.move, opponent.prev.move, sep = "-")) %>%
    filter(player_move != "none", prev.move != "none", opponent.prev.move != "none") %>% # ignore "none" moves for this purpose
    group_by(game_id, player_id) %>%
    count(move_prev.move_opponent.prev.move) %>%
    group_by(game_id, player_id, move_prev.move_opponent.prev.move) %>%
    mutate(player_move = strsplit(move_prev.move_opponent.prev.move, "-")[[1]][1], # add player_move back in because we lose it in the count() call above
           prev.move = strsplit(move_prev.move_opponent.prev.move, "-")[[1]][2], # add prev.move back in because we lose it in the count() call above
           opponent.prev.move = strsplit(move_prev.move_opponent.prev.move, "-")[[1]][3]) %>% # add opponent.prev.move back in because we lose it in the count() call above
    group_by(game_id, player_id, prev.move, opponent.prev.move) %>%
    mutate(row.totals = sum(n))
  
  # return initial counts set to 1 in prev.2move.df plus counts calculated in tmp above
  left_join(prev.2move.df, tmp, by = c("game_id", "player_id", "player_move", "prev.move", "opponent.prev.move")) %>%
    mutate(n.agg = ifelse(is.na(n.y), n.x, n.x + n.y),
           row.totals.agg = ifelse(is.na(row.totals.y), row.totals.x, row.totals.x + row.totals.y),
           pmove_prev.move_opponent.prev.move = n.agg / row.totals.agg) %>%
    select(game_id, player_id, player_move, prev.move, opponent.prev.move, 
           n.agg, row.totals.agg, pmove_prev.move_opponent.prev.move) %>%
    arrange(game_id, player_id, player_move, prev.move, opponent.prev.move)
}

# Function to get conditional distribution of each player's transition (+/-/0), given the combination of *their previous transition and their previous outcome*
get_player_transition_prev_transition_prev_outcome_cond = function(data, transitions, outcomes) {
  game_player_set = data %>% distinct(game_id, player_id)
  player.transition.prev.transition.prev.outcome.df = data.frame(game_id = character(), player_id = character(), 
                                                                 player.transition = character(), player.prev.transition = character(), prev.outcome = character(),
                                                                 n = numeric(), row.totals = numeric(),
                                                                 stringsAsFactors = F)
  # TODO can we do this without a nested loop....
  # Bayesian smoothing, put count of 1 in each combination before adding true counts
  for (player.trans in transitions) {
    for (prev.trans in transitions) {
      for (prev.outcome in outcomes) {
        player.transition.prev.transition.prev.outcome.df = rbind(player.transition.prev.transition.prev.outcome.df, 
                                                                  data.frame(game_id = game_player_set$game_id, 
                                                                             player_id = game_player_set$player_id,
                                                                             player.transition = player.trans,
                                                                             player.prev.transition = prev.trans,
                                                                             prev.outcome = prev.outcome,
                                                                             n = 1, row.totals = length(transitions),
                                                                             stringsAsFactors = F))
        
      }
    }
  }
  sep = "_"
  tmp = data %>%
    group_by(game_id, player_id) %>%
    mutate(prev.outcome = lag(player_outcome, 1),
           prev.move = lag(player_move, 1),
           prev.move2 = lag(player_move, 2)) %>%
    filter(!is.na(prev.outcome), # lag call above sets NA for lag on first outcome: ignore it here
           !is.na(prev.move), !is.na(prev.move2), # lag call above sets NA for lag on first two moves: ignore it here
           prev.move2 != "none", prev.move != "none", player_move != "none") %>% 
    # TODO move to a model where we add all these cols once at the beginning then just summarize in each analysis
    mutate(player.transition = case_when(prev.move == player_move ~ "0",
                                         ((prev.move == "rock" & player_move == "paper") |
                                            (prev.move == "paper" & player_move == "scissors") |
                                            (prev.move == "scissors" & player_move == "rock")) ~ "+",
                                         ((prev.move == "rock" & player_move == "scissors") |
                                            (prev.move == "paper" & player_move == "rock") |
                                            (prev.move == "scissors" & player_move == "paper")) ~ "-"),
           player.prev.transition = case_when(prev.move2 == prev.move ~ "0",
                                              ((prev.move2 == "rock" & prev.move == "paper") |
                                                 (prev.move2 == "paper" & prev.move == "scissors") |
                                                 (prev.move2 == "scissors" & prev.move == "rock")) ~ "+",
                                              ((prev.move2 == "rock" & prev.move == "scissors") |
                                                 (prev.move2 == "paper" & prev.move == "rock") |
                                                 (prev.move2 == "scissors" & prev.move == "paper")) ~ "-"),
           player.transition.prev.transition.prev.outcome = paste(player.transition, player.prev.transition, prev.outcome, sep = sep)) %>%
    count(player.transition.prev.transition.prev.outcome) %>%
    group_by(game_id, player_id, player.transition.prev.transition.prev.outcome) %>%
    mutate(player.transition = strsplit(player.transition.prev.transition.prev.outcome, sep)[[1]][1], # add transition back in because we lose it in the count() call above
           player.prev.transition = strsplit(player.transition.prev.transition.prev.outcome, sep)[[1]][2], # add prev. transition back in because we lose it in the count() call above
           prev.outcome = strsplit(player.transition.prev.transition.prev.outcome, sep)[[1]][3]) %>% # add prev. outcome back in because we lose it in the count() call above
    group_by(game_id, player_id, player.prev.transition, prev.outcome) %>%
    mutate(row.totals = sum(n))
  
  # return initial counts set to 1 in smoothing df plus counts calculated in tmp above
  left_join(player.transition.prev.transition.prev.outcome.df, tmp, by = c("game_id", "player_id", "player.transition", "player.prev.transition", "prev.outcome")) %>%
    mutate(n.agg = ifelse(is.na(n.y), n.x, n.x + n.y),
           row.totals.agg = ifelse(is.na(row.totals.y), row.totals.x, row.totals.x + row.totals.y),
           p.transition.prev.transition.prev.outcome = n.agg / row.totals.agg) %>%
    select(game_id, player_id, player.transition, player.prev.transition, prev.outcome, 
           n.agg, row.totals.agg, p.transition.prev.transition.prev.outcome) %>%
    arrange(game_id, player_id, player.transition, player.prev.transition, prev.outcome)
}

# Get maximum expected win count differential based on move probabilities in player_summary
get_expected_win_count_differential_moves = function(player_summary, outcomes, game_rounds) {
  player_summary %>%
    group_by(game_id, player_id) %>%
    summarize(max_util = max(
      rowSums(matrix(rep(pmove, 3), nrow = 3, byrow = T) * outcomes))) %>%
    mutate(win_diff = max_util * game_rounds)
}

# Get maximum expected win count differential based on transition probabilities in player_summary
# TODO can we unify this with the get_expected_win_count_differential_moves function above? 
# only difference is column name (pmove, p.transition)
get_expected_win_count_differential_trans = function(player_summary, outcomes, game_rounds) {
  player_summary %>%
    group_by(game_id, player_id) %>%
    summarize(max_util = max(
      rowSums(matrix(rep(p.transition, 3), nrow = 3, byrow = T) * outcomes))) %>%
    mutate(win_diff = max_util * game_rounds)
}

# Get maximum expected win count differential based on distribution of moves given opponent's previous move
get_expected_win_count_differential_opponent_prev_move = function(player_summary, outcomes, game_rounds) {
  player_summary %>%
    group_by(game_id, player_id, opponent.prev.move) %>%
    # get expected value for each previous move conditional distribution
    summarize(max_util = max(
      rowSums(matrix(rep(pmove_opponent.prev.move, 3), nrow = 3, byrow = T) * outcomes))) %>%
    # normalize expected value for each opponent previous move (uniform)
    mutate(max_util_norm = max_util * (1 / 3)) %>%
    # get overall expected value by summing over (normalized) expected values for each previous move
    group_by(game_id, player_id) %>%
    summarize(win_diff = sum(max_util_norm) * game_rounds)
}

# Get maximum expected win count differential based on distribution of moves given player's previous move
get_expected_win_count_differential_prev_move = function(player_summary, outcomes, game_rounds) {
  player_summary %>%
    group_by(game_id, player_id, prev.move) %>%
    # get expected value for each previous move conditional distribution
    summarize(max_util = max(
      rowSums(matrix(rep(pmove_prev.move, 3), nrow = 3, byrow = T) * outcomes))) %>%
    # normalize expected value for each previous move (uniform)
    mutate(max_util_norm = max_util * (1 / 3)) %>%
    # get overall expected value by summing over (normalized) expected values for each previous move
    group_by(game_id, player_id) %>%
    summarize(win_diff = sum(max_util_norm) * game_rounds)
}

# Get maximum expected win count differential based on distribution of transitions given player's previous outcome
get_expected_win_count_differential_prev_outcome = function(player_summary, outcomes, game_rounds) {
  player_summary %>%
    group_by(game_id, player_id, prev.outcome) %>%
    # get expected value for each previous move conditional distribution
    summarize(max_util = max(
      rowSums(matrix(rep(p.transition.outcome, 3), nrow = 3, byrow = T) * outcomes))) %>%
    # normalize expected value for each previous outcome (uniform)
    mutate(max_util_norm = max_util * (1 / 3)) %>%
    # get overall expected value by summing over (normalized) expected values for each previous move
    group_by(game_id, player_id) %>%
    summarize(win_diff = sum(max_util_norm) * game_rounds)
}

# Get maximum expected win count differential based on distribution of moves given player's previous two moves
get_expected_win_count_differential_prev_2moves = function(player_summary, outcomes, game_rounds) {
  player_summary %>%
    group_by(game_id, player_id, prev.move, prev.move2) %>%
    # get expected value for each previous move conditional distribution
    summarize(max_util = max(
      rowSums(matrix(rep(pmove_2prev.move, 3), nrow = 3, byrow = T) * outcomes))) %>%
    # normalize expected value for each previous two-move combination (uniform)
    mutate(max_util_norm = max_util * (1 / 9)) %>%
    # get overall expected value by summing over (normalized) expected values for each previous move
    group_by(game_id, player_id) %>%
    summarize(win_diff = sum(max_util_norm) * game_rounds)
}

# Get maximum expected win count differential based on distribution of moves given player's previous move, opponent's previous move
get_expected_win_count_differential_prev_move_opponent_prev_move = function(player_summary, outcomes, game_rounds) {
  player_summary %>%
    group_by(game_id, player_id, prev.move, opponent.prev.move) %>%
    # get expected value for each previous move conditional distribution
    summarize(max_util = max(
      rowSums(matrix(rep(pmove_prev.move_opponent.prev.move, 3), nrow = 3, byrow = T) * outcomes))) %>%
    # normalize expected value for each previous two-move combination (uniform)
    mutate(max_util_norm = max_util * (1 / 9)) %>%
    # get overall expected value by summing over (normalized) expected values for each previous move
    group_by(game_id, player_id) %>%
    summarize(win_diff = sum(max_util_norm) * game_rounds)
}

# Get maximum expected win count differential based on distribution of moves given player's previous transition, previous outcome
get_expected_win_count_differential_prev_transition_prev_outcome = function(player_summary, outcomes, game_rounds) {
  player_summary %>%
    group_by(game_id, player_id, player.prev.transition, prev.outcome) %>%
    # get expected value for each previous move conditional distribution
    summarize(max_util = max(
      rowSums(matrix(rep(p.transition.prev.transition.prev.outcome, 3), nrow = 3, byrow = T) * outcomes))) %>%
    # normalize expected value for each previous two-move combination (uniform)
    mutate(max_util_norm = max_util * (1 / 9)) %>%
    # get overall expected value by summing over (normalized) expected values for each previous move
    group_by(game_id, player_id) %>%
    summarize(win_diff = sum(max_util_norm) * game_rounds)
}

# Get summary stats for win count differential
get_win_count_differential_summary = function(data, category) {
  data %>%
    ungroup() %>%
    summarize(
      category = category,
      mean_wins = mean(win_diff),
      n = n(),
      se = sd(win_diff) / sqrt(n),
      ci_lower = mean_wins - se,
      ci_upper = mean_wins + se
    )
}


#### Bot Analysis Functions ####

get_bot_strategy_win_count_differential = function(data) {
  # NB: this is different from the empirical win count differential in v1 because
  # we care about human wins - bot wins, not absolute value between each player
  win_diff = data %>%
    group_by(bot_strategy, game_id, player_id, is_bot) %>%
    count(win_count = player_outcome == "win") %>%
    filter(win_count == TRUE) %>%
    group_by(bot_strategy, game_id) %>%
    summarize(win_count_diff = n[is_bot == 0] - n[is_bot == 1]) %>%
    as.data.frame()
  return(win_diff)
}

get_bot_strategy_win_count_differential_summary = function(strategy_data) {
  strategy_data %>%
    group_by(bot_strategy) %>%
    summarize(mean_win_count_diff = mean(win_count_diff),
              n = n(),
              se = sd(win_count_diff) / sqrt(n),
              lower_se = mean_win_count_diff - se,
              upper_se = mean_win_count_diff + se)
}

# Divide each subject's trials into blocks of size blocksize (e.g. 10 trials)
# then get each subject's win percent in each block
get_subject_block_data = function(data, blocksize) {
  data %>%
    filter(is_bot == 0) %>%
    group_by(bot_strategy, round_index) %>%
    mutate(round_block = ceiling(round_index / blocksize)) %>%
    select(bot_strategy, round_index, game_id, player_id, player_outcome, round_block) %>%
    group_by(bot_strategy, game_id, player_id, round_block) %>%
    count(win = player_outcome == "win") %>%
    mutate(total = sum(n),
           win_pct = n / total) %>%
    filter(win == TRUE)
}

# Take in subject block win percent (calculated above) and summarize by bot strategy across subjects
get_block_data_summary = function(subject_block_data) {
  subject_block_data %>%
    group_by(bot_strategy, round_block) %>%
    summarize(subjects = n(),
              mean_win_pct = mean(win_pct),
              se_win_pct = sd(win_pct) / sqrt(subjects),
              lower_ci = mean_win_pct - se_win_pct,
              upper_ci = mean_win_pct + se_win_pct)
}

# Get loss percent for each bot dependent on their previous move
get_bot_prev_move_loss_pct = function(data) {
  data %>%
    filter(# round_index <= 15, # TODO exploratory
      bot_strategy == "prev_move_positive" | bot_strategy == "prev_move_negative") %>%
    group_by(player_id) %>%
    mutate(prev_move = lag(player_move, 1)) %>%
    filter(is_bot == 1, # look only at bot prev moves
           !is.na(prev_move), # lag call above sets NA for lag on first move: ignore it here
           prev_move != "none") %>%
    group_by(bot_strategy, game_id, player_id, prev_move) %>%
    count(player_outcome) %>%
    filter(!is.na(player_outcome)) %>% # TODO why do we have NA game outcomes??
    group_by(bot_strategy, game_id, player_id, prev_move) %>%
    # player win percent calculated as bot loss percent
    summarize(player_win_pct = max(0, n[player_outcome == "loss"]) / max(1, sum(n)))
}

# Get win percent for each player dependent on their own previous move
get_player_prev_move_win_pct = function(data) {
  data %>%
    filter(is_bot == 0,
           # round_index <= 15, # TODO exploratory
           bot_strategy == "opponent_prev_move_nil" | bot_strategy == "opponent_prev_move_positive") %>%
    group_by(player_id) %>%
    mutate(prev_move = lag(player_move, 1)) %>%
    filter(!is.na(prev_move), # lag call above sets NA for lag on first move: ignore it here
           prev_move != "none") %>%
    group_by(bot_strategy, game_id, player_id, prev_move) %>%
    count(player_outcome) %>%
    filter(!is.na(player_outcome)) %>% # TODO why do we have NA game outcomes??
    group_by(bot_strategy, game_id, player_id, prev_move) %>%
    # player win percent calculated using player win outcomes
    summarize(player_win_pct = max(0, n[player_outcome == "win"]) / max(1, sum(n)))
}

# Get loss percent for each bot dependent on the bot's previous outcome
get_bot_prev_outcome_loss_pct = function(data) {
  data %>%
    filter(# round_index >= 270, # TODO exploratory
      bot_strategy == "win_nil_lose_positive" | bot_strategy == "win_positive_lose_negative") %>%
    group_by(player_id) %>%
    mutate(prev_outcome = lag(player_outcome, 1)) %>%
    filter(is_bot == 1, # look only at bot prev moves
           !is.na(prev_outcome)) %>% # lag call above sets NA for lag on first move: ignore it here
    group_by(bot_strategy, game_id, player_id, prev_outcome) %>%
    count(player_outcome) %>%
    filter(!is.na(player_outcome)) %>% # TODO why do we have NA game outcomes??
    group_by(bot_strategy, game_id, player_id, prev_outcome) %>%
    # player win percent calculated as bot loss percent
    summarize(player_win_pct = max(0, n[player_outcome == "loss"]) / max(1, sum(n)))
}

# Get summary win percent by strategy (dependent on previous move by bot or player)
get_bot_prev_move_win_pct_summary = function(prev_move_data) {
  prev_move_data %>%
    group_by(bot_strategy, prev_move) %>%
    summarize(mean_player_win_pct = mean(player_win_pct),
              n = n(),
              se = sd(player_win_pct) / sqrt(n),
              se_lower = mean_player_win_pct - se,
              se_upper = mean_player_win_pct + se)
}

# Get summary win percent by strategy (dependent on previous outcome by bot or player)
get_prev_outcome_win_pct_summary = function(bot_loss_prev_outcome) {
  bot_loss_prev_outcome %>%
    group_by(bot_strategy, prev_outcome) %>%
    summarize(mean_player_win_pct = mean(player_win_pct),
              n = n(),
              se = sd(player_win_pct) / sqrt(n),
              se_lower = mean_player_win_pct - se,
              se_upper = mean_player_win_pct + se)
}



#### GRAPHING STYLE FUNCTIONS ####

individ_plot_theme = theme(
  # titles
  plot.title = element_text(face = "bold", size = 24),
  axis.title.y = element_text(face = "bold", size = 20),
  axis.title.x = element_text(face = "bold", size = 20),
  legend.title = element_text(face = "bold", size = 16),
  # axis text
  axis.text.y = element_text(size = 14, face = "bold"),
  axis.text.x = element_text(size = 14, angle = 45, vjust = 0.5, face = "bold"),
  # legend text
  legend.text = element_text(size = 16, face = "bold"),
  # facet text
  strip.text = element_text(size = 12),
  # backgrounds, lines
  panel.background = element_blank(),
  strip.background = element_blank(),
  
  panel.grid = element_line(color = "gray"),
  axis.line = element_line(color = "black"),
  # positioning
  legend.position = "bottom",
  legend.key = element_rect(colour = "transparent", fill = "transparent")
)


#### GRAPHING FUNCTIONS ####

plot_win_count_differentials = function(win_count_diff_empirical, win_count_diff_null, scale_factor, ceil) {
  win_count_diff_empirical %>%
    ggplot(aes(x = win_diff, color = cat, fill = cat)) +
    geom_histogram(
      alpha = 0.4,
      breaks = c(seq(0, ceil, by = 10)), 
      position = "identity") +
    geom_histogram(data = win_count_diff_null,
                   aes(y = ..count.. * scale_factor, x = win_diff, color = cat, fill = cat),
                   alpha = 0.6,
                   breaks = c(seq(0, ceil, by = 10)),
                   position = "identity") +
    labs(x = "Dyad win count differential", y = "Count (equal scales)") +
    scale_color_viridis(discrete = T,
                        name = element_blank(),
                        begin = 0.2,
                        end = 0.8) +
    scale_fill_viridis(discrete = T,
                       name = element_blank(),
                       begin = 0.2, 
                       end = 0.8) +
    ggtitle("Distribution of win count differentials") +
    individ_plot_theme
  
}

plot_acf = function(acf_data, ci) {
  summary_acf = acf_data %>%
    group_by(lag) %>%
    summarize(mean_acf = mean(acf))
  
  acf_data %>%
    ggplot(aes(x = lag, y = acf)) +
    geom_jitter(aes(color = "ind"), alpha = 0.5, width = 0.1, size = 2) +
    geom_point(data = summary_acf, aes(x = lag, y = mean_acf, color = "mean"), size = 4) +
    scale_x_continuous(breaks = seq(0, max(acf_data$lag))) +
    # significance thresholds
    geom_hline(yintercept = ci, linetype = "dashed", size = 1, color = "black") +
    geom_hline(yintercept = -ci, linetype = "dashed", size = 1, color = "black") +
    scale_color_viridis(discrete = T,
                        labels = c("ind" = "Individual dyads", "mean" = "Average across dyads"),
                        # Set color range to avoid purple and yellow contrasts...
                        name = element_blank(),
                        begin = 0.8,
                        end = 0.2) +
    labs(x = "Lag (game rounds)", y = "Outcome auto-correlation") +
    ggtitle("Auto-correlation of round outcomes") +
    individ_plot_theme
}

plot_dyad_win_count_differential_summary = function(win_count_diff_summary, win_count_diff_empirical, win_count_diff_empirical_summary, win_count_diff_null) {
  legend.width = 10
  summary_labels = c("empirical" = str_wrap("Empirical results", legend.width),
                     "null_sample" = str_wrap("Random behavior", legend.width),
                     "move_probability" = str_wrap("Choice baserate (R/P/S)", legend.width),
                     "trans_probability" = str_wrap("Transition baserate (+/-/0)", legend.width),
                     "cournot_probability" = str_wrap("Opponent transition baserate (+/-/0)", legend.width),
                     "opponent_prev_move_probability" = str_wrap("Choice given opponent's prior choice", legend.width),
                     "prev_move_probability" = str_wrap("Choice given player's prior choice", legend.width),
                     "player_transition_prev_outcome_probability" = str_wrap("Transition given prior outcome (W/L/T)", legend.width),
                     "prev_2move_probability" = str_wrap("Choice given player's prior two choices", legend.width),
                     "prev_move_opponent_prev_move_probability" = str_wrap("Choice given player's prior choice & opponent's prior choice", legend.width),
                     "player_transition_prev_transition_prev_outcome_probability" = str_wrap("Transition given prior transition & prior outcome", legend.width))
  summary_values = c("move_probability", 
                     "cournot_probability", "trans_probability",
                     "opponent_prev_move_probability", "prev_move_probability",
                     "player_transition_prev_outcome_probability",
                     "prev_2move_probability", "prev_move_opponent_prev_move_probability",
                     "player_transition_prev_transition_prev_outcome_probability")
  x_values = c("empirical", 
               "null_sample", "move_probability", 
               "cournot_probability", "trans_probability", 
               "opponent_prev_move_probability", "prev_move_probability",
               "player_transition_prev_outcome_probability",
               "prev_2move_probability", "prev_move_opponent_prev_move_probability",
               "player_transition_prev_transition_prev_outcome_probability")
  
  win_count_diff_summary %>%
    ggplot(aes(x = factor(category, 
                          # TODO extract these automatically from the data object above rather than making a variable
                          levels = summary_values), 
               y = mean_wins)) +
    # points for expected value win count diffs
    geom_point(aes(color = factor(category, 
                                  levels = summary_values)), size = 6) +
    # errorbars for expected value win count diffs
    geom_errorbar(aes(color = factor(category, 
                                     levels = summary_values),
                      ymin = ci_lower, ymax = ci_upper), width = 0.25, size = 1) +
    # raw data for empirical win count diffs
    geom_jitter(data = win_count_diff_empirical, aes(x = factor("empirical"), y = win_diff),
                color = "blue", alpha = 0.5, width = 0.2, size = 4) +
    geom_point(data = win_count_diff_empirical, aes(x = factor("empirical"), y = mean(win_diff)),
               color = "red", size = 6) +
    geom_errorbar(data = win_count_diff_empirical_summary, aes(x = factor("empirical"), 
                                                               ymin = ci_lower, ymax = ci_upper),
                  color = "red", width = 0.25, size = 1) +
    # point for mean null win count diff
    geom_point(data = win_count_diff_null, aes(x = factor("null_sample"), y = mean(win_diff)), size = 6, color = "black") +
    labs(x = "", y = "Dyad win count differential") +
    ggtitle("Theoretical and empirical exploitability of player moves") +
    scale_x_discrete(limits = x_values,
                     labels = summary_labels) +
    scale_color_viridis(discrete = TRUE,
                        name = element_blank()) +
    individ_plot_theme +
    theme(plot.title = element_text(size = 32, face = "bold"),
          axis.title.y = element_text(size = 24, face = "bold"),
          axis.text.x = element_text(size = 20, face = "bold", angle = 0, vjust = 1),
          axis.text.y = element_text(face = "bold", size = 20),
          legend.position = "none")
}

# Plot mean + SEM of each strategy
plot_bot_strategy_win_count_differential_summary = function(wcd_summary) {
  label_width = 10
  summary_labels = c("prev_move_positive" = str_wrap(STRATEGY_LOOKUP[["prev_move_positive"]], label_width),
                     "prev_move_negative" = str_wrap(STRATEGY_LOOKUP[["prev_move_negative"]], label_width),
                     "opponent_prev_move_positive" = str_wrap(STRATEGY_LOOKUP[["opponent_prev_move_positive"]], label_width),
                     "opponent_prev_move_nil" = str_wrap(STRATEGY_LOOKUP[["opponent_prev_move_nil"]], label_width),
                     "win_nil_lose_positive" = str_wrap(STRATEGY_LOOKUP[["win_nil_lose_positive"]], label_width),
                     "win_positive_lose_negative" = str_wrap(STRATEGY_LOOKUP[["win_positive_lose_negative"]], label_width),
                     "outcome_transition_dual_dependency" = str_wrap(STRATEGY_LOOKUP[["outcome_transition_dual_dependency"]], label_width))
  
  wcd_summary %>%
    ggplot(aes(x = bot_strategy, y = mean_win_count_diff)) +
    geom_point(aes(color = bot_strategy),
               size = 6) +
    geom_errorbar(aes(color = bot_strategy, ymin = lower_se, ymax = upper_se),
                  width = 0.25, size = 1) +
    geom_hline(yintercept = 0, size = 1, linetype = "dashed", color = "red") +
    labs(x = "", y = "Mean win count differential") +
    #ggtitle("Win count differential across bot strategies") +
    ggtitle("Aggregate") +
    #scale_x_discrete(labels = summary_labels) +
    scale_color_viridis(discrete = TRUE,
                        name = element_blank()) +
    individ_plot_theme +
    theme(
      # plot.title = element_text(size = 32, face = "bold"),
      axis.title.y = element_text(size = 24, face = "bold"),
      # axis.text.x = element_text(size = 20, face = "bold", angle = 0, vjust = 1),
      # axis.text.x = element_text(size = 20, face = "bold", angle = 0, vjust = 1),
      axis.text.x = element_blank(),
      # axis.text.y = element_text(face = "bold", size = 20),
      legend.position = "none"
    )
}

# Plot average of each participant's win percent in blocks of trials by strategy
plot_bot_strategy_win_pct_by_block = function(block_data_summary) {
  label_width = 12
  strategy_labels = c("prev_move_positive" = str_wrap(STRATEGY_LOOKUP[["prev_move_positive"]], label_width), 
                      "prev_move_negative" = str_wrap(STRATEGY_LOOKUP[["prev_move_negative"]], label_width),
                      "opponent_prev_move_nil" = str_wrap(STRATEGY_LOOKUP[["opponent_prev_move_nil"]], label_width),
                      "opponent_prev_move_positive" = str_wrap(STRATEGY_LOOKUP[["opponent_prev_move_positive"]], label_width),
                      "win_nil_lose_positive" = str_wrap(STRATEGY_LOOKUP[["win_nil_lose_positive"]], label_width),
                      "win_positive_lose_negative" = str_wrap(STRATEGY_LOOKUP[["win_positive_lose_negative"]], label_width),
                      "outcome_transition_dual_dependency" = str_wrap(STRATEGY_LOOKUP[["outcome_transition_dual_dependency"]], label_width))
  
  block_labels = c("1" = "30", "2" = "60", "3" = "90", "4" = "120", "5" = "150",
                   "6" = "180", "7" = "210", "8" = "240", "9" = "270", "10" = "300")
  
  block_data_summary %>%
    ggplot(aes(x = round_block, y = mean_win_pct, color = bot_strategy)) +
    geom_point(size = 6, alpha = 0.75) +
    geom_errorbar(aes(ymin = lower_ci, ymax = upper_ci), size = 1, width = 0.25, alpha = 0.75) +
    geom_hline(yintercept = 1 / 3, linetype = "dashed", color = "red", size = 1) +
    labs(x = "Game round", y = "Mean win percentage") +
    # ggtitle("Participant win percentage against bot strategies") +
    ggtitle("By Round") +
    scale_color_viridis(discrete = T,
                        name = element_blank(),
                        labels = strategy_labels) +
    scale_x_continuous(labels = block_labels, breaks = seq(1:10)) +
    individ_plot_theme +
    theme(#axis.text.x = element_blank(),
      axis.title.y = element_text(size = 24, face = "bold"),
      legend.text = element_text(face = "bold", size = 14),
      legend.position = "right",
      legend.spacing.y = unit(1.0, 'lines'),
      #legend.key = element_rect(size = 2),
      legend.key.size = unit(4.75, 'lines'))
}

# Plot average win percent based on previous move dependency
plot_prev_move_win_pct = function(bot_loss_summary_prev_move, strategy, xlabel) {
  bot_loss_summary_prev_move %>%
    filter(bot_strategy == strategy) %>%
    ggplot(aes(x = prev_move, y = mean_player_win_pct)) +
    geom_bar(stat = "identity", alpha = 0.5, color = "grey50", fill = "steelblue") +
    geom_errorbar(aes(ymin = se_lower, ymax = se_upper), width = 0.5, size = 1, color = "midnightblue") +
    geom_hline(yintercept = 1 / 3, linetype = "dashed", color = "red", size = 1) +
    scale_y_continuous(labels = seq(0, 0.8, by = 0.2),
                       breaks = seq(0, 0.8, by = 0.2),
                       limits = c(0, 0.8)) +
    labs(x = xlabel, y = "Avg. player win pct.") +
    ggtitle(STRATEGY_LOOKUP[[strategy]]) +
    individ_plot_theme +
    theme(legend.position = "none",
          axis.text.x = element_text(angle = 0, vjust = 1))
}

# Plot average win percent based on outcome dependency
plot_outcome_win_pct = function(bot_loss_summary_prev_outcome, strategy, xlabel) {
  bot_loss_summary_prev_outcome %>%
    filter(bot_strategy == strategy) %>%
    ggplot(aes(x = prev_outcome, y = mean_player_win_pct)) +
    geom_bar(stat = "identity", alpha = 0.5, color = "grey50", fill = "steelblue") +
    geom_errorbar(aes(ymin = se_lower, ymax = se_upper), width = 0.5, size = 1, color = "midnightblue") +
    geom_hline(yintercept = 1 / 3, linetype = "dashed", color = "red", size = 1) +
    scale_y_continuous(labels = seq(0, 0.8, by = 0.2),
                       breaks = seq(0, 0.8, by = 0.2),
                       limits = c(0, 0.8)) +
    labs(x = xlabel, y = "Avg. player win pct") +
    ggtitle(STRATEGY_LOOKUP[[strategy]]) +
    individ_plot_theme +
    theme(legend.position = "none",
          axis.text.x = element_text(angle = 0, vjust = 1))
}


#### ANALYSIS ####

# Read in data
dyad_data = read_dyad_data(E1_DATA_FILE, GAME_ROUNDS)
unique(dyad_data$game_id)

bot_data = read_bot_data(E2_DATA_FILE, STRATEGY_LEVELS, GAME_ROUNDS)
length(unique(bot_data$game_id))

# How many complete participants do we have for each bot strategy?
bot_data %>%
  filter(is_bot == 0) %>%
  group_by(bot_strategy) %>%
  summarize(n = n() / GAME_ROUNDS)


# Experiment completion time: summary stats
dyad_data %>%
  group_by(player_id) %>%
  summarize(expt_completion_sec = (round_begin_ts[round_index == 300] - round_begin_ts[round_index == 1]) / 1000) %>%
  summarize(mean_expt_completion_sec = mean(expt_completion_sec),
            sd_expt_completion_sec = sd(expt_completion_sec))

bot_data %>%
  filter(is_bot == 0) %>%
  group_by(player_id) %>%
  summarize(expt_completion_sec = (round_begin_ts[round_index == 300] - round_begin_ts[round_index == 1]) / 1000) %>%
  summarize(mean_expt_completion_sec = mean(expt_completion_sec),
            sd_expt_completion_sec = sd(expt_completion_sec))


#### Win Count Differential Analysis ####

# Empirical win count differentials
win_count_diff_empirical = get_empirical_win_count_differential(dyad_data)
WIN_COUNT_DIFF_CEILING = plyr::round_any(max(win_count_diff_empirical$win_diff), 10, f = ceiling)

# Sampled null win count differentials
win_count_diff_null = get_sample_win_count_differential(NULL_SAMPLES, GAME_ROUNDS)

# Plot histograms overlaid
win_count_diff_empirical = win_count_diff_empirical %>%
  mutate(cat = "Empirical data")
win_count_diff_null = win_count_diff_null %>%
  mutate(cat = "Sampled null data")
empirical_n = win_count_diff_empirical %>% nrow()
scale_factor = empirical_n / NULL_SAMPLES

win_hist = plot_win_count_differentials(win_count_diff_empirical, win_count_diff_null, scale_factor, WIN_COUNT_DIFF_CEILING)

# Chi-squared comparison of empirical and null win count differentials
# NB: setting distinct bin_width below has similar results
bin_width = 10
emp_win_count_bins = win_count_diff_empirical %>%
  group_by(bin = cut(win_diff, breaks = seq(0, WIN_COUNT_DIFF_CEILING, by = bin_width), include.lowest = TRUE)) %>% 
  summarise(n = n())

null_win_count_bins = win_count_diff_null %>%
  filter(win_diff <= max(win_count_diff_empirical$win_diff)) %>%
  group_by(bin = cut(win_diff, breaks = seq(0, WIN_COUNT_DIFF_CEILING, by = bin_width), include.lowest = TRUE)) %>% 
  summarise(n = n()) %>%
  mutate(prop = n / sum(n))

chisq.test(emp_win_count_bins$n, p = null_win_count_bins$prop)

# Confirm chi-sq results hold when truncating the top percentiles
# NB: setting distinct percentil_cutoff vals below has similar results
percentile_cutoff = 0.1 # top 10%
win_count_diff_empirical_top = win_count_diff_empirical %>%
  top_frac(win_diff, n = percentile_cutoff)
win_count_diff_empirical_truncated = win_count_diff_empirical %>%
  filter(!game_id %in% win_count_diff_empirical_top$game_id)

emp_win_count_bins_truncated = win_count_diff_empirical_truncated %>%
  group_by(bin = cut(win_diff, breaks = seq(0, WIN_COUNT_DIFF_CEILING, by = bin_width), include.lowest = TRUE)) %>% 
  summarise(n = n())

null_win_count_bins = win_count_diff_null %>%
  filter(win_diff <= max(win_count_diff_empirical_truncated$win_diff)) %>%
  group_by(bin = cut(win_diff, breaks = seq(0, WIN_COUNT_DIFF_CEILING, by = bin_width), include.lowest = TRUE)) %>% 
  summarise(n = n()) %>%
  mutate(prop = n / sum(n))

chisq.test(emp_win_count_bins_truncated$n, p = null_win_count_bins$prop)


#### Autocorrelation Analysis ####

unique_game_data = get_unique_game_data(dyad_data)

# 1. Autocorrelation across all experimental dyads

# Get ACF data
acf_agg = get_game_acf(unique_game_data, MAX_LAG) # NB: this takes 5-10 secs. to run
# Plot ACF data
# significance threshold: 2 SDs from 0 over sqrt(N) obs to get 95% CI on mean of 0 auto-corr (subtract one because only 299 obs for lag-1)
ci_thresh = 2 / sqrt(GAME_ROUNDS - 1)
acf_plot = plot_acf(acf_agg, ci_thresh)


# Plot histogram and autocorrelation together
win_hist + acf_plot


# 3. What kind of streaks are needed to produce significant auto-correlations?
streak_length = 15
streak_pct = (2 * streak_length) / GAME_ROUNDS
sims = 1000 # set to high enough number that we're confident in power below
# Get sample game data to match the empirical number of dyads
sample_acf_data = get_sample_acf(streak_length, GAME_ROUNDS, sims) # takes about 15s for 1000 obs
# Get ACF for sample game data
acf_sample = get_game_acf(sample_acf_data, MAX_LAG) # takes 5-10s for 1000 obs
# Plot ACF data
# significance threshold: 2 SDs from 0 over sqrt(N) obs to get 95% CI on mean of 0 auto-corr (subtract one because only 299 obs for lag-1)
ci_thresh = 2 / sqrt(GAME_ROUNDS - 1)
plot_acf(acf_sample, ci_thresh) # NB: this plot not included in results
# Take-aways: 
# streak_pct needs to be > 10% to detect significant auto-correlations
# by 20% it's very visible

# How much power do we have to detect significant autocorrelations?
# i.e. what fraction of samples from the underlying distribution of non-zero auto-correlated outcomes
# for an individual exceed the significance threshold?
acf_sample %>%
  mutate(sig = acf >= ci_thresh) %>%
  group_by(lag) %>%
  summarize(sig_count = sum(sig),
            total = n(),
            prop = sig_count / total)



#### Max. Expected Win Count Differential Analysis ####

## 1. Distribution of moves (3 cells)
# get overall probability of each move (for each player)
player_summary = get_player_move_dist(dyad_data, MOVE_SET)
# get max utility value for opponent of each player based on each player's move probabilities
player_utils = get_expected_win_count_differential_moves(player_summary, OUTCOME_MATRIX, GAME_ROUNDS)


## 2. Distribution of transitions (3 cells)
# get overall probability of each transition (for each player)
player_transition_summary = get_player_transition_dist(dyad_data)
# get max utility value for opponent of each player based on each player's transition probabilities
player_transition_utils = get_expected_win_count_differential_trans(player_transition_summary, OUTCOME_MATRIX, GAME_ROUNDS)

## 2.5 Distribution of transitions *relative to opponent*, i.e. Cournot responses (3 cells)
# get overall probability of each transition (for each player)
player_transition_cournot_summary = get_player_transition_cournot_dist(dyad_data)
# get max utility value for opponent of each player based on each player's transition probabilities
player_transition_cournot_utils = get_expected_win_count_differential_trans(player_transition_cournot_summary, OUTCOME_MATRIX, GAME_ROUNDS)


## 3. Distribution of moves given opponent's previous move (9 cells)
# get probability of each move for each player given their opponent's previous move
opponent_prev_move_summary = get_opponent_prev_move_cond(dyad_data)
# get max utility value for opponent of each player based on each player's move probabilities *given their opponent's previous move*
opponent_prev_move_utils = get_expected_win_count_differential_opponent_prev_move(opponent_prev_move_summary, OUTCOME_MATRIX, GAME_ROUNDS)


## 4. Distribution of moves given player's previous move (9 cells)
# get probability of each move for each player given their own previous move
player_prev_move_summary = get_player_prev_move_cond(dyad_data)
# get max utility value for opponent of each player based on each player's move probabilities *given their previous move*
player_prev_move_utils = get_expected_win_count_differential_prev_move(player_prev_move_summary, OUTCOME_MATRIX, GAME_ROUNDS)


## 5. Distribution of transitions given previous outcome (9 cells)
# get probability of each transition for each player given their previous outcome
player_transition_prev_outcome_summary = get_player_transition_outcome_cond(dyad_data) 
# get max utility value for opponent of ech player based on each player's transition probabilities *given their previous outcome*
player_transition_prev_outcome_utils = get_expected_win_count_differential_prev_outcome(player_transition_prev_outcome_summary, OUTCOME_MATRIX, GAME_ROUNDS)


## 6. Distribution of moves given player's previous two moves (27 cells)
# get probability of each move for each player given their previous two moves
player_prev_2move_summary = get_player_prev_2move_cond(dyad_data, MOVE_SET)
# get max utility value for opponent of each player based on each player's move probabiliteis *given their previous two moves*
player_prev_2move_utils = get_expected_win_count_differential_prev_2moves(player_prev_2move_summary, OUTCOME_MATRIX, GAME_ROUNDS)


## 7. Distribution of moves given player's previous move, opponent's previous move (27 cells)
# get probability of each move for each player given their previous move, their opponent's previous move
player_opponent_prev_move_summary = get_player_opponent_prev_move_cond(dyad_data, MOVE_SET) 
# get max utility value for opponent of each player based on each player's move probabilities *given their previous move and their opponent's previous move*
player_opponent_prev_move_utils = get_expected_win_count_differential_prev_move_opponent_prev_move(player_opponent_prev_move_summary, OUTCOME_MATRIX, GAME_ROUNDS)


## 8. Distribution of transitions given player's previous transition and previous outcome (27 cells)
# get probability of each transition for each player given their previous transition and player's previous outcome
player_transition_prev_transition_prev_outcome_summary = get_player_transition_prev_transition_prev_outcome_cond(dyad_data, TRANSITION_SET, OUTCOME_SET) 
# get max utility value for opponent of each player based on each player's transition probabilities *given their previous transition and previous outcome*
player_transition_prev_transition_prev_outcome_utils = get_expected_win_count_differential_prev_transition_prev_outcome(player_transition_prev_transition_prev_outcome_summary, OUTCOME_MATRIX, GAME_ROUNDS)



# Combine summary win count differentials for empirical data, null sample, and expected value calcs
win_count_diff_summary = bind_rows(
  get_win_count_differential_summary(player_utils, "move_probability"),
  get_win_count_differential_summary(player_transition_utils, "trans_probability"),
  get_win_count_differential_summary(player_transition_cournot_utils, "cournot_probability"),
  get_win_count_differential_summary(opponent_prev_move_utils, "opponent_prev_move_probability"),
  get_win_count_differential_summary(player_prev_move_utils, "prev_move_probability"),
  get_win_count_differential_summary(player_transition_prev_outcome_utils, "player_transition_prev_outcome_probability"),
  get_win_count_differential_summary(player_prev_2move_utils, "prev_2move_probability"),
  get_win_count_differential_summary(player_opponent_prev_move_utils, "prev_move_opponent_prev_move_probability"),
  get_win_count_differential_summary(player_transition_prev_transition_prev_outcome_utils, "player_transition_prev_transition_prev_outcome_probability")
)
win_count_diff_empirical_summary = get_win_count_differential_summary(win_count_diff_empirical, "empirical")


# plot summary of win differentials for EV alongside empirical and null data
plot_dyad_win_count_differential_summary(win_count_diff_summary, win_count_diff_empirical, win_count_diff_empirical_summary, win_count_diff_null)


#### Expected Win Count Differential Regression Analysis ####
# NB: this draws on many of the same data structures as the previous analysis

# predicting empirical win count diff
empirical_win_count_diff = get_empirical_win_count_differential(dyad_data)
empirical_win_count_diff = empirical_win_count_diff %>% rename("empirical_wcd" = win_diff)

## 1. Distribution of moves (3 cells)
player_utils_summary = player_utils %>%
  group_by(game_id) %>%
  summarize(max_exp_wcd_move_dist = mean(win_diff))

## 2. Distribution of transitions (3 cells)
player_transition_utils_summary = player_transition_utils %>%
  group_by(game_id) %>%
  summarize(max_exp_wcd_transition = mean(win_diff))

## 2.5 Distribution of transitions *relative to opponent*, i.e. Cournot responses (3 cells)
player_transition_cournot_utils_summary = player_transition_cournot_utils %>%
  group_by(game_id) %>%
  summarize(max_exp_wcd_transition_cournot = mean(win_diff))

## 3. Distribution of moves given opponent's previous move (9 cells)
opponent_prev_move_utils_summary = opponent_prev_move_utils %>%
  group_by(game_id) %>%
  summarize(max_exp_wcd_opponent_prev_move = mean(win_diff))

## 4. Distribution of moves given player's previous move (9 cells)
player_prev_move_utils_summary = player_prev_move_utils %>%
  group_by(game_id) %>%
  summarize(max_exp_wcd_player_prev_move = mean(win_diff))

## 5. Distribution of transitions given previous outcome (9 cells)
player_transition_prev_outcome_utils_summary = player_transition_prev_outcome_utils %>%
  group_by(game_id) %>%
  summarize(max_exp_wcd_transition_outcome = mean(win_diff))

## 6. Distribution of moves given player's previous two moves (27 cells)
player_prev_2move_utils_summary = player_prev_2move_utils %>%
  group_by(game_id) %>%
  summarize(max_exp_wcd_player_prev_2move = mean(win_diff))

## 7. Distribution of moves given player's previous move, opponent's previous move (27 cells)
player_opponent_prev_move_utils_summary = player_opponent_prev_move_utils %>%
  group_by(game_id) %>%
  summarize(max_exp_wcd_player_opponent_prev_move = mean(win_diff))

## 8. Distribution of transitions given player's previous transition and previous outcome (27 cells)
player_transition_prev_transition_prev_outcome_utils_summary = player_transition_prev_transition_prev_outcome_utils %>%
  group_by(game_id) %>%
  summarize(max_exp_wcd_transition_prev_transition_prev_outcome = mean(win_diff))


summary_win_diff = empirical_win_count_diff %>%
  inner_join(player_utils_summary, by = "game_id") %>%
  inner_join(player_transition_utils_summary, by = "game_id") %>%
  inner_join(player_transition_cournot_utils_summary, by = "game_id") %>%
  inner_join(opponent_prev_move_utils_summary, by = "game_id") %>%
  inner_join(player_prev_move_utils_summary, by = "game_id") %>%
  inner_join(player_transition_prev_outcome_utils_summary, by = "game_id") %>%
  inner_join(player_prev_2move_utils_summary, by = "game_id") %>%
  inner_join(player_opponent_prev_move_utils_summary, by = "game_id") %>%
  inner_join(player_transition_prev_transition_prev_outcome_utils_summary, by = "game_id")

# Regression using residuals from composed predictors
summary_win_diff = summary_win_diff %>%
  mutate(opponent_prev_move_resid = residuals(lm(max_exp_wcd_opponent_prev_move ~ max_exp_wcd_move_dist + max_exp_wcd_transition_cournot)),
         player_prev_move_resid = residuals(lm(max_exp_wcd_player_prev_move ~ max_exp_wcd_move_dist + max_exp_wcd_transition)),
         player_opponent_prev_move_resid = residuals(lm(max_exp_wcd_player_opponent_prev_move ~ max_exp_wcd_move_dist + max_exp_wcd_player_prev_move + max_exp_wcd_opponent_prev_move)),
         player_prev_2move_resid = residuals(lm(max_exp_wcd_player_prev_2move ~ max_exp_wcd_move_dist + max_exp_wcd_player_prev_move)),
         transition_outcome_resid = residuals(lm(max_exp_wcd_transition_outcome ~ max_exp_wcd_transition)),
         transition_prev_trans_outcome_resid = residuals(lm(max_exp_wcd_transition_prev_transition_prev_outcome ~ max_exp_wcd_transition_outcome)))

# Full model based on residuals
# This should tell us whether variables composed of other predictors (e.g. transition as subset of prev move) are significant
# above and beyond the compressed predictors they're made up of
mod_resids = with(summary_win_diff, 
                  lm(empirical_wcd ~ max_exp_wcd_move_dist + 
                       max_exp_wcd_transition + 
                       max_exp_wcd_transition_cournot +
                       opponent_prev_move_resid +
                       player_prev_move_resid +
                       player_opponent_prev_move_resid +
                       player_prev_2move_resid +
                       transition_outcome_resid +
                       transition_prev_trans_outcome_resid))
summary(mod_resids) 


#### Bot Strategy Win Count Differential ####

wcd_all = get_bot_strategy_win_count_differential(bot_data)
wcd_summary = get_bot_strategy_win_count_differential_summary(wcd_all)

overall_wcd = plot_bot_strategy_win_count_differential_summary(wcd_summary)


#### Bot Strategy Learning Curves ####

subject_block_data = get_subject_block_data(bot_data, blocksize = 30)
block_data_summary = get_block_data_summary(subject_block_data)

rounds = plot_bot_strategy_win_pct_by_block(block_data_summary)

overall_wcd + rounds +
  plot_layout(widths = c(1, 2)) +
  plot_annotation(tag_levels = 'A') & 
  theme(plot.tag = element_text(size = 24))

#### Bot Strategy Conditional Analysis ####

# Which aspects of each strategy did players detect?
# 1. Bot previous move strategies
bot_loss_prev_move = get_bot_prev_move_loss_pct(bot_data)
bot_loss_summary_prev_move = get_bot_prev_move_win_pct_summary(bot_loss_prev_move)

# Generate plots
prev_move_positive_plot = plot_prev_move_win_pct(bot_loss_summary_prev_move, "prev_move_positive", "Bot previous move")
prev_move_negative_plot = plot_prev_move_win_pct(bot_loss_summary_prev_move, "prev_move_negative", "Bot previous move")

# 2. Player previous move strategies
player_win_prev_move = get_player_prev_move_win_pct(bot_data)
player_win_summary_prev_move = get_bot_prev_move_win_pct_summary(player_win_prev_move)

# Generate plots
opponent_prev_move_positive_plot = plot_prev_move_win_pct(player_win_summary_prev_move, "opponent_prev_move_positive", "Player previous move")
opponent_prev_move_nil_plot = plot_prev_move_win_pct(player_win_summary_prev_move, "opponent_prev_move_nil", "Player previous move")

# 3. Bot previous outcome
bot_loss_prev_outcome = get_bot_prev_outcome_loss_pct(bot_data)
bot_loss_summary_prev_outcome = get_prev_outcome_win_pct_summary(bot_loss_prev_outcome)

# Generate plots
win_nil_lose_positive_plot_outcome = plot_outcome_win_pct(bot_loss_summary_prev_outcome, "win_nil_lose_positive", "Bot previous outcome")
win_positive_lose_negative_plot_outcome = plot_outcome_win_pct(bot_loss_summary_prev_outcome, "win_positive_lose_negative", "Bot previous outcome")


# Plot using patchwork
prev_move_positive_plot + prev_move_negative_plot +
  opponent_prev_move_positive_plot + opponent_prev_move_nil_plot +
  win_nil_lose_positive_plot_outcome + win_positive_lose_negative_plot_outcome +
  plot_layout(ncol = 2)











