-- ========================================================================
-- ALLOYDB STUDIO: VECTOR SEARCH ACCELERATION SCRIPT
-- ========================================================================
-- Description: Run this script in AlloyDB Studio after updating your
--              google_columnar_engine.relations flag to accelerate
--              vector search performance.
-- ========================================================================

-- 1. Create a high-performance HNSW (vector) index on the embeddings column
--    Uses 'vector_cosine_ops' to match the cosine distance operator (<=>)
CREATE INDEX IF NOT EXISTS recipes_hnsw_idx 
ON brews.recipes USING HNSW (recipe_embeddings vector_cosine_ops);

-- 2. Refresh the Columnar Engine in-memory capacity for the recipes table
-- google_columnar_engine_refresh expects the table (relation regclass) as an argument
SELECT public.google_columnar_engine_refresh('brews.recipes'::regclass);

-- 3. Verification: Verify that the index built successfully
SELECT indexname, indexdef 
FROM pg_indexes 
WHERE tablename = 'recipes' AND indexname = 'recipes_hnsw_idx';
