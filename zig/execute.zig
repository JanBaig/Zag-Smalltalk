const std = @import("std");
const object = @import("object.zig");
const Object = object.Object;
const Nil = object.Nil;
const NilFlag = object.NilFlag;
const True = object.True;
const False = object.False;
const Thread = @import("thread.zig").Thread;
pub const tailCall: std.builtin.CallOptions = .{.modifier = .always_tail};

pub const Context = [*]Object;
pub const Code = packed union {
    prim: PrimitivePtr,
    int: i64,
    uint: u64,
    object: Object,
    fn object(o: Object) Code {
        return Code{.object=o};
    }
    fn end() Code {
        return Code{.object=NilFlag};
    }
    fn int(i: i64) Code {
        return Code{.int=i};
    }
    fn prim(pp: PrimitivePtr) Code {
        return Code{.prim=pp};
    }
};
const PrimitivePtr = fn(next: [*]const Code, tos: [*]Object, heap: [*]Object, thread: *Thread, caller: Context) Object;
fn countNonLabels(comptime tup: anytype) usize {
    var n = 0;
    inline for (tup) |field| {
        switch (@typeInfo(@TypeOf(field))) {
            .Pointer => {if (field[field.len-1]!=':') n = n + 1;},
            else => {n = n+1;},
        }
    }
    return n;
}
fn compileTuple(name: Object, comptime tup: anytype) [countNonLabels(tup)+2]Code {
    var result: [countNonLabels(tup)+2]Code = undefined;
    result[0] = Code.object(name);
    comptime var n = 1;
    inline for (tup) |field| {
        switch (@TypeOf(field)) {
            Object => {result[n]=Code.object(field);n=n+1;},
            @TypeOf(null) => {result[n]=Code.object(Nil);n=n+1;},
            comptime_int,comptime_float => {result[n]=Code.object(Object.from(field));n = n+1;},
            PrimitivePtr => {result[n]=Code.prim(field);n=n+1;},
            else => {
                comptime var found = false;
                switch (@typeInfo(@TypeOf(field))) {
                    .Pointer => {
                        if (field[field.len-1]==':') {
                            found = true;
                        } else {
                            comptime var lp = 0;
                            inline for (tup) |t| {
                                switch (@typeInfo(@TypeOf(t))) {
                                    .Pointer => {
                                        if (t[t.len-1]==':') {
                                            if (comptime std.mem.startsWith(u8,t,field)) {
                                                result[n]=Code.int(lp+1-n);
                                                n=n+1;
                                                found = true;
                                            }
                                        } else lp=lp+1;
                                    },
                                    else => {lp=lp+1;},
                                }
                            }
                            if (!found) @compileError("missing label: "++field);
                        }
                    },
                    else => {},
                }
                if (!found) @compileError("don't know how to handle \""++@typeName(@TypeOf(field))++"\"");
            },
        }
    }
    result[n]=Code.end();
    return result;
}
const stdout = std.io.getStdOut().writer();
fn return_tos(next: [*]const Code, tos: [*]Object, heap: [*]Object, thread: *Thread, caller: Context) Object {
    _ = thread;
    _ = next;
    _ = heap;
    _ = caller;
    return tos[0];
}
fn failed_test(next: [*]const Code, tos: [*]Object, heap: [*]Object, thread: *Thread, caller: Context) Object {
    _ = thread;
    _ = next;
    _ = heap;
    _ = caller;
    _ = tos;
    @panic("failed_test");
}
test "compiling tuple" {
    const expectEqual = std.testing.expectEqual;
    var t = compileTuple(Nil,.{"abc:", return_tos, "def", True, 42, "def:", "abc", null});
    try expectEqual(t.len,8);
    try expectEqual(t[0].object,Nil);
    try expectEqual(t[1].prim,return_tos);
    try expectEqual(t[2].int,3);
    try expectEqual(t[3].object,True);
    try expectEqual(t[4].object,Object.from(42));
    try expectEqual(t[5].int,-4);
    try expectEqual(t[6].object,Nil);
    try expectEqual(t[t.len-1].object,NilFlag);
}
pub inline fn checkSpace(next: [*]const Code, tos: [*]Object, heap: [*]Object, thread: *Thread, caller: Context, needed: usize) void {
    _ = thread;
    _ = next;
    _ = heap;
    _ = caller;
    _ = tos;
    _ = needed;
}
fn testExecute(code: [] const Code) Object {
    var mem = [_]Object{Nil}**1000;
    const memSlice: []Object = mem[0..];
    const memPtr = memSlice.ptr;
    var thread = Thread.initForTest() catch unreachable;
    return execute(code.ptr,memPtr+998,memPtr,&thread,memPtr+998);
}
fn execute(next: [*]const Code, tos: [*]Object, heap: [*]Object, thread: *Thread, caller: Context) Object {
    return @call(tailCall,next[1].prim,.{next+2,tos,heap,thread,caller});
}
pub fn branch(next: [*]const Code, tos: [*]Object, heap: [*]Object, thread: *Thread, caller: Context) Object {
    const offset = next[0].int;
    const target = next+@intCast(u64,if (offset>=0) offset else -offset);
    return @call(tailCall,target[0].prim,.{target+1,tos,heap,thread,caller});
}
fn if_true(next: [*]const Code, tos: [*]Object, heap: [*]Object, thread: *Thread, caller: Context) Object {
    const v = tos[0];
    if (True.equals(v)) return @call(tailCall,branch,.{next,tos,heap,thread,caller});
    if (False.equals(v)) return @call(tailCall,next[1].prim,.{next+2,tos+1,heap,thread,caller});
    @panic("non boolean");
}
fn if_false(next: [*]const Code, tos: [*]Object, heap: [*]Object, thread: *Thread, caller: Context) Object {
    const v = tos[0];
    if (False.equals(v)) return @call(tailCall,branch,.{next,tos,heap,thread,caller});
    if (True.equals(v)) return @call(tailCall,next[1].prim,.{next+2,tos+1,heap,thread,caller});
    @panic("non boolean");
}
pub const p = struct {
    fn pushConst(next: [*]const Code, tos: [*]Object, heap: [*]Object, thread: *Thread, caller: Context) Object {
        checkSpace(next,tos,heap,thread,caller,1);
        const newTos = tos-1;
        newTos[0]=next[0].object;
        return @call(tailCall,next[1].prim,.{next+2,newTos,heap,thread,caller});
    }
    fn pushConst0(next: [*]const Code, tos: [*]Object, heap: [*]Object, thread: *Thread, caller: Context) Object {
        checkSpace(next,tos,heap,thread,caller,1);
        const newTos = tos-1;
        newTos[0]=Object.from(0);
        return @call(tailCall,next[1].prim,.{next+2,newTos,heap,thread,caller});
    }
    fn pushConst1(next: [*]const Code, tos: [*]Object, heap: [*]Object, thread: *Thread, caller: Context) Object {
        checkSpace(next,tos,heap,thread,caller,1);
        const newTos = tos-1;
        newTos[0]=Object.from(1);
        return @call(tailCall,next[1].prim,.{next+2,newTos,heap,thread,caller});
    }
    fn push1Nil(next: [*]const Code, tos: [*]Object, heap: [*]Object, thread: *Thread, caller: Context) Object {
        checkSpace(next,tos,heap,thread,caller,1);
        const newTos = tos-1;
        newTos[0]=Nil;
        return @call(tailCall,next[0].prim,.{next+1,newTos,heap,thread,caller});
    }
    usingnamespace @import("primitives.zig");
};
test "simple return via execute" {
    const expectEqual = std.testing.expectEqual;
    const prog = compileTuple(Nil,.{
        return_tos,
    });
    try expectEqual(testExecute(prog[0..]),Nil);
}
test "simple add" {
    const expectEqual = std.testing.expectEqual;
    const prog = compileTuple(Nil,.{
        p.pushConst,3,
        p.pushConst,4,            
        p.p1,"fail",
        return_tos,
        "fail:", failed_test,
    });
    try expectEqual(testExecute(prog[0..]).to(i64),7);
}
test "simple add with overflow" {
    const expectEqual = std.testing.expectEqual;
    const prog = compileTuple(Nil,.{
        p.pushConst, 0x3_ffffffffffff,
        p.pushConst,4,            
        p.p1,"fail",
        failed_test,
        "fail:", return_tos,
    });
    try expectEqual(testExecute(prog[0..]).to(i64),4);
}
test "simple compare" {
    const expectEqual = std.testing.expectEqual;
    const prog = compileTuple(Nil,.{
        p.pushConst,3,
        p.pushConst,4,            
        p.p110,
        return_tos,
    });
    try expectEqual(testExecute(prog[0..]),False);
}
test "simple compare and don't branch" {
    const expectEqual = std.testing.expectEqual;
    const prog = compileTuple(Nil,.{
        p.pushConst,3,
        p.pushConst,4,            
        p.p110,
        if_true,"true",
        p.pushConst,17,
        branch,"common",
        "true:",
        p.pushConst,42,
        "common:", return_tos,
    });
    try expectEqual(testExecute(prog[0..]).to(i64),17);
}
test "simple compare and branch" {
    const expectEqual = std.testing.expectEqual;
    const prog = compileTuple(Nil,.{
        p.pushConst,3,
        p.pushConst,4,            
        p.p169,
        if_true,"true",
        p.pushConst,17,
        branch,"common",
        "true:",
        p.pushConst,42,
        "common:", return_tos,
    });
    try expectEqual(testExecute(prog[0..]).to(i64),42);
}
