# frozen_string_literal: true

require_relative "atoms"

module Atoms
  module DocParse
    Symbol = Struct.new(:kind, :name, :signature, :brief, :params, :returns, :line, keyword_init: true)

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

          brief = comment[/@brief\s+(.+)/, 1]&.strip
          brief ||= comment.lines.map(&:strip).reject { |l| l.start_with?("*") && l =~ /@/ }
                              .join(" ").gsub(/\A\*+\s*/, "").strip
          brief = brief.sub(/\A\*+\s*/, "").split("*").first.to_s.strip if brief

          params = comment.scan(/@param\s+(\S+)\s+(.+)/).map { |n, d| [n, d.strip] }
          returns = comment[/@return\s+(.+)/, 1]&.strip

          kind, sym_name = classify(decl)
          next unless kind

          symbols << Symbol.new(
            kind: kind,
            name: sym_name,
            signature: decl.gsub(/\s+/, " ").strip,
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
      # skip empty / cpp lines
      while i < lines.size && (lines[i].strip.empty? || lines[i] =~ /\A\s*#/)
        return ["", i + 1] if lines[i] =~ /\A\s*#\s*if/
        i += 1 if lines[i].strip.empty? || lines[i] =~ /\A\s*#\s*(define|if|endif|else|elif|include)/
        break unless lines[i]&.strip&.empty? || lines[i] =~ /\A\s*#/
      end
      return ["", i] if i >= lines.size

      buf = +lines[i]
      # multi-line decl until ; or { or macro end
      if lines[i] =~ /\A\s*#\s*define/
        return [lines[i].strip, i + 1]
      end
      while i < lines.size && !buf.include?(";") && !buf.include?("{")
        i += 1
        break if i >= lines.size

        buf << lines[i]
      end
      [buf.strip, i + 1]
    end

    def classify(decl)
      if decl =~ /\A\s*#\s*define\s+(\w+)/
        [:macro, $1]
      elsif decl =~ /typedef\s+enum/
        name = decl[/}\s*(\w+)/, 1]
        [:enum, name || "enum"]
      elsif decl =~ /typedef\s+.*\(\s*\*\s*(\w+)\s*\)/
        [:typedef, $1]
      elsif decl =~ /\b(\w+)\s*\(/
        # function — last identifier before (
        if decl =~ /\b([a-zA-Z_]\w*)\s*\(/
          name = decl.scan(/\b([a-zA-Z_]\w*)\s*\(/).flatten.last
          return [:function, name] if name && !%w[if for while switch].include?(name)
        end
        nil
      else
        nil
      end
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
