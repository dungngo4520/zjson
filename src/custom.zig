const std = @import("std");
const value_mod = @import("value.zig");
const marshal_mod = @import("marshal.zig");
const unmarshal_mod = @import("unmarshal.zig");

pub const Value = value_mod.Value;
pub const Error = value_mod.Error;
pub const MarshalOptions = value_mod.MarshalOptions;

/// Check if a type has a custom marshal method
pub fn hasCustomMarshal(comptime T: type) bool {
    return @hasDecl(T, "marshal");
}

/// Check if a type has a custom unmarshal method
pub fn hasCustomUnmarshal(comptime T: type) bool {
    return @hasDecl(T, "unmarshal");
}

/// Marshal a value, using custom marshal if available
pub fn marshalWithCustom(value: anytype, allocator: std.mem.Allocator, options: MarshalOptions) std.mem.Allocator.Error![]u8 {
    const T = @TypeOf(value);

    // Check if T has a custom marshal method
    if (comptime hasCustomMarshal(T)) {
        // Custom marshal should return a Value
        const custom_value = value.marshal();
        return marshal_mod.marshalAlloc(custom_value, allocator, options);
    }

    // Fall back to default marshal
    return marshal_mod.marshalAlloc(value, allocator, options);
}

/// Unmarshal a Value into a target type, using custom unmarshal if available
pub fn unmarshalWithCustom(comptime T: type, val: Value, allocator: std.mem.Allocator) Error!T {
    // Check if T has a custom unmarshal method
    if (comptime hasCustomUnmarshal(T)) {
        // Custom unmarshal should accept a Value and return T
        return T.unmarshal(val, allocator);
    }

    // Fall back to default unmarshal
    return unmarshal_mod.unmarshal(T, val, allocator);
}
