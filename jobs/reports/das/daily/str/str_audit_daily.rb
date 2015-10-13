require 'json'
require './jobs/helpers/report_helper'
require './jobs/helpers/job_utility'
require 'time'
include ReportHelper
include JobUtility

module StrAuditDaily
  def get_str_audit_hash(rpt_date, str_count)
    init_hash = {:success => 0, :failure => 0, :response_time => 0}
    @hourly_data_hash = (0..23).to_a.map { |a| '%02d' % a.to_s }.inject(Hash.new) { |h, k| h.merge!(k => {:last_trans_time => nil, '1p'.to_sym => init_hash.clone, '2p'.to_sym => init_hash.clone}) }
    tot_trans_time = '00h 00m 00s'
    last_trans_time = nil
    pass1_count = 0
    pass2_count = 0

    unless str_count == 0
      t = 'T00:00:00Z'
      dt = get_gmt(rpt_date)
      @startdt = format_date(dt, '%Y-%m-%d') + t
      @end_dt = format_date(dt + (60*60*24), '%Y-%m-%d') + t
      data = []
      putty = %{#{@plink} dasuser@bhiepapp4.r04.med.va.gov -pw dasprod@123! \"cd audit && ./ecrudstraudit-vamu.sh '#{@startdt}' '#{@end_dt}'\"}

      (1..10).each do
        data = backtick(putty).split("\n")
        next if data.empty?
        break
      end

=begin
    file_path = 'C:\Users\VHAISPBOWMAG\Desktop\DAS-reports\STR DQB Daily Reports\STR Audit Daily Master\STR_daily_audit-gmt-2015-06-25.txt'
    File.open(file_path, 'r').each_line do |line|
      data.push(line)
    end
=end

      # read the data calculating the first and second pass counts and response times
      data.each do |line|
        if line =~ /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}.*$/
          cols = line.split(',').map(&:strip)
          last_trans_time = cols[0]
          hour = '%02d' % Time.parse(last_trans_time).hour
          status = cols[1].to_i
          resp_time = cols[2]
          pass = cols[4].to_sym

          pass1_count += 1 if pass.eql?('1p'.to_sym)
          pass2_count += 1 unless pass.eql?('1p'.to_sym)
          @hourly_data_hash[hour][pass][status == 200 ? :success : :failure] += 1
          @hourly_data_hash[hour][pass][:response_time] += resp_time.to_i if status == 200
          @hourly_data_hash[hour][:last_trans_time] = last_trans_time
        end
      end

      # get the total transaction time. Because the processing window starts at 7PM eastern we need to determine if we are in daylight savings
      # or standard time because midnight GMT will be either 7PM or 8PM eastern depending on daylight savings.
      if last_trans_time
        sum_time_seconds = 0

        @hourly_data_hash.values.each do |v|
          last_time = v[:last_trans_time].nil? ? nil : Time.parse(v[:last_trans_time])
          sum_time_seconds += last_time.min * 60 unless last_time.nil?
          sum_time_seconds += last_time.sec unless last_time.nil?
        end

        # add one hour to the time when we are in daylight savings time by backing off one hour from the start_dt
        tot_trans_time = convert_seconds_to_time(sum_time_seconds)
      end
    end

    #now format the ret for inclusion into the mongo document
    {tot_trans_time: tot_trans_time, pass1_count: pass1_count, pass2_count: pass2_count, hourly_breakdown: @hourly_data_hash}
  end

  def get_str_audit_as_js(data, pass)
    max_resp = 0
    hourly = data[:str][:audit][:breakdown][:hourly_breakdown]
    pass_hash = {}
    hourly.each_pair do |h, v|
      hour_hash = v[pass]
      resp_time = hour_hash[:response_time].to_f
      avg_resp_time = 0.0

      if resp_time > 0
        avg_resp_time = ((resp_time/(hour_hash[:success] + hour_hash[:failure]))/1000).round(1)
      end

      hour_hash[:avg_resp_time] = avg_resp_time
      max_resp = avg_resp_time unless max_resp > avg_resp_time
      pass_hash[h] = hour_hash
    end

    # add the saved docs to the second pass hash
    if pass.eql?('2p')
      str_docs_hourly = data[:str][:audit][:breakdown][:str_docs_saved_hourly]
      str_docs_hourly.each_pair do |h, v|
        pass_hash[h][:str_docs_saved] = v
      end
    end

    # now build the js
    max_scale = max_resp.round(-1) #this rounds to the nearest 10
    max_scale += 10 if max_scale < max_resp #ensure that the max scale is greater than the rounded value
    ret = "viewWindow: {min: 1, max: #{max_scale}},\ndata: \n[ "
    # ret = "data: \n[ "
    d = data[:_id]

    pass_hash.each_pair do |h, v|
      hr = h.to_i
      dt = d + (60*60*hr)

      et = gmt_to_et_time(dt)
      if pass.eql?('1p')
        # ret << "[{v: new Date(#{dt.year}, #{dt.month}, #{dt.day}, #{hr}, 0, 0), f: '#{format_date(dt, '%l %p').strip}'}, #{v[:success]}, #{v[:failure]}, #{v[:avg_resp_time]}],\n"
        ret << "[{v: new Date(#{et.to_i.to_s}), f: '#{format_date(et, '%l %p').strip}'}, #{v[:success]}, #{v[:failure]}, #{v[:avg_resp_time]}],\n"
      else
        # ret << "[{v: new Date(#{dt.year}, #{dt.month}, #{dt.day}, #{hr}, 0, 0), f: '#{format_date(dt, '%l %p').strip}'}, #{v[:success]}, #{v[:failure]}, #{v[:str_docs_saved] || 0}, #{v[:avg_resp_time]}],\n"
        ret << "[{v: new Date(#{et.to_i.to_s}), f: '#{format_date(et, '%l %p').strip}'}, #{v[:success]}, #{v[:failure]}, #{v[:str_docs_saved] || 0}, #{v[:avg_resp_time]}],\n"
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
    query = get_str_daily_counts
    query.each do |doc|
      ret << "[ new Date('#{format_date(doc[:_id], '%-m/%-d/%Y')}'),#{doc[:str][:yesterday_count]}],\n" #to_i to epoch?!
    end
    ret.chomp!(",\n")
    ret << ']'
  end

  def get_str_daily_counts
    @collection
        .find(_id: {"$lte" => @doc[:_id]})
        .select(_id: 1, "str.yesterday_count" => 1)
        .sort(_id: -1)
        .limit(120)
  end

  def get_scatter_plot_data
    doc_nbr = 0
    limit = (@doc[:str][:yesterday_count] < 5000) ? 5000 : (@doc[:str][:yesterday_count] > 10000 ? 10000 : @doc[:str][:yesterday_count])
    ret = "[ \n"
    query = str_scatter_plot_query(@doc[:rpt_date_string], limit)
    query.each do |doc|
      size = ((doc['str:ServiceTreatmentRecord']['str:Attachments']['nc:Attachment']['nc:BinarySizeValue']).to_f / 1024**2).round(3)
      lt100 = size < 100.0 ? size : 'null'
      gt100 = size > 100.0 ? size : 'null'
      ret << "[#{doc_nbr += 1},#{lt100},#{gt100}],\n"
    end
    ret.chomp!(",\n")
    ret << "]"
    ret
  end

# http://mongoid.org/en/mongoid/docs/querying.html
  def str_scatter_plot_query(rpt_date, limit = 1500)
    @core_db["serviceTreatmentRecords"]
        .find(uploadDate: {"$gte" => get_gmt(rpt_date)})
        .select("_id" => 0, "str:ServiceTreatmentRecord.str:Attachments.nc:Attachment.nc:BinarySizeValue" => 1)
        .limit(limit)
  end

  def str_doc_size_breakdown(startdate, enddate)
    match = {"$match" => {:uploadDate => {"$gte" => startdate, "$lt" => enddate}}}
    project = {"$project" => {"_id" => 0,
                              "year" => {"$year" => "$uploadDate"},
                              "month" => {"$month" => "$uploadDate"},
                              "day" => {"$dayOfMonth" => "$uploadDate"},
                              "sizeMb" => {"$divide" => ["$str:ServiceTreatmentRecord.str:Attachments.nc:Attachment.nc:BinarySizeValue", 1048576.0]}}}
    group = {"$group" => {"_id" => {"year" => "$year",
                                    "month" => "$month",
                                    "day" => "$day"}, "total_count" => {"$sum" => 1},
                          "lt5mb" => {"$sum" => {"$cond" => [{"$lt" => ["$sizeMb", 5.0]}, 1, 0]}},
                          "btw5and25mb" => {"$sum" => {"$cond" => [{"$and" => [
                                                                       {"$gte" => ["$sizeMb", 5.0]},
                                                                       {"$lt" => ["$sizeMb", 25.0]}]}, 1, 0]}},
                          "btw25and50mb" => {"$sum" => {"$cond" => [{"$and" => [
                                                                       {"$gte" => ["$sizeMb", 25.0]},
                                                                       {"$lt" => ["$sizeMb", 50.0]}]}, 1, 0]}},
                          "btw50and75mb" => {"$sum" => {"$cond" => [{"$and" => [
                                                                        {"$gte" => ["$sizeMb", 50.0]},
                                                                        {"$lt" => ["$sizeMb", 75.0]}]}, 1, 0]}},
                          "btw75and100mb" => {"$sum" => {"$cond" => [{"$and" => [
                                                                         {"$gte" => ["$sizeMb", 75.0]},
                                                                         {"$lt" => ["$sizeMb", 100.0]}]}, 1, 0]}},
                          "gte100mb" => {"$sum" => {"$cond" => [{"$gte" => ["$sizeMb", 100.0]}, 1, 0]}}
    }}
    sort = {"$sort" => {"_id" => -1}}
    query = @core_db["serviceTreatmentRecords"].aggregate([match, project, group, sort])
    query.entries
  end
end
