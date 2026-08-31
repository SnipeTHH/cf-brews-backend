<cfscript>
/**
 * ========================================================================
 * AI AGENT TOOL: INVENTORY CHECKER
 * ========================================================================
 *
 * PURPOSE:     Used by Gemini Enterprise Agents to determine if there are enough
 * ingredients in stock to brew a specific volume of a recipe.
 *
 * INPUTS (URL):
 * - recipe_name (string): Name of the beer (e.g., "Hoppy McHopface")
 * - volume_gallons (numeric, optional): Defaults to 1 if omitted.
 *
 * ========================================================================
 */

    response = {
        "can_brew": false,
        "recipe_found": false,
        "missing_ingredients": []
    };

    try {
        if ( !structKeyExists(url, "recipe_name") || !len(trim(url.recipe_name)) ) {
            throw(message="Missing required parameter: recipe_name");
        }
        targetVolume = (structKeyExists(url, "volume_gallons") && isNumeric(url.volume_gallons)) ? val(url.volume_gallons) : 1;
        recipeName = trim(url.recipe_name);

        tools = new BrewMasterTools();
        response = tools.checkInventory(recipeName, targetVolume);

    } catch (any e) {
        cfheader(statusCode=500);
        response.error = e.message;
    }

    writeOutput(serializeJson(response));
</cfscript>