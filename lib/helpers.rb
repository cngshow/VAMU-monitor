module PSTConstants
	PST_SUSPEND='SUSPEND'
  PST_COMPLETED='Completed'
  PST_SYSTEM = 'SYSTEM'
  PST_PENDING = 'Pending'
  PST_RUNNING = 'Running'
  PST_UNKNOWN = 'UNKNOWN'
  PST_RED = 'RED'
  PST_GREEN = 'GREEN'
  PST_ALL = 'ALL'
  PST_FAILURE = 'Failure'

end

module Kernel
	def Boolean(string)
		return true if string == true || string =~ /^true$/i
		return false if string == false || string.nil? || string =~ /^false$/i
		raise ArgumentError.new("invalid value for Boolean: \"#{string}\"")
	end

end

module ActionView::Helpers::UrlHelper
	def link_to_absolute(relative_string)
		#url_for  :controller => controller, :action =
		host = $application_properties['root_url']
		relative_string.sub!("<a href=\"","<a href=\"#{host}")
		relative_string
	end

end

class ActionController::Request

	#  def ssl?()
	#    puts "RAILS ActionController::Request -- ssl"
	#    https_on = @env['HTTPS']
	#    proto = @env['HTTP_X_FORWARDED_PROTO']
	#    puts "https_on = #{https_on.to_s}, proto = #{proto.to_s}"
	#    #return true
	#    @env['HTTPS'] == 'on' || @env['HTTP_X_FORWARDED_PROTO'] == 'https'
	#
	#  end
	def protocol
		#puts "RAILS ActionController::Request - protocol"
		https = Boolean($application_properties['use_https'])
		https ? 'https://' : 'http://'
	# original definition
	#       ssl? ? 'https://' : 'http://'
	end

end

module Utilities
	class FileHelper
		def FileHelper.file_as_string(file)
			rVal = ''
			File.open(file, 'r') do |file_handle|
				file_handle.read.each_line do |line|
					rVal << line
				end
			end
			rVal
		end
	end
end

module DeviseHelpers
  class ParameterSanitizer < Devise::ParameterSanitizer
    def account_update
      default_params.permit(:username, :email, :password, :password_confirmation, :current_password)
    end
    def sign_up
      default_params.permit(:username, :email, :password, :password_confirmation)
    end
  end
end

#module TrinidadHelper
#  def trinidad_ssl_enforcer(action_array)
#    if (!$trinidad_config[:ssl].nil? && !$trinidad_config[:ssl][:port].nil?)
#      force_ssl only: action_array, port: $trinidad_config[:ssl][:port]
#    else
#      force_ssl only: action_array unless $trinidad_config[:ssl].nil?
#    end
#  end
#end