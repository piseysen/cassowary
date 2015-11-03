// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import "dart:math" as math;
import "dart:typed_data";

class _Vector {
  _Vector(int size)
  : _offset = 0, _length = size, _elements = new Float64List(size);

  _Vector.fromValues(List<double> values)
  : _offset = 0, _length = values.length, _elements = values;

  _Vector.fromVOL(List<double> values, int offset, int length)
  : _offset = offset, _length = length, _elements = values;

  int get length => _length;

  operator [](int i) => _elements[i + _offset];
  operator []=(int i, double value) => _elements[i + _offset] = value;

  operator *(_Vector a) {
    double result = 0.0;
    for (int i = 0; i < _length; i++) {
      result += this[i] * a[i];
    }
    return result;
  }

  double norm() => math.sqrt(this * this);

  String toString() {
    String result = "";
    for (int i = 0; i < _length; i++) {
      if (i > 0)
        result += ", ";
        result += this[i].toString();
    }
    return result;
  }

  final int _offset;
  final int _length;
  final List<double> _elements;
}

class _Matrix {
  _Matrix(int rows, int cols)
  : _rows = rows,
    _columns = cols,
    _elements = new Float64List(rows * cols);

  double get(int row, int col) => _elements[row * _columns + col];
  void set(int row, int col, double value) {
    _elements[row * _columns + col] = value;
  }

  _Vector getRow(int row) => new _Vector.fromVOL(
    _elements,
    row * _columns,
    _columns
  );

  String toString() {
    String result = "";
    for (int i = 0; i < _rows; i++) {
      if (i > 0)
        result += "; ";
      for (int j = 0; j < _columns; j++) {
        if (j > 0)
          result += ", ";
        result += get(i, j).toString();
      }
    }
    return result;
  }

  final int _rows;
  final int _columns;
  final List<double> _elements;
}

class PolynomialFit {
  PolynomialFit(int degree) : coefficients = new Float64List(degree + 1);

  final List<double> coefficients;
  double confidence;
}

class LeastSquaresSolver {
  LeastSquaresSolver(this.x, this.y, this.w) {
    assert(x.length == y.length);
    assert(y.length == w.length);
  }

  final List<double> x;
  final List<double> y;
  final List<double> w;

  PolynomialFit solve(int degree) {
    if (degree > x.length) // not enough data to fit a curve
      return null;

    PolynomialFit result = new PolynomialFit(degree);

    // Shorthands for the purpose of notation equivalence to original C++ code
    final int m = x.length;
    final int n = degree + 1;

    // Expand the X vector to a matrix A, pre-multiplied by the weights.
    _Matrix a = new _Matrix(n, m);
    for (int h = 0; h < m; h++) {
      a.set(0, h, w[h]);
      for (int i = 1; i < n; i++) {
        a.set(i, h, a.get(i - 1, h) * x[h]);
      }
    }

    // Apply the Gram-Schmidt process to A to obtain its QR decomposition.

    // Orthonormal basis, column-major ordVectorer.
    _Matrix q = new _Matrix(n, m);
    // Upper triangular matrix, row-major order.
    _Matrix r = new _Matrix(n, n);
    for (int j = 0; j < n; j++) {
      for (int h = 0; h < m; h++) {
        q.set(j, h, a.get(j, h));
      }
      for (int i = 0; i < j; i++) {
        double dot = q.getRow(j) * q.getRow(i);
        for (int h = 0; h < m; h++) {
          q.set(j, h, q.get(j, h) - dot * q.get(i, h));
        }
      }

      double norm = q.getRow(j).norm();
      if (norm < 0.000001) {
        // vectors are linearly dependent or zero so no solution
        return null;
      }

      double inverseNorm = 1.0 / norm;
      for (int h = 0; h < m; h++) {
        q.set(j, h, q.get(j, h) * inverseNorm);
      }
      for (int i = 0; i < n; i++) {
        r.set(j, i, i < j ? 0.0 : q.getRow(j) * a.getRow(i));
      }
    }

    // Solve R B = Qt W Y to find B.  This is easy because R is upper triangular.
    // We just work from bottom-right to top-left calculating B's coefficients.
    _Vector wy = new _Vector(m);
    for (int h = 0; h < m; h++) {
      wy[h] = y[h] * w[h];
    }
    for (int i = n; i-- != 0;) {
      result.coefficients[i] = q.getRow(i) * wy;
      for (int j = n - 1; j > i; j--) {
        result.coefficients[i] -= r.get(i, j) * result.coefficients[j];
      }
      result.coefficients[i] /= r.get(i, i);
    }

    // Calculate the coefficient of determination (confidence) as:
    // 1 - (sumSquaredError / sumSquaredTotal)
    // where sumSquaredError is the residual sum of squares (variance of the
    // error), and sumSquaredTotal is the total sum of squares (variance of the
    // data) where each has been weighted.
    double yMean = 0.0;
    for (int h = 0; h < m; h++) {
      yMean += y[h];
    }
    yMean /= m;

    double sumSquaredError = 0.0;
    double sumSquaredTotal = 0.0;
    for (int h = 0; h < m; h++) {
      double err = y[h] - result.coefficients[0];
      double term = 1.0;
      for (int i = 1; i < n; i++) {
        term *= x[h];
        err -= term * result.coefficients[i];
      }
      sumSquaredError += w[h] * w[h] * err * err;
      double v = y[h] - yMean;
      sumSquaredTotal += w[h] * w[h] * v * v;
    }

    result.confidence = sumSquaredTotal > 0.000001 ?
      1.0 - (sumSquaredError / sumSquaredTotal) :
      1.0;

    return result;
  }

}
