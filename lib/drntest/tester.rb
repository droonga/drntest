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

require "shellwords"
require "optparse"
require "pathname"

require "drntest/version"
require "drntest/path"
require "drntest/test-runner"
require "drntest/test-suites-result"

module Drntest
  class Tester
    class << self
      def run(argv=nil)
        argv ||= ARGV.dup
        tester = new
        option_parser = create_option_parser(tester)
        targets = option_parser.parse!(argv)
        targets << tester.base_path + Path::SUITE if targets.empty?
        tester.run(*targets)
      end

      private
      def create_option_parser(tester)
        parser = OptionParser.new

        parser.banner += " TEST_FILE..."

        parser.on("--port=PORT",
                  "Connect to fluent-plugin-droonga on PORT",
                  "(#{tester.port})") do |port|
          tester.port = port
        end

        parser.on("--host=HOST",
                  "Connect to fluent-plugin-droonga on HOST",
                  "(#{tester.host})") do |host|
          tester.host = host
        end

        parser.on("--tag=TAG",
                  "Send messages to fluent-plugin-droonga with TAG",
                  "(#{tester.tag})") do |tag|
          tester.tag = tag
        end

        parser.on("--base-path=PATH",
                  "Path to the base directory including test suite, config and fixture",
                  "(#{tester.base_path})") do |base_path|
          tester.base_path = Pathname(base_path).expand_path(Dir.pwd)
        end

        parser.on("--config=NAME",
                  "Name of the configuration directory for Droonga engine",
                  "(#{tester.config})") do |config|
          tester.config = config
        end

        parser.on("--fluentd=PATH",
                  "Path to the fluentd executable",
                  "(#{tester.fluentd})") do |fluentd|
          tester.fluentd = fluentd
        end

        parser.on("--fluentd-options=OPTIONS",
                  "Options for fluentd",
                  "You can specify this option multiple times") do |options|
          tester.fluentd_options.concat(Shellwords.split(options))
        end

        parser.on("--test=PATTERN",
                  "Run only tests which have a name matched to the given PATTERN") do |pattern|
          if /\A\/(.+)\/\z/ =~ pattern
            pattern = Regexp.new($1)
          end
          tester.test_pattern = pattern
        end

        parser.on("--test-suite=PATTERN",
                  "Run only test suites which have a path matched to the given PATTERN") do |pattern|
          if /\A\/(.+)\/\z/ =~ pattern
            pattern = Regexp.new($1)
          end
          tester.suite_pattern = pattern
        end

        parser
      end
    end

    attr_accessor :port, :host, :tag, :fluentd, :fluentd_options
    attr_accessor :test_pattern, :suite_pattern, :base_path, :config

    def initialize
      @port = 24224
      @host = "localhost"
      @tag  = "droonga"
      @base_path = Pathname(Dir.pwd)
      @config  = "default"
      @fluentd = "fluentd"
      @fluentd_options = []
      @test_pattern = nil
      @suite_pattern = nil
    end

    def run(*targets)
      test_suites_result = TestSuitesResult.new
      tests = load_tests(*targets)
      tests.each do |test|
        test_runner = TestRunner.new(self, test)
        test_suites_result.test_results << test_runner.run
      end

      puts
      puts "==== Test Results ===="
      test_suites_result.test_results.each do |result|
        puts "%s: %s" % [
          result.name,
          result.status
        ]
      end

      puts
      puts "==== Summary ===="
      p test_suites_result.summary

      test_suites_result.success?
    end

    def load_tests(*targets)
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
          @suite_pattern === test.dirname.to_s.sub(@base_path.to_s, "")
        end
      end

      tests
    end
  end
end
