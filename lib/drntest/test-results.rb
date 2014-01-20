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

    def initialize(name)
      @name = name
      @actuals = []
      @expecteds = []
      @errors = []
    end

    def status
      return :error unless @errors.empty?
      return :no_response if @actuals.empty?
      return :not_checked if @expecteds.empty?

      if @actuals == @expecteds
        :success
      else
        :failure
      end
    end
  end
end
