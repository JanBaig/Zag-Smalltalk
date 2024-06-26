const std = @import("std");
const execute = @import("execute.zig");
const primitives = @import("primitives.zig");
const ThreadedFn = execute.ThreadedFn;
const Reference = struct {
    str: []const u8,
    addr: ThreadedFn,
};
pub fn compileReferences(comptime tup: anytype) [tup.len/2]Reference {
    @setEvalBranchQuota(3000);
    comptime var result: [tup.len/2]Reference = undefined;
    inline for (tup, 0..) |field, idx| {
        if (idx&1==0) {
            result[idx/2].str = comptime field[0..];
        } else
            result[idx/2].addr = field;
    }
    const final = result;
    return final;
}
const references = compileReferences(.{
    // grep -r ': *PC,.*: *SP,.*:.*Process,.*:.*Context,.*: *MethodSignature)' .|grep -v 'not embedded'|sed -n 's;./\(.*\)[.]zig:[ 	]*pub fn \([^(]*\)(.*;"\2",\&\1.\2,;p'|sed 's;\(&[^/.]*\).;\1.embedded.;'|sed 's;@"\([^"]*\)";\1;'|sed '/^"p[0-9]/s/embedded[.][^.]*/primitives/'|sort
"branch",&execute.embedded.branch,
"call",&execute.embedded.call,
"callRecursive",&execute.embedded.callRecursive,
"closureData",&primitives.embedded.BlockClosure.closureData,
"drop",&execute.embedded.drop,
"dropNext",&execute.embedded.dropNext,
"dup",&execute.embedded.dup,
"dynamicDispatch",&execute.embedded.dynamicDispatch,
"fallback",&execute.embedded.fallback,
"fullClosure",&primitives.embedded.BlockClosure.fullClosure,
"generalClosure",&primitives.embedded.BlockClosure.generalClosure,
"ifFalse",&execute.embedded.ifFalse,
"ifNil",&execute.embedded.ifNil,
"ifNotNil",&execute.embedded.ifNotNil,
"ifTrue",&execute.embedded.ifTrue,
"immutableClosure",&primitives.embedded.BlockClosure.immutableClosure,
"over",&execute.embedded.over,
"p201",&primitives.primitives.p201,
"p202",&primitives.primitives.p202,
"p203",&primitives.primitives.p203,
"p204",&primitives.primitives.p204,
"p205",&primitives.primitives.p205,
//"perform",&execute.embedded.perform,
//"performWith",&execute.embedded.performWith,
"popLocal",&execute.embedded.popLocal,
"popLocal0",&execute.embedded.popLocal0,
"popLocalData",&execute.embedded.popLocalData,
"popLocalField",&execute.embedded.popLocalField,
"printStack",&execute.embedded.printStack,
"pushContext",&execute.embedded.pushContext,
"pushLiteral",&execute.embedded.pushLiteral,
"pushLiteral0",&execute.embedded.pushLiteral0,
"pushLiteral1",&execute.embedded.pushLiteral1,
"pushLiteral2",&execute.embedded.pushLiteral2,
"pushLiteralFalse",&execute.embedded.pushLiteralFalse,
"pushLiteralIndirect",&execute.embedded.pushLiteralIndirect,
"pushLiteralNil",&execute.embedded.pushLiteralNil,
"pushLiteralTrue",&execute.embedded.pushLiteralTrue,
"pushLiteral_1",&execute.embedded.pushLiteral_1,
"pushLocal",&execute.embedded.pushLocal,
"pushLocal0",&execute.embedded.pushLocal0,
"pushLocalData",&execute.embedded.pushLocalData,
"pushLocalField",&execute.embedded.pushLocalField,
"pushNonlocalBlock_false",&primitives.embedded.BlockClosure.pushNonlocalBlock_false,
"pushNonlocalBlock_minusOne",&primitives.embedded.BlockClosure.pushNonlocalBlock_minusOne,
"pushNonlocalBlock_nil",&primitives.embedded.BlockClosure.pushNonlocalBlock_nil,
"pushNonlocalBlock_one",&primitives.embedded.BlockClosure.pushNonlocalBlock_one,
"pushNonlocalBlock_self",&primitives.embedded.BlockClosure.pushNonlocalBlock_self,
"pushNonlocalBlock_true",&primitives.embedded.BlockClosure.pushNonlocalBlock_true,
"pushNonlocalBlock_two",&primitives.embedded.BlockClosure.pushNonlocalBlock_two,
"pushNonlocalBlock_zero",&primitives.embedded.BlockClosure.pushNonlocalBlock_zero,
"pushThisContext",&execute.embedded.pushThisContext,
"replaceLiteral",&execute.embedded.replaceLiteral,
"replaceLiteral0",&execute.embedded.replaceLiteral0,
"replaceLiteral1",&execute.embedded.replaceLiteral1,
"returnNoContext",&execute.embedded.returnNoContext,
"returnNonLocal",&execute.embedded.returnNonLocal,
"returnTop",&execute.embedded.returnTop,
"returnWithContext",&execute.embedded.returnWithContext,
"setupSend",&execute.embedded.setupSend,
"setupTailSend",&execute.embedded.setupTailSend,
"setupTailSend0",&execute.embedded.setupTailSend0,
"storeLocal",&execute.embedded.storeLocal,
"swap",&execute.embedded.swap,
"value:",&primitives.embedded.BlockClosure.@"value:",
"verifyMethod",&execute.embedded.verifyMethod,
});
var zfHashValue: u64 = 0;
const print = std.debug.print;
fn capitalize(c: u8) u8 {
    return c-'a'+'A';
}
fn hash(addr: ThreadedFn) void {
    zfHashValue = std.math.rotr(u64,zfHashValue,1) +% @intFromPtr(addr);
}
fn calculateAndWriteHeader(writeFile: bool) void {
    if (writeFile) {
        print(
            \\{s}I have shared variables generated by zag so that images can be generated that directly reference zig code.
             \\From zag on {s} at {s}{s}
                ,.{"\"","13 March 2024","7:53:53.977136 am","\n"});
        print(
            \\Class {s}
            \\	#name : 'ASZagConstants',
            \\	#superclass : 'SharedPool',
            \\	#classVars : [
            \\		'Addresses',
            \\		'PredefinedSymbols',
            \\		'ZfHashValue',{c}
                ,.{"{",'\n'});
        for (references[0..]) |ref|
            print("\t\t'Zf{c}{s}',\n",.{capitalize(ref.str[0]),ref.str[1..]});
        print(
            \\	],
            \\	#category : 'ASTSmalltalk-Output',
            \\	#package : 'ASTSmalltalk',
            \\	#tag : 'Output'
            \\{s}
            \\
            \\{s} #category : 'mapping' {s}
            \\ASZagConstants class >> constantMap [
            \\
            \\	^ Dictionary new{s}
                ,.{"}","{","}","\n"});
        for (references[0..]) |ref|
            print("\t\t  at: #{s} put: Zf{c}{s};\n",.{ref.str,capitalize(ref.str[0]),ref.str[1..]});
        print(
            \\		  yourself
            \\]
            \\
            \\{s} #category : 'class initialization' {s}
            \\ASZagConstants class >> initialize [
            \\
            \\	PredefinedSymbols := #(  ).
            \\	self initializeForImage.
            \\	Addresses := self constantMap
            \\]
            \\
            \\{s} #category : 'class initialization' {s}
            \\ASZagConstants class >> initializeForImage [{s}
                ,.{"{","}","{","}","\n"});
        //	ZfIfFalse := 1.
    }
    for (references[0..]) |ref|
        hash(ref.addr);
    if (writeFile) {
        for (references[0..]) |ref|
            print("\tZf{c}{s} := {}.\n",.{capitalize(ref.str[0]),ref.str[1..],@intFromPtr(ref.addr)});
        print("\tZfHashValue := {}\n]\n",.{zfHashValue});
    }
}

pub fn main() void {
    calculateAndWriteHeader(true);
}
