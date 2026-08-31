/**
 * DataGenerator.cfc
 *
 * This component handles all logic for creating mock data.
 * It's called by the datagenerator.cfm controller.
 */
component {
    /**
     * Generates a specified number of sensor readings dynamically mapped
     * to existing batches and vats to maintain foreign key integrity.
     */
    public struct function generate(struct params = {}) {
        
        var response = {
            "success": false,
            "rowsInserted": 0,
            "duration_sec": 0
        };

        // --- 1. Set defaults ---
        var numRows = params.numRows ?? 10000;

        // --- 2. Dynamically fetch existing active Batch and Vat IDs ---
        var qBatches = queryExecute("SELECT batch_id FROM Batches");
        var qVats = queryExecute("SELECT vat_id FROM Vats");

        var batchIds = [];
        for (var row in qBatches) {
            arrayAppend(batchIds, row.batch_id);
        }

        var vatIds = [];
        for (var row in qVats) {
            arrayAppend(vatIds, row.vat_id);
        }

        // Fallbacks to create default Batch / Vat if tables are empty
        if (arrayLen(batchIds) == 0) {
            var bInsert = queryExecute("INSERT INTO Batches (recipe_id, status, start_time) VALUES (1, 'Fermenting', CURRENT_TIMESTAMP) RETURNING batch_id");
            arrayAppend(batchIds, bInsert.batch_id[1]);
        }
        if (arrayLen(vatIds) == 0) {
            var vInsert = queryExecute(
                "INSERT INTO Vats (name, location, capacity_gallons, current_batch_id) VALUES ('Vat Alpha', 'Fermentation Line 1', 500, :batchId) RETURNING vat_id",
                { batchId: { value: batchIds[1], cfsqltype: "cf_sql_integer" } }
            );
            arrayAppend(vatIds, vInsert.vat_id[1]);
        }

        var transactionStartTime = now();
        var loopStartTime = now();
        
        // Use a transaction to ensure all records are created atomically
        transaction {

            var sensorSqlTemplate = "INSERT INTO VatSensorReadings (batch_id, vat_id, reading_time, temp, pressure, ph) VALUES ";
            var sensorSqlTemplate_Row = "INSERT INTO VatSensorReadings_Row (batch_id, vat_id, reading_time, temp, pressure, ph) VALUES ";

            // Define batching settings
            var batchSize = 1000; // Insert 1,000 rows at a time
            var valueClauses = []; // Holds the "(...),(...),(...)" string parts
            var allParams = {};    // Holds all parameters for the batch

            for (var i = 1; i <= numRows; i++) {
                
                // Pick a random batch and vat ID from existing ones
                var batchId = batchIds[randRange(1, arrayLen(batchIds))];
                var vatId = vatIds[randRange(1, arrayLen(vatIds))];

                var temp = Round((65 + (Rand() * 10)) * 100) / 100;
                var pressure = Round((10 + (Rand() * 5)) * 100) / 100;
                var ph = Round((4.5 + Rand()) * 100) / 100;
                var readingTime = dateAdd("s", i * 10, transactionStartTime); 

                // Create a unique parameter name for this row in this batch
                var batchCounter = (i - 1) % batchSize + 1;
                
                var p_bid   = "b" & batchCounter;
                var p_vid   = "v" & batchCounter;
                var p_rtime = "r" & batchCounter;
                var p_temp  = "t" & batchCounter;
                var p_press = "p" & batchCounter;
                var p_ph    = "h" & batchCounter;

                // Add the VALUES placeholder string for this row
                arrayAppend(valueClauses, 
                    "(:#p_bid#, :#p_vid#, :#p_rtime#, :#p_temp#, :#p_press#, :#p_ph#)"
                );

                // Add the actual data to the flat param struct
                allParams[p_bid]   = { value: batchId, cfsqltype: "cf_sql_integer" };
                allParams[p_vid]   = { value: vatId, cfsqltype: "cf_sql_integer" };
                allParams[p_rtime] = { value: readingTime, cfsqltype: "cf_sql_timestamp" };
                allParams[p_temp]  = { value: temp, cfsqltype: "cf_sql_decimal" };
                allParams[p_press] = { value: pressure, cfsqltype: "cf_sql_decimal" };
                allParams[p_ph]    = { value: ph, cfsqltype: "cf_sql_decimal" };

                // Execute the batch if we're full OR on the very last loop
                if (batchCounter == batchSize || i == numRows) {
                    
                    // Build the final SQL for this batch
                    var finalSql = sensorSqlTemplate & arrayToList(valueClauses, ",");
                    var finalSql_Row = sensorSqlTemplate_Row & arrayToList(valueClauses, ",");
                    
                    // Run the queries with all the parameters we collected
                    queryExecute(finalSql, allParams);
                    queryExecute(finalSql_Row, allParams);
                    
                    // Reset for the next batch
                    valueClauses = [];
                    allParams = {};
                }
            }

            var loopEndTime = now();
            response.duration_sec = (loopEndTime.getTime() - loopStartTime.getTime()) / 1000;
            response.rowsInserted = numRows;
            response.success = true;

        } // End transaction

        return response;
    }
}
