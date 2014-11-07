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

module Drntest
  class ResponseNormalizer
    def initialize(request, response)
      @request = request
      @response = response
    end

    def normalize
      return @response if @response.nil?

      normalized_response = @response.dup
      normalize_droonga_message!(normalized_response)
      normalized_response
    end

    private
    def normalize_droonga_message!(droonga_message)
      normalize_droonga_message_envelope!(droonga_message)
      normalize_droonga_message_body!(droonga_message["body"])
    end

    def normalize_droonga_message_body!(body)
      if groonga_command?
        normalize_groonga_command_response!(body)
      elsif search_command?
        normalize_search_command_response!(body)
      end
    end

    GROONGA_COMMANDS = [
      "table_create",
      "table_remove",
      "table_list",
      "column_create",
      "column_remove",
      "column_rename",
      "column_list",
      "select",
      "delete",
    ]
    def groonga_command?
      GROONGA_COMMANDS.include?(@request["type"])
    end

    def search_command?
      @request["type"] == "search"
    end

    def normalize_droonga_message_envelope!(message)
      normalized_in_reply_to = "request-id"
      in_reply_to = message["inReplyTo"]
      message["inReplyTo"] = normalized_in_reply_to if in_reply_to

      errors = message["errors"]
      message["errors"] = normalize_errors(errors) if errors
    end

    def normalize_errors(errors)
      normalized_errors = {}
      error_details = errors.values
      errors.keys.each_with_index do |source, index|
        normalized_errors["sources#{index}"] = error_details[index]
      end
      normalized_errors
    end

    def normalize_groonga_command_response!(response)
      normalize_groonga_command_header!(response[0])
      normalize_groonga_command_body!(response[1..-1])
    end

    def normalized_start_time
      0.0
    end

    def normalized_elapsed
      0.0
    end

    def normalize_groonga_command_header!(header)
      return unless header.is_a?(Array)
      header[1] = normalized_start_time if valid_start_time?(header[1])
      header[2] = normalized_elapsed if valid_elapsed?(header[2])
    end

    def normalize_groonga_command_body!(body)
      return if not body.is_a?(Array) or body.empty?

      case @request["type"]
      when "table_list"
        normalize_groonga_table_list_command_body!(body)
      when "column_list"
        normalize_groonga_column_list_command_body!(body)
      end
    end

    TABLE_PATH_COLUMN_INDEX = 2
    def normalize_groonga_table_list_command_body!(body)
      tables = body[0][1..-1]
      return unless tables.is_a?(Array)
      tables.each do |table|
        if table[TABLE_PATH_COLUMN_INDEX].is_a?(String)
          table[TABLE_PATH_COLUMN_INDEX] = "/path/to/table"
        end
      end
    end

    COLUMN_PATH_COLUMN_INDEX = 2
    def normalize_groonga_column_list_command_body!(body)
      columns = body[0][1..-1]
      return unless columns.is_a?(Array)
      columns.each do |column|
        value = column[COLUMN_PATH_COLUMN_INDEX]
        if value.is_a?(String) and not value.empty?
          column[COLUMN_PATH_COLUMN_INDEX] = "/path/to/column"
        end
      end
    end

    def normalize_search_command_response!(response)
      response.each do |query_name, result|
        if valid_elapsed?(result["elapsedTime"])
          result["elapsedTime"] = normalized_elapsed
        end
      end
    end

    def valid_start_time?(start_time)
      start_time.is_a?(Float) and start_time > 0
    end

    def valid_elapsed?(elapsed)
      elapsed.is_a?(Float) and elapsed > 0
    end
  end
end
