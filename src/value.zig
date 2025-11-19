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
