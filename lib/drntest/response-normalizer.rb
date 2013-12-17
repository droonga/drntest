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

module Drntest
  class ResponseNormalizer
    def initialize(request, response)
      @request = request
      @response = response
    end

    def normalize
      return @response if @response.nil?

      normalized_response = @response.dup
      normalize_envelope!(normalized_response)
      normalize_body!(normalized_response)
      normalized_response
    end

    private
    def normalize_envelope!(normalized_response)
      normalized_start_time = 0
      normalized_response[1] = normalized_start_time
    end

    def normalize_body!(normalized_response)
      return unless groonga_command?
      begin
        normalize_groonga_command_response!(normalized_response[2])
      rescue StandardError => error
        p error
      end
    end

    GROONGA_COMMANDS = [
      "table_create",
      "column_create",
      "select",
    ]
    def groonga_command?
      GROONGA_COMMANDS.include?(@request["type"])
    end

    def normalize_groonga_command_response!(response)
      normalize_groonga_command_header!(response["body"][0])
    end

    def normalize_groonga_command_header!(header)
      normalized_start_time = 0.0
      normalized_elapsed = 0.0
      header[1] = normalized_start_time if valid_start_time?(header[1])
      header[2] = normalized_elapsed if valid_elapsed?(header[2])
    end

    def valid_start_time?(start_time)
      start_time.is_a?(Float) and start_time > 0
    end

    def valid_elapsed?(elapsed)
      elapsed.is_a?(Float) and elapsed > 0
    end
  end
end
