# frozen_string_literal: true

require "rbconfig"

module Atoms
  # Discover SDL3 for tests:
  #   1) pkg-config sdl3
  #   2) SDL3_DIR / SDL3_ROOT (setup-sdl sets SDL3_DIR to its install prefix)
  #   3) VCPKG_ROOT/installed/<triplet>
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

      %w[x64-windows x64-windows-static x86-windows].each do |trip|
        prefix = File.join(root, "installed", trip)
        cfg = from_prefix(prefix, "vcpkg:#{trip}")
        return cfg if cfg
      end
      nil
    end

    def from_prefix(prefix, source)
      # setup-sdl / CMake install: include/SDL3/*.h, lib{,64}/libSDL3.*
      # Official VC zip: include/SDL3, lib/x64/SDL3.lib + SDL3.dll
      inc = File.join(prefix, "include")
      return nil unless File.directory?(inc)
      return nil unless File.exist?(File.join(inc, "SDL3", "SDL_log.h")) ||
                        File.exist?(File.join(inc, "SDL3", "SDL.h"))

      lib_dir = %w[lib/x64 lib/x86 lib64 lib].map { |p| File.join(prefix, p) }
                                             .find { |p| Dir.exist?(p) && lib_dir_has_sdl3?(p) }
      return nil unless lib_dir

      bin_dir = %w[lib/x64 lib/x86 bin lib64 lib].map { |p| File.join(prefix, p) }
                                                 .find { |p| Dir.exist?(p) && runtime_dir?(p) }

      Config.new(
        cflags: ["-I#{inc}"],
        libs: ["-L#{lib_dir}", "-lSDL3"],
        bin_dir: bin_dir || lib_dir,
        source: source
      )
    end

    def lib_dir_has_sdl3?(dir)
      Dir.glob(File.join(dir, "*SDL3*")).any? ||
        Dir.glob(File.join(dir, "*sdl3*")).any?
    end

    def runtime_dir?(dir)
      Dir.glob(File.join(dir, "SDL3*.dll")).any? ||
        Dir.glob(File.join(dir, "libSDL3*.so*")).any? ||
        Dir.glob(File.join(dir, "libSDL3*.dylib")).any?
    end

    def prepend_bin_to_path!
      dir = bin_dir
      return if dir.nil? || dir.empty?

      sep = File::PATH_SEPARATOR
      ENV["PATH"] = "#{dir}#{sep}#{ENV.fetch('PATH', '')}"

      # Unix: ensure the dynamic linker can find libSDL3 when not using rpath.
      case RbConfig::CONFIG["host_os"]
      when /darwin/i
        ENV["DYLD_LIBRARY_PATH"] =
          "#{dir}#{sep}#{ENV.fetch('DYLD_LIBRARY_PATH', '')}"
      when /linux/i
        ENV["LD_LIBRARY_PATH"] =
          "#{dir}#{sep}#{ENV.fetch('LD_LIBRARY_PATH', '')}"
      end
    end
  end
end
