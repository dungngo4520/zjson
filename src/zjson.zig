const value_mod = @import("core/value.zig");
const marshal_mod = @import("serialization/marshal.zig");
const parse_mod = @import("parsing/parse.zig");
const unmarshal_mod = @import("deserialization/unmarshal.zig");
const stream_parse_mod = @import("parsing/stream_parse.zig");
const stream_write_mod = @import("serialization/stream_write.zig");
const pointer_mod = @import("query/pointer.zig");
const jsonpath_mod = @import("query/jsonpath.zig");

// Core types
pub const Error = value_mod.Error;
pub const Value = value_mod.Value;
pub const Pair = value_mod.Pair;
pub const ParseOptions = value_mod.ParseOptions;
pub const MarshalOptions = value_mod.MarshalOptions;
pub const ParseResult = value_mod.ParseResult;

// Main functions
pub const parse = parse_mod.parse;
pub const marshal = marshal_mod.marshal;
pub const marshalAlloc = marshal_mod.marshalAlloc;
pub const unmarshal = unmarshal_mod.unmarshal;

// Value utilities
pub const value = struct {
    pub const as = value_mod.as;
    pub const isNull = value_mod.isNull;
    pub const getField = value_mod.getField;
    pub const getIndex = value_mod.getIndex;
    pub const arrayLen = value_mod.arrayLen;
    pub const objectLen = value_mod.objectLen;
    pub const getNumberString = value_mod.getNumberString;
    pub const getFieldAs = unmarshal_mod.getFieldAs;
    pub const arrayAs = unmarshal_mod.arrayAs;
};

// JSON Pointer (RFC 6901)
pub const pointer = struct {
    pub const get = pointer_mod.getPointer;
    pub const getAs = pointer_mod.getPointerAs;
    pub const has = pointer_mod.hasPointer;
};

// JSONPath query
pub const path = struct {
    pub const query = jsonpath_mod.query;
    pub const queryOne = jsonpath_mod.queryOne;
};

// Streaming API
pub const stream = struct {
    pub const Parser = stream_parse_mod.StreamParser;
    pub const parser = stream_parse_mod.streamParser;
    pub const Writer = stream_write_mod.StreamWriter;
    pub const writer = stream_write_mod.streamWriter;
    pub const Token = stream_parse_mod.Token;
    pub const TokenType = stream_parse_mod.TokenType;
};
