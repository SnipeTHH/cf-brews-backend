<cfscript>
 /**
 * ========================================================================
 * API ENDPOINT (CONTROLLER)
 * ========================================================================
 *
 * PURPOSE:     Returns the total number of rows in the VatSensorReadings table.
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
        "total": 0
    };

    try {

        // --- 1. Only allow GET requests ---
        if (cgi.request_method != "GET") {
            cfheader(statusCode=405);
            response.message = "This endpoint only accepts GET requests.";
            writeOutput(serializeJson(response));
            return;
        }

        // --- 2. Get the count ---
        countQuery = queryExecute(
            "SELECT COUNT(*) as total FROM VatSensorReadings"
        );

        if (countQuery.recordCount == 1) {
            response.total = countQuery.total;
            response.success = true;
        } else {
            response.message = "Could not retrieve row count.";
        }

    } catch (any e) {
        // Use the global error handler from Application.cfc
        throw(e);
    }

    // --- 3. Return the JSON response ---
    // The api/Application.cfc already sets the content type to JSON
    writeOutput(serializeJson(response));

</cfscript>
