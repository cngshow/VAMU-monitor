def dbq_chart_points(doc)
  ret = {rpt_date: doc[:_id], dbq_tot_size: 0, dbqs_submitted: 0, capri_count: 0, external_count: 0}
  o = 78851166512+59125820796
  n = doc[:str][:tot_str_attachments]
  m = doc[:dbq][:fs_size]
  q = 42991214320
  p = m - (n + o)
  r = (p + q) / 1024.0**3
  ret[:dbq_tot_size] = r.round(2)
  ret[:dbqs_submitted] = doc[:dbq][:completed_count] + 16447
  ret[:capri_count] = doc[:dbq][:capri_count]
  ret[:external_count] = doc[:dbq][:external_count]
  ret
end

def dbq_data
  ret = []
  @collection.find({}).sort({_id: 1}).each do |doc|
    ret << doc
    break if doc[:_id].eql?(@doc[:_id])
  end
  ret
end

def get_dbq_counts(line, external = false)
  line =~ /.*(\s\d+).*(\s\d+).*(\s\d+).*(\s\d+).*/ unless external
  ret = [$1,$2,$3,$4] unless external
  line =~ /.*(\s\d+).*(\s\d+).*(\s\d+).*/ if external
  ret = [$1,$2,$3] if external
  ret
end