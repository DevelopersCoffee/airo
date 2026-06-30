class BootstrapContext {
  // Shared immutable context. Dependencies are fetched via Riverpod providers
  // during task initialization rather than stored directly in the context,
  // to adhere to the Riverpod architecture. This class serves as a scope.
  
  const BootstrapContext();
}
