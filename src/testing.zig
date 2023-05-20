const std = @import("std");
const Allocator = std.mem.Allocator;
const List = std.ArrayList;

const interner = @import("interner.zig");
const Intern = interner.Intern;
const Builtins = @import("builtins.zig").Builtins;
const tokenizer = @import("tokenizer.zig");
const parser = @import("parser.zig");
const type_checker = @import("type_checker.zig");
const lower = @import("lower.zig");
const wat = @import("codegen.zig").wat;

pub fn tokenize(allocator: Allocator, source: []const u8) ![]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var intern = Intern.init(arena.allocator());
    const builtins = try Builtins.init(&intern);
    const tokens = try tokenizer.tokenize(arena.allocator(), &intern, builtins, source);
    const reconstructed = try tokenizer.toSource(arena.allocator(), intern, tokens);
    try std.testing.expectEqualStrings(source, reconstructed);
    return try tokenizer.toString(allocator, intern, tokens);
}

pub fn parse(allocator: Allocator, source: []const u8) ![]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var intern = Intern.init(arena.allocator());
    const builtins = try Builtins.init(&intern);
    const tokens = try tokenizer.tokenize(arena.allocator(), &intern, builtins, source);
    const module = try parser.parse(arena.allocator(), tokens);
    return try parser.toString(allocator, intern, module);
}

pub fn typeInfer(allocator: Allocator, source: []const u8, name: []const u8) ![]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var intern = Intern.init(arena.allocator());
    const builtins = try Builtins.init(&intern);
    const tokens = try tokenizer.tokenize(arena.allocator(), &intern, builtins, source);
    const untyped_module = try parser.parse(arena.allocator(), tokens);
    var next_type_var: type_checker.types.TypeVar = 0;
    var module = try type_checker.infer.module(arena.allocator(), builtins, untyped_module, &next_type_var);
    const interned = try interner.store(&intern, name);
    var constraints = type_checker.types.Constraints{
        .equal = List(type_checker.types.Equal).init(arena.allocator()),
    };
    try type_checker.infer.infer(arena.allocator(), &constraints, &module, builtins, &next_type_var, interned);
    const substitution = try type_checker.solve(arena.allocator(), constraints);
    const typed_module = try type_checker.apply(arena.allocator(), substitution, module);
    var list = List(u8).init(allocator);
    const writer = list.writer();
    try type_checker.toString(writer, intern, typed_module);
    return list.toOwnedSlice();
}

pub fn typeInferVerbose(allocator: Allocator, source: []const u8, name: []const u8) ![]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var intern = Intern.init(arena.allocator());
    const builtins = try Builtins.init(&intern);
    const tokens = try tokenizer.tokenize(arena.allocator(), &intern, builtins, source);
    const untyped_module = try parser.parse(arena.allocator(), tokens);
    const interned = try interner.store(&intern, name);
    var next_type_var: type_checker.types.TypeVar = 0;
    var module = try type_checker.infer.module(arena.allocator(), builtins, untyped_module, &next_type_var);
    var constraints = type_checker.types.Constraints{
        .equal = List(type_checker.types.Equal).init(arena.allocator()),
    };
    try type_checker.infer.infer(arena.allocator(), &constraints, &module, builtins, &next_type_var, interned);
    const substitution = try type_checker.solve(arena.allocator(), constraints);
    const typed_module = try type_checker.apply(arena.allocator(), substitution, module);
    var list = List(u8).init(allocator);
    const writer = list.writer();
    try type_checker.to_verbose_string.module(writer, intern, module);
    try type_checker.to_verbose_string.constraints(writer, constraints);
    try type_checker.to_verbose_string.substitution(writer, substitution);
    try type_checker.to_verbose_string.module(writer, intern, typed_module);
    return list.toOwnedSlice();
}

pub fn codegen(allocator: Allocator, source: []const u8) ![]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var intern = Intern.init(arena.allocator());
    const builtins = try Builtins.init(&intern);
    const tokens = try tokenizer.tokenize(arena.allocator(), &intern, builtins, source);
    const untyped_module = try parser.parse(arena.allocator(), tokens);
    var next_type_var: type_checker.types.TypeVar = 0;
    var module = try type_checker.infer.module(arena.allocator(), builtins, untyped_module, &next_type_var);
    const interned = try interner.store(&intern, "start");
    var constraints = type_checker.types.Constraints{
        .equal = List(type_checker.types.Equal).init(arena.allocator()),
    };
    try type_checker.infer.infer(arena.allocator(), &constraints, &module, builtins, &next_type_var, interned);
    const substitution = try type_checker.solve(arena.allocator(), constraints);
    const typed_module = try type_checker.apply(arena.allocator(), substitution, module);
    const ir = try lower.buildIr(arena.allocator(), intern, typed_module);
    return try wat(allocator, intern, ir);
}
