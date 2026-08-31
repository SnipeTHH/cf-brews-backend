-- ========================================================================
-- ALLOYDB STUDIO SEEDING SCRIPT: VAT ASSIGNMENTS & TAPROOM RATINGS
-- ========================================================================
-- Description: Run this PL/pgSQL script in AlloyDB Studio to automatically:
--              1. Ensure brews.taproom_feedback exists.
--              2. Link your 3 most recent batches dynamically to Vats A, B, C.
--              3. Seed realistic FOH reviews (highly rated, mixed, and
--                 low-rated to trigger the pulsing Quality Alert tag).
-- ========================================================================

DO $$
DECLARE
    b1 INT;
    b2 INT;
    b3 INT;
    c_id INT;
BEGIN
    -- 1. Ensure brews.taproom_feedback table exists (with customer_id matching pre-existing schemas)
    CREATE TABLE IF NOT EXISTS brews.taproom_feedback (
        feedback_id SERIAL PRIMARY KEY,
        batch_id INT NOT NULL,
        rating DECIMAL(2,1) NOT NULL,
        customer_id INT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    -- 2. Clear existing taproom feedback
    TRUNCATE TABLE brews.taproom_feedback CASCADE;

    -- 3. Fetch the 3 most recent batches dynamically from OLTP Batches table
    SELECT batch_id INTO b1 FROM Batches ORDER BY batch_id DESC LIMIT 1 OFFSET 0;
    SELECT batch_id INTO b2 FROM Batches ORDER BY batch_id DESC LIMIT 1 OFFSET 1;
    SELECT batch_id INTO b3 FROM Batches ORDER BY batch_id DESC LIMIT 1 OFFSET 2;

    -- Validate we have enough batches
    IF b1 IS NULL OR b2 IS NULL OR b3 IS NULL THEN
        RAISE EXCEPTION 'Not enough batches found in the database. Please click "Create New Batch" at least 3 times in the UI first, then re-run this script.';
    END IF;

    -- 4. Dynamically resolve or seed a valid customer_id (enforces NOT NULL foreign keys)
    SELECT customer_id INTO c_id FROM brews.customers LIMIT 1;
    IF c_id IS NULL THEN
        INSERT INTO brews.customers (customer_name) VALUES ('Demo Patron') RETURNING customer_id INTO c_id;
    END IF;

    -- 5. Assign these batches to Vats (BOH OLTP assignments)
    -- Clear stale assignments first
    UPDATE Vats SET current_batch_id = NULL;
    
    -- Assign to Vat A, Vat B, and Vat C
    UPDATE Vats SET current_batch_id = b1 WHERE name = 'Vat A';
    UPDATE Vats SET current_batch_id = b2 WHERE name = 'Vat B';
    UPDATE Vats SET current_batch_id = b3 WHERE name = 'Vat C';

    -- 6. Seed ratings for Batch 1 (High rating ~4.8 average)
    INSERT INTO brews.taproom_feedback (batch_id, rating, customer_id) VALUES 
    (b1, 5.0, c_id),
    (b1, 5.0, c_id),
    (b1, 4.5, c_id),
    (b1, 5.0, c_id),
    (b1, 4.5, c_id);

    -- 7. Seed ratings for Batch 2 (Mixed rating ~3.3 average)
    INSERT INTO brews.taproom_feedback (batch_id, rating, customer_id) VALUES 
    (b2, 4.0, c_id),
    (b2, 3.0, c_id),
    (b2, 3.0, c_id);

    -- 8. Seed ratings for Batch 3 (LOW rating ~2.1 average) -> WILL TRIGGER QUALITY ALERT PULSATOR!
    INSERT INTO brews.taproom_feedback (batch_id, rating, customer_id) VALUES 
    (b3, 2.0, c_id),
    (b3, 2.5, c_id),
    (b3, 2.0, c_id),
    (b3, 2.0, c_id);

    RAISE NOTICE 'Successfully assigned batches: Vat A (#%), Vat B (#%), Vat C (#%).', b1, b2, b3;
    RAISE NOTICE 'Seeded 12 reviews. Batch #% has been seeded with low ratings (Quality Alert active).', b3;
END $$;
