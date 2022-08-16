const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const object = @import("object.zig");
const Object = object.Object;
const Nil = object.Nil;
const True = object.True;
const False = object.False;
const class = @import("class.zig");
const ClassIndex = class.ClassIndex;
const native_endian = builtin.target.cpu.arch.endian();
pub const externalPageSize = 3100;
test "size assertions" {
    try std.testing.expect(externalPageSize<heapMethods.maxLength);
}
const objectAllocationSize = (externalPageSize*@sizeOf(Object)*2+mem.page_size-1) & -mem.page_size;
pub const Format = enum(u8) {
    none = 0,
    object = InstVars,
    array = Indexable,
    both = InstVars + Indexable,
    weak = InstVars + Indexable + Weak,
    objectNP = InstVars + PointerFree,
    arrayNP = Indexable + PointerFree,
    bothNP = InstVars + Indexable + PointerFree,
    raw64 = Indexable_64,
    _,
    const Self = @This();
    const InstVars : u8 = 1;
    const Indexable : u8 = 2;
    const Weak : u8 = 4;
    const PointerFree : u8 = 8;
    const RawData : u8 = 16;
    const Indexable_64 : u8 = 17;
    const Indexable_32 : u8 = 18;
    const Indexable_16 : u8 = 20;
    const Indexable_8 : u8 = 24;
    const BaseFormat : u8 = 31;
    const Immutable : u8 = 32;
    const Global : u8 = 64;
    fn calcSizes() [BaseFormat+1]u8 {
        var sizes : [BaseFormat+1]u8 = undefined;
        for (sizes) |*size,i| {
           if (i<Indexable_32) size.* = 1
            else if (i<Indexable_16) size.* = 2
            else if (i<Indexable_8) size.* = 4
            else size.* = 8;
        }
        return sizes;
    }
    const fieldSizes = [_]u8{calcSizes()};
    fn calcPartials() [BaseFormat+1]u8 {
        var partials : [BaseFormat+1]u8 = undefined;
        for (partials) |*partial,i| {
            if (i<Indexable_32) partial.* = 0
            else if (i<Indexable_16) partial.* = Indexable_32-i
            else if (i<Indexable_8) partial.* = Indexable_16-i
            else partial.* = Indexable_8-i;
        }
        return partials;
    }
    const fieldPartials = [_]u8{calcPartials()};
    pub inline fn weak(self: Self) Self {
        return self.nonBasePlus(InstVars + Indexable + Weak);
    }
    pub inline fn noBase(self: Self) Self {
        return self.nonBase();
    }
    pub inline fn object(self: Self) Self {
        return @intToEnum(Self,@bitCast(u8,self) | InstVars);
    }
    pub inline fn nonBase(self: Self) Self {
        return @intToEnum(Self,@bitCast(u8,self) & ~BaseFormat);
    }
    pub inline fn nonBasePlus(self: Self, n: isize) Self {
        return @intToEnum(Self,@bitCast(u8,self.nonBase())+@truncate(u8,@intCast(usize,n)));
    }
    pub inline fn base(self: Self) Self {
        return @intToEnum(Self,@bitCast(u8,self) & BaseFormat);
    }
    pub inline fn array(self: Self) Self {
        return @intToEnum(Self,@bitCast(u8,self) | Indexable);
    }
    pub inline fn raw(self: Self, comptime T : type, size : usize) Self {
        switch (T) {
            u8,i8 => {return self.nonBasePlus(Indexable_8 + ((-@intCast(isize,size))&7));},
        u16,i16 => {return self.nonBasePlus(Indexable_16 + ((-@intCast(isize,size))&3));},
            u32,i32,f32 => {return self.nonBasePlus(Indexable_32 + ((-@intCast(isize,size))&1));},
            u64,i64,f64 => {return self.nonBasePlus(Indexable_64);},
            else => {return self;},
        }
    }
    pub inline fn hasInstVars(self: Self) bool {
        return @bitCast(u8, self) & InstVars+RawData == InstVars;
    }
    pub inline fn isIndexable(self: Self) bool {
        return @bitCast(u8, self) & Indexable+RawData != 0;
    }
    pub inline fn hasBoth(self: Self) bool {
        return @bitCast(u8, self) & InstVars+Indexable+RawData == InstVars+Indexable;
    }
    pub inline fn isWeak(self: Self) bool {
        return @bitCast(u8, self) & Weak+RawData == Weak;
    }
    pub inline fn isPointerFree(self: Self) bool {
        return @bitCast(u8,self.base()) >= PointerFree;
    }
    pub inline fn hasPointers(self: Self) bool {
        return ~self.isPointerFree();
    }
    pub inline fn isRaw(self: Self) bool {
        return @bitCast(u8,self.base()) >= RawData;
    }
    pub inline fn is64(self: Self) bool {
        return self.base() == Indexable_64;
    }
    pub inline fn is32(self: Self) bool {
        return self.base() >= Indexable_32 and self.base() <= Indexable_32 + 1;
    }
    pub inline fn is16(self: Self) bool {
        return self.base() >= Indexable_16 and self.base() <= Indexable_16 + 3;
    }
    pub inline fn is8(self: Self) bool {
        return self.base() >= Indexable_8 and self.base() <= Indexable_8 + 7;
    }
    pub inline fn isImmutable(self: Self) bool {
        return @bitCast(u8, self) & Immutable != 0;
    }
    pub inline fn isGlobal(self: Self) bool {
        return @bitCast(u8, self) & Global != 0;
    }
    fn eq(f: Self, v: u8) !void {
        return std.testing.expectEqual(v,@enumToInt(f));
    }
};
test "raw formats" {
    try Format.none.raw(u8,0).eq(Format.Indexable_8+0);
    try Format.none.raw(u8,1).eq(Format.Indexable_8+7);
    try Format.none.raw(u8,2).eq(Format.Indexable_8+6);
    try Format.none.raw(u8,3).eq(Format.Indexable_8+5);
    try Format.none.raw(u8,4).eq(Format.Indexable_8+4);
    try Format.none.raw(u8,5).eq(Format.Indexable_8+3);
    try Format.none.raw(u8,6).eq(Format.Indexable_8+2);
    try Format.none.raw(u8,7).eq(Format.Indexable_8+1);
    try Format.none.raw(u8,8).eq(Format.Indexable_8+0);
}
test "header formats" {
    const expect = std.testing.expect;
    try expect(Format.object.hasInstVars());
    try expect(!Format.object.isPointerFree());
    try expect(Format.objectNP.isPointerFree());
    try expect(!Format.object.isIndexable());
    try expect(Format.raw64.isPointerFree());
    try expect(!Format.raw64.isWeak());
    try expect(!Format.object.isWeak());
    try expect(Format.weak.isWeak());
}
pub const HeaderArray = [*]align(@alignOf(u64)) Header;
pub const HeapPtr = *align(@alignOf(u64)) Header;
pub const HeapConstPtr = *align(@alignOf(u64)) const Header;
const heapMethods = struct {
    const forwardLength : u16 = 4095 << 4;
    const indirectLength : u16 = 4094 << 4;
    const maxLength = 4093;
    pub inline fn forwardedTo(self: HeapConstPtr) HeapConstPtr {
        return @intToPtr(HeapConstPtr,@intCast(u64,@intCast(i64,@bitCast(u64,self.*)<<16)>>16));
    }
    pub inline fn isForwarded(self: HeapConstPtr) bool {
        return self.length>=forwardLength;
    }
    pub inline fn forwarded(self: HeapConstPtr) HeapConstPtr {
        var ptr = self;
        while (ptr.isForwarded()) {
            ptr = ptr.forwardedTo();
        }
        return ptr;
    }
    pub inline fn isIndirect(self: HeapConstPtr) bool {
        return self.length>=indirectLength and self.length<forwardLength;
    }
    pub fn arrayAsSlice(self: HeapConstPtr, comptime T: type) []T {
        const scale = @sizeOf(Object)/@sizeOf(T);
        const ptr = self.forwarded();
        const form = ptr.objectFormat;
        if (form.isRaw()) {
            const formi = @enumToInt(form);
            var size :usize = ptr.length;
            var oa = ptr.asObjectArray();
            if (ptr.isIndirect()) {
                size = @bitCast(usize,oa[0]);
                oa += 1;
                @panic("incomplete");
            }
            return mem.bytesAsSlice(
                T,
                if (formi>=Format.Indexable_8) @ptrCast([*]T,oa)[0..size*scale-(formi&7)]
                    else if (formi>=Format.Indexable_16) @ptrCast([*]T,oa)[0..size*scale-(formi&3)]
                    else if (formi>=Format.Indexable_32) @ptrCast([*]T,oa)[0..size*scale-(formi&1)]
                    else @ptrCast([*]T,oa)[0..size*scale]);
        } else {
            const size = ptr.length;
            const oa = ptr.asObjectArray();
            return mem.bytesAsSlice(
                T,
                if (!form.isIndexable()) (&[0]T{})
                    else if (form.hasInstVars()) @ptrCast([*]T,oa+size+1)[0..@bitCast(usize,oa[size])*scale]
                    else @ptrCast([*]T,oa)[0..size*scale]);
        }
    }
    pub inline fn isIndexable(self: HeapConstPtr) bool {
        return self.objectFormat.isIndexable();
    }
    pub inline fn isRaw(self: HeapConstPtr) bool {
        return self.objectFormat.isRaw();
    }
    pub inline fn asObject(self: HeapConstPtr) Object {
        return Object.from(self);
    }
    pub inline fn asObjectPtr(self: HeapConstPtr) [*]Object {
        return @bitCast([*]Object,self);
    }
    pub inline fn fromObjectPtr(op:  [*]const Object) HeapConstPtr {
        return @bitCast(HeapPtr,op);
    }
    pub inline fn o(self: Header) Object {
        return @bitCast(Object,self);
    }
    pub inline fn asObjectArray(self: HeapConstPtr) [*]align(@alignOf(u64)) Object {
        return @intToPtr([*]align(@alignOf(u64)) Object, @ptrToInt(self)) + 1;
    }
    pub inline fn setHash(self: HeapPtr,hash: u24) Header {
        self.hash=hash;
        return self.*;
    }
    pub inline fn setNArgs(self: HeapPtr,args: u8) Header {
        self.hash=(self.hash & 0xffff)+(args<<16);
        return self.*;
    }
    pub inline fn instVars(self: HeapConstPtr) []Object {
        if (self.objectFormat.hasInstVars()) {
            const size = self.length;
            return self.asObjectArray()[0..size];
        } else return &[0]Object{};
    }
    pub inline fn indexables(self: HeapConstPtr,comptime T:type) []T {
        const form = self.objectFormat;
        const formi = @enumToInt(form);
        const size = self.length;
        const oa = self.asObjectArray();
        switch (T) {
            Object => {
                if (form.hasInstVars()) {
                    const array_size = @bitCast(usize,oa[size]);
                    return oa[size+1..size+array_size+1];
                } else {
                    return oa[0..size];
                }
            },
            i64,u64,f64 => {
                return @ptrCast([*]T,oa)[0..size];
            },
            i32,u32,f32 => {
                return @ptrCast([*]T,oa)[0..size*2-(formi&1)];
            },
            i16,u16 => {
                return @ptrCast([*]T,oa)[0..size*4-(formi&3)];
            },
            i8,u8 => {
                return @ptrCast([*]T,oa)[0..size*8-(formi&7)];
            },
            else => {},
        }
        unreachable;
    }
    pub inline fn getClass(self: HeapConstPtr) ClassIndex {
        return self.classIndex;
    }
    pub inline fn totalSize(self: HeapConstPtr) usize {
        const form = self.objectFormat;
        var size : usize = self.length;
        if (form.isRaw()) {
            if (size>=32767) size += self.asObjectArray()[0].u()+1;
        } else if (form.hasBoth()) {
            size += self.asObjectArray()[size].u()+1;
        }
        @panic("incomplete");
//        return size+1;
    }
    fn @"format FUBAR"(
        self: HeapConstPtr,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) std.os.WriteError!void {
        _ = fmt;
        _ = options;
        if (self.objectFormat.isRaw()) {
            if (self.objectFormat.is8() and self.classIndex==class.String) {
                try writer.print("{s}",.{self.indexables(u8)});
            } else if (self.objectFormat.is8()) {
                try writer.print("raw[{}]",.{self.indexables(u8).len});
            } else if (self.objectFormat.is16()) {
                try writer.print("raw[{}]",.{self.indexables(u16).len});
            } else if (self.objectFormat.is32()) {
                try writer.print("raw[{}]",.{self.indexables(u32).len});
            } else try writer.print("raw[{}]",.{self.indexables(u64).len});
        } else {
            var blank = false;
            const ivs = self.instVars();
            if (ivs.len>0) {
                try writer.print("#(",.{});
                for (ivs) |item| {
                    if (blank) try writer.print(" ",.{});
                    blank = true;
                    try writer.print("{}",.{item});
                }
                try writer.print(")",.{});
            }
            if (self.objectFormat.isIndexable()) {
                const idx = self.indexables(Object);
                if (blank) try writer.print(" ",.{});
                blank = false;
                try writer.print("{c}",.{'{'});
                for (idx) |item| {
                    if (blank) try writer.print(" ",.{});
                    blank = true;
                    try writer.print("{}",.{item});
                }
                try writer.print("{c}",.{'}'});
            }
        }
    }
};
pub const Header = switch (native_endian) {
    .Big => packed struct {
        length: u16, // align(8),
        objectFormat: Format,
        hash: u24,
        classIndex: u16,
        usingnamespace heapMethods;
        pub const includesHeader = true;
    },
    .Little => packed struct {
        classIndex: u16, // align(8),
        hash: u24,
        objectFormat: Format,
        length: u16,
        usingnamespace heapMethods;
        pub const includesHeader = true;
    },
};
pub inline fn header(length : u16, format : Format, classIndex : u16, hash: u24) Header {
    return Header {
        .length = length,
        .objectFormat = format,
        .hash = hash,
        .classIndex = classIndex,
    };
}
test "Header structure" {
    const expect = std.testing.expect;
    try expect(@sizeOf(Header) == 8);
    const hdr = header(17, Format.object, 35,0x123);
    try expect(hdr.o().u() == 0x0011010001230023);
}
pub inline fn arenaFree(stackPointer: [*]const Object, heapPointer: HeapConstPtr) isize {
    return @divFloor(@bitCast(isize,(@ptrToInt(stackPointer)-%@ptrToInt(heapPointer))),@sizeOf(Object));
    }
test "arenaFree" {
    const testing = std.testing;
    const stack: [10]Object=undefined;
    const s1: [*]const Object = @ptrCast([*]const Object,&stack[1]);
    const s5 = s1+4;
    const hp: HeapPtr = Header.fromObjectPtr(s1+2);
    try testing.expectEqual(arenaFree(s5,hp),2);
    try testing.expectEqual(arenaFree(s1,hp),-2);
}
const nurserySize = 2048;
pub const NurseryArena = Arena {
    .vtable = nurseryVtable,
    .heap = undefined,
    .toh = undefined,
    .allocated = undefined,
    .collectTo = undefined,
    .size = nurserySize,
};
const nurseryVtable =  Arena.Vtable {
    .getGlobal = getGlobalNext,
};
fn getGlobalNext(self: *const Arena) *Arena {
    if (self.collectTo) | ptr | return ptr.getGlobal();
    @panic("nothing to collect to");
}
pub const TeenArena = Arena {
    .vtable = teenVtable,
    .heap = undefined,
    .toh = undefined,
    .allocated = undefined,
    .collectTo = undefined,
    .size = nurserySize*3,
};
const teenVtable =  Arena.Vtable {
    .getGlobal = getGlobalNext,
};
const GlobalArena = Arena {
    .vtable = globalVtable,
    .heap = undefined,
    .toh = undefined,
    .allocated = undefined,
    .collectTo = undefined,
    .size = 32768,
};
const globalVtable =  Arena.Vtable {
    .getGlobal = getGlobalSelf,
};
pub const TestArena = Arena {
    .vtable = testVtable,
    .heap = undefined,
    .toh = undefined,
    .allocated = undefined,
    .collectTo = undefined,
    .size = 32768,
};
const testVtable =  Arena.Vtable {
    .getGlobal = getGlobalSelf,
};
fn getGlobalSelf(self: *const Arena) *Arena {
    return @intToPtr(*Arena,@ptrToInt(self));
}

pub const Arena = struct {
    vtable: Vtable,
    heap: HeapPtr,
    toh: [*]Object,
    allocated: []Object,
    collectTo: ?*Arena,
    size: usize,
    const Self = Arena;
    const Vtable = struct {
        getGlobal : arenaStar_to_arenaStar,
    };
    const arenaStar_to_arenaStar = fn (self: *const Arena) *Arena;
    const vtable = Vtable {
        .getGlobal = getGlobalV,
    };
    fn getGlobalV(_: *const Arena) *Arena {
        @panic("missing vtable:getGlobal");
    }
    pub fn getGlobal(self: *const Arena) *Arena {
        return self.vtable.getGlobal(self);
    }
    pub fn space(self: *const Arena) isize {
        return @intCast(i64,@ptrToInt(self.toh))-@intCast(i64,@ptrToInt(self.heap));
    }
    pub fn setCollectTo(self: *Arena, collectTo: ?*Arena) void {
        self.collectTo = collectTo;
    }
    pub fn init(self: *const Arena) !Arena {
        const allocated = std.heap.page_allocator.alignedAlloc(Object,Object.alignment,self.size) catch |err| return err;
        //try std.io.getStdOut().writer().print("allocated ptr=0x{x:0>16} len={}\n",.{@ptrToInt(allocated.ptr),allocated.len});
        return Arena {
            .vtable = self.vtable,
            .heap = @ptrCast(HeapPtr,allocated.ptr),
            .toh = allocated.ptr+allocated.len,
            .collectTo = null,
            .allocated = allocated,
            .size = allocated.len,
        };
    }
    pub fn with(self: *const Arena, expected: []Object) !Arena {
        const size = expected.len+4;
        const allocated = std.heap.page_allocator.alignedAlloc(Object,Object.alignment,size) catch |err| return err;
        //const stdout =  std.io.getStdOut().writer();
        //try stdout.print("allocated ptr=0x{x} len={}\n",.{@ptrToInt(allocated.ptr),allocated.len});

        //try stdout.print("heap=0x{x:0>16} tos=0x{x:0>16}\n",.{@ptrToInt(allocated.ptr+1),@ptrToInt(allocated.ptr+1+expected.len)});
        return Arena {
            .vtable = self.vtable,
            .heap = @ptrCast(HeapPtr,allocated.ptr+1),
            .toh = allocated.ptr+1+expected.len,
            .collectTo = null,
            .allocated = allocated,
            .size = size,
        };
    }
    pub fn deinit(self : *Self) void {
        //std.io.getStdOut().writer().print("deallocate ptr=0x{x:0>16} len={}\n",.{@ptrToInt(self.allocated.ptr),self.allocated.len}) catch unreachable;
        std.heap.page_allocator.free(self.allocated);
        self.* = undefined;
    }
    fn verify(self: *Self, expected: []Object) !void {
        const stdout =  std.io.getStdOut().writer();
        if (@ptrCast([*]Object,self.heap)!=self.toh) {
            stdout.print("heap=0x{x:0>16} toh=0x{x:0>16}\n",.{@ptrToInt(self.heap),@ptrToInt(self.toh)}
                         ) catch unreachable;
            return error.HeapDidnotEndUpAtEnd;
        }
        var ok=true;
        for (expected) |item, index| {
            if (self.allocated[index+1].u() != item.u()) {
                if (item.is_double() and std.math.fabs(item.to(f64))<0.00001) {
                    try stdout.print("comparing[{}] expected=0x{x:0>16} output=0x{x:0>16}\n",
                                 .{index,item.u(),self.allocated[index+1].u()});
                } else try stdout.print("comparing[{}] expected={} output={}\n",.{index,item,self.allocated[index+1]});
                ok = false;
            }
        }
        if (!ok) return error.OutputDiffered;
    }
    pub fn promote(self: *Self, obj: Object) !Object {
        if (!obj.is_heap()) return obj;
        const result = self.heap;
        const ptr = obj.to(HeapConstPtr);
        const totalSize = ptr.totalSize();
        const end = @ptrCast(HeapPtr,@ptrCast([*]Header,self.heap) + totalSize);
        if (@ptrToInt(end)>@ptrToInt(self.toh)) return error.HeapFull;
        self.heap = end;
        @memcpy(@ptrCast([*]u8,result),@ptrCast([*]const u8,ptr),totalSize*8);
        return result.asObject();
    }
    pub fn allocObject(self : *Self, classIndex : class.ClassIndex, format: Format, iv_size : usize, array_size : usize) !HeapPtr {
        var form = format.noBase();
        var totalSize = iv_size + array_size + 1;
        if (iv_size>0) form=form.object();
        if (array_size>0) {
            form=form.array();
            if (array_size>32766) form=form.object(); // big arrays use Format.both
        }
        if (format.isWeak()) form=form.weak();
        if (form.hasBoth()) totalSize += 1;
        const size = if (form.hasInstVars()) iv_size else array_size;
        return self.alloc(classIndex, form, iv_size, array_size, size, totalSize, object.Nil);
    }
    pub fn allocRaw(self : *Self, classIndex : class.ClassIndex, array_size : usize, comptime T: type) !HeapPtr {
        const objectWidth = @sizeOf(Object);
        const width = @sizeOf(T);
        const asize = (array_size*width+objectWidth-width)/objectWidth;
        const form = Format.none.raw(T,array_size);
        const size = @minimum(asize,heapMethods.maxLength);
        var totalSize = asize+@as(usize,if (size<asize) 2 else 1);
        return self.alloc(classIndex, form, 0, asize, size, totalSize, object.ZERO); //,&[0]Object{});
    }
    pub fn allocStruct(self : *Self, classIndex : class.ClassIndex, width : usize, comptime T: type, fill: Object) !*T {
        const objectWidth = @sizeOf(Object);
        const asize = (width+objectWidth-1)/objectWidth;
        const form = Format.object;
        var totalSize = asize+1;
        return @ptrCast(*T,@alignCast(8,try self.alloc(classIndex, form, asize, 0, asize, totalSize, fill)));
    }
    fn alloc(self: *Self, classIndex: class.ClassIndex, form: Format, iv_size: usize, asize: usize, size: usize, totalSize: usize, fill: Object) !HeapPtr {
        const result = self.heap;
        const end = @ptrCast(HeapPtr,@ptrCast([*]Header,self.heap) + totalSize);
        if (self.space()<0) {
            const stdout = std.io.getStdOut().writer();
            stdout.print("classIndex={} totalSize={} end=0x{X:0>16} toh=0x{X:0>16}\n",.{classIndex,totalSize,@ptrToInt(end),@ptrToInt(self.toh)}) catch unreachable;
            return error.HeapFull;
        }
        self.heap = end;
        const hash = if (builtin.is_test) 0 else @truncate(u24,@truncate(u32,@ptrToInt(result))*%object.u32_phi_inverse>>8);
        const head = header(@intCast(u16,size),form,classIndex,hash);
        result.* = @bitCast(Object,head);
        mem.set(Object,@ptrCast([*]Object,result)[1..totalSize],fill);
        if (totalSize>size+1) @ptrCast([*]Object,result)[iv_size+1] = @bitCast(Object,asize);
        return @ptrCast(HeapPtr,result);
    }
    pub  fn allocString(self: *Self, source: []const u8) !HeapPtr {
        const result = try self.allocRaw(class.String_I,source.len,u8);
        //const stdout = std.io.getStdOut().writer();
        //stdout.print("result={} ptr=0x{x:0>16} len={}\n",.{result,@ptrToInt(result.indexables(u8).ptr),result.indexables(u8).len}) catch unreachable;
        mem.copy(u8,result.indexables(u8),source);
        return result;
    }
    pub inline fn allocGlobalString(self: *Self, source: []const u8) !HeapPtr {
        return self.getGlobal().allocString(source);
    }
};
pub fn tempArena(bytes: []align(Object.alignment)u8) Arena {
    var allocated = mem.bytesAsSlice(Object,bytes);
    return Arena {
        .vtable = GlobalArena.vtable,
        .heap = @ptrCast(HeapPtr,allocated.ptr),
        .toh = allocated.ptr+allocated.len,
        .collectTo = undefined,
        .allocated = allocated,
        .size = allocated.len,
    };
}
test "temp arena" {
    const testing = std.testing;
    var buffer: [40]u8 align(8)= undefined;
    var testArena = tempArena(&buffer);
    const obj1 : HeapPtr = try testArena.allocObject(42,Format.none,3,0);
    try testing.expectEqual(@alignOf(@TypeOf(obj1)),Object.alignment);
    try testing.expect(obj1.asObject().is_heap());
    try testing.expectEqual(obj1.totalSize(),4);
    try testing.expectError(error.HeapFull,testArena.allocObject(42,Format.none,3,0));
}
test "slicing" {
    const testing = std.testing;
    var buffer: [128]u8 align(8)= undefined;
    var testArena = tempArena(&buffer);
    const hp0 = try testArena.allocObject(42,Format.none,1,0);
    try testing.expectEqual(hp0.arrayAsSlice(u8).len,0);
    const hp1 = try testArena.allocObject(42,Format.none,1,2);
    const obj1 = hp1.asObject();
    try testing.expectEqual(hp1.arrayAsSlice(u8).len,16);
    try testing.expectEqual(obj1.arrayAsSlice(u8).len,16);
    try testing.expectEqual(hp1.arrayAsSlice(u8),obj1.arrayAsSlice(u8));
}
    
test "four object allocator" {
    // const stdout = std.io.getStdOut().writer();
    const testing = std.testing;
    const h1 = header(3,Format.object,42,0);
    const h2 = header(1,Format.both,43,0);
    const h3 = header(2,Format.array,44,0);
    const h4 = header(2,Format.raw64,45,0);
    const expected = ([_]Object{
        h1.o(),True,Nil,False,
        h2.o(),True,@bitCast(Object,@as(u64,1)),False,
        h3.o(),Nil,True,
        h4.o(),@bitCast(Object,@as(i64,0)),@bitCast(Object,@as(i64,1)),
    })[0..];
    var testArena = try TestArena.with(expected);
    const obj1 = try testArena.allocObject(42,Format.none,3,0);
    try testing.expectEqual(obj1.totalSize(),4);
    const obj2 = try testArena.allocObject(43,Format.none,1,1);
    try testing.expectEqual(obj2.totalSize(),4);
    const obj3 = try testArena.allocObject(44,Format.none,0,2);
    try testing.expectEqual(obj3.totalSize(),3);
    const obj4 = try testArena.allocRaw(45,2,u64);
    try testing.expectEqual(obj4.totalSize(),3);
    const ivs4 = obj4.instVars();
    try testing.expectEqual(ivs4.len,0);
    const idx4 = obj4.indexables(i64);
    try testing.expectEqual(idx4.len,2);
    idx4[1]=1;
    const ivs3 = obj3.instVars();
    try testing.expectEqual(ivs3.len,0);
    const idx3 = obj3.indexables(Object);
    try testing.expectEqual(idx3.len,2);
    idx3[1]=True;
    const ivs2 = obj2.instVars();
    try testing.expectEqual(ivs2.len,1);
    ivs2[0]=True;
    const idx2 = obj2.indexables(Object);
    try testing.expectEqual(idx2.len,1);
    idx2[0]=False;
    const ivs1 = obj1.instVars();
    try testing.expectEqual(ivs1.len,3);
    ivs1[0]=True;
    ivs1[2]=False;
    // try stdout.print("obj1*=0x{x:0>16}: {}\n",.{@ptrToInt(obj1),obj1});
    // try stdout.print("obj2*=0x{x:0>16}: {}\n",.{@ptrToInt(obj2),obj2});
    // try stdout.print("obj3*=0x{x:0>16}: {}\n",.{@ptrToInt(obj3),obj3});
    // try stdout.print("obj4*=0x{x:0>16}: {}\n",.{@ptrToInt(obj4),obj4});
    try testArena.verify(expected);
}
test "string allocator" {
    //const stdout = std.io.getStdOut().writer();
    const testing = std.testing;
    const h1 = header(1,Format.none.raw(u8,5),class.String_I,0);
    const h2 = header(2,Format.none.raw(u8,5),class.String_I,0);
    const expected = ([_]Object{
        h1.o(),
        object.fromLE(u64,0x0000006f6c6c6568),
        h2.o(),
        object.fromLE(u64,0x646e612073696874),
        object.fromLE(u64,0x0000007461687420),
    })[0..];
    var testArena = try TestArena.with(expected);
    const obj1 = try testArena.allocGlobalString("hello"[0..]);
    try testing.expectEqual(obj1.indexables(u8).len,5);
    //try stdout.print("obj1*=0x{x:0>16}: \"{}\"\n",.{@ptrToInt(obj1),obj1});
    const obj2 = try testArena.allocGlobalString("this and that"[0..]);
    try testing.expectEqual(obj2.indexables(u8).len,13);
    //try stdout.print("obj2*=0x{x:0>16}: \"{}\"\n",.{@ptrToInt(obj2),obj2});
    try testArena.verify(expected);
}
const allocationUnit = heapMethods.maxLength; // size in u64 units including the header
const allocIndex = [_]u8{1, 1, 1, // minimum allocation is 2 - room for header+link in free list
                         2, 3, 3,
                         4, 4, 4,
                         5, 5, 5, 5, 5,
                         6, 6, 6, 6, 6, 6, 6, 6,
                         7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7};
fn findAllocationList(target: u64) ?usize {
    if (target<=34) return allocIndex[target];
    if (target>allocationUnit) return null;
    return @import("utilities.zig").findFib(target);
}
fn findContainedList(target: u64) ?usize {
    _ = target;
    unreachable;
}
const Allocation = packed struct {
    next: ?Allocation,
};
const FreeList = packed struct {
    header: Header,
    next: ?FreeList,
};
var normalAllocations : ?Allocation = null;
var bigAllocations : ?Allocation = null;
fn alloc(h: Header) *Header {
    if (findAllocationList(h.totalSize())) |listNumber| {
        _ = listNumber;
        unreachable;
    } else {
        unreachable;
        // use bigAllocation
    }
}
