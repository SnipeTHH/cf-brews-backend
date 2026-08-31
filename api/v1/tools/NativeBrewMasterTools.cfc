component displayname="NativeBrewMasterTools" {

    /**
     * Determines if there are enough ingredients in stock to brew a specific volume of a recipe.
     */
    remote struct function checkInventory(required string recipeName, numeric volumeGallons = 1) {
        var tools = new BrewMasterTools();
        return tools.checkInventory(arguments.recipeName, arguments.volumeGallons);
    }

    /**
     * Retrieves the specific ingredients and targets (ABV, ideal temperatures) for a single named recipe.
     */
    remote struct function getRecipeDetails(required string recipeName) {
        var tools = new BrewMasterTools();
        return tools.getRecipeDetails(arguments.recipeName);
    }

    /**
     * Checks all currently fermenting batches against their recipe targets to detect anomalies.
     */
    remote struct function checkBatchRisk(string style = "") {
        var tools = new BrewMasterTools();
        return tools.checkBatchRisk(arguments.style);
    }

}
