# frozen_string_literal: true

require_relative "amalgamate"

namespace :amalgamate do
  Atoms.libs.each do |name|
    desc "Amalgamate #{name} → build/amalgam/#{name}.h"
    task name do
      path = Atoms::Amalgamate.build(name)
      puts "wrote #{path.relative_path_from(Atoms::ROOT)}"
    end
  end
end

desc "Amalgamate all libraries into build/amalgam/"
task amalgamate: Atoms.libs.map { |n| "amalgamate:#{n}" }
