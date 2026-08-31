<cfscript>
/**
 * ========================================================================
 * API ENDPOINT: GET VATS & LIVE SENSOR DATA
 * ========================================================================
 *
 * PURPOSE: Returns all Vats, their current batch assignments, and their
 * MOST RECENT sensor reading.
 *
 * DEMO NOTE: Uses a LEFT JOIN LATERAL, which is highly efficient in
 * Postgres/AlloyDB for fetching the "top-N" records per group (i.e.,
 * the latest 1 reading per vat).
 *
 * ========================================================================
 */

    response = {
        "success": false,
        "vats": []
    };

    try {
        if (cgi.request_method != "GET") {
            throw(type="MethodNotAllowed", message="Only GET requests accepted");
        }

        // --- UPDATED SQL ---
        sql = "
            SELECT
                v.vat_id,
                v.name,
                r.recipe_name as current_batch,
                b.status as batch_status,  -- NEW: Get the real status
                lr.temp,
                lr.pressure,
                -- NEW: Full date and time format
                TO_CHAR(lr.reading_time, 'YYYY-MM-DD HH24:MI:SS') as last_read_time
            FROM
                Vats v
            LEFT JOIN
                Batches b ON v.current_batch_id = b.batch_id
            LEFT JOIN
                Recipes r ON b.recipe_id = r.recipe_id
            LEFT JOIN LATERAL (
                SELECT temp, pressure, reading_time
                FROM VatSensorReadings vsr
                WHERE vsr.vat_id = v.vat_id
                ORDER BY reading_time DESC
                LIMIT 1
            ) lr ON TRUE
            ORDER BY
                v.vat_id ASC
        ";

        vatsQuery = queryExecute(sql, {}, { returnType: "array" });

        response.vats = vatsQuery;
        response.success = true;

    } catch (any e) {
        cfheader(statusCode=500);
        response.error = e.message;
        response.detail = e.detail;
    }

    writeOutput(serializeJson(response));
</cfscript>