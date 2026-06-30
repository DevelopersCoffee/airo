abstract interface class McpTransport {
  Future<void> connect();
  Future<void> disconnect();
  Stream<Map<String, dynamic>> get messages;
  void send(Map<String, dynamic> message);
}
