import 'package:flutter/material.dart';
import 'package:textify_dashboard/widgets/image_viewer.dart';

class Panel2Toolbar extends StatefulWidget {
  const Panel2Toolbar({
    super.key,
    required this.viewAsStep,
    required this.onViewChanged,
    required this.transformationController,
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
  final ViewAs viewAsStep;
  final Function(ViewAs) onViewChanged;
  final TransformationController transformationController;
  final bool showRegions;
  final bool showHistograms;
  final int kernelSizeDilate;
  final Function(int) onDelateChanged;
  final Function(bool) onShowRegionsChanged;
  final Function(bool) onShowHistogramsChanged;
  final Function onReset;

  @override
  State<Panel2Toolbar> createState() => _Panel2ToolbarState();
}

class _Panel2ToolbarState extends State<Panel2Toolbar>
    with SingleTickerProviderStateMixin {
  final Map<ViewAs, String> tabViews = {
    ViewAs.grayScale: '1 GrayS',
    ViewAs.blackAndWhite: '2 B&W',
    ViewAs.region: '3 Regions',
    ViewAs.artifacts: '4 Artifacts',
    ViewAs.characters: '5 Characters',
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
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 20,
      runSpacing: 20,
      children: [
        // TabsVi
        IntrinsicWidth(
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
        IntrinsicWidth(
          child: Row(
            spacing: 10,
            children: [
              OutlinedButton(
                onPressed: () {
                  widget.transformationController.value =
                      widget.transformationController.value.scaled(1 / 1.5);
                },
                child: const Text('-'),
              ),
              Text('Zoom'),
              OutlinedButton(
                onPressed: () {
                  widget.transformationController.value =
                      widget.transformationController.value.scaled(1.5);
                },
                child: const Text('+'),
              ),
            ],
          ),
        ),

        IntrinsicWidth(
          child: _buildDilateButtons(),
        ),

        IntrinsicWidth(
          child: Row(
            spacing: 20,
            children: [
              Row(
                children: [
                  const Text('Regions'),
                  Checkbox(
                    value: widget.showRegions,
                    onChanged: (value) => widget.onShowRegionsChanged(value!),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text('Histogram'),
                  Checkbox(
                    value: widget.showHistograms,
                    onChanged: (value) =>
                        widget.onShowHistogramsChanged(value!),
                  ),
                ],
              ),
            ],
          ),
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
        Text(
          'Dilate\n${widget.kernelSizeDilate}',
          textAlign: TextAlign.center,
        ),
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
