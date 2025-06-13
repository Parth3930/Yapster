-- Migration to add star_count column to posts table
-- This column will track the number of stars/favorites for each post

-- Add star_count column to posts table if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'posts' 
        AND column_name = 'star_count'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.posts ADD COLUMN star_count INTEGER DEFAULT 0;
        
        -- Add a comment to explain the column
        COMMENT ON COLUMN public.posts.star_count IS 'Number of stars/favorites for this post';
        
        -- Update existing posts to have correct star counts based on user_favorites
        UPDATE public.posts 
        SET star_count = (
            SELECT COUNT(*) 
            FROM public.user_favorites 
            WHERE user_favorites.post_id = posts.id
        );
        
        RAISE NOTICE 'Added star_count column to posts table and updated existing records';
    ELSE
        RAISE NOTICE 'star_count column already exists in posts table';
    END IF;
END $$;

-- Create an index on star_count for better query performance
CREATE INDEX IF NOT EXISTS idx_posts_star_count ON public.posts(star_count);

-- Add a check constraint to ensure star_count is never negative
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'chk_posts_star_count_non_negative'
        AND table_name = 'posts'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.posts ADD CONSTRAINT chk_posts_star_count_non_negative 
        CHECK (star_count >= 0);
        RAISE NOTICE 'Added check constraint for star_count';
    ELSE
        RAISE NOTICE 'Check constraint for star_count already exists';
    END IF;
END $$;