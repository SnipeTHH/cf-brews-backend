<cfscript>
/**
 * ========================================================================
 * AI AGENT TOOL: BATCH RISK CHECKER
 * ========================================================================
 *
 * PURPOSE:     Used by Gemini Enterprise Agents to assess if active batches are
 * deviating from their recipe's ideal parameters.
 *
 * INPUTS (URL):
 * - style (string, optional): Filter by beer style (e.g., 'Lager')
 *
 * ========================================================================
 */

    response = {
        "active_batches_checked": 0,
        "at_risk_count": 0,
        "at_risk_batches": []
    };
 
    try {
        beerStyle = (structKeyExists(url, "style")) ? trim(url.style) : "";
 
        tools = new BrewMasterTools();
        response = tools.checkBatchRisk(beerStyle);
 
    } catch (any e) {
        cfheader(statusCode=500);
        response.error = e.message;
    }
 
    writeOutput(serializeJson(response));
</cfscript>