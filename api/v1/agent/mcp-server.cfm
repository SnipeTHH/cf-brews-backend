<cfscript>
/**
 * ========================================================================
 * API ENDPOINT: NATIVE CODFUSION MCP SERVER HANDLER
 * ========================================================================
 *
 * PURPOSE:     Acts as the entry point for external MCP clients to interact
 *              with the exposed BrewMaster tools.
 *
 * HTTP METHOD: POST/GET
 *
 * ========================================================================
 */
    try {
        if (structKeyExists(application, "mcpServer")) {
            application.mcpServer.handleRequest();
        } else {
            cfheader(statusCode=503);
            writeOutput(serializeJson({
                "success": false,
                "error": "MCP Server not initialized in Application scope."
            }));
        }
    } catch (any e) {
        writeLog(file="cfbrews_error", text="MCP Server Error: #e.message# #e.detail#");
        cfheader(statusCode=500);
        writeOutput(serializeJson({
            "success": false,
            "error": "MCP Request Execution Failed."
        }));
    }
</cfscript>
