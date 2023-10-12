const std = @import("std");
const testing = std.testing;

fn checkFunctionArgs(comptime f1: std.builtin.Type, comptime f2: std.builtin.Type) bool {
    const fn1 = f1.Fn;
    const fn2 = f2.Fn;

    if (fn1.return_type != fn2.return_type) {
        return false;
    }

    if (fn1.params.len != fn2.params.len) {
        return false;
    }

    for (fn1.params, fn2.params) |param1, param2| {
        if (param1.type != param2.type) {
            return false;
        }
    }

    return true;
}

// @compileLog() forces a compilation error when found zzz
pub fn Interface(comptime Outer: type) fn (comptime type) void {
    const validator_info = @typeInfo(Outer);
    switch (validator_info) {
        .Struct, .Enum, .Union => {},
        else => {
            const type_error_msg = std.fmt.comptimePrint("Parameter for Interface() must be a Struct, Enum, or Union. Type {s} is of type {*}", .{ @typeName(Outer), validator_info });
            @compileError(type_error_msg);
        },
    }

    const validator_decl_names = std.meta.declarations(Outer);
    const decl_len = validator_decl_names.len;

    const KeyValueType = struct {
        []const u8,
    };

    var kvs: [decl_len]KeyValueType = undefined;
    for (validator_decl_names, 0..) |field, i| {
        kvs[i] = .{field.name};
    }

    const decl_set = std.ComptimeStringMap(void, kvs);

    const Closure = struct {
        fn check(comptime Inner: type) void {
            comptime {
                const decls = std.meta.declarations(Inner);
                var has_error = false;
                var field_count: comptime_int = 0;

                inline for (decls) |decl| {
                    if (decl_set.has(decl.name)) {
                        const outer_type = @typeInfo(@TypeOf(@field(Outer, decl.name)));
                        const inner_type = @typeInfo(@TypeOf(@field(Inner, decl.name)));

                        if (outer_type == .Fn and inner_type == .Fn) {
                            if (checkFunctionArgs(outer_type, inner_type)) {
                                field_count += 1;
                            }
                        } else {
                            const type_mismatch_error_msg = std.fmt.comptimePrint("Field {s} of type {*} doesn't match", .{ decl.name, @typeName(Inner) });
                            @compileLog(type_mismatch_error_msg);
                            has_error = true;
                        }
                    }
                }

                if (field_count != decl_len) {
                    const inexhaustive_error_msg = std.fmt.comptimePrint("Type {s} does not fulfill all the requirements of {s}", .{ @typeName(Inner), @typeName(Outer) });
                    @compileLog(inexhaustive_error_msg);
                }

                if (has_error) {
                    const mismatch_error_msg = std.fmt.comptimePrint("Interface mismatch between {s} and {s}", .{ @typeName(Inner), @typeName(Outer) });
                    @compileLog(mismatch_error_msg);
                }
            }
        }
    };

    return Closure.check;
}

test "sanity" {
    const Foo = struct {
        pub fn testFn() void {}
    };

    const Bar = struct {
        pub fn testFn() void {}
    };

    const foo_fields = std.meta.fields(Foo);
    try testing.expectEqual(foo_fields.len, 0);

    const foo_decls = std.meta.declarations(Foo);
    try testing.expectEqual(foo_decls.len, 1);

    const bar_fields = std.meta.fields(Bar);
    try testing.expectEqual(bar_fields.len, 0);

    const bar_decls = std.meta.declarations(Bar);
    try testing.expectEqual(bar_decls.len, 1);
}

test "basic" {
    const Foo = struct {
        pub fn testFn() void {}
    };

    const Bar = struct {
        pub fn testFn() void {}
    };

    const IFoo = comptime Interface(Foo);
    comptime IFoo(Bar);
}

test "more" {
    const Foo = struct {
        pub fn testFn() void {}
        pub fn testFn1() void {}
        pub fn testFn2() void {}
        pub fn testFn3() void {}
    };

    const Bar = struct {
        pub fn testFn() void {}
        pub fn testFn1() void {}
        pub fn testFn2() void {}
        pub fn testFn3() void {}
    };

    const IFoo = comptime Interface(Foo);
    comptime IFoo(Bar);
}
