/// Marshal output options
pub const MarshalOptions = struct {
    pretty: bool = false,
    indent: u32 = 2,
    omit_null: bool = true,
    sort_keys: bool = false,
    use_tabs: bool = false,
    compact_arrays: bool = false,
    line_ending: LineEnding = .lf,

    pub const LineEnding = enum {
        lf,
        crlf,
    };
};

/// Duplicate key handling policy
pub const DuplicateKeyPolicy = enum {
    keep_last,
    keep_first,
    reject,
};

/// Parse input options
pub const ParseOptions = struct {
    allow_comments: bool = false,
    allow_trailing_commas: bool = false,
    max_depth: usize = 128,
    max_document_size: usize = 10_000_000,
    duplicate_key_policy: DuplicateKeyPolicy = .keep_last,
};
