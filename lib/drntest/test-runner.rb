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
require "yajl"
require "tempfile"
require "pp"
require "fileutils"

require "drntest/path"
require "drntest/test-results"
require "drntest/test-executor"
require "drntest/json-loader"

module Drntest
  class TestRunner
    attr_reader :owner, :base_path, :target_path

    def initialize(owner, target)
      @owner = owner
      @base_path = Pathname(owner.base_path)
      @target_path = Pathname(target)
    end

    def run
      print "#{@target_path}: "
      prepare
      setup
      begin
        results = process_requests
      ensure
        teardown
      end
      results
    end

    def config_dir
      (@base_path + Path::CONFIG) + @owner.config
    end

    def config_file
      config_dir + "fluentd.conf"
    end

    def catalog_file
      config_dir + "catalog.json"
    end

    def port
      @port || @owner.port
    end

    def host
      @host || @owner.host
    end

    def tag
      @tag || @owner.tag
    end

    private
    def prepare
      if catalog_file.exist?
        catalog_json = JSON.parse(catalog_file.read, :symbolize_names => true)
        zone = catalog_json[:zones].first
        /\A([^:]+):(\d+)\/(.+)\z/ =~ zone
        @host = "localhost" # $1
        @port = $2.to_i
        @tag  = $3
      end
    end

    def setup
      return unless temporary_engine?

      FileUtils.rm_rf(temporary_dir)
      FileUtils.mkdir_p(temporary_dir)

      temporary_config = temporary_dir + "fluentd.conf"
      FileUtils.cp(config_file, temporary_config)
      temporary_catalog = temporary_dir + "catalog.json"
      FileUtils.cp(catalog_file, temporary_catalog)

      engine_command = [
        @owner.fluentd,
        "--config", temporary_config.to_s,
        *@owner.fluentd_options,
      ]
      engine_env = {
        "RUBYOPT" => nil,
        "BUNDLE_GEMFILE" => nil,
        "DROONGA_CATALOG" => temporary_catalog.to_s,
      }
      engine_options = {
        :chdir => temporary_dir.to_s,
        STDERR => STDOUT,
      }
      arguments = [engine_env, *engine_command]
      arguments << engine_options
      @engine_pid = Process.spawn(*arguments)

      wait_until_engine_ready
    end

    def teardown
      return unless temporary_engine?

      Process.kill(:TERM, @engine_pid)
      Process.wait(@engine_pid)

      FileUtils.rm_rf(temporary_dir.to_s)
    end

    def temporary_dir
      config_dir + "tmp"
    end

    def temporary_engine?
      @owner.fluentd && config_file.exist?
    end

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
          begin
            json = JSON.pretty_generate(result)
            file.puts(json)
          rescue JSON::GeneratorError => error
            p error
            p result
          end
        end
      end
    end

    def show_diff(expecteds, actuals)
      expected_pretty = format_results(expecteds)
      actual_pretty = format_results(actuals)

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

    def format_results(results)
      results.collect do |result|
        begin
          JSON.pretty_generate(result)
        rescue JSON::GeneratorError => error
          p error
          p result
        end
      end.join("\n")
    end

    def create_temporary_file(key, content)
      file = Tempfile.new("drntest-#{key}")
      file.write(content)
      file.close
      yield(file)
    end

    def engine_ready?
      begin
        socket = TCPSocket.new(@host, @port)
        socket.close
        true
      rescue Errno::ECONNREFUSED
        false
      end
    end

    def wait_until_engine_ready
      until engine_ready?
        sleep 1
      end
    end
  end
end
