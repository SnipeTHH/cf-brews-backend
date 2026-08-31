<cfscript>
/**
 * ========================================================================
 * API ENDPOINT (CONTROLLER)
 * ========================================================================
 *
 * PURPOSE:     AlloyDB Conversational Analytics (Preview) Gateway.
 *              Exposes the new managed GCP Data Agents Conversational Analytics API
 *              to the React frontend. Securely fetches OAuth tokens and forwards
 *              prompts to geminidataanalytics.googleapis.com.
 *
 * HTTP METHOD: POST
 *
 * BODY (JSON): { "prompt": "English question" }
 *
 * USED BY:     React BreweryAssistant UI (BreweryAssistant.jsx - Tab 4)
 *
 * ========================================================================
 */

    // Prepare response object
    response = {
        "success": false,
        "answer": "",
        "reasoning_steps": [],
        "query": "",
        "data": [],
        "chart_data": "",
        "message": ""
    };

    // Helper: Get OAuth token from metadata server on Cloud Run
    function getAuthToken() {
        try {
            var httpRes = "";
            cfhttp(url="http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token", method="GET", result="httpRes") {
                cfhttpparam(type="header", name="Metadata-Flavor", value="Google");
            }
            if (val(httpRes.statusCode) != 200) {
                 throw(message="Metadata server error. Status: #httpRes.statusCode#", detail=httpRes.fileContent);
            }
            var tokenData = deserializeJson(httpRes.fileContent);
            return tokenData.access_token;
        } catch (any e) {
            throw(message="Could not get auth token from metadata server.", detail=e.message);
        }
    }

    try {
        // 1. Only allow POST requests
        if (cgi.request_method != "POST") {
            cfheader(statusCode=405);
            response.message = "This endpoint only accepts POST requests.";
            writeOutput(serializeJson(response));
            abort;
        }

        // 2. Parse Request Body
        requestBody = deserializeJson(toString(getHttpRequestData().content));
        if (!structKeyExists(requestBody, "prompt") || len(trim(requestBody.prompt)) < 3) {
            throw(message="A valid conversational prompt is required.");
        }
        userPrompt = requestBody.prompt;

        // 3. Real Mode Handler (Calling geminidataanalytics.googleapis.com)
        try {
            token = getAuthToken();
            projectId = server.system.environment.GOOGLE_CLOUD_PROJECT ?: "";
            if (len(trim(projectId)) == 0) throw("GOOGLE_CLOUD_PROJECT environment variable is not configured.");
            
            // Format dynamic Agent ID from environment
            agentId = server.system.environment.ALLOYDB_CA_DATA_AGENT_ID ?: server.system.environment.VERTEX_AGENT_ID ?: "";
            if (len(trim(agentId)) == 0) throw("ALLOYDB_CA_DATA_AGENT_ID environment variable is not configured.");
            if (left(agentId, 6) != "agent_") {
                agentId = "agent_" & agentId;
            }
            agentPath = "projects/#projectId#/locations/global/dataAgents/#agentId#";

            // Step 1: Create ephemeral conversation resource
            createUrl = "https://geminidataanalytics.googleapis.com/v1beta/projects/#projectId#/locations/global/conversations";
            createBody = { "agents": [ agentPath ] };
            
            createRes = "";
            cfhttp(url=createUrl, method="POST", result="createRes", timeout=15) {
                cfhttpparam(type="header", name="Authorization", value="Bearer #token#");
                cfhttpparam(type="header", name="Content-Type", value="application/json");
                cfhttpparam(type="body", value=serializeJson(createBody));
            }

            if (val(createRes.statusCode) != 200 && val(createRes.statusCode) != 201) {
                throw(message="Google Conversation Creation Error: #createRes.statusCode#", detail=createRes.fileContent);
            }
            
            convData = deserializeJson(createRes.fileContent);
            conversationPath = convData.name;

            // Step 2: Send Chat Turn
            chatUrl = "https://geminidataanalytics.googleapis.com/v1beta/projects/#projectId#/locations/global:chat";
            chatBody = {
                "parent": "projects/#projectId#/locations/global",
                "client_id": "ALLOYDB",
                "conversation_reference": {
                    "conversation": conversationPath,
                    "data_agent_context": {
                        "data_agent": agentPath
                    }
                },
                "messages": [
                    {
                        "user_message": {
                            "text": userPrompt
                        }
                    }
                ]
            };

            apiResult = "";
            cfhttp(url=chatUrl, method="POST", result="apiResult", timeout=40) {
                cfhttpparam(type="header", name="Authorization", value="Bearer #token#");
                cfhttpparam(type="header", name="Content-Type", value="application/json");
                cfhttpparam(type="body", value=serializeJson(chatBody));
            }

            if (val(apiResult.statusCode) == 200) {
                googleData = deserializeJson(apiResult.fileContent);
                
                response.success = true;
                
                // Parse Events array from :chat response
                for (event in googleData) {
                    if (structKeyExists(event, "systemMessage")) {
                        sysMsg = event.systemMessage;
                        
                        // Parse Thoughts / Reasoning steps
                        if (structKeyExists(sysMsg, "text") 
                            && structKeyExists(sysMsg.text, "textType") 
                            && sysMsg.text.textType == "THOUGHT" 
                            && arrayLen(sysMsg.text.parts) > 0) {
                            
                            arrayAppend(response.reasoning_steps, {
                                "title": "Agent Thought",
                                "description": sysMsg.text.parts[1]
                            });
                        }
                        
                        // Parse SQL Query
                        if (structKeyExists(sysMsg, "data") 
                            && structKeyExists(sysMsg.data, "generatedSql")) {
                            response.query = sysMsg.data.generatedSql;
                        }
                        
                        // Parse Data Grid Results
                        if (structKeyExists(sysMsg, "data") 
                            && structKeyExists(sysMsg.data, "result") 
                            && structKeyExists(sysMsg.data.result, "data") 
                            && isArray(sysMsg.data.result.data)) {
                            response.data = sysMsg.data.result.data;
                        }
                        // Parse Chart Data
                        if (structKeyExists(sysMsg, "chart") 
                            && structKeyExists(sysMsg.chart, "result")
                            && structKeyExists(sysMsg.chart.result, "vegaConfig")
                            && isStruct(sysMsg.chart.result.vegaConfig)) {
                            
                            response.chart_data = sysMsg.chart.result.vegaConfig;
                            
                            // Map the raw data grid from chart data values if it was not sent separately
                            if (arrayLen(response.data) == 0 
                                && structKeyExists(sysMsg.chart.result.vegaConfig, "data") 
                                && structKeyExists(sysMsg.chart.result.vegaConfig.data, "values") 
                                && isArray(sysMsg.chart.result.vegaConfig.data.values)) {
                                response.data = sysMsg.chart.result.vegaConfig.data.values;
                            }
                        }
                        
                        // Parse Final Conversational Response
                        if (structKeyExists(sysMsg, "text") 
                            && structKeyExists(sysMsg.text, "textType") 
                            && sysMsg.text.textType == "FINAL_RESPONSE" 
                            && arrayLen(sysMsg.text.parts) > 0) {
                            response.answer = sysMsg.text.parts[1];
                        }
                    }
                }
                
            } else {
                writeLog(file="cfbrews_error", text="Real Conversational Analytics API call failed with status: #apiResult.statusCode#. Content: #apiResult.fileContent#");
                cfheader(statusCode=500);
                response.message = "Real GCP API returned code #apiResult.statusCode#. Please check configuration.";
            }

        } catch (any apiError) {
            writeLog(file="cfbrews_error", text="Real Conversational Analytics API call exception: #apiError.message#");
            cfheader(statusCode=500);
            response.message = "Real GCP API failed: " & apiError.message;
        }

    } catch (any e) {
        errorMsg = "query-data-agent API Gateway Failed: " & e.message & " | Detail: " & (e.detail ?: "") & " | Stack: " & (e.stacktrace ?: "");
        writeLog(file="cfbrews_error", text=errorMsg);
        systemOutput(errorMsg, true);
        
        cfheader(statusCode=500);
        response.message = "Conversational Analytics gateway error: " & e.message;
    }

    // Output JSON
    writeOutput(serializeJson(response));
</cfscript>
