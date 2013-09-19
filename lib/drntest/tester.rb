require "optparse"
require "drntest/test-runner"

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

        parser
      end
    end

    attr_accessor :port, :host, :tag

    def initialize
      @port = 24224
      @host = "localhost"
      @tag  = "droonga"
    end

    def run(*targets)
      tests = load_tests(*targets)
      tests.each do |test|
        test_runner = TestRunner.new(self, test)
        test_runner.run
      end
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
      tests
    end
  end
end
