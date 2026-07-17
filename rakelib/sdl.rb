# frozen_string_literal: true

require "rbconfig"

module Atoms
  # Discover SDL3 for tests: pkg-config (Unix) or SDL3_DIR / VCPKG_ROOT (Windows).
  module Sdl
    module_function

    Config = Struct.new(:cflags, :libs, :bin_dir, :source, keyword_init: true)

    def available?
      !config.nil?
    end

    def config
      @config ||= detect
    end

    def cflags
      config&.cflags || []
    end

    def libs
      config&.libs || []
    end

    def bin_dir
      config&.bin_dir
    end

    def detect
      from_pkg_config || from_sdl3_dir || from_vcpkg
    end

    def from_pkg_config
      return nil unless system("pkg-config --exists sdl3",
                               out: File::NULL, err: File::NULL)

      cflags = `pkg-config --cflags sdl3`.split
      libs   = `pkg-config --libs sdl3`.split
      Config.new(cflags: cflags, libs: libs, bin_dir: nil, source: "pkg-config")
    rescue StandardError
      nil
    end

    def from_sdl3_dir
      root = ENV["SDL3_DIR"] || ENV["SDL3_ROOT"]
      return nil if root.nil? || root.empty? || !Dir.exist?(root)

      from_prefix(root, "SDL3_DIR")
    end

    def from_vcpkg
      root = ENV["VCPKG_ROOT"]
      return nil if root.nil? || root.empty?

      # Common classic triplets
      %w[x64-windows x64-windows-static x86-windows].each do |trip|
        prefix = File.join(root, "installed", trip)
        cfg = from_prefix(prefix, "vcpkg:#{trip}")
        return cfg if cfg
      end
      nil
    end

    def from_prefix(prefix, source)
      inc = File.join(prefix, "include")
      return nil unless File.directory?(inc)
      return nil unless File.exist?(File.join(inc, "SDL3", "SDL_log.h")) ||
                        File.exist?(File.join(inc, "SDL3", "SDL.h"))

      lib_dir = %w[lib/x64 lib/x86 lib].map { |p| File.join(prefix, p) }
                                       .find { |p| Dir.exist?(p) }
      return nil unless lib_dir

      bin_dir = %w[lib/x64 lib/x86 bin].map { |p| File.join(prefix, p) }
                                       .find { |p|
                                         Dir.exist?(p) &&
                                           Dir.glob(File.join(p, "SDL3*.dll")).any?
                                       }

      Config.new(
        cflags: ["-I#{inc}"],
        libs: ["-L#{lib_dir}", "-lSDL3"],
        bin_dir: bin_dir,
        source: source
      )
    end

    def prepend_bin_to_path!
      dir = bin_dir
      return if dir.nil? || dir.empty?

      sep = File::PATH_SEPARATOR
      ENV["PATH"] = "#{dir}#{sep}#{ENV.fetch('PATH', '')}"
    end
  end
end
