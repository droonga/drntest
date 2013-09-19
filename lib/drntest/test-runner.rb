module Drntest
  class TestRunner
    attr_reader :tester, :target_path

    def initialize(tester, target)
      @tester = tester
      @target_path = Pathname(target)
    end

    def run
      client = Droonga::Client.new(tag: tester.tag, port: tester.port)
      envelope = JSON.parse(target_path.read)
      expected_path = target_path.sub_ext(".expected")

      print "#{target_path}: "
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
          output_reject_file(actual)
        end
      else
        output_actual_file(actual)
      end
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
      actual_json = actual_result.to_json
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
