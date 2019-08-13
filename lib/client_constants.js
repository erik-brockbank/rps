/*
 * constants library for rps client (this gets loaded in the browser)
 */

const HTMLPATH = "/static"; // path to html files for dynamic loading
const IMGPATH = "/img"; // path to image files during instructions
const ROUND_TIMEOUT = 10; // number of seconds for players to make a decision each round (includes some buffer for loading)


const INSTRUCTION_ARRAY = [
    {
        top_text: "<p>In today’s experiment, you’ll be playing the Rock, Paper, Scissors game " +
            "against another human player.</p>",
        canvas_img: "",
        bottom_text: ""
    },
    {
        top_text: "<p>If you’re unfamiliar with Rock, Paper, Scissors, here’s how to play:</p>",
        canvas_img: "",
        bottom_text: ""
    },
    {
        top_text: "<p>In each round, you will select one of the rock, paper, or scissors " +
            "cards to play against your opponent by clicking the appropriate card. They look " +
            "like the icons below.</p>",
        canvas_img: "combined-standard.jpg",
        bottom_text: ""
    },
    {
        top_text: "<p>Your opponent is going to choose a card to play as well, but neither of " +
            "you can see what the other has selected until after you have both chosen.</p>",
        canvas_img: "",
        bottom_text: ""
    },
    {
        top_text: "<p>Once both you and your opponent have selected a card to play in the " +
            "current round, your chosen card and your opponent’s card will both be revealed.</p>",
        canvas_img: "",
        bottom_text: ""
    },
    {
        top_text: "<p>In each round, the rules for which card wins are simple:</p>" +
            "<p>- <b><i>Rock beats scissors</i></b> (to remember, imagine the rock breaking the scissors).</p>" +
            "<p>- <b><i>Scissors beats paper</i></b> (to remember, imagine the scissors cutting the paper).</p>" +
            "<p>- <b><i>Paper beats rock</i></b> (to remember, imagine the paper wrapping around the rock).</p>" +
            "<p>- If both players play the same card, the round is a tie.</p>",
        canvas_img: "",
        bottom_text: ""
    },
    {
        top_text: "<p>The rules for each card combination are illustrated below and will be " +
            "shown throughout the game as a reminder.</p>",
        canvas_img: "schematic.jpg",
        bottom_text: ""
    },
    {
        top_text: "<p>In each round, the winner will receive 3 points, the loser will receive -1 " +
            "point, and when there’s a tie, both players will receive 0 points.</p>" +
            "<p>Your points and your opponent’s points will be visible throughout the game to " +
            "see who is winning.</p>",
        canvas_img: "",
        bottom_text: ""
    },
    {
        top_text: "<p>You’ll have 10 seconds to choose a card in each round. If you don’t choose " +
            "a card within the 10 seconds, your opponent will automatically win that round. </p>" +
            "<p>You and your opponent are going to play 100 rounds of the rock, paper, scissors game.</p>",
        canvas_img: "",
        bottom_text: ""
    },
    {
        top_text: "<p>Ready? Click the button below to get started!</p>",
        canvas_img: "",
        bottom_text: ""
    }
];
