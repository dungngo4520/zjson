const val = @import("value.zig");
const str = @import("stringify.zig");
const prs = @import("parse.zig");
const conv = @import("convert.zig");

// Re-export all public APIs
pub const Error = val.Error;
pub const Value = val.Value;
pub const Pair = val.Pair;
pub const StringifyOptions = val.StringifyOptions;
pub const ParseOptions = val.ParseOptions;
pub const ParseError = val.ParseError;

pub const stringify = str.stringify;
pub const stringifyAlloc = str.stringifyAlloc;

pub const parse = prs.parse;
pub const parseWithError = prs.parseWithError;
pub const getLastParseError = prs.getLastParseError;
pub const freeValue = prs.freeValue;

// Value conversion functions
pub const toI64 = conv.toI64;
pub const toI32 = conv.toI32;
pub const toU64 = conv.toU64;
pub const toU32 = conv.toU32;
pub const toF64 = conv.toF64;
pub const toF32 = conv.toF32;
pub const toString = conv.toString;
pub const toBool = conv.toBool;
pub const isNull = conv.isNull;
pub const arrayLen = conv.arrayLen;
pub const objectLen = conv.objectLen;
pub const getObjectField = conv.getObjectField;
pub const getArrayElement = conv.getArrayElement;
pub const getNumberString = conv.getNumberString;
