# Architecture Compatibility Matrix

As Program 1 and later programs evolve independently, this matrix acts as the authoritative source for version compatibility across platform packages.

| Component        | Version | Compatible With                                |
| ---------------- | ------- | ---------------------------------------------- |
| platform_core    | 0.1.0   | logging 0.1.0+, events 0.1.0+, settings 0.1.0+ |
| platform_events  | 0.1.0   | core 0.1.0+                                    |
| platform_storage | 0.1.0   | settings 0.1.0+, filesystem 0.1.0+, core 0.1.0+|
| platform_jobs    | 0.1.0   | events 0.1.0+, storage 0.1.0+, core 0.1.0+     |
| platform_logging | 0.1.0   | core 0.1.0+                                    |
| platform_settings| 0.1.0   | core 0.1.0+                                    |
| platform_filesystem| 0.1.0 | core 0.1.0+                                    |
| design_system    | 0.1.0   | framework agnostic                             |
