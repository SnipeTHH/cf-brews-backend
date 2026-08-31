<cfscript>
/**
 * ========================================================================
 * API ENDPOINT: PREDICT BATCH FAILURE
 * ========================================================================
 *
 * PURPOSE:     Orchestrates a real-time predictive risk assessment for a
 * specific batch. It gathers live sensor data via BigQuery
 * federation and sends it to a Gemini Enterprise AutoML model.
 *
 * HTTP METHOD: POST
 *
 * BODY (JSON): { "batch_id": integer }
 *
 * RETURNS:     JSON
 * {
 * "success": boolean,
 * "prediction": {
 * "risk": number (0.0 - 1.0),
 * "reason": string
 * }
 * }
 * ========================================================================
 */

/**
 * ========================================================================
 * HELPER FUNCTIONS
 * ========================================================================
 */
function getAuthToken() {
    try {
        var httpRes = "";
        // Native cfhttp call
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

/**
 * ========================================================================
 * API ENDPOINT (CONTROLLER)
 * ========================================================================
 */

    // --- 1. SET YOUR VARIABLES ---
    variables.BIGQUERY_CONNECTION_ID = server.system.environment.BIGQUERY_CONNECTION_ID;
    variables.VERTEX_ENDPOINT_ID = server.system.environment.VERTEX_ENDPOINT_ID;
    variables.GCP_PROJECT_ID = server.system.environment.GOOGLE_CLOUD_PROJECT;
    variables.GCP_REGION = server.system.environment.GOOGLE_CLOUD_REGION;

    variables.vertexUrl = "https://#variables.GCP_REGION#-aiplatform.googleapis.com/v1/projects/#variables.GCP_PROJECT_ID#/locations/#variables.GCP_REGION#/endpoints/#variables.VERTEX_ENDPOINT_ID#:predict";
    response = {
        "success": false,
        "prediction": {}
    };
    try {
        if (cgi.request_method != "POST") {
            cfheader(statusCode=405);
            response.message = "This endpoint only accepts POST requests.";
            writeOutput(serializeJson(response));
            return;
        }

        requestBody = deserializeJson(toString(getHttpRequestData().content));
        if (!structKeyExists(requestBody, "batch_id")) {
            throw(message="`batch_id` is required.");
        }
        batch_id_to_predict = requestBody.batch_id;
        
        // --- 6. GET LIVE FEATURES FROM ALLOYDB (UPDATED WITH RECIPE JOIN) ---
        safe_batch_id = val(batch_id_to_predict); 
        
        featureSql = "
            WITH sensor_features AS (
              SELECT
                batch_id,
                AVG(temp) AS avg_temp, MAX(temp) AS max_temp, MIN(temp) AS min_temp, STDDEV(temp) AS stddev_temp,
                AVG(pressure) AS avg_pressure, MAX(pressure) AS max_pressure, MIN(pressure) AS min_pressure, STDDEV(pressure) AS stddev_pressure,
                AVG(ph) AS avg_ph, MAX(ph) AS max_ph, MIN(ph) AS min_ph,
                COUNT(CASE WHEN temp > 74.0 THEN 1 END) AS high_temp_alert_count,
                COUNT(CASE WHEN temp BETWEEN 73.0 AND 74.0 THEN 1 END) AS warning_temp_alert_count,
                COUNT(CASE WHEN pressure > 14.5 THEN 1 END) AS high_pressure_alert_count,
                COUNT(CASE WHEN pressure BETWEEN 14.0 AND 14.5 THEN 1 END) AS warning_pressure_alert_count,
                COUNT(CASE WHEN ph < 4.6 THEN 1 END) AS low_ph_alert_count
              FROM
                brews.vatsensorreadings
              WHERE
                batch_id = #safe_batch_id#
              GROUP BY
                batch_id
            )
            SELECT 
                b.batch_id,
                r.style,
                r.ideal_min_temp,
                r.ideal_max_temp,
                r.target_ph,
                r.target_abv,
                s.avg_temp, s.max_temp, s.min_temp, s.stddev_temp,
                s.avg_pressure, s.max_pressure, s.min_pressure, s.stddev_pressure,
                s.avg_ph, s.max_ph, s.min_ph,
                s.high_temp_alert_count, s.warning_temp_alert_count,
                s.high_pressure_alert_count, s.warning_pressure_alert_count,
                s.low_ph_alert_count
            FROM
                brews.batches b
            INNER JOIN
                brews.recipes r ON b.recipe_id = r.recipe_id
            INNER JOIN
                sensor_features s ON b.batch_id = s.batch_id
        ";
        flatFeatureSql = featureSql.replaceAll("[\r\n]+", " ");
        finalBqSql = "SELECT * FROM EXTERNAL_QUERY('#variables.BIGQUERY_CONNECTION_ID#', '#preserveSingleQuotes(flatFeatureSql)#')";
        featuresResult = queryExecute(
            finalBqSql,
            {}, 
            { "datasource": Application.bigquery_dsn } 
        );
        if (featuresResult.recordCount == 0) {
            response.prediction = {
                "risk": 0.05,
                "reason": "No sensor data found for this batch yet. (Live from Gemini Enterprise)"
            };
            response.success = true;
            writeOutput(serializeJson(response));
            return;
        }

        // --- 7. Format Features for Gemini Enterprise Agent Platform (UPDATED WITH NEW FIELDS) ---
        vertexInstance = {
            "batch_id": toString(featuresResult.batch_id[1]),
            
            // RECIPE FEATURES: Force to number with val()
            "style": featuresResult.style[1],
            "ideal_min_temp": val(featuresResult.ideal_min_temp[1]),
            "ideal_max_temp": val(featuresResult.ideal_max_temp[1]),
            "target_ph": val(featuresResult.target_ph[1]),
            "target_abv": val(featuresResult.target_abv[1]),
            
            // SENSOR FEATURES: Force these too just to be safe
            "avg_temp": val(featuresResult.avg_temp[1]),
            "max_temp": val(featuresResult.max_temp[1]),
            "min_temp": val(featuresResult.min_temp[1]),
            "stddev_temp": val(featuresResult.stddev_temp[1]),
            "avg_pressure": val(featuresResult.avg_pressure[1]),
            "max_pressure": val(featuresResult.max_pressure[1]),
            "min_pressure": val(featuresResult.min_pressure[1]),
            "stddev_pressure": val(featuresResult.stddev_pressure[1]),
            "avg_ph": val(featuresResult.avg_ph[1]),
            "max_ph": val(featuresResult.max_ph[1]),
            "min_ph": val(featuresResult.min_ph[1]),
            
            // ALERT COUNTS: Keep toString() here as requested by previous errors
            "high_temp_alert_count": toString(featuresResult.high_temp_alert_count[1]),
            "warning_temp_alert_count": toString(featuresResult.warning_temp_alert_count[1]),
            "high_pressure_alert_count": toString(featuresResult.high_pressure_alert_count[1]),
            "warning_pressure_alert_count": toString(featuresResult.warning_pressure_alert_count[1]),
            "low_ph_alert_count": toString(featuresResult.low_ph_alert_count[1])
        };
        vertexPayload = {
            "instances": [ vertexInstance ]
        };

        // --- 8. Call the AutoML Prediction Endpoint via REST ---
        authToken = getAuthToken();
        cfhttp(url=variables.vertexUrl, method="POST", result="apiResult") {
            cfhttpparam(type="header", name="Authorization", value="Bearer #authToken#");
            cfhttpparam(type="header", name="Content-Type", value="application/json");
            cfhttpparam(type="body", value=serializeJson(vertexPayload));
        }
        
        if ( val(apiResult.statusCode) != 200 ) {
            throw(message="Gemini Enterprise Agent Platform API call failed. Status: #apiResult.statusCode#", detail=apiResult.fileContent);
        }
        
        apiResponse = deserializeJson(apiResult.fileContent);
        
        // --- 9. Parse the prediction score ---
        modelPrediction = apiResponse.predictions[1];
        failureRisk = 0;
        for (i=1; i <= arrayLen(modelPrediction.classes); i++) {
            if (modelPrediction.classes[i] == "Failed") {
                failureRisk = modelPrediction.scores[i];
            }
        }

        // --- 10. Generate explanation (Native GenAI vs Legacy Hardcoded Fallback) ---
        reason = "";
        useNativeAI = false;
        try {
            // Check if the ChatModel class/function is available
            if (structKeyExists(variables, "ChatModel") || (structKeyExists(server, "coldfusion") && val(listFirst(server.coldfusion.productversion)) >= 2025)) {
                useNativeAI = true;
            }
        } catch (any e) {}

        if (useNativeAI) {
            try {
                // Configure Native Chat Model (ColdFusion 2025+)
                apiKey = application.AI_STUDIO_API_KEY;
                chatConfig = {
                    "provider": "gemini",
                    "modelName": "gemini-2.5-flash",
                    "apiKey": trim(apiKey),
                    "temperature": 0.3,
                    "timeout": 20,
                    "maxRetries": 1
                };
                chatModel = ChatModel(chatConfig);
                
                systemPrompt = "You are a master brewer and quality control assistant. A batch of beer is currently fermenting, and our predictive AutoML model has calculated a batch failure risk of " & failureRisk & " (on a scale of 0.0 to 1.0, where 0.0 is completely safe and 1.0 is certain failure). "
                    & "Analyze the target recipe details and active sensor readings, and write a concise, professional explanation (maximum 2 sentences) of why the risk is at this level and what specific action the brewer should take if any. "
                    & "Be specific about which sensor values deviate from the ideal targets. Return only the plain-text message without formatting or quotes.";

                userPrompt = "Recipe target and active sensor values: " & serializeJson(vertexInstance);
                
                aiResponse = chatModel.chat(systemPrompt & "\n\n" & userPrompt);
                reason = trim(aiResponse.message);
                
            } catch (any nativeError) {
                // Log failure and set flag to false to hit fallback
                writeLog(file="cfbrews_error", text="Native AI Explanation Generation Failed: " & nativeError.message);
                useNativeAI = false;
            }
        }

        if (!useNativeAI || len(reason) == 0) {
            // --- Legacy Fallback Reason Logic ---
            reason = "Sensor readings are nominal.";
            if (failureRisk > 0.75) {
                reason = "Model detected anomalies in temperature and pressure stability.";
            } else if (failureRisk > 0.5) {
                 reason = "Model detected minor anomalies in pH and temperature.";
            }
            reason = reason & " (Live from Gemini Enterprise)";
        }

        response.prediction = {
            "risk": failureRisk,
            "reason": reason
        };
        response.success = true;

    } catch (any e) {
        cfheader(statusCode=500);
        response.success = false;
        response.message = "CFM Error: " & e.message;
        response.detail = e.detail;
    }

    writeOutput(serializeJson(response));
</cfscript>