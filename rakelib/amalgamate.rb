# frozen_string_literal: true

require_relative "atoms"

module Atoms
  module Amalgamate
    module_function

    # Fixed impl order per library.
    IMPL_ORDER = {
      "atom_log" => %w[path.c colour.c format.c core.c sdl.c]
    }.freeze

    def build(name)
      dir = Atoms.lib_dir(name)
      raise "unknown library: #{name}" unless dir.directory?

      version = Atoms.version(name)
      sha = Atoms.git_sha
      banner = dir.join("banner.h.in").read
                  .gsub("{{VERSION}}", version)
                  .gsub("{{GIT_SHA}}", sha)

      public_h = dir.join("public.h").read

      impl_files = IMPL_ORDER.fetch(name) do
        dir.glob("*.c").map { |p| p.basename.to_s }.sort
      end

      impl = +""
      impl_files.each do |fname|
        path = dir.join(fname)
        raise "missing impl fragment: #{path}" unless path.file?

        impl << "\n/* ---- #{fname} ---- */\n"
        impl << path.read
        impl << "\n"
      end

      slug = name.upcase.gsub(/[^A-Z0-9]/, "_")
      guard = "#{slug}_H"
      impl_macro = "#{slug}_IMPLEMENTATION"

      out = +""
      out << banner
      out << "\n"
      out << "#ifndef #{guard}\n#define #{guard}\n\n"
      out << public_h
      out << "\n"
      out << "#ifdef #{impl_macro}\n\n"
      out << "#include <stdarg.h>\n"
      out << "#include <stdbool.h>\n"
      out << "#include <stdio.h>\n"
      out << "#include <stdlib.h>\n"
      out << "#include <string.h>\n\n"
      out << impl
      out << "\n#endif /* #{impl_macro} */\n"
      out << "\n#endif /* #{guard} */\n"

      Atoms::DIST.mkpath
      target = Atoms::DIST.join("#{name}.h")
      target.write(out)
      target
    end
  end
end
