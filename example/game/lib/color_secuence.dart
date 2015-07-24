part of sprites;

class ColorSequence {
  List<Color> colors;
  List<double> colorStops;

  ColorSequence(this.colors, this.colorStops) {
    assert(colors != null);
    assert(colorStops != null);
    assert(colors.length == colorStops.length);
  }

  ColorSequence.fromStartAndEndColor(Color start, Color end) {
    colors = [start, end];
    colorStops = [0.0, 1.0];
  }

  ColorSequence.copy(ColorSequence sequence) {
    colors = new List<Color>.from(sequence.colors);
    colorStops = new List<double>.from(sequence.colorStops);
  }

  ColorSequence.copyWithVariance(ColorSequence sequence, int alphaVar, int redVar, int greenVar, int blueVar) {
    colors = new List<Color>();
    colorStops = new List<double>.from(sequence.colorStops);

    for (Color color in sequence.colors) {
      int aDelta = ((randomDouble() * 2.0 - 1.0) * alphaVar).toInt();
      int rDelta = ((randomDouble() * 2.0 - 1.0) * redVar).toInt();
      int gDelta = ((randomDouble() * 2.0 - 1.0) * greenVar).toInt();
      int bDelta = ((randomDouble() * 2.0 - 1.0) * blueVar).toInt();

      int aNew = (color.alpha + aDelta).clamp(0, 255);
      int rNew = (color.red + rDelta).clamp(0, 255);
      int gNew = (color.green + gDelta).clamp(0, 255);
      int bNew = (color.blue + bDelta).clamp(0, 255);

      colors.add(new Color.fromARGB(aNew, rNew, gNew, bNew));
    }
  }

  Color colorAtPosition(double pos) {
    assert(pos >= 0.0 && pos <= 1.0);

    double lastStop = colorStops[0];
    Color lastColor = colors[0];

    for (int i = 0; i < colors.length; i++) {
      double currentStop = colorStops[i];
      Color currentColor = colors[i];

      if (pos <= currentStop) {
        double blend = (pos - lastStop) / (currentStop - lastStop);
        return _interpolateColor(lastColor, currentColor, blend);
      }
      lastStop = currentStop;
      lastColor = currentColor;
    }
    return colors[colors.length-1];
  }
}

Color _interpolateColor(Color a, Color b, double blend) {
  double aa = a.alpha.toDouble();
  double ar = a.red.toDouble();
  double ag = a.green.toDouble();
  double ab = a.blue.toDouble();

  double ba = b.alpha.toDouble();
  double br = b.red.toDouble();
  double bg = b.green.toDouble();
  double bb = b.blue.toDouble();

  int na = (aa * (1.0 - blend) + ba * blend).toInt();
  int nr = (ar * (1.0 - blend) + br * blend).toInt();
  int ng = (ag * (1.0 - blend) + bg * blend).toInt();
  int nb = (ab * (1.0 - blend) + bb * blend).toInt();

  return new Color.fromARGB(na, nr, ng, nb);
}
