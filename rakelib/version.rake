# frozen_string_literal: true

require_relative "atoms"
require_relative "changelog"

desc "List library versions"
task :version do
  Atoms.libs.each do |name|
    puts "#{name} #{Atoms.version(name)}"
  end
end

namespace :version do
  desc "Check VERSION + CHANGELOG consistency for all libraries"
  task :check do
    Atoms.libs.each do |name|
      Atoms::Changelog.check!(name)
      puts "ok #{name} #{Atoms.version(name)}"
    end
  end

  Atoms.libs.each do |name|
    desc "Print VERSION for #{name}"
    task name do
      puts Atoms.version(name)
    end

    namespace name do
      desc "Bump #{name} VERSION (patch|minor|major)"
      task :bump, [:part] do |_t, args|
        part = (args[:part] || "patch").to_sym
        new_v = Atoms::Changelog.bump_version!(name, part)
        puts "#{name} → #{new_v}"
      end
    end
  end
end
