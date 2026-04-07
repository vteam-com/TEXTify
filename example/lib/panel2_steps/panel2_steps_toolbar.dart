import 'package:flutter/material.dart';
import 'package:textify_dashboard/widgets/image_viewer.dart';

class Panel2Toolbar extends StatefulWidget {
  const Panel2Toolbar({
    super.key,
    required this.viewAsStep,
    required this.onViewChanged,
    required this.transformationController,
    //
    // region
    //
    required this.showRegions,
    required this.onShowRegionsChanged,
    //
    // attemptToExtractWideArtifacts
    //
    required this.tryToExtractWideArtifacts,
    required this.onTryToExtractWideArtifactsChanged,
    required this.excludeLongLines,
    required this.onExcludeLongLinesChanged,
    //
    // histogram
    //
    required this.showHistograms,
    required this.onShowHistogramsChanged,
    //
    // dilate
    //
    required this.kernelSizeDilate,
    required this.onDelateChanged,
    required this.matchingThreshold,
    required this.onMatchingThresholdChanged,
    required this.maxProcessingTimeMs,
    required this.onMaxProcessingTimeChanged,
    required this.onReset,
  });

  static const int timeoutStepMs = 1000;
  static const int timeoutMinMs = 1000;

  final ViewAs viewAsStep;
  final Function(ViewAs) onViewChanged;
  final TransformationController transformationController;
  final bool showRegions;
  final bool tryToExtractWideArtifacts;
  final bool excludeLongLines;
  final Function(bool) onTryToExtractWideArtifactsChanged;
  final Function(bool) onExcludeLongLinesChanged;
  final bool showHistograms;
  final int kernelSizeDilate;
  final Function(int) onDelateChanged;
  final double matchingThreshold;
  final Function(double) onMatchingThresholdChanged;
  final int maxProcessingTimeMs;
  final Function(int) onMaxProcessingTimeChanged;
  final Function(bool) onShowRegionsChanged;
  final Function(bool) onShowHistogramsChanged;
  final Function onReset;

  @override
  State<Panel2Toolbar> createState() => _Panel2ToolbarState();
}

class _Panel2ToolbarState extends State<Panel2Toolbar>
    with SingleTickerProviderStateMixin {
  final Map<ViewAs, String> tabViews = {
    ViewAs.blackAndWhite: '1 B&W',
    ViewAs.region: '2 Dilated',
    ViewAs.artifacts: '3 Artifacts',
    ViewAs.characters: '4 Characters',
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
        // TabsView
        IntrinsicWidth(
          child: TabBar(
            isScrollable: true,
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
                      widget.transformationController.value * (1 / 1.5);
                },
                child: const Text('-'),
              ),
              Text('Zoom'),
              OutlinedButton(
                onPressed: () {
                  widget.transformationController.value =
                      widget.transformationController.value * 1.5;
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
                  const Text('Bounds'),
                  Checkbox(
                    value: widget.showRegions,
                    onChanged: (value) => widget.onShowRegionsChanged(value!),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text('InnerSplit'),
                  Checkbox(
                    value: widget.tryToExtractWideArtifacts,
                    onChanged: (value) =>
                        widget.onTryToExtractWideArtifactsChanged(value!),
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
              Row(
                children: [
                  const Text('Exclude Lines'),
                  Checkbox(
                    value: widget.excludeLongLines,
                    onChanged: (value) =>
                        widget.onExcludeLongLinesChanged(value!),
                  ),
                ],
              ),
            ],
          ),
        ),
        IntrinsicWidth(
          child: Row(
            spacing: 10,
            children: [
              const Text('Match'),
              SizedBox(
                width: 160,
                child: Slider(
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  value: widget.matchingThreshold,
                  onChanged: widget.onMatchingThresholdChanged,
                ),
              ),
              Text(widget.matchingThreshold.toStringAsFixed(2)),
            ],
          ),
        ),
        IntrinsicWidth(
          child: Row(
            spacing: 10,
            children: [
              _buildButton('-', () {
                final int next =
                    widget.maxProcessingTimeMs - Panel2Toolbar.timeoutStepMs;
                if (next >= Panel2Toolbar.timeoutMinMs) {
                  widget.onMaxProcessingTimeChanged(next);
                }
              }),
              Text(
                'Timeout\n${widget.maxProcessingTimeMs}ms',
                textAlign: TextAlign.center,
              ),
              _buildButton('+', () {
                widget.onMaxProcessingTimeChanged(
                  widget.maxProcessingTimeMs + Panel2Toolbar.timeoutStepMs,
                );
              }),
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
