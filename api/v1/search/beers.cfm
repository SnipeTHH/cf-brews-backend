<cfscript>
/**
 * ========================================================================
 * API ENDPOINT (CONTROLLER)
 * ========================================================================
 *
 * PURPOSE:     Hybrid Search Controller. Orchestrates AI-driven flavor matching and keyword relevance.
 *
 * HTTP METHOD: GET
 *
 * CALLS:       AlloyDB AI (google_ml.embedding calls Gemini Enterprise)
 * 
 * USED BY:     Google Cloud Conversational Agents & React Search UI (BrewerySearch.jsx)
 *
 * BODY (JSON): None
 *
 * ========================================================================
 */
    
    // 1. Sanitize the search query (e.g., "crisp tropical summer ale")
    search_term = url.q ?: "";
    
    if (len(search_term) >= 3) {
        try {
            // 2. Execute Hybrid Search using the 'google_ml' schema
            // We use the 'text-gecko' alias and explicit casting to match your DB version
            results = queryExecute("
                SELECT 
                    recipe_id, recipe_name, style, description,
                    -- A: Vector Distance (Semantics)
                    -- Finds beers that 'feel' like the search term
                    (recipe_embeddings <=> google_ml.embedding('text-gecko'::TEXT, :term::TEXT)::vector) as flavor_score,
                    
                    -- B: Text Ranking (Keywords)
                    -- Finds beers that explicitly mention the search term
                    ts_rank(to_tsvector('english', COALESCE(recipe_name, '') || ' ' || COALESCE(description, '')), plainto_tsquery('english', :term)) as text_rank
                FROM brews.recipes
                WHERE recipe_embeddings IS NOT NULL
                -- Order by the best flavor match first, then by keyword relevance
                ORDER BY flavor_score ASC, text_rank DESC
                LIMIT 6
            ", 
            { term: { value=search_term, cfsqltype="cf_sql_varchar" } }, 
            { datasource: application.cfbrews_dsn, returnType: "array" });

            // 3. Optional: Generate AI summary if results are found using ChatModel()
            summary = "";
            useNativeAI = false;
            try {
                if (structKeyExists(variables, "ChatModel") || (structKeyExists(server, "coldfusion") && val(listFirst(server.coldfusion.productversion)) >= 2025)) {
                    useNativeAI = true;
                }
            } catch (any e) {}

            if (useNativeAI && results.len() > 0) {
                try {
                    apiKey = application.AI_STUDIO_API_KEY;
                    chatConfig = {
                        "provider": "gemini",
                        "modelName": "gemini-2.5-flash",
                        "apiKey": trim(apiKey),
                        "temperature": 0.5,
                        "timeout": 20,
                        "maxRetries": 1
                    };
                    chatModel = ChatModel(chatConfig);
                    
                    systemPrompt = "You are an expert sommelier and master brewer at CF-Brews. "
                        & "A user is searching the brewery catalog for flavors. We have performed a semantic and keyword search for the term: '" & search_term & "'. "
                        & "Analyze the matching recipes returned, and write a concise, engaging summary (maximum 3 sentences) explaining how these beers fit their search request and recommending the best starting point. "
                        & "Be warm, helpful, and specific. Return only the plain-text message without formatting or quotes.";
                    
                    // Format the matching results for the LLM
                    simplifiedResults = [];
                    for (item in results) {
                        simplifiedResults.append({
                            "name": item.recipe_name,
                            "style": item.style,
                            "description": item.description
                        });
                    }
                    
                    userPrompt = "Search Query: " & search_term & "\nMatching Recipes: " & serializeJson(simplifiedResults);
                    
                    aiResponse = chatModel.chat(systemPrompt & "\n\n" & userPrompt);
                    summary = trim(aiResponse.message);
                } catch (any aiError) {
                    writeLog(file="cfbrews_error", text="Search AI Summary Generation Failed: " & aiError.message);
                }
            }

            // 4. Return results as JSON for the React frontend
            writeOutput(serializeJson({
                "success": true,
                "data": results,
                "count": results.len(),
                "summary": summary
            }));

        } catch (any e) {
            writeLog(file="cfbrews_error", text="AI Search Failed: #e.message#");
            writeOutput(serializeJson({ "success": false, "error": "Search unavailable" }));
        }
    } else {
        writeOutput(serializeJson({ "success": false, "error": "Search term too short" }));
    }
</cfscript>