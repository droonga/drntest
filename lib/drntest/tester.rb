require "optparse"
require "json"
require "droonga/client"

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
      targets.each do |target|
        run_test(target)
      end
      0 # FIXME
    end

    def run_test(target)
      client = Droonga::Client.new(tag: tag, port: port)
      envelope = JSON.parse(File.read(target))
      target_path = Pathname(target)
      actual_path   = target_path.sub_ext(".actual")
      expected_path = target_path.sub_ext(".expected")

      print "#{target}: "
      actual = client.connection.send_receive(envelope)
      unless actual
        puts "No response received"
        return
      end
      actual = normalize_result(actual)
      actual_json = actual.to_json
      File.write(actual_path, actual_json)

      if File.exist?(expected_path)
        expected = JSON.parse(File.read(expected_path))
        expected = normalize_result(expected)
        if expected == actual
          puts "PASS"
        else
          puts "FAIL"
          puts "Expected:"
          p expected
          puts "Actual:"
          p actual
        end
      else
        puts "No expectation specified"
      end
    end

    def normalize_result(result)
      result = result.dup
      result[1] = 0 # Mask start time
      result
    end
  end
end
