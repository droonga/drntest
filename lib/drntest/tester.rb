require "optparse"
require "json"
require "droonga/client"
require "tempfile"
require "pp"

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
      expected_path = target_path.sub_ext(".expected")

      print "#{target}: "
      actual = client.connection.send_receive(envelope)
      unless actual
        puts "No response received"
        return
      end
      actual = normalize_result(actual)
      actual_json = actual.to_json

      if File.exist?(expected_path)
        expected = JSON.parse(File.read(expected_path))
        expected = normalize_result(expected)
        if expected == actual
          puts "PASS"
        else
          puts "FAIL"
          show_diff(expected, actual)
          reject_path = target_path.sub_ext(".reject")
          puts "Saving received result as #{reject_path}"
          File.write(reject_path, actual_json)
        end
      else
        actual_path = target_path.sub_ext(".actual")
        puts "No expectation specified. Saving result as #{actual_path}."
        File.write(actual_path, actual_json)
      end
    end

    def show_diff(expected, actual)
      expected_pretty = expected.pretty_inspect
      actual_pretty = actual.pretty_inspect

      create_temporary_file("expected", expected_pretty) do |expected_file|
        create_temporary_file("actual", actual_pretty) do |actual_file|
          diff_options = [
            "-u",
            "--label", "(expected)", expected_file.path,
            "--label", "(actual)", actual_file.path
          ]
          system("diff", *diff_options)
        end
      end
    end

    def create_temporary_file(key, content)
      file = Tempfile.new("drntest-#{key}")
      file.write(content)
      file.close
      yield(file)
    end

    def normalize_result(result)
      result = result.dup
      result[1] = 0 # Mask start time
      result
    end
  end
end
