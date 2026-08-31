<cfscript>
    // Initialize response data
    responseData = {
        "message": "Testing Database Connections",
        "timestamp": now(),
        "alloydb": { "connected": false, "test_value": "", "error": "" },
        "bigquery": { "connected": false, "test_value": "", "error": "" }
    };

    // --- Test AlloyDB Connection ---
    try {
        // Using the default datasource defined in Application.cfc (cfbrews_dsn)
        // We explicitly set datasource here for clarity, though it defaults if not passed.
        alloyResult = queryExecute("SELECT 1 AS test_value", {}, {datasource="cfbrews_dsn"});

        responseData.alloydb.connected = true;
        responseData.alloydb.test_value = alloyResult.test_value[1];

    } catch (any e) {
        writeLog(file="cfbrews_error", text="AlloyDB Error: #e.message# #e.detail#");
        responseData.alloydb.error = e.message & " " & e.detail;
    }

    // --- Test BigQuery Connection ---
    try {
        // MUST explicitly use the 'bigquery_dsn' datasource here
        bqResult = queryExecute("SELECT 1 AS bq_test_value", {}, {datasource="bigquery_dsn"});

        responseData.bigquery.connected = true;
        responseData.bigquery.test_value = bqResult.bq_test_value[1];

    } catch (any e) {
        writeLog(file="cfbrews_error", text="BigQuery Error: #e.message# #e.detail#");
        responseData.bigquery.error = e.message & " " & e.detail;
    }

    // Output the JSON response
    cfheader(name="Content-Type", value="application/json");
    writeOutput( serializeJson(responseData) );
</cfscript>