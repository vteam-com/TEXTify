import 'package:flutter/material.dart';
import 'package:textify_dashboard/widgets/image_viewer.dart';

class PanelStepsToolbar extends StatefulWidget {
  const PanelStepsToolbar({
    super.key,
    required this.viewAsStep,
    required this.onViewChanged,
    // region
    required this.showRegions,
    required this.onShowRegionsChanged,
    // histogram
    required this.showHistograms,
    required this.onShowHistogramsChanged,
    // dilate
    required this.kernelSizeDilate,
    required this.onDelateChanged,
    required this.onReset,
  });
  final ViewImageSteps viewAsStep;
  final Function(ViewImageSteps) onViewChanged;
  final bool showRegions;
  final bool showHistograms;
  final int kernelSizeDilate;
  final Function(int) onDelateChanged;
  final Function(bool) onShowRegionsChanged;
  final Function(bool) onShowHistogramsChanged;
  final Function onReset;

  @override
  State<PanelStepsToolbar> createState() => _PanelStepsToolbarState();
}

class _PanelStepsToolbarState extends State<PanelStepsToolbar>
    with SingleTickerProviderStateMixin {
  final Map<ViewImageSteps, String> tabViews = {
    ViewImageSteps.grayScale: '1 GrayS',
    ViewImageSteps.blackAndWhite: '2 B&W',
    ViewImageSteps.region: '3 Regions',
  };

  late TabController _tabController;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      initialIndex: widget.viewAsStep.index,
      length: tabViews.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 10,
      children: [
        SizedBox(
          width: 400,
          child: TabBar(
            controller: _tabController,
            tabs: tabViews.entries
                .map((entry) => Tab(text: entry.value))
                .toList(),
            onTap: (index) {
              _tabController.animateTo(index);
              widget.onViewChanged(tabViews.keys.elementAt(index));
            },
          ),
        ),
        _buildDilateButtons(),
        Row(
          children: [
            Checkbox(
              value: widget.showRegions,
              onChanged: (value) => widget.onShowRegionsChanged(value!),
            ),
            const Text('Show Regions'),
          ],
        ),
        Row(
          children: [
            Checkbox(
              value: widget.showHistograms,
              onChanged: (value) => widget.onShowHistogramsChanged(value!),
            ),
            const Text('Show Histogram'),
          ],
        ),
        OutlinedButton(
          onPressed: () {
            widget.onReset();
          },
          child: Text('Reset'),
        ),
      ],
    );
  }

  Widget _buildDilateButtons() {
    return Row(
      spacing: 10,
      children: [
        _buildButton('-', () {
          if (widget.kernelSizeDilate > 0) {
            widget.onDelateChanged(
              widget.kernelSizeDilate - 1,
            );
          }
        }),
        Text('Dilate: ${widget.kernelSizeDilate}'),
        _buildButton('+', () {
          widget.onDelateChanged(
            widget.kernelSizeDilate + 1,
          );
        }),
      ],
    );
  }

  // New helper method to create buttons
  Widget _buildButton(String label, VoidCallback onPressed) {
    return OutlinedButton(
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
