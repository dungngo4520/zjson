const value = @import("value.zig");
const marshaler = @import("marshal.zig");
const parser = @import("parse.zig");
const converter = @import("convert.zig");
const unmarshaller = @import("unmarshal.zig");
const custom = @import("custom.zig");
const stream_parse = @import("stream_parse.zig");
const stream_write = @import("stream_write.zig");
const lexer = @import("lexer.zig");
const escape_mod = @import("escape.zig");

// Re-export all public APIs
pub const Error = value.Error;
pub const Value = value.Value;
pub const Pair = value.Pair;
pub const MarshalOptions = value.MarshalOptions;
pub const ParseOptions = value.ParseOptions;
pub const ParseResult = value.ParseResult;
pub const ParseErrorInfo = value.ParseErrorInfo;

pub const marshal = marshaler.marshal;
pub const marshalAlloc = marshaler.marshalAlloc;

pub const parse = parser.parse;
pub const lastParseErrorInfo = parser.lastParseErrorInfo;
pub const writeParseErrorIndicator = parser.writeParseErrorIndicator;

// Lexer module (for advanced use and testing)
pub const Lexer = lexer.Lexer;
pub const Position = lexer.Position;
pub const LexerError = lexer.Error;

// Escape utilities (for advanced use and testing)
pub const escape = escape_mod;

// Value conversion functions
pub const toI64 = converter.toI64;
pub const toI32 = converter.toI32;
pub const toU64 = converter.toU64;
pub const toU32 = converter.toU32;
pub const toF64 = converter.toF64;
pub const toF32 = converter.toF32;
pub const toString = converter.toString;
pub const toBool = converter.toBool;
pub const isNull = converter.isNull;
pub const arrayLen = converter.arrayLen;
pub const objectLen = converter.objectLen;
pub const getObjectField = converter.getObjectField;
pub const getArrayElement = converter.getArrayElement;
pub const getNumberString = converter.getNumberString;

// Unmarshal functions for deserializing into typed structs
pub const unmarshal = unmarshaller.unmarshal;
pub const getFieldAs = unmarshaller.getFieldAs;
pub const arrayAs = unmarshaller.arrayAs;

// Custom marshaler support
pub const hasCustomMarshal = custom.hasCustomMarshal;
pub const hasCustomUnmarshal = custom.hasCustomUnmarshal;
pub const marshalWithCustom = custom.marshalWithCustom;
pub const unmarshalWithCustom = custom.unmarshalWithCustom;

// Streaming parser and writer
pub const StreamParser = stream_parse.StreamParser;
pub const streamParser = stream_parse.streamParser;
pub const Token = stream_parse.Token;
pub const TokenType = stream_parse.TokenType;

pub const StreamWriter = stream_write.StreamWriter;
pub const streamWriter = stream_write.streamWriter;
