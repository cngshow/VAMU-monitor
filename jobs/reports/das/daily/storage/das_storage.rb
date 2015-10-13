def charting_data_points(rpt_doc)
    rpt_date = rpt_doc[:_id]
    prev_day = rpt_date - (60*60*24)
    prev_doc = @collection.find({_id: prev_day}).first
    prev_pts = disk_space_points(prev_doc)
    curr_pts = disk_space_points(rpt_doc)
    [prev_pts, curr_pts]
end

def disk_space_points(doc)
  ret = {core: {:avail => nil, :used => nil},
         audit: {:avail => nil, :used => nil}}

  core = (doc[:storage][:core_used])/(1024.0**4)#G
  grid = (doc[:storage][:grid_used])/(1024.0**4)#H
  used = core + grid#C
  avail = 20.0 - used#D
  ret[:core][:avail] = avail.round(2)
  ret[:core][:used] = used.round(2)

  # get the audit data
  audit_used = (doc[:storage][:audit_used])/(1024.0**4)#L
  audit_avail = 5.1 - audit_used#M
  ret[:audit][:avail] = audit_avail.round(2)
  ret[:audit][:used] = audit_used.round(2)
  ret
end
