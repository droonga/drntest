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

require "drntest/path"
require "drntest/test-results"
require "drntest/test-executor"
require "drntest/json-loader"
require "drntest/engine"

module Drntest
  class TestRunner
    attr_reader :owner, :base_path, :target_path

    def initialize(owner, target)
      @owner = owner
      @base_path = Pathname(owner.base_path)
      @target_path = Pathname(target)
      @engine = Engine.new(:base_path => @base_path,
                           :config_dir => config_dir,
                           :default_port => @owner.port,
                           :default_host => @owner.host,
                           :default_tag => @owner.tag,
                           :fluentd => @owner.fluentd,
                           :fluentd_options => @owner.fluentd_options)
    end

    def run
      print "#{@target_path}: "
      @engine.start
      begin
        results = process_requests
      ensure
        @engine.stop
      end
      results
    end

    def config_dir
      (@base_path + Path::CONFIG) + @owner.config
    end

    private
    def process_requests
      results = TestResults.new(@target_path)

      executor = TestExecutor.new(self, @target_path)
      results.actuals = executor.execute
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
        output_reject_file(results.actuals)
        show_diff(results.expecteds, results.actuals)
      when :not_checked
        puts "NOT CHECKED"
        output_actual_file(results.actuals)
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

    def output_reject_file(results)
      output_results(results, reject_path)
    end

    def output_actual_file(results)
      output_results(results, actual_path)
    end

    def output_results(results, output_path)
      puts "Saving received results as #{output_path}"
      File.open(output_path, "w") do |file|
        results.each do |result|
          file.puts(format_result(result))
        end
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
  end
end
