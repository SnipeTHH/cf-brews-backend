<cfscript>
/**
 * ========================================================================
 * API ENDPOINT: SHOWCASING NATIVE COLDFUSION 2025 AI SERVICES
 * ========================================================================
 */

    // Set CORS and JSON response headers
    cfheader(name="Access-Control-Allow-Origin", value="*");
    cfcontent(type="application/json");

    response = {
        "success": false,
        "message": "",
        "version_running": "",
        "details": {}
    };

    try {
        response.version_running = server.coldfusion.productversion;

        // 1. Fetch API Key from application settings
        apiKey = application.AI_STUDIO_API_KEY;

        userPrompt = "Explain quantum computing in one sentence.";
        if (structKeyExists(url, "prompt") && len(trim(url.prompt)) > 0) {
            userPrompt = trim(url.prompt);
        }

        // 2. Configure Native Chat Model Structure
        chatConfig = {
            "provider": "gemini",
            "modelName": "gemini-2.5-flash", 
            "apiKey": trim(apiKey), 
            "temperature": 0.7,
            "timeout": 30, 
            "maxRetries": 1 
        };

        // 3. Showcase the new native compilation features!
        chatModel = ChatModel(chatConfig);
        aiResponse = chatModel.chat(userPrompt);

        // 4. Map the native response payload
        response.success = true;
        response.message = aiResponse.message;
        response.details.model = "gemini-2.5-flash";
        response.details.prompt_used = userPrompt;
        response.details.metadata = aiResponse.metadata ?: {};

    } catch (any e) {
        cfheader(statusCode=500);
        response.success = false;
        response.message = "Native AI Execution Failed: " & e.message;
        response.details.detail = e.detail;
        response.details.tagContext = e.tagContext ?: [];
        writeLog(file="cfbrews_error", text="Native AI Test Failed: #e.message# #e.detail#");
    }

    // Output JSON response
    writeOutput(serializeJson(response));
</cfscript>