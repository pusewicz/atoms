# frozen_string_literal: true

require_relative "atoms"
require_relative "sdl"

desc "clang-format all first-party C sources (src/**/*.{c,h})"
task :format do
  files = FileList["#{Atoms::SRC}/**/*.{c,h}"].exclude("**/banner.h.in")
  abort "clang-format not found" unless system("command -v clang-format",
                                               out: File::NULL, err: File::NULL)
  sh "clang-format", "-i", *files
end

namespace :format do
  desc "Verify formatting without writing"
  task :check do
    files = FileList["#{Atoms::SRC}/**/*.{c,h}"].exclude("**/banner.h.in")
    abort "clang-format not found" unless system("command -v clang-format",
                                                 out: File::NULL,
                                                 err: File::NULL)
    sh "clang-format", "--dry-run", "--Werror", *files
  end
end

desc "clang-tidy first-party test TUs (after amalgamate)"
task tidy: :amalgamate do
  abort "clang-tidy not found" unless system("command -v clang-tidy",
                                             out: File::NULL, err: File::NULL)
  Atoms.libs.each do |name|
    extra = []
    if Atoms.requires_sdl?(name)
      unless Atoms::Sdl.available?
        abort "SDL3 not found (pkg-config sdl3, or set SDL3_DIR / VCPKG_ROOT)"
      end
      extra = Atoms::Sdl.config.cflags
    end
    Atoms.lib_dir(name).glob("tests/test_#{name}.c").each do |src|
      sh "clang-tidy", src.to_s, "--", *Atoms::CFlags.default, *extra
    end
  end
end
