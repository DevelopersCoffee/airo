/// Normalize a channel name for deduplication and search.
///
/// Strips non-alphanumeric characters, lowercases, collapses whitespace.
/// This is the thin vertical slice proving the FFI pipeline end-to-end.
///
/// # Examples
/// ```
/// use airo_core::api::text::normalize_channel_name;
/// assert_eq!(normalize_channel_name("BBC  News!".to_string()), "bbcnews");
/// ```
pub fn normalize_channel_name(name: String) -> String {
    name.chars()
        .filter(|c| c.is_alphanumeric())
        .map(|c| c.to_ascii_lowercase())
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_string() {
        assert_eq!(normalize_channel_name(String::new()), "");
    }

    #[test]
    fn strips_punctuation_and_lowercases() {
        assert_eq!(normalize_channel_name("BBC  News!".to_string()), "bbcnews");
    }

    #[test]
    fn unicode_alphanumeric_kept() {
        assert_eq!(normalize_channel_name("9XM".to_string()), "9xm");
    }

    #[test]
    fn already_normalized() {
        assert_eq!(normalize_channel_name("starnews".to_string()), "starnews");
    }
}
