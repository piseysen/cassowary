part of sprites;

class _Particle {
  Vector2 pos;
  Vector2 startPos;

  double colorPos;
  double deltaColorPos;

  double size;
  double deltaSize;

  double rotation;
  double deltaRotation;

  double timeToLive;

  Vector2 dir;

  _ParticleAccelerations accelerations;

  Float64List simpleColorSequence;

  ColorSequence colorSequence;
}

class _ParticleAccelerations {
  double radialAccel;
  double tangentialAccel;
}

class ParticleSystem extends Node {

  Texture texture;

  double life;
  double lifeVar;

  Point posVar;

  double startSize;
  double startSizeVar;

  double endSize;
  double endSizeVar;

  double startRotation;
  double startRotationVar;

  double endRotation;
  double endRotationVar;

  bool rotateToMovement;

  double direction;
  double directionVar;

  double speed;
  double speedVar;

  double radialAcceleration;
  double radialAccelerationVar;

  double tangentialAcceleration;
  double tangentialAccelerationVar;

  Vector2 gravity;

  int maxParticles;
  int numParticlesToEmit;
  double emissionRate;
  bool autoRemoveOnFinish;

  ColorSequence colorSequence;
  int alphaVar;
  int redVar;
  int greenVar;
  int blueVar;
  TransferMode colorTransferMode;
  TransferMode transferMode;

  List<_Particle> _particles;

  double _emitCounter;
  int _numEmittedParticles = 0;

  static Paint _paint = new Paint()
    ..setFilterQuality(FilterQuality.low)
    ..isAntiAlias = false;

  ParticleSystem(this.texture,
                 {this.life: 1.5,
                  this.lifeVar: 1.0,
                  this.posVar: Point.origin,
                  this.startSize: 2.5,
                  this.startSizeVar: 0.5,
                  this.endSize: 0.0,
                  this.endSizeVar: 0.0,
                  this.startRotation: 0.0,
                  this.startRotationVar: 0.0,
                  this.endRotation: 0.0,
                  this.endRotationVar: 0.0,
                  this.rotateToMovement : false,
                  this.direction: 0.0,
                  this.directionVar: 360.0,
                  this.speed: 100.0,
                  this.speedVar: 50.0,
                  this.radialAcceleration: 0.0,
                  this.radialAccelerationVar: 0.0,
                  this.tangentialAcceleration: 0.0,
                  this.tangentialAccelerationVar: 0.0,
                  this.gravity,
                  this.maxParticles: 100,
                  this.emissionRate: 50.0,
                  this.colorSequence,
                  this.alphaVar: 0,
                  this.redVar: 0,
                  this.greenVar: 0,
                  this.blueVar: 0,
                  this.colorTransferMode: TransferMode.multiply,
                  this.transferMode: TransferMode.plus,
                  this.numParticlesToEmit: 0,
                  this.autoRemoveOnFinish: true}) {
    _particles = new List<_Particle>();
    _emitCounter = 0.0;
    // _elapsedTime = 0.0;
    if (gravity == null) gravity = new Vector2.zero();
    if (colorSequence == null) colorSequence = new ColorSequence.fromStartAndEndColor(new Color(0xffffffff), new Color(0x00ffffff));
  }

  void update(double dt) {
    // TODO: Fix this (it's a temp fix for low framerates)
    if (dt > 0.1) dt = 0.1;

    // Create new particles
    double rate = 1.0 / emissionRate;

    if (_particles.length < maxParticles) {
      _emitCounter += dt;
    }

    while(_particles.length < maxParticles
       && _emitCounter > rate
       && (numParticlesToEmit == 0 || _numEmittedParticles < numParticlesToEmit)) {
      // Add a new particle
      _addParticle();
      _emitCounter -= rate;
    }

    // _elapsedTime += dt;

    // Iterate over all particles
    for (int i = _particles.length -1; i >= 0; i--) {
      _Particle particle = _particles[i];

      // Manage life time
      particle.timeToLive -= dt;
      if (particle.timeToLive <= 0) {
        _particles.removeAt(i);
        continue;
      }

      // Update the particle

      if (particle.accelerations != null) {
      // Radial acceleration
      Vector2 radial;
        if (particle.pos[0] != 0 || particle.pos[1] != 0) {
          radial = new Vector2.copy(particle.pos).normalize();
        } else {
          radial = new Vector2.zero();
        }
        Vector2 tangential = new Vector2.copy(radial);
        radial.scale(particle.accelerations.radialAccel);

        // Tangential acceleration
        double newY = tangential.x;
        tangential.x = -tangential.y;
        tangential.y = newY;
        tangential.scale(particle.accelerations.tangentialAccel);

        // (gravity + radial + tangential) * dt
        Vector2 accel = (gravity + radial + tangential).scale(dt);
        particle.dir += accel;
      } else if (gravity[0] != 0.0 || gravity[1] != 0) {
        // gravity
        Vector2 accel = gravity.scale(dt);
        particle.dir += accel;
      }

      // Update particle position
      particle.pos[0] += particle.dir[0] * dt;
      particle.pos[1] += particle.dir[1] * dt;

      // Size
      particle.size = math.max(particle.size + particle.deltaSize * dt, 0.0);

      // Angle
      particle.rotation += particle.deltaRotation * dt;

      // Color
      if (particle.simpleColorSequence != null) {
        for (int i = 0; i < 4; i++) {
          particle.simpleColorSequence[i] += particle.simpleColorSequence[i + 4] * dt;
        }
      } else {
        particle.colorPos = math.min(particle.colorPos + particle.deltaColorPos * dt, 1.0);
      }
    }

    if (autoRemoveOnFinish && _particles.length == 0 && _numEmittedParticles > 0) {
      if (parent != null) removeFromParent();
    }
  }

  void _addParticle() {

    _Particle particle = new _Particle();

    // Time to live
    particle.timeToLive = math.max(life + lifeVar * randomSignedDouble(), 0.0);

    // Position
    Point srcPos = Point.origin;
    particle.pos = new Vector2(srcPos.x + posVar.x * randomSignedDouble(),
                               srcPos.y + posVar.y * randomSignedDouble());

    // Size
    particle.size = math.max(startSize + startSizeVar * randomSignedDouble(), 0.0);
    double endSizeFinal = math.max(endSize + endSizeVar * randomSignedDouble(), 0.0);
    particle.deltaSize = (endSizeFinal - particle.size) / particle.timeToLive;

    // Rotation
    particle.rotation = startRotation + startRotationVar * randomSignedDouble();
    double endRotationFinal = endRotation + endRotationVar * randomSignedDouble();
    particle.deltaRotation = (endRotationFinal - particle.rotation) / particle.timeToLive;

    // Direction
    double dirRadians = convertDegrees2Radians(direction + directionVar * randomSignedDouble());
    Vector2 dirVector = new Vector2(math.cos(dirRadians), math.sin(dirRadians));
    double speedFinal = speed + speedVar * randomSignedDouble();
    particle.dir = dirVector.scale(speedFinal);

    // Accelerations
    if (radialAcceleration != 0.0 || radialAccelerationVar != 0.0 ||
        tangentialAcceleration != 0.0 || tangentialAccelerationVar != 0.0) {
      particle.accelerations = new _ParticleAccelerations();

      // Radial acceleration
      particle.accelerations.radialAccel = radialAcceleration + radialAccelerationVar * randomSignedDouble();

      // Tangential acceleration
      particle.accelerations.tangentialAccel = tangentialAcceleration + tangentialAccelerationVar * randomSignedDouble();
    }

    // Color
    particle.colorPos = 0.0;
    particle.deltaColorPos = 1.0 / particle.timeToLive;

    if (alphaVar != 0 || redVar != 0 || greenVar != 0 || blueVar != 0) {
      particle.colorSequence = _ColorSequenceUtil.copyWithVariance(colorSequence, alphaVar, redVar, greenVar, blueVar);
    }

    // Optimizes the case where there are only two colors in the sequence
    if (colorSequence.colors.length == 2) {
      Color startColor;
      Color endColor;

      if (particle.colorSequence != null) {
        startColor = particle.colorSequence.colors[0];
        endColor = particle.colorSequence.colors[1];
      } else {
        startColor = colorSequence.colors[0];
        endColor = colorSequence.colors[1];
      }

      // First 4 elements are start ARGB, last 4 are delta ARGB
      particle.simpleColorSequence = new Float64List(8);
      particle.simpleColorSequence[0] = startColor.alpha.toDouble();
      particle.simpleColorSequence[1] = startColor.red.toDouble();
      particle.simpleColorSequence[2] = startColor.green.toDouble();
      particle.simpleColorSequence[3] = startColor.blue.toDouble();

      particle.simpleColorSequence[4] = (endColor.alpha.toDouble() - startColor.alpha.toDouble()) / particle.timeToLive;
      particle.simpleColorSequence[5] = (endColor.red.toDouble() - startColor.red.toDouble()) / particle.timeToLive;
      particle.simpleColorSequence[6] = (endColor.green.toDouble() - startColor.green.toDouble()) / particle.timeToLive;
      particle.simpleColorSequence[7] = (endColor.blue.toDouble() - startColor.blue.toDouble()) / particle.timeToLive;
    }

    _particles.add(particle);
    _numEmittedParticles++;
  }

  void paint(PaintingCanvas canvas) {

    List<RSTransform> transforms = [];
    List<Rect> rects = [];
    List<Color> colors = [];

    _paint.setTransferMode(transferMode);

    for (_Particle particle in _particles) {
      // Rect
      Rect rect = texture.frame;
      rects.add(rect);

      // Transform
      double scos;
      double ssin;
      if (rotateToMovement) {
        double extraRotation = GameMath.atan2(particle.dir[1], particle.dir[0]);
        scos = math.cos(convertDegrees2Radians(particle.rotation) + extraRotation) * particle.size;
        ssin = math.sin(convertDegrees2Radians(particle.rotation) + extraRotation) * particle.size;
      } else if (particle.rotation != 0.0) {
        scos = math.cos(convertDegrees2Radians(particle.rotation)) * particle.size;
        ssin = math.sin(convertDegrees2Radians(particle.rotation)) * particle.size;
      } else {
        scos = particle.size;
        ssin = 0.0;
      }
      double ax = rect.width / 2;
      double ay = rect.height / 2;
      double tx = particle.pos[0] + -scos * ax + ssin * ay;
      double ty = particle.pos[1] + -ssin * ax - scos * ay;
      RSTransform transform = new RSTransform(scos, ssin, tx, ty);
      transforms.add(transform);

      // Color
      if (particle.simpleColorSequence != null) {
        Color particleColor = new Color.fromARGB(
          particle.simpleColorSequence[0].toInt().clamp(0, 255),
          particle.simpleColorSequence[1].toInt().clamp(0, 255),
          particle.simpleColorSequence[2].toInt().clamp(0, 255),
          particle.simpleColorSequence[3].toInt().clamp(0, 255));
        colors.add(particleColor);
      } else {
        Color particleColor;
        if (particle.colorSequence != null) {
          particleColor = particle.colorSequence.colorAtPosition(particle.colorPos);
        } else {
          particleColor = colorSequence.colorAtPosition(particle.colorPos);
        }
        colors.add(particleColor);
      }
    }

    canvas.drawAtlas(texture.image, transforms, rects, colors,
      TransferMode.modulate, null, _paint);
  }
}

class _ColorSequenceUtil {
  static ColorSequence copyWithVariance(
    ColorSequence sequence,
    int alphaVar,
    int redVar,
    int greenVar,
    int blueVar
  ) {
    ColorSequence copy = new ColorSequence.copy(sequence);

    int i = 0;
    for (Color color in sequence.colors) {
      int aDelta = ((randomDouble() * 2.0 - 1.0) * alphaVar).toInt();
      int rDelta = ((randomDouble() * 2.0 - 1.0) * redVar).toInt();
      int gDelta = ((randomDouble() * 2.0 - 1.0) * greenVar).toInt();
      int bDelta = ((randomDouble() * 2.0 - 1.0) * blueVar).toInt();

      int aNew = (color.alpha + aDelta).clamp(0, 255);
      int rNew = (color.red + rDelta).clamp(0, 255);
      int gNew = (color.green + gDelta).clamp(0, 255);
      int bNew = (color.blue + bDelta).clamp(0, 255);

      copy.colors[i] = new Color.fromARGB(aNew, rNew, gNew, bNew);
      i++;
    }

    return copy;
  }
}
