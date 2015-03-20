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

require "shellwords"
require "optparse"
require "pathname"

require "drntest/version"
require "drntest/configuration"
require "drntest/test-runner"
require "drntest/test-suites-result"

module Drntest
  class Tester
    class << self
      def run(argv=nil)
        argv ||= ARGV.dup
        tester = new
        *targets = tester.parse_command_line_options(argv)
        tester.run(*targets)
      end
    end

    def initialize
      @config = Configuration.new
      @test_pattern = nil
      @suite_pattern = nil
    end

    def parse_command_line_options(command_line_options)
      option_parser = create_option_parser
      option_parser.parse!(command_line_options)
    end

    def run(*targets)
      test_suites_result = TestSuitesResult.new
      tests = load_tests(*targets)
      tests.each do |test|
        test_runner = TestRunner.new(@config, test)
        result = test_runner.run
        test_suites_result.test_results << result
        if result.status == :no_response and @config.exit_on_stalled?
          break
        end
      end

      puts
      puts "==== Summary ===="
      p test_suites_result.summary

      test_suites_result.success?
    end

    private
    def create_option_parser
      parser = OptionParser.new

      parser.banner += " TEST_FILE..."

      parser.on("--port=PORT",
                "Connect to fluent-plugin-droonga on PORT",
                "(#{@config.port})") do |port|
        @config.port = port
      end

      parser.on("--host=HOST",
                "Connect to fluent-plugin-droonga on HOST",
                "(#{@config.host})") do |host|
        @config.host = host
      end

      parser.on("--tag=TAG",
                "Send messages to fluent-plugin-droonga with TAG",
                "(#{@config.tag})") do |tag|
        @config.tag = tag
      end

      parser.on("--base-path=PATH",
                "Path to the base directory including test suite, config and fixture",
                "(#{@config.base_path})") do |base_path|
        @config.base_path = Pathname(base_path).expand_path(Dir.pwd)
      end

      parser.on("--config=NAME",
                "Name of the configuration directory for Droonga engine",
                "(#{@config.engine_config})") do |config|
        @config.engine_config = config
      end

      parser.on("--droonga-engine=PATH",
                "Path to the droonga-engine executable",
                "(#{@config.droonga_engine})") do |droonga_engine|
        @config.droonga_engine = droonga_engine
      end

      parser.on("--droonga-engine-options=OPTIONS",
                "Options for droonga-engine",
                "You can specify this option multiple times") do |options|
        @config.droonga_engine_options.concat(Shellwords.split(options))
      end

      parser.on("--test=PATTERN",
                "Run only tests which have a name matched to the given PATTERN") do |pattern|
        if /\A\/(.+)\/\z/ =~ pattern
          pattern = Regexp.new($1)
        end
        @test_pattern = pattern
      end

      parser.on("--test-suite=PATTERN",
                "Run only test suites which have a path matched to the given PATTERN") do |pattern|
        if /\A\/(.+)\/\z/ =~ pattern
          pattern = Regexp.new($1)
        end
        @suite_pattern = pattern
      end

      parser.on("--timeout=TIMEOUT", Float,
                "Wait TIMEOUT seconds for " +
                  "receiving responses from Droonga engine") do |timeout|
        @config.timeout = timeout
      end

      parser.on("--exit-on-stalled",
                "Stop running of tests when \"NO RESPONSE\" result appears on any testcase") do
        @config.exit_on_stalled = true
      end

      parser
    end

    def load_tests(*targets)
      suite_path = @config.suite_path
      targets << suite_path if targets.empty?

      tests = []
      targets.each do |target|
        target_path = Pathname(target)
        next unless target_path.exist?
        if target_path.directory?
          tests += Pathname.glob(target_path + "**" + "*.test")
        else
          tests << target_path
        end
      end

      unless @test_pattern.nil?
        tests.select! do |test|
          @test_pattern === test.basename(".test").to_s
        end
      end

      unless @suite_pattern.nil?
        tests.select! do |test|
          test_suite_name = test.relative_path_from(suite_path).dirname.to_s
          @suite_pattern === test_suite_name
        end
      end

      tests
    end
  end
end
