<cfscript>
/**
 * ========================================================================
 * API ENDPOINT (CONTROLLER)
 * ========================================================================
 *
 * PURPOSE:     Graph Recommendations Controller. Orchestrates multi-hop
 *              peer suggestions from the BigQuery GQL Property Graph.
 *
 * HTTP METHOD: GET
 *
 * CALLS:       BigQuery Graph (GQL PROPERTY GRAPH)
 * 
 * USED BY:     React Customer 360 Graph UI
 *
 * BODY (JSON): None
 *
 * ========================================================================
 */
    
    // 1. Sanitize customer name input to prevent SQL injection (alphanumeric & spaces only)
    customer_name = url.name ?: "Ian";
    safe_name = REReplace(customer_name, "[^a-zA-Z0-9 ]", "", "ALL");

    try {
        // 2. Query BigQuery Property Graph.
        // Note: We reference the graph as `cf_brews_dataset.customer_360_graph` (omitting the project ID)
        // because the Simba JDBC connection is already anchored to the default project, and GQL parses 
        // dataset-relative references more reliably in JDBC contexts.
        results = queryExecute("
            SELECT *
            FROM GRAPH_TABLE(
              `cf_brews_dataset.customer_360_graph`
              MATCH 
                (me:Customer)-[:FRIEND_OF]-(friend:Customer)-[buy:BUY]->(rec_beer:Beer)
              WHERE me.customer_name = '#safe_name#'
                AND NOT EXISTS { 
                  MATCH (m2:Customer)-[:BUY]->(rb2:Beer)
                  WHERE m2.customer_id = me.customer_id 
                    AND rb2.beer_id = rec_beer.beer_id
                }
              COLUMNS (
                friend.customer_name AS friend_name,
                rec_beer.beer_name AS beer_name,
                rec_beer.style AS beer_style
              )
            )
            LIMIT 6
        ",
        {},
        { datasource: Application.bigquery_dsn, returnType: "array", cachedWithin: createTimespan(0, 1, 0, 0) });

        // 3. Generate an AI Profile Summary using native ChatModel
        aiSummary = "";
        if (results.len() > 0) {
            try {
                chatConfig = {
                    "provider": "gemini",
                    "modelName": "gemini-2.5-flash",
                    "apiKey": Application.AI_STUDIO_API_KEY
                };
                chatModel = ChatModel(chatConfig);
                
                synthesisPrompt = "You are the Brewery Customer Relations Assistant. Analyze this graph database recommendation output for the active customer '" & safe_name & "': " 
                    & serializeJson(results) 
                    & ". Write a concise, 2-sentence marketing profile and suggestion for taproom staff on how to engage this customer based on their friends' favorite beers. Do not refer to JSON structures, be natural.";
                    
                aiResponse = chatModel.chat(synthesisPrompt);
                aiSummary = trim(aiResponse.message);
            } catch (any ae) {
                aiSummary = "Profile summary offline: " & ae.message;
            }
        } else {
            aiSummary = "No active recommendations to summarize.";
        }

        writeOutput(serializeJson({
            "success": true,
            "data": results,
            "summary": aiSummary,
            "count": results.len()
        }));

    } catch (any e) {
        writeLog(file="cfbrews_error", text="Graph Query Failed: #e.message#");
        cfheader(statusCode=500);
        writeOutput(serializeJson({ "success": false, "error": "Graph analytics unavailable: " & e.message }));
    }
</cfscript>
