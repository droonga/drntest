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
  end
end
