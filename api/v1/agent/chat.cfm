<cfscript>
/**
 * ========================================================================
 * API ENDPOINT: BREWMASTER AI CONVERSATIONAL AGENT PROXY (TAB 1)
 * ========================================================================
 *
 * PURPOSE:     Proxies chat requests from the React frontend (Tab 1) to the
 *              Google Cloud Vertex AI Agent Builder / Dialogflow CX Playbook
 *              Agent ("BrewMaster AI"), which orchestrates OpenAPI ColdFusion
 *              webhook tools and RAG PDF SOP data stores.
 *
 * ========================================================================
 */
cfsetting(requestTimeout=90);

// --- HELPER: Get secure Google Cloud token ---
function getAuthToken() {
    try {
        var httpRes = "";
        cfhttp(url="http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token", method="GET", result="httpRes", timeout=10) {
            cfhttpparam(type="header", name="Metadata-Flavor", value="Google");
        }
        if (val(httpRes.statusCode) != 200) throw(message="Metadata token failed", detail=httpRes.fileContent);
        return deserializeJson(httpRes.fileContent).access_token;
    } catch (any e) {
        throw(message="Could not get auth token.", detail=e.message);
    }
}

    response = { "success": false, "text": "", "error": "" };

    try {
        // 1. Setup Variables from Environment / Secret Manager
        projectId = trim(server.system.environment.GOOGLE_CLOUD_PROJECT ?: "");
        location  = trim(server.system.environment.GOOGLE_CLOUD_REGION ?: "us-central1");
        // Dedicated Dialogflow CX / Vertex AI Playbook Agent ID for BrewMaster AI (Tab 1)
        brewmasterAgentId = trim(server.system.environment.BREWMASTER_AGENT_ID ?: "");

        // 2. Parse Request
        requestBody = deserializeJson(toString(getHttpRequestData().content));
        if (!structKeyExists(requestBody, "prompt")) throw("Missing 'prompt' in request");

        userPrompt = trim(requestBody.prompt);
        clientSessionId = structKeyExists(requestBody, "sessionId") && len(trim(requestBody.sessionId)) > 0
            ? rereplace(trim(requestBody.sessionId), "[^a-zA-Z0-9_-]", "", "all")
            : createUUID();

        authToken = getAuthToken();

        // 3. Fast-path silent session warm-up from frontend mount (prevents concurrent session lock)
        if (lCase(userPrompt) == "hello") {
            response.success = true;
            response.text = "Agent session primed.";
            response.sessionId = clientSessionId;
            writeOutput(serializeJson(response));
            abort;
        }

        // 4. Optional ColdFusion Data-Binding for cross-checking customer feedback with IoT vat telemetry
        promptToSend = userPrompt;
        if (findNoCase("flat beer", userPrompt) > 0 || findNoCase("anomal", userPrompt) > 0 || findNoCase("review", userPrompt) > 0) {
            try {
                telemetryQuery = queryExecute("
                    SELECT b.batch_id, r.recipe_name, r.style, r.ideal_min_temp, r.ideal_max_temp,
                           lr.temp AS current_temp, lr.pressure AS current_pressure, lr.operator_notes
                    FROM Batches b
                    INNER JOIN Recipes r ON b.recipe_id = r.recipe_id
                    LEFT JOIN LATERAL (
                        SELECT temp, pressure, operator_notes
                        FROM VatSensorReadings vsr
                        WHERE vsr.batch_id = b.batch_id
                        ORDER BY reading_time DESC
                        LIMIT 1
                    ) lr ON TRUE
                    WHERE b.status = 'Fermenting'
                    ORDER BY b.batch_id ASC
                ");
                telemetrySummary = [];
                for (row in telemetryQuery) {
                    arrayAppend(telemetrySummary, "Batch ##" & row.batch_id & " (" & row.recipe_name & " - " & row.style & "): Temp=" & row.current_temp & "F (Ideal " & row.ideal_min_temp & "-" & row.ideal_max_temp & "F), Pressure=" & row.current_pressure & " PSI (SOP Normal Range: 8.0-12.0 PSI; <8.0 PSI causes under-carbonation/flat beer; >15.0 PSI is critical over-pressure), Notes=" & (len(row.operator_notes) ? row.operator_notes : "None"));
                }
                if (arrayLen(telemetrySummary) > 0) {
                    promptToSend = userPrompt & chr(10) & chr(10) & "[ColdFusion Live AlloyDB IoT Telemetry Context: " & arrayToList(telemetrySummary, "; ") & "]";
                }
            } catch (any dbErr) {
                // Non-fatal if telemetry enrichment fails
            }
        }

        // 5. Call Dialogflow CX / Vertex AI Playbook Agent detectIntent endpoint
        detectUrl = "https://#location#-dialogflow.googleapis.com/v3/projects/#projectId#/locations/#location#/agents/#brewmasterAgentId#/sessions/#clientSessionId#:detectIntent";

        detectBody = {
            "queryInput": {
                "text": {
                    "text": promptToSend
                },
                "languageCode": "en"
            }
        };

        apiRes = "";
        cfhttp(url=detectUrl, method="POST", result="apiRes", timeout=60) {
            cfhttpparam(type="header", name="Authorization", value="Bearer #authToken#");
            cfhttpparam(type="header", name="x-goog-user-project", value="#projectId#");
            cfhttpparam(type="header", name="Content-Type", value="application/json");
            cfhttpparam(type="body", value=serializeJson(detectBody));
        }

        if (val(apiRes.statusCode) != 200) {
            throw(message="Dialogflow CX Error: #apiRes.statusCode#", detail=apiRes.fileContent);
        }

        dialogflowData = deserializeJson(apiRes.fileContent);
        replyParts = [];

        if (structKeyExists(dialogflowData, "queryResult") && structKeyExists(dialogflowData.queryResult, "responseMessages")) {
            for (msg in dialogflowData.queryResult.responseMessages) {
                if (structKeyExists(msg, "text") && structKeyExists(msg.text, "text") && arrayLen(msg.text.text) > 0) {
                    for (part in msg.text.text) {
                        if (len(trim(part)) > 0) {
                            arrayAppend(replyParts, trim(part));
                        }
                    }
                }
            }
        }

        botReply = arrayLen(replyParts) > 0 ? arrayToList(replyParts, chr(10) & chr(10)) : "No response from BrewMaster AI.";

        response.success = true;
        response.text = botReply;
        response.sessionId = clientSessionId;

    } catch (any e) {
        writeLog(file="cfbrews_error", text="Agent Chat Error: #e.message# #e.detail#");
        cfheader(statusCode=500);
        response.error = "Agent request failed.";
    }

    writeOutput(serializeJson(response));
</cfscript>