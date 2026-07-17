# frozen_string_literal: true

require_relative "amalgamate"
require "rake/clean"

CLOBBER.include "dist"

namespace :dist do
  Atoms.libs.each do |name|
    desc "Amalgamate #{name} → dist/#{name}.h"
    task name do
      path = Atoms::Amalgamate.build(name)
      puts "wrote #{path.relative_path_from(Atoms::ROOT)}"
    end
  end
end

desc "Amalgamate all libraries into dist/"
task dist: Atoms.libs.map { |n| "dist:#{n}" }
