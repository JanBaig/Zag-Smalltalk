const std = @import("std");
const config = @import("../config.zig");
const tailCall = config.tailCall;
const trace = config.trace;
const Context = @import("../context.zig").Context;
const execute = @import("../execute.zig");
const SendCache = execute.SendCache;
const ContextPtr = execute.CodeContextPtr;
const Code = execute.Code;
const compileMethod = execute.compileMethod;
const CompiledMethod = execute.CompiledMethod;
const CompiledMethodPtr = execute.CompiledMethodPtr;
const Process = @import("../process.zig").Process;
const object = @import("../zobject.zig");
const Object = object.Object;
const Nil = object.Nil;
const True = object.True;
const False = object.False;
const u64_MINVAL = object.u64_MINVAL;
const Sym = @import("../symbol.zig").symbols;
const heap = @import("../heap.zig");
const MinSmallInteger: i64 = object.MinSmallInteger;
const MaxSmallInteger: i64 = object.MaxSmallInteger;

pub fn init() void {}

pub const inlines = struct {
    pub inline fn p201(self: Object, other: Object) !Object { // value
        _ = self;
        _ = other;
        return error.primitiveError;
    }
    pub inline fn p202(self: Object, other: Object) !Object { // value:
        _ = self;
        _ = other;
        return error.primitiveError;
    }
    pub inline fn p203(self: Object, other: Object) !Object { // value:value:
        _ = self;
        _ = other;
        return error.primitiveError;
    }
    pub inline fn p204(self: Object, other: Object) !Object { // value:value:value:
        _ = self;
        _ = other;
        return error.primitiveError;
    }
    pub inline fn p205(self: Object, other: Object) !Object { // value:value:value:value:
        _ = self;
        _ = other;
        return error.primitiveError;
    }
    pub fn immutableClosure(sp: [*]Object, process: *Process, contextMutable: *ContextPtr) [*]Object {
        const val = sp[0];
        var newSp = sp;
        if (val.isInt() and val.u() <= Object.from(0x3fff_ffff_ffff).u() and val.u() >= Object.from(-0x4000_0000_0000).u()) {
            sp[0] = Object.makeGroup(.numericThunk, @as(u47, @truncate(val.u())));
        } else if (val.isDouble() and (val.u() & 0x1ffff) == 0) {
            sp[0] = Object.makeGroup(.numericThunk, @as(u48, 1) << 47 | @as(u48, @truncate(val.u() >> 17)));
        } else if (val.isImmediate()) {
            sp[0].tag = .immediateThunk;
        } else if (val.isHeapObject()) {
            sp[0].tag = .heapThunk;
        } else {
            newSp = generalClosure(sp + 1, process, val, contextMutable);
        }
        return newSp;
    }
    pub inline fn generalClosure(oldSp: [*]Object, process: *Process, value: Object, contextMutable: *ContextPtr) [*]Object {
        const sp = process.allocStack(oldSp, 4, contextMutable);
        sp[0] = Object.from(&sp[3]);
        sp[0].tag = .heapClosure;
        sp[1] = value;
        sp[2] = Object.from(&valueClosureMethod);
        sp[3] = heap.HeapObject.simpleStackObject(object.ClassIndex.BlockClosure, 2, Sym.value.hash24()).o();
        return sp;
    }
    var valueClosureMethod = CompiledMethod.init2(Sym.value, pushValue, e.returnNoContext);
    pub inline fn fullClosure(oldSp: [*]Object, process: *Process, block: CompiledMethodPtr, contextMutable: *ContextPtr) [*]Object {
        const flags = block.stackStructure.h0 >> 8;
        const fields = flags & 63;
        const sp = process.allocStack(oldSp, fields + 2 - (flags >> 7), contextMutable);
        sp[0] = Object.from(&sp[fields + 1]);
        sp[0].tag = .heapClosure;
        sp[fields] = Object.from(block);
        var f = fields;
        if (flags & 64 != 0) {
            f = f - 1;
            sp[f] = Object.from(contextMutable.*);
        }
        if (flags & 128 != 0) {
            f = f - 1;
            sp[f] = oldSp[0];
        }
        for (sp[1..f]) |*op|
            op.* = Nil;
        sp[fields + 1] = heap.HeapObject.simpleStackObject(object.BlockClosure_C, fields, block.selector.hash24()).o();
        return sp;
    }
    pub inline fn closureData(oldSp: [*]Object, process: *Process, fields: usize, contextMutable: *ContextPtr) [*]Object {
        const sp = process.allocStack(oldSp, fields + 3, contextMutable);
        const ptr = Object.from(&sp[fields + 1]);
        sp[0] = ptr;
        sp[1] = ptr;
        for (sp[2 .. fields + 2]) |*op|
            op.* = Nil;
        sp[fields + 2] = heap.HeapObject.simpleStackObject(fields, object.ClosureData_C, 0).o();
        return sp;
    }
    fn pushValue(_: [*]const Code, sp: [*]Object, process: *Process, context: ContextPtr, selector: Object, cache: SendCache) [*]Object {
        if (!Sym.value.selectorEquals(selector)) {
            const dPc = cache.current();
            return @call(tailCall, dPc[0].prim, .{ dPc+1, sp, process, context, selector, cache.next() });
        }
        const closure = sp[0].to(heap.HeapObjectPtr);
        sp[0] = closure.prevPrev();
        @panic("unfinished");
    }
    fn nonLocalReturn(_: [*]const Code, sp: [*]Object, process: *Process, targetContext: ContextPtr, selector: Object, cache: SendCache) [*]Object {
        const val = sp[0];
        var result = targetContext.pop(process);
        const newSp = result.sp;
        if (!val.equals(object.NotAnObject))
            newSp[0] = val;
        const callerContext = result.ctxt;
        trace("-> {any}", .{callerContext.stack(newSp, process)});
        return @call(tailCall, callerContext.getNPc(), .{ callerContext.getTPc(), newSp, process, @constCast(callerContext), selector, cache});
    }
};
pub const embedded = struct {
    const fallback = execute.fallback;
    const literalNonLocalReturn = enum(u3) { self = 0, true_, false_, nil, minusOne, zero, one, two };
    const nonLocalValues = [_]Object{ object.NotAnObject, True, False, Nil, Object.from(-1), Object.from(0), Object.from(1), Object.from(2) };
    pub fn value(pc: [*]const Code, sp: [*]Object, process: *Process, context: ContextPtr, selector: Object, cache: SendCache) [*]Object {
        const val = sp[0];
        trace("\nvalue: {}",.{val});
        switch (val.tag) {
            // .numericThunk => {
            //     if (((val.u() >> 47) & 1) == 0) {
            //         sp[0] = Object.from(@as(i64, @bitCast(val.u() << 17)) >> 17);
            //     } else {
            //         sp[0] = @as(Object, @bitCast(val.u() << 17));
            //     }
            // },
            // .immediateThunk => sp[0].tag = .immediates,
            // .heapThunk => sp[0].tag = .heap,
            .nonLocalThunk => {
                const targetContext = @as(ContextPtr, @ptrFromInt(val.rawWordAddress()));
                const index = val.u() & 7;
                sp[0] = nonLocalValues[index];
                trace(" {*} {}",.{targetContext,index});
                return @call(tailCall, inlines.nonLocalReturn, .{ pc, sp, process, targetContext, selector, cache });
            },
            // .heapClosure => {
            //     const closure = val.to(heap.HeapObjectPtr);
            //     const method = closure.prev().to(CompiledMethodPtr);
            //     if (method != &inlines.valueClosureMethod) {
            //         const newPc = method.codePtr();
            //         context.setReturn(pc);
            //         return @call(tailCall, newPc[0].prim, .{ newPc + 1, sp, process, context, Sym.value });
            //     }
            //     if (!Sym.value.selectorEquals(method.selector)) @panic("wrong selector"); //return @call(tailCall,e.dnu,.{pc,sp,process,context,selector});
            //     sp[0] = closure.prevPrev();
            // },
            else =>  @panic("unknown block type"),
            //return @call(tailCall, fallback, .{ pc, sp, process, context, Sym.value }),
        }
        return @call(tailCall, pc[0].prim, .{ pc + 1, sp, process, context, selector, cache });
    }
    pub fn @"value:"(pc: [*]const Code, sp: [*]Object, process: *Process, context: ContextPtr, selector: Object, cache: SendCache) [*]Object {
        const val = sp[1];
        switch (val.tag) {
            .numericThunk, .immediateThunk, .heapThunk.nonLocalThunk => @panic("wrong number of parameters"),
            .heapClosure => {
                const closure = val.to(heap.HeapObjectPtr);
                const method = closure.prev().to(CompiledMethodPtr);
                if (!Sym.@"value:".selectorEquals(method.selector)) @panic("wrong selector"); //return @call(tailCall,e.dnu,.{pc,sp,process,context,selector});
                const newPc = method.codePtr();
                context.setReturn(pc);
                if (true) @panic("unfinished");
                return @call(tailCall, newPc[0].prim, .{ newPc + 1, sp, process, context, Sym.value });
            },
            else => @panic("not closure"),
        }
        return @call(tailCall, pc[0].prim, .{ pc + 1, sp, process, context, selector, cache });
    }
    pub fn immutableClosure(pc: [*]const Code, sp: [*]Object, process: *Process, context: ContextPtr, selector: Object, cache: SendCache) [*]Object {
        var mutableContext = context;
        const newSp = inlines.immutableClosure(sp, process, &mutableContext);
        return @call(tailCall, pc[1].prim, .{ pc + 2, newSp, process, mutableContext, selector, cache });
    }
    pub fn generalClosure(pc: [*]const Code, sp: [*]Object, process: *Process, context: ContextPtr, selector: Object, cache: SendCache) [*]Object {
        var mutableContext = context;
        const newSp = inlines.generalClosure(sp + 1, process, sp[0], &mutableContext);
        return @call(tailCall, pc[1].prim, .{ pc + 2, newSp, process, mutableContext, selector, cache });
    }
    pub fn fullClosure(pc: [*]const Code, sp: [*]Object, process: *Process, context: ContextPtr, selector: Object, cache: SendCache) [*]Object {
        var mutableContext = context;
        const block = pc.indirectLiteral();
        const newSp = inlines.fullClosure(sp, process, block, &mutableContext);
        return @call(tailCall, pc[1].prim, .{ pc + 2, newSp, process, mutableContext, selector, cache });
    }
    pub fn closureData(pc: [*]const Code, sp: [*]Object, process: *Process, context: ContextPtr, selector: Object, cache: SendCache) [*]Object {
        var mutableContext = context;
        const newSp = inlines.closureData(sp, process, pc[0].uint, &mutableContext);
        return @call(tailCall, pc[1].prim, .{ pc + 2, newSp, process, mutableContext, selector, cache });
    }

    inline fn nonLocalBlock(sp: [*]Object, tag: literalNonLocalReturn, context: ContextPtr) [*]Object {
        // [^self] [^true] [^false] [^nil] [^-1] [^0] [^1] [^2]
        const newSp = sp - 1;
        newSp[0] = Object.tagged(.nonLocalThunk,@intFromEnum(tag),context.cleanAddress());
        return newSp;
    }
    pub fn pushNonlocalBlock_self(pc: [*]const Code, sp: [*]Object, process: *Process, context: ContextPtr, selector: Object, cache: SendCache) [*]Object {
        return @call(tailCall, pc[0].prim, .{ pc + 1, nonLocalBlock(sp, .self, context), process, context, selector, cache });
    }
    pub fn pushNonlocalBlock_true(pc: [*]const Code, sp: [*]Object, process: *Process, context: ContextPtr, selector: Object, cache: SendCache) [*]Object {
        return @call(tailCall, pc[0].prim, .{ pc + 1, nonLocalBlock(sp, .true_, context), process, context, selector, cache });
    }
    pub fn pushNonlocalBlock_false(pc: [*]const Code, sp: [*]Object, process: *Process, context: ContextPtr, selector: Object, cache: SendCache) [*]Object {
        return @call(tailCall, pc[0].prim, .{ pc + 1, nonLocalBlock(sp, .false_, context), process, context, selector, cache });
    }
    pub fn pushNonlocalBlock_nil(pc: [*]const Code, sp: [*]Object, process: *Process, context: ContextPtr, selector: Object, cache: SendCache) [*]Object {
        return @call(tailCall, pc[0].prim, .{ pc + 1, nonLocalBlock(sp, .nil, context), process, context, selector, cache });
    }
    pub fn pushNonlocalBlock_minusOne(pc: [*]const Code, sp: [*]Object, process: *Process, context: ContextPtr, selector: Object, cache: SendCache) [*]Object {
        return @call(tailCall, pc[0].prim, .{ pc + 1, nonLocalBlock(sp, .minusOne, context), process, context, selector, cache });
    }
    pub fn pushNonlocalBlock_zero(pc: [*]const Code, sp: [*]Object, process: *Process, context: ContextPtr, selector: Object, cache: SendCache) [*]Object {
        return @call(tailCall, pc[0].prim, .{ pc + 1, nonLocalBlock(sp, .zero, context), process, context, selector, cache });
    }
    pub fn pushNonlocalBlock_one(pc: [*]const Code, sp: [*]Object, process: *Process, context: ContextPtr, selector: Object, cache: SendCache) [*]Object {
        return @call(tailCall, pc[0].prim, .{ pc + 1, nonLocalBlock(sp, .one, context), process, context, selector, cache });
    }
    pub fn pushNonlocalBlock_two(pc: [*]const Code, sp: [*]Object, process: *Process, context: ContextPtr, selector: Object, cache: SendCache) [*]Object {
        return @call(tailCall, pc[0].prim, .{ pc + 1, nonLocalBlock(sp, .two, context), process, context, selector, cache });
    }
};
fn testImmutableClosure(process: *Process, value: Object) !object.Group {
    const ee = std.testing.expectEqual;
    var context = Context.init();
    const sp = process.endOfStack() - 1;
    sp[0] = value;
    var cache = execute.SendCacheStruct.init();
    const newSp = embedded.immutableClosure(Code.endThread, sp, process, &context, Nil,cache.dontCache());
    if (newSp != sp) {
        try ee(value.u(), newSp[1].u());
    }
    const tag = newSp[0].tag;
    const newerSp = embedded.value(Code.endThread, newSp, process, &context, Nil,cache.dontCache());
    try ee(value.u(), newerSp[0].u());
    return tag;
}
test "immutableClosures" {
    const ee = std.testing.expectEqual;
    var process = Process.new();
    process.init();
    try ee(try testImmutableClosure(&process, Object.from(1)), .numericThunk);
    try ee(try testImmutableClosure(&process, Object.from(-1)), .numericThunk);
    try ee(try testImmutableClosure(&process, Object.from(0x3fff_ffff_ffff)), .numericThunk);
    try ee(try testImmutableClosure(&process, Object.from(-0x4000_0000_0000)), .numericThunk);
    try ee(try testImmutableClosure(&process, Object.from(1000.75)), .numericThunk);
    try ee(try testImmutableClosure(&process, Object.from(-1000.75)), .numericThunk);
    try ee(try testImmutableClosure(&process, Nil), .immediateThunk);
    try ee(try testImmutableClosure(&process, Object.from(&process)), .heapThunk);
    try ee(try testImmutableClosure(&process, Object.from(0x4000_0000_0000)), .heapClosure);
    try ee(try testImmutableClosure(&process, Object.from(-0x4000_0000_0001)), .heapClosure);
    try ee(try testImmutableClosure(&process, Object.from(1000.3)), .heapClosure);
}
pub const primitives = struct {
    pub fn p201(pc: [*]const Code, sp: [*]Object, process: *Process, context: ContextPtr, selector: Object, cache: SendCache) [*]Object { // value
        if (!Sym.value.selectorEquals(selector)) return @call(tailCall, execute.dnu, .{ pc, sp, process, context, selector, cache });
        unreachable;
    }
    pub fn p202(pc: [*]const Code, sp: [*]Object, process: *Process, context: ContextPtr, selector: Object, cache: SendCache) [*]Object { // value:
        _ = .{ pc, sp, process, context, selector, cache };
        unreachable;
    }
    pub fn p203(pc: [*]const Code, sp: [*]Object, process: *Process, context: ContextPtr, selector: Object, cache: SendCache) [*]Object { // value:value:
        _ = .{ pc, sp, process, context, selector, cache };
        unreachable;
    }
    pub fn p204(pc: [*]const Code, sp: [*]Object, process: *Process, context: ContextPtr, selector: Object, cache: SendCache) [*]Object { // value:value:value:
        _ = .{ pc, sp, process, context, selector, cache };
        unreachable;
    }
    pub fn p205(pc: [*]const Code, sp: [*]Object, process: *Process, context: ContextPtr, selector: Object, cache: SendCache) [*]Object { // value:value:value:value:
        _ = .{ pc, sp, process, context, selector, cache };
        unreachable;
    }
};
const e = struct {
    usingnamespace @import("../execute.zig").controlPrimitives;
    usingnamespace embedded;
};
