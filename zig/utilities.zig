const std = @import("std");
//    const allocator = @import("std").heap.page_allocator;
//    bits = allocator.alloc(bool, n) catch @panic("Failed Allocating");
//    defer allocator.free(bits);

// define Fibonacci sequence tables
// almost all allocations will be for sizes <= 65535 words long
// so define the sequence up to that size in u16s and unroll the search
const fibonacci_u16 = init: {
    var initial_value: [24]u16 = undefined;
    initFibs(u16,initial_value[0..23]);
    initial_value[23] = 0xffff;
    break :init initial_value;
};
// but just in case it's a bigger allocation, match everything up to the maximum u64 value
const fibonacci_u64 = init: {
    var initial_value: [93]u64 = undefined;
    initFibs(u64,initial_value[0..92]);
    initial_value[92] = 0xffff_ffff_ffff_ffff;
    break :init initial_value;
};
fn initFibs(comptime T: type,array: []T) void {
    array[0] = 1;
    array[1] = 2;
    const start = 2;
    for(array[start..]) |*value,index| {
        value.* = array[index+start-2] + array[index+start-1];
    }
}
fn findFib(size: u64) usize {
    if (size<=fibonacci_u16[fibonacci_u16.len-1]) {
        const s_16 = @intCast(u16,size);
        inline for (fibonacci_u16) |value,index| {
            if (value>=s_16) return index;
        }
        unreachable;
    }
    const start = fibonacci_u16.len-1;
    for (fibonacci_u64[start..]) |value,index| {
        if (value>=size) return index+start;
    }
    unreachable;
}
test "fibonacci sizes" {
//    const stdout = @import("std").io.getStdOut().writer();
//    try stdout.print("\nfibonacci_u16 {} {any}\n", .{fibonacci_u16.len,fibonacci_u16});
//    try stdout.print("fibonacci_u64 {} {any}\n", .{fibonacci_u64.len,fibonacci_u64});
    try std.testing.expectEqual(findFib(5),3);
    try std.testing.expectEqual(findFib(12),5);
    try std.testing.expectEqual(findFib(13),5);
    try std.testing.expectEqual(findFib(14),6);
    try std.testing.expectEqual(findFib(10945),19);
    try std.testing.expectEqual(findFib(10946),19);
    try std.testing.expectEqual(findFib(10947),20);
    try std.testing.expectEqual(findFib(17711),20);
    try std.testing.expectEqual(findFib(17712),21);
    try std.testing.expectEqual(findFib(28657),21);
    try std.testing.expectEqual(findFib(28658),22);
    try std.testing.expectEqual(findFib(46368),22);
    try std.testing.expectEqual(findFib(46369),23);
    try std.testing.expectEqual(findFib(75025),23);
    try std.testing.expectEqual(findFib(75026),24);
}