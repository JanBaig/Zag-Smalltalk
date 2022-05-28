const std = @import("std");
const mem = std.mem;
const builtin = @import("builtin");
inline fn of(comptime v: u64) Object {
    return @bitCast(Object,v);
}
pub const ZERO              = of(0);
const Negative_Infinity     =    0xfff0000000000000;
pub const False             = of(0xfff0_0200_0001_0000);
pub const True              = of(0xfff0030000100001);
pub const Nil               = of(0xfff0040001000002);
const Symbol_Base           =    0xfff0050000000000;
const Character_Base        =    0xfff0060000000000;
pub const ThisContext       = of(0xfff0070010000003);
// unused NaN fff08-fff5f
const Start_of_Heap_Objects =    0xfff6000000000000;
const End_of_Heap_Objects   =    0xfff7ffffffffffff;
const u64_MINVAL            =    0xfff8000000000000;
const u64_ZERO              =    0xfffc000000000000;
const native_endian = builtin.target.cpu.arch.endian();
const heap = @import("heap.zig");
const HeapPtr = heap.HeapPtr;
const HeapConstPtr = heap.HeapConstPtr;
const Thread = @import("thread.zig");
const Dispatch = @import("dispatch.zig");
const class = @import("class.zig");
const ClassIndex = class.ClassIndex;

pub fn fromLE(v: u64) Object {
    const val = @ptrCast(*const [8]u8,&v);
    return @bitCast(Object,mem.readIntLittle(u64,val));
}
pub const compareObject = objectMethods.compare;
const objectMethods = struct {
    pub inline fn equals(self: Object,other: Object) bool {
        return @bitCast(u64, self) == @bitCast(u64,other);
    }
    pub inline fn is_int(self: Object) bool {
        return @bitCast(u64, self) >= u64_MINVAL;
    }
    pub inline fn is_double(self: Object) bool {
        return @bitCast(u64, self) <= Negative_Infinity;
    }
    pub inline fn is_bool(self: Object) bool {
        return @bitCast(u64,self) == @bitCast(u64,False) or @bitCast(u64,self) == @bitCast(u64,True);
    }
    pub inline fn is_nil(self: Object) bool {
        return @bitCast(u64,self) == @bitCast(u64,Nil);
    }
    pub inline fn is_heap(self: Object) bool {
        if (@bitCast(u64, self) < Start_of_Heap_Objects) return false;
        return @bitCast(u64, self) <= End_of_Heap_Objects;
    }
    pub inline fn to(self: Object, comptime T:type) T {
        switch (T) {
            i64 => {if (self.is_int()) return @bitCast(i64, @bitCast(u64, self) - u64_ZERO);},
            f64 => {if (self.is_double()) return @bitCast(f64, self);},
            bool=> {if (self.is_bool()) return self.equals(True);},
            //u8  => {return @intCast(u8, self.hash & 0xff);},
            HeapPtr,HeapConstPtr => {if (self.is_heap()) return @intToPtr(T, @bitCast(usize, @bitCast(i64, self) << 16 >> 16));},
            else => {
                switch (@typeInfo(T)) {
                    .Pointer => |ptrInfo| {
                        @import("std").io.getStdOut().writer().print("to type 0x{x:0>16} 0x{x}\n",.{@bitCast(u64,self.to(HeapConstPtr).*),ptrInfo.child.ClassIndex}) catch unreachable;
                        if (self.is_heap() and (ptrInfo.child.ClassIndex==0 or self.to(HeapConstPtr).classIndex==ptrInfo.child.ClassIndex))
                            return @intToPtr(T, @bitCast(usize, @bitCast(i64, self) << 15 >> 15)+@sizeOf(Object));
                    },
                    else => {},
                }
            },
        }
        unreachable;
    }
    pub inline fn as_string(self: Object) []const u8 {
        //
        // symbol handling broken
        //
        _ = self;
        return "dummy string";
    }
    pub inline fn arrayAsSlice(self: Object, comptime T:type) []T {
        if (self.is_heap()) return self.to(HeapPtr).arrayAsSlice(T);
        return &[0]T{};
    }
    pub inline fn from(value: anytype) Object {
        const T = @TypeOf(value);
        if (T==HeapConstPtr) return @bitCast(Object, @ptrToInt(value) + Start_of_Heap_Objects);
        switch (@typeInfo(@TypeOf(value))) {
            .Int,
            .ComptimeInt => {
                return @bitCast(Object, @bitCast(u64, @as(i64, value)) +% u64_ZERO);
            },
            .Float,
            .ComptimeFloat => {
                return @bitCast(Object, @as(f64, value));
            },
            .Bool => {
                return if (value) True else False;
            },
            .Null => {
                return Nil;
            },
            .Pointer => |ptr_info| {
                switch (ptr_info.size) {
                    .One => {
                        return @bitCast(Object, @ptrToInt(value) + Start_of_Heap_Objects);
                    },
                    else => {},
                }
            },
            else => {},
        }
        @compileError("Can't convert");
    }
    pub inline fn fullHash(self: Object) u64 {
        return @bitCast(u64, self) % 16777213; // largest 24 bit prime
    }
    pub fn compare(self: Object, other: Object) std.math.Order {
        if (!self.is_heap() or !other.is_heap()) {
            const u64s = @bitCast(u64,self);
            const u64o = @bitCast(u64,other);
            return std.math.order(u64s,u64o);
        }
        const ord = std.math.Order;
        if (@bitCast(u64,self)==@bitCast(u64,other)) return ord.eq;
        if (self.immediate_class() != other.immediate_class()) unreachable;
        const sla = self.arrayAsSlice(u8);
        const slb = other.arrayAsSlice(u8);
        for (sla[0..@minimum(sla.len,slb.len)]) |va,index| {
            const vb=slb[index];
            if (va<vb) return ord.lt;
            if (va>vb) return ord.gt;
        }
        if (sla.len<slb.len) return ord.lt;
        if (sla.len>slb.len) return ord.gt;
        return ord.eq;
    }
    pub inline fn immediate_class(self: Object) ClassIndex {
        if (self.is_int()) return class.SmallInteger_I;
        if (self.is_double()) return class.Float_I;
        if (@bitCast(u64, self) >= Start_of_Heap_Objects) return class.Object_I;
        return @truncate(ClassIndex,@bitCast(u64, self) >> 40) & 255;
    }
    pub inline fn get_class(self: Object) ClassIndex {
        const immediate = self.immediate_class();
        if (immediate > 1) return immediate;
        return self.to(HeapPtr).*.get_class();
    }
    pub inline fn promoteTo(self: Object, arena: *heap.Arena) !Object {
        return arena.promote(self);
    }
    pub inline fn dispatch(self: Object, thread: *Thread.Thread, selector: Object) Dispatch.MethodReturns {
        return Dispatch.call(thread,self,selector);
    }
    pub fn format(
        self: Object,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        
        try switch (self.immediate_class()) {
            class.Object_I => writer.print("object:0x{x:>16}", .{@bitCast(u64,self)}), //,as_pointer(x));
            class.False_I => writer.print("false", .{}),
            class.True_I => writer.print("true", .{}),
            class.UndefinedObject_I => writer.print("nil", .{}),
            class.Symbol_I => writer.print("#{s}", .{self.as_string()}),
            class.Character_I => writer.print("${c}", .{self.to(u8)}),
            class.SmallInteger_I => writer.print("{d}", .{self.to(i64)}),
            class.Float_I => writer.print("{}", .{self.to(f64)}),
            else => unreachable,
        };
    }
    pub const alignment = @alignOf(u64);
};
pub const Tag = enum(u8) { Object = 1, False, True, UndefinedObject, Symbol, Character, Context };
pub const Object = switch (native_endian) {
    .Big => packed struct {
        signMantissa: u16, // align(8),
        tag: Tag,
        nArgs : u8,
        hash: i32,
        usingnamespace objectMethods;
    },
    .Little => packed struct {
        hash: i32, // align(8),
        nArgs : u8,
        tag: Tag,
        signMantissa: u16,
        usingnamespace objectMethods;
    },
};

test "slicing" {
    const testing = std.testing;
    try testing.expectEqual(Nil.arrayAsSlice(u8).len,0);
}
test "from conversion" {
    const testing = std.testing;
    try testing.expectEqual(@bitCast(f64, Object.from(3.14)), 3.14);
    try testing.expectEqual(@bitCast(u64, Object.from(42)), u64_ZERO +% 42);
    try testing.expectEqual(Object.from(3.14).immediate_class(),class.Float_I);
    try testing.expect(Object.from(3.14).is_double());
    try testing.expectEqual(Object.from(3).immediate_class(),class.SmallInteger_I);
    try testing.expect(Object.from(3).is_int());
    try testing.expect(Object.from(false).is_bool());
    try testing.expectEqual(Object.from(false).immediate_class(),class.False_I);
    try testing.expectEqual(Object.from(true).immediate_class(),class.True_I);
    try testing.expect(Object.from(true).is_bool());
    try testing.expectEqual(Object.from(null).immediate_class(),class.UndefinedObject_I);
    try testing.expect(Object.from(null).is_nil());
}
test "to conversion" {
    const testing = std.testing;
    try testing.expectEqual(Object.from(3.14).to(f64), 3.14);
    try testing.expectEqual(Object.from(42).to(i64), 42);
    try testing.expect(Object.from(42).is_int());
    try testing.expectEqual(Object.from(true).to(bool), true);
}
test "printing" {
    var buf: [255]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const stream = fbs.writer();
    const symbol = @import("symbol.zig");
    try stream.print("{}\n",.{Object.from(42)});
    try stream.print("{}\n",.{symbol.symbols.yourself});
    try std.testing.expectEqualSlices(u8, "42\n#dummy string\n", fbs.getWritten());
}
