const std = @import("std");
const value_mod = @import("value.zig");
const lexer_mod = @import("lexer.zig");

pub const Error = value_mod.Error;
pub const Value = value_mod.Value;
pub const Pair = value_mod.Pair;
pub const ParseOptions = value_mod.ParseOptions;
pub const ParseResult = value_mod.ParseResult;
pub const ParseErrorInfo = value_mod.ParseErrorInfo;

threadlocal var last_parse_error_info: ?value_mod.ParseErrorInfo = null;

pub fn lastParseErrorInfo() ?value_mod.ParseErrorInfo {
    return last_parse_error_info;
}

pub fn writeParseErrorIndicator(info: value_mod.ParseErrorInfo, writer: anytype) !void {
    const ctx = info.context;
    if (ctx.len == 0) {
        try writer.print("(no context available)\n", .{});
        return;
    }

    const caret_rel = if (info.byte_offset >= info.context_offset)
        info.byte_offset - info.context_offset
    else
        0;

    const before_slice = ctx[0..@min(caret_rel, ctx.len)];
    const line_start = blk: {
        if (std.mem.lastIndexOfScalar(u8, before_slice, '\n')) |idx|
            break :blk idx + 1;
        break :blk 0;
    };

    const line_end = blk: {
        if (caret_rel < ctx.len) {
            if (std.mem.indexOfScalarPos(u8, ctx, caret_rel, '\n')) |idx|
                break :blk idx;
        }
        break :blk ctx.len;
    };

    const line_slice = ctx[line_start..line_end];
    const caret_pos = if (caret_rel > line_start) caret_rel - line_start else 0;

    try writer.print("line {d}, column {d}\n", .{ info.line, info.column });
    try writer.print("{s}\n", .{line_slice});

    var i: usize = 0;
    while (i < caret_pos) : (i += 1) {
        try writer.writeByte(' ');
    }

    try writer.writeAll("^\n");
}

pub fn parse(input: []const u8, base_allocator: std.mem.Allocator, options: ParseOptions) Error!ParseResult {
    var arena = std.heap.ArenaAllocator.init(base_allocator);
    errdefer arena.deinit();

    last_parse_error_info = null;

    const lexer = lexer_mod.Lexer(void).initSlice(input, arena.allocator());

    var parser = FastParser{
        .lexer = lexer,
        .arena = arena.allocator(),
        .options = options,
        .last_error_info = null,
    };

    const value = try parser.parseValue();

    // Check for trailing content
    try parser.skipWhitespace();
    if (try parser.lexer.input.hasMore(parser.lexer.allocator)) {
        return parser.fail(Error.TrailingCharacters);
    }

    return ParseResult{
        .value = value,
        .arena = arena,
        .error_info = null,
    };
}

/// Fast parser using arena allocator
const FastParser = struct {
    lexer: lexer_mod.Lexer(void),
    arena: std.mem.Allocator,
    options: ParseOptions,
    last_error_info: ?value_mod.ParseErrorInfo = null,

    fn parseValue(self: *FastParser) Error!Value {
        try self.skipWhitespace();
        const c = (try self.lexer.input.peek(self.lexer.allocator)) orelse return self.fail(Error.UnexpectedEnd);

        return switch (c) {
            'n' => self.parseNull(),
            't', 'f' => self.parseBool(),
            '"' => self.parseString(),
            '[' => self.parseArray(),
            '{' => self.parseObject(),
            '-', '0'...'9' => self.parseNumber(),
            else => self.fail(Error.InvalidSyntax),
        };
    }

    inline fn fail(self: *FastParser, err: Error) Error {
        const pos = self.lexer.position;
        const ctx = self.sliceContext();
        const info = value_mod.ParseErrorInfo{
            .byte_offset = pos.byte_offset,
            .line = pos.line,
            .column = pos.column,
            .context = ctx.slice,
            .context_offset = ctx.start,
        };
        self.last_error_info = info;
        last_parse_error_info = info;
        return err;
    }

    const ContextSlice = struct {
        slice: []const u8,
        start: usize,
    };

    fn sliceContext(self: *FastParser) ContextSlice {
        const window: usize = 24;
        const pos = self.lexer.position.byte_offset;
        const input = switch (self.lexer.input) {
            .slice => |*s| s.data,
            else => unreachable, // FastParser only uses slice input
        };
        const start = if (pos > window) pos - window else 0;
        const end = @min(input.len, pos + window);
        return ContextSlice{ .slice = input[start..end], .start = start };
    }

    inline fn parseNull(self: *FastParser) Error!Value {
        self.lexer.expectLiteral("null") catch return self.fail(Error.InvalidSyntax);
        return Value.Null;
    }

    inline fn parseBool(self: *FastParser) Error!Value {
        const c = (try self.lexer.input.peek(self.lexer.allocator)) orelse return self.fail(Error.InvalidSyntax);
        if (c == 't') {
            self.lexer.expectLiteral("true") catch return self.fail(Error.InvalidSyntax);
            return Value{ .Bool = true };
        } else {
            self.lexer.expectLiteral("false") catch return self.fail(Error.InvalidSyntax);
            return Value{ .Bool = false };
        }
    }

    fn parseNumber(self: *FastParser) Error!Value {
        const num_str = self.lexer.parseNumber() catch |err| return self.fail(err);
        // Numbers from lexer are always allocated, but we want to borrow from input
        // So we need to find the slice in the original input
        // For arena allocation, we can just use the allocated string from lexer
        return Value{ .Number = num_str };
    }

    fn parseString(self: *FastParser) Error!Value {
        const str_result = self.lexer.parseString() catch |err| return self.fail(err);
        // str_result.data is either borrowed (slice input) or allocated (buffered input)
        // Since FastParser uses arena, we can use it directly if borrowed,
        // or transfer ownership if allocated
        return Value{ .String = str_result.data };
    }

    // Helper methods for lexer access
    inline fn peek(self: *FastParser) !?u8 {
        return try self.lexer.input.peek(self.lexer.allocator);
    }

    inline fn advance(self: *FastParser, count: usize) void {
        self.lexer.input.advance(&self.lexer.position, count);
    }

    inline fn skipWhitespace(self: *FastParser) !void {
        try self.lexer.skipWhitespace();
        // Handle comments if enabled
        if (self.options.allow_comments) {
            while (true) {
                const c = (try self.peek()) orelse break;
                if (c == '/') {
                    const next = blk: {
                        const old_pos = self.lexer.input.currentPos();
                        self.advance(1);
                        const result = try self.peek();
                        // Reset position
                        switch (self.lexer.input) {
                            .slice => |*s| s.pos = old_pos,
                            .buffered => |*b| b.pos = old_pos,
                        }
                        self.lexer.position.byte_offset = old_pos;
                        break :blk result;
                    } orelse break;

                    if (next == '/') {
                        // Line comment
                        self.advance(2);
                        while (try self.peek()) |ch| {
                            if (ch == '\n') break;
                            self.advance(1);
                        }
                        try self.lexer.skipWhitespace();
                    } else if (next == '*') {
                        // Block comment
                        self.advance(2);
                        while (true) {
                            const ch = (try self.peek()) orelse return self.fail(Error.UnexpectedEnd);
                            self.advance(1);
                            if (ch == '*') {
                                if ((try self.peek()) == '/') {
                                    self.advance(1);
                                    break;
                                }
                            }
                        }
                        try self.lexer.skipWhitespace();
                    } else {
                        break;
                    }
                } else {
                    break;
                }
            }
        }
    }

    fn parseArray(self: *FastParser) Error!Value {
        return self.parseContainer(.array);
    }

    fn parseObject(self: *FastParser) Error!Value {
        return self.parseContainer(.object);
    }

    const ContainerKind = enum { array, object };

    const StackFrame = union(enum) {
        array: ArrayFrame,
        object: ObjectFrame,
    };

    const ArrayFrame = struct {
        items: std.ArrayList(Value),
        expect_value: bool,
        seen_value: bool,
    };

    const ObjectState = enum {
        expect_key_or_end,
        expect_colon,
        expect_value,
        expect_comma_or_end,
    };

    const ObjectFrame = struct {
        fields: std.ArrayList(Pair),
        state: ObjectState,
        pending_key: ?[]const u8,
        awaiting_key_after_comma: bool,
    };

    const FrameStack = std.ArrayList(StackFrame);

    fn parseContainer(self: *FastParser, kind: ContainerKind) Error!Value {
        var stack: FrameStack = .empty;
        defer stack.deinit(self.arena);

        switch (kind) {
            .array => try self.pushArrayFrame(&stack),
            .object => try self.pushObjectFrame(&stack),
        }

        while (stack.items.len > 0) {
            try self.skipWhitespace();
            const idx = stack.items.len - 1;
            switch (stack.items[idx]) {
                .array => |*arr| {
                    if (arr.expect_value) {
                        const c = (try self.peek()) orelse return self.fail(Error.UnexpectedEnd);

                        if (c == ']') {
                            if (arr.seen_value and !self.options.allow_trailing_commas) {
                                return self.fail(Error.InvalidSyntax);
                            }
                            self.advance(1);
                            const completion = try self.handleContainerCompletion(
                                &stack,
                                Value{ .Array = try arr.items.toOwnedSlice(self.arena) },
                            );
                            if (completion) |result| return result;
                            continue;
                        }

                        const scalar = try self.beginValue(&stack);
                        if (scalar) |value| {
                            try arr.items.append(self.arena, value);
                            arr.expect_value = false;
                            arr.seen_value = true;
                        }
                        continue;
                    }

                    const c = (try self.peek()) orelse return self.fail(Error.UnexpectedEnd);
                    if (c == ',') {
                        self.advance(1);
                        arr.expect_value = true;
                        continue;
                    } else if (c == ']') {
                        self.advance(1);
                        const completion = try self.handleContainerCompletion(
                            &stack,
                            Value{ .Array = try arr.items.toOwnedSlice(self.arena) },
                        );
                        if (completion) |result| return result;
                        continue;
                    } else {
                        return self.fail(Error.InvalidSyntax);
                    }
                },
                .object => |*obj| {
                    switch (obj.state) {
                        .expect_key_or_end => {
                            const c = (try self.peek()) orelse return self.fail(Error.UnexpectedEnd);

                            if (c == '}') {
                                if (obj.awaiting_key_after_comma and !self.options.allow_trailing_commas) {
                                    return self.fail(Error.InvalidSyntax);
                                }
                                self.advance(1);
                                const completion = try self.handleContainerCompletion(
                                    &stack,
                                    Value{ .Object = try obj.fields.toOwnedSlice(self.arena) },
                                );
                                if (completion) |result| return result;
                                continue;
                            }

                            const key_value = try self.parseString();
                            const key = switch (key_value) {
                                .String => |s| s,
                                else => return self.fail(Error.InvalidSyntax),
                            };

                            obj.pending_key = key;
                            obj.state = .expect_colon;
                            obj.awaiting_key_after_comma = false;
                            continue;
                        },
                        .expect_colon => {
                            const c = (try self.peek()) orelse return self.fail(Error.InvalidSyntax);
                            if (c != ':') return self.fail(Error.InvalidSyntax);
                            self.advance(1);
                            obj.state = .expect_value;
                            continue;
                        },
                        .expect_value => {
                            const scalar = try self.beginValue(&stack);
                            if (scalar) |value| {
                                const key = obj.pending_key orelse return self.fail(Error.InvalidSyntax);
                                try obj.fields.append(self.arena, Pair{ .key = key, .value = value });
                                obj.pending_key = null;
                                obj.state = .expect_comma_or_end;
                            }
                            continue;
                        },
                        .expect_comma_or_end => {
                            const c = (try self.peek()) orelse return self.fail(Error.UnexpectedEnd);
                            if (c == ',') {
                                self.advance(1);
                                obj.state = .expect_key_or_end;
                                obj.awaiting_key_after_comma = true;
                                continue;
                            } else if (c == '}') {
                                self.advance(1);
                                const completion = try self.handleContainerCompletion(
                                    &stack,
                                    Value{ .Object = try obj.fields.toOwnedSlice(self.arena) },
                                );
                                if (completion) |result| return result;
                                continue;
                            } else {
                                return self.fail(Error.InvalidSyntax);
                            }
                        },
                    }
                },
            }
        }

        unreachable;
    }

    fn pushArrayFrame(self: *FastParser, stack: *FrameStack) Error!void {
        const c = (try self.peek()) orelse return self.fail(Error.InvalidSyntax);
        if (c != '[') return self.fail(Error.InvalidSyntax);
        self.advance(1);
        const frame = StackFrame{
            .array = .{
                .items = try std.ArrayList(Value).initCapacity(self.arena, 8),
                .expect_value = true,
                .seen_value = false,
            },
        };
        try stack.append(self.arena, frame);
    }

    fn pushObjectFrame(self: *FastParser, stack: *FrameStack) Error!void {
        const c = (try self.peek()) orelse return self.fail(Error.InvalidSyntax);
        if (c != '{') return self.fail(Error.InvalidSyntax);
        self.advance(1);
        const frame = StackFrame{
            .object = .{
                .fields = try std.ArrayList(Pair).initCapacity(self.arena, 8),
                .state = .expect_key_or_end,
                .pending_key = null,
                .awaiting_key_after_comma = false,
            },
        };
        try stack.append(self.arena, frame);
    }

    fn beginValue(self: *FastParser, stack: *FrameStack) Error!?Value {
        const c = (try self.peek()) orelse return self.fail(Error.UnexpectedEnd);

        return switch (c) {
            '[' => blk: {
                try self.pushArrayFrame(stack);
                break :blk null;
            },
            '{' => blk: {
                try self.pushObjectFrame(stack);
                break :blk null;
            },
            'n' => try self.parseNull(),
            't', 'f' => try self.parseBool(),
            '"' => try self.parseString(),
            '-', '0'...'9' => try self.parseNumber(),
            else => self.fail(Error.InvalidSyntax),
        };
    }

    fn handleContainerCompletion(self: *FastParser, stack: *FrameStack, value: Value) Error!?Value {
        stack.items.len -= 1;
        if (stack.items.len == 0) {
            return value;
        }

        try self.attachValueToParent(stack, value);
        return null;
    }

    fn attachValueToParent(self: *FastParser, stack: *FrameStack, value: Value) Error!void {
        if (stack.items.len == 0) return;
        const parent = &stack.items[stack.items.len - 1];
        switch (parent.*) {
            .array => |*arr| {
                try arr.items.append(self.arena, value);
                arr.expect_value = false;
                arr.seen_value = true;
            },
            .object => |*obj| {
                const key = obj.pending_key orelse return self.fail(Error.InvalidSyntax);
                try obj.fields.append(self.arena, Pair{ .key = key, .value = value });
                obj.pending_key = null;
                obj.state = .expect_comma_or_end;
            },
        }
    }
};
