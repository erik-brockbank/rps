"""
To run this:
- cd /Users/erikbrockbank/web/vullab/data_analysis/rps_data
- python json_to_csv_freeResp.py
"""

import io
import json
import csv
from os import listdir
from os.path import isfile, join

# TODO make these command line flags
EXPERIMENT = "rps_v1" # useful identifier for experiment data: modify this to reflect the particular experiment
DATA_PATH = "/Users/erikbrockbank/web/vullab/rps/data/v1/" # path to data files: modify as needed for particular experiments


output_file = "{}_data_freeResp.csv".format(EXPERIMENT) # name of csv file to write to
with io.open(output_file, "w") as csv_output:
    csvwriter = csv.writer(csv_output)
    write_index = 0
    files = [f for f in listdir(DATA_PATH) if f.endswith(".json") and "freeResp" in f]
    for f in files:
        with io.open(join(DATA_PATH + f), "r", encoding = "utf-8", errors = "ignore") as readfile:
            print("Processing: {}".format(f))
            content = readfile.read()
            parsed_data = json.loads(content)

            # init header array
            if write_index == 0:
                header = ["game_id", "player_id", "free_resp_prompt", "free_resp_answer"]
                csvwriter.writerow(header)
                write_index = 1

            write_vals = [parsed_data[elem] for elem in header]
            csvwriter.writerow(write_vals)

csv_output.close()
