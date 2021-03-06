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
    def initialize(config)
      @config = config
    end

    def start(target_path)
      setup(target_path)
    end

    def stop
      teardown
    end

    def catalog_file
      @config.engine_config_path + "catalog.json"
    end

    private
    def load_catalog_json(target_path)
      catalog_json = JSON.parse(catalog_file.read)
      @config.catalog_version = catalog_json["version"]
      case @config.catalog_version
      when 1
        extract_connection_info_catalog_v1(catalog_json)
      when 2
        custom_catalog_json_file = custom_catalog_json(target_path)
        if custom_catalog_json_file.exist?
          custom_catalog_json = JSON.parse(custom_catalog_json_file.read)
          merge_catalog_v2!(catalog_json, custom_catalog_json)
        end
        extract_connection_info_catalog_v2(catalog_json)
      end
      catalog_json
    end

    def custom_catalog_json(target_path)
      catalog_json_for_config = target_path.sub_ext(".catalog.json.#{@config.engine_config}")
      if catalog_json_for_config.exist?
        catalog_json_for_config
      else
        target_path.sub_ext(".catalog.json")
      end
    end

    def extract_connection_info_catalog_v1(catalog_json)
      zone = catalog_json["zones"].first
      /\A([^:]+):(\d+)\/(.+)\z/ =~ zone
      @config.host = $1
      @config.port = $2.to_i
      @config.tag  = $3
    end

    def merge_catalog_v2!(catalog_json, custom_catalog_json)
      base_datasets = catalog_json["datasets"]
      custom_catalog_json["datasets"].each do |name, dataset|
        base_dataset = base_datasets[name]
        if base_dataset
          base_dataset["fact"] = dataset["fact"] || base_dataset["fact"]
          base_dataset["schema"] = dataset["schema"] || base_dataset["schema"]
          replicas = dataset["replicas"] || []
          base_replicas = base_dataset["replicas"]
          replicas.each_with_index do |replica, i|
            base_replicas[i].merge!(replica)
          end
        else
          base_datasets[name] = dataset
        end
      end
    end

    def extract_connection_info_catalog_v2(catalog_json)
      datasets = catalog_json["datasets"]
      datasets.each do |name, dataset|
        dataset["replicas"].each do |replica|
          replica["slices"].each do |slice|
            if /\A([^:]+):(\d+)\/([^.]+)/ =~ slice["volume"]["address"]
              @config.host = $1
              @config.port = $2.to_i
              @config.tag  = $3
              return
            end
          end
        end
      end
    end

    def setup(target_path)
      setup_temporary_dir

      catalog_json = load_catalog_json(target_path)
      temporary_catalog = temporary_dir + "catalog.json"
      temporary_catalog.open("w") do |output|
        output.puts(JSON.pretty_generate(catalog_json))
      end

      ready_notify_in, ready_notify_out = IO.pipe
      command = [
        @config.droonga_engine,
        "--host", @config.host,
        "--port", @config.port.to_s,
        "--tag", @config.tag,
        "--base-dir", temporary_dir.to_s,
        "--ready-notify-fd", ready_notify_out.fileno.to_s,
        *@config.droonga_engine_options,
      ]
      env = {
      }
      options = {
        :err => :out,
        ready_notify_out => ready_notify_out,
      }
      arguments = [env, *command]
      arguments << options
      @pid = Process.spawn(*arguments)
      ready_notify_out.close
      wait_until_ready(ready_notify_in)
      ready_notify_in.close
    end

    def teardown
      Process.kill(:TERM, @pid)
      Process.wait(@pid)

      teardown_temporary_dir
    end

    def setup_temporary_dir
      tmpfs_candidates = [
        "/dev/shm",
        "/run/shm",
      ]
      tmpfs_candidates.each do |tmpfs_candidate|
        tmpfs = Pathname(tmpfs_candidate)
        if tmpfs.directory? and tmpfs.writable?
          FileUtils.rm_rf(temporary_base_dir)
          FileUtils.ln_s(tmpfs.to_s, temporary_base_dir.to_s)
          break
        end
      end
      FileUtils.rm_rf(temporary_dir)
      FileUtils.mkdir_p(temporary_dir)
    end

    def teardown_temporary_dir
      FileUtils.rm_rf(temporary_dir.to_s)
    end

    def temporary_base_dir
      @config.base_path + "tmp"
    end

    def temporary_dir
      temporary_base_dir + "drntest"
    end

    def wait_until_ready(ready_notify_in)
      ready_notify_in.gets
    end
  end
end
