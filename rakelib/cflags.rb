# frozen_string_literal: true

require "shellwords"

module Atoms
  module CFlags
    module_function

    # Curated first-party warning set. Pedantic + Werror always on for tests /
    # examples so CI and local builds match. third_party is -isystem so
    # pico_unit stays quiet.
    DEFAULT = %w[
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
      -Wcomma
      -Wconversion
      -Wno-sign-conversion
      -g
      -O0
      -Idist
      -isystem
      third_party
    ].freeze

    def default
      DEFAULT
    end

    def from_env
      if ENV.key?("CFLAGS")
        Shellwords.split(ENV.fetch("CFLAGS"))
      else
        default.dup
      end
    end

    def asan
      base = from_env.reject { |f| f == "-O0" }
      base + %w[-O1 -fsanitize=address,undefined -fno-omit-frame-pointer]
    end
  end
end
