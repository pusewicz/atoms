# frozen_string_literal: true

require_relative "atoms"
require_relative "doc_parse"
require_relative "markdown"
require "cgi"
require "erb"
require "fileutils"

module Atoms
  module DocRender
    module_function

    KIND_ORDER = %i[enum typedef function macro].freeze
    KIND_LABEL = {
      enum: "Enums",
      typedef: "Types",
      function: "Functions",
      macro: "Macros"
    }.freeze

    def build_all
      sha = Atoms.git_sha
      sha_display = Atoms.git_dirty? ? "#{sha}-dirty" : sha
      Atoms::DOCS_OUT.mkpath

      write_styles!
      write_scripts!
      license_text = Atoms::ROOT.join("LICENSE").read

      libs = Atoms.libs.map do |name|
        readme_path = Atoms.lib_dir(name).join("README.md")
        changelog_path = Atoms.lib_dir(name).join("CHANGELOG.md")
        readme_md = strip_license_section(readme_path.read)
        {
          name: name,
          version: Atoms.version(name),
          symbols: DocParse.parse_public(name),
          examples: DocParse.examples(name),
          readme: Markdown.to_html(readme_md),
          changelog: changelog_path.file? ? Markdown.to_html(changelog_path.read) : "",
          license_text: license_text,
          source_url: "#{Atoms::GITHUB}/tree/#{sha}/src/#{name}",
          examples_url: "#{Atoms::GITHUB}/tree/#{sha}/src/#{name}/examples",
          changelog_url: "#{Atoms::GITHUB}/blob/#{sha}/src/#{name}/CHANGELOG.md",
          download_url: "#{Atoms::GITHUB}/releases/download/#{name}-v#{Atoms.version(name)}/#{name}.h",
          public_url: "#{Atoms::GITHUB}/blob/#{sha}/src/#{name}/public.h"
        }
      end

      render_index(libs, sha_display)
      libs.each { |lib| render_lib(lib, sha_display) }
      Atoms::DOCS_OUT
    end

    def strip_license_section(md)
      md.sub(/\n##[ \t]+License\b.*\z/m, "\n")
    end

    def write_styles!
      site_css = Atoms::SITE.join("styles.css")
      css = +""
      css << site_css.read if site_css.file?
      css << "\n"
      css << Markdown.theme_css
      Atoms::DOCS_OUT.join("styles.css").write(css)
    end

    def write_scripts!
      toc_js = Atoms::SITE.join("toc.js")
      FileUtils.cp(toc_js, Atoms::DOCS_OUT.join("toc.js")) if toc_js.file?
    end

    def h(s)
      CGI.escapeHTML(s.to_s)
    end

    def layout(title, body, sha_display, root: true, scripts: [],
               lib_name: nil, lib_version: nil)
      collection = "#{Atoms::GITHUB}/tree/#{Atoms.git_sha}"
      css_href = root ? "styles.css" : "../styles.css"
      home_href = root ? "./" : "../"
      script_prefix = root ? "" : "../"
      footer_license = root ? "" : '· <a href="#license">license</a>'
      script_tags = scripts.map { |s|
        %(<script src="#{h(script_prefix + s)}" defer></script>)
      }.join("\n  ")

      crumb = if lib_name
                <<~HTML.chomp
                  <span class="header-sep" aria-hidden="true">/</span>
                        <a class="header-lib" href="#top">#{h(lib_name)} <span class="ver">v#{h(lib_version)}</span></a>
                HTML
              else
                ""
              end

      body_class = root ? "" : ' class="has-toc"'
      <<~HTML
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>#{h(title)}</title>
          <link rel="stylesheet" href="#{h(css_href)}">
          #{script_tags}
        </head>
        <body id="top"#{body_class}>
          <header class="site-header">
            <div class="site-header-inner">
              <a class="brand" href="#{h(home_href)}">atoms</a>
              #{crumb}
            </div>
          </header>
          #{body}
          <footer class="site-footer">
            <p>Docs built from commit <code>#{h(sha_display)}</code>
              · <a href="#{h(collection)}">source</a>
              #{footer_license}</p>
          </footer>
        </body>
        </html>
      HTML
    end

    def license_section(text)
      <<~HTML
        <section id="license">
          <h2>License</h2>
          <pre class="license"><code>#{h(text.rstrip)}\n</code></pre>
        </section>
      HTML
    end

    def render_index(libs, sha_display)
      body = +"<main><h1>atoms</h1><p>Single-header C23 libraries.</p><ul class=\"catalog\">"
      libs.each do |lib|
        body << "<li><a href=\"#{h(lib[:name])}/\"><strong>#{h(lib[:name])}</strong></a> "
        body << "<span class=\"ver\">v#{h(lib[:version])}</span> "
        body << "— <a href=\"#{h(lib[:source_url])}\">source</a></li>"
      end
      body << "</ul></main>"
      Atoms::DOCS_OUT.join("index.html").write(
        layout("atoms", body, sha_display, root: true)
      )
    end

    def toc_html(lib)
      symbols = lib[:symbols]
      out = +%(<nav class="toc" data-toc aria-label="Table of contents">\n)
      out << %(<h2 class="toc-title">On this page</h2>\n)
      out << %(<ul class="toc-sections">\n)
      out << %(<li><a href="#overview">Overview</a></li>\n)
      out << %(<li><a href="#examples">Examples</a></li>\n)
      out << %(<li><a href="#api">API</a></li>\n)
      out << %(<li><a href="#changelog">Changelog</a></li>\n) unless lib[:changelog].empty?
      out << %(<li><a href="#license">License</a></li>\n)
      out << %(</ul>\n)

      out << %(<div class="toc-api">\n)
      out << %(<h3 class="toc-subtitle">API</h3>\n)
      out << %(<label class="toc-filter-label" for="toc-filter">Filter</label>\n)
      out << %(<input id="toc-filter" class="toc-filter" type="search" )
      out << %(data-toc-filter placeholder="Filter symbols…" )
      out << %(autocomplete="off" spellcheck="false">\n)
      out << %(<p class="toc-empty" data-toc-empty hidden>No matches</p>\n)

      KIND_ORDER.each do |kind|
        group = symbols.select { |s| s.kind == kind }
        next if group.empty?

        out << %(<div class="toc-group" data-toc-group data-kind="#{h(kind)}">\n)
        out << %(<h4 class="toc-kind">#{h(KIND_LABEL[kind])}</h4>\n)
        out << %(<ul class="toc-symbols">\n)
        group.each do |sym|
          out << %(<li data-toc-item data-toc-name="#{h(sym.name)}" )
          out << %(data-toc-kind="#{h(sym.kind)}">)
          out << %(<a href="##{h(sym.name)}"><code>#{h(sym.name)}</code>)
          out << %(<span class="toc-kind-tag">#{h(sym.kind)}</span></a></li>\n)
        end
        out << %(</ul>\n</div>\n)
      end
      out << %(</div>\n</nav>\n)
      out
    end

    def render_lib(lib, sha_display)
      dir = Atoms::DOCS_OUT.join(lib[:name])
      dir.mkpath

      content = +""
      content << %(<h1>#{h(lib[:name])} <span class="ver">v#{h(lib[:version])}</span></h1>\n)
      content << %(<nav class="lib-nav">\n)
      content << %(<a href="#{h(lib[:source_url])}">Source</a>\n)
      content << %(<a href="#{h(lib[:examples_url])}">Examples</a>\n)
      content << %(<a href="#api">API</a>\n)
      content << %(<a href="#changelog">Changelog</a>\n) unless lib[:changelog].empty?
      content << %(<a href="#{h(lib[:download_url])}">Download</a>\n)
      content << %(<a href="#license">License</a>\n)
      content << %(</nav>\n)

      content << %(<section id="overview" class="overview markdown-body">#{lib[:readme]}</section>\n)

      content << %(<section id="examples"><h2>Examples</h2><ul>\n)
      lib[:examples].each do |ex|
        url = "#{Atoms::GITHUB}/blob/#{Atoms.git_sha}/#{ex[:path]}"
        content << %(<li><a href="#{h(url)}"><code>#{h(ex[:name])}</code></a> — #{h(ex[:brief])}</li>\n)
      end
      content << %(</ul></section>\n)

      content << %(<section id="api"><h2>API</h2>\n)
      content << %(<p class="muted">Parsed from <a href="#{h(lib[:public_url])}">public.h</a>.</p>\n)
      lib[:symbols].each do |sym|
        content << %(<article class="symbol" id="#{h(sym.name)}" data-kind="#{h(sym.kind)}">\n)
        content << %(<h3><code>#{h(sym.name)}</code> <span class="kind">#{h(sym.kind)}</span></h3>\n)
        content << Markdown.highlight_c(sym.signature)
        content << %(<p>#{h(sym.brief)}</p>\n) if sym.brief && !sym.brief.empty?
        if sym.params && !sym.params.empty?
          content << %(<dl class="params">\n)
          sym.params.each do |n, d|
            content << %(<dt><code>#{h(n)}</code></dt><dd>#{h(d)}</dd>\n)
          end
          content << %(</dl>\n)
        end
        if sym.returns
          content << %(<p class="returns"><strong>Returns:</strong> #{h(sym.returns)}</p>\n)
        end
        content << %(</article>\n)
      end
      content << %(</section>\n)

      unless lib[:changelog].empty?
        content << %(<section id="changelog" class="markdown-body">\n)
        content << %(<h2>Changelog</h2>\n)
        content << lib[:changelog]
        content << %(</section>\n)
      end

      content << license_section(lib[:license_text])

      body = +%(<div class="page">\n)
      body << toc_html(lib)
      body << %(<main class="content">\n)
      body << content
      body << %(</main>\n</div>\n)

      dir.join("index.html").write(
        layout(
          lib[:name],
          body,
          sha_display,
          root: false,
          scripts: ["toc.js"],
          lib_name: lib[:name],
          lib_version: lib[:version]
        )
      )
    end
  end
end
