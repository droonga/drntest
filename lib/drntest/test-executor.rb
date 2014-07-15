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

require "droonga/client"

require "drntest/test-loader"
require "drntest/response-normalizer"
require "drntest/responses-normalizer"

module Drntest
  class TestExecutor
    def initialize(config, test_path, results)
      @config = config
      @test_path = test_path
      @results = results
    end

    def execute
      catch do |abort_tag|
        begin
          options = {
            :tag     => @config.tag,
            :port    => @config.port,
            :timeout => @config.timeout,
          }
          Droonga::Client.open(options) do |client|
            context = Context.new(client, @config, @results, abort_tag)
            operations.each do |operation|
              context.execute(operation)
            end
            context.finish
          end
        rescue
          @results.errors << $!
        end
      end
    end

    private
    def operations
      loader = TestLoader.new(@config, @test_path)
      loader.load
    end

    class Context
      def initialize(client, config, results, abort_tag)
        @client = client
        @config = config
        @results = results
        @abort_tag = abort_tag
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
        @results.actuals = @responses
      end

      private
      def execute_directive(directive)
        case directive
        when EnableLoggingDirective
          @logging = true
          consume_requests
        when DisableLoggingDirective
          @logging = false
        when OmitDirective
          @results.omit(directive.message)
          abort_execution
        when RequireCatalogVersionDirective
          if @config.catalog_version < directive.version
            message =
              "require catalog version #{directive.version} or later: " +
              "<#{@config.catalog_version}>"
            @results.omit(message)
            abort_execution
          end
        end
      end

      def execute_request(request)
        if @logging
          responses = []
          request_process = @client.request(request) do |raw_response|
            responses << clean_response(request, raw_response)
          end
          request_process.wait
          @responses.concat(normalize_responses(request, responses))
        else
          @requests << @client.request(request) do
          end
        end
      end

      def clean_response(request, raw_response)
        begin
          normalize_response(request, raw_response)
        rescue
          {
            "error" => {
              "message" => "failed to normalize response",
              "detail" => "#{$!.message} (#{$!.class})",
              "backtrace" => $!.backtrace,
              "response" => raw_response,
            },
          }
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

      def normalize_responses(request, responses)
        normalizer = ResponsesNormalizer.new(request, responses)
        normalizer.normalize
      end

      def abort_execution
        throw(@abort_tag)
      end
    end
  end
end
