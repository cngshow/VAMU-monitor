#config/initializers/legacy_data_type_coercion.rb
module LegacyDataTypeCoercion
  def set_integer_columns *col_names
    col_names.each do |col_name|
      columns_hash[col_name.to_s].instance_eval do
        @precision = 0
      end
    end
  end

=begin
  def force_integer_columns *col_names
    class << self.
  end
=end

end
ActiveRecord::Base.extend(LegacyDataTypeCoercion)
