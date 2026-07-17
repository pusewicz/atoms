# frozen_string_literal: true

require "pathname"

module Atoms
  ROOT = Pathname.new(__dir__).parent.expand_path
  SRC = ROOT.join("src")
  DIST = ROOT.join("dist")
  BUILD = ROOT.join("build")
  SITE = ROOT.join("site")
  DOCS_OUT = BUILD.join("docs")
  GITHUB = "https://github.com/pusewicz/atoms"

  module_function

  def libs
    SRC.children.select(&:directory?).map { |p| p.basename.to_s }.sort
  end

  def lib_dir(name)
    SRC.join(name)
  end

  def version(name)
    lib_dir(name).join("VERSION").read.strip
  end

  def git_sha
    sha = `git -C #{ROOT} rev-parse HEAD 2>/dev/null`.strip
    sha.empty? ? "UNKNOWN" : sha
  end

  def git_dirty?
    !`git -C #{ROOT} status --porcelain 2>/dev/null`.strip.empty?
  end
end
