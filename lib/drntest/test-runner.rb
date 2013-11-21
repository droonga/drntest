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
      result = TestResult.new(target_path.to_s)

      print "#{target_path}: "
      actual = execute_commands
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

    private
    def execute_commands
      client = Droonga::Client.new(tag: tester.tag, port: tester.port)
      request_envelope = load_request_envelope
      actual = client.connection.send(request_envelope, :response => :one)
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

    def actual_path
      target_path.sub_ext(".actual")
    end

    def remove_reject_file
      FileUtils.rm_rf(reject_path, :secure => true)
    end

    def output_reject_file(actual_result)
      output_actual_result(actual_result, reject_path)
    end

    def output_actual_file(actual_result)
      output_actual_result(actual_result, actual_path)
    end

    def output_actual_result(actual_result, output_path)
      puts "Saving received result as #{output_path}"
      actual_json = JSON.pretty_generate(actual_result)
      File.write(output_path, actual_json)
    end

    def show_diff(expected, actual)
      expected_pretty = JSON.pretty_generate(expected)
      actual_pretty = JSON.pretty_generate(actual)

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
