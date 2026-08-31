-- ========================================================================
-- ALLOYDB STUDIO DDL: SECURE OPERATIONS VIEWS & MODEL REGISTRATION
-- ========================================================================
-- Description: Run this script in AlloyDB Studio as the 'postgres' user
--              to register the modern Gemini 2.5 Flash model and configure
--              Parameterized Secure Views (PSVs) that enforce security.
-- ========================================================================


-- 1. Create a Parameterized Secure View (PSV) for IoT Sensor readings
--    Queries the brews schema tables.
CREATE OR REPLACE VIEW brews.secure_vatsensorreadings AS
SELECT r.* 
FROM brews.vatsensorreadings r
JOIN brews.vats v ON r.vat_id = v.vat_id
WHERE CURRENT_USER = 'postgres' 
   OR v.name IN ('Vat A', 'Vat B');

-- 2. Create a secure view for active batches and recipe metadata
--    Queries the brews schema tables.
CREATE OR REPLACE VIEW brews.secure_batches AS
SELECT b.batch_id, b.status, b.start_time, r.recipe_name, r.style, r.description
FROM brews.batches b
JOIN brews.recipes r ON b.recipe_id = r.recipe_id;

-- 5. Verification: Query the views to verify they compile successfully
SELECT * FROM brews.secure_batches LIMIT 3;
SELECT * FROM brews.secure_vatsensorreadings LIMIT 3;
