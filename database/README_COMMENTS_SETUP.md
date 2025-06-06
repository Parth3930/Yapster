# Comments Database Setup

## Quick Setup

To fix the "404 Not Found" error when liking comments, you need to run the comments database setup.

### Steps:

1. **Open Supabase Dashboard**
   - Go to your Supabase project dashboard
   - Navigate to **SQL Editor**

2. **Run the Setup Script**
   - Copy the entire content from `database/comments_setup.sql`
   - Paste it into the SQL Editor
   - Click **Run** to execute the script

3. **Verify Tables Created**
   - Go to **Table Editor**
   - You should see two new tables:
     - `post_comments` - stores all comments and replies
     - `post_comment_likes` - stores comment likes

### What This Creates:

- **Tables**: Comments and comment likes with proper relationships
- **RLS Policies**: Security rules for data access
- **Triggers**: Automatic count updates for likes and comments
- **Indexes**: Performance optimization for queries

### Features Enabled:

✅ **Comment Likes** - Users can like/unlike comments and replies
✅ **Reply System** - Nested comments with connecting lines
✅ **Auto Counts** - Automatic like and comment count updates
✅ **Security** - Row Level Security policies
✅ **Performance** - Optimized database indexes

### UI Features:

- **Instagram-style layout** with connecting lines for replies
- **Collapsible replies** - "2 Replies" button to expand/collapse
- **Real-time updates** - Like counts update immediately
- **Clean icons** - Heart for likes, comment icon for replies
- **Responsive design** - Works on all screen sizes

Once you run this setup, the comment system will work perfectly without any 404 errors!
