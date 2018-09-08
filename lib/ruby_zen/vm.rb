module RubyZen
  class VM
    def initialize(scope: nil, logger:)
      @callbacks = {}

      @logger = logger

      @scope = [scope]
      @stack = RubyZen::DoubleStack.new
    end

    def run(iseq)
      @logger.info("Indexing iseq `#{iseq.label}`, type: `#{iseq.type}`, path: `#{iseq.path}`")

      iseq.instructions.each_with_index do |instruction, index|
        handler_name = "handle_#{instruction.name}".to_sym
        if respond_to?(handler_name, true)
          @logger.debug("Running instruction `#{instruction.name}` with params #{instruction.operands}")
          send(handler_name, instruction)
        else
          @logger.debug("Skip instruction `#{instruction.name}`")
        end
      end
    end

    def on(instruction_name, *filters, &callback)
      @callbacks[instruction_name] ||= []
      @callbacks[instruction_name] << {
        proc: callback,
        filters: filters
      }
    end

    def dispatch_callback(instruction_name, filter: nil, args: [])
      callback =
        if !@callbacks[instruction_name]
          nil
        elsif filter.nil?
          @callbacks[instruction_name].first
        else
          @callbacks[instruction_name].find do |p|
            p[:filters].include?(filter)
          end
        end
      callback[:proc].call(*args) if callback
    end

    private

    def handle_putspecialobject(instruction)
      case instruction.operands[0]
      when 1
        @stack.push(@scope.first)
      when 2
        @stack.push(nil)
      when 3
        @stack.push(@scope.last)
      else
        @stack.push(nil)
      end
    end

    def handle_putobject(instruction)
      @stack.push(instruction.operands[0])
    end

    def handle_putiseq(instruction)
      @stack.push(instruction.operands[0])
    end

    def handle_putnil(_instruction)
      @stack.push(nil)
    end

    def handle_putself(_instruction)
      @stack.push(@scope.last)
    end

    def handle_pop(_instruction)
      @stack.pop
    end

    def handle_getconstant(instruction)
      name = instruction.operands[0]
      klass = @stack.pop
      constant_value = dispatch_callback(
        instruction.name, args: [name, klass]
      )
      @stack.push(constant_value)
    end

    def handle_defineclass(instruction)
      class_name, class_body, flags = instruction.operands
      superclass = @stack.pop
      cbase = @stack.pop

      class_value = dispatch_callback(
        instruction.name,
        args: [class_name, class_body, superclass, cbase, flags]
      )

      @stack.new_frame
      @stack.push(class_value)
      @scope.push(class_value)
      run(class_body)
    end

    def handle_opt_send_without_block(instruction)
      call_info, _call_cache = instruction.operands
      case call_info.mid
      when :"core#define_method", :define_method
        method_body = @stack.pop
        method_name = @stack.pop

        method_object = dispatch_callback(
          instruction.name,
          filter: 'define_method',
          args: [@scope.last, method_name, method_body]
        )

        if method_body.is_a?(YarvGenerator::Iseq)
          @stack.new_frame
          @stack.push(method_object)
          @scope.push(@scope)
          run(method_body)
        end

        @stack.push(method_object)
      when :"core#define_singleton_method", :define_singleton_method
        method_body = @stack.pop
        method_name = @stack.pop
        receiver = @stack.pop

        method_object = dispatch_callback(
          instruction.name,
          filter: 'define_singleton_method',
          args: [receiver, method_name, method_body]
        )

        if method_body.is_a?(YarvGenerator::Iseq)
          @stack.new_frame
          @stack.push(method_object)
          @scope.push(@scope)
          run(method_body)
        end

        @stack.push(method_object)
      when :instance_method
        method_name = @stack.pop
        receiver = @stack.pop

        method_object = dispatch_callback(
          instruction.name,
          filter: 'instance_method',
          args: [receiver, method_name]
        )
        @stack.push(method_object)
      when :method
        method_name = @stack.pop
        receiver = @stack.pop

        method_object = dispatch_callback(
          instruction.name,
          filter: 'method',
          args: [receiver, method_name]
        )
        @stack.push(method_object)
      when :include
        module_definition = @stack.pop
        receiver = @stack.pop

        dispatch_callback(
          instruction.name,
          filter: 'include',
          args: [receiver, module_definition]
        )
      when :extend
        module_definition = @stack.pop
        receiver = @stack.pop

        dispatch_callback(
          instruction.name,
          filter: 'extend',
          args: [receiver, module_definition]
        )
      when :prepend
        module_definition = @stack.pop
        receiver = @stack.pop

        dispatch_callback(
          instruction.name,
          filter: 'prepend',
          args: [receiver, module_definition]
        )
      else
        @logger.debug("Method #{call_info.mid} not handled.")
      end
    end

    def handle_send(instruction)
      call_info, _call_cache, block_iseq = instruction.operands
      case call_info.mid
      when :define_method
        method_name = @stack.pop
        receiver = @stack.pop

        method_object = dispatch_callback(
          instruction.name,
          filter: 'define_method',
          args: [receiver, method_name, block_iseq]
        )

        @stack.new_frame
        @stack.push(method_object)
        @scope.push(@scope.last)
        run(block_iseq)

        @stack.push(method_object)
      when :define_singleton_method
        method_name = @stack.pop
        receiver = @stack.pop

        method_object = dispatch_callback(
          instruction.name,
          filter: 'define_singleton_method',
          args: [receiver, method_name, block_iseq]
        )

        @stack.new_frame
        @stack.push(method_object)
        @scope.push(@scope.last)
        run(block_iseq)

        @stack.push(method_object)
      else
        @logger.debug("Method #{call_info.mid} not handled.")
      end
    end

    def handle_leave(_instruction)
      @stack.leave_frame
      @scope.pop
    end

    def handle_getinlinecache(_instruction)
      @stack.push(nil)
    end

    def handle_setinlinecache(_instruction)
      val = @stack.pop
      @stack.push(val)
    end
  end
end
