require 'test_helper_no_rails'
require 'elastic_search/utils'

describe ElasticSearch::Utils do
  describe "#sanitize" do
    before do
      @hash = { :level_1_a => "quote -> \" apos -> '", 
        :level_1_b => {
          :level_2_a => {
            "quote -> \" apos -> '" => "fslash -> / bslash -> \\",
            :level_3_a => "apos -> ' fslash -> /"
          }
        },
        :level_1_c => {
          "apos -> ' fslash -> /" => "bslash -> \\ quote -> \"",
          "fslash -> / bslash -> \\" => "apos -> ' bslash -> \\"
        }
      }
    end

    it "escapes quotes, apostrophes, slashes & backslashes in values" do
      e1 = ElasticSearch::Utils::sanitize(@hash)

      e1["level_1_b"]["level_2_a"]["level_3_a"].must_equal "apos -> \\' fslash -> \\/"
      e1["level_1_a"].must_equal "quote -> \\\" apos -> \\'"
    end

    it "escapes quotes, apostrophes, slashes & backslashes in keys" do
      e2 = ElasticSearch::Utils::sanitize(@hash)

      e2["level_1_b"]["level_2_a"].keys.must_include "quote -> \\\" apos -> \\'"
      e2["level_1_c"].keys.must_include "fslash -> \\/ bslash -> \\\\"
    end
  end 
end
