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
  class ResponsesNormalizer
    def initialize(request, responses)
      @request = request
      @responses = responses
    end

    def normalize
      return @responses unless dump_command?

      normalize_dump_responses
    end

    private
    def dump_command?
      @request["type"] == "dump"
    end

    DUMP_TYPE_ORDER = [
      "dump.start",
      "dump.result",
      "dump.table",
      "dump.column",
      "dump.record",
      "dump.end",
    ]
    def normalize_dump_responses
      @responses.sort_by do |response|
        if response["error"] and response["response"]
          response = response["response"]
        end
        type = response["type"]
        type_order = DUMP_TYPE_ORDER.index(type) || -1
        body = response["body"]
        case type
        when "dump.table"
          body_order = body["name"]
        when "dump.column"
          body_order = "#{body['table']}.#{body['name']}"
        when "dump.record"
          body_order = "#{body['table']}.#{body['key']}"
        else
          body_order = ""
        end
        [type_order, body_order]
      end
    end
  end
end
