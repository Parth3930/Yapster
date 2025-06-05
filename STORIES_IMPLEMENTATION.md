# Stories Feature Implementation

## Overview

This document outlines the complete implementation of the Stories feature for Yapster, including database schema, backend logic, and frontend components.

## Features Implemented

### 1. Story Creation

- **Image Upload**: Users can select images from gallery or take photos
- **Text Overlay**: Add text with customizable colors, fonts, and positioning
- **Doodle Support**: Draw on stories with different colors and brush sizes
- **24-hour Expiration**: Stories automatically expire after 24 hours

### 2. Story Viewing

- **Story Feed**: Horizontal scrollable list of user avatars with story indicators
- **Visual Indicators**:
  - Colorful gradient border for unseen stories
  - Gray border for seen stories
  - Add button (+) for current user when no active story
- **Story Viewer**: Full-screen story viewer with auto-advance and manual navigation
- **Progress Indicators**: Visual progress bars showing story position

### 3. Story Management

- **Automatic Cleanup**: Expired stories are automatically removed
- **View Tracking**: Track which users have viewed each story
- **Profile Integration**: User profiles show story status

## Database Schema

### Consolidated Stories Table

The stories feature uses a single consolidated table with comprehensive row-level security:

```sql
CREATE TABLE public.stories (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    image_url TEXT,
    text_items JSONB DEFAULT '[]'::jsonb,
    doodle_points JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '24 hours'),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- View tracking (consolidated from separate table)
    view_count INTEGER DEFAULT 0,
    viewers JSONB DEFAULT '[]'::jsonb, -- Array of user IDs who viewed this story

    -- Status fields
    is_active BOOLEAN DEFAULT true,
    is_expired BOOLEAN GENERATED ALWAYS AS (expires_at < NOW()) STORED
);
```

### Key Features

- **Consolidated Design**: Single table instead of multiple related tables
- **View Tracking**: Built-in view counting and viewer tracking
- **Computed Fields**: Automatic expiration status calculation
- **JSONB Storage**: Efficient storage for viewers list and story content
- **Comprehensive Indexing**: Optimized for common query patterns

### Profile Extensions

- Added `has_active_story` BOOLEAN column to profiles
- Added `latest_story_at` TIMESTAMP column to profiles

### Storage Bucket

- **Bucket Name**: `stories`
- **File Size Limit**: 50MB
- **Allowed Types**: JPEG, PNG, WebP, GIF
- **Public Access**: Enabled

## Backend Components

### 1. Models

- **StoryModel**: Main story data model with text items and doodle points
- **StoryUser**: User model with story status information

### 2. Repository

- **StoryRepository**: Handles all story-related database operations
  - `uploadStoryImage()`: Upload story images to storage
  - `createStory()`: Create new story records
  - `getUserStories()`: Get stories for a specific user
  - `getFollowingStories()`: Get stories from followed users
  - `deleteStory()`: Delete specific stories

### 3. Controllers

- **StoriesController**: Main story creation controller
- **StoriesHomeController**: Manages story display on home screen
- **StoryViewerController**: Handles story viewing and navigation

## Frontend Components

### 1. Story Creation

- **CreateStoryView**: Full-screen story creation interface
- **Text Tools**: Text editing with positioning and styling
- **Doodle Tools**: Drawing tools with color and brush size options
- **Media Selection**: Gallery and camera integration

### 2. Story Display

- **StoriesListWidget**: Horizontal story list for home screen
- **ProfileAvatarWidget**: Enhanced avatar with story indicators
- **StoryViewerView**: Full-screen story viewer

### 3. Navigation

- **Routes Added**:
  - `/create-story`: Story creation page
  - `/view-stories`: Story viewer page

## Database Functions

### 1. Story Management Functions

```sql
-- Update profile story status when stories are added/removed
CREATE OR REPLACE FUNCTION update_profile_story_status()

-- Clean up expired stories and associated files
CREATE OR REPLACE FUNCTION cleanup_expired_stories()

-- Mark a story as viewed by current user
CREATE OR REPLACE FUNCTION mark_story_as_viewed(story_uuid UUID)

-- Get following users with their story status
CREATE OR REPLACE FUNCTION get_following_with_stories()
```

### 2. Triggers

- **update_profile_story_status_trigger**: Automatically updates profile story status
- **update_stories_updated_at**: Updates timestamp on story modifications

## Security (Row-Level Security)

### Comprehensive RLS Policies

The consolidated stories table includes comprehensive row-level security:

#### Story Management Policies

- **Create**: Users can only create their own stories
- **Read**: Users can view their own stories and stories from followed users (if not expired)
- **Update**: Users can update their own stories (for view tracking)
- **Delete**: Users can only delete their own stories

#### View Tracking Policies

- **View Tracking**: Secure view counting with user validation
- **Privacy**: Users cannot see who viewed others' stories (except their own)
- **Following Validation**: View tracking only works for followed users

#### Storage Security Policies

- **Upload**: Users can only upload to their own folder (`stories/{user_id}/`)
- **Access**: Users can view images from followed users
- **Cleanup**: Users can delete their own story files
- **Public Access**: Story images are publicly accessible via URL

### Security Features

- **Automatic Expiration**: Expired stories are automatically filtered out
- **Following Validation**: All story access requires valid following relationships
- **User Authentication**: All operations require authenticated users
- **Data Isolation**: Users cannot access unauthorized story data

## Installation Instructions

### 1. Database Setup

Run the consolidated schema script in your Supabase SQL editor:

**Consolidated Schema (Recommended)**

```sql
-- Run: database/stories_consolidated_schema.sql
```

This script will:

- Create the consolidated stories table with RLS
- Set up all necessary functions and triggers
- Configure storage bucket and policies
- Add profile extensions
- Set up automatic cleanup

### 2. Dependencies

The following dependencies are already included in the project:

- `supabase_flutter`: Database and storage
- `image_picker`: Image selection
- `photo_manager`: Gallery access
- `permission_handler`: Permissions
- `get`: State management

### 3. Permissions

Add these permissions to your platform-specific files:

**Android** (`android/app/src/main/AndroidManifest.xml`):

```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.CAMERA" />
```

**iOS** (`ios/Runner/Info.plist`):

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to take photos for stories</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs photo library access to select images for stories</string>
```

## Usage

### 1. Creating Stories

1. Tap the "+" button on your avatar in the home screen
2. Select an image from gallery or take a photo
3. Add text by tapping on the image
4. Draw doodles using the drawing tools
5. Tap "Post" to publish the story

### 2. Viewing Stories

1. Tap on any avatar with a colored border in the home screen
2. Stories will auto-advance every 5 seconds
3. Tap left/right sides to navigate manually
4. Tap "X" to close the story viewer

### 3. Story Indicators

- **Colorful gradient border**: User has unseen stories
- **Gray border**: User has stories but you've seen them all
- **No border**: User has no active stories
- **+ button**: Your avatar when you have no active story

## Automatic Cleanup

Stories are automatically cleaned up in several ways:

1. **Database Trigger**: Updates profile status when stories are added/removed
2. **Cleanup Function**: Can be called manually or scheduled
3. **Expiration Check**: All queries filter out expired stories

### Manual Cleanup

```sql
SELECT cleanup_expired_stories();
```

### Scheduled Cleanup (Optional)

If you have pg_cron enabled:

```sql
SELECT cron.schedule(
    'cleanup-expired-stories',
    '0 */6 * * *', -- Run every 6 hours
    'SELECT cleanup_expired_stories();'
);
```

## Troubleshooting

### Common Issues

1. **Bucket Already Exists Error**

   - The SQL scripts handle this with `ON CONFLICT` clauses
   - Safe to ignore if bucket already exists

2. **Policy Already Exists Error**

   - The complete schema drops existing policies before creating new ones
   - Use the complete schema for updates

3. **Permission Denied**

   - Ensure RLS policies are properly set up
   - Check that user is authenticated

4. **Images Not Loading**
   - Verify storage bucket is public
   - Check file upload permissions
   - Ensure correct file paths

### Debug Queries

```sql
-- Check active stories
SELECT * FROM public.stories WHERE expires_at > NOW();

-- Check story views
SELECT * FROM public.story_views;

-- Check profile story status
SELECT user_id, has_active_story, latest_story_at FROM public.profiles;

-- Manual cleanup
SELECT cleanup_expired_stories();
```

## Future Enhancements

Potential improvements for the stories feature:

1. **Story Reactions**: Add emoji reactions to stories
2. **Story Replies**: Allow users to reply to stories via DM
3. **Story Highlights**: Save stories permanently as highlights
4. **Story Analytics**: Show view counts and viewer lists
5. **Story Templates**: Pre-designed story templates
6. **Video Stories**: Support for video content
7. **Story Mentions**: Tag other users in stories
8. **Story Music**: Add background music to stories

## API Reference

### Story Repository Methods

```dart
// Upload story image
Future<String?> uploadStoryImage(File imageFile, String userId)

// Create new story
Future<bool> createStory(StoryModel story)

// Get user's stories
Future<List<StoryModel>> getUserStories(String userId)

// Get following users' stories
Future<List<StoryModel>> getFollowingStories(String userId)

// Delete story
Future<bool> deleteStory(String storyId, String userId)
```

### Controller Methods

```dart
// Stories Controller
Future<void> postStory()
Future<File?> pickImage()
Future<File?> takePhoto()

// Stories Home Controller
Future<void> loadStoriesData()
Future<void> markStoryAsViewed(String storyId)
void navigateToCreateStory()
void navigateToViewStories(String userId)

// Story Viewer Controller
Future<void> loadUserStories(String userId)
void nextStory()
void previousStory()
Future<void> markCurrentStoryAsViewed()
```

This implementation provides a complete Instagram-style stories feature with all the essential functionality for creating, viewing, and managing temporary content in your social media app.
