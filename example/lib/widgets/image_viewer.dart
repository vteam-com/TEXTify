import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

enum ViewAs {
  blackAndWhite,
  region,
  artifacts,
  characters,
}

class ImageViewer extends StatelessWidget {
  const ImageViewer({super.key, required this.image});

  final ui.Image image;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: ImagePainter(image),
      size: Size(image.width.toDouble(), image.height.toDouble()),
    );
  }
}

class ImagePainter extends CustomPainter {
  ImagePainter(this.image);

  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    paintImage(
      canvas: canvas,
      rect: Offset.zero & size,
      image: image,
      fit: BoxFit.contain,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Widget buildInteractiveImageViewer(
  final ui.Image? imageToDisplay,
  final TransformationController? transformationController,
) {
  if (imageToDisplay == null) {
    return const SizedBox();
  }
  return CustomInteractiveViewer(
    transformationController: transformationController,
    child: ImageViewer(
      image: imageToDisplay,
    ),
  );
}

class PanningGestureRecognizer extends PanGestureRecognizer {
  @override
  void addPointer(PointerDownEvent event) {
    if (event.buttons == kPrimaryButton) {
      // Only start tracking when the primary mouse button is pressed
      startTrackingPointer(event.pointer);
      resolve(GestureDisposition.accepted);
    } else {
      stopTrackingPointer(event.pointer);
    }
  }
}

class CustomInteractiveViewer extends StatefulWidget {
  const CustomInteractiveViewer({
    super.key,
    required this.child,
    this.transformationController,
    this.constrained = false,
    this.minScale = 0.01,
    this.maxScale = 50,
    //        minScale: 0.1,
    // maxScale: 50,
  });
  final Widget child;
  final TransformationController? transformationController;

  final bool constrained;
  final double minScale;
  final double maxScale;

  @override
  CustomInteractiveViewerState createState() => CustomInteractiveViewerState();
}

class CustomInteractiveViewerState extends State<CustomInteractiveViewer> {
  bool _isPanning = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        if (event.buttons == kPrimaryButton) {
          setState(() {
            _isPanning = true;
          });
        }
      },
      onPointerUp: (event) {
        setState(() {
          _isPanning = false;
        });
      },
      child: InteractiveViewer(
        transformationController: widget.transformationController,
        panEnabled: _isPanning,
        scaleEnabled: true,
        panAxis: PanAxis.free,
        constrained: widget.constrained,
        minScale: widget.minScale,
        maxScale: widget.maxScale,
        child: widget.child,
      ),
    );
  }
}
