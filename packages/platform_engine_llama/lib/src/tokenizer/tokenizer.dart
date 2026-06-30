abstract interface class Tokenizer {
  List<int> encode(String text);
  String decode(List<int> tokens);
}

class LlamaTokenizer implements Tokenizer {
  @override
  List<int> encode(String text) {
    // Mock implementation for now
    return [1, 2, 3];
  }

  @override
  String decode(List<int> tokens) {
    // Mock implementation for now
    return 'mock decoded text';
  }
}
