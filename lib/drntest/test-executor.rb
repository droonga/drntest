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

require "drntest/test-loader"
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
          if test_command.is_a?(TestLoader::Directive)
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
    def normalize_response(request, response)
      normalizer = ResponseNormalizer.new(request, response)
      normalizer.normalize
    end

    def test_commands
      loader = TestLoader.new(@owner, @test_path)
      loader.load
    end
  end
end
