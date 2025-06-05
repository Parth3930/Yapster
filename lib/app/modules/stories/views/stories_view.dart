import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/stories_controller.dart';
import 'widgets/story_button.dart';
import 'create_story_view.dart';

class StoriesView extends GetView<StoriesController> {
  const StoriesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Stories')),
      body: _buildStoriesList(),
    );
  }

  Widget _buildStoriesList() {
    // Sample stories data - in a real app, this would come from your data source
    final List<Map<String, dynamic>> sampleStories = [
      {
        'id': '1',
        'username': 'johndoe',
        'avatar': 'https://i.pravatar.cc/150?img=1',
        'hasUnseen': true,
      },
      {
        'id': '2',
        'username': 'janedoe',
        'avatar': 'https://i.pravatar.cc/150?img=2',
        'hasUnseen': true,
      },
      {
        'id': '3',
        'username': 'alex',
        'avatar': 'https://i.pravatar.cc/150?img=3',
        'hasUnseen': false,
      },
      {
        'id': '4',
        'username': 'sarah',
        'avatar': 'https://i.pravatar.cc/150?img=4',
        'hasUnseen': true,
      },
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      scrollDirection: Axis.horizontal,
      children: [
        // Add story button (always first)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: StoryButton(
            isAddButton: true,
            onTap: controller.toggleStoryPanel,
          ),
        ),

        // User's stories
        ...sampleStories.map(
          (story) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Column(
              children: [
                // Story ring with gradient border for unseen stories
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient:
                        story['hasUnseen']
                            ? const LinearGradient(
                              colors: [Colors.purple, Colors.orange],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                            : null,
                    border:
                        !story['hasUnseen']
                            ? Border.all(color: Colors.grey.shade300)
                            : null,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 30,
                      backgroundImage: NetworkImage(story['avatar']),
                      child: null,
                    ),
                  ),
                ),
                SizedBox(height: 4),
                SizedBox(
                  width: 60,
                  child: Text(
                    story['username'],
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
