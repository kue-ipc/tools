# frozen_string_literal: true

# = LogManager::Utils
# compatible with Ruby 2.0.0
#
# Copyright 2019 Kyoto University of Education
# The MIT License
# https://opensource.org/licenses/MIT

require 'yaml'

require_relative 'error'

module LogManager
  module Utils
    module_function

    # symbolize_names ruby >= 2.5
    def yaml_safe_load_symbolize(yaml)
      obj = YAML.safe_load(yaml, symbolize_names: true)
      return obj if avaiable_yaml_symbolize_names?

      safe_hash_symbolize(obj)
    end

    def yaml_load_symbolize(yaml)
      obj = YAML.load(yaml, symbolize_names: true)
      return obj if avaiable_yaml_symbolize_names?

      safe_hash_symbolize(obj)
    end

    def avaiable_yaml_symbolize_names?
      YAML.safe_load("---\na: 1\n", symbolize_names: true).key?(:a)
    end

    def safe_hash_symbolize(obj)
      case obj
      when true, false, nil
        obj
      when Numeric, String
        obj
      when Array
        obj.map { |e| safe_hash_symbolize(e) }
      when Hash
        array_to_hash(obj.map { |k, v| [k.intern, safe_hash_symbolize(v)] })
      else
        obj
        # raise Error, "Not a safe object: #{obj}"
      end
    end

    # Array#to_h ruby >= 2.1
    def array_to_hash(arr)
      return arr.to_h if arr.respond_to?(:to_h)

      arr.each_with_object({}) { |e, h| h[e[0]] = e[1] }
    end
  end
end
