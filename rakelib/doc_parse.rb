# frozen_string_literal: true

require_relative "atoms"

module Atoms
  module DocParse
    Symbol = Struct.new(:kind, :name, :signature, :brief, :details, :params,
                        :returns, :line, keyword_init: true)

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

          fields = extract_doc_fields(comment)

          kind, sym_name = classify(decl)
          next unless kind && sym_name

          symbols << Symbol.new(
            kind: kind,
            name: sym_name,
            signature: normalize_sig(decl),
            brief: fields[:brief],
            details: fields[:details],
            params: fields[:params],
            returns: fields[:returns],
            line: decl_line + 1
          )
        else
          i += 1
        end
      end
      symbols
    end

    def extract_doc_fields(comment)
      body = comment_content_lines(comment)
      brief = nil
      details = []
      params = []
      returns = nil
      para = []

      flush_para = lambda do
        text = para.join(" ").strip
        details << text unless text.empty?
        para.clear
      end

      body.each do |line|
        if (m = line.match(/\A@brief\s+(.*)\z/))
          flush_para.call
          brief = m[1].strip
        elsif (m = line.match(/\A@details\s*(.*)\z/))
          flush_para.call
          para << m[1].strip unless m[1].strip.empty?
        elsif (m = line.match(/\A@param\s+(\S+)\s+(.*)\z/))
          flush_para.call
          params << [m[1], m[2].strip]
        elsif (m = line.match(/\A@returns?\s+(.*)\z/))
          flush_para.call
          returns = m[1].strip
        elsif line.match?(/\A@\w+/)
          # Other block tags (@file, @note, …) end free-form text.
          flush_para.call
        elsif line.strip.empty?
          flush_para.call
        else
          para << line.strip
        end
      end
      flush_para.call

      # No @brief: first free paragraph becomes the brief (legacy fallback).
      if (brief.nil? || brief.empty?) && !details.empty?
        brief = details.shift
      end

      {
        brief: brief,
        details: details,
        params: params,
        returns: returns
      }
    end

    # Strip Doxygen comment chrome; return one content string per source line.
    def comment_content_lines(comment)
      comment.each_line.map do |raw|
        s = raw.chomp
        s = s.sub(%r{\A\s*/\*+\s?}, "")
        s = s.sub(%r{\s*\*/\s*\z}, "")
        s = s.sub(/\A\s*\*\s?/, "")
        s
      end
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
      Atoms.lib_dir(name).glob("examples/*.{c,cc,cpp}").sort.map do |p|
        text = p.read
        brief = text[/@brief\s+(.+)/, 1]&.strip || p.basename.to_s
        ext = p.extname.delete_prefix(".")
        lang = case ext
               when "c", "h" then "c"
               when "cc", "cpp", "cxx" then "cpp"
               else ext
               end
        {
          name: p.basename.to_s,
          stem: p.basename(p.extname).to_s,
          path: p.relative_path_from(Atoms::ROOT).to_s,
          brief: brief,
          source: text,
          lang: lang
        }
      end
    end
  end
end
