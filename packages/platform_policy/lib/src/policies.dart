import 'package:platform_identity/platform_identity.dart';
import 'package:platform_security/platform_security.dart';
import 'package:platform_resources/platform_resources.dart';

abstract class PlatformPolicy {
  String get name;
  String get description;
}

abstract class DependencyPolicy extends PlatformPolicy {
  bool canDependOn(PlatformIdentifier dependent, PlatformIdentifier target);
}

abstract class ResourcePolicy extends PlatformPolicy {
  bool canAllocate(PlatformIdentifier context, PlatformResource resource);
}

abstract class SchedulingPolicy extends PlatformPolicy {
  int calculatePriority(PlatformIdentifier task);
}

abstract class PermissionPolicy extends PlatformPolicy {
  bool isPermissionAllowed(PlatformIdentifier subject, Permission permission);
}

class PolicyManager {
  final List<DependencyPolicy> _dependencyPolicies = [];
  final List<ResourcePolicy> _resourcePolicies = [];
  final List<SchedulingPolicy> _schedulingPolicies = [];
  final List<PermissionPolicy> _permissionPolicies = [];
  
  void registerDependencyPolicy(DependencyPolicy policy) => _dependencyPolicies.add(policy);
  void registerResourcePolicy(ResourcePolicy policy) => _resourcePolicies.add(policy);
  void registerSchedulingPolicy(SchedulingPolicy policy) => _schedulingPolicies.add(policy);
  void registerPermissionPolicy(PermissionPolicy policy) => _permissionPolicies.add(policy);
  
  bool evaluateDependency(PlatformIdentifier dependent, PlatformIdentifier target) {
    for (final p in _dependencyPolicies) {
      if (!p.canDependOn(dependent, target)) return false;
    }
    return true;
  }
}
