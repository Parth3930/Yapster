import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class StoryButton extends StatelessWidget {
  final String? avatarUrl;
  final bool isAddButton;
  final VoidCallback? onTap;

  const StoryButton({
    super.key,
    this.avatarUrl,
    this.isAddButton = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient:
                  isAddButton
                      ? null
                      : const LinearGradient(
                        colors: [Colors.purple, Colors.orange],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
              border:
                  isAddButton ? Border.all(color: Colors.grey.shade300) : null,
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border:
                    isAddButton
                        ? null
                        : Border.all(color: Colors.white, width: 2),
              ),
              child:
                  isAddButton
                      ? Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add,
                          size: 30,
                          color: Colors.black87,
                        ),
                      )
                      : ClipOval(
                        child:
                            avatarUrl != null && avatarUrl!.isNotEmpty
                                ? CachedNetworkImage(
                                  imageUrl: avatarUrl!,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  placeholder:
                                      (context, url) => CircleAvatar(
                                        radius: 30,
                                        backgroundColor: Colors.grey.shade300,
                                        child: const Icon(
                                          Icons.person,
                                          size: 30,
                                        ),
                                      ),
                                  errorWidget:
                                      (context, url, error) => CircleAvatar(
                                        radius: 30,
                                        backgroundColor: Colors.grey.shade300,
                                        child: const Icon(
                                          Icons.person,
                                          size: 30,
                                        ),
                                      ),
                                )
                                : CircleAvatar(
                                  radius: 30,
                                  backgroundColor: Colors.grey.shade300,
                                  child: const Icon(Icons.person, size: 30),
                                ),
                      ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isAddButton ? 'Add to Story' : 'Your Story',
            style: const TextStyle(fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
