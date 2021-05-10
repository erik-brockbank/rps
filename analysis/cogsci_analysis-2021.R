#'
#' RPS *adaptive* bot analysis for CogSci 2021
#' Examines human performance against bot opponents with varying
#' adaptive strategies
#'



# SETUP ========================================================================
source('manuscript_analysis.R') # NB: if this fails, run again (takes ~20-30s)

setwd("/Users/erikbrockbank/web/vullab/rps/analysis/")
# rm(list = ls())
library(tidyverse)
library(viridis)
library(wesanderson)
library(patchwork)



# GLOBALS ======================================================================

DATA_FILE = "rps_v3_data.csv" # name of file containing full dataset for all rounds
FREE_RESP_FILE = "rps_v3_data_freeResp.csv" # file containing free response data by participant
SLIDER_FILE = "rps_v3_data_sliderData.csv" # file containing slider Likert data by participant
NUM_ROUNDS = 300 # number of rounds in each complete game

# In order of complexity
STRATEGY_LEVELS = c(
  # 1x3
  # "opponent_moves",
  "opponent_transitions",
  "opponent_courn_transitions",
  # 3x3
  "opponent_prev_move",
  "bot_prev_move",
  "opponent_outcome_transitions",
  # 9x3
  "opponent_bot_prev_move",
  "opponent_prev_two_moves",
  # "bot_prev_two_moves",
  "opponent_outcome_prev_transition_dual"
)

STRATEGY_LOOKUP = list(
  # "opponent_moves" = "Move distribution",
  "opponent_prev_move" = "Transition given player's prior choice",
  "bot_prev_move" = "Transition given opponent's prior choice",
  "opponent_bot_prev_move" = "Choice given player's prior choice & opponent's prior choice",
  "opponent_prev_two_moves" = "Choice given player's prior two choices",
  # "bot_prev_two_moves" = "Bot previous two moves",
  "opponent_transitions" = "Transition baserate (+/-/0)",
  "opponent_courn_transitions" = "Opponent transition baserate (+/-/0)",
  "opponent_outcome_transitions" = "Transition given prior outcome (W/L/T)",
  "opponent_outcome_prev_transition_dual" = "Transition given prior transition & prior outcome"
)



# ANALYSIS FUNCTIONS ===========================================================

# Read in and process free response data
read_free_resp_data = function(filename, game_data) {
  data = read_csv(filename)
  # Join with game data to get bot strategy, etc.
  data = data %>%
    inner_join(game_data, by = c("game_id", "player_id")) %>%
    distinct(bot_strategy, game_id, player_id, free_resp_answer)
  # Order bot strategies
  data$bot_strategy = factor(data$bot_strategy, levels = STRATEGY_LEVELS)
  # Add plain english strategy, string process free resposne answers
  data = data %>%
    group_by(bot_strategy, player_id) %>%
    mutate(strategy = STRATEGY_LOOKUP[[bot_strategy]],
           free_resp_answer = str_replace_all(free_resp_answer, "\n" , "[newline]")) %>%
    ungroup()

  return(data)
}

# Read in and process slider data
read_slider_data = function(filename, game_data) {
  data = read_csv(filename)
  data = data %>%
    inner_join(game_data, by = c("game_id", "player_id")) %>%
    distinct(game_id, player_id, bot_strategy, index, statement, resp)
  # Order bot strategies
  data$bot_strategy = factor(data$bot_strategy, levels = STRATEGY_LEVELS)
  # Add plain english strategy
  data = data %>%
    group_by(bot_strategy, player_id, index) %>%
    mutate(strategy = STRATEGY_LOOKUP[[bot_strategy]]) %>%
    ungroup()

  return(data)
}

get_slider_summary = function(slider_data) {
  slider_data %>%
    group_by(statement, bot_strategy, strategy) %>%
    summarize(n = n(),
              mean_resp = mean(resp),
              se = sd(resp) / sqrt(n),
              se_upper = mean_resp + se,
              se_lower = mean_resp - se)
}


get_bot_strategy_win_count_differential = function(data) {
  win_diff = data %>%
    group_by(bot_strategy, game_id, player_id, is_bot) %>%
    count(win_count = player_outcome == "win") %>%
    filter(win_count == TRUE) %>%
    group_by(bot_strategy, game_id) %>%
    # Win count for bots minus win count for human opponents
    # NB: if the person or bot *never* wins, this count will fail for them
    summarize(win_count_diff = n[is_bot == 1] - n[is_bot == 0]) %>%
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
# then get each *bot's* win percent in each block
get_bot_block_data = function(data, blocksize) {
  data %>%
    filter(is_bot == 1) %>%
    group_by(bot_strategy, round_index) %>%
    mutate(round_block = ceiling(round_index / blocksize)) %>%
    select(bot_strategy, round_index, game_id, player_id, player_outcome, round_block) %>%
    group_by(bot_strategy, game_id, player_id, round_block) %>%
    count(win = player_outcome == "win") %>%
    mutate(total = sum(n),
           win_pct = n / total) %>%
    filter(win == TRUE)
}

# Take in block win percent data (calculated above) and summarize by bot strategy
get_block_data_summary = function(subject_block_data) {
  subject_block_data %>%
    group_by(bot_strategy, round_block) %>%
    summarize(subjects = n(),
              mean_win_pct = mean(win_pct),
              se_win_pct = sd(win_pct) / sqrt(subjects),
              lower_ci = mean_win_pct - se_win_pct,
              upper_ci = mean_win_pct + se_win_pct)
}


# GRAPH STYLE ==================================================================

default_plot_theme = theme(
  # titles
  plot.title = element_text(face = "bold", size = 20),
  axis.title.y = element_text(face = "bold", size = 16),
  axis.title.x = element_text(face = "bold", size = 16),
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

label_width = 48 # default: 10
# label_width = 10 # default: 10

strategy_labels = c("opponent_moves" = str_wrap(STRATEGY_LOOKUP[["opponent_moves"]], label_width),
                    "opponent_prev_move" = str_wrap(STRATEGY_LOOKUP[["opponent_prev_move"]], label_width),
                    "bot_prev_move" = str_wrap(STRATEGY_LOOKUP[["bot_prev_move"]], label_width),
                    "opponent_bot_prev_move" = str_wrap(STRATEGY_LOOKUP[["opponent_bot_prev_move"]], label_width),
                    "opponent_prev_two_moves" = str_wrap(STRATEGY_LOOKUP[["opponent_prev_two_moves"]], label_width),
                    "bot_prev_two_moves" = str_wrap(STRATEGY_LOOKUP[["bot_prev_two_moves"]], label_width),
                    "opponent_transitions" = str_wrap(STRATEGY_LOOKUP[["opponent_transitions"]], label_width),
                    "opponent_courn_transitions" = str_wrap(STRATEGY_LOOKUP[["opponent_courn_transitions"]], label_width),
                    "opponent_outcome_transitions" = str_wrap(STRATEGY_LOOKUP[["opponent_outcome_transitions"]], label_width),
                    "opponent_outcome_prev_transition_dual" = str_wrap(STRATEGY_LOOKUP[["opponent_outcome_prev_transition_dual"]], label_width))


# GRAPH FUNCTIONS ==============================================================

plot_block_summary = function(summary_data, individ_data) {
  block_labels = c("1" = "30", "2" = "60", "3" = "90", "4" = "120", "5" = "150",
                   "6" = "180", "7" = "210", "8" = "240", "9" = "270", "10" = "300")
  summary_data %>%
    ggplot(aes(x = round_block, y = mean_win_pct, color = bot_strategy)) +
    geom_point(size = 6, alpha = 0.75) +
    geom_errorbar(aes(ymin = lower_ci, ymax = upper_ci), size = 1, width = 0.25, alpha = 0.75) +
    geom_jitter(data = individ_data, aes(x = round_block, y = win_pct),
                width = 0.1, height = 0, size = 2, alpha = 0.5) +
    geom_hline(yintercept = 1 / 3, linetype = "dashed", color = "red", size = 1) +
    labs(x = "Game round", y = "Bot win percentage") +
    # ggtitle("Bot win percentage against participants") +
    scale_color_viridis(discrete = T,
                        name = element_blank(),
                        labels = strategy_labels) +
    scale_x_continuous(labels = block_labels, breaks = seq(1:10)) +
    # ylim(c(0, 1)) +
    default_plot_theme +
    theme(#axis.text.x = element_blank(),
      axis.title.y = element_text(size = 24, face = "bold"),
      legend.text = element_text(face = "bold", size = 14),
      # legend.position = "right",
      legend.spacing.y = unit(1.0, 'lines'),
      #legend.key = element_rect(size = 2),
      legend.key.size = unit(4.75, 'lines'))
}

plot_slider_data = function(slider_data) {
  q = unique(slider_data$statement)
  slider_data %>%
    ggplot(aes(x = bot_strategy, y = mean_resp, color = bot_strategy)) +
    geom_point(size = 6) +
    geom_errorbar(aes(ymin = se_lower, ymax = se_upper), size = 1, width = 0.25) +
    scale_color_viridis(discrete = T,
                        name = element_blank(),
                        labels = element_blank()) +
    scale_x_discrete(name = element_blank(),
                     labels = strategy_labels) +
    ylim(c(1, 7)) +
    labs(y = "Mean response (1: Strongly disagree, 7: Strongly agree)") +
    ggtitle(str_wrap(q, 50)) +
    default_plot_theme +
    theme(axis.text.x = element_text(angle = 0, vjust = 1),
          axis.title.x = element_blank(),
          legend.position = "none")
}



# PROCESS DATA =================================================================

# Read in data
data = read_csv(DATA_FILE)
data$bot_strategy = factor(data$bot_strategy, levels = STRATEGY_LEVELS)

# Remove all incomplete games
incomplete_games = data %>%
  group_by(game_id, player_id) %>%
  summarize(rounds = max(round_index)) %>%
  filter(rounds < NUM_ROUNDS) %>%
  select(game_id) %>%
  unique()
incomplete_games

data = data %>%
  filter(!(game_id %in% incomplete_games$game_id))

# TODO players with "NA" moves; look into this
# (processing python script writes NA for empty move values)
tmp = data %>% filter(is.na(player_move))
tmp %>% group_by(sona_survey_code) %>% summarize(n())
data = data %>% filter(!is.na(player_move))


# Remove any duplicate complete games that have the same SONA survey code
# NB: this can happen if somebody played all the way through but exited before receiving credit
# First, fetch sona survey codes with multiple complete games
repeat_codes = data %>%
  group_by(sona_survey_code) %>%
  filter(is_bot == 0) %>%
  summarize(trials = n()) %>%
  filter(trials > NUM_ROUNDS) %>%
  select(sona_survey_code)
repeat_codes
# Next, get game id for the earlier complete game
# NB: commented out code checks that we have slider/free resp data for at least one of the games
duplicate_games = data %>%
  filter(sona_survey_code %in% repeat_codes$sona_survey_code &
           is_bot == 0  &
           round_index == NUM_ROUNDS) %>%
  select(sona_survey_code, game_id, player_id, round_begin_ts) %>%
  # remove the later one to avoid results based on experience
  group_by(sona_survey_code) %>%
  filter(round_begin_ts == max(round_begin_ts)) %>%
  # joins below check whether we have slider/free resp data for earlier or later survey code responses
  # inner_join(fr_data, by = c("game_id", "player_id")) %>%
  # inner_join(slider_data, by = c("game_id", "player_id")) %>%
  distinct(game_id)
duplicate_games

data = data %>%
  filter(!game_id %in% duplicate_games$game_id)


# Sanity check: anybody with trials != 300?
trial_count = data %>%
  filter(is_bot == 0) %>%
  group_by(sona_survey_code) %>%
  summarize(trials = n()) %>%
  filter(trials != NUM_ROUNDS)
trial_count


# Check that there are no rows with memory >= 300
# (this was a bug in early data)
mem = data %>%
  filter(round_index == NUM_ROUNDS & is_bot == 1) %>%
  group_by(bot_strategy, game_id, sona_survey_code) %>%
  select(bot_strategy, game_id, sona_survey_code, bot_round_memory)

mem = mem %>%
  rowwise() %>%
  mutate(memory_sum =
           sum(as.numeric(unlist(regmatches(bot_round_memory, gregexpr("[[:digit:]]+", bot_round_memory))))))

mem = mem %>% filter(memory_sum >= NUM_ROUNDS)

data = data %>%
  filter(!sona_survey_code %in% mem$sona_survey_code)



fr_data = read_free_resp_data(FREE_RESP_FILE, data)
slider_data = read_slider_data(SLIDER_FILE, data)
slider_summary = get_slider_summary(slider_data)


# ANALYSIS: participant RTs etc. ===============================================

# How many complete participants for each bot?
data %>%
  filter(is_bot == 0, round_index == NUM_ROUNDS) %>%
  group_by(bot_strategy) %>%
  summarize(subjects = n()) %>%
  summarize(sum(subjects))

# How many times did players play a particular move?
# Note the first person here forced a bot WCD of -67; playing scissors repeatedly
# put the bot in a cycle of loss, tie, loss, ...
# Another person lost 288 times, so move choice is not an exclusion criteria by itself, but can be
data %>%
  filter(is_bot == 0) %>%
  group_by(game_id, player_id) %>%
  count(player_move) %>%
  filter(n >= 250)

# How long did participants take to choose a move?
rt_summary = data %>%
  filter(is_bot == 0) %>% # NB: filtering for actual moves here doesn't decrease mean that much
  group_by(player_id) %>%
  summarize(mean_rt = mean(player_rt),
            mean_log_rt = mean(log10(player_rt)),
            nrounds = n())
rt_summary
mean(rt_summary$mean_log_rt)
sd(rt_summary$mean_log_rt)

# And how often did they choose "none"?
none_moves = data %>%
  filter(is_bot == 0) %>%
  group_by(player_id) %>%
  filter(player_move == "none") %>%
  count(player_move)
none_moves %>% ungroup() %>% filter(n == max(n))

# How long do people spend overall?
completion_summary = data %>%
  filter(is_bot == 0) %>%
  group_by(player_id) %>%
  summarize(completion_time = round_begin_ts[round_index == NUM_ROUNDS],
            start_time =  round_begin_ts[round_index == 1],
            total_secs = (completion_time - start_time) / 1000)

mean(completion_summary$total_secs)
sd(completion_summary$total_secs)


# this person finished the experiment in 90s, chose paper 275 times, and lost 288 times
data = data %>%
  filter(game_id != "f7290e62-697c-46ec-b42d-51090ce3eed5")


# ANALYSIS: Bot strategy win count differentials ===============================
wcd_all = get_bot_strategy_win_count_differential(data)
# exclude data for participant with 200+ losing choices of paper
wcd_summary = get_bot_strategy_win_count_differential_summary(wcd_all)

complexity_lookup = c(
  "opponent_transitions" = "3 cell memory",
  "opponent_courn_transitions" = "3 cell memory",
  "opponent_prev_move" = "9 cell memory",
  "bot_prev_move" = "9 cell memory",
  "opponent_outcome_transitions" = "9 cell memory",
  "opponent_bot_prev_move" = "27 cell memory",
  "opponent_prev_two_moves" = "27 cell memory",
  "opponent_outcome_prev_transition_dual" = "27 cell memory"
)
wcd_summary = wcd_summary %>%
  rowwise() %>%
  mutate(complexity = complexity_lookup[bot_strategy])
wcd_summary$complexity = factor(wcd_summary$complexity,
                                levels = c("3 cell memory", "9 cell memory", "27 cell memory"))

wcd_all = wcd_all %>%
  rowwise() %>%
  mutate(complexity = complexity_lookup[bot_strategy])
wcd_all$complexity = factor(wcd_all$complexity,
                            levels = c("3 cell memory", "9 cell memory", "27 cell memory"))


wcd_summary %>%
  ggplot(aes(x = bot_strategy, y = mean_win_count_diff, color = complexity)) +
  geom_point(size = 6) +
  geom_errorbar(
    aes(ymin = lower_se, ymax = upper_se),
    width = 0.1, size = 1) +
  # geom_jitter(data = wcd_all, aes(x = bot_strategy, y = win_count_diff),
  #             size = 2, alpha = 0.75, width = 0.25, height = 0) +
  geom_hline(yintercept = 0, size = 1, linetype = "dashed") +
  labs(x = "", y = "Bot win count differential") +
  ggtitle("Adaptive bot performance against humans") +
  scale_x_discrete(
    name = element_blank(),
    labels = strategy_labels) +
  scale_color_manual(
    name = "Complexity",
    values = wes_palette("Zissou1", 3, type = "continuous")) +
  default_plot_theme +
  theme(
    plot.title = element_text(size = 32, face = "bold"),
    axis.title.y = element_text(size = 24, face = "bold"),
    # NB: axis title below is to give cushion for adding complexity labels in PPT
    # axis.title.x = element_text(size = 64),
    # axis.text.x = element_blank(),
    axis.text.x = element_text(size = 12, face = "bold", angle = 0, vjust = 1),
    axis.text.y = element_text(size = 14, face = "bold"),
    legend.position = "bottom",
    legend.title = element_text(size = 18, face = "bold"),
    legend.text = element_text(size = 16)
  )


# Basic analysis: which strategies are different from 0?
table(wcd_all$bot_strategy)

t.test(x = wcd_all$win_count_diff[wcd_all$bot_strategy == "opponent_transitions"]) # *
t.test(x = wcd_all$win_count_diff[wcd_all$bot_strategy == "opponent_courn_transitions"]) # ***
t.test(x = wcd_all$win_count_diff[wcd_all$bot_strategy == "opponent_prev_move"]) # NS
t.test(x = wcd_all$win_count_diff[wcd_all$bot_strategy == "bot_prev_move"]) # **
t.test(x = wcd_all$win_count_diff[wcd_all$bot_strategy == "opponent_outcome_transitions"]) # NS
t.test(x = wcd_all$win_count_diff[wcd_all$bot_strategy == "opponent_bot_prev_move"]) # *
t.test(x = wcd_all$win_count_diff[wcd_all$bot_strategy == "opponent_prev_two_moves"]) # ***
t.test(x = wcd_all$win_count_diff[wcd_all$bot_strategy == "opponent_outcome_prev_transition_dual"]) # ***


# Aggregating across strategy complexity
wcd_all = wcd_all %>%
  rowwise() %>%
  mutate(complexity = complexity_lookup[bot_strategy])
wcd_all$complexity = factor(wcd_all$complexity,
                            levels = c("3 cell memory", "9 cell memory", "27 cell memory"))


t.test(wcd_all$win_count_diff[wcd_all$complexity == "3 cell memory"]) # ***
t.test(wcd_all$win_count_diff[wcd_all$complexity == "9 cell memory"]) # ***
t.test(wcd_all$win_count_diff[wcd_all$complexity == "27 cell memory"]) # ***


# Difference between participant-relative and bot-relative deps
t.test(
  c(
    wcd_all$win_count_diff[wcd_all$bot_strategy == "opponent_transitions"],
    wcd_all$win_count_diff[wcd_all$bot_strategy == "opponent_prev_move"]),
  c(
    wcd_all$win_count_diff[wcd_all$bot_strategy == "opponent_courn_transitions"],
    wcd_all$win_count_diff[wcd_all$bot_strategy == "bot_prev_move"])
)

# Binomial tests
binom.test(
  x = sum(wcd_all$win_count_diff[wcd_all$bot_strategy == "opponent_transitions"] < 0),
  n = length(wcd_all$win_count_diff[wcd_all$bot_strategy == "opponent_transitions"])
)

binom.test(
  x = sum(wcd_all$win_count_diff[wcd_all$bot_strategy == "opponent_courn_transitions"] < 0),
  n = length(wcd_all$win_count_diff[wcd_all$bot_strategy == "opponent_courn_transitions"])
)

binom.test(
  x = sum(wcd_all$win_count_diff[wcd_all$bot_strategy == "opponent_prev_move"] < 0),
  n = length(wcd_all$win_count_diff[wcd_all$bot_strategy == "opponent_prev_move"])
)

binom.test(
  x = sum(wcd_all$win_count_diff[wcd_all$bot_strategy == "bot_prev_move"] < 0),
  n = length(wcd_all$win_count_diff[wcd_all$bot_strategy == "bot_prev_move"])
)

binom.test(
  x = sum(wcd_all$win_count_diff[wcd_all$bot_strategy == "opponent_outcome_transitions"] < 0),
  n = length(wcd_all$win_count_diff[wcd_all$bot_strategy == "opponent_outcome_transitions"])
)

binom.test(
  x = sum(wcd_all$win_count_diff[wcd_all$bot_strategy == "opponent_bot_prev_move"] < 0),
  n = length(wcd_all$win_count_diff[wcd_all$bot_strategy == "opponent_bot_prev_move"])
)

binom.test(
  x = sum(wcd_all$win_count_diff[wcd_all$bot_strategy == "opponent_prev_two_moves"] <= 0),
  n = length(wcd_all$win_count_diff[wcd_all$bot_strategy == "opponent_prev_two_moves"])
)

binom.test(
  x = sum(wcd_all$win_count_diff[wcd_all$bot_strategy == "opponent_outcome_prev_transition_dual"] <= 0),
  n = length(wcd_all$win_count_diff[wcd_all$bot_strategy == "opponent_outcome_prev_transition_dual"])
)




# ANALYSIS: compare to dyad results ============================================

dyad_wcd_summary = bind_rows(
  get_win_count_differential_summary(player_transition_utils, "opponent_transitions"),
  get_win_count_differential_summary(player_transition_cournot_utils, "opponent_courn_transitions"),
  get_win_count_differential_summary(player_prev_move_utils, "opponent_prev_move"),
  get_win_count_differential_summary(opponent_prev_move_utils, "bot_prev_move"),
  get_win_count_differential_summary(player_transition_prev_outcome_utils, "opponent_outcome_transitions"),
  get_win_count_differential_summary(player_opponent_prev_move_utils, "opponent_bot_prev_move"),
  get_win_count_differential_summary(player_prev_2move_utils, "opponent_prev_two_moves"),
  get_win_count_differential_summary(player_transition_prev_transition_prev_outcome_utils, "opponent_outcome_prev_transition_dual")
)

# NB: before running this, need to re-declare STRATEGY_LEVELS above...
dyad_wcd_summary$category = factor(dyad_wcd_summary$category, levels = STRATEGY_LEVELS)

# dyad_wcd_summary %>%
#   ggplot(aes(x = category, y = mean_wins)) +
#   geom_point(#aes(color = category),
#              size = 6) +
#   geom_errorbar(aes(#color = category,
#                     ymin = ci_lower, ymax = ci_upper),
#                 width = 0.1, size = 1) +
#   # geom_jitter(data = wcd_all, aes(x = bot_strategy, y = win_count_diff),
#   # size = 2, alpha = 0.75, width = 0.25, height = 0) +
#   # geom_hline(yintercept = 0, size = 1, linetype = "dashed", color = "red") +
#   labs(x = "", y = "Expected win count differential") +
#   ggtitle("Exploitability in human dyad play") +
#   scale_x_discrete(name = element_blank(),
#                    labels = strategy_labels) +
#   ylim(c(0, 90)) +
#   #scale_color_viridis(discrete = TRUE,
#   #                    name = element_blank()) +
#   default_plot_theme +
#   theme(
#     plot.title = element_text(size = 32, face = "bold"),
#     axis.title.y = element_text(size = 24, face = "bold"),
#     # axis.text.x = element_text(size = 20, face = "bold", angle = 0, vjust = 1),
#     axis.text.x = element_text(size = 12, face = "bold", angle = 0, vjust = 1),
#     # axis.text.x = element_blank(),
#     # axis.text.y = element_text(face = "bold", size = 20),
#     legend.position = "none"
#   )


# Correlation between expected win count diff.
# and empirical win count diffs from adaptive bots
cor.test(dyad_wcd_summary$mean_wins, wcd_summary$mean_win_count_diff)



combined_wcd = wcd_summary %>%
  rename(category = bot_strategy) %>%
  inner_join(dyad_wcd_summary, by = c("category"))

combined_wcd %>%
  ggplot(aes(x = mean_wins, y = mean_win_count_diff,
             color = category)) +
  geom_point(size = 6) +
  geom_errorbar(aes(color = category,
                    ymin = lower_se, ymax = upper_se),
                width = 1, size = 1) +
  geom_errorbarh(aes(color = category,
                     xmin = ci_lower, xmax = ci_upper), size = 1) +
  geom_hline(yintercept = 0, size = 1, linetype = "dashed") +
  scale_color_manual(name = element_blank(),
                     labels = strategy_labels,
                     values = wes_palette("Zissou1", 8, type = "continuous")) +
  labs(x = "Human dyad expected win count differential \n",
       y = "Bot win count differential") +
  ggtitle("Exploitability in bots v. other humans") +
  default_plot_theme +
  theme(
    plot.title = element_text(size = 32, face = "bold"),
    axis.title.y = element_text(size = 24, face = "bold"),
    axis.text.y = element_text(size = 14, face = "bold", angle = 0, vjust = 1),
    axis.title.x = element_text(size = 24, face = "bold"),
    axis.text.x = element_text(size = 14, face = "bold", angle = 0, vjust = 1),
    legend.position = "bottom",
    legend.text = element_text(size = 14)
  ) +
  guides(color=guide_legend(ncol = 2))


# APPENDIX: Bot strategy win percentages by block ==============================

block_win_data = get_bot_block_data(data, blocksize = (NUM_ROUNDS / 2))
block_data_summary = get_block_data_summary(block_win_data)

block_data_summary = block_data_summary %>%
  rowwise() %>%
  mutate(complexity = complexity_lookup[bot_strategy])
block_data_summary$complexity = factor(block_data_summary$complexity,
                                       levels = c("3 cell memory", "9 cell memory", "27 cell memory"))



# Plot win percentage by block for each strategy
plot_block_summary(summary_data = block_data_summary %>% filter(bot_strategy == "opponent_transitions"),
                   individ_data = block_win_data %>% filter(bot_strategy == "opponent_transitions"))

plot_block_summary(summary_data = block_data_summary %>% filter(bot_strategy == "opponent_courn_transitions"),
                   individ_data = block_win_data %>% filter(bot_strategy == "opponent_courn_transitions"))

plot_block_summary(summary_data = block_data_summary %>% filter(bot_strategy == "opponent_prev_move"),
                   individ_data = block_win_data %>% filter(bot_strategy == "opponent_prev_move"))

plot_block_summary(summary_data = block_data_summary %>% filter(bot_strategy == "bot_prev_move"),
                   individ_data = block_win_data %>% filter(bot_strategy == "bot_prev_move"))

plot_block_summary(summary_data = block_data_summary %>% filter(bot_strategy == "opponent_outcome_transitions"),
                   individ_data = block_win_data %>% filter(bot_strategy == "opponent_outcome_transitions"))

plot_block_summary(summary_data = block_data_summary %>% filter(bot_strategy == "opponent_bot_prev_move"),
                   individ_data = block_win_data %>% filter(bot_strategy == "opponent_bot_prev_move"))

plot_block_summary(summary_data = block_data_summary %>% filter(bot_strategy == "opponent_prev_two_moves"),
                   individ_data = block_win_data %>% filter(bot_strategy == "opponent_prev_two_moves"))

plot_block_summary(summary_data = block_data_summary %>% filter(bot_strategy == "opponent_outcome_prev_transition_dual"),
                   individ_data = block_win_data %>% filter(bot_strategy == "opponent_outcome_prev_transition_dual"))


block_labels = c("1" = "30", "2" = "60", "3" = "90", "4" = "120", "5" = "150",
                 "6" = "180", "7" = "210", "8" = "240", "9" = "270", "10" = "300")

ggplot(data = block_data_summary, aes(x = round_block, y = mean_win_pct, color = complexity)) +
  geom_point(size = 6, alpha = 0.75) +
  geom_errorbar(aes(ymin = lower_ci, ymax = upper_ci), size = 1, width = 0.25, alpha = 0.75) +
  # geom_jitter(data = individ_data, aes(x = round_block, y = win_pct),
  # width = 0.1, height = 0, size = 2, alpha = 0.5) +
  geom_hline(yintercept = 1 / 3, linetype = "dashed", color = "red", size = 1) +
  labs(x = "Game round", y = "Bot win percentage") +
  # ggtitle("Bot win percentage against participants") +
  scale_color_viridis(discrete = T,
                      # name = element_blank(),
                      # labels = strategy_labels) +
  ) +
  scale_x_continuous(labels = block_labels, breaks = seq(1:10)) +
  # ylim(c(0, 1)) +
  default_plot_theme +
  theme(#axis.text.x = element_blank(),
    axis.title.y = element_text(size = 24, face = "bold"),
    legend.text = element_text(face = "plain", size = 10),
    legend.spacing.y = unit(1.0, 'lines'),
  ) +
  guides(color = guide_legend(ncol = 1))


# ANALYSIS: Free response ======================================================

fr_data %>%
  arrange(bot_strategy, strategy, game_id, player_id, free_resp_answer) %>%
  select(strategy, game_id, player_id, free_resp_answer)


# ANALYSIS: Slider scales ======================================================

slider_qs = unique(slider_summary$statement)

q1_plot = slider_summary %>%
  filter(statement == slider_qs[1]) %>%
  plot_slider_data()

q2_plot = slider_summary %>%
  filter(statement == slider_qs[2]) %>%
  plot_slider_data()

q3_plot = slider_summary %>%
  filter(statement == slider_qs[3]) %>%
  plot_slider_data()

q4_plot = slider_summary %>%
  filter(statement == slider_qs[4]) %>%
  plot_slider_data()

q5_plot = slider_summary %>%
  filter(statement == slider_qs[5]) %>%
  plot_slider_data()


q1_plot + q2_plot + q3_plot + q4_plot + q5_plot +
  plot_layout(ncol = 2)



# ANALYSIS: Scratch ============================================================

# library(rjson)

data %>%
  filter(is_bot == 0, round_index == NUM_ROUNDS) %>%
  group_by(bot_strategy) %>%
  summarize(subjects = n())
# summarize(sum(subjects))

mem = data %>%
  filter(round_index == NUM_ROUNDS & is_bot == 1) %>%
  group_by(bot_strategy, game_id) %>%
  select(bot_strategy, game_id, bot_round_memory)


mem = mem %>%
  rowwise() %>%
  mutate(memory_sum =
           sum(as.numeric(unlist(regmatches(bot_round_memory, gregexpr("[[:digit:]]+", bot_round_memory))))))


# mem = data %>% filter(game_id == "b684bbe7-ba7c-41f8-8589-674c2979f0f6", is_bot == 1, round_index == NUM_ROUNDS) %>%
#   select(bot_round_memory)

data %>% filter(game_id == "b684bbe7-ba7c-41f8-8589-674c2979f0f6", is_bot == 0) %>%
  group_by(player_id) %>%
  summarize(n())

mem$bot_round_memory

# 21 below, 21 in first pilot round
#' opponent_bot_prev_move (27 cells): 299
#' opponent_prev_two_moves (27 cells): 298
#' bot_prev_move (9 cells): 299, 750
#' opponent_outcome_transitions (9 cells): 596, 566
#' opponent_courn_transitions (3 cells): 299, 297, 299
#' opponent_outcome_prev_transition_dual (27 cells): 574, 2081, 298, 298
#' opponent_prev_move (9 cells): 598, 357, 299, 641
#' opponent_transitions (3 cells): 300, 299, 598, 299 (NB: 300 doesn't count here, counts go 0s in round 1 to 2 + transitions in round 2)
#'
# -> From above, 11 are usable
safe_game_ids = c(
  "c9b597bc-ff5e-4e76-9cf7-7048bac572a6", # opponent_bot_prev_move
  "ff64c8a4-babc-4874-a895-a21215c22b43", # opponent_prev_two_moves
  "7af733f0-7253-4dc5-9cea-1e89f7dbc3a6", # bot_prev_move
  "a0e44570-8d8d-4472-b087-5046773411fa", # opponent_courn_transitions
  "c169a038-ca59-4ede-801f-476ec48cba2f", # opponent_courn_transitions
  "7833ab77-0d2c-4f01-8127-a84ff09daef2", # opponent_courn_transitions
  "fcc1cce0-e209-4a78-9581-8bfb7bb53751", # opponent_prev_move
  "e6e34c91-95ac-4b31-aea1-f850b64c9b5f", # opponent_outcome_prev_transition_dual,
  "de6123c4-e8fd-4699-95d1-f41d35e49ca3", # opponent_outcome_prev_transition_dual (no slider data for this person)
  "5a3a0315-9259-41d0-8ec0-a8188333609a", # opponent_transitions
  "b684bbe7-ba7c-41f8-8589-674c2979f0f6" # opponent_transitions
)



mem$bot_round_memory[mem$sona_survey_code == "31656"]

#' Subsequent batch
#' 34181: 299
#' 22809: 299
#' 23814: 295
#' 24723: 298
#' 26084: 299
#' 30527: 297
#' 36067: 299 # NB: we may want to cut this person, they played paper 268 times in a losing sequence...
#' 30289: 298
#' 26999: 299
#' 34027: 299
#' 31656: 298
#'

jsonlite::fromJSON(mem$bot_round_memory[1])

