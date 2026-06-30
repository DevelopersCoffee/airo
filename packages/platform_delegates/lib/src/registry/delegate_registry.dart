import '../types/delegate_types.dart';

abstract interface class DelegateProvider {
  List<DelegateType> getAvailableDelegates();
}

abstract interface class DelegateRegistry {
  void registerProvider(DelegateProvider provider);
  List<DelegateType> getAvailableDelegates();
}
