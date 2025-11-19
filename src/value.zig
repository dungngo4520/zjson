const std = @import("std");

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

/// Detailed parse error with position information
pub const ParseError = struct {
    error_type: Error,
    pos: usize,
    line: usize,
    column: usize,

    pub fn format(self: ParseError, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        return std.fmt.format(writer, "{s} at line {d}, column {d} (pos {d})", .{
            @errorName(self.error_type),
            self.line,
            self.column,
            self.pos,
        });
    }
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
