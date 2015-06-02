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

require "json"
require "yajl"
require "tempfile"
require "pp"
require "fileutils"

require "drntest/test-results"
require "drntest/test-executor"
require "drntest/json-loader"
require "drntest/engine"
require "drntest/input-error"

module Drntest
  class EngineStalled < StandardError
  end

  class TestRunner
    def initialize(config, target)
      @config = config
      @target_path = Pathname(target).expand_path
      @engine = Engine.new(@config)
    end

    def run
      relative_target_path = @target_path.relative_path_from(@config.suite_path)
      print "#{relative_target_path}: "
      @engine.start(@target_path)
      begin
        results = process_requests
        raise EngineStalled.new if results.status == :no_response
      ensure
        @engine.stop
      end
      results
    end

    private
    def process_requests
      results = TestResults.new(@target_path)

      executor = TestExecutor.new(@config, @target_path, results)
      executor.execute
      if expected_exist?
        results.expecteds = load_expected_responses
      end

      case results.status
      when :success
        puts "SUCCESS"
        remove_reject_file
      when :no_response
        puts "NO RESPONSE"
      when :failure
        puts "FAILURE"
        save_reject_file(results.actuals)
        show_diff(results.expecteds, results.actuals)
      when :not_checked
        puts "NOT CHECKED"
        save_actual_file(results.actuals)
        output_results(results.actuals, $stdout)
      when :error
        puts "ERROR"
        output_errors(results.errors)
      when :omitted
        puts "OMITTED: #{results.omit_message}"
      end

      results
    end

    def load_expected_responses
      load_jsons(expected_path)
    end

    def load_jsons(path)
      loader = JSONLoader.new
      loader.load(path)
    end

    def expected_exist?
      expected_path.exist?
    end

    def expected_path
      expected_for_config = @target_path.sub_ext(".expected.#{@config.engine_config}")
      if expected_for_config.exist?
        return expected_for_config
      end
      @target_path.sub_ext(".expected")
    end

    def reject_path
      @target_path.sub_ext(".reject")
    end

    def actual_path
      @target_path.sub_ext(".actual")
    end

    def remove_reject_file
      FileUtils.rm_rf(reject_path, :secure => true)
    end

    def save_reject_file(results)
      save_results(results, reject_path)
    end

    def save_actual_file(results)
      save_results(results, actual_path)
    end

    def save_results(results, output_path)
      puts "Saving received results as #{output_path}"
      File.open(output_path, "w") do |file|
        output_results(results, file)
      end
    end

    def output_results(results, output)
      results.each do |result|
        output.puts(format_result(result))
      end
    end

    def show_diff(expecteds, actuals)
      formatted_expected = format_results(expecteds)
      formatted_actual = format_results(actuals)

      create_temporary_file("expected", formatted_expected) do |expected_file|
        create_temporary_file("actual", formatted_actual) do |actual_file|
          diff_options = [
            "-u",
            "--label", "(expected)", expected_file.path,
            "--label", "(actual)", actual_file.path
          ]
          system("diff", *diff_options)
        end
      end
    end

    def format_results(results)
      formatted_results = ""
      results.each do |result|
        formatted_results << format_result(result)
        formatted_results << "\n"
      end
      formatted_results
    end

    def format_result(result)
      return "" if result.nil?
      begin
        JSON.pretty_generate(result)
      rescue JSON::GeneratorError
        result.inspect
      end
    end

    def create_temporary_file(key, content)
      file = Tempfile.new("drntest-#{key}")
      file.write(content)
      file.close
      yield(file)
    end

    def output_errors(errors)
      return if errors.empty?
      n_digits = (Math.log10(errors.size) + 1).ceil
      mark = "=" * 78
      errors.each_with_index do |error, i|
        puts(mark)
        formatted_nth = "%*d)" % [n_digits, i + 1]
        if error.is_a?(InputError)
          puts("#{formatted_nth} #{error.message}")
        else
          puts("#{formatted_nth} #{error.message} (#{error.class})")
          puts(error.backtrace)
        end
        puts(mark)
      end
    end
  end
end
