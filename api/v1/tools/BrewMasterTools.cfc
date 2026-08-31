component {

    /**
     * @name checkInventory
     * @description Determines if there are enough ingredients in stock to brew a specific volume of a recipe.
     * @tool
     */
    public struct function checkInventory(required string recipeName, numeric volumeGallons = 1) {
        var response = {
            "can_brew": false,
            "recipe_found": false,
            "missing_ingredients": []
        };

        // JOIN Recipes -> RecipeIngredients -> Inventory
        var sql = "
            SELECT
                r.recipe_name,
                i.name AS item_name,
                (ri.amount_per_gallon * :volume) AS required_amount,
                i.quantity_on_hand AS current_stock,
                i.unit
            FROM Recipes r
            INNER JOIN RecipeIngredients ri ON r.recipe_id = ri.recipe_id
            INNER JOIN Inventory i ON ri.inventory_item_id = i.item_id
            WHERE LOWER(r.recipe_name) = LOWER(:recipe)
        ";

        var ingredients = queryExecute(sql, {
            recipe = { value = arguments.recipeName, cfsqltype = "cf_sql_varchar" },
            volume = { value = arguments.volumeGallons, cfsqltype = "cf_sql_numeric" }
        });

        if ( ingredients.recordCount == 0 ) {
             response.message = "Recipe '#arguments.recipeName#' not found or has no ingredients listed.";
             return response;
        }

        response.recipe_found = true;
        var canBrew = true;
        var missingList = [];

        for ( var row in ingredients ) {
            if ( row.current_stock < row.required_amount ) {
                canBrew = false;
                arrayAppend(missingList, {
                    "item": row.item_name,
                    "required": row.required_amount,
                    "in_stock": row.current_stock,
                    "missing_amount": row.required_amount - row.current_stock,
                    "unit": row.unit
                });
            }
        }

        response.can_brew = canBrew;
        response.missing_ingredients = missingList;
        response.message = canBrew ? "Yes, you have enough ingredients." : "No, insufficient inventory.";
        
        return response;
    }

    /**
     * @name getRecipeDetails
     * @description Retrieves the specific ingredients and targets (ABV, ideal temperatures) for a single named recipe.
     * @tool
     */
    public struct function getRecipeDetails(required string recipeName) {
        var response = { "found": false, "recipe": {} };

        var sql = "
            SELECT r.recipe_name, r.style, r.target_abv, r.ideal_min_temp, r.ideal_max_temp,
                jsonb_agg(jsonb_build_object('item', i.name, 'amount', ri.amount_per_gallon, 'unit', i.unit)) AS ingredients
            FROM Recipes r
            JOIN RecipeIngredients ri ON r.recipe_id = ri.recipe_id
            JOIN Inventory i ON ri.inventory_item_id = i.item_id
            WHERE LOWER(r.recipe_name) = LOWER(:name)
            GROUP BY r.recipe_id
        ";
        
        var data = queryExecute(sql, {name={value=arguments.recipeName, cfsqltype="cf_sql_varchar"}}, {returnType:"array"});

        if (arrayLen(data) > 0) {
            response.found = true;
            if (isJSON(data[1].ingredients) && !isArray(data[1].ingredients)) {
                 data[1].ingredients = deserializeJSON(data[1].ingredients);
            }
            response.recipe = data[1];
        } else {
            response.message = "Recipe not found.";
        }
        
        return response;
    }

    /**
     * @name checkBatchRisk
     * @description Checks all currently fermenting batches against their recipe targets to detect temperature or pressure deviations.
     * @tool
     */
    public struct function checkBatchRisk(string style = "") {
        var response = {
            "active_batches_checked": 0,
            "at_risk_count": 0,
            "at_risk_batches": []
        };

        var sql = "
            SELECT
                b.batch_id,
                r.recipe_name,
                r.style,
                r.ideal_min_temp,
                r.ideal_max_temp,
                lr.temp AS current_temp,
                lr.pressure AS current_pressure
            FROM
                Batches b
            INNER JOIN
                Recipes r ON b.recipe_id = r.recipe_id
            LEFT JOIN LATERAL (
                SELECT temp, pressure
                FROM VatSensorReadings vsr
                WHERE vsr.batch_id = b.batch_id
                ORDER BY reading_time DESC
                LIMIT 1
            ) lr ON TRUE
            WHERE
                b.status = 'Fermenting'
        ";

        var params = {};
        if ( len(arguments.style) ) {
            sql &= " AND LOWER(r.style) LIKE LOWER(:style) ";
            params.style = { value = "%#arguments.style#%", cfsqltype = "cf_sql_varchar" };
        }

        var activeBatches = queryExecute(sql, params);
        response.active_batches_checked = activeBatches.recordCount;

        var atRiskList = [];
        for ( var row in activeBatches ) {
            var risks = [];
            if ( isNumeric(row.current_temp) ) {
                if ( row.current_temp < row.ideal_min_temp ) arrayAppend(risks, "Temp TOO LOW (#row.current_temp#°F). Min ideal: #row.ideal_min_temp#°F.");
                else if ( row.current_temp > row.ideal_max_temp ) arrayAppend(risks, "Temp TOO HIGH (#row.current_temp#°F). Max ideal: #row.ideal_max_temp#°F.");
            }
            if ( isNumeric(row.current_pressure) && row.current_pressure > 15.0 ) {
                arrayAppend(risks, "CRITICAL: Pressure HIGH (#row.current_pressure# PSI). Check release valve.");
            }

            if ( arrayLen(risks) > 0 ) {
                arrayAppend(atRiskList, {
                    "batch_id": row.batch_id,
                    "recipe": row.recipe_name,
                    "style": row.style,
                    "reasons": arrayToList(risks, " | ")
                });
            }
        }

        response.at_risk_batches = atRiskList;
        response.at_risk_count = arrayLen(atRiskList);
        
        return response;
    }

}
