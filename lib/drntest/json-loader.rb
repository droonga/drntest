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

require "yajl"

module Drntest
  class JSONLoader
    attr_reader :objects

    def initialize
      @parser = Yajl::Parser.new
      @objects = []
      @parser.on_parse_complete = lambda do |object|
        @objects << object
      end
    end

    def <<(data)
      @parser << data
    end

    def load(path)
      path.open do |file|
        data = ""
        file.each_line do |line|
          data << line
          begin
            self << line
          rescue Yajl::ParseError => error
            marker = "-" * 60
            puts("Failed to load JSONs file: #{path}")
            puts(marker)
            puts(data)
            puts(marker)
            puts(error)
            puts(marker)
            break
          end
        end
      end
      @objects
    end
  end
end
