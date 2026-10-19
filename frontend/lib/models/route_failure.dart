enum RouteFailureCode {
  invalidOrigin,
  invalidDestination,
  timeout,
  network,
  http,
  noRoute,
  noSegment,
  invalidResponse,
  rateLimited,
  unavailable,
}

class RouteFailure implements Exception {
  final RouteFailureCode code;
  final int? status;
  const RouteFailure(this.code, {this.status});
}
