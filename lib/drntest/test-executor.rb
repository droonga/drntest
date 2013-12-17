# Copyright (C) 2013  Droonga Project
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

require "yajl"

require "drntest/request-executor"

module Drntest
  class TestExecutor
    attr_reader :owner, :test_path

    def initialize(owner, test_path)
      @owner = owner
      @test_path = test_path
    end

    def execute
      actuals = []
      logging = true
      requests.each do |request|
        if request.is_a?(Directive)
          case request.type
          when :enable_logging
            logging = true
          when :disable_logging
            logging = false
          end
          next
        end
        executor = RequestExecutor.new(@owner, request)
        response = executor.execute
        actuals << response if logging
      end
      actuals
    end

    private
    def resolve_relative_path(path)
      path = path.to_s
      path = path[2..-1] if path[0..1] == "./"
      Pathname(path).expand_path(@owner.base_path)
    end

    def requests
      load_jsons(@test_path)
    end

    def load_jsons(path)
      parser = Yajl::Parser.new
      objects = []
      parser.on_parse_complete = Proc.new do |object|
        objects << object
      end
      Pathname(path).read.each_line do |line|
        if line[0] == "#"
          if Directive.directive?(line)
            directive = Directive.new(line)
            if directive.type == :include
              included = resolve_relative_path(directive.value)
              included_jsons = load_jsons(included)
              json_objects += included_jsons
            else
              json_objects << directive
            end
          end
        else
          begin
            parser << line
          rescue StandardError => error
            p "Failed to load JSONs file: #{path.to_s}"
            raise error
          end
        end
      end
      json_objects
    end

    class Directive
      MATCHER = /\A\#\@([^\s]+)(?:\s+(.+))?\z/.freeze

      class << self
        def directive?(source)
          MATCHER =~ source.strip
        end
      end

      attr_reader :type, :value

      def initialize(source)
        MATCHER =~ source.strip
        @value = $2
        @type = $1.gsub("-", "_").to_sym
      end
    end
  end
end
