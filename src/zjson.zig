const value_mod = @import("core/value.zig");
const marshal_mod = @import("serialization/marshal.zig");
const parse_mod = @import("parsing/parse.zig");
const unmarshal_mod = @import("deserialization/unmarshal.zig");
const stream_parse_mod = @import("parsing/stream_parse.zig");
const stream_write_mod = @import("serialization/stream_write.zig");
const lexer_mod = @import("parsing/lexer.zig");
const escape_mod = @import("utils/escape.zig");
const error_mod = @import("utils/error.zig");

// Re-export all public APIs
pub const Error = value_mod.Error;
pub const Value = value_mod.Value;
pub const Pair = value_mod.Pair;
pub const MarshalOptions = value_mod.MarshalOptions;
pub const ParseOptions = value_mod.ParseOptions;
pub const ParseResult = value_mod.ParseResult;
pub const ParseErrorInfo = value_mod.ParseErrorInfo;

pub const marshal = marshal_mod.marshal;
pub const marshalAlloc = marshal_mod.marshalAlloc;

pub const parse = parse_mod.parse;
pub const lastParseErrorInfo = parse_mod.lastParseErrorInfo;
pub const writeParseErrorIndicator = error_mod.writeParseErrorIndicator;

// Lexer types (for advanced use and testing)
pub const SliceLexer = lexer_mod.SliceLexer;
pub const BufferedLexer = lexer_mod.BufferedLexer;
pub const SliceInput = lexer_mod.SliceInput;
pub const BufferedInput = lexer_mod.BufferedInput;
pub const Position = lexer_mod.Position;
pub const StringResult = lexer_mod.StringResult;
pub const LexerError = lexer_mod.Error;

// Escape utilities (for advanced use and testing)
pub const escape = escape_mod;

pub const toI64 = value_mod.toI64;
pub const toI32 = value_mod.toI32;
pub const toU64 = value_mod.toU64;
pub const toU32 = value_mod.toU32;
pub const toF64 = value_mod.toF64;
pub const toF32 = value_mod.toF32;
pub const toString = value_mod.toString;
pub const toBool = value_mod.toBool;
pub const isNull = value_mod.isNull;
pub const arrayLen = value_mod.arrayLen;
pub const objectLen = value_mod.objectLen;
pub const getObjectField = value_mod.getObjectField;
pub const getArrayElement = value_mod.getArrayElement;
pub const getNumberString = value_mod.getNumberString;

// Unmarshal functions for deserializing into typed structs
pub const unmarshal = unmarshal_mod.unmarshal;
pub const getFieldAs = unmarshal_mod.getFieldAs;
pub const arrayAs = unmarshal_mod.arrayAs;

// Streaming parser and writer
pub const StreamParser = stream_parse_mod.StreamParser;
pub const streamParser = stream_parse_mod.streamParser;
pub const Token = stream_parse_mod.Token;
pub const TokenType = stream_parse_mod.TokenType;

pub const StreamWriter = stream_write_mod.StreamWriter;
pub const streamWriter = stream_write_mod.streamWriter;
