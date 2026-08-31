/**
 * Analytics.cfc
 *
 * This component handles all analytical queries for the CF-Brews API.
 * It encapsulates all database logic.
 */
component {

    /**
    * Runs the SAME batch summary query, but with the
    * columnar engine explicitly disabled for a side-by-side comparison.
    */
    public struct function getBatchSummaryNoColumnar() {
        var response = {};

        try {
            // 1. Start the timer
            var startTime = getTickCount();
            
            // 2. Wrap both queries in a single transaction
            // This GUARANTEES they run on the same connection.
            transaction {
                
                // 3. Define the *exact same* heavy analytical query
                var sql = " SELECT "
                    & "     B.batch_name, "
                    & "     ROUND(AVG(V.temp), 2) AS avg_temp, "
                    & "     MAX(V.pressure) AS max_pressure, "
                    & "     ROUND(MAX(V.ph) - MIN(V.ph), 2) AS ph_variance "
                    & " FROM "
                    & "     VatSensorReadings_Row AS V "
                    & " JOIN "
                    & "     Batches AS B ON V.batch_id = B.batch_id "
                    & " GROUP BY "
                    & "     B.batch_name "
                    & " ORDER BY "
                    & "     avg_temp DESC ";

                // 4. Execute the query
                // We assign this to a variable outside the transaction
                // scope so we can return it.
                qAnalytics = queryExecute(sql, {}, {
                    returnType: "array"
                });
            } // The transaction automatically commits here

            // 5. Stop the timer and calculate duration
            var duration_ms = getTickCount() - startTime;
            var duration_sec = round( (duration_ms / 1000) * 100 ) / 100;

            // 6. Prepare the successful response
            response = {
                "success": true,
                "querySpeed": duration_sec,
                "results": qAnalytics
            };

        } catch (any e) {
            // 7b. Prepare the error response
            response = {
                "success": false,
                "message": e.message,
                "detail": e.detail
            };
        }

        // 8. Return the struct
        return response;
    }

    /**
     * Runs the heavy batch summary query and times it.
     */
    public struct function getBatchSummary() {
        var response = {};

        try {
            // 1. Start the timer
            var startTime = getTickCount();

            // 2. Define the heavy analytical query
            // Using string concatenation for broad CF compatibility.
            var sql = " SELECT "
                & "     B.batch_name, "
                & "     ROUND(AVG(V.temp), 2) AS avg_temp, "
                & "     MAX(V.pressure) AS max_pressure, "
                & "     ROUND(MAX(V.ph) - MIN(V.ph), 2) AS ph_variance "
                & " FROM "
                & "     VatSensorReadings AS V "
                & " JOIN "
                & "     Batches AS B ON V.batch_id = B.batch_id "
                & " GROUP BY "
                & "     B.batch_name "
                & " ORDER BY "
                & "     avg_temp DESC ";

            // 3. Execute the query
            var qAnalytics = queryExecute(sql, {}, {
                returnType: "array" 
            });

            // 4. Stop the timer and calculate duration
            var duration_ms = getTickCount() - startTime;
            var duration_sec = round( (duration_ms / 1000) * 100 ) / 100;

            // 5. Prepare the successful response
            response = {
                "success": true,
                "querySpeed": duration_sec,
                "results": qAnalytics
            };

        } catch (any e) {
            // 5b. Prepare the error response
            response = {
                "success": false,
                "message": e.message,
                "detail": e.detail
            };
        }

        // 6. Return the struct to the caller
        return response;
    }

    /**
     * Runs EXPLAIN ANALYZE on the summary query.
     * --- UPDATED TO RETURN querySpeed AND RUN A MORE COMPLEX QUERY ---
     */
    public struct function getBatchSummaryExplain() {
        var response = {};

        try {
            // --- 1. Start timer ---
            var startTime = getTickCount();
            
            // --- UPDATED: More complex query ---
            var sql = " EXPLAIN (ANALYZE, VERBOSE, BUFFERS, COLUMNAR_ENGINE) "
                & " SELECT "
                & "     batch_id, "
                & "     ROUND(AVG(temp), 2) AS avg_temp, "
                & "     MAX(pressure) AS max_pressure, "
                & "     ROUND(MAX(ph) - MIN(ph), 2) AS ph_variance "
                & " FROM VatSensorReadings "
                & " GROUP BY batch_id ";

            // 2. Execute the EXPLAIN query
            var qExplain = queryExecute(sql);

            // --- 3. Stop timer ---
            var duration_ms = getTickCount() - startTime;
            var duration_sec = round( (duration_ms / 1000) * 100 ) / 100;

            // 4. Format the query plan into a simple text block
            var explainOutput = "";
            for (var row in qExplain) {
                explainOutput &= row["QUERY PLAN"] & chr(10); // chr(10) is a newline
            }

            // 5. Prepare the successful response
            response = {
                "success": true,
                "querySpeed": duration_sec, // --- Returns speed ---
                "explainOutput": explainOutput
            };

        } catch (any e) {
            // 5b. Prepare the error response
            response = {
                "success": false,
                "message": e.message
            };
        }

        // 6. Return the struct
        return response;
    }

    /**
     * Runs EXPLAIN ANALYZE on the summary query.
     * --- UPDATED TO RETURN querySpeed AND RUN A MORE COMPLEX QUERY ---
     */
    public struct function getBatchSummaryNoColumnarExplain() {
        var response = {};

        try {
            // --- 1. Start timer ---
            var startTime = getTickCount();
            
            // --- UPDATED: More complex query ---
            var sql = " EXPLAIN (ANALYZE, VERBOSE, BUFFERS, COLUMNAR_ENGINE) "
                & " SELECT "
                & "     batch_id, "
                & "     ROUND(AVG(temp), 2) AS avg_temp, "
                & "     MAX(pressure) AS max_pressure, "
                & "     ROUND(MAX(ph) - MIN(ph), 2) AS ph_variance "
                & " FROM VatSensorReadings_row "
                & " GROUP BY batch_id ";

            // 2. Execute the EXPLAIN query
            var qExplain = queryExecute(sql);
            
            // --- 3. Stop timer ---
            var duration_ms = getTickCount() - startTime;
            var duration_sec = round( (duration_ms / 1000) * 100 ) / 100;

            // 4. Format the query plan into a simple text block
            var explainOutput = "";
            for (var row in qExplain) {
                explainOutput &= row["QUERY PLAN"] & chr(10); // chr(10) is a newline
            }

            // 5. Prepare the successful response
            response = {
                "success": true,
                "querySpeed": duration_sec, // --- Returns speed ---
                "explainOutput": explainOutput
            };

        } catch (any e) {
            // 5b. Prepare the error response
            response = {
                "success": false,
                "message": e.message
            };
        }

        // 6. Return the struct
        return response;
    }

}

