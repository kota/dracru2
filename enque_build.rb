$: << File.dirname(__FILE__)
require 'dracru2'
ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3',
  :database => DB
)
unless BuildQueue.table_exists?
  ActiveRecord::Base.connection.create_table(:build_queues) do |t|
    t.column :buildingid, :integer
    t.timestamps
  end
end

if ARGV[0] && ARGV[0].to_i != 0
  if build_queue = BuildQueue.create(:buildingid => ARGV[0].to_i)
    puts "Enqueued #{BuildQueue::BUILDING_NAMES[ARGV[0].to_i]} successfully"
    puts "Queued Buidings."
    BuildQueue.find(:all,:order => 'id asc').each do |queue|
      puts BuildQueue::BUILDING_NAMES[queue.buildingid]
    end
  end
end
