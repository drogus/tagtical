# TODO: remove this monkeypatch
module ActiveRecord
  module Associations
    class Association
      def target=(target)
        if target.respond_to?(:on_set_target)
          target = target.on_set_target(owner)
        end
        @target = target
        loaded!
      end
    end
  end
end

