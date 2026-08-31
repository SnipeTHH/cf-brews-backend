<cfscript>
/**
 * ========================================================================
 * API ENDPOINT (CONTROLLER)
 * ========================================================================
 *
 * PURPOSE:     Transactionally creates a new batch record and assigns it
 * to the first available Vat.
 *
 * HTTP METHOD: POST
 *
 * BODY (JSON): { "recipe_id": integer }
 *
 * CALLS:       None (Direct Database Transaction)
 *
 * RETURNS:     JSON
 * {
 * "success": boolean,
 * "batch_id": integer (on success),
 * "vat_id": integer (on success),
 * "message": string,
 * "error": string (on failure)
 * }
 *
 * ========================================================================
 */
    response = { "success": false };

    try {
        if (cgi.request_method != "POST") throw(type="MethodNotAllowed", message="Only POST accepted");
        
        requestBody = deserializeJson(toString(getHttpRequestData().content));
        if (!structKeyExists(requestBody, "recipe_id")) throw("Missing recipe_id");

        recipeId = val(requestBody.recipe_id);

        // --- BEGIN TRANSACTION ---
        transaction action="begin" {
            try {
                // 1. Find the first available Vat
                // We use a simple lock here to prevent race conditions in a high-concurrency demo
                findVat = queryExecute(
                    "SELECT vat_id FROM Vats WHERE current_batch_id IS NULL ORDER BY vat_id ASC LIMIT 1 FOR UPDATE"
                );

                if (findVat.recordCount == 0) {
                    throw(type="CapacityError", message="No Vats are currently free. Please wait for a batch to complete.");
                }
                vatIdToAssign = findVat.vat_id;

                // 2. Insert the new Batch and get its generated ID immediately
                // AlloyDB/Postgres supports 'RETURNING' to do this in one efficient shot
                insertBatch = queryExecute(
                    "INSERT INTO Batches (recipe_id, status) VALUES (:rid, 'Fermenting') RETURNING batch_id",
                    { rid = {value=recipeId, cfsqltype="cf_sql_integer"} }
                );
                newBatchId = insertBatch.batch_id;

                // 3. Assign the new Batch to the reserved Vat
                queryExecute(
                    "UPDATE Vats SET current_batch_id = :bid WHERE vat_id = :vid",
                    { 
                        bid = {value=newBatchId, cfsqltype="cf_sql_integer"},
                        vid = {value=vatIdToAssign, cfsqltype="cf_sql_integer"}
                    }
                );

                transaction action="commit";
                response.success = true;
                response.batch_id = newBatchId;
                response.vat_id = vatIdToAssign;
                response.message = "Batch #newBatchId# successfully started in Vat #vatIdToAssign#.";

            } catch (any e) {
                transaction action="rollback";
                // Re-throw to be caught by main error handler
                throw(object=e);
            }
        }
        // --- END TRANSACTION ---

    } catch (any e) {
        // If it was our custom capacity error, send 409 Conflict, otherwise 500
        if (structKeyExists(e, "type") && e.type == "CapacityError") {
             cfheader(statusCode=409);
        } else {
             cfheader(statusCode=500);
        }
        response.error = e.message;
    }

    writeOutput(serializeJson(response));
</cfscript>