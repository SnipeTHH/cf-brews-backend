<cfscript>
/**
 * ========================================================================
 * API ENDPOINT (CONTROLLER)
 * ========================================================================
 *
 * PURPOSE:     Recent Customer Reviews Controller. Fetches recent feedback
 *              and dynamically evaluates sentiment using AlloyDB AI.
 *
 * HTTP METHOD: GET
 *
 * CALLS:       AlloyDB AI (ai.analyze_sentiment)
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
        "reviews": []
    };

    try {
        // 1. Only allow GET requests
        if (cgi.request_method != "GET") {
            cfheader(statusCode=405);
            response.message = "This endpoint only accepts GET requests.";
            writeOutput(serializeJson(response));
            return;
        }

        // 2. Query recent feedback with dynamically evaluated sentiment
        sql = "
            SELECT 
                p.purchase_id,
                r.recipe_name,
                c.customer_name,
                p.feedback_text,
                p.purchase_time,
                ai.analyze_sentiment(p.feedback_text) AS sentiment
            FROM brews.purchases p
            JOIN brews.recipes r ON p.recipe_id = r.recipe_id
            JOIN brews.customers c ON p.customer_id = c.customer_id
            WHERE p.feedback_text IS NOT NULL
            ORDER BY p.purchase_time DESC
            LIMIT 10
        ";

        // Execute the query targeting the standard AlloyDB DSN
        reviewsData = queryExecute(sql, {}, { datasource: application.cfbrews_dsn, returnType: "array" });

        // 3. Build successful response
        response.reviews = reviewsData;
        response.success = true;

    } catch (any e) {
        // Log error and return 500
        writeLog(file="cfbrews_error", text="Reviews API Failed: #e.message# #e.detail#");
        cfheader(statusCode=500);
        response.message = "Reviews analytics temporarily unavailable: " & e.message;
    }

    // Output standard JSON response
    writeOutput(serializeJson(response));
</cfscript>
