require 'tempfile'

module JobUtility
  def backtick(command)
    f = Tempfile.new(File.basename($0))
    f.close
    system("#{command} > #{f.path}")
    result = f.open.read
    f.close
    f.unlink
    result
  end
end
