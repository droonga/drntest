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
require "drntest/test-results"
require "drntest/executor"
require "fileutils"

module Drntest
  class TestRunner
    attr_reader :owner, :target_path

    def initialize(owner, target)
      @owner = owner
      @target_path = Pathname(target)
      @options = load_options
    end

    def run
      print "#{@target_path}: "
      prepare
      setup
      results = process_requests
      teardown
      results
    end

    def config_dir
      return nil unless @config
      @config.parent
    end

    def config
      @config
    end

    def config=(path)
      path = Pathname(path).expand_path(@target_path.parent)
      path += "fluentd.conf" if path.directory?
      @config = path
    end

    def catalog
      path = @catalog
      path ||= config_dir + "catalog.json" if config_dir
      if path
        Pathname(path).expand_path(@target_path.parent)
      else
        nil
      end
    end

    def port
      @port || @options[:port] || @owner.port
    end

    def host
      @host || @options[:host] || @owner.host
    end

    def tag
      @tag || @options[:tag] || @owner.tag
    end

    private
    def prepare
      self.config = @owner.config if @owner.config
      self.config = @options[:config] if @options[:config]

      @catalog = @owner.catalog if @owner.catalog
      @catalog = @options[:catalog] if @options[:catalog]

      if catalog && catalog.exist?
        catalog_json = JSON.parse(catalog.read, :symbolize_names => true)
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
      FileUtils.cp(config, temporary_config)
      temporary_catalog = temporary_dir + "catalog.json"
      FileUtils.cp(catalog, temporary_catalog)

      engine_command = "#{@owner.fluentd} --config #{temporary_config}"
      engine_env = {
        "DROONGA_CATALOG" => temporary_catalog.to_s,
      }
      engine_options = {
        :chdir => temporary_dir.to_s,
        STDERR => STDOUT,
      }
      @engine_pid = Process.spawn(engine_env, engine_command, engine_options)
    end

    def teardown
      return unless temporary_engine?

      Process.kill(:KILL, @engine_pid)
      FileUtils.rm_rf(temporary_dir.to_s)
    end

    def temporary_dir
      config_dir + "tmp"
    end

    def temporary_engine?
      @owner.fluentd && config && config.exist?
    end

    def process_requests
      results = TestResults.new(@target_path)

      load_request_envelopes.each do |request|
        executor = Executor.new(self, request)
        results.actuals << executor.execute
      end
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

    def load_options
      options = {}
      @target_path.read.each_line do |line|
        next unless /\A\#\@([^\s]+)\s+(.+)\n?\z/ =~ line
        options[$1.to_sym] = $2
      end
      options
    end

    def load_request_envelopes
      load_jsons(@target_path)
    end

    def load_expected_responses
      load_jsons(expected_path)
    end

    def load_jsons(pathname, options={})
      parser = Yajl::Parser.new(options)
      json_objects = []
      parser.on_parse_complete = Proc.new do |json_object|
        json_objects << json_object
      end
      pathname.read.each_line do |line|
        unless line[0] == "#"
          parser << line 
        end
      end
      json_objects
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
          json = JSON.pretty_generate(result)
          file.puts(json)
        end
      end
    end

    def show_diff(expecteds, actuals)
      expected_pretty = expecteds.collect do |expected|
        JSON.pretty_generate(expected)
      end.join("\n")
      actual_pretty = actuals.collect do |actual|
        JSON.pretty_generate(actual)
      end.join("\n")

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
  end
end
