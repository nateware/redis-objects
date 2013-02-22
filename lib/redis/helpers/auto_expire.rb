class Redis
  module Helpers
    # These are auto-expires commands that all types share (rename, etc)
    module AutoExpire

      def auto_exprire
        self.send(:expire,   options[:expires])      if options[:expires]
      end

      def init_auto_exprire
        if options[:expires] && !self.setter_methods.empty?
          self.setter_methods.each do |method|
            
            self.class.send :define_method, "#{method}_with_expires" do |*args|
              return_value = self.send "#{method}_without_expires".to_sym, *args
              auto_exprire
              return_value
            end

            self.class.send :alias_method, "#{method}_without_expires".to_sym, method
            self.class.send :alias_method, method, "#{method}_with_expires".to_sym
          end
        end
      end

    end
  end
end