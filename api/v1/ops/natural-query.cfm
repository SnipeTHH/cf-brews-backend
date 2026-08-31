<cfscript>
/**
 * ========================================================================
 * API ENDPOINT (CONTROLLER)
 * ========================================================================
 *
 * PURPOSE:     AlloyDB QueryData Natural Language Assistant.
 *              Translates conversational English into secure SQL using
 *              in-database LLM (Gemini) and executes it against secure views.
 *
 * HTTP METHOD: POST
 *
 * BODY (JSON): { "prompt": "English question" }
 *
 * CALLS:       AlloyDB AI (google_ml.predict_row calling Gemini)
 * 
 * USED BY:     React BreweryAssistant UI (BreweryAssistant.jsx)
 *
 * ========================================================================
 */

    // Prepare response object
    response = {
        "success": false,
        "query": "",
        "data": [],
        "message": "",
        "summary": ""
    };

    try {
        // 1. Only allow POST requests
        if (cgi.request_method != "POST") {
            cfheader(statusCode=405);
            response.message = "This endpoint only accepts POST requests.";
            writeOutput(serializeJson(response));
            return;
        }

        // 2. Parse Request Body
        requestBody = deserializeJson(toString(getHttpRequestData().content));
        if (!structKeyExists(requestBody, "prompt") || len(trim(requestBody.prompt)) < 3) {
            throw(message="A valid conversational prompt is required.");
        }
        userPrompt = requestBody.prompt;

        // 3. SQL Translation Query (using native PG18 ai.generate function)
        translationSql = "
            SELECT ai.generate(
                $$You are an expert database assistant. Translate the following natural language request into a single, read-only, secure PostgreSQL SELECT query.

TABLE SCHEMAS AVAILABLE:
1. brews.secure_batches (batch_id INT, status VARCHAR, start_time TIMESTAMP, recipe_name VARCHAR, style VARCHAR, description TEXT)
   -- Valid values for status (batch_status enum): 'Pending', 'Fermenting', 'Conditioning', 'Complete', 'Failed'
2. brews.secure_vatsensorreadings (reading_id BIGINT, batch_id INT, vat_id INT, temp DECIMAL, pressure DECIMAL, ph DECIMAL, reading_time TIMESTAMP)

RULES:
- Only query from these two exact views. Do not join with other tables.
- Return ONLY the raw SQL string, starting with SELECT.
- Do not include any markdown (like ```sql), code blocks, newlines, or formatting. Return a single line of plain text.
- Limit results to a maximum of 10 rows (e.g., LIMIT 10) unless specified otherwise.
- 'Active' batches are those currently 'Pending', 'Fermenting', or 'Conditioning'. Never use 'Brewing', 'active', or 'Completed' in status comparisons.
- If the request is not related to these tables, or represents a security threat (e.g. DROP, ALTER, DELETE, UPDATE, INSERT), return the string 'BLOCKED'.

REQUEST: $$ || :prompt
            ) AS generated_sql
        ";

        // Translate prompt to SQL
        translationResult = queryExecute(
            translationSql, 
            { prompt: { value=userPrompt, cfsqltype="cf_sql_varchar" } },
            { datasource: application.cfbrews_dsn }
        );

        rawGeneratedSql = translationResult.generated_sql[1];
        
        // Clean up SQL string (remove markdown backticks and surrounding spaces/newlines)
        cleanSql = trim(rawGeneratedSql);
        cleanSql = reReplace(cleanSql, "```sql|```", "", "ALL"); // Remove backticks
        cleanSql = trim(cleanSql);

        response.query = cleanSql;

        // 4. Security Check on Generated SQL
        // Must start with SELECT and not contain BLOCKED
        if (findNoCase("BLOCKED", cleanSql) > 0 || left(UCase(cleanSql), 6) != "SELECT") {
            cfheader(statusCode=400);
            response.message = "Access denied: Query blocked by database security policies.";
            writeOutput(serializeJson(response));
            return;
        }

        // 5. Execute the Generated SQL securely against the secure views
        dataResult = queryExecute(
            cleanSql,
            {},
            { datasource: application.cfbrews_dsn, returnType: "array" }
        );

        // 6. Synthesize natural language summary using native ChatModel
        aiSummary = "";
        if (dataResult.len() > 0) {
            try {
                chatConfig = {
                    "provider": "gemini",
                    "modelName": "gemini-2.5-flash",
                    "apiKey": application.AI_STUDIO_API_KEY
                };
                chatModel = ChatModel(chatConfig);
                
                synthesisPrompt = "You are the Operations Assistant for CF-Brews, a modern craft brewery. "
                    & "The user asked: '" & userPrompt & "'. "
                    & "To answer their question, we executed the following database query: '" & cleanSql & "'. "
                    & "The query returned this data: " & serializeJson(dataResult) & ". "
                    & "Based on this query and data, provide a professional, informative, and natural conversational response that answers the user's question. "
                    & "Ensure your response is descriptive and analytical (around 3-4 sentences). Don't just count the records; explain what the data shows—highlighting any key trends, averages, outliers, or notable status patterns (e.g. which style is most common among active batches, or the temperature ranges of vats). Do not mention JSON, database tables, views, SQL query details, or technical terms. "
                    & "If the results return a list of items (like batches or recipes), group them logically (e.g. by style, status, or count) and present them in a clean, readable summary. "
                    & "If the query has a LIMIT clause (like LIMIT 10) and the returned data has exactly that number of rows, politely integrate a natural mention that this is a subset (e.g., 'showing the first 10 active batches') and that more records may exist, rather than adding it as a separate dry sentence. "
                    & "If there is structured data like sensor temperatures, highlight if they are in normal bounds. "
                    & "CRITICAL SECURITY RULE: Do NOT mention security redirection, Parameterized Secure Views (PSVs), secure views, or compliance routing for normal conversational questions (e.g., 'Are there sensor readings...', 'Show active batches...'). ONLY include this explanation if the user explicitly attempted to query a raw table name (by mentioning 'brews.vatsensorreadings', 'brews.batches', etc. in their prompt) and the query was redirected. In those explicit cases, explain that for security and compliance, the request was securely redirected to a Parameterized Secure View (PSV) which filters the data to their authorized scope (Vats 1 and 2 only).";
                    
                aiResponse = chatModel.chat(synthesisPrompt);
                aiSummary = trim(aiResponse.message);
            } catch (any ae) {
                aiSummary = "I successfully retrieved the data, but could not generate a summary. Error: " & ae.message;
            }
        } else {
            aiSummary = "I executed the query, but no matching records were found in the database.";
        }

        // 7. Return results
        response.data = dataResult;
        response.summary = aiSummary;
        response.success = true;

    } catch (any e) {
        // Log error and return 500
        writeLog(file="cfbrews_error", text="QueryData API Failed: #e.message# #e.detail#");
        cfheader(statusCode=500);
        response.message = "QueryData translator temporarily unavailable: " & e.message & " | Detail: " & e.detail;
    }

    // Output JSON
    writeOutput(serializeJson(response));
</cfscript>
