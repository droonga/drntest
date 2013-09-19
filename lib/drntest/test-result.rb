module Drntest
  class TestResult
    attr_accessor :name, :expected, :actual

    def initialize(name)
      @name = name
      @expected = nil
      @actual = nil
    end

    def status
      if @actual
        if @expected
          if @actual == @expected
            :success
          else
            :failure
          end
        else
          :not_checked
        end
      else
        :no_response
      end
    end
  end
end
