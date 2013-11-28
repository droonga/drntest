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
  class TestSuitesResult
    attr_accessor :test_results

    def initialize
      @test_results = []
    end

    def summary
      status_counts = Hash.new(0)
      test_results.each do |result|
        status_counts[result.status] += 1
      end
      status_counts
    end

    def success?
      summary[:failure].zero? && summary[:no_response].zero?
    end
  end
end
