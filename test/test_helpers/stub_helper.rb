module StubHelper
  # Replace `method_name` on `receiver` for the duration of the block, then
  # restore the original. Works on classes, modules, and instances. Avoids the
  # dropped `Minitest::Mock#stub` from minitest 6+.
  #
  # Usage:
  #   stub_method(Tiktok::Resources::Authorization, :exchange_code, ->(code) { fake_pair }) do
  #     post tiktok_callback_path, params: {...}
  #   end
  def stub_method(receiver, method_name, replacement)
    metaclass = receiver.singleton_class
    original_was_defined = receiver.singleton_methods(false).include?(method_name) ||
                           metaclass.method_defined?(method_name) ||
                           metaclass.private_method_defined?(method_name)
    original = receiver.method(method_name) if original_was_defined

    metaclass.define_method(method_name) do |*args, **kwargs, &block|
      if replacement.respond_to?(:call)
        if kwargs.empty?
          replacement.call(*args, &block)
        else
          replacement.call(*args, **kwargs, &block)
        end
      else
        replacement
      end
    end

    yield
  ensure
    if original
      metaclass.define_method(method_name, original)
    else
      metaclass.remove_method(method_name) if metaclass.method_defined?(method_name)
    end
  end
end
