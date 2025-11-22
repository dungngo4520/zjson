const std = @import("std");
const value_mod = @import("../core/value.zig");
const escape_mod = @import("../utils/escape.zig");

pub const Error = error{
    InvalidState,
    OutOfMemory,
} || std.fs.File.WriteError;

/// Streaming JSON writer that writes directly to any writer
pub fn StreamWriter(comptime WriterType: type) type {
    return struct {
        writer: WriterType,
        state_stack: std.ArrayList(State),
        allocator: std.mem.Allocator,
        indent_level: usize,
        pretty: bool,
        indent_size: usize,
        need_comma: bool,

        const Self = @This();
        const State = enum {
            object_start,
            object_field,
            array_start,
            array_element,
            finished,
        };

        pub const Options = struct {
            pretty: bool = false,
            indent: usize = 2,
        };

        pub fn init(writer: WriterType, allocator: std.mem.Allocator, options: Options) Self {
            return .{
                .writer = writer,
                .state_stack = .{},
                .allocator = allocator,
                .indent_level = 0,
                .pretty = options.pretty,
                .indent_size = options.indent,
                .need_comma = false,
            };
        }

        pub fn deinit(self: *Self) void {
            self.state_stack.deinit(self.allocator);
        }

        /// Begin writing an object
        pub fn beginObject(self: *Self) !void {
            try self.writeCommaIfNeeded();
            try self.writer.writeByte('{');
            try self.state_stack.append(self.allocator, .object_start);
            self.indent_level += 1;
            self.need_comma = false;
        }

        /// End the current object
        pub fn endObject(self: *Self) !void {
            if (self.state_stack.items.len == 0) return Error.InvalidState;
            const state = self.state_stack.pop();
            if (state != .object_start and state != .object_field) {
                return Error.InvalidState;
            }

            self.indent_level -= 1;
            if (self.pretty and state == .object_field) {
                try self.writeNewline();
                try self.writeIndent();
            }
            try self.writer.writeByte('}');
            self.need_comma = true;
        }

        /// Begin writing an array
        pub fn beginArray(self: *Self) !void {
            try self.writeCommaIfNeeded();
            try self.writer.writeByte('[');
            try self.state_stack.append(self.allocator, .array_start);
            self.indent_level += 1;
            self.need_comma = false;
        }

        /// End the current array
        pub fn endArray(self: *Self) !void {
            if (self.state_stack.items.len == 0) return Error.InvalidState;
            const state = self.state_stack.pop();
            if (state != .array_start and state != .array_element) {
                return Error.InvalidState;
            }

            self.indent_level -= 1;
            if (self.pretty and state == .array_element) {
                try self.writeNewline();
                try self.writeIndent();
            }
            try self.writer.writeByte(']');
            self.need_comma = true;
        }

        /// Write an object field name (must be inside an object)
        pub fn writeField(self: *Self, name: []const u8) !void {
            if (self.state_stack.items.len == 0) return Error.InvalidState;
            const idx = self.state_stack.items.len - 1;
            const state = self.state_stack.items[idx];

            if (state == .object_start) {
                if (self.pretty) {
                    try self.writeNewline();
                    try self.writeIndent();
                }
                self.state_stack.items[idx] = .object_field;
            } else if (state == .object_field) {
                try self.writer.writeByte(',');
                if (self.pretty) {
                    try self.writeNewline();
                    try self.writeIndent();
                }
            } else {
                return Error.InvalidState;
            }

            try self.writeStringValue(name);
            try self.writer.writeByte(':');
            if (self.pretty) {
                try self.writer.writeByte(' ');
            }
            self.need_comma = false;
        }

        /// Write a string value
        pub fn writeString(self: *Self, value: []const u8) !void {
            try self.writeCommaIfNeeded();
            try self.writeStringValue(value);
            self.need_comma = true;
        }

        /// Write a number (as string representation)
        pub fn writeNumber(self: *Self, value: []const u8) !void {
            try self.writeCommaIfNeeded();
            try self.writer.writeAll(value);
            self.need_comma = true;
        }

        /// Write an integer
        pub fn writeInt(self: *Self, value: anytype) !void {
            try self.writeCommaIfNeeded();
            try std.fmt.format(self.writer, "{d}", .{value});
            self.need_comma = true;
        }

        /// Write a float
        pub fn writeFloat(self: *Self, value: anytype) !void {
            try self.writeCommaIfNeeded();
            try std.fmt.format(self.writer, "{d}", .{value});
            self.need_comma = true;
        }

        /// Write a boolean
        pub fn writeBool(self: *Self, value: bool) !void {
            try self.writeCommaIfNeeded();
            if (value) {
                try self.writer.writeAll("true");
            } else {
                try self.writer.writeAll("false");
            }
            self.need_comma = true;
        }

        /// Write null
        pub fn writeNull(self: *Self) !void {
            try self.writeCommaIfNeeded();
            try self.writer.writeAll("null");
            self.need_comma = true;
        }

        /// Write any Zig value (convenience method)
        pub fn writeValue(self: *Self, value: anytype) !void {
            const T = @TypeOf(value);
            const info = @typeInfo(T);

            switch (info) {
                .null => try self.writeNull(),
                .bool => try self.writeBool(value),
                .int, .comptime_int => try self.writeInt(value),
                .float, .comptime_float => try self.writeFloat(value),
                .pointer => |ptr| {
                    switch (ptr.size) {
                        .slice => {
                            if (ptr.child == u8) {
                                try self.writeString(value);
                            } else {
                                try self.beginArray();
                                for (value) |item| {
                                    try self.writeValue(item);
                                }
                                try self.endArray();
                            }
                        },
                        else => @compileError("Unsupported pointer type"),
                    }
                },
                .array => |arr| {
                    if (arr.child == u8) {
                        try self.writeString(&value);
                    } else {
                        try self.beginArray();
                        for (value) |item| {
                            try self.writeValue(item);
                        }
                        try self.endArray();
                    }
                },
                .@"struct" => |struct_info| {
                    try self.beginObject();
                    inline for (struct_info.fields) |field| {
                        try self.writeField(field.name);
                        try self.writeValue(@field(value, field.name));
                    }
                    try self.endObject();
                },
                .optional => {
                    if (value) |v| {
                        try self.writeValue(v);
                    } else {
                        try self.writeNull();
                    }
                },
                else => @compileError("Unsupported type: " ++ @typeName(T)),
            }
        }

        fn writeCommaIfNeeded(self: *Self) !void {
            if (self.state_stack.items.len > 0) {
                const state = self.state_stack.items[self.state_stack.items.len - 1];

                if (state == .array_start) {
                    if (self.pretty) {
                        try self.writeNewline();
                        try self.writeIndent();
                    }
                    self.state_stack.items[self.state_stack.items.len - 1] = .array_element;
                } else if (state == .array_element) {
                    try self.writer.writeByte(',');
                    if (self.pretty) {
                        try self.writeNewline();
                        try self.writeIndent();
                    }
                }
            }
        }

        fn writeStringValue(self: *Self, value: []const u8) !void {
            try escape_mod.writeEscapedToWriter(self.writer, value);
        }

        fn writeNewline(self: *Self) !void {
            try self.writer.writeByte('\n');
        }

        fn writeIndent(self: *Self) !void {
            const total_indent = self.indent_level * self.indent_size;
            var i: usize = 0;
            while (i < total_indent) : (i += 1) {
                try self.writer.writeByte(' ');
            }
        }
    };
}

/// Convenience function to create a stream writer
pub fn streamWriter(writer: anytype, allocator: std.mem.Allocator, options: StreamWriter(@TypeOf(writer)).Options) StreamWriter(@TypeOf(writer)) {
    return StreamWriter(@TypeOf(writer)).init(writer, allocator, options);
}
