//! Every domain-separation string in the crate, in one place.
//!
//! The two original strings happened not to be prefixes of one another. That
//! was luck, not construction. A registry plus the test below makes it
//! construction: adding `"airo-mind/root"` beside
//! `"airo-mind/root-identity/v1"` now fails the build rather than silently
//! weakening separation.

pub const ROOT_IDENTITY: &[u8] = b"airo-mind/root-identity/v1";
pub const RECOVERY_PACKAGE: &[u8] = b"airo-mind/recovery-package/v1";
pub const DEVICE_CERTIFICATE: &[u8] = b"airo-mind/device-certificate/v1";
pub const CONTENT_WRAPPING: &[u8] = b"airo-mind/content-wrapping/v1";
pub const PACKAGE_HEADER: &[u8] = b"airo-mind/recovery-package-header/v1";

/// Every registered string. Add here when adding a constant above.
#[cfg_attr(not(test), allow(dead_code))]
pub const ALL: &[&[u8]] = &[
    ROOT_IDENTITY,
    RECOVERY_PACKAGE,
    DEVICE_CERTIFICATE,
    CONTENT_WRAPPING,
    PACKAGE_HEADER,
];

#[cfg(test)]
mod tests {
    use super::*;
    #[allow(unused_imports)]
    use crate::vault::identifier::{cid, content_id, ContentId, DeviceId};

    #[test]
    fn no_domain_string_is_a_prefix_of_another() {
        for (i, a) in ALL.iter().enumerate() {
            for (j, b) in ALL.iter().enumerate() {
                if i == j {
                    continue;
                }
                assert!(
                    !b.starts_with(a),
                    "{} is a prefix of {}",
                    String::from_utf8_lossy(a),
                    String::from_utf8_lossy(b)
                );
            }
        }
    }

    #[test]
    fn every_domain_string_is_versioned() {
        for s in ALL {
            let text = String::from_utf8_lossy(s);
            assert!(text.starts_with("airo-mind/"), "{text} lacks the namespace");
            assert!(text.ends_with("/v1"), "{text} lacks a version suffix");
        }
    }
}
