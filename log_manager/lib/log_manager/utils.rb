require 'yaml'

require_relative 'error'
require_relative 'utils/disk_stat'
require_relative 'utils/file_stat'

module LogManager
  module Utils
    module_function def disk_stat(path)
      LogManager::Utils::DiskStat.new(path)
    end

    module_function def file_stat(path)
      LogManager::Utils::FileStat.new(path)
    end

    module_function def hash_symbolize_names(obj)
      case obj
      when Array
        obj.map { |e| hash_symbolize_names(e) }
      when Hash
        # Array#to_h {block} is Ruby >= 2.6
        obj.map { |k, v| [k.intern, hash_symbolize_names(v)] }.to_h
      else
        obj
      end
    end

    module_function def hash_stringify_names(obj)
      case obj
      when Array
        obj.map { |e| hash_stringify_names(e) }
      when Hash
        # Array#to_h {block} is Ruby >= 2.6
        obj.map { |k, v| [k.to_s, hash_stringify_names(v)] }.to_h
      else
        obj
      end
    end

    module_function def hash_deep_merge(a_hash, b_bash, &block)
      a_hash.merge(b_bash) do |key, a_val, b_val|
        if a_val.is_a?(Hash) && b_val.is_a?(Hash)
          hash_deep_merge(a_val, b_val, &block)
        elsif block_given?
          block.call(key, a_val, b_val)
        else
          b_val
        end
      end
    end
  end
end
