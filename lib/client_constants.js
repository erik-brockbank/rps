/*
 * constants library for rps client (this gets loaded in the browser)
 */

const HTMLPATH = '/static'; // path to html files for dynamic loading
const ROUND_TIMEOUT = 10; // number of seconds for players to make a decision each round (includes some buffer for loading)


const INSTRUCTION_ARRAY = [
    {
        top_text: "In today’s experiment, you’ll be playing repeated rounds of the Rock, Paper, " +
            "Scissors game against another human player.",
        canvas_img: "",
        bottom_text: ""
    },
    {
        top_text: "If you’re unfamiliar with Rock, Paper, Scissors, here’s how to play:" +
        "1. In each round, you will select one of the rock, paper, or scissors cards to play against " +
        "your opponent by clicking the appropriate card. They look like the buttons below. " +
        "2. Your opponent is going to choose a card to play as well, but neither of you can see what " +
        "the other has selected until after you have both chosen. " +
        "3. Once both you and your opponent have selected a card to play in the current round, " +
        "your chosen card and your opponent’s card will be revealed.",
        canvas_img: "",
        bottom_text: "Click below to get started"
    },
    {
        top_text: "In each round, the rules for which card wins are simple:" +
        "1. Rock beats scissors (to remember, imagine the rock breaking the scissors)" +
        "2. Scissors beats paper (to remember, imagine the scissors cutting the paper)" +
        "3. Paper beats rock (to remember, imagine the paper wrapping around the rock)" +
        "4. If both players play the same card (e.g. both players play scissors), the round is a tie.",
        canvas_img: "",
        bottom_text: "The rules for each card combination are illustrated above and will be shown " +
        "throughout the game as a reminder."
    },
    {
        top_text: "In each round, the winner will receive 3 points, the loser will receive -1 point, " +
        "and when there’s a tie, both players will receive 0 points. You and your opponent are going " +
        "to play 100 rounds of the rock, paper, scissors game.",
        canvas_img: "",
        bottom_text: ""
    },
    {
        top_text: "You’ll have 10 seconds to choose a card in each round. If you don’t choose a card " +
        "within the 10 seconds, your opponent will automatically win that round. After both you and " +
        "your opponent have chosen a card, both of your cards will be revealed and you’ll both see " +
        "the results of that round. Your points and your opponent’s points will be visible throughout " +
        "the game to see who is winning.",
        canvas_img: "",
        bottom_text: ""
    },
    {
        top_text: "Ready? Click the button below to get started!",
        canvas_img: "",
        bottom_text: ""
    }
];
