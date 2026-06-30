import 'dart:async';

class NegotiationRequest {
  NegotiationRequest(this.requiredCapabilities);
  final List<String> requiredCapabilities;
}

class NegotiationResponse {
  NegotiationResponse(this.accepted, this.fallbackRequired);
  final bool accepted;
  final bool fallbackRequired;
}

abstract class CapabilityNegotiator {
  Future<NegotiationResponse> negotiate(NegotiationRequest request);
}
