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
  class Directive
  end

  class UnknownDirective < Directive
    attr_reader :type, :options

    def initialize(type, options)
      @type = type
      @options = options
    end
  end

  class IncludeDirective < Directive
    attr_reader :path

    def initialize(path)
      @path = path
    end
  end

  class EnableLoggingDirective < Directive
  end

  class DisableLoggingDirective < Directive
  end

  class OmitDirective < Directive
    attr_reader :message

    def initialize(message)
      @message = message
    end
  end

  class RequireCatalogVersionDirective < Directive
    attr_reader :version

    def initialize(version)
      @version = version
    end
  end

  class EnableCompletionDirective < Directive
  end

  class DisableCompletionDirective < Directive
  end

  class EnableValidationDirective < Directive
  end

  class DisableValidationDirective < Directive
  end

  class SubscribeUntil < Directive
    attr_reader :timeout_seconds

    DEFAULT_TIMEOUT_SECONDS = 1

    ONE_MINUTE_IN_SECONDS = 60
    ONE_HOUR_IN_SECONDS = ONE_MINUTE_IN_SECONDS * 60

    def initialize(timeout)
      if timeout =~ /\A(\d+\.?|\.\d+|\d+\.\d+)s(?:ec(?:onds?)?)?\z/
        @timeout_seconds = $1.to_f
      elsif timeout =~ /\A(\d+\.?|\.\d+|\d+\.\d+)m(?:inutes?)?\z/
        @timeout_seconds = $1.to_f * ONE_MINUTE_IN_SECONDS
      elsif timeout =~ /\A(\d+\.?|\.\d+|\d+\.\d+)h(?:ours?)?\z/
        @timeout_seconds = $1.to_f * ONE_HOUR_IN_SECONDS
      else
        @timeout_seconds = DEFAULT_TIMEOUT_SECONDS
      end
    end
  end
end
