# frozen_string_literal: true

require_relative "atoms"
require_relative "cflags"
require "json"

desc "Generate compile_commands.json from real clang invocations"
task :compile_commands do
  unless Atoms::CFlags.clangish?
    abort "compile_commands needs clang (CC=#{Atoms::CFlags.cc_name} has no -MJ)"
  end

  Atoms::BUILD.glob("*.o.json").each(&:delete)
  Rake::Task[:test].invoke
  Atoms.libs.each { |name| Rake::Task["example:#{name}"].invoke }

  # Each -MJ file is one entry with a trailing comma, ready for array splicing.
  entries = Atoms::BUILD.glob("*.o.json").sort.map do |path|
    JSON.parse(path.read.strip.delete_suffix(","))
  end
  abort "no compile entries captured" if entries.empty?

  out = Atoms::ROOT.join("compile_commands.json")
  out.write(JSON.pretty_generate(entries) << "\n")
  puts "#{out.basename}: #{entries.size} entries"
end
