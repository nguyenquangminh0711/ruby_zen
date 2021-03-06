module RubyZen::Interpreters
  class PopInterpreter < Base
    interpret 'pop'

    def call(vm, _instruction)
      vm.environment.pop
    end
  end

  class PutObjectInterpreter < Base
    interpret 'putobject'

    def call(vm, instruction)
      vm.environment.push(instruction.operands[0])
    end
  end

  class PutIseqtInterpreter < Base
    interpret 'putiseq'

    def call(vm, instruction)
      vm.environment.push(instruction.operands[0])
    end
  end

  class PutNilInterpreter < Base
    interpret 'putnil'

    def call(vm, instruction)
      vm.environment.push(nil)
    end
  end

  class PutSelfInterpreter < Base
    interpret 'putself'

    def call(vm, instruction)
      vm.environment.push(vm.environment.self_pointer)
    end
  end

  class PutSpecialObjectInterpreter < Base
    interpret 'putspecialobject'

    def call(vm, instruction)
      case instruction.operands[0]
      when 1
        vm.environment.push(vm.environment.root_scope)
      when 2
        vm.environment.push(nil)
      when 3
        vm.environment.push(vm.environment.scope)
      else
        vm.environment.push(nil)
      end
    end
  end
end
