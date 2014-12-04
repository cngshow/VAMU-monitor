require 'test/unit'
require './lib/ucppool.rb.del_me'

$local_file_base = 'C:\temp\mpi_icns_alive_and_younger_than_three\\'
$data_hash_file  = $local_file_base + 'database_hash.hash'
$sql             = %{
select A.EXTERNAL_AGENCY_PATIENT_ID as deers_id,
    case a.status when 1 then 'active' else 'not active' end as status
from chdr2.patient_identity_xref a
where A.VPID = ?
}

class NoOp
  def method_missing(meth, *args, &block)
  end
end
$logger=NoOp.new

def oracle_credentials
  creds = nil
  File.open('./test/oracle_password.txt.password', 'r') do |file_handle|
    file_handle.read.each_line do |line|
      creds = line.chomp.split(',')
    end
  end
  return creds
end

def file_as_string(file)
  rVal = ''
  File.open(file, 'r') do |file_handle|
    file_handle.read.each_line do |line|
      rVal << line
    end
  end
  rVal
end

def initialize_database_hash
  if (File.exists?($data_hash_file))
    $results_hash = Marshal.load(File.read($data_hash_file))
  else
    $results_hash = {}
  end
end


class NorthChicagoADCTest < Test::Unit::TestCase
  def setup
    creds       = oracle_credentials
    #PRODUCTION
    ucppool     = MyOracleUcpPool.new(creds[0], creds[1], "jdbc:oracle:thin:@//hdr2db4v.aac.va.gov:1569/CHDRP01.AAC.VA.GOV ", 0, 5, 2)
                    #get connection from pool
    $connection = ucppool.get_connection()
    file_data   = file_as_string('C:\temp\mpi_icns_alive_and_younger_than_three\NCwithoutDeathwithCHDRandDLTwithin3yrs.csv')
    file_data   = file_data.split("\n")
    file_data.shift # first line is comment line# ICN|NC VistA IEN|DateLastTreated|EDIPI
    $mpi_hash                = {}
    $mpi_hash[:icn]          = []
    $mpi_hash[:vista_ien]    = []
    $mpi_hash[:last_treated] = []
    $mpi_hash[:edipi]        = []
    dup_hash                 = {}
    file_data.each do |data|
      data = data.split('|').map do |e| e.strip end
      if dup_hash[data[0]].nil?
        dup_hash[data[0]] = 0
      else
        dup_hash[data[0]] += 1
      end
      $mpi_hash[:icn] << data[0]
      $mpi_hash[:vista_ien] << data[1]
      $mpi_hash[:last_treated] << data[2]
      $mpi_hash[:edipi] << data[3]
    end
    dup_results = ''
    dup_hash.each_pair do |k, v|
      dup_results << "ICN #{k} was duplicated #{v} time(s)\n" if (v > 0)
    end
    File.open($local_file_base+"dups.txt", 'w') { |f| f.write(dup_results) }
    puts "Setup done!"
  end

  def test_data_against_oracle
    initialize_database_hash
    if ($results_hash.empty?)
      preparedStatement = $connection.prepareStatement($sql);
      count = 0
      st    = Time.now
      $mpi_hash[:icn].each do |icn|
        $results_hash[icn] = []
        count              = count + 1
        if ((count % 500) == 0)
          puts "Current count is #{count}, elapsed time is " + (Time.now - st).to_s
        end
        preparedStatement.setString(1, icn)
        results = preparedStatement.executeQuery
        if (results.next)
          hash            = {}
          hash[:deers_id] = results.getString("deers_id")
          hash[:status]   = results.getString("status")
          $results_hash[icn] << hash
        else
          $results_hash[icn] = :NOT_FOUND
        end
      end
      File.open($data_hash_file, 'w') do |f|
        f.write Marshal.dump($results_hash)
      end
    end
    puts "Database crap Done!"
    create_results_files
  end

  def create_results_files
    icn_deers_active   = ''
    icn_deers_inactive = ''
    icn_unknown        = ''
    $results_hash.each_pair do |icn, data_hash|
      if (data_hash == :NOT_FOUND)
        icn_unknown << (icn +"\n")
      else
        if (data_hash[0][:status].eql?('active'))
          icn_deers_active << (icn + "," + data_hash[0][:deers_id] + "\n")
        else
          icn_deers_inactive << (icn + "," + data_hash[0][:deers_id] + "\n")
        end
      end
    end

    File.open($local_file_base+"icn_deers_active.csv", 'w') { |f| f.write(icn_deers_active) }
    File.open($local_file_base+"icn_deers_inactive.csv", 'w') { |f| f.write(icn_deers_inactive) }
    File.open($local_file_base+"unknown.csv", 'w') { |f| f.write(icn_unknown) }
  end

end