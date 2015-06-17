module DailyReportHelper
  def get_str_audit_hash(rpt_date)
    #this takes around 4 minutes to complete
    dt = get_gmt(rpt_date)
    end_dt = format_date(dt + (60*60*24),'%Y-%m-%d')
    putty = %{c:\\putty\\plink dasuser@bhiepapp4.r04.med.va.gov -pw dasprod@123! \"cd audit && ./ecrudstraudit.sh '#{rpt_date}' '#{end_dt}'\"}
    data = `#{putty}`.split("\n")

    # read the data calculating the first and second pass counts and response times
    hours_hash = {'23' => '19','00' => '20','01' => '21','02' => '22','03' => '23','04' => '00','05' => '01','06' => '02','07' => '03','08' => '04','09' => '05','10' => '06','11' => '07','12' => '08','13' => '09','14' => '10','15' => '11','16' => '12','17' => '13','18' => '14','19' => '15','20' => '16','21' => '17','22' => '18'}
    ret = {}

    hours_hash.keys.each do |k|
      ret[k] = {'1p'.to_sym => {:success => 0, :failure => 0, :response_time => 0}, '2p'.to_sym => {:success => 0, :failure => 0, :response_time => 0}}
    end
    tot_trans_time = nil
    pass1_count = 0
    pass2_count = 0

   data.each do |line|
      unless line.include?("[dasuser@bhiepapp4")
        cols = line.split(',').map(&:strip)
        tot_trans_time = cols[0]
        hour = '%02d' % Time.parse(cols[0]).hour
        status = cols[1].to_i
        resp_time = cols[2]
        pass = cols[4].to_sym

        pass1_count += 1 if pass.eql?('1p'.to_sym)
        pass2_count += 1 unless pass.eql?('1p'.to_sym)
        ret[hour][pass][status == 200 ? :success : :failure] += 1
        ret[hour][pass][:response_time] += resp_time.to_i if status == 200
      end
    end

    #get the total transaction time (add an hour and format as a string)
    if tot_trans_time
      tot_trans_time = Time.parse(tot_trans_time)
      hour = tot_trans_time.hour + 1
      min = tot_trans_time.min
      sec = tot_trans_time.sec
      tot_trans_time = "#{'%02d' % hour}:#{'%02d' % min}:#{'%02d' % sec}"
    else
      tot_trans_time = '00:00:00'
    end

    #now format the ret for inclusion into the mongo document
    audit_hash = {tot_trans_time: tot_trans_time, pass1_count: pass1_count, pass2_count: pass2_count, hourly_breakdown: {}}
    hours_hash.each_pair do |k,v|
      audit_hash[:hourly_breakdown][v] = ret[k]
    end
    audit_hash
  end

  def get_str_audit_as_js(data, pass)
    hourly = data[:audit][:breakdown][:hourly_breakdown]
    pass_hash = {}
    hourly.each_pair do |h, v|
      hour_hash = v[pass]
      resp_time = hour_hash[:response_time].to_f
      avg_resp_time = 0.0

      if resp_time > 0
        avg_resp_time = ((resp_time/(hour_hash[:success] + hour_hash[:failure]))/1000)
      end

      hour_hash[:avg_resp_time] = avg_resp_time
      pass_hash[h] = hour_hash
    end

    # add the saved docs to the second pass hash
    if pass.eql?('2p')
      str_docs_hourly = data[:audit][:breakdown][:str_docs_saved_hourly]
      str_docs_hourly.each_pair do |h,v|
        pass_hash['%02d' % h][:str_docs_saved] = v
      end
    end

    # now build the js
    prev_day = (19..23).to_a
    ret = "data: \n[ "
    d = data[:_id]

    pass_hash.each_pair do |h,v|
      hr = h.to_i
      dt = (prev_day.include?(hr) ? d - (60*60*24) : d)
      dt = dt + (60*60*hr)

      if (pass.eql?('1p'))
        ret << "[{v: new Date(#{dt.year}, #{dt.month}, #{dt.day}, #{hr}, 0, 0), f: '#{format_date(dt,'%l %p').strip}'}, #{v[:success]}, #{v[:failure]}, #{v[:avg_resp_time]}],\n"
      else
        ret << "[{v: new Date(#{dt.year}, #{dt.month}, #{dt.day}, #{hr}, 0, 0), f: '#{format_date(dt,'%l %p').strip}'}, #{v[:success]}, #{v[:failure]}, #{v[:str_docs_saved] || 0}, #{v[:avg_resp_time]}],\n"
      end
    end
    ret.chomp!(",\n")
    ret << "\n]"
  end

  def get_str_download_total_data(doc)
    data = %{[
      ["STR Administrative Documentation (includes Certification Memo)",#{doc[:str][:admin_doc_vet]},#{doc[:str][:admin_doc_tot]}],
      ["STR AHLTA.pdf ",#{doc[:str][:ahlta_pdf_vet]},#{doc[:str][:ahlta_pdf_tot]}],
      ["STR Dental Record Part 1 ",#{doc[:str][:dental_part1_vet]},#{doc[:str][:dental_part1_tot]}],
      ["STR Dental Record Part 2 ",#{doc[:str][:dental_part2_vet]},#{doc[:str][:dental_part2_tot]}],
      ["STR Dental Record Part 3 ",#{doc[:str][:dental_part3_vet]},#{doc[:str][:dental_part3_tot]}],
      ["STR Dental Record Part 4 ",#{doc[:str][:dental_part4_vet]},#{doc[:str][:dental_part4_tot]}],
      ["STR Medical Record Part 1 ",#{doc[:str][:medical_part1_vet]},#{doc[:str][:medical_part1_tot]}],
      ["STR Medical Record Part 2 ",#{doc[:str][:medical_part2_vet]},#{doc[:str][:medical_part2_tot]}],
      ["STR Medical Record Part 3 ",#{doc[:str][:medical_part3_vet]},#{doc[:str][:medical_part3_tot]}],
      ["STR Medical Record Part 4 ",#{doc[:str][:medical_part4_vet]},#{doc[:str][:medical_part4_tot]}],
      ["STR HRR",#{doc[:str][:hrr_vet]},#{doc[:str][:hrr_tot]}],
      ["Other",0,CALC_OTHER] ]
    }
    type_counts = [doc[:str][:admin_doc_tot],
                   doc[:str][:ahlta_pdf_tot],
                   doc[:str][:dental_part1_tot],
                   doc[:str][:dental_part2_tot],
                   doc[:str][:dental_part3_tot],
                   doc[:str][:dental_part4_tot],
                   doc[:str][:medical_part1_tot],
                   doc[:str][:medical_part2_tot],
                   doc[:str][:medical_part3_tot],
                   doc[:str][:medical_part4_tot],
                   doc[:str][:hrr_tot]]
    sum_tot = type_counts.inject(0) { |result, element| result + element }
    other = doc[:str][:tot_str_count] - sum_tot
    data.gsub!('CALC_OTHER', other.to_s)
  end

  def get_str_daily_data
    ret = "[ \n"
    query = get_str_daily_count
    query.each do |doc|
      ret << "[ new Date('#{format_date(doc[:_id], '%-m/%-d/%Y')}'),#{doc[:str][:yesterday_count]}],\n"
    end
    ret.chomp!(",\n")
    ret << "]"
  end

  def get_scatter_plot_data
    doc_nbr = 0
    limit = (@doc[:str][:yesterday_count] < 1500) ? 1500 : @doc[:str][:yesterday_count]
    ret = "[ \n"
    query = str_scatter_plot_query(@doc[:rpt_date_string], limit)
    query.each do |doc|
      size = (doc['str:ServiceTreatmentRecord']['str:Attachments']['nc:Attachment']['nc:BinarySizeValue']).to_f / 1024**2
      lt100 = size < 100.0 ? size : 0
      gt100 = size > 100.0 ? size : 0
      ret << "[#{doc_nbr += 1},#{lt100},#{gt100}],"
    end
    ret.chomp!(",\n")
    ret << "]"
    ret
  end
end
