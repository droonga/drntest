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
  class TestResults
    attr_accessor :name, :actuals, :expecteds, :errors
    attr_reader :omit_message

    def initialize(name)
      @name = name
      @actuals = []
      @expecteds = []
      @errors = []
      @omitted = false
      @omit_message = nil
    end

    def status
      return :omitted if @omitted
      return :error unless @errors.empty?
      return :no_response if @actuals.empty?
      return :not_checked if @expecteds.empty?

      if @actuals == @expecteds
        :success
      else
        :failure
      end
    end

    def omit(message)
      @omitted = true
      @omit_message = message
    end
  end
end
