import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/startup/preloader/preloader_service.dart';
import 'package:yapster/app/startup/preloader/optimized_bindings.dart';

/// Debug widget to show app optimization status
/// Only shown in debug mode
class OptimizationDebugWidget extends StatelessWidget {
  const OptimizationDebugWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Only show in debug mode
    if (!kDebugMode) return const SizedBox.shrink();

    return Positioned(
      top: 100,
      right: 10,
      child: GestureDetector(
        onTap: () => _showOptimizationDialog(context),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green, width: 1),
          ),
          child: Obx(() {
            final preloader = Get.find<PreloaderService>();
            final isOptimized = preloader.isPreloaded.value;
            final progress = preloader.preloadingProgress.value;
            
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isOptimized ? Icons.rocket_launch : Icons.hourglass_empty,
                  color: isOptimized ? Colors.green : Colors.orange,
                  size: 16,
                ),
                const SizedBox(height: 2),
                Text(
                  isOptimized ? 'OPT' : '${(progress * 100).toInt()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  void _showOptimizationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('App Optimization Status'),
        content: SizedBox(
          width: 300,
          child: Obx(() {
            final preloader = Get.find<PreloaderService>();
            final status = preloader.getPreloadingStatus();
            final controllerStatus = OptimizationChecker.controllerStatus;
            final repositoryStatus = OptimizationChecker.repositoryStatus;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusRow('App Optimized', status['isPreloaded']),
                _buildStatusRow('Controllers Preloaded', status['controllersPreloaded']),
                _buildStatusRow('Data Preloaded', status['dataPreloaded']),
                _buildStatusRow('Repositories Preloaded', status['repositoriesPreloaded']),
                
                if (status['isPreloading'])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Progress: ${(status['progress'] * 100).toInt()}%'),
                        LinearProgressIndicator(value: status['progress']),
                        const SizedBox(height: 4),
                        Text(
                          status['currentStep'] ?? '',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),

                const Divider(),
                const Text('Controllers:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...controllerStatus.entries.map((entry) => 
                  _buildStatusRow(entry.key, entry.value)),

                const Divider(),
                const Text('Repositories:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...repositoryStatus.entries.map((entry) => 
                  _buildStatusRow(entry.key, entry.value)),
              ],
            );
          }),
        ),
        actions: [
          TextButton(
            onPressed: () {
              OptimizationChecker.printOptimizationStatus();
              Navigator.of(context).pop();
            },
            child: const Text('Print to Console'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, bool status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            status ? Icons.check_circle : Icons.cancel,
            color: status ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mixin to easily add optimization debug widget to any page
mixin OptimizationDebugMixin {
  Widget wrapWithOptimizationDebug(Widget child) {
    return Stack(
      children: [
        child,
        const OptimizationDebugWidget(),
      ],
    );
  }
}
