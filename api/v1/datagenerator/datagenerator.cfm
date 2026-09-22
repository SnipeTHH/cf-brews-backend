<cfscript>
/**
 * ========================================================================
 * API ENDPOINT (CONTROLLER)
 * ========================================================================
 *
 * PURPOSE:     Inserts a large number of mock sensor readings.
 *
 * HTTP METHOD: POST
 *
 * CALLS:       /api/v1/DataGenerator.cfc -> generate()
 *
 * BODY (JSON):
 * {
 * "numRows": 10000, // Optional, defaults to 10,000
 * "batchName": "Demo Batch", // Optional
 * "vatName": "Demo Vat" // Optional
 * }
 *
 * ========================================================================
 */

    response = {};

    try {

        // --- 1. Only allow POST requests ---
        if (cgi.request_method != "POST") {
            cfheader(statusCode=405);
            response.message = "This endpoint only accepts POST requests.";
            writeOutput(serializeJson(response));
            return;
        }

        // --- 2. Get parameters from JSON body ---
        params = {};
        try {
            requestBody = getHttpRequestData().content;
            if (isJson(requestBody) && len(requestBody) > 0) {
                params = deserializeJson(requestBody);
            }
        } catch (any e) {
            // Ignore if body is empty or not JSON
        }

        // --- 3. Call the Service Layer ---
        generatorService = new api.v1.datagenerator.DataGenerator();
        response = generatorService.generate(params);
        
        if (!response.success) {
            cfheader(statusCode=500);
        }

    } catch (any e) {
        // Use the global error handler from Application.cfc
        // We just need to re-throw the error
        throw(e);
    }

    // --- 4. Return the JSON response ---
    writeOutput(serializeJson(response));

</cfscript>
