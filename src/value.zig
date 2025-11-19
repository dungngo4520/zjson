pub const Error = error{
    UnexpectedEnd,
    InvalidSyntax,
    InvalidEscape,
    InvalidNumber,
    ExpectedColon,
    ExpectedCommaOrEnd,
    ExpectedValue,
    TrailingCharacters,
    OutOfMemory,
};

pub const Value = union(enum) {
    Null,
    Bool: bool,
    Number: []const u8,
    String: []const u8,
    Object: []const Pair,
    Array: []const Value,
};

pub const Pair = struct {
    key: []const u8,
    value: Value,
};

pub const StringifyOptions = struct {
    pretty: bool = false,
    indent: u32 = 2,
    omit_null: bool = true,
    sort_keys: bool = false,
};

pub const ParseOptions = struct {
    allow_comments: bool = false,
    allow_trailing_commas: bool = false,
    allow_control_chars: bool = false,
};
