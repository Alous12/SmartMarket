class RenderMetrics {
  const RenderMetrics({
    this.fps = 0,
    this.drawCalls = 0,
    this.triangles = 0,
    this.loadMilliseconds = 0,
  });

  final double fps;
  final int drawCalls;
  final int triangles;
  final int loadMilliseconds;
}
