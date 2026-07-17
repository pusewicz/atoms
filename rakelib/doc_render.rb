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
        examples = DocParse.examples(name).map do |ex|
          ex.merge(
            github_url: "#{Atoms::GITHUB}/blob/#{sha}/#{ex[:path]}",
            page_url: "examples/#{ex[:stem]}.html"
          )
        end
        {
          name: name,
          version: Atoms.version(name),
          symbols: DocParse.parse_public(name),
          examples: examples,
          readme: Markdown.to_html(readme_md),
          changelog: changelog_path.file? ? Markdown.to_html(changelog_path.read) : "",
          license_text: license_text,
          source_url: "#{Atoms::GITHUB}/tree/#{sha}/src/#{name}",
          github_examples_url: "#{Atoms::GITHUB}/tree/#{sha}/src/#{name}/examples",
          download_url: "#{Atoms::GITHUB}/releases/download/#{name}-v#{Atoms.version(name)}/#{name}.h",
          public_url: "#{Atoms::GITHUB}/blob/#{sha}/src/#{name}/public.h"
        }
      end

      render_index(libs, sha_display)
      libs.each do |lib|
        render_lib(lib, sha_display)
        render_examples_browser(lib, sha_display)
      end
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

    # depth: 0 = site root, 1 = lib/, 2 = lib/examples/
    def layout(title, body, sha_display, depth: 0, scripts: [],
               lib_name: nil, lib_version: nil, lib_href: nil,
               page_class: nil)
      collection = "#{Atoms::GITHUB}/tree/#{Atoms.git_sha}"
      prefix = depth.zero? ? "" : ("../" * depth)
      css_href = "#{prefix}styles.css"
      home_href = depth.zero? ? "./" : prefix
      script_prefix = prefix
      footer_license = if lib_name
                         href = depth >= 2 ? "../#license" : "#license"
                         "· <a href=\"#{h(href)}\">license</a>"
                       else
                         ""
                       end
      script_tags = scripts.map { |s|
        %(<script src="#{h(script_prefix + s)}" defer></script>)
      }.join("\n  ")

      lib_top = lib_href || (depth >= 2 ? "../" : "#top")
      crumb = if lib_name
                <<~HTML.chomp
                  <span class="header-sep" aria-hidden="true">/</span>
                        <a class="header-lib" href="#{h(lib_top)}">#{h(lib_name)} <span class="ver">v#{h(lib_version)}</span></a>
                HTML
              else
                ""
              end

      body_attrs = []
      body_attrs << %(id="top")
      classes = []
      classes << "has-toc" if page_class.to_s.include?("has-toc") || (lib_name && depth == 1 && page_class.nil?)
      classes << page_class if page_class && page_class != "has-toc"
      body_attrs << %(class="#{classes.join(' ')}") unless classes.empty?

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
        <body #{body_attrs.join(' ')}>
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
        layout("atoms", body, sha_display, depth: 0)
      )
    end

    def toc_html(lib)
      symbols = lib[:symbols]
      out = +%(<nav class="toc" data-toc aria-label="Table of contents">\n)
      out << %(<h2 class="toc-title">On this page</h2>\n)
      out << %(<ul class="toc-sections">\n)
      out << %(<li><a href="#overview">Overview</a></li>\n)
      out << %(<li><a href="examples/">Examples</a></li>\n)
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

    def examples_sidebar(lib, active_stem: nil)
      out = +%(<nav class="examples-nav" aria-label="Examples">\n)
      out << %(<h2 class="toc-title">Examples</h2>\n)
      out << %(<ul class="examples-list">\n)
      index_active = active_stem.nil? ? " is-active" : ""
      out << %(<li class="#{index_active.strip}"><a href="index.html">All examples</a></li>\n)
      lib[:examples].each do |ex|
        active = ex[:stem] == active_stem ? " is-active" : ""
        out << %(<li class="#{active.strip}">)
        out << %(<a href="#{h(ex[:stem])}.html"><code>#{h(ex[:name])}</code>)
        out << %(<span class="examples-brief">#{h(ex[:brief])}</span></a></li>\n)
      end
      out << %(</ul>\n)
      out << %(<p class="muted examples-github"><a href="#{h(lib[:github_examples_url])}">View on GitHub</a></p>\n)
      out << %(</nav>\n)
      out
    end

    def render_examples_browser(lib, sha_display)
      ex_dir = Atoms::DOCS_OUT.join(lib[:name], "examples")
      ex_dir.mkpath

      # Index: gallery of all examples
      cards = +""
      lib[:examples].each do |ex|
        cards << %(<article class="example-card">\n)
        cards << %(<h2><a href="#{h(ex[:stem])}.html"><code>#{h(ex[:name])}</code></a></h2>\n)
        cards << %(<p>#{h(ex[:brief])}</p>\n)
        cards << %(<div class="example-preview">)
        cards << Markdown.highlight(ex[:source], ex[:lang])
        cards << %(</div>\n)
        cards << %(<p class="example-actions">)
        cards << %(<a class="button" href="#{h(ex[:stem])}.html">Open</a> )
        cards << %(<a href="#{h(ex[:github_url])}">Source on GitHub</a>)
        cards << %(</p>\n</article>\n)
      end

      if lib[:examples].empty?
        cards = %(<p class="muted">No examples yet.</p>\n)
      end

      content = +""
      content << %(<h1>Examples</h1>\n)
      content << %(<p class="muted">Runnable samples for <code>#{h(lib[:name])}</code>. )
      content << %(Build with <code>rake example:#{h(lib[:name])}</code>.</p>\n)
      content << cards

      body = +%(<div class="page examples-page">\n)
      body << examples_sidebar(lib, active_stem: nil)
      body << %(<main class="content">\n#{content}</main>\n</div>\n)

      ex_dir.join("index.html").write(
        layout(
          "#{lib[:name]} examples",
          body,
          sha_display,
          depth: 2,
          lib_name: lib[:name],
          lib_version: lib[:version],
          lib_href: "../",
          page_class: "has-examples-nav"
        )
      )

      # One page per example
      lib[:examples].each do |ex|
        render_example_page(lib, ex, sha_display)
      end
    end

    def render_example_page(lib, ex, sha_display)
      ex_dir = Atoms::DOCS_OUT.join(lib[:name], "examples")

      content = +""
      content << %(<h1><code>#{h(ex[:name])}</code></h1>\n)
      content << %(<p>#{h(ex[:brief])}</p>\n)
      content << %(<p class="example-meta muted">)
      content << %(<code>#{h(ex[:path])}</code> · )
      content << %(<a href="#{h(ex[:github_url])}">GitHub</a>)
      content << %(</p>\n)
      content << %(<div class="example-source">)
      content << Markdown.highlight(ex[:source], ex[:lang])
      content << %(</div>\n)
      content << %(<h2>Run</h2>\n)
      content << %(<pre class="highlight"><code class="language-shell">)
      content << h("rake example:#{lib[:name]}")
      content << %(</code></pre>\n)
      content << %(<p class="muted">Or compile against <code>dist/#{h(lib[:name])}.h</code> after )
      content << %(<code>rake dist:#{h(lib[:name])}</code>.</p>\n)

      body = +%(<div class="page examples-page">\n)
      body << examples_sidebar(lib, active_stem: ex[:stem])
      body << %(<main class="content">\n#{content}</main>\n</div>\n)

      ex_dir.join("#{ex[:stem]}.html").write(
        layout(
          "#{ex[:name]} · #{lib[:name]}",
          body,
          sha_display,
          depth: 2,
          lib_name: lib[:name],
          lib_version: lib[:version],
          lib_href: "../",
          page_class: "has-examples-nav"
        )
      )
    end

    def render_lib(lib, sha_display)
      dir = Atoms::DOCS_OUT.join(lib[:name])
      dir.mkpath

      content = +""
      content << %(<h1>#{h(lib[:name])} <span class="ver">v#{h(lib[:version])}</span></h1>\n)
      content << %(<nav class="lib-nav">\n)
      content << %(<a href="#{h(lib[:source_url])}">Source</a>\n)
      content << %(<a href="examples/">Examples</a>\n)
      content << %(<a href="#api">API</a>\n)
      content << %(<a href="#changelog">Changelog</a>\n) unless lib[:changelog].empty?
      content << %(<a href="#{h(lib[:download_url])}">Download</a>\n)
      content << %(<a href="#license">License</a>\n)
      content << %(</nav>\n)

      content << %(<section id="overview" class="overview markdown-body">#{lib[:readme]}</section>\n)

      content << %(<section id="examples"><h2>Examples</h2>\n)
      content << %(<p><a href="examples/">Browse all examples →</a></p>\n)
      content << %(<ul class="examples-summary">\n)
      lib[:examples].each do |ex|
        content << %(<li><a href="#{h(ex[:page_url])}"><code>#{h(ex[:name])}</code></a> — #{h(ex[:brief])}</li>\n)
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
          depth: 1,
          scripts: ["toc.js"],
          lib_name: lib[:name],
          lib_version: lib[:version],
          page_class: "has-toc"
        )
      )
    end
  end
end
