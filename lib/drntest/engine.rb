# Copyright (C) 2014  Droonga Project
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
require "pathname"
require "fileutils"

module Drntest
  class Engine
    attr_reader :config_dir, :fluentd, :fluentd_options

    def initialize(params)
      @config_dir = Pathname(params[:config_dir])
      @default_port = params[:default_port]
      @default_host = params[:default_host]
      @default_tag = params[:default_tag]
      @fluentd = params[:fluentd]
      @fluentd_options = params[:fluentd_options]
    end

    def start
      prepare
      setup
    end

    def stop
      teardown
    end

    def config_file
      config_dir + "fluentd.conf"
    end

    def catalog_file
      config_dir + "catalog.json"
    end

    def port
      @port || @default_port
    end

    def host
      @host || @default_host
    end

    def tag
      @tag || @default_tag
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
      return unless temporary?

      setup_temporary_dir

      temporary_config = temporary_dir + "fluentd.conf"
      FileUtils.cp(config_file, temporary_config)
      temporary_catalog = temporary_dir + "catalog.json"
      FileUtils.cp(catalog_file, temporary_catalog)

      command = [
        @fluentd,
        "--config", temporary_config.to_s,
        *@fluentd_options,
      ]
      env = {
        "DROONGA_CATALOG" => temporary_catalog.to_s,
      }
      options = {
        :chdir => temporary_dir.to_s,
        STDERR => STDOUT,
      }
      arguments = [env, *command]
      arguments << options
      @pid = Process.spawn(*arguments)

      wait_until_ready
    end

    def teardown
      return unless temporary?

      Process.kill(:TERM, @pid)
      Process.wait(@pid)

      teardown_temporary_dir
    end

    def setup_temporary_dir
      tmpfs = Pathname("/run/shm")
      if tmpfs.directory? and tmpfs.writable?
        FileUtils.rm_rf(temporary_base_dir)
        FileUtils.ln_s(tmpfs.to_s, temporary_base_dir.to_s)
      end
      FileUtils.rm_rf(temporary_dir)
      FileUtils.mkdir_p(temporary_dir)
    end

    def teardown_temporary_dir
      FileUtils.rm_rf(temporary_dir.to_s)
    end

    def temporary_base_dir
      @base_path + "tmp"
    end

    def temporary_dir
      temporary_base_dir + "drntest"
    end

    def temporary?
      @fluentd && config_file.exist?
    end

    def ready?
      begin
        socket = TCPSocket.new(@host, @port)
        socket.close
        true
      rescue Errno::ECONNREFUSED
        false
      end
    end

    def wait_until_ready
      until ready?
        sleep 1
      end
    end
  end
end
