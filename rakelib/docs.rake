# frozen_string_literal: true

require_relative "doc_render"
require "fileutils"

desc "Generate documentation site into build/docs/"
task :docs do
  out = Atoms::DocRender.build_all
  puts "docs → #{out.relative_path_from(Atoms::ROOT)}"
end

namespace :docs do
  desc "Check public symbols are documented and each lib has examples"
  task :check do
    Atoms.libs.each do |name|
      symbols = Atoms::DocParse.parse_public(name)
      raise "#{name}: no documented symbols parsed from public.h" if symbols.empty?

      undoc = symbols.select { |s| s.brief.nil? || s.brief.strip.empty? }
      unless undoc.empty?
        raise "#{name}: missing @brief on: #{undoc.map(&:name).join(', ')}"
      end

      ex = Atoms::DocParse.examples(name)
      raise "#{name}: need at least one file in examples/" if ex.empty?

      puts "ok docs #{name} (#{symbols.size} symbols, #{ex.size} examples)"
    end
    Rake::Task[:docs].invoke
  end

  desc "Build docs and serve on http://127.0.0.1:PORT (default 4000; PORT=…)"
  task serve: :docs do
    require "webrick"

    port = Integer(ENV.fetch("PORT", "4000"))
    host = ENV.fetch("HOST", "127.0.0.1")
    root = Atoms::DOCS_OUT.to_s

    server = WEBrick::HTTPServer.new(
      Port: port,
      BindAddress: host,
      DocumentRoot: root,
      AccessLog: [],
      Logger: WEBrick::Log.new($stderr, WEBrick::Log::INFO)
    )

    shut = proc {
      puts "\nstopping docs server…"
      server.shutdown
    }
    trap("INT", &shut)
    trap("TERM", &shut)

    url = "http://#{host}:#{port}/"
    puts "serving #{Atoms::DOCS_OUT.relative_path_from(Atoms::ROOT)} at #{url}"
    puts "  atom_log → #{url}atom_log/"
    puts "  Ctrl-C to stop"
    server.start
  end
end
