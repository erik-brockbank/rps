# rps
Repo for Rock, Paper, Scissors experiments

## To run experiment locallly:
1. Clone repo
2. This requires `node.js` and the node package manager `npm`. Google these to install locally :)
3. cd to `rps/` directory
2. Start server: `node app.js`
3. In browser, navigate to URL below that matches the version you'd like to play

### Paired dyad play
- Visit `http://localhost:3000/index.html` or `http://localhost:3000/index.html?&mode=test` for test version (writes a file prepended with `TEST_...` for easy debugging)
- For dyad version, open two browser tabs and visit the links above in each to play against yourself!

### Single play against a bot
- Visit `http://localhost:3000/index.html?&ver=2` or `http://localhost:3000/index.html?&ver=2&mode=test` for test version (same as above)
- For single bot version, the server chooses the bot strategy at random from among the strategies outlined in `/lib/server_constants.js` and prints the strategy out at runtime.

### Admin functions
- Visit http://localhost:3000/admin to view the state of games currently in play, including the current round

