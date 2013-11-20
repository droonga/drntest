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

        parser.on("--testcase=PATTERN",
                  "Run only testcases which have a name matched to the given PATTERN") do |pattern|
          tester.pattern = pattern
        end

        parser
      end
    end

    attr_accessor :port, :host, :tag, :pattern

    def initialize
      @port = 24224
      @host = "localhost"
      @tag  = "droonga"
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
