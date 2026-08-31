<cfscript>
/**
 * ========================================================================
 * API ENDPOINT (CONTROLLER)
 * ========================================================================
 *
 * PURPOSE:     Beer Feedback Summaries Controller. Aggregates customer
 *              feedback text per beer and summarizes it using AlloyDB AI.
 *
 * HTTP METHOD: GET
 *
 * CALLS:       AlloyDB AI (ai.agg_summarize)
 * 
 * USED BY:     React Analytics UI (Analytics.jsx)
 *
 * BODY (JSON): None
 *
 * ========================================================================
 */

    // Prepare response object
    response = {
        "success": false,
        "summaries": []
    };

    try {
        // 1. Only allow GET requests
        if (cgi.request_method != "GET") {
            cfheader(statusCode=405);
            response.message = "This endpoint only accepts GET requests.";
            writeOutput(serializeJson(response));
            return;
        }

        // 2. Query aggregated summaries per beer style using ai.agg_summarize
        sql = "
            SELECT 
                r.recipe_id,
                r.recipe_name,
                r.style,
                ai.agg_summarize(p.feedback_text) AS crowd_summary
            FROM brews.purchases p
            JOIN brews.recipes r ON p.recipe_id = r.recipe_id
            WHERE p.feedback_text IS NOT NULL
            GROUP BY r.recipe_id, r.recipe_name, r.style
            ORDER BY r.recipe_name ASC
        ";

        // Execute the query targeting the standard AlloyDB DSN
        summariesData = queryExecute(sql, {}, { datasource: application.cfbrews_dsn, returnType: "array" });

        // 3. Build successful response
        response.summaries = summariesData;
        response.success = true;

    } catch (any e) {
        // Log error and return 500
        writeLog(file="cfbrews_error", text="Beer Summaries API Failed: #e.message# #e.detail#");
        cfheader(statusCode=500);
        response.message = "Crowd feedback summaries temporarily unavailable: " & e.message;
    }

    // Output standard JSON response
    writeOutput(serializeJson(response));
</cfscript>
