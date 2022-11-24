const std = @import("std");
const checkEqual = @import("utilities.zig").checkEqual;
const Thread = @import("thread.zig").Thread;
const object = @import("object.zig");
const Object = object.Object;
const Nil = object.Nil;
const NotAnObject = object.NotAnObject;
const True = object.True;
const False = object.False;
const u64_MINVAL = object.u64_MINVAL;
const heap = @import("heap.zig");
const HeapPtr = heap.HeapPtr;
pub const Hp = heap.HeaderArray;
const Format = heap.Format;
const Age = heap.Age;
const class = @import("class.zig");
const sym = @import("symbol.zig").symbols;
const uniqueSymbol = @import("symbol.zig").uniqueSymbol;
const Context = @import("execute.zig").Context;
const ContextPtr = @import("execute.zig").ContextPtr;
pub const tailCall: std.builtin.CallOptions = .{.modifier = .always_tail};
const noInlineCall: std.builtin.CallOptions = .{.modifier = .never_inline};
pub const TestByteExecution = struct {
    thread: Thread,
    ctxt: Context,
    sp: [*]Object,
    hp: Hp,
    pc: [*] const ByteCode,
    const Self = @This();
    var endSp: [*]Object = undefined;
    var endHp: Hp = undefined;
    var endPc: [*] const ByteCode = undefined;
    var baseByteCodeMethod = CompiledByteCodeMethod.init(Nil,0);
    pub fn new() Self {
        return Self {
            .thread = Thread.new(),
            .ctxt = Context.init(&baseByteCodeMethod),
            .sp = undefined,
            .hp = undefined,
            .pc = undefined,
        };
    }
    pub fn init(self: *Self) void {
        self.thread.init();
    }
    fn end(pc: [*]const ByteCode, sp: [*]Object, hp: Hp, _: *Thread, _: ContextPtr) void {
        endPc = pc;
        endHp = hp;
        endSp = sp;
    }
    pub fn run(self: *Self, source: [] const Object, method: CompiledByteCodeMethodPtr) []Object {
        const sp = self.thread.endOfStack() - source.len;
        for (source) |src,idx|
            sp[idx] = src;
        const pc = method.codePtr();
        const hp = self.thread.getHeap();
        self.ctxt.setNPc(Self.end);
        pc[0].prim(pc+1,sp,hp,&self.thread,&self.ctxt);
        self.sp = endSp;
        self.hp = endHp;
        self.pc = endPc;
        return self.thread.stack(self.sp);
    }
};

pub const CompiledByteCodeMethodPtr = *CompiledByteCodeMethod;
pub const CompiledByteCodeMethod = extern struct {
    header: heap.Header,
    name: Object,
    class: Object,
    stackStructure: Object, // number of local values beyond the parameters
    size: u64,
    code: [1] ByteCode,
    const Self = @This();
    const codeOffset = @offsetOf(CompiledByteCodeMethod,"code");
    const nIVars = codeOffset/@sizeOf(Object)-2;
    comptime {
        if (checkEqual(codeOffset,@offsetOf(CompileTimeByteCodeMethod(.{0}),"code"))) |s|
            @compileError("CompileByteCodeMethod prefix not the same as CompileTimeByteCodeMethod == " ++ s);
    }
    const pr = std.io.getStdOut().writer().print;
    fn init(name: Object, size: u64) Self {
        return Self {
            .header = undefined,
            .name = name,
            .class = Nil,
            .stackStructure = Object.from(0),
            .size = size,
            .code = [1]ByteCode{ByteCode.int(0)},
        };
    }
    fn codeSlice(self: * const CompiledByteCodeMethod) [] const ByteCode{
        @setRuntimeSafety(false);
        return self.code[0..self.codeSize()];
    }
    fn codePtr(self: * const CompiledByteCodeMethod) [*] const ByteCode {
        return @ptrCast([*]const ByteCode,&self.code[0]);
    }
    inline fn codeSize(self: * const CompiledByteCodeMethod) usize {
        return @alignCast(8,&self.header).inHeapSize()-@sizeOf(Self)/@sizeOf(Object)+1;
    }
    fn matchedSelector(pc: [*] const ByteCode) bool {
        _ = pc;
        return true;
    }
    fn methodFromCodeOffset(pc: [*] const ByteCode) CompiledByteCodeMethodPtr {
        const method = @intToPtr(CompiledByteCodeMethodPtr,@ptrToInt(pc)-codeOffset-(pc[0].uint)*@sizeOf(ByteCode));
        return method;
    }
    fn print(self: *Self) void {
        pr("CByteCodeMethod: {} {} {} {} (",.{self.header,self.name,self.class,self.stackStructure}) catch @panic("io");
//            for (self.code[0..]) |c| {
//                pr(" 0x{x:0>16}",.{@bitCast(u64,c)}) catch @panic("io");
//            }
        pr(")\n",.{}) catch @panic("io");
    }
};
pub const ByteCode = enum(u8) {
    noop,
    push,
    exit,
    inline fn int(i: i8) ByteCode {
        @setRuntimeSafety(false);
        return @intToEnum(ByteCode,i);
    }
};
fn countNonLabels(comptime tup: anytype) usize {
    var n = 1;
    inline for (tup) |field| {
        switch (@TypeOf(field)) {
            Object => {n+=1;},
            @TypeOf(null) => {n+=1;},
            comptime_int,comptime_float => {n+=1;},
            ThreadedFn => {n+=1;},
            else => 
                switch (@typeInfo(@TypeOf(field))) {
                    .Pointer => {if (field[field.len-1]!=':') n = n + 1;},
                    else => {n = n+1;},
            }
        }
    }
    return n;
}
fn CompileTimeByteCodeMethod(comptime tup: anytype) type {
    const codeSize = countNonLabels(tup);
    return extern struct { // structure must exactly match CompiledByteCodeMethod
        header: heap.Header,
        name: Object,
        class: Object,
        stackStructure: Object,
        size: u64,
        code: [codeSize] ByteCode,
        const pr = std.io.getStdOut().writer().print;
        const codeOffsetInUnits = CompiledByteCodeMethod.codeOffset/@sizeOf(ByteCode);
        const methodIVars = CompiledByteCodeMethod.nIVars;
        const Self = @This();
        fn init(name: Object, comptime locals: comptime_int) Self {
            return .{
                .header = heap.header(methodIVars,Format.both,class.CompiledByteCodeMethod_I,name.hash24(),Age.static),
                .name = name,
                .class = Nil,
                .stackStructure = Object.packedInt(locals,locals+name.numArgs(),0),
                .size = codeSize,
                .code = undefined,
            };
        }
        pub fn asCompiledByteCodeMethodPtr(self: *Self) * CompiledByteCodeMethod {
            return @ptrCast(* CompiledByteCodeMethod,self);
        }
        pub fn update(self: *Self, tag: Object, method: CompiledByteCodeMethodPtr) void {
            for (self.code) |*c| {
                if (c.object.equals(tag)) c.* = ByteCode.method(method);
            }
        }
        fn headerOffset(_: *Self, codeIndex: usize) ByteCode {
            return ByteCode.uint(codeIndex+codeOffsetInUnits);
        }
        fn getCodeSize(_: *Self) usize {
            return codeSize;
        }
        fn print(self: *Self) void {
            pr("CTByteCodeMethod: {} {} {} {} (",.{self.header,self.name,self.class,self.stackStructure}) catch @panic("io");
            for (self.code[0..]) |c| {
                pr(" 0x{x:0>16}",.{@bitCast(u64,c)}) catch @panic("io");
            }
            pr(")\n",.{}) catch @panic("io");
        }
    };
}
pub fn compileByteCodeMethod(name: Object, comptime parameters: comptime_int, comptime locals: comptime_int, comptime tup: anytype) CompileTimeByteCodeMethod(tup) {
    @setEvalBranchQuota(2000);
    const methodType = CompileTimeByteCodeMethod(tup);
    var method = methodType.init(name,locals);
    comptime var n = 0;
    _ = parameters;
    inline for (tup) |field| {
        switch (@TypeOf(field)) {
            Object => {method.code[n]=ByteCode.object(field);n=n+1;},
            @TypeOf(null) => {method.code[n]=ByteCode.object(Nil);n=n+1;},
            comptime_int => {method.code[n]=ByteCode.int(field);n = n+1;},
            ThreadedFn => {method.code[n]=ByteCode.prim(field);n=n+1;},
            else => {
                comptime var found = false;
                switch (@typeInfo(@TypeOf(field))) {
                    .Pointer => {
                        if (field[field.len-1]==':') {
                            found = true;
                        } else if (field.len==1 and field[0]=='^') {
                            method.code[n]=Code.int(n);
                            n=n+1;
                            found = true;
                        } else if (field.len==1 and field[0]=='*') {
                            method.code[n]=Code.int(-1);
                            n=n+1;
                            found = true;
                        } else {
                            comptime var lp = 0;
                            inline for (tup) |t| {
                                if (@TypeOf(t) == ThreadedFn) lp=lp+1
                                    else
                                    switch (@typeInfo(@TypeOf(t))) {
                                        .Pointer => {
                                            if (t[t.len-1]==':') {
                                                if (comptime std.mem.startsWith(u8,t,field)) {
                                                    method.code[n]=Code.int(lp-n-1);
                                                    n=n+1;
                                                    found = true;
                                                }
                                            } else lp=lp+1;
                                        },
                                        else => {lp=lp+1;},
                                }
                            }
                            if (!found) @compileError("missing label: \""++field++"\"");
                        }
                    },
                    else => {},
                }
                if (!found) @compileError("don't know how to handle \""++@typeName(@TypeOf(field))++"\"");
            },
        }
    }
//    method.code[n]=Code.end();
//    method.print();
    return method;
}
const stdout = std.io.getStdOut().writer();
const print = std.io.getStdOut().writer().print;
test "compiling method" {
    const expectEqual = std.testing.expectEqual;
    const mref = comptime uniqueSymbol(42);
    var m = compileByteCodeMethod(Nil,0,0,.{"abc:", testing.return_tos, "def", True, comptime Object.from(42), "def:", "abc", "*", "^", 3, mref, null});
    const mcmp = m.asCompiledByteCodeMethodPtr();
    m.update(mref,mcmp);
    var t = m.code[0..];
    try expectEqual(t.len,11);
    try expectEqual(t[0].prim,controlPrimitives.noop);
    try expectEqual(t[1].prim,testing.return_tos);
    try expectEqual(t[2].int,2);
    try expectEqual(t[3].object,True);
    try expectEqual(t[4].object,Object.from(42));
    try expectEqual(t[5].int,-5);
    try expectEqual(t[6].int,-1);
    try expectEqual(t[7].int,7);
    try expectEqual(CompiledByteCodeMethod.methodFromCodeOffset((&t[7]).codePtr()),m.asCompiledByteCodeMethodPtr());
    try expectEqual((&t[7]).methodPtr(),mcmp);
    try expectEqual(t[8].int,3);
    try expectEqual(t[9].method,mcmp);
    try expectEqual(t[10].object,Nil);
}
fn execute(pc: [*]const ByteCode, sp: [*]Object, hp: Hp, thread: *Thread, context: ContextPtr) void {
    return @call(tailCall,pc[0].prim,.{pc+1,sp,hp,thread,context});
}
pub const controlPrimitives = struct {
    pub inline fn checkSpace(pc: [*]const ByteCode, sp: [*]Object, hp: Hp, thread: *Thread, context: Context, needed: usize) void {
        _ = thread;
        _ = pc;
        _ = hp;
        _ = context;
        _ = sp;
        _ = needed;
    }
    pub fn noop(pc: [*]const ByteCode, sp: [*]Object, hp: Hp, thread: *Thread, context: ContextPtr) void {
        return @call(tailCall,pc[0].prim,.{pc+1,sp,hp,thread,context});
    }
    pub fn branch(pc: [*]const ByteCode, sp: [*]Object, hp: Hp, thread: *Thread, context: ContextPtr) void {
        const offset = pc[0].int;
        if (offset>=0) {
            const target = pc+1+@intCast(u64, offset);
            if (thread.needsCheck()) return @call(tailCall,Thread.check,.{target,sp,hp,thread,context});
            return @call(tailCall,target[0].prim,.{target+1,sp,hp,thread,context});
        }
        if (offset == -1) {
            const target = context.getTPc();
            if (thread.needsCheck()) return @call(tailCall,Thread.check,.{target,sp,hp,thread,context});
            return @call(tailCall,target[0].prim,.{target+1,sp,hp,thread,context});
        }
        const target = pc+1-@intCast(u64, -offset);
        if (thread.needsCheck()) return @call(tailCall,Thread.check,.{target,sp,hp,thread,context});
        return @call(tailCall,target[0].prim,.{target+1,sp,hp,thread.decCheck(),context});
    }
    pub fn ifTrue(pc: [*]const ByteCode, sp: [*]Object, hp: Hp, thread: *Thread, context: ContextPtr) void {
        const v = sp[0];
        if (True.equals(v)) return @call(tailCall,branch,.{pc,sp+1,hp,thread,context});
        if (thread.needsCheck()) return @call(tailCall,Thread.check,.{pc+2,sp,hp,thread,context});
        if (False.equals(v)) return @call(tailCall,pc[1].prim,.{pc+2,sp+1,hp,thread,context});
        @panic("non boolean");
    }
    pub fn ifFalse(pc: [*]const ByteCode, sp: [*]Object, hp: Hp, thread: *Thread, context: ContextPtr) void {
        const v = sp[0];
        if (False.equals(v)) return @call(tailCall,branch,.{pc,sp+1,hp,thread,context});
        if (True.equals(v)) return @call(tailCall,pc[1].prim,.{pc+2,sp+1,hp,thread,context});
        @panic("non boolean");
    }
    pub fn primFailure(_: [*]const ByteCode, _: [*]Object, _: Hp, _: *Thread, _: ContextPtr) void {
        @panic("primFailure");
    }
    pub fn dup(pc: [*]const ByteCode, sp: [*]Object, hp: Hp, thread: *Thread, context: ContextPtr) void {
        const newSp = sp-1;
        newSp[0]=newSp[1];
        return @call(tailCall,pc[0].prim,.{pc+1,newSp,hp,thread,context});
    }
    pub fn over(pc: [*]const ByteCode, sp: [*]Object, hp: Hp, thread: *Thread, context: ContextPtr) void {
        const newSp = sp-1;
        newSp[0]=newSp[2];
        return @call(tailCall,pc[0].prim,.{pc+1,newSp,hp,thread,context});
    }
    pub fn drop(pc: [*]const ByteCode, sp: [*]Object, hp: Hp, thread: *Thread, context: ContextPtr) void {
        return @call(tailCall,pc[0].prim,.{pc+1,sp+1,hp,thread,context});
    }
    pub fn pushLiteral(pc: [*]const ByteCode, sp: [*]Object, hp: Hp, thread: *Thread, context: ContextPtr) void {
        const newSp = sp-1;
        newSp[0]=pc[0].object;
        return @call(tailCall,pc[1].prim,.{pc+2,newSp,hp,thread,context});
    }
    pub fn pushLiteral0(pc: [*]const ByteCode, sp: [*]Object, hp: Hp, thread: *Thread, context: ContextPtr) void {
        const newSp = sp-1;
        newSp[0]=Object.from(0);
        return @call(tailCall,pc[0].prim,.{pc+1,newSp,hp,thread,context});
    }
    pub fn pushLiteral1(pc: [*]const ByteCode, sp: [*]Object, hp: Hp, thread: *Thread, context: ContextPtr) void {
        const newSp = sp-1;
        newSp[0]=Object.from(1);
        return @call(tailCall,pc[1].prim,.{pc+1,newSp,hp,thread,context});
    }
    pub fn pushNil(pc: [*]const ByteCode, sp: [*]Object, hp: Hp, thread: *Thread, context: ContextPtr) void {
        const newSp = sp-1;
        newSp[0]=Nil;
        return @call(tailCall,pc[0].prim,.{pc+1,newSp,hp,thread,context});
    }
    pub fn pushTrue(pc: [*]const ByteCode, sp: [*]Object, hp: Hp, thread: *Thread, context: ContextPtr) void {
        const newSp = sp-1;
        newSp[0]=True;
        return @call(tailCall,pc[0].prim,.{pc+1,newSp,hp,thread,context});
    }
    pub fn pushFalse(pc: [*]const ByteCode, sp: [*]Object, hp: Hp, thread: *Thread, context: ContextPtr) void {
        const newSp = sp-1;
        newSp[0]=False;
        return @call(tailCall,pc[0].prim,.{pc+1,newSp,hp,thread,context});
    }
    pub fn popIntoTemp(pc: [*]const ByteCode, sp: [*]Object, hp: Hp, thread: *Thread, context: ContextPtr) void {
        context.setTemp(pc[0].uint,sp[0]);
        return @call(tailCall,pc[1].prim,.{pc+2,sp+1,hp,thread,context});
    }
    pub fn popIntoTemp1(pc: [*]const ByteCode, sp: [*]Object, hp: Hp, thread: *Thread, context: ContextPtr) void {
        context.setTemp(0,sp[0]);
        return @call(tailCall,pc[0].prim,.{pc+1,sp+1,hp,thread,context});
    }
    pub fn pushTemp(pc: [*]const ByteCode, sp: [*]Object, hp: Hp, thread: *Thread, context: ContextPtr) void {
        const newSp = sp-1;
        newSp[0]=context.getTemp(pc[0].uint-1);
        return @call(tailCall,pc[1].prim,.{pc+2,newSp,hp,thread,context});
    }
    pub fn pushTemp1(pc: [*]const ByteCode, sp: [*]Object, hp: Hp, thread: *Thread, context: ContextPtr) void {
        const newSp = sp-1;
        newSp[0]=context.getTemp(0);
        return @call(tailCall,pc[0].prim,.{pc+1,newSp,hp,thread,context});
    }
    fn lookupByteCodeMethod(cls: class.ClassIndex,selector: u64) CompiledByteCodeMethodPtr {
        _ = cls;
        _ = selector;
        @panic("unimplemented");
    }
    pub fn send(pc: [*]const ByteCode, sp: [*]Object, hp: Hp, thread: *Thread, context: ContextPtr) void {
        _=pc; _=sp; _=hp; _=thread; _=context;
        @panic("not implemented");
        // const selector = pc[0].object;
        // const numArgs = selector.numArgs();
        // const newPc = lookupByteCodeMethod(sp[numArgs].get_class(),selector.hash32()).codePtr();
        // context.setTPc(pc+1);
        // return @call(tailCall,newPc[0].prim,.{newPc+1,sp,hp,thread,context});
    }
    pub fn call(pc: [*]const ByteCode, sp: [*]Object, hp: Hp, thread: *Thread, context: ContextPtr) void {
        context.setTPc(pc+1);
        const newPc = pc[0].method.codePtr();
        return @call(tailCall,newPc[0].prim,.{newPc+1,sp,hp,thread,context});
    }
    pub fn pushContext(pc: [*]const ByteCode, sp: [*]Object, hp: Hp, thread: *Thread, context: ContextPtr) void {
        const method = CompiledByteCodeMethod.methodFromCodeOffset(pc);
        // can rewrite pc[0] to be direct mathod reference and pc[-1] to be pushContextAlt
        // - so second time will be faster
        // - but need to be careful to do in an idempotent way to guard against another thread executing this in parallel
        const stackStructure = method.stackStructure;
        const locals = stackStructure.h0;
        const maxStackNeeded = stackStructure.h1;
        const result = context.push(sp,hp,thread,method,locals,maxStackNeeded);
        const ctxt = result.ctxt;
        ctxt.setNPc(returnTrampoline);
        return @call(tailCall,pc[1].prim,.{pc+2,result.ctxt.asObjectPtr(),result.hp,thread,ctxt});
    }
    pub fn returnTrampoline(pc: [*]const ByteCode, sp: [*]Object, hp: Hp, thread: *Thread, context: ContextPtr) void {
        return @call(tailCall,pc[0].prim,.{pc+1,sp,hp,thread,context});
    }
    pub fn returnWithContext(pc: [*]const ByteCode, _: [*]Object, hp: Hp, thread: *Thread, context: ContextPtr) void {
        const result = context.pop(thread,pc[0].uint);
        const newSp = result.sp;
        const callerContext = result.ctxt;
        return @call(tailCall,callerContext.getNPc(),.{callerContext.getTPc(),newSp,hp,thread,callerContext});
    }
    pub fn returnTop(pc: [*]const ByteCode, sp: [*]Object, hp: Hp, thread: *Thread, context: ContextPtr) void {
        const top = sp[0];
        const result = context.pop(thread,pc[0].uint);
        const newSp = result.sp;
        newSp[0] = top;
        const callerContext = result.ctxt;
        return @call(tailCall,callerContext.getNPc(),.{callerContext.getTPc(),newSp,hp,thread,callerContext});
    }
    pub fn returnNoContext(_: [*]const ByteCode, sp: [*]Object, hp: Hp, thread: *Thread, context: ContextPtr) void {
        return @call(tailCall,context.getNPc(),.{context.getTPc(),sp,hp,thread,context});
    }
    pub fn dnu(pc: [*]const ByteCode, sp: [*]Object, hp: Hp, thread: *Thread, context: ContextPtr) void {
        _ = pc;
        _ = sp;
        _ = hp;
        _ = thread;
        _ = context;
        @panic("unimplemented");
    }
};
const p = struct {
    usingnamespace controlPrimitives;
};
pub const testing = struct {
    pub fn return_tos(pc: [*]const ByteCode, sp: [*]Object, hp: Hp, thread: *Thread, context: ContextPtr) void {
        _ = pc;
        _ = sp;
        _ = hp;
        _ = thread;
        _ = context;
        return;
    }
    pub fn failed_test(pc: [*]const ByteCode, sp: [*]Object, hp: Hp, thread: *Thread, context: ContextPtr) void {
        _ = pc;
        _ = hp;
        _ = thread;
        _ = context;
        _ = sp;
        @panic("failed_test");
    }
    pub fn unexpected_return(pc: [*]const ByteCode, sp: [*]Object, hp: Hp, thread: *Thread, context: ContextPtr) void {
        _ = pc;
        _ = sp;
        _ = hp;
        _ = thread;
        _ = context;
        @panic("unexpected_return");
    }
    pub fn dumpContext(pc: [*]const ByteCode, sp: [*]Object, hp: Hp, thread: *Thread, context: ContextPtr) void {
        print("pc: 0x{x:0>16} sp: 0x{x:0>16} hp: 0x{x:0>16}",.{pc,sp,hp});
        context.print(sp,thread);
        return @call(tailCall,pc[0].prim,.{pc+1,sp,hp,thread,context});
    }
    pub fn testExecute(method: * const CompiledByteCodeMethod) Object {
        const code = method.codeSlice();
        var context: Context = undefined;
        var thread = Thread.newForTest(null) catch unreachable;
        thread.init();
        var sp = thread.endOfStack()-1;
        sp[0]=Nil;
        execute(code.ptr,sp+1,thread.getHeap(),(&thread).maxCheck(),&context);
        return sp[0];
    }
    pub fn debugExecute(method: * const CompiledByteCodeMethod) Object {
        const code = method.codeSlice();
        var context: Context = undefined;
        var thread = Thread.initForTest(null) catch unreachable;
        var sp = thread.endOfStack()-1;
        sp[0]=Nil;
        execute(code.ptr,sp,thread.getArena().heap,1000,&thread,&context,method.name);
        return sp[0];
    }
};

test "simple return via execute" {
    const expectEqual = std.testing.expectEqual;
    var method = compileByteCodeMethod(Nil,0,0,.{
        p.noop,
        testing.return_tos,
    });
    try expectEqual(testing.testExecute(method.asCompiledByteCodeMethodPtr()),Nil);
}
test "simple return via TestExecution" {
    const expectEqual = std.testing.expectEqual;
    var method = compileByteCodeMethod(Nil,0,0,.{
        p.noop,
        p.pushLiteral,comptime Object.from(42),
        p.returnNoContext,
    });
    var te = TestByteExecution.new();
    te.init();
    var objs = [_]Object{Nil,True};
    var result = te.run(objs[0..],method.asCompiledByteCodeMethodPtr());
    try expectEqual(result.len,3);
    try expectEqual(result[0],Object.from(42));
    try expectEqual(result[1],Nil);
    try expectEqual(result[2],True);
}
test "context return via TestExecution" {
    const expectEqual = std.testing.expectEqual;
    var method = compileByteCodeMethod(Nil,0,0,.{
        p.noop,
        p.pushContext,"^",
        p.pushLiteral,comptime Object.from(42),
        p.returnWithContext,1,
    });
    var te = TestByteExecution.new();
    te.init();
    var objs = [_]Object{Nil,True};
    var result = te.run(objs[0..],method.asCompiledByteCodeMethodPtr());
    try expectEqual(result.len,1);
    try expectEqual(result[0],True);
}
test "context returnTop via TestExecution" {
    const expectEqual = std.testing.expectEqual;
    var method = compileByteCodeMethod(Nil,0,0,.{
        p.noop,
        p.pushContext,"^",
        p.pushLiteral,comptime Object.from(42),
        p.returnTop,1,
    });
    var te = TestByteExecution.new();
    te.init();
    var objs = [_]Object{Nil,True};
    var result = te.run(objs[0..],method.asCompiledByteCodeMethodPtr());
    try expectEqual(result.len,1);
    try expectEqual(result[0],Object.from(42));
}
test "simple executable" {
    var method = compileByteCodeMethod(Nil,0,1,.{
        p.pushContext,"^",
        "label1:",
        p.pushLiteral,comptime Object.from(42),
        p.popIntoTemp,1,
        p.pushTemp1,
        p.pushLiteral0,
        p.pushTrue,
        p.ifFalse,"label3",
        p.branch,"label2",
        "label3:",
        p.pushTemp,1,
        "label4:",
        p.returnWithContext,1,
        "label2:",
        p.pushLiteral0,
        p.branch,"label4",
    });
    var objs = [_]Object{Nil};
    var te = TestByteExecution.new();
    te.init();
    _ = te.run(objs[0..],method.asCompiledByteCodeMethodPtr());
}