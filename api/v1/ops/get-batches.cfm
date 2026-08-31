<cfscript>
/**
 * ========================================================================
 * API ENDPOINT (CONTROLLER)
 * ========================================================================
 *
 * PURPOSE:     Returns a list of the 50 most recent batches, joined with
 *              Recipe names, current Vat assignments, and real-time
 *              FOH taproom reviews sentiment aggregates for the BOH 
 *              Operations dashboard.
 *
 * HTTP METHOD: GET
 *
 * CALLS:       None (Direct Database Query)
 *
 * RETURNS:     JSON
 *              {
 *                "success": boolean,
 *                "batches": [
 *                  {
 *                    "batch_id": integer,
 *                    "recipe_name": string,
 *                    "status": string,
 *                    "start_date": string,
 *                    "vat_name": string (nullable),
 *                    "avg_rating": number (nullable),
 *                    "feedback_count": integer
 *                  }
 *                ]
 *              }
 * ========================================================================
 */

    response = {
        "success": false,
        "batches": []
    };

    try {
        if (cgi.request_method != "GET") {
            throw(type="MethodNotAllowed", message="Only GET requests accepted");
        }

        // Join Batches -> Recipes (to get name)
        // LEFT JOIN Vats (to see if it's currently in a vat)
        // LEFT JOIN brews.taproom_feedback (to calculate real-time customer sentiment aggregates)
        sql = "
            SELECT
                b.batch_id,
                r.recipe_name,
                b.status,
                TO_CHAR(b.start_time, 'YYYY-MM-DD') as start_date,
                v.name AS vat_name,
                COALESCE(ROUND(AVG(tf.rating), 1), 0) AS avg_rating,
                COUNT(tf.feedback_id) AS feedback_count
            FROM
                Batches b
            INNER JOIN
                Recipes r ON b.recipe_id = r.recipe_id
            LEFT JOIN
                Vats v ON b.batch_id = v.current_batch_id
            LEFT JOIN
                brews.taproom_feedback tf ON b.batch_id = tf.batch_id
            GROUP BY
                b.batch_id,
                r.recipe_name,
                b.status,
                b.start_time,
                v.name
            ORDER BY
                b.batch_id DESC
            LIMIT 50
        ";

        batchesQuery = queryExecute(sql, {}, { returnType: "array" });

        response.batches = batchesQuery;
        response.success = true;

    } catch (any e) {
        cfheader(statusCode=500);
        response.error = e.message;
        response.detail = e.detail;
    }

    writeOutput(serializeJson(response));
</cfscript>