require 'erb'

class PropLoader
  APPLICATION_PROP_FILE = './pst_dashboard.properties.erb'

  def PropLoader.load_properties(properties_filename)
    properties = {}
    File.open(properties_filename, 'r') do |properties_file|
      properties_file.read.each_line do |line|
        PropLoader.process_prop(properties, line)
      end
    end
    properties
  end

  def PropLoader.load_properties_from_erb(erb = APPLICATION_PROP_FILE)
    props = ERB.new(File.open(erb,'r') {|file| file.read }).result
    properties = {}
    prop_array = props.split("\n")
    prop_array.each do |line|
      PropLoader.process_prop(properties, line)
    end
    properties
  end

  def PropLoader.load_properties_from_string(props)
    properties = {}
    prop_array = props.split("\n")
    prop_array.each do |line|
      PropLoader.process_prop(properties, line)
    end
    properties
  end

  def PropLoader.process_prop(properties, line)
    line.strip!
    if (line[0] != ?# and line[0] != ?=)
      i = line.index('=')
      if (i)
        properties[line[0..i - 1].strip] = line[i + 1..-1].strip
      else
        properties[line] = ''
      end
    end
  end
end

module PropHashBuilder
  def get_prop_hash(prop_file, logger = nil)
    prop_hash = {}
    begin
      prop_hash = PropLoader.load_properties(prop_file)
      logger.info("PropFile #{prop_file} was loaded successfully.") unless logger.nil?
    rescue
      logger.error "Failed to load #{prop_file}" << $!.to_s unless logger.nil?
    end
    prop_hash
  end
end