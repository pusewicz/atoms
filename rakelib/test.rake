# frozen_string_literal: true

require_relative "atoms"
require_relative "cflags"
require "rake/clean"
require "shellwords"
require "rbconfig"

CC = ENV.fetch("CC", "clang")
CFLAGS = Atoms::CFlags.from_env
LDFLAGS = Shellwords.split(ENV.fetch("LDFLAGS", ""))

CLEAN.include "build"
CLOBBER.include "build"

def exe_suffix
  Atoms::CFlags.windows? ? ".exe" : ""
end

def sdl_available?
  system("pkg-config --exists sdl3", out: File::NULL, err: File::NULL)
end

def sdl_cflags
  `pkg-config --cflags sdl3`.split
rescue StandardError
  []
end

def sdl_libs
  `pkg-config --libs sdl3`.split
rescue StandardError
  []
end

def compile_and_link(src, bin, extra_cflags: [], extra_ldflags: [], cflags: CFLAGS)
  Atoms::BUILD.mkpath
  # Include test dir for host_compat.h (and future shared test headers).
  test_inc = ["-I#{src.dirname}"]
  obj = Atoms::BUILD.join("#{bin.basename(exe_suffix)}.o")
  sh CC, *cflags, *test_inc, *extra_cflags, "-c", src.to_s, "-o", obj.to_s
  sh CC, *cflags, obj.to_s, "-o", bin.to_s, *LDFLAGS, *extra_ldflags
end

def run_bin(bin)
  # Prefer direct exec so Windows .exe paths work without a Unix shell.
  sh bin.to_s
end

namespace :test do
  Atoms.libs.each do |name|
    core_tests = Atoms.lib_dir(name).glob("tests/test_#{name}.c")
    sdl_tests = Atoms.lib_dir(name).glob("tests/test_#{name}_sdl.c")

    desc "Run core tests for #{name}"
    task name => "dist:#{name}" do
      core_tests.each do |src|
        bin = Atoms::BUILD.join("#{src.basename('.c')}#{exe_suffix}")
        compile_and_link(src, bin)
        run_bin(bin)
      end
    end

    next if sdl_tests.empty?

    desc "Run SDL tests for #{name} (requires SDL3)"
    task "#{name}:sdl" => "dist:#{name}" do
      abort "SDL3 not found (pkg-config sdl3)" unless sdl_available?

      sdl_tests.each do |src|
        bin = Atoms::BUILD.join("#{src.basename('.c')}#{exe_suffix}")
        compile_and_link(
          src,
          bin,
          extra_cflags: ["-DATOM_LOG_SDL", *sdl_cflags],
          extra_ldflags: sdl_libs
        )
        run_bin(bin)
      end
    end
  end
end

desc "Build dist and run all available test suites"
task :test do
  puts "CC=#{CC}  clangish=#{Atoms::CFlags.clangish?}  host=#{RbConfig::CONFIG['host_os']}"
  Atoms.libs.each do |name|
    Rake::Task["test:#{name}"].invoke
    sdl_task = "test:#{name}:sdl"
    if Rake::Task.task_defined?(sdl_task) && sdl_available?
      Rake::Task[sdl_task].invoke
    elsif Rake::Task.task_defined?(sdl_task)
      warn "skip #{sdl_task} (SDL3 not available)"
    end
  end
end

desc "Run tests under ASan+UBSan"
task :asan do
  asan_cflags = Atoms::CFlags.asan
  asan_ldflags = Shellwords.split(ENV.fetch("LDFLAGS", "")) +
                 %w[-fsanitize=address,undefined]
  Atoms.libs.each do |name|
    Rake::Task["dist:#{name}"].invoke
    Atoms.lib_dir(name).glob("tests/test_#{name}.c").each do |src|
      bin = Atoms::BUILD.join("asan_#{src.basename('.c')}#{exe_suffix}")
      compile_and_link(src, bin, cflags: asan_cflags, extra_ldflags: asan_ldflags)
      run_bin(bin)
    end
  end
end

namespace :example do
  Atoms.libs.each do |name|
    desc "Build and run examples for #{name}"
    task name => "dist:#{name}" do
      Atoms.lib_dir(name).glob("examples/*.c").each do |src|
        bin = Atoms::BUILD.join("example_#{name}_#{src.basename('.c')}#{exe_suffix}")
        compile_and_link(src, bin)
        run_bin(bin)
      end
    end
  end
end
