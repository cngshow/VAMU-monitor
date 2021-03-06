require 'time_utils'
require 'helpers'

# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
	# include SystemPropConstants

  def errors_to_flash(errors)
    retval = []
    errors.each {|attr,error_string|
      formatted_attr = attr.to_s.gsub('_',' ').capitalize + " " + error_string
      retval << formatted_attr
    }
    retval.flatten
  end

	def admin_check?
		! current_user.nil? && (current_user.administrator)
	end

	def set_field_focus(id, selected = false)
    script = "$('#" + id + "').focus();"
    script += "$('#" + id + "').select();" if selected
		javascript_tag(script);
	end

	def system_suspended?
		begin
			return Boolean(SystemProp.get_value(SUSPEND))
		rescue
		  return false
		end
	end

	def convert_seconds_to_time(time)
		#    time = time.to_i
		#    time_string = [time/3600, time/60 % 60, time % 60].map{|t| t.to_s.rjust(2,'0')}.join(':')
		#    time_string.sub!(':','h ').sub!(':','m ').concat('s')
		#    time_string.sub!('00h 00m ','')
		#    time_string.sub!('00h ','')
		#    time_string
		time_string = "%02dd %02dh %02dm %02ds"% [
			time.to_i/ (60*60*24),
			time.to_i/ (60*60) % 24,
			time.to_i/ 60 % 60,
			time.to_i % 60
		]
		time_string.sub!('00d 00h 00m ', '')
		time_string.sub!('00d 00h ', '')
		time_string.sub!('00d ', '')
		time_string
	end

	def display_time(time)
		ret = ""
		if (! time.nil?)
			converted_time = time + session[:tzOffset].to_i.hours
			ret = converted_time.strftime("%m/%d/%Y %H:%M:%S") << " " << TimeUtils.offset_to_zone(session[:tzOffset])
		end
		ret
	end

	def commas_to_br(string)
		return '' if string.nil?
		string.gsub!(',', '<br/>')
		string
	end

	def job_meta_datas_to_option_list(jmds,option_name)
		js = String.new
		jmds.each do  |jc|
      js << "<option value='#{jc}'>#{jc}</option>"
    end
    #js
    raw("#{option_name} = \"" + js + "\";")
  end

  def add_on_doc_ready_js(javascript)
    (@on_ready_calls ||= []).push(javascript)
  end

  def write_on_ready
    unless @on_ready_calls.nil?
      js = "jQuery(window).ready(function() {\n"

      @on_ready_calls.each do |js_code|
        js << js_code + "\n"
      end
      js << "});"

      #reset the @on_ready_calls variable for the next request
      @on_ready_calls = nil
      javascript_tag(raw(js))
    end
  end
end
