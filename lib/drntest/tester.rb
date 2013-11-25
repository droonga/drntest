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

require "optparse"
require "drntest/version"
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

        parser.on("--config=PATH",
                  "Path to the default configuration file of Droonga engine" do |config|
          tester.config = config
        end

        parser.on("--catalog=PATH",
                  "Path to the default catalog file of Droonga engine" do |catalog|
          tester.catalog = catalog
        end

        parser.on("--testcase=PATTERN",
                  "Run only testcases which have a name matched to the given PATTERN") do |pattern|
          tester.pattern = pattern
        end

        parser
      end
    end

    attr_accessor :port, :host, :tag, :pattern, :config, :catalog

    def initialize
      @port = 24224
      @host = "localhost"
      @tag  = "droonga"
      @config  = nil
      @catalog = nil
      @pattern = nil
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

      0 # FIXME
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

      unless @pattern.nil?
        if @pattern =~ /\A\/.+\/\z/
          matcher = Regexp.new(@pattern[1..-2])
          tests.select! do |test|
            test.basename(".test").to_s =~ matcher
          end
        else
          tests.select! do |test|
            test.basename(".test").to_s == @pattern
          end
        end
      end

      tests
    end
  end
end
