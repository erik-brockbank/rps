"""
To run this:
- cd /rps/analysis/
- python json_to_csv_sliderData.py --experiment {name}
    - the `experiment` flag should be followed by either "rps_v1" or "rps_v2"
"""

import argparse
import csv
import io
import json
from os import listdir
from os.path import isfile, join


# Parse command line flags
parser = argparse.ArgumentParser(description = "Script for encoding Likert scale slider data from post-experiment questionnaire.")
parser.add_argument("--experiment", required = True, choices=["rps_v1", "rps_v2"],
                    help="Name of experiment (used for file output), e.g., 'rps_v1'")

args = parser.parse_args()
EXPERIMENT = args.experiment
if EXPERIMENT == "rps_v1": DATA_PATH = "/Users/erikbrockbank/web/vullab/rps/data/v1/"
elif EXPERIMENT == "rps_v2": DATA_PATH = "/Users/erikbrockbank/web/vullab/rps/data/v2/"


output_file = "{}_data_sliderData.csv".format(EXPERIMENT) # name of csv file to write to
with io.open(output_file, "w") as csv_output:
    csvwriter = csv.writer(csv_output)
    write_index = 0
    files = [f for f in listdir(DATA_PATH) if f.endswith(".json") and "sliderData" in f]
    for f in files:
        with io.open(join(DATA_PATH + f), "r", encoding = "utf-8", errors = "ignore") as readfile:
            print("Processing: {}".format(f))
            content = readfile.read()
            parsed_data = json.loads(content)

            # init header array
            if write_index == 0:
                header = ["game_id", "player_id", "statement", "index", "resp"]
                csvwriter.writerow(header)
                write_index = 1

            for q in parsed_data["slider_responses"]:
                write_vals = [q[elem] for elem in header]
                csvwriter.writerow(write_vals)

csv_output.close()
