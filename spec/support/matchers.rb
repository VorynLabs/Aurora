# Permite compor negativas dentro de um único expect com `.and`.
RSpec::Matchers.define_negated_matcher :not_change, :change
