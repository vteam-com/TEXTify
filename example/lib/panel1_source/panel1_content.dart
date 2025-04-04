import 'package:flutter/material.dart';

class PanelStepContent extends StatelessWidget {
  const PanelStepContent({
    super.key,
    this.left,
    this.top,
    this.center,
    this.bottom,
    this.right,
  });

  final Widget? left;
  final Widget? top;
  final Widget? center;
  final Widget? bottom;
  final Widget? right;

  @override
  Widget build(final BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (left != null) left!,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (top != null) top!,
              Container(
                height: 400,
                margin: const EdgeInsets.only(top: 13, bottom: 3),
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.0),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.grey.shade900.withAlpha(100),
                      Colors.black.withAlpha(150),
                    ],
                  ),
                ),
                child: Center(child: center ?? Text('Working...')),
              ),
              if (bottom != null) bottom!,
            ],
          ),
        ),
        if (right != null) right!,
      ],
    );
  }
}

ExpansionPanel buildExpansionPanel({
  required final BuildContext context,
  required final String titleLeft,
  required final String titleCenter,
  required final String titleRight,
  required final bool isExpanded,
  required final Widget content,
}) {
  final ColorScheme colorScheme = Theme.of(context).colorScheme;

  return ExpansionPanel(
    backgroundColor: colorScheme.primaryContainer,
    canTapOnHeader: true,
    isExpanded: isExpanded,
    headerBuilder: (final BuildContext context, final bool isExpanded) =>
        buildPanelHeader(titleLeft, titleCenter, titleRight),
    body: Container(
      color: colorScheme.secondaryContainer,
      padding: const EdgeInsets.all(8.0),
      child: isExpanded ? content : SizedBox(),
    ),
  );
}

Widget buildPanelHeader(
  final String left,
  final String center,
  final String right,
) {
  return Padding(
    padding: const EdgeInsets.only(left: 8.0, right: 8.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: Text(
            left,
            textAlign: TextAlign.left,
            style: const TextStyle(fontSize: 20),
          ),
        ),
        Expanded(
          child: Text(
            center,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20),
          ),
        ),
        Expanded(
          child: Text(
            right,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 20),
          ),
        ),
      ],
    ),
  );
}
