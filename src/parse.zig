const std = @import("std");
const value_mod = @import("value.zig");

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

pub fn parseToArena(input: []const u8, base_allocator: std.mem.Allocator, options: ParseOptions) Error!ParseResult {
    var arena = std.heap.ArenaAllocator.init(base_allocator);
    errdefer arena.deinit();

    last_parse_error_info = null;

    var parser = FastParser{
        .input = input,
        .pos = 0,
        .line = 1,
        .column = 1,
        .arena = arena.allocator(),
        .options = options,
        .last_error_info = null,
    };

    const value = try parser.parseValue();

    // Check for trailing content
    parser.skipWhitespace();
    if (parser.pos < parser.input.len) {
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
    input: []const u8,
    pos: usize,
    line: usize,
    column: usize,
    arena: std.mem.Allocator,
    options: ParseOptions,
    last_error_info: ?value_mod.ParseErrorInfo = null,

    fn parseValue(self: *FastParser) Error!Value {
        self.skipWhitespace();
        if (self.pos >= self.input.len) return self.fail(Error.UnexpectedEnd);

        return switch (self.input[self.pos]) {
            'n' => self.parseNull(),
            't', 'f' => self.parseBool(),
            '"' => self.parseString(),
            '[' => self.parseArray(),
            '{' => self.parseObject(),
            '-', '0'...'9' => self.parseNumber(),
            else => self.fail(Error.InvalidSyntax),
        };
    }

    inline fn advance(self: *FastParser, count: usize) void {
        var moved: usize = 0;
        while (moved < count and self.pos < self.input.len) : (moved += 1) {
            const c = self.input[self.pos];
            self.pos += 1;
            if (c == '\n') {
                self.line += 1;
                self.column = 1;
            } else {
                self.column += 1;
            }
        }
    }

    inline fn fail(self: *FastParser, err: Error) Error {
        const ctx = self.sliceContext();
        const info = value_mod.ParseErrorInfo{
            .byte_offset = self.pos,
            .line = self.line,
            .column = self.column,
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
        const start = if (self.pos > window) self.pos - window else 0;
        const end = @min(self.input.len, self.pos + window);
        return ContextSlice{ .slice = self.input[start..end], .start = start };
    }

    inline fn parseNull(self: *FastParser) Error!Value {
        if (self.pos + 4 > self.input.len or
            !std.mem.eql(u8, self.input[self.pos .. self.pos + 4], "null"))
        {
            return self.fail(Error.InvalidSyntax);
        }
        self.advance(4);
        return Value.Null;
    }

    inline fn parseBool(self: *FastParser) Error!Value {
        if (self.pos + 4 <= self.input.len and
            std.mem.eql(u8, self.input[self.pos .. self.pos + 4], "true"))
        {
            self.advance(4);
            return Value{ .Bool = true };
        } else if (self.pos + 5 <= self.input.len and
            std.mem.eql(u8, self.input[self.pos .. self.pos + 5], "false"))
        {
            self.advance(5);
            return Value{ .Bool = false };
        }
        return self.fail(Error.InvalidSyntax);
    }

    fn parseNumber(self: *FastParser) Error!Value {
        const start = self.pos;

        // Optional minus
        if (self.pos < self.input.len and self.input[self.pos] == '-') {
            self.advance(1);
        }

        if (self.pos >= self.input.len or !std.ascii.isDigit(self.input[self.pos])) {
            return self.fail(Error.InvalidNumber);
        }

        // Fast number scanning
        while (self.pos < self.input.len) {
            const c = self.input[self.pos];
            if (std.ascii.isDigit(c) or c == '.' or c == 'e' or c == 'E' or c == '+' or c == '-') {
                self.advance(1);
            } else {
                break;
            }
        }

        return Value{ .Number = self.input[start..self.pos] };
    }

    fn parseString(self: *FastParser) Error!Value {
        if (self.input[self.pos] != '"') return self.fail(Error.InvalidSyntax);
        self.advance(1);

        const start = self.pos;
        const result = self.scanString() catch |err| switch (err) {
            error.UnexpectedEnd => return self.fail(Error.UnexpectedEnd),
        };

        if (result.has_escapes) {
            return Value{ .String = try self.unescapeString(start, result.end) };
        } else {
            // Zero-copy string
            return Value{ .String = self.input[start..result.end] };
        }
    }

    const StringScanResult = struct {
        end: usize,
        has_escapes: bool,
    };

    fn scanString(self: *FastParser) !StringScanResult {
        var has_escapes = false;

        while (self.pos < self.input.len) {
            const c = self.input[self.pos];

            if (c == '"') {
                const end = self.pos;
                self.advance(1);
                return StringScanResult{ .end = end, .has_escapes = has_escapes };
            } else if (c == '\\') {
                has_escapes = true;
                self.advance(1);
                if (self.pos >= self.input.len) return error.UnexpectedEnd;

                if (self.input[self.pos] == 'u') {
                    self.advance(5); // Skip u + 4 hex digits
                } else {
                    self.advance(1);
                }
            } else {
                self.advance(1);
            }
        }

        return error.UnexpectedEnd;
    }

    fn unescapeString(self: *FastParser, start: usize, end: usize) ![]const u8 {
        var result = try std.ArrayList(u8).initCapacity(self.arena, end - start);

        var i = start;
        while (i < end) {
            if (self.input[i] == '\\') {
                i += 1;
                if (i >= end) return self.fail(Error.InvalidEscape);

                switch (self.input[i]) {
                    '"' => try result.append(self.arena, '"'),
                    '\\' => try result.append(self.arena, '\\'),
                    '/' => try result.append(self.arena, '/'),
                    'b' => try result.append(self.arena, '\x08'),
                    'f' => try result.append(self.arena, '\x0C'),
                    'n' => try result.append(self.arena, '\n'),
                    'r' => try result.append(self.arena, '\r'),
                    't' => try result.append(self.arena, '\t'),
                    'u' => {
                        i += 1;
                        if (i + 3 >= end) return self.fail(Error.InvalidEscape);
                        const hex = self.input[i .. i + 4];
                        const codepoint = std.fmt.parseInt(u16, hex, 16) catch return self.fail(Error.InvalidEscape);
                        try result.append(self.arena, @intCast(codepoint));
                        i += 3;
                    },
                    else => return self.fail(Error.InvalidEscape),
                }
                i += 1;
            } else {
                // Batch copy normal characters
                const batch_start = i;
                while (i < end and self.input[i] != '\\') {
                    i += 1;
                }
                try result.appendSlice(self.arena, self.input[batch_start..i]);
            }
        }

        return result.toOwnedSlice(self.arena);
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
            self.skipWhitespace();
            const idx = stack.items.len - 1;
            switch (stack.items[idx]) {
                .array => |*arr| {
                    if (arr.expect_value) {
                        if (self.pos >= self.input.len) return self.fail(Error.UnexpectedEnd);

                        if (self.input[self.pos] == ']') {
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

                    if (self.pos >= self.input.len) return self.fail(Error.UnexpectedEnd);
                    const c = self.input[self.pos];
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
                            if (self.pos >= self.input.len) return self.fail(Error.UnexpectedEnd);

                            if (self.input[self.pos] == '}') {
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
                            if (self.pos >= self.input.len or self.input[self.pos] != ':') {
                                return self.fail(Error.InvalidSyntax);
                            }
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
                            if (self.pos >= self.input.len) return self.fail(Error.UnexpectedEnd);
                            const c = self.input[self.pos];
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
        if (self.pos >= self.input.len or self.input[self.pos] != '[') {
            return self.fail(Error.InvalidSyntax);
        }
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
        if (self.pos >= self.input.len or self.input[self.pos] != '{') {
            return self.fail(Error.InvalidSyntax);
        }
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
        if (self.pos >= self.input.len) return self.fail(Error.UnexpectedEnd);

        return switch (self.input[self.pos]) {
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

    inline fn skipWhitespace(self: *FastParser) void {
        while (self.pos < self.input.len) {
            const c = self.input[self.pos];
            if (std.ascii.isWhitespace(c)) {
                self.advance(1);
            } else if (self.options.allow_comments and c == '/') {
                if (self.pos + 1 < self.input.len) {
                    if (self.input[self.pos + 1] == '/') {
                        // Line comment - skip to end of line
                        self.advance(2);
                        while (self.pos < self.input.len and self.input[self.pos] != '\n') {
                            self.advance(1);
                        }
                    } else if (self.input[self.pos + 1] == '*') {
                        // Block comment - skip to */
                        self.advance(2);
                        while (self.pos + 1 < self.input.len) {
                            if (self.input[self.pos] == '*' and self.input[self.pos + 1] == '/') {
                                self.advance(2);
                                break;
                            }
                            self.advance(1);
                        }
                    } else {
                        break;
                    }
                } else {
                    break;
                }
            } else {
                break;
            }
        }
    }
};
