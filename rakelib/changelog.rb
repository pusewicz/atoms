# frozen_string_literal: true

require_relative "atoms"

module Atoms
  module Changelog
    module_function

    SEMVER = /\A\d+\.\d+\.\d+\z/

    def path(name)
      Atoms.lib_dir(name).join("CHANGELOG.md")
    end

    def version_path(name)
      Atoms.lib_dir(name).join("VERSION")
    end

    def read_version(name)
      version_path(name).read.strip
    end

    def write_version(name, version)
      version_path(name).write("#{version}\n")
    end

    def check!(name)
      v = read_version(name)
      raise "#{name}: VERSION not semver (#{v.inspect})" unless v.match?(SEMVER)

      text = path(name).read
      unless text.match?(/^## \[Unreleased\]/)
        raise "#{name}: CHANGELOG missing ## [Unreleased]"
      end

      versions = text.scan(/^## \[(\d+\.\d+\.\d+)\]/).flatten
      if versions.size != versions.uniq.size
        raise "#{name}: duplicate version sections in CHANGELOG"
      end
    end

    def bump_version!(name, part)
      v = read_version(name)
      major, minor, patch = v.split(".").map(&:to_i)
      case part
      when :major then major, minor, patch = major + 1, 0, 0
      when :minor then minor, patch = minor + 1, 0
      when :patch then patch += 1
      else raise "part must be major|minor|patch"
      end
      new_v = "#{major}.#{minor}.#{patch}"
      write_version(name, new_v)
      new_v
    end

    def promote!(name)
      v = read_version(name)
      text = path(name).read
      m = text.match(/\A(.*?)## \[Unreleased\]\n(.*?)(?=^## |\z)(.*)\z/m)
      raise "#{name}: could not parse CHANGELOG" unless m

      head, unreleased_body, rest = m[1], m[2], m[3]
      if rest.match?(/^## \[#{Regexp.escape(v)}\]/)
        raise "#{name}: ## [#{v}] already exists"
      end
      unless unreleased_body.lines.any? { |l| l.match?(/\A\s*-\s+\S/) }
        raise "#{name}: [Unreleased] has no bullet entries"
      end

      date = Time.now.utc.strftime("%Y-%m-%d")
      new_text = +"#{head}## [Unreleased]\n\n"
      new_text << "## [#{v}] - #{date}\n"
      new_text << unreleased_body.sub(/\A\n+/, "")
      new_text << rest
      path(name).write(new_text)
      v
    end
  end
end
