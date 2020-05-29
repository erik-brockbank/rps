#'
#' This script contains the final analysis for the CogSci 2020 submission
#' 


rm(list = ls())
setwd("/Users/erikbrockbank/web/vullab/rps/analysis")

library(tidyverse)
library(viridis)
library(patchwork)




###############
### GLOBALS ###
###############

DATA_FILE = "rps_v1_data.csv" # name of file containing full dataset for all rounds
FREE_RESP_FILE = "rps_v1_data_freeResp.csv" # name of file containing free response data by participant
SLIDER_FILE = "rps_v1_data_sliderData.csv" # name of file containing slider Likert data by participant

GAME_ROUNDS = 300
NULL_SAMPLES = 10000 
MAX_LAG = 10 # lag for autocorrelation analysis



#######################
### DATA PROCESSING ###
#######################

# Function to read in and structure data appropriately
read_game_data = function(filename, game_rounds) {
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

get_sample_win_count_differential = function(reps, game_rounds) {
  win_diff_sample = data.frame(
    game_id = seq(1:reps),
    win_diff = replicate(reps, abs(sum(sample(c(-1, 0, 1), game_rounds, replace = T))))
  )
  return(win_diff_sample)
}

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




######################
### GRAPHING STYLE ###
######################

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


##########################
### GRAPHING FUNCTIONS ###
##########################

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


plot_acf = function(acf_data, game_rounds) {
  summary_acf = acf_data %>%
    group_by(lag) %>%
    summarize(mean_acf = mean(acf))
  
  ci_thresh = 2 / sqrt(game_rounds) # num. SDs from 0 over sqrt(N) obs to get 95% CI on mean of 0 auto-corr
  
  acf_data %>%
    ggplot(aes(x = lag, y = acf)) +
    geom_jitter(aes(color = "ind"), alpha = 0.5, width = 0.1, size = 2) +
    geom_point(data = summary_acf, aes(x = lag, y = mean_acf, color = "mean"), size = 4) +
    scale_x_continuous(breaks = seq(0, max(acf_data$lag))) +
    # significance thresholds
    geom_hline(yintercept = ci_thresh, linetype = "dashed", size = 1, color = "black") +
    geom_hline(yintercept = -ci_thresh, linetype = "dashed", size = 1, color = "black") +
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




################
### ANALYSIS ###
################

# Read in data
data = read_game_data(DATA_FILE, GAME_ROUNDS)
unique(data$game_id)


# 1. Win count differential
# Empirical win count differentials
win_count_diff_empirical = get_empirical_win_count_differential(data)
mean(win_count_diff_empirical$win_diff)
sd(win_count_diff_empirical$win_diff) / sqrt(nrow(win_count_diff_empirical))
max(win_count_diff_empirical$win_diff)
WIN_COUNT_DIFF_CEILING = plyr::round_any(max(win_count_diff_empirical$win_diff), 10, f = ceiling)

# Sampled null win count differentials
win_count_diff_null = get_sample_win_count_differential(NULL_SAMPLES, GAME_ROUNDS)
mean(win_count_diff_null$win_diff)
max(win_count_diff_null$win_diff)

# Plot histograms overlaid
win_count_diff_empirical = win_count_diff_empirical %>%
  mutate(cat = "Empirical data")
win_count_diff_null = win_count_diff_null %>%
  mutate(cat = "Sampled null data")
empirical_n = win_count_diff_empirical %>% nrow()
scale_factor = empirical_n / NULL_SAMPLES

plot_win_count_differentials(win_count_diff_empirical, win_count_diff_null, scale_factor, WIN_COUNT_DIFF_CEILING)

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


# 2. Auto-correlation of outcomes
unique_game_data = get_unique_game_data(data)
# Get ACF data
acf_agg = get_game_acf(unique_game_data, MAX_LAG)
# Plot ACF data
plot_acf(acf_agg, GAME_ROUNDS)

# Auto-correlation for top-N win count differential dyads
win_count_diff_empirical_top = win_count_diff_empirical %>%
  top_n(win_diff, n = 10)
unique(win_count_diff_empirical_top$game_id)

unique_game_data_top = unique_game_data %>%
  filter(game_id %in% win_count_diff_empirical_top$game_id)
# Get ACF data
acf_top = get_game_acf(unique_game_data_top, MAX_LAG)
# Plot ACF data
plot_acf(acf_top, GAME_ROUNDS)

# What kind of streaks are needed to produce significant auto-correlations?
streak_length = 30
streak_pct = (2 * streak_length) / GAME_ROUNDS
# Get sample game data to match the empirical number of dyads
sample_acf_data = get_sample_acf(streak_length, GAME_ROUNDS, length(unique(data$game_id)))
# Get ACF for sample game data
acf_sample = get_game_acf(sample_acf_data, MAX_LAG)
# Plot ACF data
plot_acf(acf_sample, GAME_ROUNDS)
# Take-aways: 
# streak_pct needs to be > 10% to detect significant auto-correlations
# by 20% it's very visible









