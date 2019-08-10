/*
 * Library for advancing through instructions
 */

Instructions = function(instructionPath, instructionSet, experimentCallback) {
    this.instructionPath = instructionPath; // Path to html page for instructions skeleton
    this.instructionSet = instructionSet; // Array of instruction text elements to display
    this.instructionsIndex = 0; // Index to keep track of how many instructions have been processed
    this.callback = experimentCallback; // Function to call when instructions complete
};


Instructions.prototype.run = function() {
    console.log("inst.js:\t starting instructions");

    // Load html for displaying instructions
    var that = this;
    $("body").load(that.instructionPath, function() {
        that.populateInstruction();
        $("#next-inst").click(function() {that.buttonNext();});
    });
};

/*
 * Function called by button click, used for moving through instruction flow
 */
Instructions.prototype.buttonNext = function() {
    // console.log("Button click! Instruction index: ", this.instructionsIndex);

    if (this.instructionsIndex >= this.instructionSet.length) {
        console.log("End of instructions");
        this.callback();
    } else {
        this.populateInstruction();
    }
};

/*
 * Function to populate instruction html elements with appropriate text/images
 * during each phase of instructions
*/
Instructions.prototype.populateInstruction = function() {
    // console.log("Loading instruction elem at index: ", this.instructionsIndex);
    instructionElem = this.instructionSet[this.instructionsIndex];

    // Remove any existing images in the canvas
    $(".instruction-img").remove();
    // Add top text
    $("#text-top").html(instructionElem.top_text);
    // Add bottom text
    $("#text-bottom").html(instructionElem.bottom_text);
    // Add and format image
    if (instructionElem.canvas_img != "") {
        img_src = IMGPATH + "/" + instructionElem.canvas_img;
        $("#canvas-mid").prepend("<img class='instruction-img' src='" + img_src + "' />");
        $(".instruction-img").width($("#canvas-mid").width());
    }


    this.instructionsIndex++;
    return
};
