<cfscript>
/**
 * ========================================================================
 * API ENDPOINT (CONTROLLER)
 * ========================================================================
 *
 * PURPOSE:     Returns a lightweight list of all recipes to populate
 * UI dropdown menus (e.g., in the "Create Batch" modal).
 *
 * HTTP METHOD: GET
 *
 * CALLS:       None (Direct Database Query)
 *
 * RETURNS:     JSON
 * {
 * "success": boolean,
 * "recipes": [
 * { "recipe_id": integer, "recipe_name": string }
 * ]
 * }
 *
 * ========================================================================
 */
    response = { "success": false, "recipes": [] };
    try {
        if (cgi.request_method != "GET") throw(type="MethodNotAllowed", message="Only GET requests accepted");

        sql = "SELECT recipe_id, recipe_name FROM Recipes ORDER BY recipe_name ASC";
        recipesQuery = queryExecute(sql, {}, { returnType: "array" });

        response.recipes = recipesQuery;
        response.success = true;
    } catch (any e) {
        writeLog(file="cfbrews_error", text="Get Recipes Dropdown Error: #e.message#");
        cfheader(statusCode=500);
        response.error = "Failed to retrieve recipes.";
    }
    writeOutput(serializeJson(response));
</cfscript>