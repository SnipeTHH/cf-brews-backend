<cfscript>
/**
 * ========================================================================
 * API ENDPOINT (CONTROLLER)
 * ========================================================================
 *
 * PURPOSE:     Gets a list of batches that are 'Pending' or
 * 'Fermenting' to be used in the prediction dropdown.
 *
 * HTTP METHOD: GET
 *
 * ========================================================================
 */

    response = {
        "success": false,
        "batches": []
    };

    try {
        if (cgi.request_method != "GET") {
            cfheader(statusCode=405);
            response.message = "This endpoint only accepts GET requests.";
            writeOutput(serializeJson(response));
            return;
        }

        // Get batches that can be predicted on
        sql = "
            SELECT b.batch_id, r.recipe_name AS batch_name
            FROM Batches b
            INNER JOIN Recipes r ON b.recipe_id = r.recipe_id
            WHERE b.status = 'Pending' OR b.status = 'Fermenting'
            ORDER BY b.batch_id DESC
        ";
        
        batchesQuery = queryExecute(sql, {}, { returnType: "array" });
        
        response.batches = batchesQuery;
        response.success = true;


    } catch (any e) {
        throw(e);
    }

    // --- 3. Return the JSON response ---
    writeOutput(serializeJson(response));

</cfscript>