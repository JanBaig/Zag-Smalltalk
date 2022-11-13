const std = @import("std");
const debug = std.debug;
const math = std.math;
const tailCall: std.builtin.CallOptions = .{.modifier = .always_tail};
const noInlineCall: std.builtin.CallOptions = .{.modifier = .never_inline};
const stdout = std.io.getStdOut().writer();
const Object = @import("zag/object.zig").Object;
const Nil = @import("zag/object.zig").Nil;
const Code = @import("zag/execute.zig").Code;
const compileMethod = @import("zag/execute.zig").compileMethod;
const ContextPtr = @import("zag/execute.zig").ContextPtr;
const TestExecution = @import("zag/execute.zig").TestExecution;
const Hp = @import("zag/heap.zig").HeaderArray;
const Thread = @import("zag/thread.zig").Thread;
const i = struct {
    usingnamespace @import("zag/primitives.zig").inlines;
};
const p = struct {
    usingnamespace @import("zag/execute.zig").controlPrimitives;
    usingnamespace @import("zag/primitives.zig").primitives;
};
var fibCompM = compileMethod(Nil,0,0,.{fibComp});
const fibCompT = @ptrCast([*]Code,&fibCompM.code[0]);
// fibonacci
//	self <= 2 ifTrue: [ ^ 1 ].
//	^ (self - 1) fibonacci + (self - 2) fibonacci
fn fibNative(self: u64) u64 {
    if (self <= 2) return 1;
    return fibNative(self-1) + fibNative(self-2);
}
fn fibNativeEnd() void {
}
fn fibComp(pc: [*]const Code, sp: [*]Object, hp: Hp, thread: *Thread, context: ContextPtr) void {
    if (i.p5(sp[0],Object.from(2)) catch unreachable) {
        sp[0] = Object.from(1);
        return @call(tailCall,context.npc,.{context.tpc,sp,hp,thread,context});
    }
    const result = context.push(sp,hp,thread,fibThread.asCompiledMethodPtr(),0,1);
    const newContext = result.ctxt;
    const newHp = result.hp;
    const newSp = newContext.asObjectPtr()-1;
    const m1 = i.p2(sp[0],Object.from(1)) catch @panic("int subtract failed in fibComp");
    newSp[0] = m1;
    newContext.tpc = pc+4;
    newContext.npc = fibComp1;
    const fib = fibCompT;
    return @call(tailCall,fib[0].prim,.{fib+1,newSp,newHp,thread,newContext});
}
fn fibComp1(pc: [*]const Code, sp: [*]Object, hp: Hp, thread: *Thread, context: ContextPtr) void {
    const newSp = sp-1;
    const m2 = i.p2(context.getTemp(0),Object.from(2)) catch @panic("int add failed in fibComp1");
    newSp[0] = m2;
    context.tpc = pc+3;
    context.npc = fibComp2;
    const fib = fibCompT;
    return @call(tailCall,fib[0].prim,.{fib+1,newSp,hp,thread,context});
}
fn fibComp2(_: [*]const Code, sp: [*]Object, hp: Hp, thread: *Thread, context: ContextPtr) void {
    const sum = i.p1(sp[1],sp[0]) catch @panic("int add failed in fibComp2");
    context.setTemp(0,sum);
    const result = context.pop(thread,0);
    const newSp = result.sp;
    const callerContext = result.ctxt;
    return @call(tailCall,callerContext.npc,.{callerContext.tpc,newSp,hp,thread,callerContext});
}
var fibThread =
    compileMethod(Nil,0,0,.{
        "fibonacci:",
        p.noop,
        p.dup,
        p.pushLiteral, 2,
        p.p5,
        p.ifFalse,"label3",
        "label2:",
        p.drop,
        p.pushLiteral, 1,
//        p.returnNoContext,
        "label3:",
        p.pushContext,"^",
        p.pushTemp1,
        p.pushLiteral, 1,
        p.p2,
        p.call,"fibonacci",
        p.pushTemp1,
        p.pushLiteral, 2,
        p.p2,
        p.call,"fibonacci",
        p.p1,
//        p.returnTop,
});
test "fibComp" {
    var method = compileMethod(Nil,0,0,.{
        fibComp,
    });
    var n:u32 = 1;
    while (n<40) : (n += 1) {
        var objs = [_]Object{Object.from(n)};
        var te =  TestExecution.init();
        const result = te.run(objs[0..],method.asCompiledMethodPtr());
        std.debug.print("fib({} = {any}\n",.{n,result});
        try std.testing.expectEqual(result.len,1);
        try std.testing.expectEqual(result[0].toInt(),@as(i64,@truncate(u51,fibNative(n))));
    }
}
fn timeComp(n: i64) void {
    var method = compileMethod(Nil,0,0,.{
        fibComp,
    });
    var objs = [_]Object{Object.from(n)};
    var te = TestExecution.new();
    te.init();
    _ = te.run(objs[0..],method.asCompiledMethodPtr());
}
pub fn timing(runs: u32) !void {
    const ts=std.time.nanoTimestamp;
    try stdout.print("for {} runs\n",.{runs});
    var start=ts();
    _ = fibNative(runs);
    var base = ts()-start;
    try stdout.print("fibNative: {d:8.3}s {d:8.3}ns\n",.{@intToFloat(f64,base)/1000000000,@intToFloat(f64,base)/@intToFloat(f64,runs)});
    start=ts();
    _ = timeComp(runs);
    _ = fibThread;
    _ = Object;
    var time = ts()-start;
    try stdout.print("fibComp: {d:8.3}s {d:8.3}ns +{d:6.2}%\n",.{@intToFloat(f64,time)/1000000000,@intToFloat(f64,time)/@intToFloat(f64,runs),@intToFloat(f64,time-base)*100.0/@intToFloat(f64,base)});
    // start=ts();
    // _ = P.run(runs);
    // time = ts()-start;
    // try stdout.print("P: {d:8.3}s {d:8.3}ns +{d:6.2}%\n",.{@intToFloat(f64,time)/1000000000,@intToFloat(f64,time)/@intToFloat(f64,runs),@intToFloat(f64,time-base)*100.0/@intToFloat(f64,base)});
}
pub fn main() !void {
    try timing(40);
}
