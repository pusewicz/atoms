# frozen_string_literal: true

require_relative "atoms"

module Atoms
  module DocParse
    Symbol = Struct.new(:kind, :name, :signature, :brief, :params, :returns,
                        :line, keyword_init: true)

    module_function

    def parse_public(name)
      path = Atoms.lib_dir(name).join("public.h")
      lines = path.readlines
      symbols = []
      i = 0
      while i < lines.size
        if lines[i] =~ %r{\A\s*/\*\*}
          comment, i = read_comment(lines, i)
          next if i >= lines.size

          decl_line = i
          decl, i = read_declaration(lines, i)
          next if decl.strip.empty?

          brief = comment[/@brief\s+(.+?)(?:\s*\*+\/)?\s*$/, 1]&.strip
          brief = brief&.sub(%r{\s*\*/\s*\z}, "")&.strip
          if brief.nil? || brief.empty?
            brief = comment.lines.map(&:strip)
                           .reject { |l| l.include?("@") || l == "/**" || l == "*/" }
                           .map { |l| l.sub(%r{\A\*+\s*}, "").sub(%r{\s*\*/\s*\z}, "") }
                           .reject(&:empty?)
                           .join(" ")
                           .strip
          end

          params = comment.scan(/@param\s+(\S+)\s+(.+)/).map { |n, d| [n, d.strip] }
          returns = comment[/@return\s+(.+)/, 1]&.strip

          kind, sym_name = classify(decl)
          next unless kind && sym_name

          symbols << Symbol.new(
            kind: kind,
            name: sym_name,
            signature: normalize_sig(decl),
            brief: brief,
            params: params,
            returns: returns,
            line: decl_line + 1
          )
        else
          i += 1
        end
      end
      symbols
    end

    def read_comment(lines, i)
      buf = +""
      while i < lines.size
        buf << lines[i]
        break if lines[i].include?("*/")

        i += 1
      end
      [buf, i + 1]
    end

    def read_declaration(lines, i)
      while i < lines.size && lines[i].strip.empty?
        i += 1
      end
      return ["", i] if i >= lines.size

      # Object-like / function-like macros (may continue with \).
      if lines[i] =~ /\A\s*#\s*define\s+\w/
        buf = lines[i].rstrip
        while buf.end_with?("\\") && i + 1 < lines.size
          i += 1
          buf = "#{buf.chomp('\\')} #{lines[i].strip}"
        end
        return [buf, i + 1]
      end

      # Skip other preprocessor directives (includes, guards, ifdef, …).
      return ["", i + 1] if lines[i] =~ /\A\s*#/

      buf = +lines[i]
      # typedef enum … { … } Name;  — read until closing `};` or `;` after `}`
      if buf =~ /enum\b/
        while i < lines.size && !buf.match?(/}\s*\w*\s*;/)
          i += 1
          break if i >= lines.size

          buf << lines[i]
        end
        return [buf.strip, i + 1]
      end

      while i < lines.size && !buf.include?(";")
        i += 1
        break if i >= lines.size

        buf << lines[i]
      end
      [buf.strip, i + 1]
    end

    def classify(decl)
      if decl =~ /\A\s*#\s*define\s+(\w+)/
        return [:macro, Regexp.last_match(1)]
      end

      if decl =~ /typedef\s+enum(?:\s+(\w+))?/
        tag = Regexp.last_match(1)
        name = decl[/}\s*(\w+)\s*;/m, 1] || tag
        return [:enum, name] if name
      end

      if decl =~ /typedef\s+.*\(\s*\*\s*(\w+)\s*\)/
        return [:typedef, Regexp.last_match(1)]
      end

      # Function declarator: last identifier immediately before '('.
      names = decl.scan(/\b([A-Za-z_]\w*)\s*\(/).flatten
      names.reject! { |n| %w[if for while switch sizeof _Generic typeof].include?(n) }
      # Drop attribute tokens like gnu, format, printf inside [[…]]
      names.reject! { |n| %w[gnu format printf noreturn].include?(n) }
      return [:function, names.last] if names.last

      nil
    end

    def normalize_sig(decl)
      decl.gsub(/\s+/, " ").strip
    end

    def examples(name)
      Atoms.lib_dir(name).glob("examples/*.{c,cc,cpp}").map do |p|
        text = p.read
        brief = text[/@brief\s+(.+)/, 1]&.strip || p.basename.to_s
        { name: p.basename.to_s, path: p.relative_path_from(Atoms::ROOT).to_s, brief: brief }
      end
    end
  end
end
