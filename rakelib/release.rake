# frozen_string_literal: true

require_relative "atoms"
require_relative "changelog"

namespace :release do
  Atoms.libs.each do |name|
    desc "Cut release for #{name}: promote [Unreleased] → ## [VERSION] (VERSION unchanged)"
    task name do
      v = Atoms::Changelog.promote!(name)
      Rake::Task["dist:#{name}"].invoke
      tag = "#{name}-v#{v}"
      puts
      puts "Release #{name} v#{v} prepared."
      puts "  1. Review CHANGELOG.md and dist/#{name}.h"
      puts "  2. git add -A && git commit -m 'Release #{name} v#{v}'"
      puts "  3. git tag -a #{tag} -m '#{name} v#{v}'"
      puts "  4. git push && git push origin #{tag}"
      puts "  5. rake release:#{name}:bump_next"
    end

    namespace name do
      desc "After tagging #{name}, bump VERSION to next patch for ongoing work"
      task :bump_next do
        new_v = Atoms::Changelog.bump_version!(name, :patch)
        puts "#{name} VERSION → #{new_v} (ready for unreleased work)"
      end
    end
  end
end
