<cfscript>
/**
 * ========================================================================
 * API ENDPOINT: NATIVE AGENT ORCHESTRATION WITH LOCAL TOOLS (MCP-LIKE)
 * ========================================================================
 *
 * PURPOSE:     Bypasses Dialogflow CX and acts as a local agentic orchestrator.
 *              Uses native ChatModel to decide which tool to call, executes
 *              the tool locally via BrewMasterTools.cfc, and synthesizes the
 *              final natural language response.
 *
 * HTTP METHOD: POST
 *
 * BODY (JSON): { "prompt": "User message" }
 *
 * ========================================================================
 */
    response = { "success": false, "text": "", "error": "", "tool_used": "", "tool_arguments": {}, "tool_result": {} };

    try {
        // Only allow POST requests
        if (cgi.request_method != "POST") {
            cfheader(statusCode=405);
            response.message = "This endpoint only accepts POST requests.";
            writeOutput(serializeJson(response));
            return;
        }

        // Parse Request
        requestBody = deserializeJson(toString(getHttpRequestData().content));
        if (!structKeyExists(requestBody, "prompt") || len(trim(requestBody.prompt)) < 3) {
            throw("Missing or invalid 'prompt' in request");
        }
        userPrompt = trim(requestBody.prompt);
        
        // 1. Initialize native ChatModel (using Centralized API key)
        apiKey = application.AI_STUDIO_API_KEY;
        chatConfig = {
            "provider": "gemini",
            "modelName": "gemini-2.5-flash",
            "apiKey": trim(apiKey),
            "temperature": 0.0, // Low temperature for deterministic tool routing
            "timeout": 30,
            "maxRetries": 1
        };
        chatModel = ChatModel(chatConfig);

        // 2. Define the system instructions for tool routing
        systemInstruction = 'You are the Brewmaster AI Assistant. You have access to these local tools:
1. checkInventory(recipeName, volumeGallons): Checks if ingredients are sufficient.
2. getRecipeDetails(recipeName): Looks up recipe style, target vitals, and ingredients.
3. checkBatchRisk(style): Checks active fermentation batches for anomalies.

If you need to call a tool to answer the user question, you MUST respond ONLY with a JSON object in this format (no markdown code blocks, backticks, or extra text):
{
    "tool": "toolName",
    "arguments": {
        "recipeName": "name_of_beer",
        "volumeGallons": 5,
        "style": "beer_style"
    }
}

If no tools are needed, respond normally in plain text.

User question: ' & userPrompt;

        aiResponse = chatModel.chat(systemInstruction);
        rawReply = trim(aiResponse.message);

        // Clean markdown block wrappers if returned
        cleanReply = rawReply;
        if (left(cleanReply, 7) == "```json") {
            cleanReply = mid(cleanReply, 8, len(cleanReply) - 10);
        } else if (left(cleanReply, 3) == "```") {
            cleanReply = mid(cleanReply, 4, len(cleanReply) - 6);
        }
        cleanReply = trim(cleanReply);

        isToolCall = false;
        toolCall = {};
        if (left(cleanReply, 1) == "{" && right(cleanReply, 1) == "}") {
            try {
                toolCall = deserializeJson(cleanReply);
                if (structKeyExists(toolCall, "tool") || structKeyExists(toolCall, "TOOL")) {
                    isToolCall = true;
                }
            } catch (any e) {}
        }

        if (isToolCall) {
            // Execute the tool locally
            tools = new api.v1.tools.BrewMasterTools();
            toolResult = {};
            
            toolName = structKeyExists(toolCall, "tool") ? toolCall["tool"] : toolCall["TOOL"];
            rawArgs = {};
            if (structKeyExists(toolCall, "arguments")) {
                rawArgs = toolCall["arguments"];
            } else if (structKeyExists(toolCall, "ARGUMENTS")) {
                rawArgs = toolCall["ARGUMENTS"];
            }

            // Normalize arguments struct keys to standard camelCase
            toolArgs = {};
            for (key in rawArgs) {
                if (lcase(key) == "recipename") {
                    toolArgs["recipeName"] = rawArgs[key];
                } else if (lcase(key) == "volumegallons") {
                    toolArgs["volumeGallons"] = rawArgs[key];
                } else if (lcase(key) == "style") {
                    toolArgs["style"] = rawArgs[key];
                } else {
                    toolArgs[key] = rawArgs[key];
                }
            }

            if (toolName == "checkInventory") {
                recipe = structKeyExists(toolArgs, "recipeName") ? toolArgs["recipeName"] : "";
                vol = (structKeyExists(toolArgs, "volumeGallons") && isNumeric(toolArgs["volumeGallons"])) ? val(toolArgs["volumeGallons"]) : 1;
                toolResult = tools.checkInventory(recipe, vol);
            } else if (toolName == "getRecipeDetails") {
                recipe = structKeyExists(toolArgs, "recipeName") ? toolArgs["recipeName"] : "";
                toolResult = tools.getRecipeDetails(recipe);
            } else if (toolName == "checkBatchRisk") {
                sty = structKeyExists(toolArgs, "style") ? toolArgs["style"] : "";
                toolResult = tools.checkBatchRisk(sty);
            } else {
                throw("Unknown tool call requested by model: " & toolName);
            }

            // Synthesize the final response with tool results
            synthesisPrompt = "You are the Brewmaster AI Assistant. You called the local tool '#toolName#' with arguments: #serializeJson(toolArgs)#. "
                & "The tool execution returned this data: #serializeJson(toolResult)#. "
                & "Use this data to write a professional, natural-language response answering the user's original question: '#userPrompt#'.";
            
            finalResponse = chatModel.chat(synthesisPrompt);
            response.text = finalResponse.message;
            response.tool_used = toolName;
            response.tool_arguments = toolArgs;
            response.tool_result = toolResult;
        } else {
            // Direct plain text response
            response.text = rawReply;
        }
        
        response.success = true;

    } catch (any e) {
        cfheader(statusCode=500);
        response.error = "Agent Execution Failed: " & e.message;
        response.detail = structKeyExists(e, "tagContext") ? serializeJson(e.tagContext) : e.detail;
    }

    // Output JSON
    writeOutput(serializeJson(response));
</cfscript>
