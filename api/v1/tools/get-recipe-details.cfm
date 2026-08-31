<cfscript>
/**
 * ========================================================================
 * AI AGENT TOOL: GET RECIPE DETAILS
 * ========================================================================
 * PURPOSE: Used by Gemini Enterprise Agents to look up the specific ingredients
 * and vital stats for a single named recipe.
 * INPUTS: recipe_name (string)
 * ========================================================================
 */
    response = { "found": false, "recipe": {} };
 
    try {
        if (!structKeyExists(url, "recipe_name")) throw("Missing recipe_name");
        name = trim(url.recipe_name);
 
        tools = new BrewMasterTools();
        response = tools.getRecipeDetails(name);
 
    } catch (any e) {
        cfheader(statusCode=500);
        response.error = e.message;
    }
    writeOutput(serializeJson(response));
</cfscript>