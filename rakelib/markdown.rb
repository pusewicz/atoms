# frozen_string_literal: true

require "cgi"
require "commonmarker"
require "rouge"

module Atoms
  # GitHub-Flavoured Markdown → HTML via commonmarker (cmark-gfm), with
  # fenced code blocks highlighted by Rouge.
  module Markdown
    module_function

    GFM_OPTIONS = {
      parse: {
        smart: true
      },
      render: {
        hardbreaks: false,
        github_pre_lang: true,
        unsafe: false,
        gfm_quirks: true
      },
      extension: {
        strikethrough: true,
        tagfilter: true,
        table: true,
        autolink: true,
        tasklist: true,
        header_ids: "", # enable GFM heading anchors (empty prefix)
        footnotes: true,
        shortcodes: false
      }
    }.freeze

    # Disable syntect; we highlight with Rouge instead.
    PLUGINS = { syntax_highlighter: nil }.freeze

    FORMATTER = Rouge::Formatters::HTML.new
    LEXER_C = Rouge::Lexer.find("c")

    def to_html(text)
      raw = Commonmarker.to_html(text.to_s, options: GFM_OPTIONS, plugins: PLUGINS)
      highlight_pre_blocks(raw)
    end

    # Highlight a C fragment (API signatures, inlined examples).
    def highlight_c(source)
      wrap_highlight(LEXER_C, source.to_s)
    end

    def highlight(source, language)
      lexer = Rouge::Lexer.find_fancy(language.to_s, source.to_s) ||
              Rouge::Lexers::PlainText.new
      wrap_highlight(lexer, source.to_s)
    end

    def wrap_highlight(lexer, source)
      code = FORMATTER.format(lexer.lex(source))
      %(<pre class="highlight"><code class="language-#{CGI.escapeHTML(lexer.tag)}">#{code}</code></pre>)
    end

    # Replace plain <pre lang="…"><code>…</code></pre> from cmark with Rouge HTML.
    def highlight_pre_blocks(html)
      html.gsub(
        %r{<pre(?:\s+lang="([^"]*)")?><code>(.*?)</code></pre>}m
      ) do
        lang = Regexp.last_match(1).to_s
        raw_code = CGI.unescapeHTML(Regexp.last_match(2))
        # Drop a single trailing newline cmark often leaves in the fence body.
        raw_code = raw_code.chomp
        highlight(raw_code, lang.empty? ? "text" : lang)
      end
    end

    # CSS for light + dark themes, scoped to .highlight, matching site tones.
    def theme_css
      light = Rouge::Theme.find("github.light").render(scope: ".highlight")
      dark  = Rouge::Theme.find("github.dark").render(scope: ".highlight")
      <<~CSS
        /* Rouge: github.light (default) + github.dark (prefers-color-scheme) */
        #{light}

        /* Prefer our paper/dark code surfaces over theme page backgrounds. */
        pre.highlight,
        .highlight {
          background: var(--code-bg) !important;
        }
        pre.highlight code,
        .highlight code {
          background: transparent;
        }

        @media (prefers-color-scheme: dark) {
        #{dark}
          pre.highlight,
          .highlight {
            background: var(--code-bg) !important;
          }
        }
      CSS
    end
  end
end
