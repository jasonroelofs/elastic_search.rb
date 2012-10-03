module ElasticSearch
  class Utils
    def self.sanitize(hash)
      replacement_hash = Hash.new
      hash.each do |key,value|
        if value.is_a?(Hash)
          replacement_hash[escape_chars(key)] = sanitize(value)
        else
          replacement_hash[escape_chars(key)] = escape_chars(value)
        end
      end
      replacement_hash
    end

    def self.escape_chars(value)
      value.to_s.gsub(/([\\\/\"\'])/, '\\☣\1').gsub('\\☣', '\\')
    end
  end
end