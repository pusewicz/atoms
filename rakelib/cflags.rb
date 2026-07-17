# frozen_string_literal: true

require "shellwords"
require "rbconfig"

module Atoms
  module CFlags
    module_function

    # Shared first-party flags. Pedantic + Werror for tests/examples.
    # third_party is -isystem so pico_unit stays quiet.
    BASE = %w[
      -std=c23
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

    def default
      flags = BASE.dup
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
