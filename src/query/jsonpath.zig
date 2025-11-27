const std = @import("std");
const Allocator = std.mem.Allocator;
const value_mod = @import("../core/value.zig");

pub const Value = value_mod.Value;
pub const Error = value_mod.Error;

/// JSONPath segment types
pub const Segment = union(enum) {
    root,
    current,
    child: []const u8,
    wildcard,
    recursive_descent,
    index: isize,
    slice: Slice,
    union_: []const UnionItem,
    filter: []const u8,

    pub const Slice = struct {
        start: ?isize = null,
        end: ?isize = null,
        step: ?isize = null,
    };

    pub const UnionItem = union(enum) {
        index: isize,
        key: []const u8,
    };
};

/// Parse JSONPath expression into segments
pub fn parse(allocator: Allocator, path: []const u8) Error![]Segment {
    if (path.len == 0) return Error.InvalidPath;

    var segments: std.ArrayListUnmanaged(Segment) = .empty;
    errdefer segments.deinit(allocator);

    var i: usize = 0;

    if (path[0] == '$') {
        segments.append(allocator, .root) catch return Error.OutOfMemory;
        i = 1;
    } else if (path[0] == '@') {
        segments.append(allocator, .current) catch return Error.OutOfMemory;
        i = 1;
    } else {
        return Error.InvalidPath;
    }

    while (i < path.len) {
        if (path[i] == '.') {
            i += 1;
            if (i >= path.len) break;

            if (path[i] == '.') {
                segments.append(allocator, .recursive_descent) catch return Error.OutOfMemory;
                i += 1;
                // After .., parse the following segment (identifier, *, or [)
                if (i >= path.len) break;
                if (path[i] == '*') {
                    segments.append(allocator, .wildcard) catch return Error.OutOfMemory;
                    i += 1;
                } else if (path[i] == '[') {
                    i += 1;
                    const seg = try parseBracket(allocator, path, &i);
                    segments.append(allocator, seg) catch return Error.OutOfMemory;
                } else if (isIdentChar(path[i])) {
                    const start = i;
                    while (i < path.len and isIdentChar(path[i])) : (i += 1) {}
                    segments.append(allocator, .{ .child = path[start..i] }) catch return Error.OutOfMemory;
                }
                continue;
            }

            if (path[i] == '*') {
                segments.append(allocator, .wildcard) catch return Error.OutOfMemory;
                i += 1;
                continue;
            }

            const start = i;
            while (i < path.len and isIdentChar(path[i])) : (i += 1) {}
            if (i == start) return Error.InvalidPath;
            segments.append(allocator, .{ .child = path[start..i] }) catch return Error.OutOfMemory;
        } else if (path[i] == '[') {
            i += 1;
            const seg = try parseBracket(allocator, path, &i);
            segments.append(allocator, seg) catch return Error.OutOfMemory;
        } else {
            return Error.InvalidSyntax;
        }
    }

    return segments.toOwnedSlice(allocator) catch return Error.OutOfMemory;
}

fn parseBracket(allocator: Allocator, path: []const u8, i: *usize) Error!Segment {
    if (i.* >= path.len) return Error.InvalidSyntax;

    if (path[i.*] == '?') {
        i.* += 1;
        if (i.* >= path.len or path[i.*] != '(') return Error.InvalidSyntax;
        i.* += 1;
        const filter_start = i.*;
        var depth: usize = 1;
        while (i.* < path.len and depth > 0) {
            if (path[i.*] == '(') depth += 1;
            if (path[i.*] == ')') depth -= 1;
            i.* += 1;
        }
        if (depth != 0) return Error.InvalidSyntax;
        const filter_expr = path[filter_start .. i.* - 1];
        if (i.* >= path.len or path[i.*] != ']') return Error.InvalidSyntax;
        i.* += 1;
        return .{ .filter = filter_expr };
    }

    if (path[i.*] == '*') {
        i.* += 1;
        if (i.* >= path.len or path[i.*] != ']') return Error.InvalidSyntax;
        i.* += 1;
        return .wildcard;
    }

    if (path[i.*] == '\'' or path[i.*] == '"') {
        const quote = path[i.*];
        i.* += 1;
        const key_start = i.*;
        while (i.* < path.len and path[i.*] != quote) : (i.* += 1) {}
        if (i.* >= path.len) return Error.InvalidSyntax;
        const key = path[key_start..i.*];
        i.* += 1;

        if (i.* < path.len and path[i.*] == ',') {
            return parseUnion(allocator, path, i, key);
        }

        if (i.* >= path.len or path[i.*] != ']') return Error.InvalidSyntax;
        i.* += 1;
        return .{ .child = key };
    }

    const num_start = i.*;
    var has_colon = false;
    var has_comma = false;

    while (i.* < path.len and path[i.*] != ']') {
        if (path[i.*] == ':') has_colon = true;
        if (path[i.*] == ',') has_comma = true;
        i.* += 1;
    }
    if (i.* >= path.len) return Error.InvalidSyntax;

    const content = path[num_start..i.*];
    i.* += 1;

    if (has_colon) {
        return parseSlice(content);
    } else if (has_comma) {
        return parseIndexUnion(allocator, content);
    } else {
        const idx = std.fmt.parseInt(isize, content, 10) catch return Error.InvalidNumber;
        return .{ .index = idx };
    }
}

fn parseSlice(content: []const u8) Error!Segment {
    var slice = Segment.Slice{};
    var part: u8 = 0;
    var num_start: usize = 0;
    var i: usize = 0;

    while (i <= content.len) {
        const at_end = i == content.len;
        const is_colon = !at_end and content[i] == ':';

        if (at_end or is_colon) {
            const num_str = content[num_start..i];
            if (num_str.len > 0) {
                const val = std.fmt.parseInt(isize, num_str, 10) catch return Error.InvalidSyntax;
                switch (part) {
                    0 => slice.start = val,
                    1 => slice.end = val,
                    2 => slice.step = val,
                    else => return Error.InvalidSyntax,
                }
            }
            part += 1;
            num_start = i + 1;
        }
        i += 1;
    }

    return .{ .slice = slice };
}

fn parseUnion(allocator: Allocator, path: []const u8, i: *usize, first_key: []const u8) Error!Segment {
    var items: std.ArrayListUnmanaged(Segment.UnionItem) = .empty;
    errdefer items.deinit(allocator);

    items.append(allocator, .{ .key = first_key }) catch return Error.OutOfMemory;

    while (i.* < path.len and path[i.*] == ',') {
        i.* += 1;
        while (i.* < path.len and path[i.*] == ' ') : (i.* += 1) {}

        if (i.* >= path.len) return Error.InvalidSyntax;

        if (path[i.*] == '\'' or path[i.*] == '"') {
            const quote = path[i.*];
            i.* += 1;
            const key_start = i.*;
            while (i.* < path.len and path[i.*] != quote) : (i.* += 1) {}
            if (i.* >= path.len) return Error.InvalidSyntax;
            items.append(allocator, .{ .key = path[key_start..i.*] }) catch return Error.OutOfMemory;
            i.* += 1;
        } else {
            return Error.InvalidPath;
        }
    }

    if (i.* >= path.len or path[i.*] != ']') return Error.InvalidSyntax;
    i.* += 1;

    return .{ .union_ = items.toOwnedSlice(allocator) catch return Error.OutOfMemory };
}

fn parseIndexUnion(allocator: Allocator, content: []const u8) Error!Segment {
    var items: std.ArrayListUnmanaged(Segment.UnionItem) = .empty;
    errdefer items.deinit(allocator);

    var iter = std.mem.splitScalar(u8, content, ',');
    while (iter.next()) |part| {
        const trimmed = std.mem.trim(u8, part, " ");
        const idx = std.fmt.parseInt(isize, trimmed, 10) catch return Error.InvalidNumber;
        items.append(allocator, .{ .index = idx }) catch return Error.OutOfMemory;
    }

    return .{ .union_ = items.toOwnedSlice(allocator) catch return Error.OutOfMemory };
}

fn isIdentChar(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '_';
}

/// Query JSON using JSONPath, returns all matching values
pub fn query(allocator: Allocator, value: Value, path: []const u8) Error![]Value {
    const segments = try parse(allocator, path);
    defer freeSegments(allocator, segments);

    var results: std.ArrayListUnmanaged(Value) = .empty;
    errdefer results.deinit(allocator);

    try evaluate(allocator, &results, value, segments, 0);

    return results.toOwnedSlice(allocator) catch return Error.OutOfMemory;
}

fn evaluate(allocator: Allocator, results: *std.ArrayListUnmanaged(Value), value: Value, segments: []const Segment, idx: usize) Error!void {
    if (idx >= segments.len) {
        results.append(allocator, value) catch return Error.OutOfMemory;
        return;
    }

    const seg = segments[idx];

    switch (seg) {
        .root, .current => try evaluate(allocator, results, value, segments, idx + 1),

        .child => |key| {
            if (value == .Object) {
                for (value.Object) |pair| {
                    if (std.mem.eql(u8, pair.key, key)) {
                        try evaluate(allocator, results, pair.value, segments, idx + 1);
                        break;
                    }
                }
            }
        },

        .wildcard => {
            switch (value) {
                .Object => |obj| {
                    for (obj) |pair| {
                        try evaluate(allocator, results, pair.value, segments, idx + 1);
                    }
                },
                .Array => |arr| {
                    for (arr) |item| {
                        try evaluate(allocator, results, item, segments, idx + 1);
                    }
                },
                else => {},
            }
        },

        .index => |i| {
            if (value == .Array) {
                const arr = value.Array;
                const actual_idx = resolveIndex(i, arr.len) orelse return;
                try evaluate(allocator, results, arr[actual_idx], segments, idx + 1);
            }
        },

        .slice => |s| {
            if (value == .Array) {
                const arr = value.Array;
                const len = arr.len;
                if (len == 0) return;

                const step = s.step orelse 1;
                if (step == 0) return;

                const start_idx = resolveSliceIndex(s.start, len, if (step > 0) 0 else @as(isize, @intCast(len)) - 1);
                const end_idx = resolveSliceIndex(s.end, len, if (step > 0) @as(isize, @intCast(len)) else -1);

                if (step > 0) {
                    var j = start_idx;
                    while (j < end_idx) : (j += @intCast(step)) {
                        if (j >= 0 and j < @as(isize, @intCast(len))) {
                            try evaluate(allocator, results, arr[@intCast(j)], segments, idx + 1);
                        }
                    }
                } else {
                    var j = start_idx;
                    while (j > end_idx) : (j += step) {
                        if (j >= 0 and j < @as(isize, @intCast(len))) {
                            try evaluate(allocator, results, arr[@intCast(j)], segments, idx + 1);
                        }
                    }
                }
            }
        },

        .union_ => |items| {
            for (items) |item| {
                switch (item) {
                    .index => |i| {
                        if (value == .Array) {
                            const arr = value.Array;
                            const actual_idx = resolveIndex(i, arr.len) orelse continue;
                            try evaluate(allocator, results, arr[actual_idx], segments, idx + 1);
                        }
                    },
                    .key => |key| {
                        if (value == .Object) {
                            for (value.Object) |pair| {
                                if (std.mem.eql(u8, pair.key, key)) {
                                    try evaluate(allocator, results, pair.value, segments, idx + 1);
                                    break;
                                }
                            }
                        }
                    },
                }
            }
        },

        .recursive_descent => {
            try evaluate(allocator, results, value, segments, idx + 1);

            switch (value) {
                .Object => |obj| {
                    for (obj) |pair| {
                        try evaluate(allocator, results, pair.value, segments, idx);
                    }
                },
                .Array => |arr| {
                    for (arr) |item| {
                        try evaluate(allocator, results, item, segments, idx);
                    }
                },
                else => {},
            }
        },

        .filter => |expr| {
            if (value == .Array) {
                for (value.Array) |item| {
                    if (evaluateFilter(item, expr)) {
                        try evaluate(allocator, results, item, segments, idx + 1);
                    }
                }
            }
        },
    }
}

fn resolveIndex(idx: isize, len: usize) ?usize {
    if (len == 0) return null;
    const len_i: isize = @intCast(len);
    var actual = idx;
    if (actual < 0) actual += len_i;
    if (actual < 0 or actual >= len_i) return null;
    return @intCast(actual);
}

fn resolveSliceIndex(idx: ?isize, len: usize, default: isize) isize {
    const len_i: isize = @intCast(len);
    const i = idx orelse return default;
    if (i < 0) {
        const resolved = i + len_i;
        return if (resolved < 0) 0 else resolved;
    }
    return if (i > len_i) len_i else i;
}

fn evaluateFilter(value: Value, expr: []const u8) bool {
    var i: usize = 0;

    if (i >= expr.len or expr[i] != '@') return false;
    i += 1;

    if (i >= expr.len or expr[i] != '.') return false;
    i += 1;

    const field_start = i;
    while (i < expr.len and isIdentChar(expr[i])) : (i += 1) {}
    const field = expr[field_start..i];

    const field_val = getField(value, field) orelse return false;

    while (i < expr.len and expr[i] == ' ') : (i += 1) {}

    if (i >= expr.len) return true;

    const op_start = i;
    while (i < expr.len and (expr[i] == '<' or expr[i] == '>' or expr[i] == '=' or expr[i] == '!')) : (i += 1) {}
    const op = expr[op_start..i];

    while (i < expr.len and expr[i] == ' ') : (i += 1) {}

    const val_str = std.mem.trim(u8, expr[i..], " ");

    return compareValues(field_val, op, val_str);
}

fn getField(value: Value, field: []const u8) ?Value {
    if (value != .Object) return null;
    for (value.Object) |pair| {
        if (std.mem.eql(u8, pair.key, field)) return pair.value;
    }
    return null;
}

fn compareValues(val: Value, op: []const u8, rhs: []const u8) bool {
    if (val == .Number) {
        const lhs_num = std.fmt.parseFloat(f64, val.Number) catch return false;
        const rhs_num = std.fmt.parseFloat(f64, rhs) catch return false;

        if (std.mem.eql(u8, op, "<")) return lhs_num < rhs_num;
        if (std.mem.eql(u8, op, "<=")) return lhs_num <= rhs_num;
        if (std.mem.eql(u8, op, ">")) return lhs_num > rhs_num;
        if (std.mem.eql(u8, op, ">=")) return lhs_num >= rhs_num;
        if (std.mem.eql(u8, op, "==")) return lhs_num == rhs_num;
        if (std.mem.eql(u8, op, "!=")) return lhs_num != rhs_num;
    }

    if (val == .String) {
        var rhs_clean = rhs;
        if (rhs.len >= 2 and (rhs[0] == '"' or rhs[0] == '\'')) {
            rhs_clean = rhs[1 .. rhs.len - 1];
        }

        if (std.mem.eql(u8, op, "==")) return std.mem.eql(u8, val.String, rhs_clean);
        if (std.mem.eql(u8, op, "!=")) return !std.mem.eql(u8, val.String, rhs_clean);
    }

    return false;
}

/// Free segments allocated by parse()
pub fn freeSegments(allocator: Allocator, segments: []Segment) void {
    for (segments) |seg| {
        if (seg == .union_) {
            allocator.free(seg.union_);
        }
    }
    allocator.free(segments);
}

/// Query and return first match or null
pub fn queryOne(allocator: Allocator, value: Value, path: []const u8) Error!?Value {
    const results = try query(allocator, value, path);
    defer allocator.free(results);
    return if (results.len > 0) results[0] else null;
}
