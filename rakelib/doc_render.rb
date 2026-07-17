# frozen_string_literal: true

require_relative "atoms"
require_relative "doc_parse"
require "cgi"
require "erb"
require "fileutils"

module Atoms
  module DocRender
    module_function

    def build_all
      sha = Atoms.git_sha
      sha_display = Atoms.git_dirty? ? "#{sha}-dirty" : sha
      Atoms::DOCS_OUT.mkpath
      FileUtils.cp(Atoms::SITE.join("styles.css"), Atoms::DOCS_OUT.join("styles.css")) if Atoms::SITE.join("styles.css").file?

      libs = Atoms.libs.map do |name|
        {
          name: name,
          version: Atoms.version(name),
          symbols: DocParse.parse_public(name),
          examples: DocParse.examples(name),
          readme: md_basic(Atoms.lib_dir(name).join("README.md").read),
          source_url: "#{Atoms::GITHUB}/tree/#{sha}/src/#{name}",
          examples_url: "#{Atoms::GITHUB}/tree/#{sha}/src/#{name}/examples",
          changelog_url: "#{Atoms::GITHUB}/blob/#{sha}/src/#{name}/CHANGELOG.md",
          license_url: "#{Atoms::GITHUB}/blob/#{sha}/LICENSE",
          download_url: "#{Atoms::GITHUB}/releases/download/#{name}-v#{Atoms.version(name)}/#{name}.h",
          public_url: "#{Atoms::GITHUB}/blob/#{sha}/src/#{name}/public.h"
        }
      end

      render_index(libs, sha_display)
      libs.each { |lib| render_lib(lib, sha_display) }
      Atoms::DOCS_OUT
    end

    def h(s)
      CGI.escapeHTML(s.to_s)
    end

    def md_basic(text)
      # Minimal markdown: fenced code, headings, paragraphs, inline code, links.
      out = +""
      lines = text.lines
      i = 0
      while i < lines.size
        line = lines[i]
        if line.start_with?("```")
          lang = line.strip.delete_prefix("```")
          i += 1
          code = +""
          while i < lines.size && !lines[i].start_with?("```")
            code << lines[i]
            i += 1
          end
          i += 1
          out << "<pre><code class=\"language-#{h(lang)}\">#{h(code)}</code></pre>\n"
        elsif line =~ /\A#+\s+(.*)/
          level = line[/^#+/].length
          out << "<h#{level}>#{h(Regexp.last_match(1).strip)}</h#{level}>\n"
          i += 1
        elsif line.strip.empty?
          i += 1
        elsif line.start_with?("|")
          # skip tables as preformatted
          table = +""
          while i < lines.size && lines[i].start_with?("|")
            table << lines[i]
            i += 1
          end
          out << "<pre>#{h(table)}</pre>\n"
        else
          para = +line
          i += 1
          while i < lines.size && !lines[i].strip.empty? && !lines[i].start_with?("#", "```", "|")
            para << lines[i]
            i += 1
          end
          html = h(para.strip)
          html = html.gsub(/`([^`]+)`/, '<code>\1</code>')
          html = html.gsub(/\[([^\]]+)\]\(([^)]+)\)/, '<a href="\2">\1</a>')
          out << "<p>#{html}</p>\n"
        end
      end
      out
    end

    def layout(title, body, sha_display)
      license = "#{Atoms::GITHUB}/blob/#{Atoms.git_sha}/LICENSE"
      collection = "#{Atoms::GITHUB}/tree/#{Atoms.git_sha}"
      <<~HTML
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>#{h(title)}</title>
          <link rel="stylesheet" href="#{title == 'atoms' ? 'styles.css' : '../styles.css'}">
        </head>
        <body>
          <header class="site-header">
            <a class="brand" href="#{title == 'atoms' ? './' : '../'}">atoms</a>
          </header>
          <main>
            #{body}
          </main>
          <footer class="site-footer">
            <p>Docs built from commit <code>#{h(sha_display)}</code>
              · <a href="#{h(collection)}">source</a>
              · <a href="#{h(license)}">license</a></p>
          </footer>
        </body>
        </html>
      HTML
    end

    def render_index(libs, sha_display)
      body = +"<h1>atoms</h1><p>Single-header C23 libraries.</p><ul class=\"catalog\">"
      libs.each do |lib|
        body << "<li><a href=\"#{h(lib[:name])}/\"><strong>#{h(lib[:name])}</strong></a> "
        body << "<span class=\"ver\">v#{h(lib[:version])}</span> "
        body << "— <a href=\"#{h(lib[:source_url])}\">source</a></li>"
      end
      body << "</ul>"
      Atoms::DOCS_OUT.join("index.html").write(layout("atoms", body, sha_display))
    end

    def render_lib(lib, sha_display)
      dir = Atoms::DOCS_OUT.join(lib[:name])
      dir.mkpath
      body = +""
      body << "<h1>#{h(lib[:name])} <span class=\"ver\">v#{h(lib[:version])}</span></h1>"
      body << "<nav class=\"lib-nav\">"
      body << "<a href=\"#{h(lib[:source_url])}\">Source</a>"
      body << "<a href=\"#{h(lib[:examples_url])}\">Examples</a>"
      body << "<a href=\"#{h(lib[:changelog_url])}\">Changelog</a>"
      body << "<a href=\"#{h(lib[:download_url])}\">Download</a>"
      body << "<a href=\"#{h(lib[:license_url])}\">License</a>"
      body << "</nav>"

      body << "<section class=\"overview\">#{lib[:readme]}</section>"

      body << "<section id=\"examples\"><h2>Examples</h2><ul>"
      lib[:examples].each do |ex|
        url = "#{Atoms::GITHUB}/blob/#{Atoms.git_sha}/#{ex[:path]}"
        body << "<li><a href=\"#{h(url)}\"><code>#{h(ex[:name])}</code></a> — #{h(ex[:brief])}</li>"
      end
      body << "</ul></section>"

      body << "<section id=\"api\"><h2>API</h2>"
      body << "<p class=\"muted\">Parsed from <a href=\"#{h(lib[:public_url])}\">public.h</a>.</p>"
      lib[:symbols].each do |sym|
        body << "<article class=\"symbol\" id=\"#{h(sym.name)}\">"
        body << "<h3><code>#{h(sym.name)}</code> <span class=\"kind\">#{h(sym.kind)}</span></h3>"
        body << "<pre class=\"sig\"><code>#{h(sym.signature)}</code></pre>"
        body << "<p>#{h(sym.brief)}</p>" if sym.brief && !sym.brief.empty?
        if sym.params && !sym.params.empty?
          body << "<dl class=\"params\">"
          sym.params.each do |n, d|
            body << "<dt><code>#{h(n)}</code></dt><dd>#{h(d)}</dd>"
          end
          body << "</dl>"
        end
        body << "<p class=\"returns\"><strong>Returns:</strong> #{h(sym.returns)}</p>" if sym.returns
        body << "</article>"
      end
      body << "</section>"

      # fix stylesheet path for nested page
      html = layout(lib[:name], body, sha_display)
      html = html.sub('href="styles.css"', 'href="../styles.css"')
                 .sub('href="./"', 'href="../"')
      dir.join("index.html").write(html)
    end
  end
end
