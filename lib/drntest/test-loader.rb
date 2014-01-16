# Copyright (C) 2013-2014  Droonga Project
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require "drntest/json-loader"
require "drntest/directive"

module Drntest
  class TestLoader
    def initialize(config, test_path)
      @config = config
      @test_path = test_path
    end

    def load
      load_test_file(@test_path)
    end

    private
    def resolve_relative_path(path)
      path = path.to_s
      path = path[2..-1] if path[0..1] == "./"
      Pathname(path).expand_path(@config.base_path)
    end

    def load_test_file(path)
      parser = Yajl::Parser.new
      operations = []
      parser.on_parse_complete = lambda do |operation|
        operations << operation
      end
      data = ""
      Pathname(path).read.each_line do |line|
        data << line
        case line.chomp
        when /\A\#\@([^\s]+)(?:\s+(.+))?\z/
          type = $1
          value = $2
          directive = Directive.new(type, value)
          if directive.type == :include
            included = resolve_relative_path(directive.value)
            included_operations = load_test_file(included)
            operations += included_operations
          else
            operations << directive
          end
        when /\A\#/
          # comment
        else
          begin
            parser << line
          rescue Yajl::ParseError => error
            JSONLoader.report_error(path, data, error)
            raise error
          end
        end
      end
      operations
    end
  end
end
