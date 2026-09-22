-- ========================================================================
-- ALLOYDB STUDIO SEEDING SCRIPT: CUSTOMER FEEDBACK & AI SENTIMENT
-- ========================================================================
-- Description: Run this script in AlloyDB Studio to prepare your database
--              for the Customer AI Sentiment Dashboard demo.
--              Enables the required AI extension, creates/alters tables,
--              and seeds realistic review data.
-- ========================================================================

-- 1. Enable the AlloyDB AI extension -- Need to make sure that the database has 
-- the alloydb_ai_nl.enabled flag turned on
-- Essential for some vector operations and indexing
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- To work with vector embeddings and similarity search
CREATE EXTENSION IF NOT EXISTS vector;

-- To use ScaNN index for high performance vector search
CREATE EXTENSION IF NOT EXISTS alloydb_scann;

-- To integrate with Gemini Enterprise models
CREATE EXTENSION IF NOT EXISTS google_ml_integration;

-- To enable natural language queries
CREATE EXTENSION IF NOT EXISTS alloydb_ai_nl;

-- 2. Ensure the brews schema exists
CREATE SCHEMA IF NOT EXISTS brews;

-- 3. Ensure the customers table exists
CREATE TABLE IF NOT EXISTS brews.customers ( 
    customer_id SERIAL PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL UNIQUE
);

-- 4. Ensure the purchases table exists
CREATE TABLE IF NOT EXISTS brews.purchases (
    purchase_id SERIAL PRIMARY KEY,
    customer_id INT REFERENCES brews.customers(customer_id),
    recipe_id INT REFERENCES brews.recipes(recipe_id),
    feedback_text TEXT,
    purchase_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 5. Safe migration: Add feedback_text to purchases if it existed but lacked it
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'brews' AND table_name = 'purchases') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'brews' AND table_name = 'purchases' AND column_name = 'feedback_text') THEN
            ALTER TABLE brews.purchases ADD COLUMN feedback_text TEXT;
        END IF;
    END IF;
END $$;

-- 7. Clear existing mock feedback entries (to prevent duplicates on repeat runs)
DELETE FROM brews.purchases WHERE feedback_text IS NOT NULL;

-- 8. Seed Purchases & Descriptive Feedback (Matching existing recipe styles dynamically)

-- IPA reviews (Expected sentiment: Positive / Neutral-Negative)
INSERT INTO brews.purchases (customer_id, recipe_id, feedback_text, purchase_time)
SELECT 
    (SELECT customer_id FROM brews.customers WHERE customer_name = 'Aaron'),
    recipe_id,
    'Incredible hop profile! Bursting with tropical fruit and citrus notes. Super crisp and clean finish.',
    NOW() - INTERVAL '10 hours'
FROM brews.recipes WHERE style ILIKE '%IPA%' LIMIT 1;

INSERT INTO brews.purchases (customer_id, recipe_id, feedback_text, purchase_time)
SELECT 
    (SELECT customer_id FROM brews.customers WHERE customer_name = 'Charlie'),
    recipe_id,
    'A bit too bitter for my taste, but the aroma of pine and grapefruit is beautiful. Decent IPA.',
    NOW() - INTERVAL '8 hours'
FROM brews.recipes WHERE style ILIKE '%IPA%' LIMIT 1;

INSERT INTO brews.purchases (customer_id, recipe_id, feedback_text, purchase_time)
SELECT 
    (SELECT customer_id FROM brews.customers WHERE customer_name = 'Diana'),
    recipe_id,
    'Wow, this is exceptionally balanced for a West Coast style. Juicy, resinous, and highly drinkable!',
    NOW() - INTERVAL '5 hours'
FROM brews.recipes WHERE style ILIKE '%IPA%' LIMIT 1;

-- Stout/Porter reviews (Expected sentiment: Positive / Negative)
INSERT INTO brews.purchases (customer_id, recipe_id, feedback_text, purchase_time)
SELECT 
    (SELECT customer_id FROM brews.customers WHERE customer_name = 'Bob'),
    recipe_id,
    'Outstanding stout! Heavy notes of dark chocolate and roasted coffee. Thick, creamy mouthfeel, absolutely perfect for a cold night.',
    NOW() - INTERVAL '12 hours'
FROM brews.recipes WHERE style ILIKE '%Stout%' OR style ILIKE '%Porter%' LIMIT 1;

INSERT INTO brews.purchases (customer_id, recipe_id, feedback_text, purchase_time)
SELECT 
    (SELECT customer_id FROM brews.customers WHERE customer_name = 'Ethan'),
    recipe_id,
    'A bit too sweet and syrupy for me. It has good vanilla notes, but I could barely finish a half pint.',
    NOW() - INTERVAL '4 hours'
FROM brews.recipes WHERE style ILIKE '%Stout%' OR style ILIKE '%Porter%' LIMIT 1;

-- Pilsner/Lager reviews (Expected sentiment: Positive / Neutral-Negative)
INSERT INTO brews.purchases (customer_id, recipe_id, feedback_text, purchase_time)
SELECT 
    (SELECT customer_id FROM brews.customers WHERE customer_name = 'Fiona'),
    recipe_id,
    'Very refreshing and crisp! Clean bready malt profile with a nice herbal hop bite. Perfect taproom crusher.',
    NOW() - INTERVAL '1 day'
FROM brews.recipes WHERE style ILIKE '%Pilsner%' OR style ILIKE '%Lager%' OR style ILIKE '%Blonde%' LIMIT 1;

INSERT INTO brews.purchases (customer_id, recipe_id, feedback_text, purchase_time)
SELECT 
    (SELECT customer_id FROM brews.customers WHERE customer_name = 'George'),
    recipe_id,
    'A bit bland. Tastes like a standard macro lager. Not bad, just very uninspired.',
    NOW() - INTERVAL '18 hours'
FROM brews.recipes WHERE style ILIKE '%Pilsner%' OR style ILIKE '%Lager%' OR style ILIKE '%Blonde%' LIMIT 1;

-- General Ales/Wheat reviews (Expected sentiment: Positive / Neutral)
INSERT INTO brews.purchases (customer_id, recipe_id, feedback_text, purchase_time)
SELECT 
    (SELECT customer_id FROM brews.customers WHERE customer_name = 'Hannah'),
    recipe_id,
    'Lovely banana and clove phenols! Super fluffy head and a nice wheaty finish. Very authentic wheat beer.',
    NOW() - INTERVAL '2 days'
FROM brews.recipes WHERE style ILIKE '%Wheat%' OR style ILIKE '%Ale%' OR style ILIKE '%Saison%' LIMIT 1;

INSERT INTO brews.purchases (customer_id, recipe_id, feedback_text, purchase_time)
SELECT 
    (SELECT customer_id FROM brews.customers WHERE customer_name = 'Aaron'),
    recipe_id,
    'Refreshing but slightly under-carbonated today. The orange peel flavor is nice, but it lacks some zip.',
    NOW() - INTERVAL '6 hours'
FROM brews.recipes WHERE style ILIKE '%Wheat%' OR style ILIKE '%Ale%' OR style ILIKE '%Saison%' LIMIT 1;

-- Fallback seeding (Ensures data exist even if style-specific lookups yield no matches)
INSERT INTO brews.purchases (customer_id, recipe_id, feedback_text, purchase_time)
SELECT 
    (SELECT customer_id FROM brews.customers WHERE customer_name = 'Bob'),
    recipe_id,
    'An overall decent brew. Balanced, solid flavor profile, and very clean execution.',
    NOW() - INTERVAL '14 hours'
FROM brews.recipes ORDER BY recipe_id LIMIT 1;

INSERT INTO brews.purchases (customer_id, recipe_id, feedback_text, purchase_time)
SELECT 
    (SELECT customer_id FROM brews.customers WHERE customer_name = 'Diana'),
    recipe_id,
    'Remarkably smooth! Great flavor complexity. I would highly recommend this to anyone visiting the taproom.',
    NOW() - INTERVAL '3 hours'
FROM brews.recipes ORDER BY recipe_id OFFSET 1 LIMIT 1;
