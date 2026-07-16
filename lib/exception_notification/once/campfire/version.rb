# frozen_string_literal: true

module ExceptionNotification
  module Once
    module Campfire
      BASE_VERSION = "0.1.0"
      sha = `git -C #{__dir__} rev-parse --short HEAD 2>/dev/null`.strip
      VERSION = sha.empty? ? BASE_VERSION : "#{BASE_VERSION}.pre.git.#{sha}"
    end
  end
end
