-- ========================================================================
-- ALLOYDB STUDIO SQL: SEED OPERATIONAL & IoT SENSOR DATA
-- ========================================================================
-- Description: Run this script in AlloyDB Studio as the 'postgres' user
--              to seed realistic vats, batches, and sensor readings
--              to populate your operations dashboard and AI search.
-- ========================================================================

-- 1. Insert realistic operational Batches matching exact 'batch_status' ENUMs
--    Uses ON CONFLICT DO NOTHING to prevent duplicate primary key errors.
--    ENUM values: 'Pending', 'Fermenting', 'Conditioning', 'Complete', 'Failed'
--    Recipe IDs correspond to seeded recipes (1 = IPA, 2 = Stout, 3 = Porter, 4 = Lager)
INSERT INTO brews.batches (batch_id, recipe_id, status, start_time) VALUES
(101, 1, 'Fermenting'::brews.batch_status, CURRENT_TIMESTAMP - INTERVAL '4 days'),
(102, 2, 'Pending'::brews.batch_status, CURRENT_TIMESTAMP),
(103, 3, 'Conditioning'::brews.batch_status, CURRENT_TIMESTAMP - INTERVAL '10 days'),
(104, 4, 'Complete'::brews.batch_status, CURRENT_TIMESTAMP - INTERVAL '20 days')
ON CONFLICT (batch_id) DO NOTHING;

-- 2. Insert Vats and assign them to the active batches
--    Vats are named 'Vat A' to 'Vat C' to align perfectly with our secure views filter!
INSERT INTO brews.vats (vat_id, name, location, current_batch_id) VALUES
(1, 'Vat A', 'Fermentation Line 1', 101),
(2, 'Vat B', 'Brew House Area', 102),
(3, 'Vat C', 'Cold Aging Cellar', 103)
ON CONFLICT (vat_id) DO NOTHING;

-- 4. Insert realistic, warm IoT sensor log readings for our active vats
--    *   Vat A (Fermenting IPA): sit at warm fermentation temp (70.5 °F)
--    *   Vat B (Pending Batch): sits at room temperature waiting to brew (69.2 °F)
--    *   Vat C (Conditioning Stout): sits at cold conditioning temperature (45.2 °F)
INSERT INTO brews.vatsensorreadings (batch_id, vat_id, temp, pressure, ph, reading_time) VALUES
-- Vat A (Active Fermentation spikes & status checks)
(101, 1, 70.5, 14.8, 5.2, CURRENT_TIMESTAMP - INTERVAL '3 hours'),
(101, 1, 70.9, 15.1, 5.1, CURRENT_TIMESTAMP - INTERVAL '2 hours'),
(101, 1, 71.2, 15.4, 5.1, CURRENT_TIMESTAMP - INTERVAL '1 hour'),
(101, 1, 71.5, 15.6, 5.0, CURRENT_TIMESTAMP),

-- Vat B (Pending Startup logs)
(102, 2, 69.2, 12.1, 5.4, CURRENT_TIMESTAMP - INTERVAL '1 hour'),
(102, 2, 69.5, 12.3, 5.4, CURRENT_TIMESTAMP),

-- Vat C (Cold Aging logs)
(103, 3, 45.2, 8.5, 5.1, CURRENT_TIMESTAMP - INTERVAL '2 hours'),
(103, 3, 45.0, 8.2, 5.1, CURRENT_TIMESTAMP);

-- 5. Verification: Verify seeded counts
SELECT 'Batches Seeded' AS table, COUNT(*) FROM brews.batches
UNION ALL
SELECT 'Vats Seeded' AS table, COUNT(*) FROM brews.vats
UNION ALL
SELECT 'Sensor Readings Seeded' AS table, COUNT(*) FROM brews.vatsensorreadings;
