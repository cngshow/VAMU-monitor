require 'tempfile'

module JobUtility
  def backtick(command)
    f = nil
    result = nil

    begin
      f = Tempfile.new(File.basename($0))
      f.close
      system("#{command} > #{f.path}")
      result = f.open.read
    ensure
      f.close
      f.unlink
    end
    result
  end
end
