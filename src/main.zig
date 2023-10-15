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
        // if its generic, you can just skip comparisons
        // also an escape hatch for @This() pointers
        if (param1.is_generic or param2.is_generic) {
            continue;
        }

        if (param1.type != param2.type) {
            return false;
        }
    }

    return true;
}

pub fn Interface(comptime Self: type) type {
    return struct {
        pub fn implements(comptime Outer: type) void {
            comptime {
                const outer_info = @typeInfo(Outer);
                switch (outer_info) {
                    .Struct, .Enum, .Union => {},
                    else => {
                        const type_error_msg = std.fmt.comptimePrint("Parameter for Interface() must be a Struct, Enum, or Union. Type {s} is of type {*}", .{ @typeName(Outer), outer_info });
                        @compileError(type_error_msg);
                    },
                }

                const outer_decl_names = std.meta.declarations(Outer);
                const decl_len = outer_decl_names.len;

                const KeyValueType = struct {
                    []const u8,
                };

                var kvs: [decl_len]KeyValueType = undefined;
                for (outer_decl_names, 0..) |field, i| {
                    kvs[i] = .{field.name};
                }

                const decl_set = std.ComptimeStringMap(void, kvs);

                const decls = std.meta.declarations(Self);
                var has_error = false;
                var field_count: comptime_int = 0;

                inline for (decls) |decl| {
                    if (decl_set.has(decl.name)) {
                        const outer_type = @typeInfo(@TypeOf(@field(Outer, decl.name)));
                        const inner_type = @typeInfo(@TypeOf(@field(Self, decl.name)));

                        if (outer_type == .Fn and inner_type == .Fn) {
                            if (checkFunctionArgs(outer_type, inner_type)) {
                                field_count += 1;
                            }
                        } else {
                            const type_mismatch_error_msg = std.fmt.comptimePrint("Field {s} of type {*} doesn't match", .{ decl.name, @typeName(Self) });
                            @compileLog(type_mismatch_error_msg);
                            has_error = true;
                        }
                    }
                }

                if (field_count != decl_len) {
                    const inexhaustive_error_msg = std.fmt.comptimePrint("Type {s} does not fulfill all the requirements of {s}", .{ @typeName(Self), @typeName(Outer) });
                    @compileLog(inexhaustive_error_msg);
                }

                if (has_error) {
                    const mismatch_error_msg = std.fmt.comptimePrint("Interface mismatch between {s} and {s}", .{ @typeName(Self), @typeName(Outer) });
                    @compileLog(mismatch_error_msg);
                }
            }
        }
    };
}

test "basic" {
    const Foo = struct {
        pub fn testFn() void {}
    };

    // sanity check
    const foo_decls = std.meta.declarations(Foo);
    try testing.expectEqual(foo_decls.len, 1);

    const Bar = struct {
        const Self = @This();

        usingnamespace Interface(Self);
        comptime {
            Self.implements(Foo);
        }

        pub fn testFn() void {}
    };

    _ = Bar;
}

test "more" {
    const Foo = struct {
        pub fn testFn0() u8 {
            @compileError("unimplemented");
        }
        pub fn testFn1() f32 {
            @compileError("unimplemented");
        }
        pub fn testFn2() usize {
            @compileError("unimplemented");
        }
        pub fn testFn3() []const u8 {
            @compileError("unimplemented");
        }
    };

    const Bar = struct {
        const Self = @This();

        usingnamespace Interface(Self);
        comptime {
            Self.implements(Foo);
        }

        pub fn testFn0() u8 {
            return 0;
        }
        pub fn testFn1() f32 {
            return 0;
        }
        pub fn testFn2() usize {
            return 0;
        }
        pub fn testFn3() []const u8 {
            return "0";
        }
    };

    _ = Bar;
}

test "method" {
    const Foo = struct {
        pub fn testFn(self: anytype) void {
            _ = self;
            @compileError("unimplemented");
        }

        pub fn testFn1(self: anytype, dummy: usize) usize {
            _ = self;
            _ = dummy;
            @compileError("unimplemented");
        }
    };

    const Bar = struct {
        const Self = @This();

        dummy: usize,

        usingnamespace Interface(Self);
        comptime {
            Self.implements(Foo);
        }

        pub fn testFn(self: Self) void {
            _ = self;
        }

        pub fn testFn1(self: Self, dummy: usize) usize {
            self.dummy = dummy;
            return dummy;
        }
    };

    _ = Bar;
}

test "fields" {
    const Foo = struct {
        pub const testFn = fn () void;
    };

    const Bar = struct {
        const Self = @This();

        usingnamespace Interface(Self);
        comptime {
            Self.implements(Foo);
        }

        pub fn testFn() void {}
    };

    _ = Bar;
}

test "fail" {
    return error.SkipZigTest;

    //  const Foo = struct {
    //      pub fn testFn() void {}
    //  };

    //  const Bar = struct {
    //      const Self = @This();

    //      usingnamespace Interface(Self);
    //      comptime {
    //          Self.implements(Foo);
    //      }

    //      pub fn testFn0() void {}
    //  };
}
