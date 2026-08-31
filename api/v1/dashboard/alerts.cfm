<cfscript>
/**
 * ========================================================================
 * API ENDPOINT (CONTROLLER)
 * ========================================================================
 *
 * PURPOSE:     Returns recent high/low sensor alerts by querying
 * the VatSensorReadings table for specific criteria.
 *
 * UPDATED:     Now joins with Recipes table to get batch names.
 *
 * HTTP METHOD: GET
 *
 * CALLS:       None (self-contained)
 *
 * BODY (JSON): None
 *
 * ========================================================================
 */

    // Prepare response object
    response = {
        "success": false,
        "alerts": []
    };

    try {

        // --- 1. Only allow GET requests ---
        if (cgi.request_method != "GET") {
            cfheader(statusCode=405);
            response.message = "This endpoint only accepts GET requests.";
            writeOutput(serializeJson(response));
            return;
        }

        // --- 2. Get the alerts (BALANCED QUERY) ---
        // UPDATED: All sub-queries now JOIN Recipes (aliased as 'rec') 
        // and select 'rec.recipe_name' aliased as 'batch' for frontend compatibility.
        
        sql = "
            -- Get 3 most recent High Temp alerts
            (
                SELECT
                    rec.recipe_name AS batch,
                    v.name AS vat,
                    'Temperature' AS type,
                    CAST(r.temp AS VARCHAR) || ' °F' AS value,
                    'High' AS level,
                    r.reading_time
                FROM
                    VatSensorReadings AS r
                JOIN
                    Batches AS b ON r.batch_id = b.batch_id
                JOIN
                    Recipes AS rec ON b.recipe_id = rec.recipe_id
                JOIN
                    Vats AS v ON r.vat_id = v.vat_id
                WHERE
                    r.temp > 74.0 -- High temp threshold
                    AND b.status = 'Fermenting'
                ORDER BY
                    r.reading_time DESC
                LIMIT 3
            )

            UNION ALL

            -- Get 2 most recent Warning Temp alerts
            (
                SELECT
                    rec.recipe_name AS batch,
                    v.name AS vat,
                    'Temperature' AS type,
                    CAST(r.temp AS VARCHAR) || ' °F' AS value,
                    'Warning' AS level,
                    r.reading_time
                FROM
                    VatSensorReadings AS r
                JOIN
                    Batches AS b ON r.batch_id = b.batch_id
                JOIN
                    Recipes AS rec ON b.recipe_id = rec.recipe_id
                JOIN
                    Vats AS v ON r.vat_id = v.vat_id
                WHERE
                    r.temp BETWEEN 73.0 AND 74.0 -- Warning temp threshold
                    AND b.status = 'Fermenting'
                ORDER BY
                    r.reading_time DESC
                LIMIT 2
            )

            UNION ALL

            -- Get 2 most recent High Pressure alerts
            (
                SELECT
                    rec.recipe_name AS batch,
                    v.name AS vat,
                    'Pressure' AS type,
                    CAST(r.pressure AS VARCHAR) || ' PSI' AS value,
                    'High' AS level,
                    r.reading_time
                FROM
                    VatSensorReadings AS r
                JOIN
                    Batches AS b ON r.batch_id = b.batch_id
                JOIN
                    Recipes AS rec ON b.recipe_id = rec.recipe_id
                JOIN
                    Vats AS v ON r.vat_id = v.vat_id
                WHERE
                    r.pressure > 14.5 -- High pressure threshold
                    AND b.status = 'Fermenting'
                ORDER BY
                    r.reading_time DESC
                LIMIT 2
            )

            UNION ALL

            -- Get 2 most recent Warning Pressure alerts
            (
                SELECT
                    rec.recipe_name AS batch,
                    v.name AS vat,
                    'Pressure' AS type,
                    CAST(r.pressure AS VARCHAR) || ' PSI' AS value,
                    'Warning' AS level,
                    r.reading_time
                FROM
                    VatSensorReadings AS r
                JOIN
                    Batches AS b ON r.batch_id = b.batch_id
                JOIN
                    Recipes AS rec ON b.recipe_id = rec.recipe_id
                JOIN
                    Vats AS v ON r.vat_id = v.vat_id
                WHERE
                    r.pressure BETWEEN 14.0 AND 14.5 -- Warning pressure threshold
                    AND b.status = 'Fermenting'
                ORDER BY
                    r.reading_time DESC
                LIMIT 2
            )

            UNION ALL

            -- Get 3 most recent Low pH alerts
            (
                SELECT
                    rec.recipe_name AS batch,
                    v.name AS vat,
                    'pH' AS type,
                    CAST(r.ph AS VARCHAR) AS value,
                    'Low' AS level,
                    r.reading_time
                FROM
                    VatSensorReadings AS r
                JOIN
                    Batches AS b ON r.batch_id = b.batch_id
                JOIN
                    Recipes AS rec ON b.recipe_id = rec.recipe_id
                JOIN
                    Vats AS v ON r.vat_id = v.vat_id
                WHERE
                    r.ph < 4.6 -- Low pH threshold
                    AND b.status = 'Fermenting'
                ORDER BY
                    r.reading_time DESC
                LIMIT 3
            )

            -- Order all combined results by time, newest first
            ORDER BY
                reading_time DESC;
        ";
        
        alertsQuery = queryExecute(sql, {}, { returnType: "array" });
        
        response.alerts = alertsQuery;
        response.success = true;


    } catch (any e) {
        // Use the global error handler from Application.cfc
        throw(e);
    }

    // --- 3. Return the JSON response ---
    writeOutput(serializeJson(response));

</cfscript>