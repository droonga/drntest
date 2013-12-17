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

require "droonga/client"

require "drntest/json-loader"
require "drntest/response-normalizer"

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
      client = Droonga::Client.open(tag: owner.tag,
                                    port: owner.port) do |client|
        requests = []
        test_commands.each do |test_command|
          if test_command.is_a?(Directive)
            case test_command.type
            when :enable_logging
              logging = true
              requests.each do |request|
                request.wait
              end
              requests.clear
            when :disable_logging
              logging = false
            end
            next
          end
          if logging
            response = client.connection.execute(test_command)
            actuals << normalize_response(test_command, response)
          else
            requests << client.connection.execute(test_command,
                                                  :connect_timeout => 2) do
            end
          end
        end
        requests.each do |request|
          request.wait
        end
      end
      actuals
    end

    private
    def resolve_relative_path(path)
      path = path.to_s
      path = path[2..-1] if path[0..1] == "./"
      Pathname(path).expand_path(@owner.base_path)
    end

    def normalize_response(request, response)
      normalizer = ResponseNormalizer.new(request, response)
      normalizer.normalize
    end

    def test_commands
      load_jsons(@test_path)
    end

    def load_jsons(path)
      parser = Yajl::Parser.new
      objects = []
      parser.on_parse_complete = lambda do |object|
        objects << object
      end
      data = ""
      Pathname(path).read.each_line do |line|
        data << line
        if line[0] == "#"
          if Directive.directive?(line)
            directive = Directive.new(line)
            if directive.type == :include
              included = resolve_relative_path(directive.value)
              included_objects = load_jsons(included)
              objects += included_objects
            else
              objects << directive
            end
          end
        else
          begin
            parser << line
          rescue Yajl::ParseError => error
            JSONLoader.report_error(path, data, error)
            raise error
          end
        end
      end
      objects
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
