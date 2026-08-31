/**
 * Application.cfc - Datasource created in onApplicationStart
 * ACF 2025 Syntax
 */
component {

    // --- Application Settings ---
    this.name = "cfbrews";
    this.datasource = "cfbrews_dsn";
    this.datasources = {
        "#this.datasource#": {
            class: "org.postgresql.Driver",
            url: "jdbc:postgresql://#Trim(server.system.environment["DB_IP"])#:5432/cfbrews_db",
            username: Trim(server.system.environment["DB_USER"]), 
            password: Trim(server.system.environment["DB_PASS"])
        },
        // --- BigQuery Datasource ---
        "bigquery_dsn": {
            class: "com.simba.googlebigquery.jdbc42.Driver",
            // OAuthType=3 uses the Cloud Run Service Account automatically
            url: "jdbc:bigquery://https://www.googleapis.com/bigquery/v2:443;ProjectId=#Trim(server.system.environment.GOOGLE_CLOUD_PROJECT)#;OAuthType=3;"
            // No username/password required when using OAuthType=3 on Cloud Run
        }
    };

    this.sessionManagement = false;
    this.clientManagement = false;
    this.applicationTimeout = createTimeSpan( 0, 0, 15, 0 );
    this.scriptProtect = "all";

    /**
     * Fires when the application first starts (per-container).
     */
    public boolean function onRequestStart( required string targetPage ) {

        // Check if the request is for the API directory.
        // We use cgi.script_name as it's a reliable path.
        if (Left(UCase(cgi.script_name), 5) == "/API/") {
            
            // --- API-Specific Headers ---
            cfheader(name="Access-Control-Allow-Origin", value="*");
            cfheader(name="Access-Control-Allow-Methods", value="GET, POST, OPTIONS");
            cfheader(name="Access-Control-Allow-Headers", value="Content-Type");
            
            // Handle OPTIONS pre-flight requests
            if (cgi.request_method == "OPTIONS") {
                // Return an empty 200 OK response
                cfheader(statusCode=200);
                return false; // Stop further processing
            }

            // --- Set default content type for all API responses ---
            cfcontent(type="application/json");
        }
        
        // For all other requests (like /health.cfm or /index.cfm),
        // the 'if' block is skipped and they render normally.

        return true;
    }

    public boolean function onApplicationStart() {
        // Set application-scoped variables for use in other files
        application.cfbrews_dsn = this.datasource;
        application.BIGQUERY_DSN = "bigquery_dsn";
        application.AI_STUDIO_API_KEY = server.system.environment.AI_STUDIO_API_KEY ?: server.system.environment.GEMINI_API_KEY ?: "";

        // Initialize Native MCP Server (CF 2026/2025 new feature)
        try {
            var mcpConfig = {
                "serverInfo": {
                    "name": "BrewMaster-Tools-MCP-Server",
                    "version": "1.0.0"
                },
                "capabilities": {
                    "tools": true,
                    "prompts": false,
                    "resources": false
                },
                "tools": [
                    { "cfc": "api.v1.tools.NativeBrewMasterTools" }
                ]
            };
            application.mcpServer = MCPServer(mcpConfig);
        } catch (any e) {
            application.mcpServerError = {
                "message": e.message,
                "detail": e.detail,
                "type": e.type
            };
            writeLog(file = "cfbrews_error", text = "Failed to initialize MCPServer: " & e.message);
        }

        return true;
    }

    public void function onError( required any exception, required string eventName ) {
        // Log details if possible
        try {
            writeLog(file = "cfbrews_error", text = "onError triggered by [#eventName#] for page [#cgi.script_name#]: [#exception.type#] #exception.message# #exception.detail#");
        } catch (any e) {}

        // Return generic error
        cfheader(statusCode=500);
        cfcontent(type="application/json");
        var errorResponse = {"error": true,"message": "An internal server error occurred.","type": "unknown"};
        try {
             errorResponse.type = exception.type;
        } catch (any e) {}

        try {
            writeOutput( serializeJson(errorResponse) );
        } catch (any e) {}
        return;
    }
}
