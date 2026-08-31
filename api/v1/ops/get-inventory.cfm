<cfscript>
/**
 * ========================================================================
 * API ENDPOINT: GET INVENTORY
 * ========================================================================
 *
 * PURPOSE: Returns current inventory levels.
 *
 * DEMO NOTE: Includes a simple calculated 'status' field to simulate
 * business logic living in the database layer.
 *
 * ========================================================================
 */

    response = {
        "success": false,
        "inventory": []
    };

    try {
        if (cgi.request_method != "GET") {
            throw(type="MethodNotAllowed", message="Only GET requests accepted");
        }

        // Simple query with a CASE statement for status
        sql = "
            SELECT
                item_id,
                name,
                type,
                quantity_on_hand,
                unit,
                CASE
                    WHEN quantity_on_hand < 50 THEN 'Low'
                    ELSE 'Stocked'
                END AS status
            FROM
                Inventory
            ORDER BY
                type ASC, name ASC
        ";

        inventoryQuery = queryExecute(sql, {}, { returnType: "array" });

        response.inventory = inventoryQuery;
        response.success = true;

    } catch (any e) {
        cfheader(statusCode=500);
        response.error = e.message;
        response.detail = e.detail;
    }

    writeOutput(serializeJson(response));
</cfscript>