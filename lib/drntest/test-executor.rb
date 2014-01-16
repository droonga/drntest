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
      Droonga::Client.open(tag: owner.tag, port: owner.port) do |client|
        context = Context.new(client)
        operations.each do |operation|
          context.execute(operation)
        end
        context.finish
        context.responses
      end
    end

    private
    def operations
      loader = TestLoader.new(@owner, @test_path)
      loader.load
    end

    class Context
      attr_reader :responses

      def initialize(client)
        @client = client
        @requests = []
        @responses = []
        @logging = true
      end

      def execute(operation)
        case operation
        when Directive
          execute_directive(operation)
        else
          execute_request(operation)
        end
      end

      def finish
        consume_requests
      end

      private
      def execute_directive(directive)
        case directive.type
        when :enable_logging
          @logging = true
          consume_requests
        when :disable_logging
          @logging = false
        end
      end

      def execute_request(request)
        if @logging
          response = @client.shuttle(request)
          @responses << normalize_response(request, response)
        else
          @requests << @client.shuttle(request, :connect_timeout => 2) do
          end
        end
      end

      def consume_requests
        @requests.each do |request|
          request.wait
        end
        @requests.clear
      end

      def normalize_response(request, response)
        normalizer = ResponseNormalizer.new(request, response)
        normalizer.normalize
      end
    end
  end
end
