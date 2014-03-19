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

module Drntest
  class Configuration
    attr_accessor :port, :host, :tag
    attr_accessor :base_path, :engine_config
    attr_accessor :fluentd, :fluentd_options
    attr_accessor :catalog_version

    def initialize
      @port            = 24224
      @host            = "localhost"
      @tag             = "droonga"
      @base_path       = Pathname(Dir.pwd)
      @engine_config   = "default"
      @fluentd         = "fluentd"
      @fluentd_options = []
      @catalog_version = "2"
    end

    def suite_path
      @base_path + "suite"
    end

    def engine_config_path
      @base_path + "config" + @engine_config
    end
  end
end
