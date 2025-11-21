const value = @import("value.zig");
const marshaler = @import("marshal.zig");
const parser = @import("parse.zig");
const converter = @import("convert.zig");
const unmarshaller = @import("unmarshal.zig");
const custom = @import("custom.zig");

// Re-export all public APIs
pub const Error = value.Error;
pub const Value = value.Value;
pub const Pair = value.Pair;
pub const MarshalOptions = value.MarshalOptions;
pub const ParseOptions = value.ParseOptions;
pub const ParseResult = value.ParseResult;

pub const marshal = marshaler.marshal;
pub const marshalAlloc = marshaler.marshalAlloc;

pub const parseToArena = parser.parseToArena;

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
