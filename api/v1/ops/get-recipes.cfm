<cfscript>
/**
 * ========================================================================
 * API ENDPOINT: GET ALL RECIPES (WITH NESTED INGREDIENTS)
 * ========================================================================
 *
 * DEMO NOTE: Uses AlloyDB's native JSON aggregation functions (jsonb_agg)
 * to return a complex, nested data structure in a single DB round-trip,
 * completely avoiding the "N+1 select" problem.
 *
 * ========================================================================
 */
    response = { "success": false, "recipes": [] };

    try {
        if (cgi.request_method != "GET") throw(type="MethodNotAllowed", message="Only GET requests accepted");

        // The Magic Query: Groups ingredients into a JSON array per recipe row
        sql = "
            SELECT
                r.recipe_id,
                r.recipe_name,
                r.style,
                r.ideal_min_temp,
                r.ideal_max_temp,
                r.target_ph,
                r.target_abv,
                COALESCE(
                    jsonb_agg(
                        jsonb_build_object(
                            'item', i.name,
                            'amount', ri.amount_per_gallon,
                            'unit', i.unit
                        ) ORDER BY ri.amount_per_gallon DESC
                    ) FILTER (WHERE i.name IS NOT NULL),
                    '[]'::jsonb
                ) AS ingredients
            FROM
                Recipes r
            LEFT JOIN
                RecipeIngredients ri ON r.recipe_id = ri.recipe_id
            LEFT JOIN
                Inventory i ON ri.inventory_item_id = i.item_id
            GROUP BY
                r.recipe_id
            ORDER BY
                r.recipe_name ASC
        ";

        // We use a raw SQL execution here because standard CF might try to
        // incorrectly parse the complex JSON columns if we aren't careful.
        // Returning as an array of structs is safest.
        recipesData = queryExecute(sql, {}, {returnType:"array"});

        // Tiny fix: some CF engines return the JSON stringified from Postgres,
        // so we might need to deserialize that specific column if it looks like a string.
        for (row in recipesData) {
             if (isJSON(row.ingredients) && !isArray(row.ingredients)) {
                 row.ingredients = deserializeJSON(row.ingredients);
             }
        }

        response.recipes = recipesData;
        response.success = true;

    } catch (any e) {
        cfheader(statusCode=500);
        response.error = e.message;
        response.detail = e.detail;
    }

    writeOutput(serializeJson(response));
</cfscript>