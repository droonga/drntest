require "json"
require "droonga/client"
require "tempfile"
require "pp"
require "drntest/test-result"
require "fileutils"

module Drntest
  class TestRunner
    attr_reader :tester, :target_path

    def initialize(tester, target)
      @tester = tester
      @target_path = Pathname(target)
    end

    def run
      client = Droonga::Client.new(tag: tester.tag, port: tester.port)
      result = TestResult.new(target_path.to_s)

      print "#{target_path}: "
      request_envelope = load_request_envelope
      actual = client.connection.send_receive(request_envelope)
      if actual
        actual = normalize_result(actual)
        result.actual = actual
      end

      if expected_exist?
        result.expected = load_expected
      end

      case result.status
      when :success
        puts "SUCCESS"
        remove_reject_file
      when :no_response
        puts "NO RESPONSE"
      when :failure
        puts "FAILURE"
        output_reject_file(actual)
        show_diff(result.expected, result.actual)
      when :not_checked
        puts "NOT CHECKED"
        output_actual_file(actual)
      end

      result
    end

    def load_request_envelope
      JSON.parse(target_path.read)
    end

    def load_expected
      expected = JSON.parse(expected_path.read)
      normalize_result(expected)
    end

    def expected_exist?
      expected_path.exist?
    end

    def expected_path
      target_path.sub_ext(".expected")
    end

    def reject_path
      target_path.sub_ext(".reject")
    end

    def remove_reject_file
      FileUtils.rm_rf(reject_path, :secure => true)
    end

    def output_reject_file(actual_result)
      output_actual_result(actual_result, ".reject")
    end

    def output_actual_file(actual_result)
      output_actual_result(actual_result, ".actual")
    end

    def output_actual_result(actual_result, suffix)
      output_path = target_path.sub_ext(suffix)
      puts "Saving received result as #{output_path}"
      actual_json = JSON.pretty_generate(actual_result)
      File.write(output_path, actual_json)
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
