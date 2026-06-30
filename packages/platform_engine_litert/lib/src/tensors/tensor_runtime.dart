abstract interface class TensorRuntime {
  void allocateTensors();
  void freeTensors();
  void resizeInputTensor(int tensorIndex, List<int> shape);
}
