"""
To run this:
- cd /rps/analysis/
- python json_to_csv_v2.py
"""

import io
import json
import csv
from os import listdir
from os.path import isfile, join

EXPERIMENT = "rps_v2" # useful identifier for experiment data: modify this to reflect the particular experiment
DATA_PATH = "/Users/erikbrockbank/web/vullab/rps/data/v2/" # path to data files: modify as needed for particular experiments

output_file = "{}_data.csv".format(EXPERIMENT) # name of csv file to write to
with io.open(output_file, "w") as csv_output:
    csvwriter = csv.writer(csv_output)
    write_index = 0
    files = [f for f in listdir(DATA_PATH) if f.endswith(".json")
                and not "TEST" in f
                and not "freeResp" in f
                and not "sliderData" in f]
    for f in files:
        with io.open(join(DATA_PATH + f), "r", encoding = "utf-8", errors = "ignore") as readfile:
            print("Processing: {}".format(f))
            content = readfile.read()
            parsed_data = json.loads(content)
            round_data = parsed_data["rounds"]

            if write_index == 0:
                # init header array
                header = [
                    # generic data true for all rounds
                    "game_id", "version", "is_sona_autocredit", "sona_experiment_id", "sona_credit_token", "sona_survey_code",
                    # data specific to each round (or varies between players)
                    "round_index", "player_id", "is_bot",
                    "bot_strategy", "bot_move_probabilities", # NB: bot values only apply for bot rows
                    "round_begin_ts", "player_move", "player_rt", "player_outcome", "player_outcome_viewtime", # note this val won't work with pilot data
                    "player_points", "player_total"
                ]
                csvwriter.writerow(header)
                write_index = 1

            for r in round_data:
                p1_vals = [r["game_id"],
                    parsed_data["version"], parsed_data["sona"], parsed_data["experiment_id"], parsed_data["credit_token"], parsed_data["survey_code"],
                    r["round_index"], r["player1_id"], 0,
                    parsed_data["player2_bot_strategy"], parsed_data["player2_bot_move_probabilities"], # bot values for player 2 included here as well
                    r["round_begin_ts"],
                    r["player1_move"], r["player1_rt"], r["player1_outcome"], r["player1_outcome_viewtime"], # note this val won't work with pilot data
                    r["player1_points"], r["player1_total"]]
                p2_vals = [r["game_id"],
                    parsed_data["version"], parsed_data["sona"], parsed_data["experiment_id"], parsed_data["credit_token"], parsed_data["survey_code"],
                    r["round_index"], parsed_data["player2_botid"], 1,
                    parsed_data["player2_bot_strategy"], parsed_data["player2_bot_move_probabilities"], # bot values for player 2
                    r["round_begin_ts"],
                    r["player2_move"], r["player2_rt"], r["player2_outcome"], r["player2_outcome_viewtime"], # note this val won't work with pilot data
                    r["player2_points"], r["player2_total"]]
                csvwriter.writerow(p1_vals)
                csvwriter.writerow(p2_vals)


csv_output.close()
