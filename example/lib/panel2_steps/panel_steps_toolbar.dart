import 'package:flutter/material.dart';
import 'package:textify_dashboard/widgets/image_viewer.dart';

class PanelStepsToolbar extends StatefulWidget {
  const PanelStepsToolbar({
    super.key,
    required this.kernelSizeDilate,
    required this.viewAsStep,
    required this.onViewChanged,
    required this.onChanged,
    required this.onReset,
  });
  final int kernelSizeDilate;
  final ViewImageSteps viewAsStep;
  final Function(ViewImageSteps) onViewChanged;
  final Function(int) onChanged;
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
    ViewImageSteps.columns: '4 Columns',
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
      children: [
        SizedBox(
          width: 500,
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
        SizedBox(width: 40),
        _buildDilateButtons(),
        SizedBox(width: 40),
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
            widget.onChanged(
              widget.kernelSizeDilate - 1,
            );
          }
        }),
        Text('Dilate: ${widget.kernelSizeDilate}'),
        _buildButton('+', () {
          widget.onChanged(
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
