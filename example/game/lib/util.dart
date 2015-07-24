part of sprites;


math.Random _random = new math.Random();

// Random methods

double randomDouble() {
  return _random.nextDouble();
}

double randomSignedDouble() {
  return _random.nextDouble() * 2.0 - 1.0;
}

int randomInt(int max) {
  return _random.nextInt(max);
}

// atan2

class _Atan2Constants {

  _Atan2Constants() {
    for (int i = 0; i <= size; i++) {
      double f = i.toDouble() / size.toDouble();
      ppy[i] = math.atan(f) * stretch / math.PI;
      ppx[i] = stretch * 0.5 - ppy[i];
      pny[i] = -ppy[i];
      pnx[i] = ppy[i] - stretch * 0.5;
      npy[i] = stretch - ppy[i];
      npx[i] = ppy[i] + stretch * 0.5;
      nny[i] = ppy[i] - stretch;
      nnx[i] = -stretch * 0.5 - ppy[i];
    }
  }

  static const int size = 1024;
  static const double stretch = math.PI;

  static const int ezis = -size;

  final Float64List ppy = new Float64List(size + 1);
  final Float64List ppx = new Float64List(size + 1);
  final Float64List pny = new Float64List(size + 1);
  final Float64List pnx = new Float64List(size + 1);
  final Float64List npy = new Float64List(size + 1);
  final Float64List npx = new Float64List(size + 1);
  final Float64List nny = new Float64List(size + 1);
  final Float64List nnx = new Float64List(size + 1);
}

class GameMath {
  static final _Atan2Constants _atan2 = new _Atan2Constants();

  static double atan2(double y, double x) {
    if (x >= 0) {
      if (y >= 0) {
        if (x >= y)
          return _atan2.ppy[(_Atan2Constants.size * y / x + 0.5).floor()];
        else
          return _atan2.ppx[(_Atan2Constants.size * x / y + 0.5).floor()];
      } else {
        if (x >= -y)
          return _atan2.pny[(_Atan2Constants.ezis * y / x + 0.5).floor()];
        else
          return _atan2.pnx[(_Atan2Constants.ezis * x / y + 0.5).floor()];
      }
    } else {
      if (y >= 0) {
        if (-x >= y)
          return _atan2.npy[(_Atan2Constants.ezis * y / x + 0.5).floor()];
        else
          return _atan2.npx[(_Atan2Constants.ezis * x / y + 0.5).floor()];
      } else {
        if (x <= y)
          return _atan2.nny[(_Atan2Constants.size * y / x + 0.5).floor()];
        else
          return _atan2.nnx[(_Atan2Constants.size * x / y + 0.5).floor()];
      }
    }
  }
}
