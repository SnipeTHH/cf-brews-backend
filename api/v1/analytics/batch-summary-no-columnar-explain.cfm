<cfscript>
/**
 * ========================================================================
 * API ENDPOINT (CONTROLLER)
 * ========================================================================
 *
 * PURPOSE:     Gets the 'EXPLAIN ANALYZE' plan for the main analytical query.
 *
 * HTTP METHOD: GET
 *
 * CALLS:       /api/v1/analytics/Analytics.cfc -> getBatchSummaryNoColumnarExplain()
 *
 * RETURNS:     JSON
 * {
 * "success": true | false,
 * "explainOutput": (string)
 * }
 *
 * ========================================================================
 */
try {
    // 1. Get an instance of your new component
    analyticsService = new api.v1.analytics.Analytics();

    // 2. Call the function
    response = analyticsService.getBatchSummaryNoColumnarExplain();

    // 3. Set status code if it failed
    if (!response.success) {
        cfheader(statusCode=500);
    }

    // 4. Output the JSON response
    writeOutput(serializeJson(response));

} catch (any e) {
    // Catch CFC init errors
    cfheader(statusCode=500);
    writeOutput(serializeJson({"success": false, "message": e.message}));
}
</cfscript>