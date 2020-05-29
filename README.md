# rps
Repo for rock, paper, scissors experiments

## To run experiment locallly:
1. Clone repo
2. This requires `node.js` and the node package manager `npm`. Google these to download and run locally :)
3. cd to `rps/` directory
2. Start server: `node app.js`
3. In browser, navigate to URL below that matches the version you'd like to play

### Paired dyad play
- Visit `http://localhost:3000/index.html` or `http://localhost:3000/index.html?&mode=test` for test version (writes a file prepended with `TEST_...` for easy debugging)
- For dyad version, open two browser tabs and visit the links above in each to play against yourself!

### Single play against a bot
- Visit `http://localhost:3000/index.html?&ver=2` or `http://localhost:3000/index.html?&ver=2&mode=test` for test version (same as above)
- For single bot version, the server chooses the bot strategy at random from among the strategies outlined in `/lib/server_constants.js` and prints the strategy out at runtime

### Admin functions
- Visit `http://localhost:3000/admin` to view the state of games currently in play (helpful when running this as an experiment)


## Data
Participant data is in the `/data` directory 
- `/data/v1/` contains paired dyad results
- `/data/v2/` contains individual player strategic bot results
- `/data/pilot/` contains pilot results from the v1 paired dyad experiments

In each of the folders above, file naming conventions are as follows:
- Game data is saved in files with `{game_id}.json`
- Free response survey data is saved in files with `freeResp_{player_id}.json`
- Likert scale survey data is saved in files with `sliderData_{player_id}.json`

## Analysis
Analysis code is in the `/analysis` directory
- The python files `json_to_csv_v1.py`, `json_to_csv_sliderData.py`, and `json_to_csv_freeResp.py` each convert the individual data files from json to a single csv output file for analysis (these are in the same directory and have matched names)
- `cogsci_analysis.R` contains the full analysis for the CogSci 2020 proceedings manuscript



