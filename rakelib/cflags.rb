# frozen_string_literal: true

require "shellwords"
require "rbconfig"
require "tempfile"

module Atoms
  module CFlags
    module_function

    # Shared first-party flags. Pedantic + Werror for tests/examples.
    # third_party is -isystem so pico_unit stays quiet.
    # -std is filled in by #default (c23, or c2x on older GCC).
    BASE = %w[
      -Wall
      -Wextra
      -Wpedantic
      -Werror
      -Wshadow
      -Wvla
      -Wdouble-promotion
      -Wundef
      -Wmissing-prototypes
      -Wstrict-prototypes
      -Wwrite-strings
      -Wconversion
      -Wno-sign-conversion
      -g
      -O0
      -Idist
      -isystem
      third_party
    ].freeze

    # Clang-only extras (unknown to GCC as -Werror).
    CLANG_ONLY = %w[-Wcomma].freeze

    def cc_name
      ENV.fetch("CC", "clang")
    end

    def clangish?
      base = File.basename(cc_name).sub(/-\d+(\.\d+)*\z/, "")
      base.match?(/\Aclang(\+\+)?\z/i) || base.match?(/\Aclang-cl\z/i)
    end

    def windows?
      RbConfig::CONFIG["host_os"].match?(/mswin|mingw|cygwin/i)
    end

    # Prefer -std=c23; fall back to -std=c2x for GCC 11–13 (and similar).
    def c_std_flag
      @c_std_flag ||= begin
        if flag_accepted?("-std=c23")
          "-std=c23"
        elsif flag_accepted?("-std=c2x")
          warn "#{cc_name}: using -std=c2x (this compiler has no -std=c23)"
          "-std=c2x"
        else
          raise "#{cc_name}: supports neither -std=c23 nor -std=c2x"
        end
      end
    end

    def flag_accepted?(flag)
      Tempfile.create(["atoms_cflag", ".c"]) do |f|
        f.write("int main(void) { return 0; }\n")
        f.flush
        out = File.join(Dir.tmpdir, "atoms_cflag_probe#{Process.pid}.o")
        begin
          system(
            cc_name, flag, "-c", f.path, "-o", out,
            out: File::NULL, err: File::NULL
          )
        ensure
          File.delete(out) if File.exist?(out)
        end
      end
    end

    def default
      flags = [c_std_flag, *BASE]
      flags.concat(CLANG_ONLY) if clangish?
      # MSVC headers are noisy under -Wconversion when using clang targeting
      # the MSVC ABI; keep pedantic/error but drop conversion on Windows.
      if windows?
        flags.delete("-Wconversion")
        flags.delete("-Wno-sign-conversion")
      end
      flags
    end

    def from_env
      if ENV.key?("CFLAGS")
        Shellwords.split(ENV.fetch("CFLAGS"))
      else
        default
      end
    end

    def asan
      base = from_env.reject { |f| f == "-O0" }
      base + %w[-O1 -fsanitize=address,undefined -fno-omit-frame-pointer]
    end
  end
end
